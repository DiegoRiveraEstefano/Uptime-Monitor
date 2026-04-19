# AGENTS.md

## Project Overview

This is an uptime monitoring system built with Domain-Driven Design (DDD), Test-Driven Development (TDD), and multi-tenant architecture. The system uses Python 3.13.11 with async-first patterns.

### Core Principles

1. **Domain Purity**: Domain layer must not depend on infrastructure, frameworks, or external libraries
2. **Explicit Error Handling**: Use Result<T, E> pattern instead of exceptions for domain logic
3. **Tenant Isolation**: All data queries must include tenant_id filtering
4. **Test Coverage**: Minimum 85% coverage required for all new code
5. **Type Safety**: Strict mypy configuration with no ignored errors

---

## Architecture Guidelines

### Layer Dependencies

```
Interfaces → Application → Domain ← Infrastructure
```

- **Domain**: Pure business logic, no external dependencies
- **Application**: Orchestrates use cases, commands, queries
- **Infrastructure**: Implements repositories, external services
- **Interfaces**: HTTP controllers, middleware, schemas

### Module Structure

Each module follows this structure:

```
modules/<module_name>/
├── application/
│   ├── commands/
│   ├── queries/
│   ├── dto/
│   └── services/
├── domain/
│   ├── aggregates/
│   ├── entities/
│   ├── value_objects/
│   ├── repositories/
│   ├── events/
│   └── exceptions/
├── infrastructure/
│   ├── auth/
│   ├── persistence/
│   └── events/
└── interfaces/
    └── http/
        ├── controllers/
        ├── middlewares/
        └── schemas/
```

---

## Coding Standards

### Error Handling

Use the Result pattern for all domain operations:

```python
# CORRECT
from shared.kernel.result import Result, Ok, Err

async def create_user(cmd: CreateUserCmd) -> Result[User, DomainError]:
    if await repo.exists(cmd.email):
        return Err(UserAlreadyExistsError())
    user = User.create(cmd)
    await repo.save(user)
    return Ok(user)

# INCORRECT - Do not raise exceptions in domain layer
async def create_user(cmd: CreateUserCmd) -> User:
    if await repo.exists(cmd.email):
        raise UserAlreadyExistsError()  # Avoid this
```

### Multi-Tenancy

All repositories must enforce tenant isolation:

```python
# CORRECT - tenant_id is required and injected
class MonitorRepository:
    def __init__(self, executor: Executor, tenant_id: UUID):
        self.tenant_id = tenant_id

    async def find_by_id(self, monitor_id: UUID):
        # tenant_id is automatically included in all queries
        row = await self.executor.select(
            "SELECT * FROM monitors WHERE id = $1 AND tenant_id = $2",
            monitor_id, self.tenant_id
        )
```

```python
# INCORRECT - Do not allow queries without tenant filtering
async def find_by_id(self, monitor_id: UUID):
    row = await self.executor.select(
        "SELECT * FROM monitors WHERE id = $1",  # Missing tenant_id
        monitor_id
    )
```

### Dependency Injection

Use Dishka for all dependencies:

```python
# CORRECT - Dependencies injected via constructor
@dataclass
class CreateMonitorHandler:
    monitor_repo: IMonitorRepository
    event_bus: EventBus

    async def execute(self, cmd: CreateMonitorCmd) -> Result[Monitor, DomainError]:
        ...

# INCORRECT - Do not import or instantiate dependencies directly
@dataclass
class CreateMonitorHandler:
    async def execute(self, cmd: CreateMonitorCmd):
        from modules.monitoring.infrastructure import MonitorRepo  # Avoid this
```

### Async Patterns

- Use `async/await` for all I/O operations
- Wrap synchronous operations (like pyCasbin) with `asyncio.to_thread()`
- Propagate context vars explicitly in background tasks

```python
# CORRECT - Sync operations wrapped for async
async def check_permission(user_id: str, resource: str, action: str) -> bool:
    return await asyncio.to_thread(enforcer.enforce, user_id, resource, action)

# CORRECT - Context propagated to background tasks
async def schedule_check(monitor: Monitor):
    ctx = contextvars.copy_context()
    await taskiq.kiq(ctx.run, execute_check, monitor.id)
```

---

## Testing Guidelines

### Test Pyramid

```
        E2E (10%)
       /         \
  Integration (30%)
     /             \
   Unit (60%)
```

### Test Categories

| Category | Location | Tools | Speed |
|----------|----------|-------|-------|
| Unit | `tests/unit/` | pytest, hypothesis | Fast |
| Integration | `tests/integration/` | testcontainers | Medium |
| E2E | `tests/e2e/` | httpx, starlette testclient | Slow |

### Writing Tests

```python
# CORRECT - Unit test for domain logic
def test_monitor_invalid_interval():
    with pytest.raises(InvalidIntervalError):
        Monitor.create(url="https://example.com", interval=-1)

# CORRECT - Integration test with real database
@pytest.mark.asyncio
@pytest.mark.integration
async def test_repository_tenant_isolation(db_container):
    # Create data for tenant A
    await repo.save(monitor_a, tenant_id=tenant_a_id)

    # Query with tenant B context
    result = await repo.find_by_id(monitor_a.id, tenant_id=tenant_b_id)

    assert isinstance(result, Err)
    assert isinstance(result.error, NotFoundError)
```

