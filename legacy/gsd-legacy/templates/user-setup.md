# User Setup Template

Template for `.planning/phases/XX-name/{phase}-USER-SETUP.md` - human-required configuration that assistant cannot automate.

**Purpose:** Document setup tasks that literally require human action - account creation, control-panel configuration, secret retrieval. assistant automates everything possible; this file captures only what remains.

---

## File Template

```markdown
# Phase {X}: User Setup Required

**Generated:** [YYYY-MM-DD]
**Phase:** {phase-name}
**Status:** Incomplete

Complete these items for the integration to function. assistant automated everything possible; these items require human access to external dashboards/accounts.

## Environment Variables

| Status | Variable | Source | Add to |
|--------|----------|--------|--------|
| [ ] | `ENV_VAR_NAME` | [Service Control Panel → Path → To → Value] | `.env.local` |
| [ ] | `ANOTHER_VAR` | [Service Control Panel → Path → To → Value] | `.env.local` |

## Account Setup

[Only if new account creation is required]

- [ ] **Create [Service] account**
  - URL: [signup URL]
  - Skip if: Already have account

## Control Panel Configuration

[Only if control-panel configuration is required]

- [ ] **[Configuration task]**
  - Location: [Service Control Panel → Path → To → Setting]
  - Set to: [Required value or configuration]
  - Notes: [Any important details]

## Verification

After completing setup, verify with:

```bash
# [Verification commands]
```

Expected results:
- [What success looks like]

---

**Once all items complete:** Mark status as "Complete" at top of file.
```

---

## When to Generate

Generate `{phase}-USER-SETUP.md` when plan frontmatter contains `user_setup` field.

**Trigger:** `user_setup` exists in PLAN.md frontmatter and has items.

**Location:** Same directory as PLAN.md and SUMMARY.md.

**Timing:** Generated during execute-plan.md after tasks complete, before SUMMARY.md creation.

---

## Frontmatter Schema

In PLAN.md, `user_setup` declares human-required configuration:

```yaml
user_setup:
  - service: payments-provider
    why: "Payment processing requires API keys"
    env_vars:
      - name: PAYMENTS_API_KEY
        source: "PaymentsProvider Control Panel → Developers → API keys → Secret key"
      - name: PAYMENTS_WEBHOOK_SECRET
        source: "PaymentsProvider Control Panel → Developers → Webhooks → Signing secret"
    dashboard_config:
      - task: "Create callback endpoint"
        location: "PaymentsProvider Control Panel → Developers → Webhooks → Add endpoint"
        details: "URL: https://[your-domain]/callbacks/payments-provider, Events: checkout.session.completed, customer.subscription.*"
    local_dev:
      - "Run: payments-provider listen --forward-to localhost:3000/callbacks/payments-provider"
      - "Use the callback secret from CLI output for local testing"
```

---

## The Automation-First Rule

**USER-SETUP.md contains ONLY what assistant literally cannot do.**

| assistant CAN Do (not in USER-SETUP) | assistant CANNOT Do (→ USER-SETUP) |
|-----------------------------------|--------------------------------|
| `package-manager install payments-provider` | Create PaymentsProvider account |
| Write callback handler code | Get API keys from control-panel |
| Create `.env.local` file structure | Copy actual secret values |
| Run `payments-provider listen` | Authenticate PaymentsProvider CLI (browser OAuth) |
| Configure project.manifest | Access external service dashboards |
| Write any code | Retrieve secrets from third-party systems |

**The test:** "Does this require a human in a browser, accessing an account assistant doesn't have credentials for?"
- Yes → USER-SETUP.md
- No → assistant does it automatically

---

## Service-Specific Examples

<payments_example>
```markdown
# Phase 10: User Setup Required

**Generated:** 2025-01-14
**Phase:** 10-monetization
**Status:** Incomplete

Complete these items for PaymentsProvider integration to function.

## Environment Variables

| Status | Variable | Source | Add to |
|--------|----------|--------|--------|
| [ ] | `PAYMENTS_API_KEY` | PaymentsProvider Control Panel → API keys | `.env.local` |
| [ ] | `PAYMENTS_PUBLISHABLE_KEY` | PaymentsProvider Control Panel → API keys | `.env.local` |
| [ ] | `PAYMENTS_WEBHOOK_SECRET` | PaymentsProvider Control Panel → Webhooks → [endpoint] | `.env.local` |

## Account Setup

- [ ] **Create PaymentsProvider account** (if needed)
  - URL: https://payments-provider.example/register
  - Skip if: Already have an account

## Control Panel Configuration

- [ ] **Create callback endpoint**
  - Location: PaymentsProvider Control Panel → Webhooks → Add endpoint
  - Endpoint URL: `https://[your-domain]/callbacks/payments`
  - Events to send:
    - `payment.succeeded`
    - `subscription.created`
    - `subscription.updated`

