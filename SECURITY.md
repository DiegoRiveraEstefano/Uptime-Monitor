# SECURITY.md

## Security Policy

### Supported Versions

| Version | Supported | End of Support |
|---------|-----------|----------------|
| 0.1.x   | Yes       | Current        |
| 0.0.x   | No        | Deprecated     |

### Reporting a Vulnerability

We take security vulnerabilities seriously. If you discover a security issue, please follow this process:

1. **Do not** open a public issue on GitHub
2. Send an email to security@uptime-monitor.dev with:
   - Description of the vulnerability
   - Steps to reproduce the issue
   - Potential impact assessment
   - Any suggested fixes (optional)
3. You will receive a response within 48 hours acknowledging receipt
4. We will provide updates every 7 days until the issue is resolved
5. Once fixed, we will coordinate disclosure with you

### Security Response Timeline

| Severity | Response Time | Fix Target |
|----------|---------------|------------|
| Critical | 24 hours | 7 days |
| High | 48 hours | 14 days |
| Medium | 7 days | 30 days |
| Low | 14 days | 60 days |

---

## Table of Contents

1. [Authentication](#authentication)
2. [Authorization](#authorization)
3. [Multi-Tenant Isolation](#multi-tenant-isolation)
4. [Data Protection](#data-protection)
5. [Input Validation](#input-validation)
6. [Security Headers](#security-headers)
7. [Logging and Monitoring](#logging-and-monitoring)
8. [Dependency Management](#dependency-management)
9. [Secure Configuration](#secure-configuration)
10. [Incident Response](#incident-response)
11. [Compliance](#compliance)

---

## Authentication

### JWT Token Requirements

All API endpoints require JWT authentication unless explicitly documented as public.

```python
# Token payload structure
{
    "sub": "user-uuid",
    "tenant_id": "tenant-uuid",
    "roles": ["admin", "member"],
    "iat": 1234567890,
    "exp": 1234568790,
    "iss": "uptime-monitor",
    "aud": "uptime-monitor-api"
}
```

### Token Configuration

| Setting | Value | Description |
|---------|-------|-------------|
| Algorithm | HS256 | Signing algorithm |
| Access Token Expiry | 15 minutes | Short-lived access tokens |
| Refresh Token Expiry | 7 days | Long-lived refresh tokens |
| Issuer | uptime-monitor | Token issuer identifier |
| Audience | uptime-monitor-api | Token audience identifier |

### Password Requirements

```python
# Minimum password requirements
MIN_LENGTH = 12
REQUIRE_UPPERCASE = True
REQUIRE_LOWERCASE = True
REQUIRE_DIGIT = True
REQUIRE_SPECIAL = True

# Password hashing
ALGORITHM = "bcrypt"
ROUNDS = 12  # Minimum bcrypt rounds
```

### Authentication Endpoints

| Endpoint | Method | Auth Required | Description |
|----------|--------|---------------|-------------|
| /api/v1/auth/login | POST | No | User authentication |
| /api/v1/auth/refresh | POST | No | Token refresh |
| /api/v1/auth/logout | POST | Yes | Token invalidation |
| /api/v1/auth/register | POST | No | User registration |

### Security Measures

- Rate limiting on authentication endpoints (5 attempts per minute)
- Account lockout after 10 failed attempts
- Password reset tokens expire after 1 hour
- All authentication attempts are logged
- Refresh tokens are single-use and rotated

---

## Authorization

### RBAC Model

Authorization is implemented using Casbin with domain-based RBAC for multi-tenant support.

```ini
# Casbin model configuration
[request_definition]
r = sub, dom, obj, act

[policy_definition]
p = sub, dom, obj, act

[role_definition]
g = _, _, _

[policy_effect]
e = some(where (p.eft == allow))

[matchers]
m = g(r.sub, p.sub, r.dom) && r.dom == p.dom && keyMatch2(r.obj, p.obj)
```

### Default Roles

| Role | Permissions | Scope |
|------|-------------|-------|
| owner | Full access | Tenant |
| admin | CRUD operations, member management | Tenant |
| member | Read and limited create | Tenant |
| viewer | Read only | Tenant |

### Policy Storage

- Policies are stored in the database with tenant isolation
- Policy changes are logged in the audit trail
- Policy cache is invalidated on changes
- Default policies are version-controlled

### Authorization Checks

```python
# All protected endpoints require authorization
# Middleware layer (HTTP)
async def rbac_middleware(request: Request, call_next):
    # Extract user, tenant, roles from JWT
    # Check permissions via Casbin
    # Deny if not authorized

# Domain layer (Business rules)
async def delete_monitor(monitor_id: UUID, user_id: UUID, tenant_id: UUID):
    # Additional business rule validation
    # e.g., only owner can delete active monitors
```

---

## Multi-Tenant Isolation

### Data Isolation Strategy

**Single Database, Row-Level Isolation**

All tenant data is stored in shared database tables with mandatory tenant_id filtering.

```python
# Every query MUST include tenant_id filter
SELECT * FROM monitors
WHERE id = $1 AND tenant_id = $2  # tenant_id is non-negotiable

# Repository implementation enforces this
class MonitorRepository:
    def __init__(self, executor: Executor, tenant_id: UUID):
        self.tenant_id = tenant_id  # Injected from verified JWT

    async def find_by_id(self, monitor_id: UUID):
        # tenant_id automatically included in all queries
        return await self.executor.select(
            "SELECT * FROM monitors WHERE id = $1 AND tenant_id = $2",
            monitor_id, self.tenant_id
        )
```

### Tenant Isolation Checklist

- [ ] All database queries include tenant_id filter
- [ ] tenant_id extracted from verified JWT (never from user input)
- [ ] Repository constructors require tenant_id parameter
- [ ] Background tasks propagate tenant context
- [ ] API responses filtered by tenant context
- [ ] Cross-tenant access attempts logged and alerted

### Isolation Testing

```python
# Integration test for tenant isolation
@pytest.mark.integration
async def test_tenant_isolation():
    # Create data for tenant A
    await repo.save(monitor_a, tenant_id=tenant_a_id)

    # Query with tenant B context
    result = await repo.find_by_id(monitor_a.id, tenant_id=tenant_b_id)

    # Must return NotFound, not tenant A's data
    assert isinstance(result, Err)
    assert isinstance(result.error, NotFoundError)
```

---

## Data Protection

### Encryption at Rest

| Data Type | Encryption | Algorithm |
|-----------|------------|-----------|
| Passwords | Hash | bcrypt (12 rounds) |
| JWT Secrets | Encrypted | AES-256-GCM |
| Sensitive Config | Encrypted | AES-256-GCM |
| Database | Optional | TDE/Column-level |

### Encryption in Transit

- All API endpoints require HTTPS/TLS
- Minimum TLS version: 1.2
- Recommended TLS version: 1.3
- HSTS enabled with 1-year max-age
- Certificate pinning for internal services

### Sensitive Data Handling

```python
# CORRECT - Never log sensitive data
logger.info("user_authenticated", user_id=str(user_id))

# INCORRECT - Logging sensitive information
logger.info("user_login", email=user.email, password=user.password)  # FORBIDDEN

# CORRECT - Mask sensitive data in responses
def mask_email(email: str) -> str:
    parts = email.split("@")
    return f"{parts[0][:2]}***@{parts[1]}"
```

### Data Retention

| Data Type | Retention Period | Deletion Method |
|-----------|------------------|-----------------|
| Audit Logs | 2 years | Soft delete |
| User Data | Account lifetime | Hard delete on request |
| Monitor History | 90 days | Automatic purge |
| Incident Records | 1 year | Soft delete |
| Session Tokens | 7 days | Automatic expiration |

---

## Input Validation

### Request Validation

All incoming requests must be validated before processing:

```python
# Using msgspec for schema validation
class CreateMonitorRequest(Struct):
    url: str
    interval: int
    timeout: int
    name: str

    # Validation rules
    def __post_init__(self):
        if not self.url.startswith(("http://", "https://")):
            raise ValidationError("URL must start with http:// or https://")
        if self.interval < 30 or self.interval > 86400:
            raise ValidationError("Interval must be between 30 and 86400 seconds")
        if self.timeout > self.interval:
            raise ValidationError("Timeout cannot exceed interval")
```

### Validation Rules

| Field | Type | Min | Max | Pattern |
|-------|------|-----|-----|---------|
| URL | string | - | 2048 chars | ^https?:// |
| Interval | integer | 30 | 86400 | - |
| Timeout | integer | 5 | 300 | - |
| Email | string | - | 254 chars | RFC 5322 |
| Password | string | 12 | 128 chars | Complexity rules |
| Tenant ID | UUID | - | - | UUID v7 |

### SQL Injection Prevention

```python
# CORRECT - Parameterized queries
row = await self.executor.select(
    "SELECT * FROM monitors WHERE id = $1 AND tenant_id = $2",
    monitor_id, tenant_id
)

# INCORRECT - String interpolation (FORBIDDEN)
query = f"SELECT * FROM monitors WHERE id = '{monitor_id}'"
```

### XSS Prevention

- All responses use Content-Type: application/json
- No HTML rendering in API responses
- Input sanitization for webhook payloads
- Output encoding for any user-generated content

---

## Security Headers

### Required HTTP Headers

All API responses must include these security headers:

```http
# Security Headers
Strict-Transport-Security: max-age=31536000; includeSubDomains
X-Content-Type-Options: nosniff
X-Frame-Options: DENY
X-XSS-Protection: 1; mode=block
Content-Security-Policy: default-src 'none'
Cache-Control: no-store, no-cache, must-revalidate
```

### CORS Configuration

```python
# CORS settings for API
ALLOWED_ORIGINS = [
    "https://app.uptime-monitor.dev",
    "https://admin.uptime-monitor.dev",
]

ALLOWED_METHODS = ["GET", "POST", "PUT", "DELETE", "PATCH"]
ALLOWED_HEADERS = ["Authorization", "Content-Type", "X-Tenant-ID"]
EXPOSED_HEADERS = ["X-Request-ID", "X-RateLimit-Remaining"]
MAX_AGE = 600  # 10 minutes
```

---

## Logging and Monitoring

### Security Event Logging

The following events must be logged:

| Event | Level | Fields |
|-------|-------|--------|
| Authentication success | INFO | user_id, tenant_id, ip |
| Authentication failure | WARNING | email, ip, reason |
| Authorization failure | WARNING | user_id, resource, action |
| Cross-tenant access attempt | ERROR | user_id, from_tenant, to_tenant |
| Password reset request | INFO | user_id, ip |
| Account lockout | ERROR | user_id, ip, attempts |
| API rate limit exceeded | WARNING | user_id, endpoint, limit |

### Log Security

```python
# CORRECT - Structured logging without sensitive data
logger.info(
    "authentication_attempt",
    user_id=str(user_id),
    tenant_id=str(tenant_id),
    success=True,
    ip_address=masked_ip,
)

# Log retention and rotation
RETENTION_DAYS = 90
ROTATION_SIZE = "100MB"
COMPRESSION = "gzip"
```

### Monitoring Alerts

| Alert | Trigger | Response |
|-------|---------|----------|
| High auth failure rate | >10 failures/minute/user | Investigate brute force |
| Cross-tenant access | Any attempt | Immediate investigation |
| Unusual API patterns | Anomaly detection | Review access logs |
| Dependency vulnerabilities | CVE published | Patch within SLA |

---

## Dependency Management

### Security Scanning

All dependencies are scanned for vulnerabilities:

```bash
# Automated security checks
uv run bandit -r src/           # Code security
uv run pip-audit                 # Dependency vulnerabilities
uv run safety check              # Alternative vulnerability scan
```

### Dependency Update Policy

| Severity | Update Timeline |
|----------|-----------------|
| Critical | 24 hours |
| High | 7 days |
| Medium | 30 days |
| Low | 90 days |

### Approved Dependencies

Only dependencies from the following sources are allowed:

- PyPI (verified packages)
- GitHub (verified repositories)
- Internal package registry

### Dependency Pinning

All dependencies must be pinned to exact versions:

```toml
# pyproject.toml
[project]
dependencies = [
    "starlette==1.0.0",      # Exact version
    "pyjwt==2.12.1",         # Exact version
    "bcrypt==5.0.0",         # Exact version
]
```

---

## Secure Configuration

### Environment Variables

Sensitive configuration must be stored in environment variables:

```bash
# Required security environment variables
JWT_SECRET=<secure-random-32-bytes>
DATABASE_URL=<connection-string-with-ssl>
CASBIN_MODEL_PATH=<path-to-model>
CASBIN_POLICY_PATH=<path-to-policy>
ENCRYPTION_KEY=<aes-256-key>

# Optional security settings
RATE_LIMIT_ENABLED=true
AUDIT_LOG_ENABLED=true
SECURITY_HEADERS_ENABLED=true
```

### Configuration Validation

```python
# Validate security configuration on startup
class SecurityConfig(Settings):
    jwt_secret: str
    jwt_algorithm: str = "HS256"
    token_expiry_minutes: int = 15
    bcrypt_rounds: int = 12

    @validator("jwt_secret")
    def validate_jwt_secret(cls, v):
        if len(v) < 32:
            raise ValueError("JWT secret must be at least 32 characters")
        return v

    @validator("bcrypt_rounds")
    def validate_bcrypt_rounds(cls, v):
        if v < 10:
            raise ValueError("bcrypt rounds must be at least 10")
        return v
```

### Secrets Management

- Never commit secrets to version control
- Use environment variables or secrets manager
- Rotate secrets every 90 days
- Audit secret access

---

## Incident Response

### Incident Classification

| Severity | Description | Examples |
|----------|-------------|----------|
| P1 - Critical | Active breach, data exposure | Unauthorized data access, credential leak |
| P2 - High | Security control failure | Auth bypass, privilege escalation |
| P3 - Medium | Potential vulnerability | XSS, CSRF in non-critical paths |
| P4 - Low | Minor security issue | Information disclosure, missing headers |

### Response Procedure

```
1. Detection
   └── Automated alert or manual report

2. Triage
   └── Classify severity, assign responder

3. Containment
   └── Isolate affected systems, revoke access

4. Investigation
   └── Root cause analysis, scope assessment

5. Remediation
   └── Fix vulnerability, patch systems

6. Recovery
   └── Restore services, verify security

7. Post-Incident
   └── Documentation, lessons learned
```

### Communication Plan

| Audience | Channel | Timeline |
|----------|---------|----------|
| Security Team | Internal chat | Immediate |
| Management | Email | Within 4 hours |
| Affected Users | Email/In-app | Within 72 hours (if data exposed) |
| Public | Status page/Blog | After containment |

---

## Compliance

### Data Protection

- GDPR compliance for EU users
- Data residency options available
- Right to deletion supported
- Data portability supported

### Audit Requirements

| Requirement | Implementation |
|-------------|----------------|
| Access logs | All API requests logged |
| Change tracking | Audit trail for critical operations |
| User consent | Explicit consent for data processing |
| Data minimization | Only collect necessary data |

### Security Certifications (Planned)

- [ ] SOC 2 Type II
- [ ] ISO 27001
- [ ] GDPR Compliance

---

## Security Checklist

### Pre-Deployment

- [ ] All dependencies scanned for vulnerabilities
- [ ] Security headers configured
- [ ] TLS/SSL enabled and configured
- [ ] Rate limiting enabled
- [ ] Audit logging enabled
- [ ] Secrets rotated from defaults
- [ ] Penetration testing completed
- [ ] Security review completed

### Post-Deployment

- [ ] Monitoring alerts configured
- [ ] Incident response plan documented
- [ ] Backup and recovery tested
- [ ] Security metrics tracked
- [ ] Regular security audits scheduled

### Ongoing

- [ ] Dependency updates reviewed weekly
- [ ] Security logs reviewed daily
- [ ] Access reviews quarterly
- [ ] Penetration testing annually
- [ ] Security training for team

---

## Contact

### Security Team

- **Email:** security@uptime-monitor.dev
- **PGP Key:** Available on request
- **Response Time:** Within 48 hours

### Bug Bounty Program

Currently not accepting external bug bounty submissions. Critical vulnerabilities will be acknowledged in security advisories with reporter permission.

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2025-01-01 | Initial security policy |
| 1.1.0 | 2025-01-15 | Added multi-tenant isolation section |
| 1.2.0 | 2025-02-01 | Updated dependency management policy |

---

<div align="center">

Last updated: 2025

[Back to README](README.md) | [Agents Guide](AGENTS.md) | [Style Guide](STYLE_GUIDE.md)

</div>
