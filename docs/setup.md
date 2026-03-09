# PayPilot – Getting Started

## Prerequisites

| Tool              | Minimum version | Install guide |
|-------------------|-----------------|---------------|
| Docker Desktop    | 24.x            | https://docs.docker.com/get-docker/ |
| Docker Compose    | 2.x (bundled)   | Included with Docker Desktop |
| Python            | 3.11            | https://www.python.org/downloads/ |
| Xcode             | 15.2            | Mac App Store |
| Git               | 2.x             | https://git-scm.com |

---

## Quick Start with Docker Compose

The fastest way to run the entire platform locally.

```bash
# 1. Clone the repository
git clone https://github.com/<your-org>/paypilot.git
cd paypilot

# 2. Start all services (builds images on first run)
docker compose up --build

# 3. Verify everything is healthy
curl http://localhost:8000/health
```

Expected response:
```json
{
  "status": "ok",
  "service": "api-gateway",
  "upstreams": {
    "auth-service": "ok",
    "transaction-service": "ok",
    "fraud-service": "ok"
  }
}
```

Services start in dependency order. First boot may take 1–2 minutes while PostgreSQL initialises.

### Useful Compose commands

```bash
# Run in the background
docker compose up -d --build

# Tail logs for a single service
docker compose logs -f auth-service

# Stop everything (keep data volumes)
docker compose down

# Stop and delete all data volumes (full reset)
docker compose down -v

# Rebuild a single service after code changes
docker compose up --build auth-service
```

### Interactive API docs

Once running, each service exposes a Swagger UI:

| Service             | Swagger UI                            |
|---------------------|---------------------------------------|
| API Gateway         | http://localhost:8000/docs            |
| Auth Service        | http://localhost:8001/docs            |
| Transaction Service | http://localhost:8002/docs            |
| Fraud Service       | http://localhost:8003/docs            |

---

## Local Development Setup

Use this approach when you want to iterate quickly without rebuilding Docker images.

### 1. Spin up infrastructure only

```bash
docker compose up -d postgres redis
```

### 2. Auth Service

```bash
cd backend/auth-service
python -m venv .venv
source .venv/bin/activate          # Windows: .venv\Scripts\activate
pip install -r requirements.txt

export DATABASE_URL="postgresql://paypilot:paypilot_secret@localhost:5432/paypilot"
export JWT_SECRET_KEY="dev-secret-key"

uvicorn main:app --reload --port 8001
```

Run the tests:
```bash
pytest tests/ -v
```

### 3. Fraud Service

```bash
cd backend/fraud-service
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

export DATABASE_URL="postgresql://paypilot:paypilot_secret@localhost:5432/paypilot"

uvicorn main:app --reload --port 8003
```

Run the tests:
```bash
pytest tests/ -v
```

### 4. Transaction Service

Start auth-service and fraud-service first (or run them in Docker), then:

```bash
cd backend/transaction-service
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

export DATABASE_URL="postgresql://paypilot:paypilot_secret@localhost:5432/paypilot"
export JWT_SECRET_KEY="dev-secret-key"
export AUTH_SERVICE_URL="http://localhost:8001"
export FRAUD_SERVICE_URL="http://localhost:8003"

uvicorn main:app --reload --port 8002
```

Run the tests:
```bash
pytest tests/ -v
```

### 5. API Gateway

```bash
cd backend/api-gateway
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

export AUTH_SERVICE_URL="http://localhost:8001"
export TRANSACTION_SERVICE_URL="http://localhost:8002"
export FRAUD_SERVICE_URL="http://localhost:8003"

uvicorn main:app --reload --port 8000
```

---

## iOS Development Setup

### Requirements

- macOS 13 (Ventura) or later
- Xcode 15.2 or later

### Build and run

```bash
cd ios-app

# Build the Swift package
swift build

# Run tests
swift test

# Open in Xcode (optional)
xed .
```

To run on a simulator or device, open `ios-app/` in Xcode and select a target.

The app defaults to `http://localhost:8000` as the API base URL. Change `Endpoints.swift` if you need to point at a remote environment.

---

## Environment Variables Reference

### Auth Service

| Variable          | Required | Default | Description                        |
|-------------------|----------|---------|------------------------------------|
| `DATABASE_URL`    | Yes      | —       | PostgreSQL connection string        |
| `JWT_SECRET_KEY`  | Yes      | —       | HMAC-SHA256 signing secret          |

### Transaction Service

| Variable              | Required | Default | Description                          |
|-----------------------|----------|---------|--------------------------------------|
| `DATABASE_URL`        | Yes      | —       | PostgreSQL connection string          |
| `JWT_SECRET_KEY`      | Yes      | —       | Must match auth-service value         |
| `AUTH_SERVICE_URL`    | Yes      | —       | Base URL of auth-service              |
| `FRAUD_SERVICE_URL`   | Yes      | —       | Base URL of fraud-service             |

### Fraud Service

| Variable       | Required | Default | Description                   |
|----------------|----------|---------|-------------------------------|
| `DATABASE_URL` | Yes      | —       | PostgreSQL connection string   |

### API Gateway

| Variable                  | Required | Default | Description                       |
|---------------------------|----------|---------|-----------------------------------|
| `AUTH_SERVICE_URL`        | Yes      | —       | Base URL of auth-service           |
| `TRANSACTION_SERVICE_URL` | Yes      | —       | Base URL of transaction-service    |
| `FRAUD_SERVICE_URL`       | Yes      | —       | Base URL of fraud-service          |

---

## Troubleshooting

### Services fail to start with "connection refused" to PostgreSQL

PostgreSQL is still initialising. The healthcheck retries up to 5 times with 10-second intervals. Wait 30–60 seconds and run `docker compose ps` to check the status. If it continues failing:

```bash
docker compose logs postgres
```

### "Table does not exist" errors

The services use SQLAlchemy's `create_all()` on startup to create tables automatically. If you see this error it usually means the service started before the database was ready. Restart the affected service:

```bash
docker compose restart auth-service
```

### Port conflicts

If another process is already using port 8000–8003 or 5432:

```bash
# Find and kill the conflicting process
lsof -ti:8000 | xargs kill -9
```

Or change the host-side port in `docker-compose.yml` (e.g. `"18001:8001"`).

### `psycopg2` build errors in local setup

On macOS you may need libpq:

```bash
brew install libpq
export LDFLAGS="-L/opt/homebrew/opt/libpq/lib"
export CPPFLAGS="-I/opt/homebrew/opt/libpq/include"
pip install psycopg2-binary
```

### iOS build fails with "no such module" error

Make sure you're using Xcode 15.2:

```bash
xcode-select -p          # check active toolchain
sudo xcode-select -s /Applications/Xcode_15.2.app/Contents/Developer
```

### Resetting everything

```bash
docker compose down -v   # removes containers + volumes
docker compose up --build
```
