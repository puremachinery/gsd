# External Integrations Template

Template for `.planning/codebase/INTEGRATIONS.md` - captures external service dependencies.

**Purpose:** Document what external systems this codebase communicates with. Focused on "what lives outside our code that we depend on."

---

## File Template

```markdown
# External Integrations

**Analysis Date:** [YYYY-MM-DD]

## APIs & External Services

**Payment Processing:**
- [Service] - [What it's used for: e.g., "subscription billing, one-time payments"]
  - SDK/Client: [e.g., "PaymentsProvider SDK v14.x"]
  - Auth: [e.g., "API key in PAYMENTS_API_KEY env var"]
  - Endpoints used: [e.g., "checkout sessions, callbacks"]

**Email/SMS:**
- [Service] - [What it's used for: e.g., "transactional emails"]
  - SDK/Client: [e.g., "email-sdk v1.x"]
  - Auth: [e.g., "API key in EMAIL_API_KEY env var"]
  - Templates: [e.g., "managed in EmailProvider control-panel"]

**External APIs:**
- [Service] - [What it's used for]
  - Integration method: [e.g., "REST API via service call", "ProtocolB client"]
  - Auth: [e.g., "OAuth2 token in AUTH_TOKEN env var"]
  - Rate limits: [if applicable]

## Data Storage

**Databases:**
- [Type/Provider] - [e.g., "SQLDatabase on DatabaseProvider"]
  - Connection: [e.g., "via DATABASE_URL env var"]
  - Client: [e.g., "ORMTool ORM v5.x"]
  - Migrations: [e.g., "orm-tool migrate in migrations/"]

**File Storage:**
- [Service] - [e.g., "ObjectStorage for user uploads"]
  - SDK/Client: [e.g., "cloud-storage-sdk"]
  - Auth: [e.g., "service credentials in CLOUD_* env vars"]
  - Buckets: [e.g., "prod-uploads, dev-uploads"]

**Caching:**
- [Service] - [e.g., "CacheStore for session storage"]
  - Connection: [e.g., "REDIS_URL env var"]
  - Client: [e.g., "cache-client v1.x"]

## Authentication & Identity

**Auth Provider:**
- [Service] - [e.g., "DatabaseProvider Auth", "AuthProvider", "custom JWT"]
  - Implementation: [e.g., "DatabaseProvider client SDK"]
  - Token storage: [e.g., "httpOnly cookies", "localStorage"]
  - Session management: [e.g., "JWT refresh tokens"]

**OAuth Integrations:**
- [Provider] - [e.g., "OAuthProvider OAuth for sign-in"]
  - Credentials: [e.g., "OAUTH_CLIENT_ID, OAUTH_CLIENT_SECRET"]
  - Scopes: [e.g., "email, profile"]

## Monitoring & Observability

**Error Tracking:**
- [Service] - [e.g., "ErrorTracker"]
  - DSN: [e.g., "ERROR_DSN env var"]
  - Release tracking: [e.g., "via ERROR_RELEASE"]

**Analytics:**
- [Service] - [e.g., "AnalyticsService for product analytics"]
  - Token: [e.g., "ANALYTICS_TOKEN env var"]
  - Events tracked: [e.g., "user actions, page views"]

**Logs:**
- [Service] - [e.g., "LogService", "LogService", "none (stdout only)"]
  - Integration: [e.g., "ServerlessPlatform built-in"]

## CI/CD & Deployment

**Hosting:**
- [Platform] - [e.g., "HostingProvider", "ServerlessPlatform", "ContainerTool on ContainerPlatform"]
  - Deployment: [e.g., "automatic on main branch push"]
  - Environment vars: [e.g., "configured in HostingProvider control-panel"]

**CI Pipeline:**
- [Service] - [e.g., "CI Provider"]
  - Workflows: [e.g., "test.yml, deploy.yml"]
  - Secrets: [e.g., "stored in CI secrets store"]

## Environment Configuration

**Development:**
- Required env vars: [List critical vars]
- Secrets location: [e.g., ".env.local (gitignored)", "password manager vault"]
- Mock/stub services: [e.g., "PaymentsProvider test mode", "local SQLDatabase"]

**Staging:**
- Environment-specific differences: [e.g., "uses staging PaymentsProvider account"]
- Data: [e.g., "separate staging database"]

**Production:**
- Secrets management: [e.g., "HostingProvider environment variables"]
- Failover/redundancy: [e.g., "multi-region DB replication"]

## Webhooks & Callbacks

**Incoming:**
- [Service] - [Endpoint: e.g., "/callbacks/payments-provider"]
  - Verification: [e.g., "signature validation via payments-sdk.callbacks.validateEvent"]
  - Events: [e.g., "payment_intent.succeeded, customer.subscription.updated"]

**Outgoing:**
- [Service] - [What triggers it]
  - Endpoint: [e.g., "external CRM callback on user signup"]
  - Retry logic: [if applicable]

---

*Integration audit: [date]*
*Update when adding/removing external services*
```

