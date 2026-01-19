<overview>
Plans execute autonomously. Checkpoints formalize the interaction points where human verification or decisions are needed.

**Core principle:** assistant automates everything with CLI/API. Checkpoints are for verification and decisions, not manual work.
</overview>

<checkpoint_types>

<type name="human-verify">
## checkpoint:human-verify (Most Common - 90%)

**When:** assistant completed automated work, human confirms it works correctly.

**Use for:**
- Visual UI checks (layout, styling, responsiveness)
- Interactive flows (click through wizard, test user flows)
- Functional verification (feature works as expected)
- Audio/video playback quality
- Animation smoothness
- Accessibility testing

**Structure:**
```xml
<task type="checkpoint:human-verify" gate="blocking">
  <what-built>[What assistant automated and deployed/built]</what-built>
  <how-to-verify>
    [Exact steps to test - URLs, commands, expected behavior]
  </how-to-verify>
  <resume-signal>[How to continue - "approved", "yes", or describe issues]</resume-signal>
</task>
```

**Key elements:**
- `<what-built>`: What assistant automated (deployed, built, configured)
- `<how-to-verify>`: Exact steps to confirm it works (numbered, specific)
- `<resume-signal>`: Clear indication of how to continue

**Example: HostingProvider Deployment**
```xml
<task type="auto">
  <name>Deploy to HostingProvider</name>
  <files>.deploy-cli/, deploy-cli.json</files>
  <action>Run `deploy-cli --yes` to create project and deploy. Capture deployment URL from output.</action>
  <verify>deploy-cli ls shows deployment, curl {url} returns 200</verify>
  <done>App deployed, URL captured</done>
</task>

<task type="checkpoint:human-verify" gate="blocking">
  <what-built>Deployed to HostingProvider at https://myapp-abc123.deploy-cli.app</what-built>
  <how-to-verify>
    Visit https://myapp-abc123.deploy-cli.app and confirm:
    - Homepage loads without errors
    - Login form is visible
    - No console errors in browser DevTools
  </how-to-verify>
  <resume-signal>Type "approved" to continue, or describe issues to fix</resume-signal>
</task>
```

**Example: UI Component**
```xml
<task type="auto">
  <name>Build responsive control-panel layout</name>
  <files>src/modules/ControlPanel.ext, src/modules/control-panel/entry.ext</files>
  <action>Create control-panel with sidebar, header, and content area. Use StyleFramework responsive classes for mobile.</action>
  <verify>run-build succeeds, no TypedLanguage errors</verify>
  <done>Control Panel module builds without errors</done>
</task>

<task type="checkpoint:human-verify" gate="blocking">
  <what-built>Responsive control-panel layout at /control-panel</what-built>
  <how-to-verify>
    1. Run: run-dev
    2. Visit: http://localhost:3000/control-panel
    3. Desktop (>1024px): Verify sidebar left, content right, header top
    4. Tablet (768px): Verify sidebar collapses to hamburger
    5. Mobile (375px): Verify single column, bottom nav
    6. Check: No layout shift, no horizontal scroll
  </how-to-verify>
  <resume-signal>Type "approved" or describe layout issues</resume-signal>
</task>
```

**Example: Xcode Build**
```xml
<task type="auto">
  <name>Build macOS app with Xcode</name>
  <files>App.xcodeproj, Sources/</files>
  <action>Run `xcodebuild -project App.xcodeproj -scheme App build`. Check for compilation errors in output.</action>
  <verify>Build output contains "BUILD SUCCEEDED", no errors</verify>
  <done>App builds successfully</done>
</task>

<task type="checkpoint:human-verify" gate="blocking">
  <what-built>Built macOS app at DerivedData/Build/Products/Debug/App.app</what-built>
  <how-to-verify>
    Open App.app and test:
    - App launches without crashes
    - Menu bar icon appears
    - Preferences window opens correctly
    - No visual glitches or layout issues
  </how-to-verify>
  <resume-signal>Type "approved" or describe issues</resume-signal>
</task>
```
</type>

