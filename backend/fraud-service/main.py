"""Fraud Detection Service – main FastAPI application entry point."""

import json
from contextlib import asynccontextmanager

from fastapi import Depends, FastAPI, HTTPException, status
from sqlalchemy.orm import Session

import schemas
from database import get_db, init_db
from models import FraudAlert

# Currencies considered standard; anything else raises the risk score
STANDARD_CURRENCIES: frozenset[str] = frozenset({"USD", "EUR", "GBP", "JPY"})


@asynccontextmanager
async def lifespan(application: "FastAPI"):
    """Initialise resources on startup and release them on shutdown."""
    init_db()
    yield


app = FastAPI(
    title="PayPilot Fraud Detection Service",
    description="Analyses transactions for fraud using rule-based scoring.",
    version="1.0.0",
    lifespan=lifespan,
)


# ---------------------------------------------------------------------------
# Fraud scoring engine
# ---------------------------------------------------------------------------


def _compute_fraud_score(
    amount: float,
    sender_id: int,
    recipient_id: int,
    currency: str,
) -> tuple[float, list[str]]:
    """Apply rule-based fraud scoring and return (score, flags).

    Scoring rules
    -------------
    * Amount > 10 000        → +0.3, flag "large_transaction"
    * Amount > 50 000        → +0.2 additional, flag "very_large_transaction"
    * sender == recipient    → +0.5, flag "self_transfer"
    * Unusual currency       → +0.2, flag "unusual_currency"

    The final score is clamped to [0.0, 1.0].
    """
    score: float = 0.0
    flags: list[str] = []

    if amount > 10_000:
        score += 0.3
        flags.append("large_transaction")

    if amount > 50_000:
        score += 0.2
        flags.append("very_large_transaction")

    if sender_id == recipient_id:
        score += 0.5
        flags.append("self_transfer")

    if currency.upper() not in STANDARD_CURRENCIES:
        score += 0.2
        flags.append("unusual_currency")

    score = min(score, 1.0)
    return score, flags


def _classify(score: float) -> tuple[str, str]:
    """Return (risk_level, recommendation) for the given *score*."""
    if score < 0.3:
        return "low", "approve"
    if score < 0.7:
        return "medium", "review"
    return "high", "reject"


# ---------------------------------------------------------------------------
# Endpoints
# ---------------------------------------------------------------------------


@app.post(
    "/fraud/analyze",
    response_model=schemas.FraudAnalysisResponse,
    status_code=status.HTTP_200_OK,
    summary="Analyse a transaction for fraud",
)
def analyze_transaction(
    payload: schemas.FraudAnalysisRequest,
    db: Session = Depends(get_db),
) -> schemas.FraudAnalysisResponse:
    """Run fraud scoring rules against the provided transaction data.

    Results are persisted as a ``FraudAlert`` record (upserted by transaction_id)
    and returned to the caller.
    """
    score, flags = _compute_fraud_score(
        amount=payload.amount,
        sender_id=payload.sender_id,
        recipient_id=payload.recipient_id,
        currency=payload.currency,
    )
    risk_level, recommendation = _classify(score)

    # Upsert fraud alert
    alert = db.query(FraudAlert).filter(FraudAlert.transaction_id == payload.transaction_id).first()
    if alert is None:
        alert = FraudAlert(transaction_id=payload.transaction_id)
        db.add(alert)

    alert.fraud_score = score
    alert.risk_level = risk_level
    alert.flags = json.dumps(flags)
    alert.recommendation = recommendation
    db.commit()

    return schemas.FraudAnalysisResponse(
        transaction_id=payload.transaction_id,
        fraud_score=score,
        risk_level=risk_level,
        flags=flags,
        recommendation=recommendation,
    )


@app.get(
    "/fraud/alerts",
    response_model=list[schemas.FraudAlertResponse],
    summary="List all high-risk fraud alerts",
)
def list_alerts(db: Session = Depends(get_db)) -> list[FraudAlert]:
    """Return all fraud alerts with risk level ``high``."""
    alerts = db.query(FraudAlert).filter(FraudAlert.risk_level == "high").all()
    # Deserialise JSON flags for each alert
    for alert in alerts:
        alert.flags = alert.flags_list  # type: ignore[assignment]
    return alerts


@app.get(
    "/fraud/alerts/{transaction_id}",
    response_model=schemas.FraudAlertResponse,
    summary="Get fraud analysis for a specific transaction",
)
def get_alert(transaction_id: int, db: Session = Depends(get_db)) -> FraudAlert:
    """Return the fraud alert associated with *transaction_id*.

    Raises HTTP 404 if no analysis has been performed for the transaction.
    """
    alert = db.query(FraudAlert).filter(FraudAlert.transaction_id == transaction_id).first()
    if alert is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"No fraud analysis found for transaction {transaction_id}.",
        )
    alert.flags = alert.flags_list  # type: ignore[assignment]
    return alert


@app.get("/health", summary="Health check")
def health() -> dict:
    """Return service health status."""
    return {"status": "ok", "service": "fraud-service"}
