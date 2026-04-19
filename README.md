# Uptime Monitor

[![Python 3.13](https://img.shields.io/badge/python-3.13-blue.svg)](https://www.python.org/downloads/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Code Style: Ruff](https://img.shields.io/badge/code%20style-ruff-000000.svg)](https://github.com/astral-sh/ruff)
[![Type Checked: Mypy](https://img.shields.io/badge/types-mypy-blue.svg)](http://mypy-lang.org/)

Uptime monitoring system with multi-tenant architecture, DDD, TDD, and enterprise security (RBAC).

---

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [System Modules](#system-modules)
- [Technology Stack](#technology-stack)
- [Design Principles](#design-principles)
- [Project Structure](#project-structure)
- [Quick Start](#quick-start)
- [Development and Testing](#development-and-testing)
- [Security and Permissions](#security-and-permissions)
- [Roadmap](#roadmap)

---

## Overview

Uptime Monitor is a B2B SaaS system for service availability monitoring, designed from scratch with:

- Multi-tenant architecture with data isolation per client
- RBAC (Role-Based Access Control) using Casbin
- DDD (Domain-Driven Design) for maintainability
- TDD (Test-Driven Development) for quality assurance
- Async-first architecture for high performance

Philosophy: This is not just an uptime monitor. It is a detection, decision, and notification system.

---

## Architecture

### Pattern: DDD + Hexagonal + CQRS

```
+-------------------------------------------------------------+
|                      INTERFACES (HTTP)                       |
|              Controllers · Middlewares · Schemas             |
+-------------------------------------------------------------+
|                    APPLICATION LAYER                         |
|         Commands · Queries · DTOs · Application Services     |
+-------------------------------------------------------------+
|                      DOMAIN LAYER                            |
|    Aggregates · Entities · Value Objects · Domain Events     |
+-------------------------------------------------------------+
|                   INFRASTRUCTURE LAYER                       |
|      Repositories (Mayim) · Events · Auth · External APIs    |
+-------------------------------------------------------------+
```

### Data Flow

```
IAM → Monitoring → Scheduling → Check Execution → Incidents → Notifications → Metrics
```

---

## System Modules

| Module | Responsibility | Status |
|--------|----------------|--------|
| `iam` | Users, Tenants, Memberships, Roles | Core |
| `monitoring` | Check definition, configuration | Core |
| `check_execution` | Real check execution, workers | Core |
| `incidents` | Downtime detection and management | Phase 2 |
| `notifications` | Alerts (email, webhook, slack) | Phase 2 |
| `metrics` | History, reports, aggregations | Phase 3 |
| `scheduling` | Execution planning | Phase 3 |
| `billing` | Plans, subscriptions, limits | Phase 4 |
| `audit` | Audit logs and traceability | Phase 4 |

---

## Technology Stack

### Core
| Tool | Version | Purpose |
|-------------|---------|-----------|
| Python | 3.13.11 | Base language |
| Starlette | ≥1.0.0 | Async HTTP framework |
| Granian/Uvicorn | ≥0.44.0 | ASGI Server |
| Dishka | ≥1.10.0 | Dependency Injection |
| Mayim | ≥1.3.2 | Data access (ORM-lite) |

### Security & Auth
| Tool | Version | Purpose |
|-------------|---------|-----------|
| PyCasbin | ≥2.8.0 | RBAC authorization engine |
| PyJWT | ≥2.12.1 | Authentication tokens |
| Bcrypt | ≥5.0.0 | Password hashing |
| Cryptography | ≥46.0.7 | General cryptography |

### Messaging & Tasks
| Tool | Version | Purpose |
|-------------|---------|-----------|
| Taskiq | ≥0.12.2 | Async task queue |
| Structlog | ≥25.5.0 | Structured logging |

### Validation & Serialization
| Tool | Version | Purpose |
|-------------|---------|-----------|
| Msgspec | ≥0.21.1 | Fast serialization |
| SpecTree | ≥2.0.1 | OpenAPI documentation |
| Msgspec-settings | ≥0.1.0 | Typed configuration |

### Testing
| Tool | Version | Purpose |
|-------------|---------|-----------|
| Pytest | ≥9.0.2 | Test runner |
| Hypothesis | 6.150.2 | Property-based testing |
| Testcontainers | ≥4.14.0 | Real DBs in Docker |
| Polyfactory | ≥3.2.0 | Data generation |
| Coverage | 7.13.1 | Coverage reporting |

---

## Design Principles

### 1. Rust/Go Style Error Handling

The **`Result<T, E>`** pattern is used to make error flow explicit and allow static verification with `mypy`.

```python
from shared.kernel.result import Result, Ok, Err

async def create_monitor(cmd: CreateMonitorCmd) -> Result[Monitor, DomainError]:
    if not cmd.is_valid():
        return Err(InvalidMonitorError())
    
    monitor = Monitor.create(cmd)
    await repo.save(monitor)
    return Ok(monitor)
```

Benefits:
- `mypy` detects unhandled errors at compile time
- No hidden exceptions in the domain flow
- More predictable testing

### 2. Multi-Tenancy with Isolation

Strategy: Single Database, Row-Level Isolation

```python
# The tenant_id is injected automatically via Dishka
class MonitorRepository:
    def __init__(self, executor: Executor, tenant_id: UUID):
        self.tenant_id = tenant_id  # Injected by context
    
    async def find_by_id(self, monitor_id: UUID):
        # WHERE tenant_id = self.tenant_id ALWAYS
        ...
```

Context per Request:
```python
# Middleware extracts tenant from JWT
tenant_ctx.set(UUID(jwt_payload["tenant_id"]))
user_ctx.set(UUID(jwt_payload["sub"]))
```

### 3. RBAC with Casbin (Multi-Tenant)

Model `policy.conf`:
```ini
[request_definition]
r = sub, dom, obj, act

[policy_definition]
p = sub, dom, obj, act

[role_definition]
g = _, _, _

[matchers]
m = g(r.sub, p.sub, r.dom) && r.dom == p.dom && keyMatch2(r.obj, p.obj)
```

Policy Example:
```
p, role:admin, tenant-123, /monitors/*, (GET|POST|DELETE)
g, user-456, role:admin, tenant-123
```

### 4. TDD as Methodology

```
1. Domain Test (no DB, no async)
   ↓
2. Application Test (mock repositories)
   ↓
3. Infrastructure Test (testcontainers)
   ↓
4. Interface Test (httpx + Starlette)
```

Minimum required coverage: 85%

---

## Project Structure

```
src/
├── core/                      # Shared kernel
│   └── templates/
├── modules/
│   ├── iam/                   # Identity & Access Management
│   │   ├── application/
│   │   │   ├── commands/
│   │   │   ├── queries/
│   │   │   ├── dto/
│   │   │   └── services/
│   │   ├── domain/
│   │   │   ├── aggregates/
│   │   │   ├── entities/
│   │   │   ├── value_objects/
│   │   │   ├── repositories/
│   │   │   ├── events/
│   │   │   └── exceptions/
│   │   ├── infrastructure/
│   │   │   ├── auth/
│   │   │   ├── persistence/
│   │   │   └── events/
│   │   └── interfaces/
│   │       └── http/
│   ├── monitoring/            # Monitor definition
│   ├── check_execution/       # Check execution
│   ├── incidents/             # Incident management
│   └── notifications/         # Alert system
├── shared/                    # Shared kernel
│   ├── kernel/
│   │   ├── result.py          # Result<T,E> pattern
│   │   ├── context.py         # ContextVars (tenant, user)
│   │   └── exceptions.py      # Base exceptions
│   └── di/
│       └── container.py       # Dishka configuration
└── infrastructure/            # Global infrastructure
    ├── db/
    ├── events/
    └── config/

tests/
├── unit/                      # Domain tests (fast)
├── integration/               # Tests with real DB
└── e2e/                       # End-to-end tests
```

---

## Quick Start

### Prerequisites

```bash
# Python 3.13.11 exact
python --version

# UV for package management
curl -LsSf https://astral.sh/uv/install.sh | sh
```

### Installation

```bash
# Clone repository
git clone <repo-url>
cd uptime-monitor

# Install dependencies
uv sync --all-groups

# Configure environment
cp .env.example .env

# Start database (Docker)
docker compose up -d db

# Run migrations
uv run python -m src.infrastructure.db.migrate

# Start server
uv run granian src.interfaces.http.app:app --reload
```

### Environment Variables

```bash
# .env
DATABASE_URL=sqlite+aiosqlite:///./dev.db
JWT_SECRET=your-secret-key
JWT_ALGORITHM=HS256
CASBIN_MODEL_PATH=./config/casbin/model.conf
CASBIN_POLICY_PATH=./config/casbin/policy.csv
LOG_LEVEL=INFO
```

---

## Development and Testing

### Run Tests

```bash
# All tests
uv run pytest

# Unit only (fast, no DB)
uv run pytest tests/unit -v

# Integration only (with testcontainers)
uv run pytest tests/integration -v -m infra

# With coverage
uv run pytest --cov=src --cov-report=html

# TDD mode (watch)
uv run ptw --onpass "pytest"
```

### Code Quality

```bash
# Linting
uv run ruff check src/

# Formatting
uv run ruff format src/

# Type checking
uv run mypy src/

# Security
uv run bandit -r src/
uv run pip-audit

# Cyclomatic complexity
uv run lizard src/
```

### Pre-commit Hooks

```bash
# Install hooks
uv run pre-commit install

# Run manually
uv run pre-commit run --all-files
```

---

## Security and Permissions

### Authentication (JWT)

```bash
POST /api/v1/auth/login
{
  "email": "user@example.com",
  "password": "secure-password"
}

# Response
{
  "access_token": "eyJ...",
  "refresh_token": "eyJ...",
  "tenant_id": "uuid-here"
}
```

### Authorization (RBAC)

| Role | Permissions |
|-----|----------|
| `owner` | Full access to tenant |
| `admin` | Full CRUD, member management |
| `member` | Read and limited creation |
| `viewer` | Read only |

### Required Headers

```http
Authorization: Bearer <jwt-token>
X-Tenant-ID: <tenant-uuid>
```

---

## Roadmap

### Phase 1 - MVP (Current)
- [x] Base DDD structure
- [x] Complete IAM module
- [x] Result pattern for errors
- [x] Multi-tenancy with Dishka
- [ ] Basic Monitoring module
- [ ] Check Execution with Taskiq

### Phase 2 - Production Ready
- [ ] Incident System
- [ ] Notifications (Email, Webhook, Slack)
- [ ] Basic Dashboard
- [ ] Rate limiting per tenant

### Phase 3 - Scaling
- [ ] Historical metrics and reports
- [ ] Advanced scheduling
- [ ] Distributed cache (Redis)
- [ ] Horizontal scaling of workers

### Phase 4 - Enterprise
- [ ] Billing and subscriptions
- [ ] Complete audit logs
- [ ] SSO (SAML/OIDC)
- [ ] API Keys for integrations

---

## Contributing

1. Fork the project
2. Create your branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Commit Conventions

```
feat: new feature
fix: bug fix
docs: documentation
style: formatting (no logic changes)
refactor: refactoring
test: add tests
chore: maintenance
```

---

## License

Distributed under the MIT License. See `LICENSE` for more information.

---

## Contact

- **Project:** [https://github.com/yourusername/uptime-monitor](https://github.com/yourusername/uptime-monitor)
- **Issues:** [GitHub Issues](https://github.com/yourusername/uptime-monitor/issues)

---

## Acknowledgments

- DDD Community
- Casbin
- FastAPI/Starlette
- Taskiq

---

<div align="center">

Built with Python 3.13

[Back to top](#uptime-monitor)

</div>
