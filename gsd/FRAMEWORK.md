# Neutral Framework

## Principles
- Neutral by default: no vendor, language, or framework bias.
- Explicit placeholders: use [Placeholders] and replace per project.
- Evidence over existence: verify that artifacts are real, wired, and functional.
- Human steps are last resort: prefer automation where possible.

## Core Artifacts
- PLAN.md: tasks, sequencing, and acceptance criteria
- REQUIREMENTS.md: user-visible requirements and status
- CONTEXT.md: decisions and constraints for the current phase
- VERIFICATION.md: verification results and gaps
- SUMMARY.md: what shipped, decisions, and deviations

## Phases
1. Discuss: clarify intent and constraints
2. Plan: produce tasks with files, actions, and verification
3. Execute: implement tasks with evidence
4. Verify: prove goals are met, identify gaps
5. Transition: update context and prepare next phase

## Definitions
- Module: a cohesive unit of UI, service, or logic
- Service: a callable interface for functionality
- Handler: entry point for requests or events
- Wire: explicit connection between artifacts

## Neutrality Checklist
- No vendor, framework, or language names
- No toolchain-specific commands
- No file paths tied to a specific stack
- Examples use placeholders, not real brands
