"""SQLAlchemy ORM models for the Transaction Service."""

import enum
from datetime import datetime, timezone

from sqlalchemy import DateTime, Enum, Float, Integer, Numeric, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from database import Base


class TransactionStatus(str, enum.Enum):
    """Lifecycle states for a payment transaction."""

    pending = "pending"
    completed = "completed"
    failed = "failed"
    flagged = "flagged"


class Transaction(Base):
    """Represents a single payment transaction on the PayPilot platform."""

    __tablename__ = "transactions"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    sender_id: Mapped[int] = mapped_column(Integer, index=True, nullable=False)
    recipient_id: Mapped[int] = mapped_column(Integer, index=True, nullable=False)
    amount: Mapped[float] = mapped_column(Numeric(precision=18, scale=2), nullable=False)
    currency: Mapped[str] = mapped_column(String(3), nullable=False, default="USD")
    status: Mapped[str] = mapped_column(
        Enum(TransactionStatus),
        nullable=False,
        default=TransactionStatus.pending,
    )
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    fraud_score: Mapped[float | None] = mapped_column(Float, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
        nullable=False,
    )