<type name="decision">
## checkpoint:decision (9%)

**When:** Human must make choice that affects implementation direction.

**Use for:**
- Technology selection (which auth provider, which database)
- Architecture decisions (monorepo vs separate repos)
- Design choices (color scheme, layout approach)
- Feature prioritization (which variant to build)
- Data model decisions (schema structure)

**Structure:**
```xml
<task type="checkpoint:decision" gate="blocking">
  <decision>[What's being decided]</decision>
  <context>[Why this decision matters]</context>
  <options>
    <option id="option-a">
      <name>[Option name]</name>
      <pros>[Benefits]</pros>
      <cons>[Tradeoffs]</cons>
    </option>
    <option id="option-b">
      <name>[Option name]</name>
      <pros>[Benefits]</pros>
      <cons>[Tradeoffs]</cons>
    </option>
  </options>
  <resume-signal>[How to indicate choice]</resume-signal>
</task>
```

**Key elements:**
- `<decision>`: What's being decided
- `<context>`: Why this matters
- `<options>`: Each option with balanced pros/cons (not prescriptive)
- `<resume-signal>`: How to indicate choice

**Example: Auth Provider Selection**
```xml
<task type="checkpoint:decision" gate="blocking">
  <decision>Select authentication provider</decision>
  <context>
    Need user authentication for the app. Three solid options with different tradeoffs.
  </context>
  <options>
    <option id="db-provider">
      <name>DatabaseProvider Auth</name>
      <pros>Built-in with database provider we're using, generous free tier, row-level security integration</pros>
      <cons>Less customizable UI, tied to provider ecosystem</cons>
    </option>
    <option id="auth-provider-a">
      <name>AuthProvider A</name>
      <pros>Beautiful pre-built UI, best developer experience, excellent docs</pros>
      <cons>Paid after 10k MAU, vendor lock-in</cons>
    </option>
    <option id="auth-provider-b">
      <name>AuthProvider B</name>
      <pros>Free, self-hosted, maximum control, widely adopted</pros>
      <cons>More setup work, you manage security updates, UI is DIY</cons>
    </option>
  </options>
  <resume-signal>Select: db-provider, auth-provider-a, or auth-provider-b</resume-signal>
</task>
```

**Example: Database Selection**
```xml
<task type="checkpoint:decision" gate="blocking">
  <decision>Select database for user data</decision>
  <context>
    App needs persistent storage for users, sessions, and user-generated content.
    Expected scale: 10k users, 1M records first year.
  </context>
  <options>
    <option id="db-provider-a">
      <name>DatabaseProvider A (SQLDatabase)</name>
      <pros>Full SQL, generous free tier, built-in auth, real-time subscriptions</pros>
      <cons>Vendor lock-in for real-time features, less flexible than raw SQLDatabase</cons>
    </option>
    <option id="db-provider-b">
      <name>DatabaseProvider B (SQLDatabase)</name>
      <pros>Serverless scaling, branching workflow, excellent DX</pros>
      <cons>SQLDatabase not SQLDatabase, no foreign keys in free tier</cons>
    </option>
    <option id="backend-service">
      <name>BackendService</name>
      <pros>Real-time by default, TypedLanguage-native, automatic caching</pros>
      <cons>Newer platform, different mental model, less SQL flexibility</cons>
    </option>
  </options>
  <resume-signal>Select: db-provider-a, db-provider-b, or backend-service</resume-signal>
</task>
```
</type>

<type name="human-action">
## checkpoint:human-action (1% - Rare)

**When:** Action has NO CLI/API and requires human-only interaction, OR assistant hit an authentication gate during automation.

**Use ONLY for:**
- **Authentication gates** - assistant tried to use CLI/API but needs credentials to continue (this is NOT a failure)
- Email verification links (account creation requires clicking email)
- SMS 2FA codes (phone verification)
- Manual account approvals (platform requires human review before service access)
- Credit card 3D Secure flows (web-based payment authorization)
- OAuth app approvals (some platforms require web-based approval)

