# PayPilot Architecture

## System Overview

```
                        ┌─────────────────────────────────────────────────┐
                        │                  iOS App (SwiftUI)               │
                        │          MVVM + Combine + URLSession             │
                        └──────────────────────┬──────────────────────────┘
                                               │ HTTPS
                        ┌──────────────────────▼──────────────────────────┐
                        │              API Gateway  :8000                  │
                        │   Reverse proxy & request aggregator (FastAPI)   │
                        └────────┬──────────────┬──────────────┬──────────┘
                                 │              │              │
               ┌─────────────────▼──┐  ┌────────▼─────────┐  ┌▼────────────────┐
               │  Auth Service :8001 │  │Transaction :8002  │  │Fraud Svc  :8003 │
               │  JWT auth / users   │  │Payments & history │  │Scoring & alerts │
               │  (FastAPI + SQLAlch)│  │(FastAPI + SQLAlch)│  │(FastAPI + SQLAlch│
               └─────────┬───────────┘  └────────┬──────────┘  └────────┬────────┘
                         │                        │                       │
                         └────────────┬───────────┘                       │
                                      │                                    │
                        ┌─────────────▼────────────────────────────────────▼──────┐
                        │                 PostgreSQL  :5432                         │
                        │           Single shared database (paypilot)               │
                        └───────────────────────────────────────────────────────────┘

                        ┌──────────────────────────────────────────────────────────┐
                        │                  Redis  :6379                             │
                        │      (available for caching / session storage)            │
                        └──────────────────────────────────────────────────────────┘
```

---

## Services

### API Gateway (port 8000)

**Technology:** Python 3.11, FastAPI, httpx  
**Role:** Single entry point for all client requests.

- Proxies requests to the correct upstream service based on URL prefix (`/api/v1/auth/*`, `/api/v1/transactions/*`, `/api/v1/fraud/*`).
- Streams upstream responses directly to the client with no transformation.
- Aggregates upstream health checks into a unified `GET /health` response.
- Adds `X-Request-ID` headers for distributed tracing.

---

### Auth Service (port 8001)

**Technology:** Python 3.11, FastAPI, SQLAlchemy, python-jose, passlib  
**Role:** User identity, authentication, and authorisation.

- Stores user accounts in PostgreSQL (`users` table).
- Hashes passwords with bcrypt via passlib.
- Issues short-lived JWT **access tokens** (15 minutes) and long-lived **refresh tokens** (7 days).
- Refresh tokens are stored in the database; logout invalidates them immediately.
- Other services validate tokens by calling `GET /auth/me` or by verifying the JWT signature directly.

---

### Transaction Service (port 8002)

**Technology:** Python 3.11, FastAPI, SQLAlchemy, httpx  
**Role:** Payment processing and transaction history.

- Persists transactions in PostgreSQL (`transactions` table).
- Authenticates requests by forwarding the `Authorization` header to the auth service.
- Automatically calls the fraud service on every new transaction.
- Flags transactions with `amount > $10,000` or `fraud_score >= 0.7`.
- Supports pagination, per-user statistics, and admin status overrides.

---

### Fraud Detection Service (port 8003)

**Technology:** Python 3.11, FastAPI, SQLAlchemy  
**Role:** Rule-based fraud scoring and alert management.

- Scores transactions on a 0–1 scale using configurable heuristic rules.
- Persists results as `FraudAlert` records (upserted per transaction).
- Returns a `risk_level` (`low` / `medium` / `high`) and a `recommendation` (`allow` / `review` / `block`).
- Exposes `GET /fraud/alerts` for an administrative view of high-risk transactions.

---

## Data Flow

### User Registration

```
Client → Gateway → Auth Service → PostgreSQL (INSERT user)
                                ← 201 UserResponse
```

### Login

```
Client → Gateway → Auth Service → PostgreSQL (SELECT user, verify password)
                                ← 200 TokenResponse {access_token, refresh_token}
```

### Create Transaction

