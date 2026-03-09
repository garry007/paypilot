# PayPilot Infrastructure

This directory is the home for infrastructure-as-code and deployment tooling for the PayPilot platform.

## Overview

PayPilot is deployed as a set of containerised microservices orchestrated with Docker Compose (local / staging) and intended to be migrated to a managed container platform (e.g. AWS ECS, GKE, or Azure AKS) for production.

```
infrastructure/
├── README.md          ← you are here
└── (future)
    ├── terraform/     ← cloud resource provisioning
    ├── k8s/           ← Kubernetes manifests
    └── scripts/       ← helper shell scripts
```

## Local Environment

The fastest path to a running stack is Docker Compose at the repository root:

```bash
docker compose up --build
```

All services start in dependency order:

| Start order | Service             | Port  |
|-------------|---------------------|-------|
| 1           | postgres            | 5432  |
| 1           | redis               | 6379  |
| 2           | auth-service        | 8001  |
| 2           | fraud-service       | 8003  |
| 3           | transaction-service | 8002  |
| 4           | api-gateway         | 8000  |

## Networking

All containers share the `paypilot-network` bridge network. Services communicate using their Docker service names (e.g. `http://auth-service:8001`). Only the ports listed above are published to the host.

## Volumes

| Volume         | Mounted in   | Purpose                          |
|----------------|--------------|----------------------------------|
| `postgres_data`| postgres     | Durable PostgreSQL data files    |
| `redis_data`   | redis        | Durable Redis RDB/AOF snapshots  |

To reset the databases completely:

```bash
docker compose down -v   # removes named volumes
docker compose up --build
```

## Health Checks

Every service exposes a `GET /health` endpoint that returns:

```json
{ "status": "ok", "service": "<service-name>" }
```

Docker Compose uses these endpoints (via `curl`) to determine when a service is ready before starting its dependants.

## Container Images

On every merge to `main`, GitHub Actions builds and pushes images to GitHub Container Registry (GHCR):

| Image                                                         | Source                      |
|---------------------------------------------------------------|-----------------------------|
| `ghcr.io/<owner>/paypilot-auth-service:latest`        | `backend/auth-service/`     |
| `ghcr.io/<owner>/paypilot-transaction-service:latest` | `backend/transaction-service/` |
| `ghcr.io/<owner>/paypilot-fraud-service:latest`       | `backend/fraud-service/`    |
| `ghcr.io/<owner>/paypilot-api-gateway:latest`         | `backend/api-gateway/`      |

## Security Notes

* The `JWT_SECRET_KEY` value in `docker-compose.yml` is a placeholder. **Always override it with a strong, randomly generated secret in non-development environments.**
* The PostgreSQL password (`paypilot_secret`) is also a placeholder. Use a secrets manager (AWS Secrets Manager, HashiCorp Vault, GitHub Secrets) in production.
* Database ports are not published to the host in the Compose file; only application-layer ports are exposed.

## Future Work

- [ ] Terraform modules for AWS VPC, RDS (PostgreSQL), ElastiCache (Redis), and ECS cluster
- [ ] Kubernetes Helm chart for staging / production deployments
- [ ] Horizontal pod autoscaling configuration
- [ ] TLS termination and certificate management (cert-manager / ACM)
- [ ] Centralised logging (AWS CloudWatch / Datadog)
- [ ] Distributed tracing (OpenTelemetry)
