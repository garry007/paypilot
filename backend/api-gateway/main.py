"""API Gateway – main FastAPI application entry point.

Acts as a reverse-proxy / aggregator in front of the PayPilot microservices.
All public traffic enters through this service on port 8000.
"""

import os
import time
from collections import defaultdict
from typing import Any

import httpx
from fastapi import FastAPI, HTTPException, Request, Response, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

AUTH_SERVICE_URL: str = os.getenv("AUTH_SERVICE_URL", "http://auth-service:8001")
TRANSACTION_SERVICE_URL: str = os.getenv("TRANSACTION_SERVICE_URL", "http://transaction-service:8002")
FRAUD_SERVICE_URL: str = os.getenv("FRAUD_SERVICE_URL", "http://fraud-service:8003")

RATE_LIMIT_REQUESTS: int = int(os.getenv("RATE_LIMIT_REQUESTS", "100"))
RATE_LIMIT_WINDOW: int = int(os.getenv("RATE_LIMIT_WINDOW_SECONDS", "60"))

app = FastAPI(
    title="PayPilot API Gateway",
    description="Single entry point for all PayPilot microservices.",
    version="1.0.0",
)

# ---------------------------------------------------------------------------
# CORS
# ---------------------------------------------------------------------------

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ---------------------------------------------------------------------------
# In-memory rate limiter
# ---------------------------------------------------------------------------

# Structure: { ip: [(timestamp, count), ...] }
_rate_limit_store: dict[str, list[float]] = defaultdict(list)


def _check_rate_limit(client_ip: str) -> None:
    """Raise HTTP 429 if the client exceeds the configured request quota.

    Uses a sliding-window counter keyed on the client IP address.
    """
    now = time.monotonic()
    window_start = now - RATE_LIMIT_WINDOW

    timestamps = _rate_limit_store[client_ip]
    # Evict timestamps outside the current window
    timestamps[:] = [t for t in timestamps if t >= window_start]

    if len(timestamps) >= RATE_LIMIT_REQUESTS:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail=f"Rate limit exceeded. Maximum {RATE_LIMIT_REQUESTS} requests per {RATE_LIMIT_WINDOW} seconds.",
        )
    timestamps.append(now)


@app.middleware("http")
async def rate_limit_middleware(request: Request, call_next):
    """Apply rate limiting to every incoming request."""
    client_ip = request.client.host if request.client else "unknown"
    try:
        _check_rate_limit(client_ip)
    except HTTPException as exc:
        return JSONResponse(status_code=exc.status_code, content={"detail": exc.detail})
    return await call_next(request)


# ---------------------------------------------------------------------------
# Proxy helper
# ---------------------------------------------------------------------------


async def _proxy(
    request: Request,
    target_url: str,
    *,
    forward_auth: bool = False,
) -> Response:
    """Forward the incoming *request* to *target_url* and stream back the response.

    Args:
        request: The original FastAPI ``Request`` object.
        target_url: Fully-qualified upstream URL to forward to.
        forward_auth: When ``True``, the ``Authorization`` header is included.
    """
    headers: dict[str, str] = {}
    if forward_auth:
        auth_header = request.headers.get("Authorization")
        if auth_header:
            headers["Authorization"] = auth_header

    content_type = request.headers.get("content-type")
    if content_type:
        headers["content-type"] = content_type

    body = await request.body()

    try:
        async with httpx.AsyncClient(timeout=30.0) as client:
            upstream_response = await client.request(
                method=request.method,
                url=target_url,
                headers=headers,
                content=body,
                params=dict(request.query_params),
            )
    except httpx.ConnectError:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=f"Upstream service unavailable: {target_url}",
        )
    except httpx.TimeoutException:
        raise HTTPException(
            status_code=status.HTTP_504_GATEWAY_TIMEOUT,
            detail=f"Upstream service timed out: {target_url}",
        )

    return Response(
        content=upstream_response.content,
        status_code=upstream_response.status_code,
        headers=dict(upstream_response.headers),
        media_type=upstream_response.headers.get("content-type"),
    )


# ---------------------------------------------------------------------------
# Auth routes
# ---------------------------------------------------------------------------


@app.post("/api/v1/auth/register", tags=["Auth"], summary="Register a new user")
async def proxy_register(request: Request) -> Response:
    """Forward registration request to the Auth Service."""
    return await _proxy(request, f"{AUTH_SERVICE_URL}/auth/register")


