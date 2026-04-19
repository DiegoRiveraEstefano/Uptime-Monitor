# STYLE_GUIDE.md

## Purpose

This document establishes coding standards and conventions for the Uptime Monitor project. All contributors must follow these guidelines to maintain code consistency, readability, and maintainability.

---

## Table of Contents

1. [General Principles](#general-principles)
2. [Python Version and Features](#python-version-and-features)
3. [Naming Conventions](#naming-conventions)
4. [File and Directory Structure](#file-and-directory-structure)
5. [Type Hints](#type-hints)
6. [Import Order](#import-order)
7. [Code Formatting](#code-formatting)
8. [Documentation Standards](#documentation-standards)
9. [Error Handling](#error-handling)
10. [Async Patterns](#async-patterns)
11. [Database and Queries](#database-and-queries)
12. [Testing Standards](#testing-standards)
13. [Logging](#logging)
14. [Security](#security)
15. [Git Conventions](#git-conventions)

---

## General Principles

- **Clarity over cleverness**: Write code that is easy to understand
- **Explicit over implicit**: Make dependencies and behavior clear
- **Consistency**: Follow existing patterns in the codebase
- **Single responsibility**: Each function, class, and module should have one purpose
- **Fail fast**: Validate inputs early and return errors immediately

---

## Python Version and Features

### Required Version

- Python 3.13.11 (exact version required)

### Allowed Features

```python
# Type aliases (Python 3.12+)
type UserId = UUID
type Result[T, E] = Ok[T] | Err[E]

# Pattern matching
match result:
    case Ok(value):
        ...
    case Err(error):
        ...

# TypedDict with total=False
class Config(TypedDict, total=False):
    debug: bool
    timeout: int

# f-strings with expressions
f"User {user.id} created at {created_at:%Y-%m-%d}"
```

### Forbidden Features

```python
# Do not use eval() or exec()
eval(user_input)  # FORBIDDEN

# Do not use mutable default arguments
def add_item(item, items=[]):  # FORBIDDEN
    ...

# Do not use bare except
try:
    ...
except:  # FORBIDDEN
    ...

# Do not import inside functions
def get_repo():
    from modules.xxx import Repo  # FORBIDDEN
    ...
```

---

## Naming Conventions

### General Rules

| Type | Convention | Example |
|------|------------|---------|
| Variables | snake_case | `user_id`, `tenant_id` |
| Functions | snake_case | `create_user`, `find_by_id` |
| Classes | PascalCase | `User`, `Monitor`, `Tenant` |
| Constants | UPPER_SNAKE_CASE | `MAX_RETRIES`, `DEFAULT_TIMEOUT` |
| Private members | _prefix | `_internal_method`, `_cache` |
| Type variables | Capitalized single letter | `T`, `E`, `KT`, `VT` |

### Domain-Specific Naming

```python
# Aggregates
class Monitor(AggregateRoot):
    ...

class Tenant(AggregateRoot):
    ...

# Entities
class Membership(Entity):
    ...

class CheckResult(Entity):
    ...

# Value Objects
class Email(ValueObject):
    ...

class Url(ValueObject):
    ...

class TenantId(ValueObject):
    ...

# Repositories (interface)
class IMonitorRepository(Protocol):
    ...

# Repository implementations
class MonitorRepositoryMayim:
    ...

# Commands
@dataclass
class CreateMonitorCommand:
    ...

@dataclass
class UpdateMonitorCommand:
    ...

# Queries
@dataclass
class GetMonitorByIdQuery:
    ...

# DTOs
@dataclass
class MonitorDto:
    ...

# Events
class MonitorCreatedEvent(DomainEvent):
    ...

class MonitorDownEvent(DomainEvent):
    ...

# Exceptions
class DomainError(Exception):
    ...

class MonitorNotFoundError(DomainError):
    ...

class UnauthorizedError(DomainError):
    ...
```

### Module Naming

- Use lowercase with underscores
- Match directory names to module names
- Avoid abbreviations except for well-known ones (id, url, http, api)

```python
# CORRECT
modules/
  check_execution/
  iam/

# INCORRECT
modules/
  chk_exec/
  identity_access_mgmt/
```

---

## File and Directory Structure

### File Naming

```
# Modules
modules/iam/domain/aggregates/user.py
modules/iam/domain/entities/membership.py

# Tests (mirror source structure)
tests/unit/modules/iam/domain/aggregates/test_user.py
tests/integration/modules/iam/infrastructure/persistence/test_user_repo.py

# Configuration
config/casbin/model.conf
config/casbin/policy.csv

# Scripts
scripts/migrate.py
scripts/seed.py
```

### File Length

- Maximum 500 lines per file
- If exceeded, consider splitting into submodules
- Exception: Test files may be longer for comprehensive coverage

### Module Exports

Use `__all__` for public API:

```python
# modules/iam/domain/aggregates/__init__.py
__all__ = ["User", "Tenant", "Membership"]

from .user import User
from .tenant import Tenant
from .membership import Membership
```

---

## Type Hints

### Requirements

- All function parameters must be typed
- All function return values must be typed
- All class attributes must be typed
- No `# type: ignore` without explicit justification

### Examples

```python
# CORRECT - Complete type annotations
async def create_monitor(
    cmd: CreateMonitorCommand,
    tenant_id: UUID,
    user_id: UUID,
) -> Result[Monitor, DomainError]:
    ...

# CORRECT - Generic types
class Repository(Generic[T]):
    async def save(self, entity: T) -> Result[None, RepositoryError]:
        ...

# CORRECT - Optional types
def get_user_name(user: User | None) -> str | None:
    ...

# INCORRECT - Missing types
async def create_monitor(cmd, tenant_id, user_id):  # FORBIDDEN
    ...
```

### Type Aliases

```python
# Define at module level for reuse
type UserId = UUID
type TenantId = UUID
type MonitorId = UUID

type CommandResult[T] = Result[T, CommandError]
type QueryResult[T] = Result[T, QueryError]
```

---

## Import Order

### Standard Order

```python
# 1. Standard library
import asyncio
from dataclasses import dataclass
from typing import Generic, TypeVar
from uuid import UUID

# 2. Third-party packages
import structlog
from dishka import Provider, Scope
from msgspec import Struct
from starlette.requests import Request

# 3. Shared kernel
from shared.kernel.result import Result, Ok, Err
from shared.kernel.context import tenant_ctx, user_ctx

# 4. Local imports (same module)
from .entities import Membership
from .value_objects import Email

# 5. Local imports (other modules)
from modules.iam.domain.aggregates import User
from modules.iam.domain.repositories import IUserRepository
```

### Import Style

```python
# CORRECT - One import per line
from dataclasses import dataclass
from typing import Generic
from typing import TypeVar

# INCORRECT - Multiple imports on one line
from dataclasses import dataclass, field  # FORBIDDEN

# CORRECT - Absolute imports
from modules.iam.domain.aggregates import User

# INCORRECT - Relative imports across modules
from ...iam.domain.aggregates import User  # FORBIDDEN
```

---

## Code Formatting

### Tool Configuration

All formatting is handled by Ruff. Configuration in `pyproject.toml`:

```toml
[tool.ruff]
line-length = 100
target-version = "py313"

[tool.ruff.format]
quote-style = "double"
indent-style = "space"
```

### General Rules

- Line length: 100 characters maximum
- Indentation: 4 spaces (no tabs)
- Quotes: Double quotes for strings
- Trailing commas: Required for multi-line structures
- Blank lines: 2 between classes, 1 between methods

### Examples

```python
# CORRECT
class MonitorService:
    def __init__(
        self,
        monitor_repo: IMonitorRepository,
        event_bus: EventBus,
    ) -> None:
        self.monitor_repo = monitor_repo
        self.event_bus = event_bus

    async def create(self, cmd: CreateMonitorCommand) -> Result[Monitor, DomainError]:
        ...


# INCORRECT - Wrong spacing
class MonitorService:
    def __init__(self,monitor_repo,event_bus)->None:  # FORBIDDEN
        ...
```

---

## Documentation Standards

### Docstrings

Use Google-style docstrings for all public functions and classes:

```python
async def create_monitor(
    self,
    cmd: CreateMonitorCommand,
    tenant_id: UUID,
) -> Result[Monitor, DomainError]:
    """
    Create a new monitor for the specified tenant.

    Args:
        cmd: Command containing monitor configuration
        tenant_id: Unique identifier for the tenant

    Returns:
        Ok containing the created Monitor, or Err with DomainError

    Raises:
        No exceptions raised. Errors returned via Result pattern.

    Example:
        >>> cmd = CreateMonitorCommand(url="https://example.com")
        >>> result = await service.create_monitor(cmd, tenant_id)
        >>> if result.is_success:
        ...     monitor = result.value
    """
```

### Module Docstrings

Every module must have a docstring:

```python
"""
Monitor domain aggregates.

This module contains the core business entities for the monitoring
functionality, including Monitor, CheckConfig, and related aggregates.
"""
```

### Comments

- Use sparingly; code should be self-documenting
- Explain WHY, not WHAT
- Use full sentences with proper punctuation

```python
# CORRECT - Explains reasoning
# Using asyncio.to_thread because pyCasbin is synchronous
# and we don't want to block the event loop
result = await asyncio.to_thread(enforcer.enforce, subject, resource, action)

# INCORRECT - States the obvious
# Call the enforce method
result = enforcer.enforce(subject, resource, action)
```

---

## Error Handling

### Result Pattern

All domain operations must use the Result pattern:

```python
# CORRECT
async def find_user(user_id: UUID) -> Result[User, UserNotFoundError]:
    user = await repo.get(user_id)
    if user is None:
        return Err(UserNotFoundError(user_id))
    return Ok(user)

# INCORRECT - Raising exceptions in domain
async def find_user(user_id: UUID) -> User:
    user = await repo.get(user_id)
    if user is None:
        raise UserNotFoundError(user_id)  # FORBIDDEN in domain layer
```

### Exception Hierarchy

```python
# Base exception
class DomainError(Exception):
    code: str = "UNKNOWN_ERROR"

# Specific errors
class ValidationError(DomainError):
    code = "VALIDATION_ERROR"

class NotFoundError(DomainError):
    code = "NOT_FOUND"

class UnauthorizedError(DomainError):
    code = "UNAUTHORIZED"

class PermissionDeniedError(DomainError):
    code = "PERMISSION_DENIED"
```

### Error Messages

- Include relevant context (ids, values)
- Do not expose internal implementation details
- Use consistent format

```python
# CORRECT
raise MonitorNotFoundError(f"Monitor {monitor_id} not found for tenant {tenant_id}")

# INCORRECT - Too vague
raise MonitorNotFoundError("Not found")

# INCORRECT - Exposes internals
raise MonitorNotFoundError(f"SQL query returned 0 rows for id {monitor_id}")
```

---

## Async Patterns

### Function Signatures

```python
# CORRECT - Async for I/O operations
async def save(self, entity: Monitor) -> Result[None, RepositoryError]:
    ...

# CORRECT - Sync for pure computation
def validate_url(self, url: str) -> Result[Url, ValidationError]:
    ...
```

### Context Propagation

```python
# CORRECT - Propagate context to background tasks
async def schedule_check(self, monitor: Monitor) -> None:
    ctx = contextvars.copy_context()
    await self.taskiq.kiq(ctx.run, self.execute_check, monitor.id)

# INCORRECT - Context lost in background
async def schedule_check(self, monitor: Monitor) -> None:
    await self.taskiq.kiq(self.execute_check, monitor.id)  # Context lost
```

### Blocking Operations

Wrap synchronous operations:

```python
# CORRECT
async def check_permission(self, user_id: str, resource: str) -> bool:
    return await asyncio.to_thread(self.enforcer.enforce, user_id, resource)

# INCORRECT - Blocks event loop
async def check_permission(self, user_id: str, resource: str) -> bool:
    return self.enforcer.enforce(user_id, resource)  # FORBIDDEN
```

### Timeout Handling

```python
# CORRECT - Always set timeouts for external calls
async def fetch_url(self, url: str) -> Result[Response, TimeoutError]:
    try:
        async with asyncio.timeout(30):
            response = await self.http_client.get(url)
            return Ok(response)
    except asyncio.TimeoutError:
        return Err(TimeoutError(f"Request to {url} timed out"))
```

---

## Database and Queries

### Repository Pattern

```python
# Interface in domain
class IMonitorRepository(Protocol):
    async def save(self, monitor: Monitor, tenant_id: UUID) -> Result[None, RepositoryError]:
        ...

    async def find_by_id(self, monitor_id: UUID, tenant_id: UUID) -> Result[Monitor, NotFoundError]:
        ...

# Implementation in infrastructure
class MonitorRepositoryMayim:
    def __init__(self, executor: Executor, tenant_id: UUID):
        self.executor = executor
        self.tenant_id = tenant_id  # Injected, never from user input
```

### Query Requirements

```python
# CORRECT - Tenant filter always included
async def find_by_id(self, monitor_id: UUID, tenant_id: UUID):
    row = await self.executor.select(
        "SELECT * FROM monitors WHERE id = $1 AND tenant_id = $2",
        monitor_id, tenant_id
    )

# INCORRECT - Missing tenant filter
async def find_by_id(self, monitor_id: UUID, tenant_id: UUID):
    row = await self.executor.select(
        "SELECT * FROM monitors WHERE id = $1",  # FORBIDDEN
        monitor_id
    )
```

### Transaction Handling

```python
# CORRECT - Explicit transaction boundaries
async def create_monitor_with_config(self, cmd: CreateMonitorCommand) -> Result[Monitor, DomainError]:
    async with self.executor.transaction():
        monitor_result = await self.save_monitor(cmd)
        if not monitor_result.is_success:
            return monitor_result

        config_result = await self.save_config(cmd, monitor_result.value.id)
        if not config_result.is_success:
            return config_result

        return monitor_result
```

---

## Testing Standards

### Test File Structure

```python
# tests/unit/modules/iam/domain/aggregates/test_user.py

class TestUser:
    """Test cases for User aggregate."""

    def test_create_valid_user(self) -> None:
        """User can be created with valid data."""
        user = User.create(email="test@example.com", password="secure")
        assert user.email.value == "test@example.com"

    def test_create_duplicate_email_raises_error(self) -> None:
        """Creating user with existing email returns error."""
        ...
```

### Test Naming

```
test_<entity>_<action>_<condition>_<expected>.py

Examples:
- test_monitor_create_invalid_url_returns_error.py
- test_user_repository_save_with_tenant_isolation.py
- test_rbac_middleware_allows_admin_access.py
```

### Fixtures

```python
# CORRECT - Descriptive fixture names
@pytest.fixture
def valid_tenant_id() -> UUID:
    return uuid6.uuid7()

@pytest.fixture
def create_monitor_command() -> CreateMonitorCommand:
    return CreateMonitorCommand(
        url="https://example.com",
        interval=60,
    )

# INCORRECT - Vague fixture names
@pytest.fixture
def data():  # FORBIDDEN
    ...
```

### Assertions

```python
# CORRECT - Specific assertions
assert result.is_success
assert result.value.id == monitor_id
assert isinstance(result.error, NotFoundError)

# INCORRECT - Generic assertions
assert result  # Too vague
assert type(result.error) == NotFoundError  # Use isinstance
```

---

## Logging

### Configuration

Use structlog for all logging:

```python
import structlog

logger = structlog.get_logger(__name__)
```

### Log Levels

| Level | Usage |
|-------|-------|
| DEBUG | Detailed technical information for debugging |
| INFO | Normal business operations (user created, monitor added) |
| WARNING | Recoverable issues (retry attempted, rate limit approaching) |
| ERROR | Failures requiring attention (database error, external service down) |
| CRITICAL | System-wide issues (service unavailable, data corruption) |

### Log Format

```python
# CORRECT - Structured logging with context
logger.info(
    "monitor_created",
    monitor_id=str(monitor.id),
    tenant_id=str(tenant_id),
    user_id=str(user_id),
)

# INCORRECT - Unstructured logging
logger.info(f"Monitor {monitor.id} created by {user_id}")  # FORBIDDEN
```

### Sensitive Data

```python
# CORRECT - Never log sensitive data
logger.info("user_authenticated", user_id=str(user_id))

# INCORRECT - Logging sensitive information
logger.info("user_login", email=user.email, password=user.password)  # FORBIDDEN
```

---

## Security

### Authentication

- All endpoints require authentication except explicitly documented public endpoints
- JWT tokens must be validated on every request
- Token expiration must be enforced

### Authorization

- Use Casbin for all authorization decisions
- Never bypass authorization checks
- Log all authorization failures

### Input Validation

```python
# CORRECT - Validate all inputs
@dataclass
class CreateMonitorCommand:
    url: str
    interval: int

    def validate(self) -> Result[None, ValidationError]:
        if not self.url.startswith("http"):
            return Err(ValidationError("URL must start with http"))
        if self.interval < 30:
            return Err(ValidationError("Interval must be at least 30 seconds"))
        return Ok(None)

# INCORRECT - No validation
@dataclass
class CreateMonitorCommand:
    url: str
    interval: int
```

### SQL Injection Prevention

```python
# CORRECT - Use parameterized queries
row = await self.executor.select(
    "SELECT * FROM monitors WHERE id = $1 AND tenant_id = $2",
    monitor_id, tenant_id
)

# INCORRECT - String interpolation
query = f"SELECT * FROM monitors WHERE id = '{monitor_id}'"  # FORBIDDEN
```

---

## Git Conventions

### Commit Messages

Follow conventional commits:

```
<type>(<scope>): <subject>

<body>

<footer>
```

### Types

| Type | Description |
|------|-------------|
| feat | New feature |
| fix | Bug fix |
| docs | Documentation changes |
| style | Formatting, no code changes |
| refactor | Code restructuring, no behavior change |
| test | Adding or modifying tests |
| chore | Maintenance, dependencies |

### Examples

```bash
# CORRECT
feat(monitoring): add monitor creation endpoint
fix(iam): resolve tenant isolation bug in user repository
docs: update API documentation for authentication
test(check_execution): add integration tests for worker
refactor(notifications): extract email sender to separate service

# INCORRECT
added new stuff  # Too vague
fixed bug  # No context
WIP  # Do not commit work in progress
```

### Branch Naming

```
<type>/<description>

Examples:
- feat/monitor-crud-endpoints
- fix/tenant-isolation-query
- docs/api-authentication
- refactor/notification-service
```

### Pull Request Requirements

- [ ] All tests passing
- [ ] Coverage meets 85% threshold
- [ ] Type checking passes (mypy)
- [ ] Linting passes (ruff)
- [ ] Security scan passes (bandit, pip-audit)
- [ ] Documentation updated
- [ ] Commit messages follow convention

---

## Configuration Files

### pyproject.toml

All tool configuration should be in `pyproject.toml`:

```toml
[tool.mypy]
python_version = "3.13"
strict = true
disallow_any_generics = true
warn_return_any = true

[tool.pytest.ini_options]
asyncio_mode = "auto"
testpaths = ["tests"]
markers = [
    "unit: Unit tests",
    "integration: Integration tests",
    "e2e: End-to-end tests",
]

[tool.coverage.run]
source = ["src"]
omit = ["*/tests/*", "*/__pycache__/*"]
```

### Environment Variables

```bash
# Required for all environments
DATABASE_URL=
JWT_SECRET=
LOG_LEVEL=

# Required for production
CASBIN_MODEL_PATH=
CASBIN_POLICY_PATH=

# Optional
DEBUG=
PROFILING_ENABLED=
```

---

## Code Review Checklist

Before submitting code for review:

- [ ] Follows all naming conventions
- [ ] All functions have type annotations
- [ ] All public functions have docstrings
- [ ] Error handling uses Result pattern
- [ ] All queries include tenant_id filter
- [ ] No sensitive data in logs
- [ ] Tests cover success and failure paths
- [ ] No hardcoded values
- [ ] Imports are ordered correctly
- [ ] No unused imports or variables
- [ ] Line length under 100 characters
- [ ] Commit message follows convention

---

## Enforcement

### Automated Checks

The following checks run automatically on every commit:

1. Ruff (linting and formatting)
2. Mypy (type checking)
3. Pytest (unit tests)
4. Bandit (security)
5. Pre-commit hooks

### Manual Review

The following require manual review:

1. Architecture changes
2. Security-critical code
3. Database schema changes
4. Public API changes

### Violations

Code that violates this style guide will not be merged. Exceptions require:

1. Written justification in PR description
2. Approval from maintainers
3. Documentation of the exception in this file

---

<div align="center">

Last updated: 2025

[Back to README](README.md) | [Agents Guide](AGENTS.md)

</div>
