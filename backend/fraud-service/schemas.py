"""Pydantic schemas for the Fraud Detection Service."""

from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field


# ---------------------------------------------------------------------------
# Request schemas
# ---------------------------------------------------------------------------


class FraudAnalysisRequest(BaseModel):
    """Input payload for a fraud analysis request."""

    transaction_id: int = Field(..., description="ID of the transaction to analyse.")
    amount: float = Field(..., gt=0, description="Transaction amount.")
    sender_id: int = Field(..., description="ID of the sending user.")
    recipient_id: int = Field(..., description="ID of the recipient user.")
    currency: str = Field(..., min_length=3, max_length=3, description="ISO 4217 currency code.")


# ---------------------------------------------------------------------------
# Response schemas
# ---------------------------------------------------------------------------


class FraudAnalysisResponse(BaseModel):
    """Result of a fraud analysis operation."""

    transaction_id: int
    fraud_score: float = Field(..., ge=0.0, le=1.0, description="Composite fraud score (0 = safe, 1 = certain fraud).")
    risk_level: Literal["low", "medium", "high"]
    flags: list[str] = Field(default_factory=list, description="List of triggered fraud signals.")
    recommendation: Literal["approve", "review", "reject"]


class FraudAlertResponse(BaseModel):
    """Persisted fraud alert record."""

    id: int
    transaction_id: int
    fraud_score: float
    risk_level: str
    flags: list[str]
    recommendation: str
    created_at: datetime

    model_config = {"from_attributes": True}
