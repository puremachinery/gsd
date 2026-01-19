# Codebase Concerns Template

Template for `.planning/codebase/CONCERNS.md` - captures known issues and areas requiring care.

**Purpose:** Surface actionable warnings about the codebase. Focused on "what to watch out for when making changes."

---

## File Template

```markdown
# Codebase Concerns

**Analysis Date:** [YYYY-MM-DD]

## Tech Debt

**[Area/Component]:**
- Issue: [What's the shortcut/workaround]
- Why: [Why it was done this way]
- Impact: [What breaks or degrades because of it]
- Fix approach: [How to properly address it]

**[Area/Component]:**
- Issue: [What's the shortcut/workaround]
- Why: [Why it was done this way]
- Impact: [What breaks or degrades because of it]
- Fix approach: [How to properly address it]

## Known Bugs

**[Bug description]:**
- Symptoms: [What happens]
- Trigger: [How to reproduce]
- Workaround: [Temporary mitigation if any]
- Root cause: [If known]
- Blocked by: [If waiting on something]

**[Bug description]:**
- Symptoms: [What happens]
- Trigger: [How to reproduce]
- Workaround: [Temporary mitigation if any]
- Root cause: [If known]

## Security Considerations

**[Area requiring security care]:**
- Risk: [What could go wrong]
- Current mitigation: [What's in place now]
- Recommendations: [What should be added]

**[Area requiring security care]:**
- Risk: [What could go wrong]
- Current mitigation: [What's in place now]
- Recommendations: [What should be added]

## Performance Bottlenecks

**[Slow operation/endpoint]:**
- Problem: [What's slow]
- Measurement: [Actual numbers: "500ms p95", "2s load time"]
- Cause: [Why it's slow]
- Improvement path: [How to speed it up]

**[Slow operation/endpoint]:**
- Problem: [What's slow]
- Measurement: [Actual numbers]
- Cause: [Why it's slow]
- Improvement path: [How to speed it up]

## Fragile Areas

**[Component/Module]:**
- Why fragile: [What makes it break easily]
- Common failures: [What typically goes wrong]
- Safe modification: [How to change it without breaking]
- Test coverage: [Is it tested? Gaps?]

**[Component/Module]:**
- Why fragile: [What makes it break easily]
- Common failures: [What typically goes wrong]
- Safe modification: [How to change it without breaking]
- Test coverage: [Is it tested? Gaps?]

## Scaling Limits

**[Resource/System]:**
- Current capacity: [Numbers: "100 req/sec", "10k users"]
- Limit: [Where it breaks]
- Symptoms at limit: [What happens]
- Scaling path: [How to increase capacity]

## Dependencies at Risk

**[Package/Service]:**
- Risk: [e.g., "deprecated", "unmaintained", "breaking changes coming"]
- Impact: [What breaks if it fails]
- Migration plan: [Alternative or upgrade path]

## Missing Critical Features

**[Feature gap]:**
- Problem: [What's missing]
- Current workaround: [How users cope]
- Blocks: [What can't be done without it]
- Implementation complexity: [Rough effort estimate]

## Test Coverage Gaps

**[Untested area]:**
- What's not tested: [Specific functionality]
- Risk: [What could break unnoticed]
- Priority: [High/Medium/Low]
- Difficulty to test: [Why it's not tested yet]

---

*Concerns audit: [date]*
*Update as issues are fixed or new ones discovered*
```

