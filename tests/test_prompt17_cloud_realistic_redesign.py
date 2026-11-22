"""
Tests for Prompt 17: Cloud-First Realistic Room Redesign (Keep Local AI).
Validates:
1. Replicate inpainting adapter variant prompt compilation & seed diversity:
   - Distinct room-aware prompts for Concept A, B, and C.
   - Explicit movable clutter removal clause for 'Empty & Redesign'.
   - Structural preservation clauses for fixed walls, windows, and openings.
2. Replicate official schema validation & live cost estimation (~$0.0031/image).
3. Resilient partial success handling (returning successful variants on partial failure).
4. Project rooms hydration & variant signed URL refresh preventing blank images.
5. Local AI track preservation and fail-closed behavior.
6. Zero-spend enforcement and fail-closed behavior when cloud inference is unauthorized.
"""

import io
import os
import pytest
from PIL import Image
from unittest.mock import MagicMock
from fastapi.testclient import TestClient

from services.api.app.main import app
from services.ai_worker.pipelines.inpainting import (
    ReplicateInpaintingAdapter,
    LocalDiffusionInpaintingAdapter,
    InpaintingRequest,
    InpaintingResponse,
    InpaintingOutputVariant,
    ProviderUnconfiguredException,
    run_inpainting_pipeline,
)
from services.api.app.db.repository import repository
from packages.room_model.schema import CanonicalRoomModel, DesignConstraint, DesignVariant, DesignVersion

client = TestClient(app)


def create_synthetic_image(width=512, height=512, color=(170, 180, 190)) -> bytes:
    img = Image.new("RGB", (width, height), color=color)
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    return buf.getvalue()


def create_synthetic_mask(width=512, height=512) -> bytes:
    mask = Image.new("L", (width, height), color=0)
    for x in range(120, 390):
        for y in range(120, 390):
            mask.putpixel((x, y), 255)
    buf = io.BytesIO()
    mask.save(buf, format="PNG")
    return buf.getvalue()


def test_replicate_adapter_variant_prompt_compilation_and_seed_diversity():
    """Verifies that Concept A, B, and C receive distinct room arrangements and seeds."""
    adapter = ReplicateInpaintingAdapter(api_token="test_token_placeholder")

    req = InpaintingRequest(
        image_bytes=create_synthetic_image(512, 512),
        mask_bytes=create_synthetic_mask(512, 512),
        width=512,
        height=512,
        room_id="rm_test_prompt17",
        prompt="Empty & Redesign",
        style="Empty & Redesign",
        num_variants=3,
        seed=12345,
    )

    prompt_a = adapter._compile_variant_prompt(req, 0)
    prompt_b = adapter._compile_variant_prompt(req, 1)
    prompt_c = adapter._compile_variant_prompt(req, 2)

    # 1. Distinct prompts per concept
    assert "Concept A" in prompt_a
    assert "Concept B" in prompt_b
    assert "Concept C" in prompt_c
    assert prompt_a != prompt_b
    assert prompt_b != prompt_c

    # 2. Clutter removal clause for Empty & Redesign
    assert "Completely remove all existing movable clutter" in prompt_a
    assert "Completely remove all existing movable clutter" in prompt_b
    assert "Completely remove all existing movable clutter" in prompt_c

    # 3. Structural preservation clause
    assert "Strictly preserving fixed structural load-bearing walls" in prompt_a
    assert "window frames, door openings" in prompt_a

    # 4. Payload builds with distinct seeds and prompts
    payload_0 = adapter._build_replicate_payload(req, 0)
    payload_1 = adapter._build_replicate_payload(req, 1)
    payload_2 = adapter._build_replicate_payload(req, 2)

    assert payload_0["input"]["seed"] != payload_1["input"]["seed"]
    assert payload_1["input"]["seed"] != payload_2["input"]["seed"]
    assert payload_0["input"]["prompt"] == prompt_a
    assert payload_1["input"]["prompt"] == prompt_b


