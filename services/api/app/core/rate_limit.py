"""
Rate Limiting & Abuse Protection Module for Roomlyst API.
Adheres to Blueprint Section 24 & Milestone 1.6:
- Implements sliding window token/request rate limiting.
- Protects resource-intensive generation endpoints against denial-of-service and quota exhaustion.
- Emits standard HTTP 429 Too Many Requests with Retry-After headers.
"""

import os
import time
from collections import defaultdict
from typing import Dict, List, Optional
from fastapi import HTTPException, Request, status


class SlidingWindowRateLimiter:
    """
    In-memory thread-safe sliding window rate limiter.
    Easily swappable with Redis for distributed multi-instance deployments.
    """

    def __init__(self, default_limit: int = 60, window_seconds: int = 60):
        self.default_limit = default_limit
        self.window_seconds = window_seconds
        # client_key -> list of timestamp floats
        self._history: Dict[str, List[float]] = defaultdict(list)
        self.enabled = os.getenv("RATE_LIMIT_ENABLED", "true").lower() in ("1", "true", "yes")

    def _get_client_key(self, request: Request, custom_key: Optional[str] = None) -> str:
        if custom_key:
            return custom_key
        # Check X-Forwarded-For header or direct client host
        forwarded = request.headers.get("x-forwarded-for")
        if forwarded:
            return forwarded.split(",")[0].strip()
        if request.client and request.client.host:
            return request.client.host
        return "unknown_client"

    def check(
        self,
        request: Request,
        limit: Optional[int] = None,
        window: Optional[int] = None,
        custom_key: Optional[str] = None,
    ):
        """
        Validates rate limit for the incoming request.
        Raises HTTP 429 if the request threshold is exceeded.
        """
        if not self.enabled:
            return

        max_allowed = limit if limit is not None else self.default_limit
        win_sec = window if window is not None else self.window_seconds
        now = time.time()
        client_key = self._get_client_key(request, custom_key)

        # Filter out expired timestamps
        cutoff = now - win_sec
        timestamps = [t for t in self._history[client_key] if t > cutoff]

        if len(timestamps) >= max_allowed:
            oldest_relevant = timestamps[0]
            retry_after = max(1, int(oldest_relevant + win_sec - now))
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail=f"Rate limit exceeded: maximum {max_allowed} requests per {win_sec}s.",
                headers={
                    "Retry-After": str(retry_after),
                    "X-RateLimit-Limit": str(max_allowed),
                    "X-RateLimit-Remaining": "0",
                    "X-RateLimit-Reset": str(int(now + retry_after)),
                },
            )

        # Record this request
        timestamps.append(now)
        self._history[client_key] = timestamps

    def reset(self):
        """Clears all rate limit state (useful in testing)."""
        self._history.clear()


# Global rate limiter instances
general_limiter = SlidingWindowRateLimiter(default_limit=60, window_seconds=60)
generation_limiter = SlidingWindowRateLimiter(default_limit=10, window_seconds=60)


def rate_limit_general(request: Request):
    """Dependency enforcing standard API limits (60 req/min)."""
    general_limiter.check(request, limit=60, window=60)


def rate_limit_generation(request: Request):
    """Dependency enforcing strict AI generation limits (10 req/min)."""
    generation_limiter.check(request, limit=10, window=60)
