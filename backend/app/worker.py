"""
CloudLab Celery Worker
Phase 0.2: stub. Tasks added in Phase 1 (idle detection, auto-pause).
"""

import os

from celery import Celery

REDIS_URL = os.getenv("REDIS_URL", "redis://localhost:6379/0")

worker = Celery(
    "cloudlab",
    broker=REDIS_URL,
    backend=REDIS_URL,
    include=["app.tasks"],
)

worker.conf.update(
    task_serializer="json",
    accept_content=["json"],
    result_serializer="json",
    timezone="UTC",
    enable_utc=True,
)
