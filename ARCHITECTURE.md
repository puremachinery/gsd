# GSD Architecture

## Overview

GSD has two parts:
1. **Prompt content** (markdown) - the workflows, templates, and references.
2. **Installer + hooks** (native Nim binary) - installs content and integrates with host tools.

GSD works with Claude Code today and supports Codex CLI. It is designed to extend to other tools that support subagents.

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

## Installed Layout (v0.3)

After install, GSD uses a shared `.gsd/` directory alongside tool-specific directories:

```
~/.gsd/                     ← GSD-owned, shared
├── gsd-config.json
├── templates/
├── workflows/
├── references/
├── cache/
└── VERSION

~/.claude/                  ← Claude-specific only
├── commands/gsd/           (refs → @~/.gsd/)
├── agents/gsd-*.md         (refs → @~/.gsd/)
└── settings.json

~/.codex/                   ← Codex-specific only
├── prompts/gsd-*.md        (refs → @~/.gsd/)
├── AGENTS.md               (refs → @~/.gsd/)
└── config.toml
```

Shared resources (templates, workflows, references) live in `.gsd/` and are never duplicated. Tool directories contain only tool-specific integration files (commands, agents, settings).

---

## Installer / CLI (Nim)

Entry point: `installer/src/gsd.nim`

Commands:
- `install` / `uninstall`
- `update`
- `doctor`
- `statusline` (hook)
- `check-update` (hook)

The installer performs a two-phase install:
1. **Shared resources** — copies `gsd/` contents (templates, workflows, references) into `.gsd/`, writes `VERSION` and `gsd-config.json`, creates `cache/`.
2. **Tool-specific files** — copies commands/agents into `.claude/` or `.codex/`, merges tool settings without clobbering user customizations.

---

## Config Resolution

**Goal:** Always target the correct installation when multiple exist.

Resolution order:
1. `--config-dir` flag (explicit)
2. `GSD_CONFIG_DIR` env var
3. Local `./.gsd/gsd-config.json` (when running inside a project)
4. Global `~/.gsd/gsd-config.json`
5. Legacy fallback: `.claude/gsd-config.json` or `.codex/gsd-config.json` (v0.2 compat)

`gsd-config.json` lives in `.gsd/` and stores the resolved GSD directory, install type, platforms, and version:

```json
{
  "version": "0.3.4",
  "install_type": "global",
  "gsd_dir": "/Users/name/.gsd",
  "platforms": ["claude", "codex"],
  "installed_at": "2026-01-28T10:30:00Z"
}
```

Key fields:
- `gsd_dir` — path to the `.gsd/` directory (replaces v0.2 `config_dir`)
- `platforms` — array of installed platforms (replaces v0.2 `platform` string)

Hooks and statusline commands always include `--config-dir` pointing to the `.gsd/` directory to avoid cwd ambiguity.

---

## Settings Merge Strategy

GSD merges into existing tool settings instead of replacing them.

Principles:
- Preserve non-GSD hooks and statuslines.
- Tag GSD-owned hooks with a stable marker (e.g., `#gsd`) so updates are safe.
- If JSON is invalid, back it up and continue with a clean object.

Claude Code settings use the `statusLine` key and a nested `hooks` object. Codex CLI uses `config.toml` with `[[notify]]` hooks; integration is supported via a text-preserving merge.

---

## Path Rewriting and @-Refs

Prompt content uses `@` references for lazy-loading. The canonical form in source is `@~/.gsd/templates/...`. During install, references are rewritten based on install type:

| Install Type | Rewrite Rule |
|-------------|-------------|
| Global | No rewrite needed (source form is correct) |
| Local | `@~/.gsd/` → `@.gsd/` |
| Custom | `@~/.gsd/` → `@{customPath}/` |

This keeps content portable without maintaining duplicate copies. The rewriting is simpler than v0.2 since resource paths no longer depend on the platform.

---

## Update Checking

`check-update` hits the GitHub releases API with ETag caching. It supports `GITHUB_TOKEN` for higher rate limits and caches results in `.gsd/cache/` to avoid frequent network calls.

---

## Statusline Hook

The statusline hook reads JSON from stdin (provided by the host tool) and writes ANSI output. It combines host-provided context with local project state.

**Parsed from stdin JSON:**
- `model.display_name` — model name
- `workspace.current_dir` — extracts directory basename as project name
- `session_id` — parsed but not displayed
- `context_window.remaining_percentage` — rendered as a usage bar

**Read locally:**
- `.planning/STATE.md` — scans for `**Current:**` or `**Working on:**` markers to show current task
- `.gsd/cache/gsd-update-check.json` — shows `⬆ update` indicator when a newer release exists

Example input:

```json
{
  "model": {"display_name": "Claude Opus 4.6"},
  "workspace": {"current_dir": "/Users/name/my-project"},
  "session_id": "abc-123",
  "context_window": {"remaining_percentage": 72}
}
```

Example output (with a current task in STATE.md):

```
Claude Opus 4 │ Implement auth flow │ my-project │ ██░░░░░░░░ 28%
```

The context bar shows usage (100 minus remaining). Color thresholds: green < 50%, yellow 50–80%, red+blink >= 80%. Segments with no data are omitted.

---

## Local vs Global Storage

| Install Type | GSD Dir | Tool Dirs | Cache | VERSION |
|--------------|---------|-----------|-------|---------|
| Global | `~/.gsd/` | `~/.claude/`, `~/.codex/` | `~/.gsd/cache/` | `~/.gsd/VERSION` |
| Local | `./.gsd/` | `./.claude/`, `./.codex/` | `./.gsd/cache/` | `./.gsd/VERSION` |
| Custom | user-specified | inferred from install type | `{gsdDir}/cache/` | `{gsdDir}/VERSION` |

---

## Platform Notes

- **Claude Code:** Uses `commands/gsd` for slash commands and `settings.json` hooks (`statusLine`, `hooks`).
- **Codex CLI:** Uses `prompts/gsd-*.md` for commands, `AGENTS.md` for agent definitions, and `config.toml` for hooks.

### Codex CLI Integration Decisions

These decisions were made during the v0.2.0 implementation:

**1. Config Root: `~/.codex`**

Uses `~/.codex/` as the tool-specific config directory, mirroring the Claude Code approach (`~/.claude/`). Shared resources live in `~/.gsd/`. Custom paths are supported via `--config-dir`.

**2. Integration Surface: AGENTS.md + prompts/**

| Claude Code | Codex CLI |
|-------------|-----------|
| `commands/gsd/*.md` | `prompts/gsd-*.md` |
| `agents/gsd-*.md` (separate files) | `AGENTS.md` (concatenated) |
| `settings.json` hooks | `config.toml` `[[notify]]` hooks |

Commands are installed as `prompts/gsd-help.md`, `prompts/gsd-new-project.md`, etc. Agents are concatenated into a single `AGENTS.md` file (Codex convention). The `#gsd` marker tags GSD-owned hooks for safe updates.

**3. Repo Layout: Shared Source**

No separate `codex/` or `platforms/codex/` directory. The same source content (`gsd/`, `commands/`, `agents/`) is used for both platforms. The installer handles platform-specific transformations:

- Path references rewritten during install (`@~/.gsd/` adjusted for local/custom installs)
- Commands renamed (`help.md` → `gsd-help.md`)
- Agents concatenated into single file

This avoids content duplication and ensures both platforms stay in sync.
