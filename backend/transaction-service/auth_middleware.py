"""JWT verification middleware for the Transaction Service.

Extracts the authenticated user from an incoming Bearer token without making
a network call to the Auth Service, by validating the shared secret locally.
"""

import os

from fastapi import Depends, HTTPException, Security, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jose import JWTError, jwt

SECRET_KEY: str = os.getenv("SECRET_KEY", "changeme-super-secret-key-for-jwt-auth")
ALGORITHM: str = os.getenv("ALGORITHM", "HS256")

security = HTTPBearer()


class AuthenticatedUser:
    """Lightweight representation of the authenticated caller."""

    __slots__ = ("id", "is_admin")

    def __init__(self, user_id: int, is_admin: bool = False) -> None:
        self.id = user_id
        self.is_admin = is_admin


def get_current_user(
    credentials: HTTPAuthorizationCredentials = Security(security),
) -> AuthenticatedUser:
    """Validate the Bearer token and return the caller's identity.

    Raises HTTP 401 if the token is missing, invalid, or expired.
    """
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials.",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(credentials.credentials, SECRET_KEY, algorithms=[ALGORITHM])
        if payload.get("type") != "access":
            raise credentials_exception
        user_id_str: str | None = payload.get("sub")
        if user_id_str is None:
            raise credentials_exception
    except JWTError:
        raise credentials_exception

    return AuthenticatedUser(
        user_id=int(user_id_str),
        is_admin=payload.get("is_admin", False),
    )
