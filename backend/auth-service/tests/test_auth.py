"""Tests for the Auth Service endpoints."""

import os
import sys

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

# Ensure service module is importable
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

os.environ["DATABASE_URL"] = "sqlite:///./test_auth.db"
os.environ["SECRET_KEY"] = "test-secret-key-for-auth-tests"

from database import Base, get_db  # noqa: E402
from main import app  # noqa: E402

TEST_DATABASE_URL = "sqlite:///./test_auth.db"
engine = create_engine(TEST_DATABASE_URL, connect_args={"check_same_thread": False})
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


@pytest.fixture(autouse=True)
def setup_database():
    """Create tables before each test and drop them after."""
    Base.metadata.create_all(bind=engine)
    yield
    Base.metadata.drop_all(bind=engine)


@pytest.fixture
def db_session():
    """Provide a transactional test database session."""
    session = TestingSessionLocal()
    try:
        yield session
    finally:
        session.close()


@pytest.fixture
def client(db_session):
    """Provide a TestClient with the test database session injected."""

    def override_get_db():
        try:
            yield db_session
        finally:
            pass

    app.dependency_overrides[get_db] = override_get_db
    with TestClient(app) as c:
        yield c
    app.dependency_overrides.clear()


# ---------------------------------------------------------------------------
# Registration tests
# ---------------------------------------------------------------------------


class TestRegister:
    def test_register_success(self, client: TestClient):
        response = client.post(
            "/auth/register",
            json={"username": "testuser", "email": "test@example.com", "password": "Password1"},
        )
        assert response.status_code == 201
        data = response.json()
        assert "access_token" in data
        assert "refresh_token" in data
        assert data["token_type"] == "bearer"
        assert data["user"]["username"] == "testuser"
        assert data["user"]["email"] == "test@example.com"
        assert "hashed_password" not in data["user"]
        assert "id" in data["user"]

    def test_register_duplicate_username(self, client: TestClient):
        payload = {"username": "dupuser", "email": "first@example.com", "password": "Password1"}
        client.post("/auth/register", json=payload)
        response = client.post(
            "/auth/register",
            json={"username": "dupuser", "email": "second@example.com", "password": "Password1"},
        )
        assert response.status_code == 409
        assert "Username" in response.json()["detail"]

    def test_register_duplicate_email(self, client: TestClient):
        client.post(
            "/auth/register",
            json={"username": "user1", "email": "shared@example.com", "password": "Password1"},
        )
        response = client.post(
            "/auth/register",
            json={"username": "user2", "email": "shared@example.com", "password": "Password1"},
        )
        assert response.status_code == 409
        assert "Email" in response.json()["detail"]

    def test_register_weak_password_no_digit(self, client: TestClient):
        response = client.post(
            "/auth/register",
            json={"username": "user3", "email": "user3@example.com", "password": "NoDigitPass"},
        )
        assert response.status_code == 422

    def test_register_short_username(self, client: TestClient):
        response = client.post(
            "/auth/register",
            json={"username": "ab", "email": "short@example.com", "password": "Password1"},
        )
        assert response.status_code == 422


# ---------------------------------------------------------------------------
# Login tests
# ---------------------------------------------------------------------------


class TestLogin:
    def _register(self, client: TestClient) -> None:
        client.post(
            "/auth/register",
            json={"username": "loginuser", "email": "login@example.com", "password": "Password1"},
        )

    def test_login_success(self, client: TestClient):
        self._register(client)
        response = client.post(
            "/auth/login",
            json={"username": "loginuser", "password": "Password1"},
        )
        assert response.status_code == 200
        data = response.json()
        assert "access_token" in data
        assert "refresh_token" in data
        assert data["token_type"] == "bearer"

    def test_login_wrong_password(self, client: TestClient):
        self._register(client)
        response = client.post(
            "/auth/login",
            json={"username": "loginuser", "password": "WrongPass1"},
        )
        assert response.status_code == 401

    def test_login_unknown_user(self, client: TestClient):
        response = client.post(
            "/auth/login",
            json={"username": "ghost", "password": "Password1"},
        )
        assert response.status_code == 401


# ---------------------------------------------------------------------------
# Token refresh tests
# ---------------------------------------------------------------------------


class TestTokenRefresh:
    def _login(self, client: TestClient) -> dict:
        client.post(
            "/auth/register",
            json={"username": "refreshuser", "email": "refresh@example.com", "password": "Password1"},
        )
        return client.post(
            "/auth/login",
            json={"username": "refreshuser", "password": "Password1"},
        ).json()

    def test_refresh_success(self, client: TestClient):
        tokens = self._login(client)
        response = client.post(
            "/auth/refresh",
            json={"refresh_token": tokens["refresh_token"]},
        )
        assert response.status_code == 200
        data = response.json()
        assert "access_token" in data

    def test_refresh_invalid_token(self, client: TestClient):
        response = client.post("/auth/refresh", json={"refresh_token": "not-a-real-token"})
        assert response.status_code == 401


# ---------------------------------------------------------------------------
# /auth/me and /auth/logout tests
# ---------------------------------------------------------------------------


class TestMeAndLogout:
    def _get_tokens(self, client: TestClient) -> dict:
        client.post(
            "/auth/register",
            json={"username": "meuser", "email": "me@example.com", "password": "Password1"},
        )
        return client.post(
            "/auth/login",
            json={"username": "meuser", "password": "Password1"},
        ).json()

    def test_get_me(self, client: TestClient):
        tokens = self._get_tokens(client)
        response = client.get(
            "/auth/me",
            headers={"Authorization": f"Bearer {tokens['access_token']}"},
        )
        assert response.status_code == 200
        assert response.json()["username"] == "meuser"

    def test_get_me_no_token(self, client: TestClient):
        response = client.get("/auth/me")
        assert response.status_code == 403

    def test_logout(self, client: TestClient):
        tokens = self._get_tokens(client)
        response = client.post(
            "/auth/logout",
            headers={"Authorization": f"Bearer {tokens['access_token']}"},
        )
        assert response.status_code == 200
        assert "logged out" in response.json()["message"].lower()

    def test_refresh_after_logout_fails(self, client: TestClient):
        tokens = self._get_tokens(client)
        client.post(
            "/auth/logout",
            headers={"Authorization": f"Bearer {tokens['access_token']}"},
        )
        response = client.post("/auth/refresh", json={"refresh_token": tokens["refresh_token"]})
        assert response.status_code == 401