@app.post("/api/v1/auth/login", tags=["Auth"], summary="Authenticate and obtain tokens")
async def proxy_login(request: Request) -> Response:
    """Forward login request to the Auth Service."""
    return await _proxy(request, f"{AUTH_SERVICE_URL}/auth/login")


@app.post("/api/v1/auth/refresh", tags=["Auth"], summary="Refresh access token")
async def proxy_refresh(request: Request) -> Response:
    """Forward token refresh request to the Auth Service."""
    return await _proxy(request, f"{AUTH_SERVICE_URL}/auth/refresh")


@app.get("/api/v1/auth/me", tags=["Auth"], summary="Get current user profile")
async def proxy_me(request: Request) -> Response:
    """Forward profile request to the Auth Service (includes Authorization header)."""
    return await _proxy(request, f"{AUTH_SERVICE_URL}/auth/me", forward_auth=True)


@app.post("/api/v1/auth/logout", tags=["Auth"], summary="Logout current user")
async def proxy_logout(request: Request) -> Response:
    """Forward logout request to the Auth Service."""
    return await _proxy(request, f"{AUTH_SERVICE_URL}/auth/logout", forward_auth=True)


# ---------------------------------------------------------------------------
# Transaction routes
# ---------------------------------------------------------------------------


@app.post("/api/v1/transactions/", tags=["Transactions"], summary="Create a new transaction")
async def proxy_create_transaction(request: Request) -> Response:
    """Forward transaction creation to the Transaction Service."""
    return await _proxy(request, f"{TRANSACTION_SERVICE_URL}/transactions/", forward_auth=True)


@app.get("/api/v1/transactions/stats/summary", tags=["Transactions"], summary="Get transaction stats")
async def proxy_transaction_stats(request: Request) -> Response:
    """Forward stats request to the Transaction Service.

    This route must be declared before the ``{transaction_id}`` route to avoid
    the literal string ``stats`` being matched as a transaction ID.
    """
    return await _proxy(request, f"{TRANSACTION_SERVICE_URL}/transactions/stats/summary", forward_auth=True)


@app.get("/api/v1/transactions/", tags=["Transactions"], summary="List transactions")
async def proxy_list_transactions(request: Request) -> Response:
    """Forward list request to the Transaction Service."""
    return await _proxy(request, f"{TRANSACTION_SERVICE_URL}/transactions/", forward_auth=True)


@app.get("/api/v1/transactions/{transaction_id}", tags=["Transactions"], summary="Get a specific transaction")
async def proxy_get_transaction(transaction_id: int, request: Request) -> Response:
    """Forward get-by-id request to the Transaction Service."""
    return await _proxy(
        request,
        f"{TRANSACTION_SERVICE_URL}/transactions/{transaction_id}",
        forward_auth=True,
    )


# ---------------------------------------------------------------------------
# Fraud routes
# ---------------------------------------------------------------------------


@app.post("/api/v1/fraud/analyze", tags=["Fraud"], summary="Analyse a transaction for fraud")
async def proxy_fraud_analyze(request: Request) -> Response:
    """Forward fraud analysis request to the Fraud Detection Service."""
    return await _proxy(request, f"{FRAUD_SERVICE_URL}/fraud/analyze")


@app.get("/api/v1/fraud/alerts", tags=["Fraud"], summary="List high-risk fraud alerts")
async def proxy_fraud_alerts(request: Request) -> Response:
    """Forward fraud alerts list request to the Fraud Detection Service."""
    return await _proxy(request, f"{FRAUD_SERVICE_URL}/fraud/alerts")


# ---------------------------------------------------------------------------
# Health check
# ---------------------------------------------------------------------------


@app.get("/health", tags=["Health"], summary="Gateway and upstream service health")
async def health_check() -> dict[str, Any]:
    """Check the health of the gateway and all upstream services.

    Returns a combined status document with per-service availability.
    """
    service_urls: dict[str, str] = {
        "auth-service": f"{AUTH_SERVICE_URL}/health",
        "transaction-service": f"{TRANSACTION_SERVICE_URL}/health",
        "fraud-service": f"{FRAUD_SERVICE_URL}/health",
    }

    services: dict[str, Any] = {}
    overall_ok = True

    async with httpx.AsyncClient(timeout=5.0) as client:
        for name, url in service_urls.items():
            try:
                resp = await client.get(url)
                services[name] = {"status": "ok" if resp.status_code == 200 else "degraded"}
                if resp.status_code != 200:
                    overall_ok = False
            except Exception:
                services[name] = {"status": "unavailable"}
                overall_ok = False

    return {
        "status": "ok" if overall_ok else "degraded",
        "services": services,
    }
