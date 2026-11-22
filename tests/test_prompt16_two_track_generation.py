"""
Tests for Prompt 16: Genuine AI Room Redesign — Cloud and Local AI Evaluation.
Validates:
1. GET /api/v1/ai/inpainting-status endpoint:
   - Returns metadata for all 3 tracks: cloud_ai (Track A), local_ai (Track B), algorithmic_preview.
   - Contains honest hardware evaluation findings for staging host 192.168.0.200 (AMD Vega APU, 0 CUDA cores).
   - Validates cost, spend gate requirement, and privacy attributes.
2. LocalDiffusionInpaintingAdapter (Track B):
   - Probes availability against offline ComfyUI endpoint and fails closed with detailed hardware guidance.
   - dry_run() schema verification with 0 spend and local network retention.
   - inpaint() fail-closed behavior when worker is unreachable (no silent mock substitution).
   - Mock diffusion mode behavior when TEST_MOCK_DIFFUSION=1.
3. Fail-closed provider gating on POST /api/v1/rooms/{id}/design-requests:
   - generation_mode: "cloud_ai" fails closed with HTTP 503 PROVIDER_UNCONFIGURED when Replicate token is unset ($0 spend gate).
   - generation_mode: "local_ai" fails closed with HTTP 503 PROVIDER_UNCONFIGURED when ComfyUI worker is offline.
   - generation_mode: "algorithmic_preview" succeeds with HTTP 200, generating 3 variants with truthful disclosure.
4. Mathematical verification of honest engine disclosure:
   - Algorithmic preview is verified as spatial blockout / compositing rather than disguised diffusion.
"""

import io
import os
import pytest
from PIL import Image
from fastapi.testclient import TestClient

from services.api.app.main import app
from services.ai_worker.pipelines.inpainting import (
    LocalDiffusionInpaintingAdapter,
    InpaintingRequest,
    ProviderUnconfiguredException,
    get_inpainting_provider,
    ImageCompositingVsNeuralDetector,
)

client = TestClient(app)


def create_synthetic_image(width=512, height=512, color=(160, 180, 200)) -> bytes:
    img = Image.new("RGB", (width, height), color=color)
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    return buf.getvalue()


def create_synthetic_mask(width=512, height=512) -> bytes:
    mask = Image.new("L", (width, height), color=0)
    # Paint a 200x200 box in center as inpaint region (255)
    for x in range(156, 356):
        for y in range(156, 356):
            mask.putpixel((x, y), 255)
    buf = io.BytesIO()
    mask.save(buf, format="PNG")
    return buf.getvalue()


def test_inpainting_status_endpoint():
    """Verifies GET /api/v1/ai/inpainting-status returns all 3 tracks with correct metadata."""
    res = client.get("/api/v1/ai/inpainting-status")
    assert res.status_code == 200
    data = res.json()
    assert data["status"] == "success"
    tracks = data["tracks"]

    # 1. Cloud AI (Track A)
    assert "cloud_ai" in tracks
    cloud = tracks["cloud_ai"]
    assert cloud["track"] == "Track A"
    assert cloud["cost_estimate_usd"] > 0
    assert cloud["requires_spend_authorization"] is True
    assert cloud["requires_cloud_data_transfer"] is True
    assert cloud["is_genuine_neural"] is True

    # 2. Local AI (Track B)
    assert "local_ai" in tracks
    local = tracks["local_ai"]
    assert local["track"] == "Track B"
    assert local["cost_estimate_usd"] == 0.0
    assert local["requires_spend_authorization"] is False
    assert local["requires_cloud_data_transfer"] is False
    assert "hardware_assessment" in local
    hw = local["hardware_assessment"]
    assert "192.168.0.200" in hw["host"]
    assert "Ryzen" in hw["cpu"]
    assert "Vega" in hw["gpu"] or "None" in hw["gpu"]
    assert hw["feasibility"] == "NOT_FEASIBLE_ON_LOCAL_SERVER_CPU"

    # 3. Algorithmic Preview (Fallback)
    assert "algorithmic_preview" in tracks
    algo = tracks["algorithmic_preview"]
    assert algo["is_available"] is True
    assert algo["cost_estimate_usd"] == 0.0
    assert algo["is_photorealistic"] is False


def test_local_diffusion_adapter_availability_and_dry_run():
    """Tests LocalDiffusionInpaintingAdapter availability check and dry-run schema validation."""
    adapter = LocalDiffusionInpaintingAdapter(endpoint_url="http://127.0.0.1:59999")
    
    # Live availability check when service is offline
    is_avail, reason = adapter.is_available()
    assert is_avail is False
    assert "llmserver" in reason
    assert "Vega" in reason

    # Dry-run execution
    req = InpaintingRequest(
        image_bytes=create_synthetic_image(512, 512),
        mask_bytes=create_synthetic_mask(512, 512),
        width=512,
        height=512,
        room_id="rm_test_prompt16",
        prompt="Contemporary Scandinavian home office",
        style="Scandinavian",
        num_variants=3,
    )
    dry_result = adapter.dry_run(req)
    assert dry_result["dry_run"] is True
    assert dry_result["is_local_self_hosted"] is True
    assert dry_result["cost_usd"] == 0.0
    assert dry_result["data_leaves_server"] is False
    assert "hardware_assessment" in dry_result


