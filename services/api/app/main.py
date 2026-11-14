"""
Main FastAPI Entrypoint for Roomlyst.
Adheres to Blueprint Section 17 & Milestone 0.4.
"""

import os
from typing import Optional
from fastapi import Depends, FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles
from sqlalchemy.orm import Session

from .api.v1.admin import router as admin_router
from .api.v1.auth import router as auth_router
from .api.v1.endpoints import router as v1_router
from .api.v1.jobs import router as jobs_router
from .api.v1.media import router as media_router
from .db.session import get_db, init_db

# Ensure storage directories exist
os.makedirs("storage/uploads", exist_ok=True)
os.makedirs("storage/outputs", exist_ok=True)
os.makedirs("apps/poc-web", exist_ok=True)

# Initialize database schema
init_db()

app = FastAPI(
    title="Roomlyst API",
    description="AI-Powered Interior Design & Renovation Platform",
    version="1.0.0-mvp",
)

# Enable CORS for local web development
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Blueprint Section 20 & 23, ADR-005 & ADR-008: Secure media serving with path-traversal prevention & auth verification
@app.api_route("/storage/{file_path:path}", methods=["GET", "HEAD"])
def get_storage_file(
    file_path: str,
    request: Request,
    sig: Optional[str] = None,
    exp: Optional[int] = None,
    db: Session = Depends(get_db),
):
    from .api.v1.media import serve_media_asset
    return serve_media_asset(file_path=file_path, request=request, sig=sig, exp=exp, db=db)

# Include API v1 routers
app.include_router(auth_router, prefix="/api/v1")
app.include_router(jobs_router, prefix="/api/v1")
app.include_router(media_router, prefix="/api/v1")
app.include_router(admin_router, prefix="/api/v1")
app.include_router(v1_router, prefix="/api/v1", tags=["V1 Endpoints"])


@app.get("/health")
def health_check():
    """Health and liveness probe."""
    return {
        "status": "healthy",
        "service": "roomlyst-api",
        "version": "0.2.0",
        "phase": "Phase 0 - POC / Technical Validation",
    }


# Mount POC Web UI
poc_index_path = os.path.join("apps", "poc-web", "index.html")


@app.get("/")
def serve_poc_root():
    """Serves the Milestone 0.4 POC Web Interface."""
    if os.path.exists(poc_index_path):
        return FileResponse(poc_index_path)
    return {
        "message": "Roomlyst API is running. POC UI index.html not yet built.",
        "docs_url": "/docs",
    }


if os.path.exists("apps/poc-web"):
    app.mount("/ui", StaticFiles(directory="apps/poc-web", html=True), name="poc-web")
