<overview>
Plans execute autonomously. Checkpoints formalize interaction points where human verification or decisions are needed.

**Core principle:** assistant automates everything with CLI/API. Checkpoints are for verification and decisions, not manual work.
</overview>

<checkpoint_types>

<type name="human-verify">
## checkpoint:human-verify (Most Common)

**When:** assistant completed automated work, human confirms it works correctly.

**Use for:**
- Visual checks (layout, styling, responsiveness)
- Interactive flows (multi-step user journeys)
- Functional verification (feature works as expected)
- Media quality (audio/video)
- Accessibility checks

**Structure:**
```xml
<task type="checkpoint:human-verify" gate="blocking">
  <what-built>[What assistant automated and built]</what-built>
  <how-to-verify>
    [Exact steps to test - commands, URLs, expected behavior]
  </how-to-verify>
  <resume-signal>[How to continue - "approved", "yes", or describe issues]</resume-signal>
</task>
```

**Key elements:**
- `<what-built>`: What assistant automated
- `<how-to-verify>`: Exact steps to confirm it works (numbered, specific)
- `<resume-signal>`: Clear indication of how to continue

**Example: UI verification**
```xml
<task type="auto">
  <name>Build responsive control-panel layout</name>
  <files>src/modules/control-panel/entry.ext</files>
  <action>Create control-panel layout with sidebar and content area. Use project styling system.</action>
  <verify>run-build succeeds</verify>
  <done>Control Panel module builds without errors</done>
</task>

<task type="checkpoint:human-verify" gate="blocking">
  <what-built>Responsive control-panel layout at /control-panel</what-built>
  <how-to-verify>
    1. Run: run-dev
    2. Visit: http://localhost:3000/control-panel
    3. Desktop: Verify sidebar left, content right, header top
    4. Tablet: Sidebar collapses to icons
    5. Mobile: Single column, bottom nav
    6. Check: No layout shift, no horizontal scroll
  </how-to-verify>
  <resume-signal>Type "approved" or describe layout issues</resume-signal>
</task>
```
</type>

<type name="decision">
## checkpoint:decision

**When:** Human must make choice that affects implementation direction.

**Use for:**
- Technology selection (auth provider, data store)
- Architecture decisions (monorepo vs split)
- Design choices (layout approach, interaction model)
- Feature prioritization
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
- `<options>`: Balanced pros/cons
- `<resume-signal>`: How to indicate choice

**Example: data store selection**
```xml
<task type="checkpoint:decision" gate="blocking">
  <decision>Select data store for user data</decision>
  <context>
    App needs persistent storage for users, sessions, and user-generated content.
  </context>
  <options>
    <option id="managed-sql">
      <name>Managed SQL service</name>
      <pros>Reliable, familiar SQL, good tooling</pros>
      <cons>Operational costs, vendor constraints</cons>
    </option>
    <option id="self-hosted">
      <name>Self-hosted database</name>
      <pros>Full control, portability</pros>
      <cons>Maintenance overhead, backups required</cons>
    </option>
  </options>
  <resume-signal>Select: managed-sql or self-hosted</resume-signal>
</task>
```
</type>

<type name="human-action">
## checkpoint:human-action (Rare)

**When:** Action has NO CLI/API and requires human-only interaction, OR assistant hit an authentication gate during automation.

**Use ONLY for:**
- Authentication gates (assistant tried CLI/API but needs credentials)
- Email verification links
- SMS/2FA codes
- Manual account approvals
- Web-based payment authorization

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

**Key principle:** assistant automates EVERYTHING possible first, only asks for the truly unavoidable manual step.

**Example: Authentication gate (dynamic checkpoint)**
```xml
<task type="auto">
  <name>Deploy to hosting service</name>
  <action>Run deployment CLI to deploy</action>
  <verify>deployment list shows new deployment</verify>
</task>

<!-- If CLI returns "Not authenticated", assistant creates checkpoint -->

<task type="checkpoint:human-action" gate="blocking">
  <action>Authenticate hosting CLI so deployment can continue</action>
  <instructions>
    I tried to deploy but got an authentication error.
    Run: service-cli login
    Complete the authentication flow.
  </instructions>
  <verification>service-cli whoami returns your account</verification>
  <resume-signal>Type "done" when authenticated</resume-signal>
</task>
```