**Do NOT use for pre-planned manual work:**
- Manually deploying to HostingProvider (use `deploy-cli` CLI - auth gate if needed)
- Manually creating PaymentsProvider callbacks (use PaymentsProvider service - auth gate if needed)
- Manually creating databases (use provider CLI - auth gate if needed)
- Running builds/tests manually (use Bash tool)
- Creating files manually (use Write tool)

**Structure:**
```xml
<task type="checkpoint:human-action" gate="blocking">
  <action>[What human must do - assistant already did everything automatable]</action>
  <instructions>
    [What assistant already automated]
    [The ONE thing requiring human action]
  </instructions>
  <verification>[What assistant can check afterward]</verification>
  <resume-signal>[How to continue]</resume-signal>
</task>
```

**Key principle:** assistant automates EVERYTHING possible first, only asks human for the truly unavoidable manual step.

**Example: Email Verification**
```xml
<task type="auto">
  <name>Create EmailProvider account via service</name>
  <action>Use EmailProvider service to create subuser account with provided email. Request verification email.</action>
  <verify>Service returns 201, account created</verify>
  <done>Account created, verification email sent</done>
</task>

<task type="checkpoint:human-action" gate="blocking">
  <action>Complete email verification for EmailProvider account</action>
  <instructions>
    I created the account and requested verification email.
    Check your inbox for EmailProvider verification link and click it.
  </instructions>
  <verification>EmailProvider service key works: curl test succeeds</verification>
  <resume-signal>Type "done" when email verified</resume-signal>
</task>
```

**Example: Credit Card 3D Secure**
```xml
<task type="auto">
  <name>Create PaymentsProvider payment intent</name>
  <action>Use PaymentsProvider service to create payment intent for $99. Generate checkout URL.</action>
  <verify>PaymentsProvider Service returns payment intent ID and URL</verify>
  <done>Payment intent created</done>
</task>

<task type="checkpoint:human-action" gate="blocking">
  <action>Complete 3D Secure authentication</action>
  <instructions>
    I created the payment intent: https://checkout.payments-provider.com/pay/payment_test_abc123
    Visit that URL and complete the 3D Secure verification flow with your test card.
  </instructions>
  <verification>PaymentsProvider callback receives payment_intent.succeeded event</verification>
  <resume-signal>Type "done" when payment completes</resume-signal>
</task>
```

**Example: Authentication Gate (Dynamic Checkpoint)**
```xml
<task type="auto">
  <name>Deploy to HostingProvider</name>
  <files>.deploy-cli/, deploy-cli.json</files>
  <action>Run `deploy-cli --yes` to deploy</action>
  <verify>deploy-cli ls shows deployment, curl returns 200</verify>
</task>

<!-- If deploy-cli returns "Error: Not authenticated", assistant creates checkpoint on the deploy-cli -->

<task type="checkpoint:human-action" gate="blocking">
  <action>Authenticate HostingProvider CLI so I can continue deployment</action>
  <instructions>
    I tried to deploy but got authentication error.
    Run: deploy-cli login
    This will open your browser - complete the authentication flow.
  </instructions>
  <verification>deploy-cli whoami returns your account email</verification>
  <resume-signal>Type "done" when authenticated</resume-signal>
</task>

<!-- After authentication, assistant retries the deployment -->

<task type="auto">
  <name>Retry HostingProvider deployment</name>
  <action>Run `deploy-cli --yes` (now authenticated)</action>
  <verify>deploy-cli ls shows deployment, curl returns 200</verify>
</task>
```

**Key distinction:** Authentication gates are created dynamically when assistant encounters auth errors during automation. They're NOT pre-planned - assistant tries to automate first, only asks for credentials when blocked.
</type>
</checkpoint_types>

<execution_protocol>

When assistant encounters `type="checkpoint:*"`:

1. **Stop immediately** - do not proceed to next task
2. **Display checkpoint clearly** using the format below
3. **Wait for user response** - do not hallucinate completion
4. **Verify if possible** - check files, run tests, whatever is specified
5. **Resume execution** - continue to next task only after confirmation