### Test Naming Convention

```
test_<module>_<component>_<scenario>_<expected_result>.py

Examples:
- test_monitor_create_invalid_url_returns_error.py
- test_user_repository_tenant_isolation.py
- test_rbac_middleware_denies_unauthorized.py
```

---

## Common Patterns

### Result Pattern

```python
from shared.kernel.result import Result, Ok, Err

# Return type annotation
def operation() -> Result[SuccessType, ErrorType]:
    ...

# Handling results
result = operation()
if not result.is_success:
    return Err(result.error)

value = result.value  # Safe access after check
```

### Value Objects

```python
@dataclass(frozen=True)
class Email:
    value: str

    def __post_init__(self):
        if not self._is_valid(self.value):
            raise InvalidEmailError()

    @staticmethod
    def _is_valid(email: str) -> bool:
        return "@" in email and "." in email
```

### Domain Events

```python
@dataclass
class MonitorCreatedEvent(DomainEvent):
    monitor_id: UUID
    tenant_id: UUID
    created_at: datetime
    created_by: UUID

# Publish from aggregate
class Monitor(AggregateRoot):
    def create(cls, ...):
        monitor = cls(...)
        monitor.record_event(MonitorCreatedEvent(...))
        return monitor
```

---

## Security Requirements

### Authentication

- All endpoints require JWT authentication
- Tokens must include: user_id, tenant_id, roles
- Token expiration: 15 minutes (access), 7 days (refresh)

### Authorization

- Use Casbin for RBAC decisions
- Define policies per tenant (domain-based RBAC)
- Middleware enforces at HTTP layer
- Domain layer validates business rules

### Data Isolation

- Every query must include tenant_id filter
- Never trust client-provided tenant_id
- Extract tenant_id from verified JWT token
- Log all cross-tenant access attempts

---

## Adding New Features

### Step 1: Domain Layer

1. Define aggregates, entities, value objects
2. Define repository interfaces (Protocol)
3. Define domain events
4. Write unit tests first (TDD)

### Step 2: Application Layer

1. Create commands/queries (msgspec structs)
2. Create handlers/services
3. Wire up domain objects
4. Write application tests with mocked repositories

### Step 3: Infrastructure Layer

1. Implement repositories (Mayim)
2. Implement event publishers
3. Implement external service adapters
4. Write integration tests with testcontainers

### Step 4: Interface Layer

1. Create HTTP schemas (msgspec)
2. Create controllers (Starlette)
3. Add middleware (auth, tenant, RBAC)
4. Write E2E tests

---

## Common Pitfalls to Avoid

| Pitfall | Solution |
|---------|----------|
| Importing infrastructure in domain | Use Protocol interfaces only |
| Missing tenant_id in queries | Inject tenant_id via Dishka |
| Raising exceptions in domain | Return Result<T, E> instead |
| Blocking async with sync calls | Use asyncio.to_thread() |
| Direct dependency on Taskiq | Use scheduling module abstraction |
| Hardcoded tenant filtering | Use repository base class with automatic filtering |
| Mixing command and query logic | Separate CQRS handlers |
| Skipping type annotations | Enable strict mypy, no ignores |

---

## Code Review Checklist

- [ ] Domain layer has no external dependencies
- [ ] All repository methods include tenant_id parameter
- [ ] Error handling uses Result pattern
- [ ] Type annotations complete and correct
- [ ] Tests cover success and failure paths
- [ ] No hardcoded values (use configuration)
- [ ] Logging uses structlog
- [ ] Security headers and validation in place
- [ ] Documentation updated
- [ ] Coverage meets 85% threshold

---

## Commands Reference

```bash
# Install dependencies
uv sync --all-groups

# Run all tests
uv run pytest

# Run unit tests only
uv run pytest tests/unit -v

# Run integration tests
uv run pytest tests/integration -v -m infra

# Type checking
uv run mypy src/

# Linting
uv run ruff check src/

# Formatting
uv run ruff format src/

# Security audit
uv run bandit -r src/
uv run pip-audit

# Coverage report
uv run pytest --cov=src --cov-report=html
```

---

## Environment Setup

```bash
# Required environment variables
DATABASE_URL=sqlite+aiosqlite:///./dev.db
JWT_SECRET=<secure-random-string>
JWT_ALGORITHM=HS256
CASBIN_MODEL_PATH=./config/casbin/model.conf
CASBIN_POLICY_PATH=./config/casbin/policy.csv
LOG_LEVEL=INFO

# Docker services
docker compose up -d db
```

---

## Contact and Support

For questions about architecture or implementation:

1. Check existing documentation in `/docs`
2. Review similar implementations in existing modules
3. Open a discussion in project issues
4. Consult the DDD and TDD guidelines in this file

---

<div align="center">

Last updated: 2025

[Back to README](README.md)

</div>
