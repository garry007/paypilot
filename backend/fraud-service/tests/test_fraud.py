"""Tests for the Fraud Detection Service scoring rules and endpoints."""

import os
import sys

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

os.environ["DATABASE_URL"] = "sqlite:///./test_fraud.db"

from database import Base, get_db  # noqa: E402
from main import app, _compute_fraud_score  # noqa: E402

TEST_DATABASE_URL = "sqlite:///./test_fraud.db"
engine = create_engine(TEST_DATABASE_URL, connect_args={"check_same_thread": False})
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


@pytest.fixture(autouse=True)
def setup_database():
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
    with TestClient(app) as c:
        yield c
    app.dependency_overrides.clear()


# ---------------------------------------------------------------------------
# Unit tests for scoring engine
# ---------------------------------------------------------------------------


class TestFraudScoringRules:
    def test_normal_transaction_low_score(self):
        score, flags = _compute_fraud_score(500.0, sender_id=1, recipient_id=2, currency="USD")
        assert score == 0.0
        assert flags == []

    def test_large_transaction_flag(self):
        score, flags = _compute_fraud_score(15_000.0, sender_id=1, recipient_id=2, currency="USD")
        assert score == pytest.approx(0.3)
        assert "large_transaction" in flags

    def test_very_large_transaction_flags(self):
        score, flags = _compute_fraud_score(60_000.0, sender_id=1, recipient_id=2, currency="USD")
        assert score == pytest.approx(0.5)
        assert "large_transaction" in flags
        assert "very_large_transaction" in flags

    def test_self_transfer_flag(self):
        score, flags = _compute_fraud_score(500.0, sender_id=5, recipient_id=5, currency="USD")
        assert score == pytest.approx(0.5)
        assert "self_transfer" in flags

    def test_unusual_currency_flag(self):
        score, flags = _compute_fraud_score(500.0, sender_id=1, recipient_id=2, currency="XYZ")
        assert score == pytest.approx(0.2)
        assert "unusual_currency" in flags

    def test_score_capped_at_one(self):
        # self_transfer (0.5) + very_large (0.5) + unusual_currency (0.2) would exceed 1.0
        score, flags = _compute_fraud_score(60_000.0, sender_id=3, recipient_id=3, currency="XYZ")
        assert score == pytest.approx(1.0)

    def test_standard_currencies_not_flagged(self):
        for currency in ["USD", "EUR", "GBP", "JPY"]:
            score, flags = _compute_fraud_score(100.0, sender_id=1, recipient_id=2, currency=currency)
            assert "unusual_currency" not in flags, f"{currency} should not be flagged"

    def test_combined_flags_medium_risk(self):
        # 0.3 (large) + 0.2 (unusual_currency) = 0.5 → medium
        score, flags = _compute_fraud_score(15_000.0, sender_id=1, recipient_id=2, currency="XYZ")
        assert score == pytest.approx(0.5)
        assert "large_transaction" in flags
        assert "unusual_currency" in flags


# ---------------------------------------------------------------------------
# API endpoint tests
# ---------------------------------------------------------------------------


class TestAnalyzeEndpoint:
    def _analyze(self, client, tx_id=1, amount=500.0, sender=1, recipient=2, currency="USD"):
        return client.post(
            "/fraud/analyze",
            json={
                "transaction_id": tx_id,
                "amount": amount,
                "sender_id": sender,
                "recipient_id": recipient,
                "currency": currency,
            },
        )

    def test_analyze_low_risk(self, client: TestClient):
        response = self._analyze(client)
        assert response.status_code == 200
        data = response.json()
        assert data["fraud_score"] == 0.0
        assert data["risk_level"] == "low"
        assert data["recommendation"] == "approve"
        assert data["flags"] == []

    def test_analyze_large_amount_flagged(self, client: TestClient):
        response = self._analyze(client, amount=15_000.0)
        assert response.status_code == 200
        data = response.json()
        assert data["risk_level"] == "medium"
        assert data["recommendation"] == "review"
        assert "large_transaction" in data["flags"]

    def test_analyze_self_transfer_high_risk(self, client: TestClient):
        # self_transfer (0.5) + large_transaction (0.3) = 0.8 → high
        response = self._analyze(client, amount=15_000.0, sender=7, recipient=7)
        assert response.status_code == 200
        data = response.json()
        assert data["risk_level"] == "high"
        assert data["recommendation"] == "reject"

    def test_analyze_upserts_alert(self, client: TestClient):
        self._analyze(client, tx_id=42, amount=500.0)
        # Second call should update, not create a duplicate
        self._analyze(client, tx_id=42, amount=500.0)
        alerts_response = client.get("/fraud/alerts/42")
        assert alerts_response.status_code == 200


class TestAlertsEndpoints:
    def test_list_alerts_empty(self, client: TestClient):
        response = client.get("/fraud/alerts")
        assert response.status_code == 200
        assert response.json() == []

    def test_list_alerts_high_risk_only(self, client: TestClient):
        # Create a high-risk alert (self_transfer 0.5 + large_transaction 0.3 = 0.8 → high)
        client.post(
            "/fraud/analyze",
            json={"transaction_id": 10, "amount": 15_000.0, "sender_id": 9, "recipient_id": 9, "currency": "USD"},
        )
        # Create a low-risk alert
        client.post(
            "/fraud/analyze",
            json={"transaction_id": 11, "amount": 100.0, "sender_id": 1, "recipient_id": 2, "currency": "USD"},
        )
        response = client.get("/fraud/alerts")
        assert response.status_code == 200
        data = response.json()
        assert len(data) == 1
        assert data[0]["transaction_id"] == 10

    def test_get_alert_not_found(self, client: TestClient):
        response = client.get("/fraud/alerts/99999")
        assert response.status_code == 404

    def test_get_specific_alert(self, client: TestClient):
        client.post(
            "/fraud/analyze",
            json={"transaction_id": 20, "amount": 500.0, "sender_id": 1, "recipient_id": 2, "currency": "USD"},
        )
        response = client.get("/fraud/alerts/20")
        assert response.status_code == 200
        assert response.json()["transaction_id"] == 20


# ---------------------------------------------------------------------------
# Risk classification boundary tests
# ---------------------------------------------------------------------------


class TestRiskClassification:
    def _score_to_risk(self, client, amount, sender, recipient, currency):
        r = client.post(
            "/fraud/analyze",
            json={
                "transaction_id": 999,
                "amount": amount,
                "sender_id": sender,
                "recipient_id": recipient,
                "currency": currency,
            },
        )
        return r.json()

    def test_boundary_low_medium(self, client: TestClient):
        # score 0.0 → low
        data = self._score_to_risk(client, 100.0, 1, 2, "USD")
        assert data["risk_level"] == "low"

    def test_boundary_medium(self, client: TestClient):
        # 0.3 (large_transaction) → medium (score < 0.7)
        data = self._score_to_risk(client, 15_000.0, 1, 2, "USD")
        assert data["risk_level"] == "medium"

    def test_boundary_high(self, client: TestClient):
        # self_transfer (0.5) + large_transaction (0.3) = 0.8 → high
        data = self._score_to_risk(client, 15_000.0, 5, 5, "USD")
        assert data["risk_level"] == "high"