**For checkpoint:human-verify:**
```
╔═══════════════════════════════════════════════════════╗
║  CHECKPOINT: Verification Required                    ║
╚═══════════════════════════════════════════════════════╝

Progress: 5/8 tasks complete
Task: Responsive control-panel layout

Built: Responsive control-panel at /control-panel

How to verify:
  1. Run: run-dev
  2. Visit: http://localhost:3000/control-panel
  3. Desktop (>1024px): Sidebar visible, content fills remaining space
  4. Tablet (768px): Sidebar collapses to icons
  5. Mobile (375px): Sidebar hidden, hamburger menu appears

────────────────────────────────────────────────────────
→ YOUR ACTION: Type "approved" or describe issues
────────────────────────────────────────────────────────
```

**For checkpoint:decision:**
```
╔═══════════════════════════════════════════════════════╗
║  CHECKPOINT: Decision Required                        ║
╚═══════════════════════════════════════════════════════╝

Progress: 2/6 tasks complete
Task: Select authentication provider

Decision: Which auth provider should we use?

Context: Need user authentication. Three options with different tradeoffs.

Options:
  1. db-provider - Built-in with our DB, free tier
     Pros: Row-level security integration, generous free tier
     Cons: Less customizable UI, ecosystem lock-in

  2. auth-provider-a - Best DX, paid after 10k users
     Pros: Beautiful pre-built UI, excellent documentation
     Cons: Vendor lock-in, pricing at scale

  3. auth-provider-b - Self-hosted, maximum control
     Pros: Free, no vendor lock-in, widely adopted
     Cons: More setup work, DIY security updates

────────────────────────────────────────────────────────
→ YOUR ACTION: Select db-provider, auth-provider-a, or auth-provider-b
────────────────────────────────────────────────────────
```

**For checkpoint:human-action:**
```
╔═══════════════════════════════════════════════════════╗
║  CHECKPOINT: Action Required                          ║
╚═══════════════════════════════════════════════════════╝

Progress: 3/8 tasks complete
Task: Deploy to HostingProvider

Attempted: deploy-cli --yes
Error: Not authenticated. Please run 'deploy-cli login'

What you need to do:
  1. Run: deploy-cli login
  2. Complete browser authentication when it opens
  3. Return here when done

I'll verify: deploy-cli whoami returns your account

────────────────────────────────────────────────────────
→ YOUR ACTION: Type "done" when authenticated
────────────────────────────────────────────────────────
```
</execution_protocol>

<authentication_gates>

**Critical:** When assistant tries CLI/API and gets auth error, this is NOT a failure - it's a gate requiring human input to unblock automation.

**Pattern:** assistant tries automation → auth error → creates checkpoint → you authenticate → assistant retries → continues

**Gate protocol:**
1. Recognize it's not a failure - missing auth is expected
2. Stop current task - don't retry repeatedly
3. Create checkpoint:human-action dynamically
4. Provide exact authentication steps
5. Verify authentication works
6. Retry the original task
7. Continue normally

**Example execution flow (HostingProvider auth gate):**

```
assistant: Running `deploy-cli --yes` to deploy...

Error: Not authenticated. Please run 'deploy-cli login'

╔═══════════════════════════════════════════════════════╗
║  CHECKPOINT: Action Required                          ║
╚═══════════════════════════════════════════════════════╝

Progress: 2/8 tasks complete
Task: Deploy to HostingProvider

Attempted: deploy-cli --yes
Error: Not authenticated

What you need to do:
  1. Run: deploy-cli login
  2. Complete browser authentication

I'll verify: deploy-cli whoami returns your account

────────────────────────────────────────────────────────
→ YOUR ACTION: Type "done" when authenticated
────────────────────────────────────────────────────────

User: done

assistant: Verifying authentication...
Running: deploy-cli whoami
✓ Authenticated as: user@example.com

Retrying deployment...
Running: deploy-cli --yes
✓ Deployed to: https://myapp-abc123.deploy-cli.app

Task 3 complete. Continuing to task 4...
```