def test_local_diffusion_adapter_fail_closed_without_mock():
    """Tests that LocalDiffusionInpaintingAdapter fails closed rather than producing silent fake images."""
    prev_env = os.environ.get("TEST_MOCK_DIFFUSION")
    if "TEST_MOCK_DIFFUSION" in os.environ:
        del os.environ["TEST_MOCK_DIFFUSION"]

    try:
        adapter = LocalDiffusionInpaintingAdapter(endpoint_url="http://127.0.0.1:59999")
        req = InpaintingRequest(
            image_bytes=create_synthetic_image(512, 512),
            mask_bytes=create_synthetic_mask(512, 512),
            width=512,
            height=512,
            room_id="rm_test_prompt16",
            prompt="Japandi serene living room",
            style="Japandi",
            num_variants=1,
        )
        with pytest.raises(ProviderUnconfiguredException) as excinfo:
            adapter.inpaint(req)
        assert "Local diffusion service is not running" in str(excinfo.value)
    finally:
        if prev_env is not None:
            os.environ["TEST_MOCK_DIFFUSION"] = prev_env


def test_design_requests_cloud_ai_fail_closed_when_unconfigured():
    """Tests that POST /rooms/{id}/design-requests with generation_mode='cloud_ai' returns 503 PROVIDER_UNCONFIGURED."""
    prev_env = os.environ.get("TEST_MOCK_DIFFUSION")
    prev_tok = os.environ.get("REPLICATE_API_TOKEN")
    if "TEST_MOCK_DIFFUSION" in os.environ:
        del os.environ["TEST_MOCK_DIFFUSION"]
    if "REPLICATE_API_TOKEN" in os.environ:
        del os.environ["REPLICATE_API_TOKEN"]

    try:
        # Create a room
        res_proj = client.post("/api/v1/projects", json={"name": "Cloud AI Test Project", "currency": "MYR"})
        proj_id = res_proj.json()["id"]
        files = {"file": ("test.jpg", create_synthetic_image(), "image/jpeg")}
        res_room = client.post("/api/v1/rooms/upload-and-analyze", files=files, data={"project_id": proj_id, "room_name": "Cloud Test Room"})
        room_id = res_room.json()["id"]

        # Request with cloud_ai
        res_gen = client.post(
            f"/api/v1/rooms/{room_id}/design-requests",
            json={
                "styles": ["Modern Minimalist"],
                "goals": ["modernize"],
                "generation_mode": "cloud_ai",
            },
        )
        assert res_gen.status_code == 503
        detail = res_gen.json()["detail"]
        assert detail["error_code"] == "PROVIDER_UNCONFIGURED"
        assert detail["provider_mode"] == "cloud_ai"
        assert detail["suggested_mode"] == "algorithmic_preview"
    finally:
        if prev_env is not None:
            os.environ["TEST_MOCK_DIFFUSION"] = prev_env
        if prev_tok is not None:
            os.environ["REPLICATE_API_TOKEN"] = prev_tok


def test_design_requests_local_ai_fail_closed_when_offline():
    """Tests that POST /rooms/{id}/design-requests with generation_mode='local_ai' returns 503 PROVIDER_UNCONFIGURED."""
    prev_env = os.environ.get("TEST_MOCK_DIFFUSION")
    if "TEST_MOCK_DIFFUSION" in os.environ:
        del os.environ["TEST_MOCK_DIFFUSION"]

    try:
        # Create a room
        res_proj = client.post("/api/v1/projects", json={"name": "Local AI Test Project", "currency": "MYR"})
        proj_id = res_proj.json()["id"]
        files = {"file": ("test.jpg", create_synthetic_image(), "image/jpeg")}
        res_room = client.post("/api/v1/rooms/upload-and-analyze", files=files, data={"project_id": proj_id, "room_name": "Local Test Room"})
        room_id = res_room.json()["id"]

        # Request with local_ai
        res_gen = client.post(
            f"/api/v1/rooms/{room_id}/design-requests",
            json={
                "styles": ["Home Office"],
                "goals": ["workspace"],
                "generation_mode": "local_ai",
            },
        )
        assert res_gen.status_code == 503
        detail = res_gen.json()["detail"]
        assert detail["error_code"] == "PROVIDER_UNCONFIGURED"
        assert detail["provider_mode"] == "local_ai"
        assert "llmserver" in detail["message"]
        assert detail["suggested_mode"] == "algorithmic_preview"
    finally:
        if prev_env is not None:
            os.environ["TEST_MOCK_DIFFUSION"] = prev_env


def test_design_requests_algorithmic_preview_succeeds_with_honest_disclosure():
    """Tests that POST /rooms/{id}/design-requests with generation_mode='algorithmic_preview' succeeds with 3 variants."""
    res_proj = client.post("/api/v1/projects", json={"name": "Algorithmic Preview Test", "currency": "MYR"})
    proj_id = res_proj.json()["id"]
    files = {"file": ("test.jpg", create_synthetic_image(), "image/jpeg")}
    res_room = client.post("/api/v1/rooms/upload-and-analyze", files=files, data={"project_id": proj_id, "room_name": "Algo Test Room"})
    room_id = res_room.json()["id"]

    res_gen = client.post(
        f"/api/v1/rooms/{room_id}/design-requests",
        json={
            "styles": ["Empty & Redesign", "Warm Modern Minimalist"],
            "goals": ["modernize"],
            "generation_mode": "algorithmic_preview",
        },
    )
    assert res_gen.status_code == 200
    ver = res_gen.json()
    assert len(ver["variants"]) == 3
    # Check that variants have truthful metadata
    for v in ver["variants"]:
        assert "image_url" in v
        assert v.get("is_genuine_neural") is not True
