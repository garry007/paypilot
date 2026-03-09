# PayPilot API Reference

All requests that require authentication must include:

```
Authorization: Bearer <access_token>
```

All responses are JSON. Timestamps are ISO 8601 strings (UTC).

---

## API Gateway

**Base URL:** `http://localhost:8000`

The gateway acts as a single entry point, routing requests to the appropriate upstream microservice and aggregating health data.

### Routes

| Method | Path                                    | Upstream            | Auth required |
|--------|-----------------------------------------|---------------------|---------------|
| POST   | `/api/v1/auth/register`                 | auth-service        | No            |
| POST   | `/api/v1/auth/login`                    | auth-service        | No            |
| POST   | `/api/v1/auth/refresh`                  | auth-service        | No            |
| GET    | `/api/v1/auth/me`                       | auth-service        | Yes           |
| POST   | `/api/v1/auth/logout`                   | auth-service        | Yes           |
| POST   | `/api/v1/transactions/`                 | transaction-service | Yes           |
| GET    | `/api/v1/transactions/stats/summary`    | transaction-service | Yes           |
| GET    | `/api/v1/transactions/`                 | transaction-service | Yes           |
| GET    | `/api/v1/transactions/{id}`             | transaction-service | Yes           |
| PUT    | `/api/v1/transactions/{id}/status`      | transaction-service | Yes (admin)   |
| POST   | `/api/v1/fraud/analyze`                 | fraud-service       | No            |
| GET    | `/api/v1/fraud/alerts`                  | fraud-service       | No            |
| GET    | `/api/v1/fraud/alerts/{transaction_id}` | fraud-service       | No            |
| GET    | `/health`                               | gateway self        | No            |

### GET /health

Returns the gateway's own status plus reachability of every upstream service.

**Response 200**
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

---

## Auth Service

**Base URL (direct):** `http://localhost:8001`  
**Via gateway:** `http://localhost:8000/api/v1/auth`

### POST /auth/register

Create a new PayPilot user account.

**Request body**
```json
{
  "username": "alice",
  "email": "alice@example.com",
  "password": "SuperSecret123!"
}
```

**Response 201**
```json
{
  "id": 1,
  "username": "alice",
  "email": "alice@example.com",
  "is_active": true,
  "is_admin": false,
  "created_at": "2024-01-15T10:30:00Z"
}
```

**Errors**
| Code | Reason |
|------|--------|
| 409  | Username or email already registered |
| 422  | Validation error (invalid email, password too short, etc.) |

---

### POST /auth/login

Authenticate a user and receive JWT tokens.

**Request body**
```json
{
  "username": "alice",
  "password": "SuperSecret123!"
}
```