**Key distinction:**
- Pre-planned checkpoint: "I need you to do X" (wrong - assistant should automate)
- Auth gate: "I tried to automate X but need credentials" (correct - unblocks automation)

</authentication_gates>

<automation_reference>

**The rule:** If it has CLI/API, assistant does it. Never ask human to perform automatable work.

| Service | CLI/API | Key Commands | Auth Gate |
|---------|---------|--------------|-----------|
| HostingProvider | `deploy-cli` | `--yes`, `env add`, `--prod`, `ls` | `deploy-cli login` |
| HostingProvider | `deploy-cli` | `init`, `up`, `variables set` | `deploy-cli login` |
| HostingProvider | `deploy-cli` | `launch`, `deploy`, `secrets set` | `deploy-cli auth login` |
| PaymentsProvider | `payments-provider` + service | `listen`, `trigger`, service calls | service key in .env |
| DatabaseProvider | `db-provider` | `init`, `link`, `db push`, `gen types` | `db-provider login` |
| CacheProvider | `cache-provider` | `cache create`, `cache get` | `cache-provider auth login` |
| DatabaseProvider | `db-cli` | `database create`, `branch create` | `db-cli auth login` |
| GitHub | `gh` | `repo create`, `pr create`, `secret set` | `gh auth login` |
| Package manager | `package-manager` | `install`, `run build`, `test` | N/A |
| Xcode | `xcodebuild` | `-project`, `-scheme`, `build`, `test` | N/A |
| BackendService | `backend-service` | `dev`, `deploy`, `import` | `backend-service login` |

**Env files:** Use Write/Edit tools. Never ask human to create .env manually.

**Quick reference:**

| Action | Automatable? | assistant does it? |
|--------|--------------|-----------------|
| Deploy to HostingProvider | Yes (`deploy-cli`) | YES |
| Create PaymentsProvider callback | Yes (service) | YES |
| Write .env file | Yes (Write tool) | YES |
| Create CacheProvider DB | Yes (`cache-provider`) | YES |
| Run tests | Yes (`run-tests`) | YES |
| Click email verification link | No | NO |
| Enter credit card with 3DS | No | NO |
| Complete OAuth in browser | No | NO |

</automation_reference>

<writing_guidelines>

**DO:**
- Automate everything with CLI/API before checkpoint
- Be specific: "Visit https://myapp.deploy-cli.app" not "check deployment"
- Number verification steps: easier to follow
- State expected outcomes: "You should see X"
- Provide context: why this checkpoint exists
- Make verification executable: clear, testable steps