def test_replicate_adapter_dry_run_schema_and_cost():
    """Verifies official Replicate model schema compliance and updated live pricing."""
    adapter = ReplicateInpaintingAdapter(api_token="test_mock_token")

    req = InpaintingRequest(
        image_bytes=create_synthetic_image(512, 512),
        mask_bytes=create_synthetic_mask(512, 512),
        width=512,
        height=512,
        room_id="rm_test_p17_dry",
        prompt="Home Office",
        style="Home Office",
        num_variants=3,
    )

    dry = adapter.dry_run(req)
    assert dry["status"] == "VALID"
    assert dry["provider_name"] == "replicate-sd-inpainting"
    assert dry["model"] == "stability-ai/stable-diffusion-inpainting"
    assert dry["num_variants"] == 3
    # Verified live pricing: ~$0.0031 / image -> 3 images = ~$0.0093
    assert dry["cost_per_image_usd"] == 0.0031
    assert dry["estimated_cost_usd"] == 0.0093
    assert len(dry["variant_prompts"]) == 3
    assert "Concept A" in dry["variant_prompts"][0]
    assert "Concept B" in dry["variant_prompts"][1]
    assert "Concept C" in dry["variant_prompts"][2]


def test_replicate_adapter_partial_success_resilience():
    """Tests that partial generation failure returns available successful variants instead of losing work."""
    mock_session = MagicMock()

    # Mock response helper: calls 0 & 1 succeed, call 2 raises error
    call_count = [0]
    def mock_post(url, **kwargs):
        resp = MagicMock()
        if call_count[0] < 2:
            resp.status_code = 201
            resp.json.return_value = {"id": f"pred_{call_count[0]}", "status": "succeeded", "output": ["https://replicate.delivery/pbxt/test.jpg"]}
        else:
            resp.status_code = 500
            resp.text = "Internal Replicate Server Error"
        call_count[0] += 1
        return resp

    mock_session.post.side_effect = mock_post
    mock_session.get.return_value.status_code = 200
    mock_session.get.return_value.json.return_value = {"status": "succeeded", "output": ["https://replicate.delivery/pbxt/test.jpg"]}

    # Mock safe image downloader to return synthetic bytes
    synthetic_jpg = create_synthetic_image(512, 512)
    with pytest.MonkeyPatch.context() as mp:
        mp.setattr("services.ai_worker.pipelines.inpainting.download_safe_provider_image", lambda **kw: synthetic_jpg)
        adapter = ReplicateInpaintingAdapter(api_token="test_token_active", http_client=mock_session)

        req = InpaintingRequest(
            image_bytes=synthetic_jpg,
            mask_bytes=create_synthetic_mask(512, 512),
            width=512,
            height=512,
            room_id="rm_test_partial",
            prompt="Cozy Lounge",
            style="Cozy Lounge",
            num_variants=3,
        )

        resp = adapter.inpaint(req)
        assert resp.status == "PARTIAL_SUCCESS"
        assert len(resp.variants) == 2
        assert resp.variants[0].variant_index == 0
        assert resp.variants[1].variant_index == 1
        assert resp.total_cost_usd > 0


