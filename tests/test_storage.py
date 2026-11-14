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


def test_get_storage_provider_local_default():
    from services.api.app.storage import get_storage_provider, LocalStorageProvider
    provider = get_storage_provider()
    assert isinstance(provider, LocalStorageProvider)


def test_s3_storage_provider_missing_dependency(monkeypatch):
    import services.api.app.storage.s3 as s3_mod
    import pytest

    monkeypatch.setattr(s3_mod, "HAS_BOTO3", False)
    monkeypatch.setattr(s3_mod, "boto3", None)

    with pytest.raises(ImportError) as exc_info:
        s3_mod.S3StorageProvider(bucket_name="test-bucket")
    assert "boto3 and botocore are required" in str(exc_info.value)


def test_s3_storage_provider_mocked_operations(monkeypatch):
    from unittest.mock import MagicMock
    import services.api.app.storage.s3 as s3_mod

    mock_client = MagicMock()
    mock_boto3 = MagicMock()
    mock_boto3.client.return_value = mock_client
    mock_client.generate_presigned_url.return_value = "https://s3.amazonaws.com/test-bucket/test.jpg?signed=true"
    mock_client.get_object.return_value = {"Body": MagicMock(read=lambda: b"mock-s3-data")}

    monkeypatch.setattr(s3_mod, "HAS_BOTO3", True)
    monkeypatch.setattr(s3_mod, "boto3", mock_boto3)

    provider = s3_mod.S3StorageProvider(
        bucket_name="test-bucket",
        endpoint_url="https://s3.amazonaws.com",
        access_key="AKIA12345",
        secret_key="SECRET12345",
        region="us-east-1",
    )

    # Upload
    ret = provider.upload_file("test.jpg", b"mock-s3-data")
    assert ret == "test.jpg"
    mock_client.put_object.assert_called_once_with(
        Bucket="test-bucket",
        Key="test.jpg",
        Body=b"mock-s3-data",
        ContentType="image/jpeg",
    )

    # Signed URL
    url = provider.get_signed_url("test.jpg", expires_in=1800)
    assert "https://s3.amazonaws.com" in url

    # Download
    data = provider.download_file("test.jpg")
    assert data == b"mock-s3-data"

    # Delete
    deleted = provider.delete_file("test.jpg")
    assert deleted is True
    mock_client.delete_object.assert_called_once_with(Bucket="test-bucket", Key="test.jpg")

