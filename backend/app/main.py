"""
CloudLab Platform — FastAPI Application Entry Point
Phase 0.2: stub that proves the server starts.
Full implementation begins in Phase 1.
"""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI(
    title="CloudLab Platform API",
    description="Managed cloud lab environment for network engineers.",
    version="0.1.0",
    docs_url="/docs",
    redoc_url="/redoc",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health", tags=["system"])
async def health() -> dict:
    """Health check endpoint used by Docker and Kubernetes probes."""
    return {"status": "ok", "service": "cloudlab-api", "version": "0.1.0"}


@app.get("/", tags=["system"])
async def root() -> dict:
    return {"message": "CloudLab Platform API", "docs": "/docs"}
