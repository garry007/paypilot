"""Shared configuration classes for PayPilot microservices."""

import os
from functools import lru_cache

from pydantic_settings import BaseSettings


class AuthServiceSettings(BaseSettings):
    """Configuration for the Auth Service."""

    app_name: str = "PayPilot Auth Service"
    debug: bool = False
    host: str = "0.0.0.0"
    port: int = 8001

    database_url: str = "sqlite:///./auth.db"

    secret_key: str = "changeme-super-secret-key-for-jwt-auth"
    algorithm: str = "HS256"
    access_token_expire_minutes: int = 30
    refresh_token_expire_days: int = 7

    class Config:
        env_file = ".env"
        extra = "ignore"


class TransactionServiceSettings(BaseSettings):
    """Configuration for the Transaction Service."""

    app_name: str = "PayPilot Transaction Service"
    debug: bool = False
    host: str = "0.0.0.0"
    port: int = 8002

    database_url: str = "sqlite:///./transactions.db"

    secret_key: str = "changeme-super-secret-key-for-jwt-auth"
    algorithm: str = "HS256"

    fraud_service_url: str = "http://fraud-service:8003"

    class Config:
        env_file = ".env"
        extra = "ignore"


class FraudServiceSettings(BaseSettings):
    """Configuration for the Fraud Detection Service."""

    app_name: str = "PayPilot Fraud Detection Service"
    debug: bool = False
    host: str = "0.0.0.0"
    port: int = 8003

    database_url: str = "sqlite:///./fraud.db"

    class Config:
        env_file = ".env"
        extra = "ignore"


class APIGatewaySettings(BaseSettings):
    """Configuration for the API Gateway."""

    app_name: str = "PayPilot API Gateway"
    debug: bool = False
    host: str = "0.0.0.0"
    port: int = 8000

    auth_service_url: str = "http://auth-service:8001"
    transaction_service_url: str = "http://transaction-service:8002"
    fraud_service_url: str = "http://fraud-service:8003"

    rate_limit_requests: int = 100
    rate_limit_window_seconds: int = 60

    cors_origins: list[str] = ["*"]

    class Config:
        env_file = ".env"
        extra = "ignore"


@lru_cache
def get_auth_settings() -> AuthServiceSettings:
    """Return cached Auth Service settings."""
    return AuthServiceSettings()


@lru_cache
def get_transaction_settings() -> TransactionServiceSettings:
    """Return cached Transaction Service settings."""
    return TransactionServiceSettings()


@lru_cache
def get_fraud_settings() -> FraudServiceSettings:
    """Return cached Fraud Service settings."""
    return FraudServiceSettings()


@lru_cache
def get_gateway_settings() -> APIGatewaySettings:
    """Return cached API Gateway settings."""
    return APIGatewaySettings()
