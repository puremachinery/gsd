# Agent Guidelines

## Skill Path Resolution (Critical)

- When using a Codex skill, resolve all referenced files/scripts **relative to the skill directory first** (for example: `$CODEX_HOME/skills/<skill>/...`).
- Do not assume `scripts/...` paths in skill docs are repo-local.
- Before declaring a helper missing, verify both:
  1. skill-local path exists, then
  2. repo-local fallback path (only if skill-local is absent).
- If helper exists in the skill package, use it directly and do not create a duplicate in the repo unless the user explicitly asks to vendor it.
- When reporting "missing helper", include the exact checked paths so mistakes are auditable.