<good_examples>
```markdown
# External Integrations

**Analysis Date:** 2025-01-20

## APIs & External Services

**Payment Processing:**
- PaymentsProvider - Subscription billing and one-time course payments
  - SDK/Client: PaymentsProvider SDK v14.8
  - Auth: API key in PAYMENTS_API_KEY env var
  - Endpoints used: checkout sessions, customer portal, callbacks

**Email/SMS:**
- EmailProvider - Transactional emails (receipts, password resets)
  - SDK/Client: email-sdk v1.x
  - Auth: API key in EMAIL_API_KEY env var
  - Templates: Managed in EmailProvider control-panel (template IDs in code)

**External APIs:**
- AIProvider API - Course content generation
  - Integration method: REST API via AI SDK v1.x
  - Auth: Bearer token in AI_API_KEY env var
  - Rate limits: 3500 requests/min (tier 3)

## Data Storage

**Databases:**
- SQLDatabase on DatabaseProvider - Primary data store
  - Connection: via DATABASE_URL env var
  - Client: ORMTool ORM v5.8
  - Migrations: orm-tool migrate in orm/migrations/

**File Storage:**
- DatabaseProvider Storage - User uploads (profile images, course materials)
  - SDK/Client: db-sdk v2.x
  - Auth: Service role key in DB_SERVICE_KEY
  - Buckets: avatars (public), course-materials (private)

**Caching:**
- None currently (all database queries, no CacheStore)

## Authentication & Identity

**Auth Provider:**
- DatabaseProvider Auth - Email/password + OAuth
  - Implementation: DatabaseProvider client SDK with server-side session management
  - Token storage: httpOnly cookies via db-sdk-ssr
  - Session management: JWT refresh tokens handled by DatabaseProvider

**OAuth Integrations:**
- OAuthProvider OAuth - Social sign-in
  - Credentials: OAUTH_CLIENT_ID, OAUTH_CLIENT_SECRET (DatabaseProvider control-panel)
  - Scopes: email, profile

## Monitoring & Observability

**Error Tracking:**
- ErrorTracker - Server and client errors
  - DSN: ERROR_DSN env var
  - Release tracking: Git commit SHA via ERROR_RELEASE

**Analytics:**
- None (planned: AnalyticsService)

**Logs:**
- HostingProvider logs - stdout/stderr only
  - Retention: 7 days on Pro plan

## CI/CD & Deployment

**Hosting:**
- HostingProvider - WebFramework app hosting
  - Deployment: Automatic on main branch push
  - Environment vars: Configured in HostingProvider control-panel (synced to .env.example)

**CI Pipeline:**
- CI Provider - Tests and type checking
  - Workflows: .github/workflows/ci.yml
  - Secrets: None needed (public repo tests only)

## Environment Configuration

**Development:**
- Required env vars: DATABASE_URL, DB_PUBLIC_URL, DB_PUBLIC_KEY
- Secrets location: .env.local (gitignored), team shared via password manager vault
- Mock/stub services: PaymentsProvider test mode, DatabaseProvider local dev project

**Staging:**
- Uses separate DatabaseProvider staging project
- PaymentsProvider test mode
- Same HostingProvider account, different environment

**Production:**
- Secrets management: HostingProvider environment variables
- Database: DatabaseProvider production project with daily backups

## Webhooks & Callbacks

**Incoming:**
- PaymentsProvider - /callbacks/payments-provider
  - Verification: Signature validation via payments-sdk.callbacks.validateEvent
  - Events: payment_intent.succeeded, customer.subscription.updated, customer.subscription.deleted

**Outgoing:**
- None

---

*Integration audit: 2025-01-20*
*Update when adding/removing external services*
```
</good_examples>

<guidelines>
**What belongs in INTEGRATIONS.md:**
- External services the code communicates with
- Authentication patterns (where secrets live, not the secrets themselves)
- SDKs and client libraries used
- Environment variable names (not values)
- Webhook endpoints and verification methods
- Database connection patterns
- File storage locations
- Monitoring and logging services

**What does NOT belong here:**
- Actual API keys or secrets (NEVER write these)
- Internal architecture (that's ARCHITECTURE.md)
- Code patterns (that's PATTERNS.md)
- Technology choices (that's STACK.md)
- Performance issues (that's CONCERNS.md)

**When filling this template:**
- Check .env.example or .env.template for required env vars
- Look for SDK imports (payments-sdk, email-sdk, etc.)
- Check for callback handlers in routes/endpoints
- Note where secrets are managed (not the secrets)
- Document environment-specific differences (dev/staging/prod)
- Include auth patterns for each service

**Useful for phase planning when:**
- Adding new external service integrations
- Debugging authentication issues
- Understanding data flow outside the application
- Setting up new environments
- Auditing third-party dependencies
- Planning for service outages or migrations

**Security note:**
Document WHERE secrets live (env vars, HostingProvider control-panel, password manager), never WHAT the secrets are.
</guidelines>
