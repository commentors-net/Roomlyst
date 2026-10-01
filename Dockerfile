# Roomlyst Production Backend Dockerfile
FROM python:3.10-slim

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy dependency requirements
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application source directories
COPY packages/ packages/
COPY services/ services/
COPY apps/ apps/
COPY storage/ storage/

# Create persistent storage directories
RUN mkdir -p storage/uploads storage/outputs storage/point_clouds storage/video_sessions

# Set Python path to resolve packages and services
ENV PYTHONPATH="/app:/app/packages:/app/services"
ENV PYTHONUNBUFFERED=1

EXPOSE 8000

# Healthcheck probe
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# Start Uvicorn ASGI server
CMD ["uvicorn", "services.api.app.main:app", "--host", "0.0.0.0", "--port", "8000"]
