"""
Unit tests for Multi-Provider AI Evaluator & REST Endpoints.
Validates Ollama, Gemini, OpenAI, Claude routing, heuristic fallback, and API responses.
"""

import pytest
from fastapi.testclient import TestClient

from packages.room_model import CanonicalRoomModel, Geometry
from services.api.app.db.repository import repository
from services.api.app.main import app
from services.ai_worker.pipelines.ai_evaluator import ai_evaluator


@pytest.fixture
def client():
    return TestClient(app)


@pytest.fixture
def sample_room():
    room = CanonicalRoomModel(
        id="room_ai_eval_01",
        name="Penthouse Master Suite",
        room_type="bedroom",
        geometry=Geometry(
            floor_area_sqm=32.5,
            ceiling_height_m=3.1,
            wall_perimeter_m=24.0,
        ),
    )
    repository.save_room(room)
    return room


def test_ai_status_endpoint(client):
    resp = client.get("/api/v1/ai/status")
    assert resp.status_code == 200
    data = resp.json()
    assert "providers" in data
    assert "ollama" in data["providers"]
    assert "gemini" in data["providers"]
    assert "openai" in data["providers"]
    assert "claude" in data["providers"]
    assert "url" in data["providers"]["ollama"]


def test_ai_config_endpoint(client):
    resp = client.post(
        "/api/v1/ai/config",
        json={
            "ollama_url": "http://192.168.0.200:11434",
            "default_model": "llama3.2:latest",
        },
    )
    assert resp.status_code == 200
    data = resp.json()
    assert data["status"] == "UPDATED"
    assert data["ollama_url"] == "http://192.168.0.200:11434"
    assert data["default_model"] == "llama3.2:latest"


def test_ai_evaluation_endpoint(client, sample_room):
    resp = client.post(
        f"/api/v1/rooms/{sample_room.id}/ai-evaluation",
        json={
            "provider": "ollama",
            "model": "llama3.2:latest",
            "custom_prompt": "Evaluate for luxury minimalist staging.",
        },
    )
    assert resp.status_code == 200
    report = resp.json()
    assert report["room_id"] == sample_room.id
    assert report["overall_score"] > 0
    assert report["aesthetic_score"] > 0
    assert report["feasibility_score"] > 0
    assert report["value_score"] > 0
    assert len(report["summary"]) > 0
    assert len(report["high_impact_recommendations"]) > 0
    assert "Electrical" in report["trade_insights"]
    assert "Carpentry" in report["trade_insights"]


def test_ai_evaluation_room_not_found(client):
    resp = client.post("/api/v1/rooms/non_existent_room_999/ai-evaluation")
    assert resp.status_code == 404