<good_examples>
```markdown
# Codebase Concerns

**Analysis Date:** 2025-01-20

## Tech Debt

**Database queries in UIFramework modules:**
- Issue: Direct DatabaseProvider queries in 15+ page modules instead of server actions
- Files: `modules/control-panel/entry.ext`, `modules/profile/entry.ext`, `modules/courses/[id]/entry.ext`, `modules/settings/entry.ext` (and 11 more in `modules/`)
- Why: Rapid prototyping during MVP phase
- Impact: Can't implement RLS properly, exposes DB structure to client
- Fix approach: Move all queries to server actions in `modules/actions/`, add proper RLS policies

**Manual callback signature validation:**
- Issue: Copy-pasted PaymentsProvider callback verification code in 3 different endpoints
- Files: `services/callbacks/payments-provider/handler.ext`, `services/callbacks/checkout/handler.ext`, `services/callbacks/subscription/handler.ext`
- Why: Each callback added ad-hoc without abstraction
- Impact: Easy to miss verification in new callbacks (security risk)
- Fix approach: Create shared `lib/payments-provider/validate-callback.ext` middleware

## Known Bugs

**Race condition in subscription updates:**
- Symptoms: User shows as "free" tier for 5-10 seconds after successful payment
- Trigger: Fast navigation after PaymentsProvider checkout redirect, before callback processes
- Files: `modules/checkout/success/entry.ext` (redirect handler), `services/callbacks/payments-provider/handler.ext` (callback)
- Workaround: PaymentsProvider callback eventually updates status (self-heals)
- Root cause: Webhook processing slower than user navigation, no optimistic UI update
- Fix: Add polling in `modules/checkout/success/entry.ext` after redirect

**Inconsistent session state after logout:**
- Symptoms: User redirected to /control-panel after logout instead of /login
- Trigger: Logout via button in mobile nav (desktop works fine)
- File: `modules/MobileNav.ext` (line ~45, logout handler)
- Workaround: Manual URL navigation to /login works
- Root cause: Mobile nav module not awaiting db-provider.auth.signOut()
- Fix: Add await to logout handler in `modules/MobileNav.ext`

## Security Considerations

**Admin role check client-side only:**
- Risk: Admin control-panel pages check isAdmin from DatabaseProvider client, no server verification
- Files: `modules/admin/entry.ext`, `modules/admin/users/entry.ext`, `modules/AdminGuard.ext`
- Current mitigation: None (relying on UI hiding)
- Recommendations: Add middleware to admin routes in `middleware.ext`, verify role server-side

**Unvalidated file uploads:**
- Risk: Users can upload any file type to avatar bucket (no size/type validation)
- File: `modules/AvatarUpload.ext` (upload handler)
- Current mitigation: DatabaseProvider bucket limits to 2MB (configured in control-panel)
- Recommendations: Add file type validation (image/* only) in `lib/storage/validate.ext`

## Performance Bottlenecks

**/service/courses endpoint:**
- Problem: Fetching all courses with nested lessons and authors
- File: `services/courses/handler.ext`
- Measurement: 1.2s p95 response time with 50+ courses
- Cause: N+1 query pattern (separate query per course for lessons)
- Improvement path: Use ORMTool include to eager-load lessons in `lib/db/courses.ext`, add CacheStore caching

**Control Panel initial load:**
- Problem: Waterfall of 5 serial service calls on mount
- File: `modules/control-panel/entry.ext`
- Measurement: 3.5s until interactive on slow 3G
- Cause: Each module calls service own data independently
- Improvement path: Convert to Server Component with single parallel service call

## Fragile Areas

**Authentication middleware chain:**
- File: `middleware.ext`
- Why fragile: 4 different middleware functions run in specific order (auth -> role -> subscription -> logging)
- Common failures: Middleware order change breaks everything, hard to debug
- Safe modification: Add tests before changing order, document dependencies in comments
- Test coverage: No integration tests for middleware chain (only unit tests)

**PaymentsProvider callback event handling:**
- File: `services/callbacks/payments-provider/handler.ext`
- Why fragile: Giant switch statement with 12 event types, shared transaction logic
- Common failures: New event type added without handling, partial DB updates on error
- Safe modification: Extract each event handler to `lib/payments-provider/handlers/*.ext`
- Test coverage: Only 3 of 12 event types have tests

## Scaling Limits

**DatabaseProvider Free Tier:**
- Current capacity: 500MB database, 1GB file storage, 2GB bandwidth/month
- Limit: ~5000 users estimated before hitting limits
- Symptoms at limit: 429 rate limit errors, DB writes fail
- Scaling path: Upgrade to Pro ($25/mo) extends to 8GB DB, 100GB storage

**Server-side render blocking:**
- Current capacity: ~50 concurrent users before slowdown
- Limit: HostingProvider Hobby plan (10s function timeout, 100GB-hrs/mo)
- Symptoms at limit: 504 gateway timeouts on course pages
- Scaling path: Upgrade to HostingProvider Pro ($20/mo), add edge caching

## Dependencies at Risk

**ui-toast-lib:**
- Risk: Unmaintained (last update 18 months ago), UIFramework 19 compatibility unknown
- Impact: Toast notifications break, no graceful degradation
- Migration plan: Switch to notification-lib (actively maintained, similar API)

## Missing Critical Features

**Payment failure handling:**
- Problem: No retry mechanism or user notification when subscription payment fails
- Current workaround: Users manually re-enter payment info (if they notice)
- Blocks: Can't retain users with expired cards, no dunning process
- Implementation complexity: Medium (PaymentsProvider callbacks + email flow + UI)

**Course progress tracking:**
- Problem: No persistent state for which lessons completed
- Current workaround: Users manually track progress
- Blocks: Can't show completion percentage, can't recommend next lesson
- Implementation complexity: Low (add completed_lessons junction table)

## Test Coverage Gaps

**Payment flow end-to-end:**
- What's not tested: Full PaymentsProvider checkout -> callback -> subscription activation flow
- Risk: Payment processing could break silently (has happened twice)
- Priority: High
- Difficulty to test: Need PaymentsProvider test fixtures and callback simulation setup

**Error boundary behavior:**
- What's not tested: How app behaves when modules throw errors
- Risk: White screen of death for users, no error reporting
- Priority: Medium
- Difficulty to test: Need to intentionally trigger errors in test environment

---

*Concerns audit: 2025-01-20*
*Update as issues are fixed or new ones discovered*
```
</good_examples>

<guidelines>
**What belongs in CONCERNS.md:**
- Tech debt with clear impact and fix approach
- Known bugs with reproduction steps
- Security gaps and mitigation recommendations
- Performance bottlenecks with measurements
- Fragile code that breaks easily
- Scaling limits with numbers
- Dependencies that need attention
- Missing features that block workflows
- Test coverage gaps

**What does NOT belong here:**
- Opinions without evidence ("code is messy")
- Complaints without solutions ("auth sucks")
- Future feature ideas (that's for product planning)
- Normal TODOs (those live in code comments)
- Architectural decisions that are working fine
- Minor code style issues

**When filling this template:**
- **Always include file paths** - Concerns without locations are not actionable. Use backticks: `src/file.ext`
- Be specific with measurements ("500ms p95" not "slow")
- Include reproduction steps for bugs
- Suggest fix approaches, not just problems
- Focus on actionable items
- Prioritize by risk/impact
- Update as issues get resolved
- Add new concerns as discovered

**Tone guidelines:**
- Professional, not emotional ("N+1 query pattern" not "terrible queries")
- Solution-oriented ("Fix: add index" not "needs fixing")
- Risk-focused ("Could expose user data" not "security is bad")
- Factual ("3.5s load time" not "really slow")

**Useful for phase planning when:**
- Deciding what to work on next
- Estimating risk of changes
- Understanding where to be careful
- Prioritizing improvements
- Onboarding new assistant contexts
- Planning refactoring work

**How this gets populated:**
Explore agents detect these during codebase mapping. Manual additions welcome for human-discovered issues. This is living documentation, not a complaint list.
</guidelines>