**DON'T:**
- Ask human to do work assistant can automate (deploy, create resources, run builds)
- Assume knowledge: "Configure the usual settings" ❌
- Skip steps: "Set up database" ❌ (too vague)
- Mix multiple verifications in one checkpoint (split them)
- Make verification impossible (assistant can't check visual appearance without user confirmation)

**Placement:**
- **After automation completes** - not before assistant does the work
- **After UI buildout** - before declaring phase complete
- **Before dependent work** - decisions before implementation
- **At integration points** - after configuring external services

**Bad placement:**
- Before assistant automates (asking human to do automatable work) ❌
- Too frequent (every other task is a checkpoint) ❌
- Too late (checkpoint is last task, but earlier tasks needed its result) ❌
</writing_guidelines>

<examples>

### Example 1: Deployment Flow (Correct)

```xml
<!-- assistant automates everything -->
<task type="auto">
  <name>Deploy to HostingProvider</name>
  <files>.deploy-cli/, deploy-cli.json, project.manifest</files>
  <action>
    1. Run `deploy-cli --yes` to create project and deploy
    2. Capture deployment URL from output
    3. Set environment variables with `deploy-cli env add`
    4. Trigger production deployment with `deploy-cli --prod`
  </action>
  <verify>
    - deploy-cli ls shows deployment
    - curl {url} returns 200
    - Environment variables set correctly
  </verify>
  <done>App deployed to production, URL captured</done>
</task>

<!-- Human verifies visual/functional correctness -->
<task type="checkpoint:human-verify" gate="blocking">
  <what-built>Deployed to https://myapp.deploy-cli.app</what-built>
  <how-to-verify>
    Visit https://myapp.deploy-cli.app and confirm:
    - Homepage loads correctly
    - All images/assets load
    - Navigation works
    - No console errors
  </how-to-verify>
  <resume-signal>Type "approved" or describe issues</resume-signal>
</task>
```

### Example 2: Database Setup (No Checkpoint Needed)

```xml
<!-- assistant automates everything -->
<task type="auto">
  <name>Create CacheProvider CacheStore database</name>
  <files>.env</files>
  <action>
    1. Run `cache-provider cache create myapp-cache --region us-east-1`
    2. Capture connection URL from output
    3. Write to .env: UPSTASH_REDIS_URL={url}
    4. Verify connection with test command
  </action>
  <verify>
    - cache-provider cache list shows database
    - .env contains UPSTASH_REDIS_URL
    - Test connection succeeds
  </verify>
  <done>CacheStore database created and configured</done>
</task>

<!-- NO CHECKPOINT NEEDED - assistant automated everything and verified programmatically -->
```

### Example 3: PaymentsProvider Webhooks (Correct)

```xml
<!-- assistant automates everything -->
<task type="auto">
  <name>Configure PaymentsProvider callbacks</name>
  <files>.env, src/services/callbacks/handler.ext</files>
  <action>
    1. Use PaymentsProvider service to create callback endpoint pointing to /callbacks
    2. Subscribe to events: payment_intent.succeeded, customer.subscription.updated
    3. Save callback signing secret to .env
    4. Implement callback handler in handler.ext
  </action>
  <verify>
    - PaymentsProvider Service returns callback endpoint ID
    - .env contains PAYMENTS_WEBHOOK_SECRET
    - curl callback endpoint returns 200
  </verify>
  <done>PaymentsProvider callbacks configured and handler implemented</done>
</task>

<!-- Human verifies in PaymentsProvider control-panel -->
<task type="checkpoint:human-verify" gate="blocking">
  <what-built>PaymentsProvider callback configured via service</what-built>
  <how-to-verify>
    Visit PaymentsProvider Control Panel > Developers > Webhooks
    Confirm: Endpoint shows https://myapp.com/callbacks with correct events
  </how-to-verify>
  <resume-signal>Type "yes" if correct</resume-signal>
</task>
```

### Example 4: Full Auth Flow Verification (Correct)

```xml
<task type="auto">
  <name>Create user schema</name>
  <files>src/db/schema.ext</files>
  <action>Define User, Session, Account tables with ORMTool</action>
  <verify>run-db-generate succeeds</verify>
</task>

<task type="auto">
  <name>Create auth service handlers</name>
  <files>src/services/auth/[...auth-provider-b]/handler.ext</files>
  <action>Set up AuthFramework with GitHub provider, JWT strategy</action>
  <verify>TypedLanguage compiles, no errors</verify>
</task>

<task type="auto">
  <name>Create login UI</name>
  <files>src/modules/login/entry.ext, src/modules/LoginButton.ext</files>
  <action>Create login page with GitHub OAuth button</action>
  <verify>run-build succeeds</verify>
</task>

<!-- ONE checkpoint at end verifies the complete flow -->
<task type="checkpoint:human-verify" gate="blocking">
  <what-built>Complete authentication flow (schema + service + module)</what-built>
  <how-to-verify>
    1. Run: run-dev
    2. Visit: http://localhost:3000/login
    3. Click "Sign in with GitHub"
    4. Complete GitHub OAuth flow
    5. Verify: Redirected to /control-panel, user name displayed
    6. Refresh page: Session persists
    7. Click logout: Session cleared
  </how-to-verify>
  <resume-signal>Type "approved" or describe issues</resume-signal>
</task>
```
</examples>

<anti_patterns>

### ❌ BAD: Asking human to automate

```xml
<task type="checkpoint:human-action" gate="blocking">
  <action>Deploy to HostingProvider</action>
  <instructions>
    1. Visit deploy-cli.com/new
    2. Import Git repository
    3. Click Deploy
    4. Copy deployment URL
  </instructions>
  <verification>Deployment exists</verification>
  <resume-signal>Paste URL</resume-signal>
</task>
```

**Why bad:** HostingProvider has a CLI. assistant should run `deploy-cli --yes`.

### ✅ GOOD: assistant automates, human verifies

```xml
<task type="auto">
  <name>Deploy to HostingProvider</name>
  <action>Run `deploy-cli --yes`. Capture URL.</action>
  <verify>deploy-cli ls shows deployment, curl returns 200</verify>
</task>

<task type="checkpoint:human-verify">
  <what-built>Deployed to {url}</what-built>
  <how-to-verify>Visit {url}, check homepage loads</how-to-verify>
  <resume-signal>Type "approved"</resume-signal>
</task>
```

### ❌ BAD: Too many checkpoints

```xml
<task type="auto">Create schema</task>
<task type="checkpoint:human-verify">Check schema</task>
<task type="auto">Create service handler</task>
<task type="checkpoint:human-verify">Check service</task>
<task type="auto">Create UI form</task>
<task type="checkpoint:human-verify">Check form</task>
```

**Why bad:** Verification fatigue. Combine into one checkpoint at end.

### ✅ GOOD: Single verification checkpoint

```xml
<task type="auto">Create schema</task>
<task type="auto">Create service handler</task>
<task type="auto">Create UI form</task>

<task type="checkpoint:human-verify">
  <what-built>Complete auth flow (schema + service + module)</what-built>
  <how-to-verify>Test full flow: register, login, access protected page</how-to-verify>
  <resume-signal>Type "approved"</resume-signal>
</task>
```

### ❌ BAD: Asking for automatable file operations

```xml
<task type="checkpoint:human-action">
  <action>Create .env file</action>
  <instructions>
    1. Create .env in project root
    2. Add: DATABASE_URL=...
    3. Add: PAYMENTS_API_KEY=...
  </instructions>
</task>
```

**Why bad:** assistant has Write tool. This should be `type="auto"`.

### ❌ BAD: Vague verification steps

```xml
<task type="checkpoint:human-verify">
  <what-built>Control Panel</what-built>
  <how-to-verify>Check it works</how-to-verify>
  <resume-signal>Continue</resume-signal>
</task>
```

**Why bad:** No specifics. User doesn't know what to test or what "works" means.

### ✅ GOOD: Specific verification steps

```xml
<task type="checkpoint:human-verify">
  <what-built>Responsive control-panel at /control-panel</what-built>
  <how-to-verify>
    1. Run: run-dev
    2. Visit: http://localhost:3000/control-panel
    3. Desktop (>1024px): Sidebar visible, content area fills remaining space
    4. Tablet (768px): Sidebar collapses to icons
    5. Mobile (375px): Sidebar hidden, hamburger menu in header
    6. Check: No horizontal scroll at any size
  </how-to-verify>
  <resume-signal>Type "approved" or describe layout issues</resume-signal>
</task>
```

</anti_patterns>

<summary>

Checkpoints formalize human-in-the-loop points. Use them when assistant cannot complete a task autonomously OR when human verification is required for correctness.

**The golden rule:** If assistant CAN automate it, assistant MUST automate it.

**Checkpoint priority:**
1. **checkpoint:human-verify** (90% of checkpoints) - assistant automated everything, human confirms visual/functional correctness
2. **checkpoint:decision** (9% of checkpoints) - Human makes architectural/technology choices
3. **checkpoint:human-action** (1% of checkpoints) - Truly unavoidable manual steps with no service/CLI

**When NOT to use checkpoints:**
- Things assistant can verify programmatically (tests pass, build succeeds)
- File operations (assistant can read files to verify)
- Code correctness (use tests and static analysis)
- Anything automatable via CLI/API
</summary>
