"""
CloudLab Celery Tasks
Phase 0.2: placeholder. Real tasks (idle detection, auto-pause) added in Phase 1.
"""

from app.worker import worker


@worker.task
def ping() -> str:
    """Health check task — verifies Celery worker is reachable."""
    return "pong"
