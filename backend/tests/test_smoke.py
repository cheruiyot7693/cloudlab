"""
Phase 0.2 — Smoke tests: verify the app starts and health endpoint responds.
"""

import pytest
from httpx import ASGITransport, AsyncClient

from app.main import app


@pytest.fixture
async def client():
    async with AsyncClient(
        transport=ASGITransport(app=app), base_url="http://test"
    ) as ac:
        yield ac


async def test_health(client):
    response = await client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "ok"
    assert data["service"] == "cloudlab-api"


async def test_root(client):
    response = await client.get("/")
    assert response.status_code == 200
    assert "CloudLab" in response.json()["message"]