def test_signed_url_refresh_across_project_reloads():
    """Verifies that get_project refreshes variant signed URLs to prevent expired-link blank images."""
    from services.api.app.api.v1.endpoints import get_project
    from services.api.app.core.dependencies import AuthContext

    # 1. Create a project in repository
    proj = repository.create_project(name="Signed URL Refresh Project", user_id="usr_demo")

    # 2. Create room with a version and variant containing un-signed / expired output path
    room = CanonicalRoomModel(
        name="Living Room",
        project_id=proj.id,
        original_image_url="http://localhost:8081/storage/uploads/test_orig.jpg",
    )
    version = DesignVersion(
        room_id=room.id,
        version_number=1,
        constraints=DesignConstraint(),
        variants=[
            DesignVariant(
                title="Concept A: Warm Modern Minimalist",
                style="Warm Modern Minimalist",
                image_url="http://localhost:8081/storage/outputs/concept_abc_v1.jpg",
                description="Algorithmic Concept Preview",
                structural_preservation_score=0.95,
                changes_made=["Wall wash"],
                estimated_cost=4800.0,
            ),
            DesignVariant(
                title="Concept B: Japandi Clean Organic",
                style="Japandi Clean Organic",
                image_url="http://localhost:8081/storage/outputs/concept_abc_v2.jpg",
                description="Algorithmic Concept Preview",
                structural_preservation_score=0.93,
                changes_made=["Floor refresh"],
                estimated_cost=6200.0,
            ),
            DesignVariant(
                title="Concept C: Contemporary Scandinavian",
                style="Contemporary Scandinavian",
                image_url="http://localhost:8081/storage/outputs/concept_abc_v3.jpg",
                description="Algorithmic Concept Preview",
                structural_preservation_score=0.92,
                changes_made=["Lighting update"],
                estimated_cost=5500.0,
            ),
        ],
    )
    room.versions.append(version)
    repository.save_room(room)

    # 3. Call get_project directly
    auth = AuthContext(user_id="usr_demo", role="user", is_authenticated=True, is_guest=False)
    mock_db = MagicMock()
    mock_db.query.return_value.filter.return_value.first.return_value = None
    mock_db.query.return_value.filter.return_value.all.return_value = []
    proj_data = get_project(project_id=proj.id, auth=auth, db=mock_db)

    # 4. Verify rooms and variants contain signed URLs with sig and exp
    assert len(proj_data.rooms) > 0
    room_obj = proj_data.rooms[0]
    assert len(room_obj.versions) > 0
    variants = room_obj.versions[0].variants
    assert len(variants) == 3
    for v in variants:
        assert "sig=" in v.image_url
        assert "exp=" in v.image_url


def test_local_ai_fail_closed_preserved():
    """Verifies that Local AI track remains available and fails closed when worker is offline."""
    adapter = LocalDiffusionInpaintingAdapter(endpoint_url="http://127.0.0.1:59999")
    is_avail, reason = adapter.is_available()
    assert is_avail is False
    assert "Local diffusion service is not running" in reason
    assert "llmserver" in reason


def test_cloud_ai_fail_closed_when_unauthorized_with_zero_spend():
    """Verifies that Cloud AI fails closed with HTTP 503 PROVIDER_UNCONFIGURED when token is unset ($0 spend gate)."""
    from services.api.app.api.v1.endpoints import generate_room_design, GenerateRedesignRequest
    from services.api.app.core.dependencies import AuthContext
    from fastapi import HTTPException

    prev_tok = os.environ.get("REPLICATE_API_TOKEN")
    prev_mock = os.environ.get("TEST_MOCK_DIFFUSION")
    if "REPLICATE_API_TOKEN" in os.environ:
        del os.environ["REPLICATE_API_TOKEN"]
    if "TEST_MOCK_DIFFUSION" in os.environ:
        del os.environ["TEST_MOCK_DIFFUSION"]

    try:
        # Create a room in repository
        room = CanonicalRoomModel(name="Zero Spend Room", project_id="proj_zero")
        repository.save_room(room)

        req = GenerateRedesignRequest(styles=["Empty & Redesign"], generation_mode="cloud_ai")
        auth = AuthContext(user_id="usr_demo", role="user", is_authenticated=True, is_guest=False)

        mock_db = MagicMock()
        mock_db.query.return_value.filter.return_value.first.return_value = None

        with pytest.raises(HTTPException) as exc_info:
            generate_room_design(room_id=room.id, req=req, auth=auth, db=mock_db)

        assert exc_info.value.status_code == 503
        detail = exc_info.value.detail
        assert detail["error_code"] == "PROVIDER_UNCONFIGURED"
        assert detail["provider_mode"] == "cloud_ai"
        assert detail["suggested_mode"] == "algorithmic_preview"
    finally:
        if prev_tok is not None:
            os.environ["REPLICATE_API_TOKEN"] = prev_tok
        if prev_mock is not None:
            os.environ["TEST_MOCK_DIFFUSION"] = prev_mock
