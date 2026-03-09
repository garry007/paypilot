"""SQLAlchemy ORM models for the Fraud Detection Service."""

import json
from datetime import datetime, timezone

from sqlalchemy import DateTime, Float, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from database import Base


class FraudAlert(Base):
    """Stores the result of a fraud analysis for a specific transaction."""

    __tablename__ = "fraud_alerts"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    transaction_id: Mapped[int] = mapped_column(Integer, index=True, unique=True, nullable=False)
    fraud_score: Mapped[float] = mapped_column(Float, nullable=False)
    risk_level: Mapped[str] = mapped_column(String(16), nullable=False)
    # Stored as a JSON-serialised list of flag strings
    flags: Mapped[str] = mapped_column(Text, nullable=False, default="[]")
    recommendation: Mapped[str] = mapped_column(String(16), nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
    )

    @property
    def flags_list(self) -> list[str]:
        """Deserialise the JSON flags column into a Python list."""
        return json.loads(self.flags)

    @flags_list.setter
    def flags_list(self, value: list[str]) -> None:
        """Serialise *value* and persist it in the flags column."""
        self.flags = json.dumps(value)