**Response 200**
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "bearer"
}
```

**Errors**
| Code | Reason |
|------|--------|
| 401  | Invalid username or password |
| 403  | Account is deactivated |

---

### POST /auth/refresh

Exchange a refresh token for a new access token.

**Request body**
```json
{
  "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

**Response 200**
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

**Errors**
| Code | Reason |
|------|--------|
| 401  | Invalid, expired, or revoked refresh token |

---

### GET /auth/me

Return the profile of the authenticated user.

**Response 200**
```json
{
  "id": 1,
  "username": "alice",
  "email": "alice@example.com",
  "is_active": true,
  "is_admin": false,
  "created_at": "2024-01-15T10:30:00Z"
}
```

**Errors**
| Code | Reason |
|------|--------|
| 401  | Missing or invalid access token |

---

### POST /auth/logout

Invalidate the current user's refresh token.

**Response 200**
```json
{
  "message": "Successfully logged out."
}
```

---

### GET /health

```json
{ "status": "ok", "service": "auth-service" }
```

---

## Transaction Service

**Base URL (direct):** `http://localhost:8002`  
**Via gateway:** `http://localhost:8000/api/v1/transactions`

All endpoints require a valid `Authorization: Bearer <access_token>` header.

### POST /transactions/

Submit a new payment transaction. The fraud service is consulted automatically; if the fraud score is ≥ 0.7 **or** the amount exceeds $10,000 the transaction is flagged.

**Request body**
```json
{
  "recipient_id": 2,
  "amount": "250.00",
  "currency": "USD",
  "description": "Dinner split"
}
```

**Response 201**
```json
{
  "id": 42,
  "sender_id": 1,
  "recipient_id": 2,
  "amount": "250.00",
  "currency": "USD",
  "status": "pending",
  "fraud_score": 0.12,
  "description": "Dinner split",
  "created_at": "2024-01-15T11:00:00Z",
  "updated_at": "2024-01-15T11:00:00Z"
}
```

**Transaction statuses**

| Status    | Meaning                                      |
|-----------|----------------------------------------------|
| `pending` | Awaiting processing                          |
| `flagged` | Held for review (high amount or fraud score) |
| `completed` | Successfully processed                     |
| `failed`  | Processing failed                            |

**Errors**
| Code | Reason |
|------|--------|
| 401  | Unauthenticated |
| 422  | Invalid payload |

---

### GET /transactions/stats/summary

Aggregate sent/received totals for the authenticated user, broken down by currency.

**Response 200**
```json
{
  "total_sent": "1500.00",
  "total_received": "800.00",
  "transaction_count": 12,
  "by_currency": [
    {
      "currency": "USD",
      "total_sent": "1000.00",
      "total_received": "500.00",
      "count": 8
    },
    {
      "currency": "EUR",
      "total_sent": "500.00",
      "total_received": "300.00",
      "count": 4
    }
  ]
}
```

---

### GET /transactions/

Paginated list of transactions where the authenticated user is the sender or recipient.

**Query parameters**

| Parameter | Type    | Default | Description           |
|-----------|---------|---------|-----------------------|
| `page`    | integer | 1       | Page number (1-based) |
| `limit`   | integer | 20      | Records per page (max 100) |

**Response 200**
```json
{
  "items": [
    {
      "id": 42,
      "sender_id": 1,
      "recipient_id": 2,
      "amount": "250.00",
      "currency": "USD",
      "status": "pending",
      "fraud_score": 0.12,
      "description": "Dinner split",
      "created_at": "2024-01-15T11:00:00Z",
      "updated_at": "2024-01-15T11:00:00Z"
    }
  ],
  "total": 1,
  "page": 1,
  "limit": 20,
  "pages": 1
}
```

---

### GET /transactions/{transaction_id}

Retrieve a single transaction. The caller must be the sender or recipient.

**Response 200** — same schema as a single item above.

**Errors**
| Code | Reason |
|------|--------|
| 403  | Caller is neither sender nor recipient |
| 404  | Transaction not found |

---

### PUT /transactions/{transaction_id}/status

Manually override a transaction's status. **Admin only.**

**Request body**
```json
{
  "status": "completed"
}
```

**Response 200** — updated transaction object.

**Errors**
| Code | Reason |
|------|--------|
| 403  | Caller is not an admin |
| 404  | Transaction not found |

---

### GET /health

```json
{ "status": "ok", "service": "transaction-service" }
```

---

## Fraud Detection Service

**Base URL (direct):** `http://localhost:8003`  
**Via gateway:** `http://localhost:8000/api/v1/fraud`

The fraud service is primarily called internally by the transaction service. These endpoints are also accessible directly for testing and administrative use.

### POST /fraud/analyze

Run fraud-scoring rules against a transaction and persist the result.

**Request body**
```json
{
  "transaction_id": 42,
  "sender_id": 1,
  "recipient_id": 2,
  "amount": 15000.00,
  "currency": "USD"
}
```

**Response 200**
```json
{
  "transaction_id": 42,
  "fraud_score": 0.85,
  "risk_level": "high",
  "flags": ["large_amount", "round_number"],
  "recommendation": "block"
}
```

**Risk levels**

| Level    | Score range | Recommendation |
|----------|-------------|----------------|
| `low`    | 0.00 – 0.39 | `allow`        |
| `medium` | 0.40 – 0.69 | `review`       |
| `high`   | 0.70 – 1.00 | `block`        |

**Common flags**

| Flag              | Trigger                              |
|-------------------|--------------------------------------|
| `large_amount`    | Amount > $10,000                     |
| `round_number`    | Amount is a round number             |
| `self_transfer`   | sender_id == recipient_id            |
| `foreign_currency`| Currency is not USD                  |

---

### GET /fraud/alerts

List all fraud alerts with risk level `high`.

**Response 200**
```json
[
  {
    "id": 7,
    "transaction_id": 42,
    "fraud_score": 0.85,
    "risk_level": "high",
    "flags": ["large_amount", "round_number"],
    "recommendation": "block",
    "created_at": "2024-01-15T11:00:05Z"
  }
]
```

---

### GET /fraud/alerts/{transaction_id}

Retrieve the fraud analysis for a specific transaction.

**Response 200** — single alert object (same schema as above).

**Errors**
| Code | Reason |
|------|--------|
| 404  | No analysis found for transaction |

---

### GET /health

```json
{ "status": "ok", "service": "fraud-service" }
```