**Key distinction:**
- Pre-planned checkpoint: "I need you to do X" (wrong - assistant should automate)
- Auth gate: "I tried to automate X but need credentials" (correct - unblocks automation)
</type>

</checkpoint_types>

<execution_protocol>

When assistant encounters `type="checkpoint:*"`:

1. **Stop immediately** - do not proceed to next task
2. **Display checkpoint clearly** using the format below
3. **Wait for user response** - do not assume completion
4. **Verify if possible** - check files, run tests, whatever is specified
5. **Resume execution** - continue only after confirmation

**Checkpoint display format (human-verify):**
```
CHECKPOINT: Verification Required
Progress: 5/8 tasks complete
Task: Responsive control-panel layout

Built: Responsive control-panel at /control-panel

How to verify:
  1. Run: run-dev
  2. Visit: http://localhost:3000/control-panel
  3. Desktop: Sidebar visible, content fills remaining space
  4. Mobile: Sidebar hidden, hamburger menu in header

YOUR ACTION: Type "approved" or describe issues
```

**Checkpoint display format (decision):**
```
CHECKPOINT: Decision Required
Progress: 2/6 tasks complete
Task: Select data store

Decision: Which data store should we use?
Context: Need persistence with expected scale ~10k users.

Options:
  1. managed-sql
  2. self-hosted

YOUR ACTION: Select managed-sql or self-hosted
```

**Checkpoint display format (human-action):**
```
CHECKPOINT: Action Required
Progress: 3/8 tasks complete
Task: Deploy to hosting

Attempted: service-cli deploy
Error: Not authenticated

What you need to do:
  1. Run: service-cli login
  2. Complete browser authentication

YOUR ACTION: Type "done" when authenticated
```
</execution_protocol>

<authentication_gates>

**Critical:** When assistant tries CLI/API and gets auth error, this is NOT a failure - it's a gate requiring human input to unblock automation.

**Pattern:** assistant tries automation -> auth error -> checkpoint -> user authenticates -> assistant retries -> continues

**Gate protocol:**
1. Recognize it's not a failure
2. Stop current task
3. Create checkpoint:human-action dynamically
4. Provide exact authentication steps
5. Verify authentication works
6. Retry the original task
7. Continue normally

</authentication_gates>

<automation_reference>

**The rule:** If it has CLI/API, assistant does it. Never ask human to perform automatable work.

**Quick reference:**

| Action | Automatable? | assistant does it? |
|--------|--------------|-----------------|
| Deploy to hosting via CLI | Yes | YES |
| Create service callback via API | Yes | YES |
| Write .env file | Yes | YES |
| Run tests | Yes | YES |
| Click email verification link | No | NO |
| Enter credit card 3DS | No | NO |
| Complete OAuth in browser | No | NO |

</automation_reference>

<writing_guidelines>

**DO:**
- Automate everything with CLI/API before checkpoint
- Be specific: "Visit https://..." not "check deployment"
- Number verification steps
- State expected outcomes
- Provide context for why checkpoint exists
- Make verification executable

**DON'T:**
- Ask human to do work assistant can automate
- Assume knowledge: "Configure the usual settings"
- Skip steps: "Set up database"
- Mix multiple verifications in one checkpoint (split them)
- Make verification impossible

**Placement:**
- After automation completes
- After UI buildout, before declaring phase complete
- Before dependent work (decisions before implementation)
- At integration points after external setup

</writing_guidelines>

<summary>

Checkpoints formalize human-in-the-loop points. Use them when assistant cannot complete a task autonomously OR when human verification is required for correctness.

**The golden rule:** If assistant CAN automate it, assistant MUST automate it.

**Checkpoint priority:**
1. **checkpoint:human-verify** - assistant automated everything, human confirms correctness
2. **checkpoint:decision** - Human makes architectural/technology choices
3. **checkpoint:human-action** - Truly unavoidable manual steps with no API/CLI

**When NOT to use checkpoints:**
- Things assistant can verify programmatically (tests pass, build succeeds)
- File operations (assistant can read/write files)
- Code correctness (use tests and static analysis)
- Anything automatable via CLI/API

</summary>
