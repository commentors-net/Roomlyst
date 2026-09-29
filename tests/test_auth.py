import pytest
from fastapi.testclient import TestClient
from services.api.app.main import app

client = TestClient(app)


def test_user_registration_and_login():
    email = "tester_renovator@roomlyst.com"
    password = "StrongPassword2026!"

    # 1. Register new user
    res_reg = client.post(
        "/api/v1/auth/register",
        json={"email": email, "password": password, "role": "homeowner"},
    )
    assert res_reg.status_code == 201
    reg_data = res_reg.json()
    assert "access_token" in reg_data
    assert reg_data["email"] == email

    # 2. Duplicate registration should be rejected with 409
    res_dup = client.post(
        "/api/v1/auth/register",
        json={"email": email, "password": password},
    )
    assert res_dup.status_code == 409

    # 3. Login with correct credentials
    res_login = client.post(
        "/api/v1/auth/login",
        json={"email": email, "password": password},
    )
    assert res_login.status_code == 200
    token = res_login.json()["access_token"]

    # 4. Access authenticated profile endpoint
    headers = {"Authorization": f"Bearer {token}"}
    res_me = client.get("/api/v1/auth/me", headers=headers)
    assert res_me.status_code == 200
    me_data = res_me.json()
    assert me_data["email"] == email
    assert me_data["role"] == "homeowner"
    assert me_data["is_active"] is True


def test_auth_invalid_credentials_rejected():
    res_bad_pw = client.post(
        "/api/v1/auth/login",
        json={"email": "nonexistent@roomlyst.com", "password": "WrongPassword!"},
    )
    assert res_bad_pw.status_code == 401

    res_no_token = client.get("/api/v1/auth/me")
    assert res_no_token.status_code == 401

    res_invalid_token = client.get(
        "/api/v1/auth/me",
        headers={"Authorization": "Bearer invalid.jwt.token"},
    )
    assert res_invalid_token.status_code == 401


def test_social_login_google_and_apple():
    # 1. Google login (new user)
    google_res = client.post(
        "/api/v1/auth/social-login",
        json={
            "provider": "google",
            "email": "sarah.homeowner@gmail.com",
            "name": "Sarah Homeowner",
            "role": "homeowner",
        },
    )
    assert google_res.status_code == 200
    google_data = google_res.json()
    assert "access_token" in google_data
    assert google_data["email"] == "sarah.homeowner@gmail.com"
    assert google_data["role"] == "homeowner"

    # Verify profile access
    headers = {"Authorization": f"Bearer {google_data['access_token']}"}
    me_res = client.get("/api/v1/auth/me", headers=headers)
    assert me_res.status_code == 200
    assert me_res.json()["email"] == "sarah.homeowner@gmail.com"

    # 2. Apple login (new user)
    apple_res = client.post(
        "/api/v1/auth/social-login",
        json={
            "provider": "apple",
            "email": "designer.elena@privaterelay.appleid.com",
            "name": "Elena Vance",
            "role": "interior_designer",
        },
    )
    assert apple_res.status_code == 200
    apple_data = apple_res.json()
    assert "access_token" in apple_data
    assert apple_data["email"] == "designer.elena@privaterelay.appleid.com"

    # 3. Repeat login (existing user)
    google_repeat = client.post(
        "/api/v1/auth/social-login",
        json={
            "provider": "google",
            "email": "sarah.homeowner@gmail.com",
        },
    )
    assert google_repeat.status_code == 200
    assert google_repeat.json()["user_id"] == google_data["user_id"]

    # 4. Reject unsupported provider
    bad_provider = client.post(
        "/api/v1/auth/social-login",
        json={"provider": "unsupported_provider", "email": "test@domain.com"},
    )
    assert bad_provider.status_code == 400

