# Codebase Concerns Template

Template for `.planning/codebase/CONCERNS.md` - captures risks, bottlenecks, and fragile areas.

**Purpose:** Identify fragile areas, performance bottlenecks, security risks, and operational concerns.

---

## File Template

```markdown
# Codebase Concerns

**Analysis Date:** [YYYY-MM-DD]

## Security Considerations

**[Concern]:**
- Risk: [What could go wrong]
- Evidence: [Where observed]
- Current mitigation: [If any]
- Recommendation: [What to change]

## Performance Bottlenecks

**[Concern]:**
- Problem: [What is slow]
- Evidence: [Metrics or observation]
- Cause: [Root cause]
- Improvement path: [What to do]

## Reliability / Stability

**[Concern]:**
- Symptoms: [What fails]
- Trigger: [When it happens]
- Workaround: [If any]
- Fix: [Recommended fix]

## Operational Risks

**[Concern]:**
- Deployment risk: [What could break]
- Monitoring gaps: [What is not observed]
- Rollback plan: [If known]

## Scaling Limits

**[Concern]:**
- Limit: [What will not scale]
- Evidence: [Why this is a limit]
- Recommendation: [How to address]

---

*Concerns analysis: [date]*
*Update as risks change*
```
