# Neutral GSD Core (Skeleton)

Purpose: stack-agnostic planning and verification framework for autonomous assistants.

This folder is a clean, neutral baseline. It intentionally avoids stack, vendor, or tool bias.
Use it as the source of truth for new content. Port legacy material only after it passes the
neutrality checklist in FRAMEWORK.md.

## Scope
- Planning, execution, verification, and transition workflows
- Templates for plan, requirements, verification, summary, and decisions
- Minimal agent role definitions (planner, executor, verifier, researcher, debugger)

## Non-Goals
- Stack-specific guidance
- Tool-specific commands
- Language or framework defaults

## How to use
1. Start with FRAMEWORK.md to align on the conceptual model.
2. Copy templates into a project planning folder and fill them in.
3. Use workflows to guide phase execution.
4. Keep examples generic and replace placeholders with project-specific terms.

## Compatibility
This core is tool-agnostic. Platform integration (Claude, Codex, etc.) should live elsewhere.
