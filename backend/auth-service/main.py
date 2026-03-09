"""Auth Service – main FastAPI application entry point."""

from contextlib import asynccontextmanager

from fastapi import Depends, FastAPI, HTTPException, Security, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jose import JWTError
from sqlalchemy.orm import Session

import auth as auth_utils
import schemas
from database import get_db, init_db
from models import User


@asynccontextmanager
async def lifespan(application: "FastAPI"):
    """Initialise resources on startup and release them on shutdown."""
    init_db()
    yield


app = FastAPI(
    title="PayPilot Auth Service",
    description="Handles user registration, authentication, and token management.",
    version="1.0.0",
    lifespan=lifespan,
)

security = HTTPBearer()


# ---------------------------------------------------------------------------
# Dependency helpers
# ---------------------------------------------------------------------------


def _get_current_user(
    credentials: HTTPAuthorizationCredentials = Security(security),
    db: Session = Depends(get_db),
) -> User:
    """Decode the Bearer token and return the corresponding user.

    Raises HTTP 401 if the token is invalid or the user is not found/active.
    """
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials.",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = auth_utils.decode_access_token(credentials.credentials)
        user_id: str | None = payload.get("sub")
        if user_id is None:
            raise credentials_exception
    except JWTError:
        raise credentials_exception

    user = db.query(User).filter(User.id == int(user_id)).first()
    if user is None or not user.is_active:
        raise credentials_exception
    return user


# ---------------------------------------------------------------------------
# Endpoints
# ---------------------------------------------------------------------------


@app.post(
    "/auth/register",
    response_model=schemas.UserResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Register a new user",
)
def register(payload: schemas.UserRegister, db: Session = Depends(get_db)) -> User:
    """Create a new PayPilot user account.

    Returns the newly created user record (password excluded).
    Raises HTTP 409 if the username or email is already taken.
    """
    if db.query(User).filter(User.username == payload.username).first():
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Username already registered.",
        )
    if db.query(User).filter(User.email == payload.email).first():
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Email already registered.",
        )

    user = User(
        username=payload.username,
        email=payload.email,
        hashed_password=auth_utils.hash_password(payload.password),
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


@app.post("/auth/login", response_model=schemas.TokenResponse, summary="Authenticate and obtain tokens")
def login(payload: schemas.UserLogin, db: Session = Depends(get_db)) -> schemas.TokenResponse:
    """Validate credentials and return JWT access + refresh tokens.

    Raises HTTP 401 on invalid username or password.
    """
    user = db.query(User).filter(User.username == payload.username).first()
    if user is None or not auth_utils.verify_password(payload.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid username or password.",
            headers={"WWW-Authenticate": "Bearer"},
        )
    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="User account is deactivated.",
        )

    access_token = auth_utils.create_access_token(subject=user.id)
    refresh_token = auth_utils.create_refresh_token(subject=user.id)

    user.refresh_token = refresh_token
    db.commit()

    return schemas.TokenResponse(access_token=access_token, refresh_token=refresh_token)


@app.post(
    "/auth/refresh",
    response_model=schemas.AccessTokenResponse,
    summary="Refresh access token",
)
def refresh_token(payload: schemas.TokenRefreshRequest, db: Session = Depends(get_db)) -> schemas.AccessTokenResponse:
    """Exchange a valid refresh token for a new access token.

    Raises HTTP 401 if the refresh token is invalid, expired, or revoked.
    """
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Invalid or expired refresh token.",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        token_data = auth_utils.decode_refresh_token(payload.refresh_token)
        user_id: str | None = token_data.get("sub")
        if user_id is None:
            raise credentials_exception
    except JWTError:
        raise credentials_exception

    user = db.query(User).filter(User.id == int(user_id)).first()
    if user is None or not user.is_active or user.refresh_token != payload.refresh_token:
        raise credentials_exception

    new_access_token = auth_utils.create_access_token(subject=user.id)
    return schemas.AccessTokenResponse(access_token=new_access_token)


@app.get("/auth/me", response_model=schemas.UserResponse, summary="Get current user profile")
def get_me(current_user: User = Depends(_get_current_user)) -> User:
    """Return the profile of the currently authenticated user."""
    return current_user


@app.post("/auth/logout", response_model=schemas.MessageResponse, summary="Logout current user")
def logout(
    current_user: User = Depends(_get_current_user),
    db: Session = Depends(get_db),
) -> schemas.MessageResponse:
    """Invalidate the current user's refresh token.

    Subsequent refresh attempts will be rejected until the user logs in again.
    """
    current_user.refresh_token = None
    db.commit()
    return schemas.MessageResponse(message="Successfully logged out.")


@app.get("/health", summary="Health check")
def health() -> dict:
    """Return service health status."""
    return {"status": "ok", "service": "auth-service"}
