"""Transaction Service – main FastAPI application entry point."""

import math
import os
from contextlib import asynccontextmanager
from decimal import Decimal

import httpx
from fastapi import Depends, FastAPI, HTTPException, Query, status
from sqlalchemy import func
from sqlalchemy.orm import Session

import schemas
from auth_middleware import AuthenticatedUser, get_current_user
from database import get_db, init_db
from models import Transaction, TransactionStatus

FRAUD_SERVICE_URL: str = os.getenv("FRAUD_SERVICE_URL", "http://fraud-service:8003")
LARGE_TRANSACTION_THRESHOLD: float = 10_000.0


@asynccontextmanager
async def lifespan(application: "FastAPI"):
    """Initialise resources on startup and release them on shutdown."""
    init_db()
    yield


app = FastAPI(
    title="PayPilot Transaction Service",
    description="Manages payment transactions and coordinates with the Fraud Detection Service.",
    version="1.0.0",
    lifespan=lifespan,
)


# ---------------------------------------------------------------------------
# Helper: call fraud service
# ---------------------------------------------------------------------------


async def _call_fraud_service(transaction: Transaction) -> float | None:
    """Send the transaction to the Fraud Detection Service and return the fraud score.

    Returns ``None`` if the service is unreachable (fail-open strategy).
    """
    payload = {
        "transaction_id": transaction.id,
        "amount": float(transaction.amount),
        "sender_id": transaction.sender_id,
        "recipient_id": transaction.recipient_id,
        "currency": transaction.currency,
    }
    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            response = await client.post(f"{FRAUD_SERVICE_URL}/fraud/analyze", json=payload)
            response.raise_for_status()
            return response.json().get("fraud_score")
    except Exception:
        return None


# ---------------------------------------------------------------------------
# Endpoints
# ---------------------------------------------------------------------------


@app.post(
    "/transactions/",
    response_model=schemas.TransactionResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create a new transaction",
)
async def create_transaction(
    payload: schemas.TransactionCreate,
    current_user: AuthenticatedUser = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> Transaction:
    """Submit a new payment transaction.

    The transaction is created with ``pending`` status.  If the amount exceeds
    $10,000 it is immediately marked as ``flagged``.  The fraud service is
    consulted asynchronously and the returned score stored on the record.
    """
    amount_float = float(payload.amount)
    initial_status = (
        TransactionStatus.flagged if amount_float > LARGE_TRANSACTION_THRESHOLD else TransactionStatus.pending
    )

    transaction = Transaction(
        sender_id=current_user.id,
        recipient_id=payload.recipient_id,
        amount=payload.amount,
        currency=payload.currency.upper(),
        status=initial_status,
        description=payload.description,
    )
    db.add(transaction)
    db.commit()
    db.refresh(transaction)

    # Consult fraud service – update score if available
    fraud_score = await _call_fraud_service(transaction)
    if fraud_score is not None:
        transaction.fraud_score = fraud_score
        # Escalate to flagged if high fraud score regardless of amount
        if fraud_score >= 0.7 and transaction.status == TransactionStatus.pending:
            transaction.status = TransactionStatus.flagged
        db.commit()
        db.refresh(transaction)

    return transaction


@app.get(
    "/transactions/stats/summary",
    response_model=schemas.TransactionSummary,
    summary="Get transaction statistics for the current user",
)
def get_stats(
    current_user: AuthenticatedUser = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> schemas.TransactionSummary:
    """Return aggregate sent/received totals and per-currency breakdown."""
    sent_rows = (
        db.query(
            Transaction.currency,
            func.sum(Transaction.amount).label("total"),
            func.count(Transaction.id).label("count"),
        )
        .filter(Transaction.sender_id == current_user.id)
        .group_by(Transaction.currency)
        .all()
    )
    received_rows = (
        db.query(
            Transaction.currency,
            func.sum(Transaction.amount).label("total"),
        )
        .filter(Transaction.recipient_id == current_user.id)
        .group_by(Transaction.currency)
        .all()
    )

    received_by_currency: dict[str, Decimal] = {row.currency: Decimal(str(row.total)) for row in received_rows}

    total_sent = Decimal("0")
    total_received = Decimal("0")
    by_currency: list[schemas.CurrencyStat] = []

    for row in sent_rows:
        sent_amt = Decimal(str(row.total))
        recv_amt = received_by_currency.get(row.currency, Decimal("0"))
        total_sent += sent_amt
        total_received += recv_amt
        by_currency.append(
            schemas.CurrencyStat(
                currency=row.currency,
                total_sent=sent_amt,
                total_received=recv_amt,
                count=row.count,
            )
        )

    # Add currencies where user only received
    sent_currencies = {row.currency for row in sent_rows}
    for currency, recv_amt in received_by_currency.items():
        if currency not in sent_currencies:
            total_received += recv_amt
            by_currency.append(
                schemas.CurrencyStat(
                    currency=currency,
                    total_sent=Decimal("0"),
                    total_received=recv_amt,
                    count=0,
                )
            )

    transaction_count = db.query(func.count(Transaction.id)).filter(
        (Transaction.sender_id == current_user.id) | (Transaction.recipient_id == current_user.id)
    ).scalar() or 0

    return schemas.TransactionSummary(
        total_sent=total_sent,
        total_received=total_received,
        transaction_count=transaction_count,
        by_currency=by_currency,
    )


@app.get(
    "/transactions/",
    response_model=schemas.PaginatedTransactions,
    summary="List transactions for the current user",
)
def list_transactions(
    page: int = Query(1, ge=1, description="Page number (1-indexed)."),
    limit: int = Query(20, ge=1, le=100, description="Records per page."),
    current_user: AuthenticatedUser = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> schemas.PaginatedTransactions:
    """Return a paginated list of transactions where the user is sender or recipient."""
    base_query = db.query(Transaction).filter(
        (Transaction.sender_id == current_user.id) | (Transaction.recipient_id == current_user.id)
    )
    total = base_query.count()
    items = (
        base_query.order_by(Transaction.created_at.desc())
        .offset((page - 1) * limit)
        .limit(limit)
        .all()
    )
    return schemas.PaginatedTransactions(
        items=items,
        total=total,
        page=page,
        limit=limit,
        pages=math.ceil(total / limit) if total else 1,
    )


@app.get(
    "/transactions/{transaction_id}",
    response_model=schemas.TransactionResponse,
    summary="Get a specific transaction",
)
def get_transaction(
    transaction_id: int,
    current_user: AuthenticatedUser = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> Transaction:
    """Return a single transaction by ID.

    The caller must be the sender or recipient; otherwise HTTP 403 is raised.
    """
    transaction = db.query(Transaction).filter(Transaction.id == transaction_id).first()
    if transaction is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Transaction not found.")
    if transaction.sender_id != current_user.id and transaction.recipient_id != current_user.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Access denied.")
    return transaction


@app.put(
    "/transactions/{transaction_id}/status",
    response_model=schemas.TransactionResponse,
    summary="Update transaction status (admin only)",
)
def update_status(
    transaction_id: int,
    payload: schemas.TransactionStatusUpdate,
    current_user: AuthenticatedUser = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> Transaction:
    """Allow an admin to manually override a transaction's status."""
    if not current_user.is_admin:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Admin access required.")

    transaction = db.query(Transaction).filter(Transaction.id == transaction_id).first()
    if transaction is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Transaction not found.")

    transaction.status = TransactionStatus(payload.status)
    db.commit()
    db.refresh(transaction)
    return transaction


@app.get("/health", summary="Health check")
def health() -> dict:
    """Return service health status."""
    return {"status": "ok", "service": "transaction-service"}
