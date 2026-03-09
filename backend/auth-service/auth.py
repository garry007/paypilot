"""JWT token creation/verification and password hashing utilities for the Auth Service."""

import os
from datetime import datetime, timedelta, timezone
from typing import Any

from jose import JWTError, jwt
from passlib.context import CryptContext

SECRET_KEY: str = os.getenv("SECRET_KEY", "changeme-super-secret-key-for-jwt-auth")
ALGORITHM: str = os.getenv("ALGORITHM", "HS256")
ACCESS_TOKEN_EXPIRE_MINUTES: int = int(os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", "30"))
REFRESH_TOKEN_EXPIRE_DAYS: int = int(os.getenv("REFRESH_TOKEN_EXPIRE_DAYS", "7"))

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


# ---------------------------------------------------------------------------
# Password utilities
# ---------------------------------------------------------------------------


def hash_password(plain_password: str) -> str:
    """Return the bcrypt hash of *plain_password*."""
    return pwd_context.hash(plain_password)


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Return ``True`` if *plain_password* matches *hashed_password*."""
    return pwd_context.verify(plain_password, hashed_password)


# ---------------------------------------------------------------------------
# Token utilities
# ---------------------------------------------------------------------------


def _create_token(data: dict[str, Any], expires_delta: timedelta) -> str:
    """Encode a JWT with the given payload and expiry."""
    payload = data.copy()
    expire = datetime.now(timezone.utc) + expires_delta
    payload.update({"exp": expire, "iat": datetime.now(timezone.utc)})
    return jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)


def create_access_token(subject: str | int, extra_claims: dict[str, Any] | None = None) -> str:
    """Create a short-lived access token for *subject* (typically user id)."""
    data: dict[str, Any] = {"sub": str(subject), "type": "access"}
    if extra_claims:
        data.update(extra_claims)
    return _create_token(data, timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES))


def create_refresh_token(subject: str | int) -> str:
    """Create a long-lived refresh token for *subject*."""
    data: dict[str, Any] = {"sub": str(subject), "type": "refresh"}
    return _create_token(data, timedelta(days=REFRESH_TOKEN_EXPIRE_DAYS))


def decode_access_token(token: str) -> dict[str, Any]:
    """Decode and validate *token*, returning its payload.

    Raises ``JWTError`` if the token is invalid or expired.
    """
    payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
    if payload.get("type") != "access":
        raise JWTError("Token is not an access token.")
    return payload


def decode_refresh_token(token: str) -> dict[str, Any]:
    """Decode and validate *token* as a refresh token.

    Raises ``JWTError`` if the token is invalid or expired.
    """
    payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
    if payload.get("type") != "refresh":
        raise JWTError("Token is not a refresh token.")
    return payload
