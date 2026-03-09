"""Pydantic schemas for the Transaction Service."""

from datetime import datetime
from decimal import Decimal
from typing import Literal

from pydantic import BaseModel, Field


# ---------------------------------------------------------------------------
# Request schemas
# ---------------------------------------------------------------------------


class TransactionCreate(BaseModel):
    """Payload required to create a new transaction."""

    amount: Decimal = Field(..., gt=0, decimal_places=2, description="Transaction amount (must be positive).")
    currency: str = Field("USD", min_length=3, max_length=3, description="ISO 4217 currency code.")
    recipient_id: int = Field(..., gt=0, description="ID of the recipient user.")
    description: str | None = Field(None, max_length=512, description="Optional transaction description.")


class TransactionStatusUpdate(BaseModel):
    """Payload for updating a transaction's status (admin only)."""

    status: Literal["pending", "completed", "failed", "flagged"]


# ---------------------------------------------------------------------------
# Response schemas
# ---------------------------------------------------------------------------


class TransactionResponse(BaseModel):
    """Full transaction record returned to the caller."""

    id: int
    sender_id: int
    recipient_id: int
    amount: Decimal
    currency: str
    status: str
    description: str | None
    fraud_score: float | None
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


class PaginatedTransactions(BaseModel):
    """Paginated list of transactions."""

    items: list[TransactionResponse]
    total: int
    page: int
    limit: int
    pages: int


class CurrencyStat(BaseModel):
    """Per-currency summary statistics."""

    currency: str
    total_sent: Decimal
    total_received: Decimal
    count: int


class TransactionSummary(BaseModel):
    """Aggregate statistics for the current user's transactions."""

    total_sent: Decimal
    total_received: Decimal
    transaction_count: int
    by_currency: list[CurrencyStat]
