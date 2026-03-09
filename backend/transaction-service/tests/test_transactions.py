"""Tests for the Transaction Service endpoints."""

import os
import sys
from unittest.mock import AsyncMock, patch

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

os.environ["DATABASE_URL"] = "sqlite:///./test_transactions.db"
os.environ["SECRET_KEY"] = "test-secret-key-for-auth-tests"

from auth_middleware import AuthenticatedUser, get_current_user  # noqa: E402
from database import Base, get_db  # noqa: E402
from main import app  # noqa: E402

TEST_DATABASE_URL = "sqlite:///./test_transactions.db"
engine = create_engine(TEST_DATABASE_URL, connect_args={"check_same_thread": False})
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

MOCK_USER_ID = 1
MOCK_RECIPIENT_ID = 2


def _mock_current_user() -> AuthenticatedUser:
    return AuthenticatedUser(user_id=MOCK_USER_ID)


def _mock_admin_user() -> AuthenticatedUser:
    return AuthenticatedUser(user_id=MOCK_USER_ID, is_admin=True)


@pytest.fixture(autouse=True)
def setup_database():
    """Create tables before each test and drop them after."""
    Base.metadata.create_all(bind=engine)
    yield
    Base.metadata.drop_all(bind=engine)


@pytest.fixture
def db_session():
    session = TestingSessionLocal()
    try:
        yield session
    finally:
        session.close()


@pytest.fixture
def client(db_session):
    def override_get_db():
        try:
            yield db_session
        finally:
            pass

    app.dependency_overrides[get_db] = override_get_db
    app.dependency_overrides[get_current_user] = _mock_current_user

    with TestClient(app) as c:
        yield c

    app.dependency_overrides.clear()


@pytest.fixture
def admin_client(db_session):
    def override_get_db():
        try:
            yield db_session
        finally:
            pass

    app.dependency_overrides[get_db] = override_get_db
    app.dependency_overrides[get_current_user] = _mock_admin_user

    with TestClient(app) as c:
        yield c

    app.dependency_overrides.clear()


# ---------------------------------------------------------------------------
# Create transaction tests
# ---------------------------------------------------------------------------


class TestCreateTransaction:
    @patch("main._call_fraud_service", new_callable=AsyncMock, return_value=None)
    def test_create_success(self, _mock, client: TestClient):
        response = client.post(
            "/transactions/",
            json={"amount": "100.00", "currency": "USD", "recipient_id": MOCK_RECIPIENT_ID},
        )
        assert response.status_code == 201
        data = response.json()
        assert data["amount"] == "100.00"
        assert data["status"] == "pending"
        assert data["sender_id"] == MOCK_USER_ID
        assert data["recipient_id"] == MOCK_RECIPIENT_ID

    @patch("main._call_fraud_service", new_callable=AsyncMock, return_value=None)
    def test_create_large_transaction_flagged(self, _mock, client: TestClient):
        response = client.post(
            "/transactions/",
            json={"amount": "15000.00", "currency": "USD", "recipient_id": MOCK_RECIPIENT_ID},
        )
        assert response.status_code == 201
        assert response.json()["status"] == "flagged"

    @patch("main._call_fraud_service", new_callable=AsyncMock, return_value=0.85)
    def test_create_high_fraud_score_flagged(self, _mock, client: TestClient):
        response = client.post(
            "/transactions/",
            json={"amount": "500.00", "currency": "USD", "recipient_id": MOCK_RECIPIENT_ID},
        )
        assert response.status_code == 201
        data = response.json()
        assert data["status"] == "flagged"
        assert data["fraud_score"] == 0.85

    @patch("main._call_fraud_service", new_callable=AsyncMock, return_value=None)
    def test_create_invalid_amount(self, _mock, client: TestClient):
        response = client.post(
            "/transactions/",
            json={"amount": "-50.00", "currency": "USD", "recipient_id": MOCK_RECIPIENT_ID},
        )
        assert response.status_code == 422

    @patch("main._call_fraud_service", new_callable=AsyncMock, return_value=None)
    def test_create_with_description(self, _mock, client: TestClient):
        response = client.post(
            "/transactions/",
            json={
                "amount": "250.00",
                "currency": "EUR",
                "recipient_id": MOCK_RECIPIENT_ID,
                "description": "Invoice payment",
            },
        )
        assert response.status_code == 201
        assert response.json()["description"] == "Invoice payment"
        assert response.json()["currency"] == "EUR"


# ---------------------------------------------------------------------------
# List transactions tests
# ---------------------------------------------------------------------------


class TestListTransactions:
    def _create_tx(self, client, amount="100.00"):
        with patch("main._call_fraud_service", new_callable=AsyncMock, return_value=None):
            return client.post(
                "/transactions/",
                json={"amount": amount, "currency": "USD", "recipient_id": MOCK_RECIPIENT_ID},
            )

    def test_list_empty(self, client: TestClient):
        response = client.get("/transactions/")
        assert response.status_code == 200
        data = response.json()
        assert data["items"] == []
        assert data["total"] == 0

    def test_list_with_transactions(self, client: TestClient):
        self._create_tx(client, "100.00")
        self._create_tx(client, "200.00")
        response = client.get("/transactions/")
        assert response.status_code == 200
        data = response.json()
        assert data["total"] == 2
        assert len(data["items"]) == 2

    def test_list_pagination(self, client: TestClient):
        for i in range(5):
            self._create_tx(client, f"{(i + 1) * 100}.00")
        response = client.get("/transactions/?page=1&limit=3")
        assert response.status_code == 200
        data = response.json()
        assert len(data["items"]) == 3
        assert data["total"] == 5
        assert data["pages"] == 2


# ---------------------------------------------------------------------------
# Get specific transaction tests
# ---------------------------------------------------------------------------


class TestGetTransaction:
    @patch("main._call_fraud_service", new_callable=AsyncMock, return_value=None)
    def test_get_existing(self, _mock, client: TestClient):
        create_resp = client.post(
            "/transactions/",
            json={"amount": "300.00", "currency": "USD", "recipient_id": MOCK_RECIPIENT_ID},
        )
        tx_id = create_resp.json()["id"]
        response = client.get(f"/transactions/{tx_id}")
        assert response.status_code == 200
        assert response.json()["id"] == tx_id

    def test_get_not_found(self, client: TestClient):
        response = client.get("/transactions/99999")
        assert response.status_code == 404


# ---------------------------------------------------------------------------
# Update status tests (admin)
# ---------------------------------------------------------------------------


class TestUpdateStatus:
    @patch("main._call_fraud_service", new_callable=AsyncMock, return_value=None)
    def test_admin_update_status(self, _mock, admin_client: TestClient, db_session):
        create_resp = admin_client.post(
            "/transactions/",
            json={"amount": "500.00", "currency": "USD", "recipient_id": MOCK_RECIPIENT_ID},
        )
        tx_id = create_resp.json()["id"]
        response = admin_client.put(f"/transactions/{tx_id}/status", json={"status": "completed"})
        assert response.status_code == 200
        assert response.json()["status"] == "completed"

    @patch("main._call_fraud_service", new_callable=AsyncMock, return_value=None)
    def test_non_admin_update_status_forbidden(self, _mock, client: TestClient):
        create_resp = client.post(
            "/transactions/",
            json={"amount": "500.00", "currency": "USD", "recipient_id": MOCK_RECIPIENT_ID},
        )
        tx_id = create_resp.json()["id"]
        response = client.put(f"/transactions/{tx_id}/status", json={"status": "completed"})
        assert response.status_code == 403
