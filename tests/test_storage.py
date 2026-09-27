import os
from fastapi.testclient import TestClient
from services.api.app.main import app
from services.api.app.storage.local import LocalStorageProvider

client = TestClient(app)


def test_local_storage_provider_lifecycle(tmp_path):
    storage = LocalStorageProvider(base_dir=str(tmp_path), secret_key="test-secret")
    test_key = "rooms/test_room/photo.jpg"
    test_bytes = b"fake-jpg-binary-content-12345"

    # Upload
    ret_key = storage.upload_file(test_key, test_bytes)
    assert ret_key == test_key

    # Signed URL contains expiry and signature
    signed_url = storage.get_signed_url(test_key, expires_in=1800)
    assert "/storage/" in signed_url
    assert "sig=" in signed_url
    assert "exp=" in signed_url

    # Download
    downloaded = storage.download_file(test_key)
    assert downloaded == test_bytes

    # Delete
    deleted = storage.delete_file(test_key)
    assert deleted is True


def test_media_signed_url_endpoints():
    # 1. Register & login to get token
    email = "storage_tester@roomlyst.com"
    client.post("/api/v1/auth/register", json={"email": email, "password": "Password123!"})
    res_login = client.post("/api/v1/auth/login", json={"email": email, "password": "Password123!"})
    token = res_login.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    # 2. Create room first via DB
    from services.api.app.db.session import SessionLocal
    from services.api.app.db.models import Room, Project, User
    with SessionLocal() as db:
        user = db.query(User).filter(User.email == email).first()
        proj = Project(name="Storage Test Project", user_id=user.id)
        db.add(proj)
        db.commit()
        room = Room(id="room_storage_01", project_id=proj.id, name="Media Room")
        db.add(room)
        db.commit()

    # 3. Request signed upload URL
    res_up = client.post(
        "/api/v1/media/signed-upload-url",
        headers=headers,
        json={"room_id": "room_storage_01", "file_name": "living.jpg", "content_type": "image/jpeg"},
    )
    assert res_up.status_code == 200
    up_data = res_up.json()
    assert "signed_upload_url" in up_data
    asset_id = up_data["asset_id"]

    # 4. Request signed download URL for private asset
    res_down = client.get(
        f"/api/v1/media/{asset_id}/signed-url",
        headers=headers,
    )
    assert res_down.status_code == 200
    assert "signed_url" in res_down.json()