```
Client → Gateway → Transaction Service
                       │
                       ├─ Auth Service  (validate JWT)
                       │
                       ├─ PostgreSQL    (INSERT transaction, status=pending)
                       │
                       └─ Fraud Service (POST /fraud/analyze)
                              │
                              └─ PostgreSQL (UPSERT fraud_alert)
                              ← FraudAnalysisResponse {score, risk_level, flags}
                       │
                       ├─ (update fraud_score on transaction)
                       │
                       └─ PostgreSQL (UPDATE transaction)
                       ← 201 TransactionResponse
```

### Token Refresh

```
Client → Gateway → Auth Service → PostgreSQL (verify + rotate refresh_token)
                                ← 200 AccessTokenResponse {access_token}
```

---

## Technology Choices

| Concern              | Choice                          | Rationale                                                       |
|----------------------|---------------------------------|-----------------------------------------------------------------|
| Backend framework    | FastAPI                         | Async-capable, automatic OpenAPI docs, excellent type-safety     |
| ORM                  | SQLAlchemy 2.x                  | Mature, Alembic migrations, supports async mode                  |
| Auth tokens          | JWT (python-jose)               | Stateless access tokens; DB-backed refresh tokens for revocation |
| Password hashing     | bcrypt (passlib)                | Industry-standard; built-in cost factor for brute-force defence  |
| Database             | PostgreSQL 15                   | ACID compliance, JSONB, row-level security, wide cloud support   |
| Cache / broker       | Redis 7                         | Low-latency, ready for session caching and future task queues    |
| Container runtime    | Docker + Docker Compose         | Reproducible local environments; maps directly to k8s pods       |
| CI/CD                | GitHub Actions                  | Zero-infrastructure, native GHCR integration, free for OSS       |
| iOS framework        | SwiftUI + Combine               | Declarative UI, reactive data binding, Apple-first tooling       |
| iOS architecture     | MVVM                            | Testable, clear separation of concerns, pairs well with Combine  |
| Secure storage (iOS) | Keychain                        | OS-managed encrypted storage for tokens and credentials          |

---

## Database Schema (simplified)

```
users
  id            SERIAL PRIMARY KEY
  username      VARCHAR UNIQUE NOT NULL
  email         VARCHAR UNIQUE NOT NULL
  hashed_password VARCHAR NOT NULL
  is_active     BOOLEAN DEFAULT TRUE
  is_admin      BOOLEAN DEFAULT FALSE
  refresh_token TEXT
  created_at    TIMESTAMP DEFAULT NOW()

transactions
  id            SERIAL PRIMARY KEY
  sender_id     INTEGER REFERENCES users(id)
  recipient_id  INTEGER REFERENCES users(id)
  amount        NUMERIC(18,2) NOT NULL
  currency      VARCHAR(3) NOT NULL
  status        VARCHAR NOT NULL  -- pending | flagged | completed | failed
  fraud_score   FLOAT
  description   TEXT
  created_at    TIMESTAMP DEFAULT NOW()
  updated_at    TIMESTAMP DEFAULT NOW()

fraud_alerts
  id              SERIAL PRIMARY KEY
  transaction_id  INTEGER UNIQUE NOT NULL
  fraud_score     FLOAT NOT NULL
  risk_level      VARCHAR NOT NULL  -- low | medium | high
  flags           TEXT             -- JSON-encoded list
  recommendation  VARCHAR NOT NULL  -- allow | review | block
  created_at      TIMESTAMP DEFAULT NOW()
```

---

## Security Model

- **Transport:** All inter-service communication occurs on the private Docker bridge network. Only the gateway (8000) is intended to be internet-facing in production (behind TLS).
- **Authentication:** Stateless JWT access tokens signed with HMAC-SHA256. Refresh tokens stored in the database allow instant revocation on logout.
- **Authorisation:** The transaction service enforces ownership (sender or recipient); admin-only endpoints check `is_admin` on the authenticated user.
- **Fraud detection:** Every transaction is scored before being confirmed; high-risk transactions are held in `flagged` status for manual review.
- **Secrets:** JWT secret and database credentials are injected via environment variables and must never be committed to source control.
