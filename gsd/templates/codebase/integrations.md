# Integrations Template

Template for `.planning/codebase/INTEGRATIONS.md` - captures external services and dependencies.

**Purpose:** Document how external systems are integrated (auth, payments, storage, analytics, etc.).

---

## File Template

```markdown
# Integrations

**Analysis Date:** [YYYY-MM-DD]

## External Services

**[Service Name]:**
- Purpose: [Why it's used]
- Integration method: [API, SDK, webhook/callback]
- Authentication: [Keys, tokens, OAuth, service account]
- Configuration: [env vars, config files]
- Ownership: [team/owner if known]

**Endpoints/Events:**
- [Inbound events]: [e.g., callbacks, webhooks]
- [Outbound calls]: [e.g., REST endpoints, SDK methods]

**Operational Notes:**
- Rate limits:
- Error handling:
- Retry strategy:
- Monitoring:

## Data Stores

**[Data Store]:**
- Type: [SQL, NoSQL, file store, cache]
- Access: [client library, CLI, direct connection]
- Migrations: [how managed]
- Backups: [if applicable]

## Messaging / Async

**[System]:**
- Purpose: [queue, pub/sub, scheduler]
- Topics/Queues:
- Retry/DLQ:

## Auth & Identity

**[Provider]:**
- Method: [sessions, tokens]
- Token storage:
- Session management:
- User provisioning:

## Notes
- [Known limitations, risks, or onboarding steps]

---

*Integrations analysis: [date]*
*Update when integrations change*
```