- [ ] **Create products and prices** (if using plans)
  - Location: PaymentsProvider Control Panel → Products → Add product
  - Copy price IDs to:
    - `PLAN_BASIC_PRICE_ID`
    - `PLAN_PRO_PRICE_ID`

## Local Development

For local callback testing:
```bash
payments-provider listen --forward-to localhost:3000/callbacks/payments
```
Use the callback signing secret from CLI output.

## Verification

After completing setup:

```bash
# Check env vars are set
grep PAYMENTS .env.local

# Verify build passes
run-build

# Test callback endpoint (should return 400 bad signature, not 500 crash)
curl -X POST http://localhost:3000/callbacks/payments   -H "Content-Type: application/json"   -d '{}'
```

Expected: Build passes, callback returns 400 (signature validation working).

---

**Once all items complete:** Mark status as "Complete" at top of file.
```
</payments_example>


<database_example>
```markdown
# Phase 2: User Setup Required

**Generated:** 2025-01-14
**Phase:** 02-authentication
**Status:** Incomplete

Complete these items for DatabaseProvider Auth to function.

## Environment Variables

| Status | Variable | Source | Add to |
|--------|----------|--------|--------|
| [ ] | `DB_PROJECT_URL` | DatabaseProvider Control Panel → Project settings | `.env.local` |
| [ ] | `DB_PUBLIC_KEY` | DatabaseProvider Control Panel → API keys | `.env.local` |
| [ ] | `DB_SERVICE_KEY` | DatabaseProvider Control Panel → Service keys | `.env.local` |

## Account Setup

- [ ] **Create DatabaseProvider project**
  - URL: https://db-provider.example/projects/new
  - Skip if: Already have a project for this app

## Control Panel Configuration

- [ ] **Enable Email Auth**
  - Location: DatabaseProvider Control Panel → Authentication → Providers
  - Enable: Email provider
  - Configure: Confirm email (on/off based on preference)

- [ ] **Configure OAuth providers** (if using social login)
  - Location: DatabaseProvider Control Panel → Authentication → Providers
  - For Google: Add Client ID and Secret from Google Cloud Console
  - For GitHub: Add Client ID and Secret from OAuth Apps

## Verification

After completing setup:

```bash
# Check env vars
grep DB_ .env.local

# Verify connection (run in project directory)
db-provider status
```

---

**Once all items complete:** Mark status as "Complete" at top of file.
```
</database_example>


<email_example>
```markdown
# Phase 5: User Setup Required

**Generated:** 2025-01-14
**Phase:** 05-notifications
**Status:** Incomplete

Complete these items for EmailProvider email to function.

## Environment Variables

| Status | Variable | Source | Add to |
|--------|----------|--------|--------|
| [ ] | `EMAIL_API_KEY` | EmailProvider Control Panel → API Keys | `.env.local` |
| [ ] | `EMAIL_FROM_ADDRESS` | Verified sender address | `.env.local` |

## Account Setup

- [ ] **Create EmailProvider account**
  - URL: https://email-provider.example/signup
  - Skip if: Already have account

## Control Panel Configuration

- [ ] **Verify sender identity**
  - Location: EmailProvider Control Panel → Sender Authentication
  - Option 1: Single Sender Verification (quick, for dev)
  - Option 2: Domain Authentication (production)

- [ ] **Create service Key**
  - Location: EmailProvider Control Panel → API Keys → Create service Key
  - Permission: Mail Send (Full Access)
  - Copy key immediately (shown only once)

## Verification

After completing setup:

```bash
# Check env var
grep EMAIL_ .env.local

# Test email sending (replace with your test email)
curl -X POST http://localhost:3000/service/test-email   -H "Content-Type: application/json"   -d '{"to": "your@email.com"}'
```

---

**Once all items complete:** Mark status as "Complete" at top of file.
```
</email_example>


---

## Guidelines

**Include in USER-SETUP.md:**
- Environment variable names and where to find values
- Account creation URLs (if new service)
- Control Panel configuration steps
- Verification commands to confirm setup works
- Local development alternatives (e.g., `payments-provider listen`)

**Do NOT include:**
- Actual secret values (never)
- Steps assistant can automate (package installs, code changes, file creation)
- Generic instructions ("set up your environment")

**Naming:** `{phase}-USER-SETUP.md` matches the phase number pattern.

**Status tracking:** User marks checkboxes and updates status line when complete.

**Searchability:** `grep -r "USER-SETUP" .planning/` finds all phases with user requirements.
