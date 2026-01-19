# GSD Architecture

## Overview

GSD has two parts:
1. **Prompt content** (markdown) - the workflows, templates, and references.
2. **Installer + hooks** (native Nim binary) - installs content and integrates with host tools.

GSD works with Claude Code today and is designed to extend to other tools that support subagents. Codex CLI integration is planned.

---

## Repo Layout

```
.
├── gsd/                    # Core prompt content
│   ├── templates/          # PROJECT.md, PLAN.md, SUMMARY.md, etc
│   ├── references/         # Deep-dive guides and patterns
│   └── workflows/          # Orchestration workflows
├── commands/gsd/           # Claude Code slash commands
├── agents/                 # Subagent definitions (planner, verifier, debugger, etc)
├── installer/              # Nim CLI + hooks
├── assets/                 # Diagrams, screenshots, visuals
├── README.md
├── ARCHITECTURE.md
└── CHANGELOG.md
```

**Content strategy:** `gsd/` is platform-agnostic. Platform-specific integration happens through the installer and, where needed, tool-specific command/skill definitions.

---

## Installer / CLI (Nim)

Entry point: `installer/src/gsd.nim`

Commands:
- `install` / `uninstall`
- `doctor`
- `statusline` (hook)
- `check-update` (hook)

The installer copies `gsd/`, `commands/`, and `agents/` into the selected config root and merges tool settings without clobbering user customizations.

---

## Config Resolution

**Goal:** Always target the correct installation when multiple exist.

Resolution order:
1. `--config-dir` flag (explicit)
2. `GSD_CONFIG_DIR` env var
3. Local `./.claude/gsd-config.json` (when running inside a project)
4. Global `~/.claude/gsd-config.json`

`gsd-config.json` stores the resolved config root, install type, and version:

```json
{
  "version": "2.0.0",
  "install_type": "global",
  "config_dir": "/Users/name/.claude",
  "installed_at": "2026-01-17T10:30:00Z"
}
```

Hooks and statusline commands always include `--config-dir` to avoid cwd ambiguity.

---

## Settings Merge Strategy

GSD merges into existing tool settings instead of replacing them.

Principles:
- Preserve non-GSD hooks and statuslines.
- Tag GSD-owned hooks with a stable marker (e.g., `#gsd`) so updates are safe.
- If JSON is invalid, back it up and continue with a clean object.

Claude Code settings use the `statusLine` key and a nested `hooks` object. Codex CLI uses its own configuration format; integration is planned.

---

## Path Rewriting and @-Refs

Prompt content uses `@` references for lazy-loading. During install, references are rewritten so they remain correct for:
- **Global installs** (`~/.claude/gsd/...`)
- **Local installs** (`./.claude/gsd/...`)
- **Custom config dirs** (`/custom/path/gsd/...`)

This keeps content portable without maintaining duplicate copies.

---

## Update Checking

`check-update` hits the GitHub releases API with ETag caching. It supports `GITHUB_TOKEN` for higher rate limits and caches results locally to avoid frequent network calls.

---

## Statusline Hook

The statusline hook reads JSON from stdin and writes ANSI output. The exact payload depends on the host tool, but the hook expects model name, task label, and progress.

Example input:

```json
{
  "model": {"display_name": "Model Name"},
  "status": "Building auth system",
  "phase": "project",
  "progress": 0.6
}
```

Example output:

```
Model Name │ Building auth system │ project │ ██████░░░░ 60%
```

---

## Local vs Global Storage

| Install Type | Config Dir | Cache/Todos | VERSION |
|--------------|------------|-------------|---------|
| Global | `~/.claude/` | `~/.claude/cache/`, `~/.claude/todos/` | `~/.claude/gsd/VERSION` |
| Local | `./.claude/` | `./.claude/cache/`, `./.claude/todos/` | `./.claude/gsd/VERSION` |
| Custom | user-specified | `{config}/cache/`, `{config}/todos/` | `{config}/gsd/VERSION` |

---

## Platform Notes

- **Claude Code:** Uses `commands/gsd` for slash commands and `settings.json` hooks (`statusLine`, `hooks`).
- **Codex CLI (planned):** Will use its own config root (via `--config-dir`, `$CODEX_HOME`, or default). The same prompt content applies, but integration files are tool-specific.

