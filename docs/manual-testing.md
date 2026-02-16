# GSD QA Testing Guide

Manual test scenarios for validating GSD installation and multi-platform support.

**Prerequisites:**
- Built `gsd` binary (run `nimble build` in `installer/`)
- Access to a terminal
- Clean state recommended: back up and remove `~/.gsd`, `~/.claude`, and `~/.codex` before testing

---

## Scenario 1: Interactive Install (Fresh System)

**Setup:**
```bash
rm -rf ~/.gsd ~/.claude ~/.codex
```

**Steps:**

1. Run install without flags:
   ```bash
   ./gsd install
   ```

2. **Expected:** Interactive menu appears:
   ```
   Select platform to install GSD:
     1) Claude Code
     2) Codex CLI
     3) Both

   Shared resources install to ~/.gsd/

   Enter choice [1-3]:
   ```

3. Enter `3` and press Enter.

4. **Expected output:**
   ```
   Installing GSD to /Users/<you>/.gsd + /Users/<you>/.claude...
     Installed shared resources to /Users/<you>/.gsd
     Installed commands/gsd
     Installed agents

   Installing GSD to /Users/<you>/.gsd + /Users/<you>/.codex (Codex CLI)...
     Installed shared resources to /Users/<you>/.gsd
     Installed prompts
     Generated AGENTS.md

   Claude Code: Use /gsd:help to get started.
   Codex CLI: Use /prompts:gsd-help to get started.
   ```

5. **Verify files exist:**
   ```bash
   ls ~/.gsd/gsd-config.json ~/.gsd/VERSION
   ls ~/.claude/commands/gsd/
   ls ~/.codex/prompts/gsd-*.md
   ```

---

## Scenario 2: Install with --platform=both Flag

**Setup:**
```bash
rm -rf ~/.gsd ~/.claude ~/.codex
```

**Steps:**

1. Run install with explicit flag:
   ```bash
   ./gsd install --platform=both
   ```

2. **Expected:** No interactive prompt. Both platforms install directly.

3. **Verify:**
   ```bash
   ./gsd doctor
   ```

4. **Expected output includes:**
   ```
   Checking GSD installation at /Users/<you>/.gsd (claude)...
   [OK] gsd-config.json exists
   ...
   Installation is healthy!

   ---

   Checking GSD installation at /Users/<you>/.gsd (codex)...
   [OK] gsd-config.json exists
   ...
   Installation is healthy!

   ===

   All 2 installations are healthy!
   ```

**Note:** If you have both local and global installs, doctor will report each installation separately.

---

## Scenario 3: Install Single Platform (Claude Only)

**Setup:**
```bash
rm -rf ~/.gsd ~/.claude ~/.codex
```

**Steps:**

1. Run interactive install, select option 1:
   ```bash
   ./gsd install
   # Enter: 1
   ```

2. **Expected:** Only Claude Code installs.

3. **Verify:**
   ```bash
   ls ~/.gsd/gsd-config.json         # Should exist
   ls ~/.claude/commands/gsd/        # Should exist
   ls ~/.codex/prompts/gsd-*.md      # Should fail: No such file
   ```

4. Run doctor:
   ```bash
   ./gsd doctor
   ```

5. **Expected:** Only checks Claude installation (no "2 installations" message).

---

## Scenario 4: Install Single Platform (Codex Only)

**Setup:**
```bash
rm -rf ~/.gsd ~/.claude ~/.codex
```

**Steps:**

1. Run with explicit flag:
   ```bash
   ./gsd install --platform=codex
   ```

2. **Expected:** Only Codex CLI installs.

3. **Verify:**
   ```bash
   ls ~/.gsd/gsd-config.json         # Should exist
   ls ~/.codex/prompts/gsd-help.md   # Should exist
   ls ~/.codex/AGENTS.md             # Should exist
   ls ~/.claude/commands/gsd/        # Should fail: No such file
   ```

---

## Scenario 5: Doctor with Multiple Installations

**Setup:** Both platforms installed (run Scenario 1 or 2 first).

**Steps:**

1. Run doctor without flags:
   ```bash
   ./gsd doctor
   ```

2. **Expected:** Checks both installations with summary:
   ```
   Checking GSD installation at ~/.gsd (claude)...
   ...
   Installation is healthy!

   ---

   Checking GSD installation at ~/.gsd (codex)...
   ...
   Installation is healthy!

   ===

   All 2 installations are healthy!
   ```

**Note:** If you also have local installs (./.gsd), doctor will include them too.

3. Run doctor for specific platform:
   ```bash
   ./gsd doctor --platform=codex
   ```

4. **Expected:** Only checks Codex installation.

---

## Scenario 6: Doctor with No Installation

**Setup:**
```bash
rm -rf ~/.gsd ~/.claude ~/.codex
```

**Steps:**

1. Run doctor:
   ```bash
   ./gsd doctor
   ```

2. **Expected:**
   ```
   No GSD installation found.

   Run 'gsd install' to install GSD.
   ```
   Exit code: 1

---

## Scenario 7: Update All Installed Platforms

**Setup:** Both platforms installed.

**Steps:**

1. Run update:
   ```bash
   ./gsd update
   ```

2. **Expected:** Re-installs both platforms:
   ```
   Installing GSD to /Users/<you>/.gsd + /Users/<you>/.claude...
     Installed shared resources to /Users/<you>/.gsd
     Installed commands/gsd
     Installed agents

   Installing GSD to /Users/<you>/.gsd + /Users/<you>/.codex (Codex CLI)...
     Installed shared resources to /Users/<you>/.gsd
     Installed prompts
     Generated AGENTS.md

   Update complete!
   ```

**Note:** If local installs exist, they are updated too.

3. **Verify versions match:**
   ```bash
   cat ~/.gsd/VERSION
   ```

---

## Scenario 8: Update Specific Platform

**Setup:** Both platforms installed.

**Steps:**

1. Run update for Codex only:
   ```bash
   ./gsd update --platform=codex
   ```

2. **Expected:** Only Codex re-installs.

---

## Scenario 9: Update with No Installation

**Setup:**
```bash
rm -rf ~/.gsd ~/.claude ~/.codex
```

**Steps:**

1. Run update:
   ```bash
   ./gsd update
   ```

2. **Expected:**
   ```
   No GSD installation found. Run 'gsd install' first.
   ```
   Exit code: 1

---

## Scenario 10: Uninstall with Multiple Platforms (Interactive)

**Setup:** Both platforms installed.

**Steps:**

1. Run uninstall without flags:
   ```bash
   ./gsd uninstall
   ```

2. **Expected:** Interactive prompt:
   ```
   GSD is installed for multiple platforms. Select which to uninstall:
     1) claude (/Users/<you>/.gsd)
     2) codex (/Users/<you>/.gsd)
     3) All

   Enter choice [1-3]:
   ```

   **Note:** Paths reflect the `.gsd/` directory (local or global).

3. Enter `1` to uninstall Claude only.

4. **Expected:**
   ```
   Uninstalling GSD from /Users/<you>/.claude...
   GSD uninstalled.
   ```

5. **Verify:**
   ```bash
   cat ~/.gsd/gsd-config.json | grep platforms
   # Should show only ["codex"]
   ls ~/.claude/commands/gsd/        # Should fail (removed)
   ls ~/.codex/prompts/gsd-*.md      # Should exist
   ```

---

## Scenario 11: Uninstall All Platforms

**Setup:** Both platforms installed.

**Steps:**

1. Run uninstall with --all flag:
   ```bash
   ./gsd uninstall --all
   ```

2. **Expected:** Both uninstall without prompting:
   ```
   Uninstalling GSD from /Users/<you>/.claude...
   GSD uninstalled.
   Uninstalling GSD from /Users/<you>/.codex (Codex CLI)...
   GSD (Codex CLI) uninstalled.
   ```

**Note:** If local installs exist, they are removed too.

3. **Verify:**
   ```bash
   ls ~/.gsd/gsd-config.json    # Should fail (removed)
   ls ~/.claude/commands/gsd/   # Should fail
   ls ~/.codex/prompts/         # Should fail
   ```

---

## Scenario 12: Uninstall Specific Platform

**Setup:** Both platforms installed.

**Steps:**

1. Run uninstall with platform flag:
   ```bash
   ./gsd uninstall --platform=codex
   ```

2. **Expected:** Only Codex uninstalls, no prompt.

3. **Verify:**
   ```bash
   cat ~/.gsd/gsd-config.json | grep platforms
   # Should show only ["claude"]
   ls ~/.claude/commands/gsd/        # Should exist
   ls ~/.codex/prompts/gsd-*.md      # Should fail
   ```

---

## Scenario 13: Uninstall Single Installation (No Prompt)

**Setup:** Only Claude installed.
```bash
rm -rf ~/.gsd ~/.claude ~/.codex
./gsd install --platform=claude
```

**Steps:**

1. Run uninstall:
   ```bash
   ./gsd uninstall
   ```

2. **Expected:** Uninstalls directly without prompting (only one option).

---

## Scenario 14: Non-Interactive Install (CI/Scripts)

**Setup:**
```bash
rm -rf ~/.gsd ~/.claude ~/.codex
```

**Steps:**

1. Run install with stdin not a TTY:
   ```bash
   echo "" | ./gsd install
   ```

2. **Expected:** No prompt, defaults to Claude Code only.

3. **Verify:**
   ```bash
   ls ~/.gsd/gsd-config.json         # Should exist
   ls ~/.claude/commands/gsd/        # Should exist
   ls ~/.codex/prompts/gsd-*.md      # Should fail
   ```

---

## Scenario 15: Codex CLI Integration Verification

**Setup:** Codex installed.

**Steps:**

1. Check prompts directory:
   ```bash
   ls ~/.codex/prompts/gsd-*.md
   ```

   **Expected:** Multiple files like `gsd-help.md`, `gsd-new-project.md`, etc.

2. Check AGENTS.md:
   ```bash
   head -20 ~/.codex/AGENTS.md
   ```

   **Expected:** Header with "GSD Agents" and concatenated agent definitions.

3. Check config.toml for hooks:
   ```bash
   grep -A2 "notify" ~/.codex/config.toml
   ```

   **Expected:** `[[notify]]` section with `#gsd` marker in command.

---

## Scenario 16: Claude Code Integration Verification

**Setup:** Claude installed.

**Steps:**

1. Check commands directory:
   ```bash
   ls ~/.claude/commands/gsd/
   ```

   **Expected:** Multiple `.md` files (help.md, new-project.md, etc.)

2. Check agents directory:
   ```bash
   ls ~/.claude/agents/gsd-*.md
   ```

   **Expected:** Multiple agent files.

3. Check settings.json for hooks:
   ```bash
   cat ~/.claude/settings.json | grep -A5 '"hooks"'
   ```

   **Expected:** `SessionStart` hook with `#gsd` marker.

4. Check statusline:
   ```bash
   cat ~/.claude/settings.json | grep -A3 '"statusLine"'
   ```

   **Expected:** `statusLine` with gsd command.

---

## Scenario 17: Help Output

**Steps:**

1. Run help:
   ```bash
   ./gsd --help
   ```

2. **Expected:** Help text includes:
   - `install` command
   - `uninstall` command
   - `update` command
   - `doctor` command
   - `--platform` option mentioning `claude, codex, or both`

3. Run install help:
   ```bash
   ./gsd install --help
   ```

4. **Expected:** Install-specific options listed.

---

## Scenario 18: Version Output

**Steps:**

1. Run version:
   ```bash
   ./gsd --version
   ```

2. **Expected:** Version string like `gsd 0.3.3`

---

## Scenario 19: Local + Global Installs (Same Platform)

**Setup:** Install both local and global for Claude.
```bash
rm -rf ~/.gsd ./.gsd ~/.claude ./.claude
./gsd install --global --platform=claude
./gsd install --local --platform=claude
```

**Steps:**

1. Run doctor:
   ```bash
   ./gsd doctor --platform=claude
   ```

2. **Expected:** Two entries, one for each install path:
   ```
   Checking GSD installation at /Users/<you>/.gsd (claude)...
   ...

   ---

   Checking GSD installation at /path/to/project/.gsd (claude)...
   ...

   ===

   All 2 installations are healthy!
   ```

3. Run update:
   ```bash
   ./gsd update --platform=claude
   ```

4. **Expected:** Both installs are re-installed.

---

## Scenario 20: Custom Config Directory

**Setup:** Custom config directory containing a valid gsd-config.json.

**Steps:**

1. Install to a custom directory:
   ```bash
   ./gsd install --config-dir /tmp/test-gsd --platform=claude
   ```

2. Run doctor with `--config-dir`:
   ```bash
   ./gsd doctor --config-dir /tmp/test-gsd
   ```

3. **Expected:** Only the specified directory is checked.

4. Test the env var (same behavior, lower priority than flag):
   ```bash
   export GSD_CONFIG_DIR="/tmp/test-gsd"
   ./gsd doctor
   ```

5. **Expected:** Same result. The env var is used when `--config-dir` is not provided.

**Note:** Both `--config-dir` and `GSD_CONFIG_DIR` point to a `.gsd/` directory. Tool-specific directories are inferred from the install type. The env var is not listed in `--help` output but is part of the config resolution chain.

**Note:** `--config-dir` cannot be combined with `--platform=both`. If `gsd-config.json` is missing, GSD will infer the platform from installed files; provide `--platform` if inference is ambiguous.

---

## Scenario 21: v0.2 → v0.3 Migration

**Setup:** Simulate a v0.2 install (config in tool directory, not `.gsd/`).
```bash
rm -rf ~/.gsd ~/.claude ~/.codex
mkdir -p ~/.claude
cat > ~/.claude/gsd-config.json << 'EOF'
{
  "version": "0.2.0",
  "platform": "claude",
  "config_dir": "/Users/you/.claude",
  "installed_at": "2026-01-19T00:00:00Z"
}
EOF
```

**Steps:**

1. Run install over the old layout:
   ```bash
   ./gsd install --platform=claude
   ```

2. **Expected:**
   - Shared resources install to `~/.gsd/` (new location)
   - New `gsd-config.json` written to `~/.gsd/` with `gsd_dir` and `platforms` fields
   - Old `~/.claude/gsd-config.json` is superseded (new config takes precedence in resolution)
   - Statusline hook updated to point to new `~/.gsd/` path

3. **Verify:**
   ```bash
   cat ~/.gsd/gsd-config.json | grep gsd_dir    # Should show ~/.gsd
   cat ~/.gsd/gsd-config.json | grep platforms   # Should show ["claude"]
   ./gsd doctor
   ```

4. **Expected:** Doctor reports healthy installation at `~/.gsd`.

---

## Scenario 22: Local and Global Install Conflict

**Setup:**
```bash
rm -rf ~/.gsd ./.gsd ~/.claude ./.claude
```

**Steps:**

1. Install globally:
   ```bash
   ./gsd install --global --platform=claude
   ```

2. Install locally in same project:
   ```bash
   ./gsd install --local --platform=claude
   ```

3. Run doctor from the project directory:
   ```bash
   ./gsd doctor
   ```

4. **Expected:** Two separate installations reported:
   ```
   Checking GSD installation at /Users/<you>/.gsd (claude)...
   ...
   Installation is healthy!

   ---

   Checking GSD installation at /path/to/project/.gsd (claude)...
   ...
   Installation is healthy!

   ===

   All 2 installations are healthy!
   ```

5. Run update:
   ```bash
   ./gsd update
   ```

6. **Expected:** Both installations are re-installed.

7. Uninstall only local:
   ```bash
   ./gsd uninstall --local --platform=claude
   ```

8. **Expected:** Only `./.gsd` removed; `~/.gsd` remains intact.

---

## Scenario 23: Install Rollback on Failure

**Purpose:** Verify that a failed fresh install doesn't leave partial state behind.

**Setup:**
```bash
rm -rf ~/.gsd ~/.claude
```

**Steps:**

1. Create a read-only directory where `.claude/settings.json` would go:
   ```bash
   mkdir -p ~/.claude
   mkdir ~/.claude/settings.json   # directory, not file — forces write failure
   ```

2. Run install:
   ```bash
   ./gsd install --platform=claude
   ```

3. **Expected:**
   - Install fails with an error about settings.json
   - `~/.gsd/` is **removed** (was freshly created, rolled back)
   - `~/.claude/` is **preserved** (existed before install)
   - Stderr shows: `Rolled back: removed /Users/<you>/.gsd`

4. **Verify:**
   ```bash
   ls ~/.gsd/            # Should fail: No such file or directory
   ls ~/.claude/         # Should exist
   ```

5. **Cleanup:**
   ```bash
   rm -rf ~/.claude/settings.json
   ```

**Variant (update case):** If both `~/.gsd/` and `~/.claude/` exist before the failed install, neither should be removed (prior state is still valid).

---

## Scenario 24: Post-Install Workflow Smoke Test

**Purpose:** Verify that GSD actually works end-to-end after installation.

**Setup:** Claude Code installed globally.

**Steps:**

1. Open Claude Code in a test project:
   ```bash
   mkdir /tmp/gsd-smoke-test && cd /tmp/gsd-smoke-test
   ```

2. Verify slash commands are available:
   - Type `/gsd:help` — should show GSD help and command list
   - Type `/gsd:status` — should report project state (no project initialized yet)

3. Verify statusline is active:
   - The Claude Code status bar should show GSD info (version, context usage)

4. Verify session hook fires:
   - Start a new session — the check-update hook should run silently
   - Check cache was written:
     ```bash
     ls ~/.gsd/cache/gsd-update-check.json
     ```

5. **Cleanup:**
   ```bash
   rm -rf /tmp/gsd-smoke-test
   ```

---

## Edge Cases

### Invalid Platform Flag
```bash
./gsd install --platform=vscode
```
**Expected:** Error message and exit code 1.

### Uninstall Non-Existent Platform
```bash
./gsd uninstall --platform=codex
```
**Expected:** Error message about no installation found.

### Doctor on Corrupted Installation
```bash
rm ~/.gsd/VERSION
./gsd doctor --platform=claude
```
**Expected:** Reports "VERSION file missing" as an issue.

---

## Test Matrix Summary

| Scenario | Install | Doctor | Update | Uninstall |
|----------|---------|--------|--------|-----------|
| No installations | Prompt | Error | Error | Error |
| Claude only | - | Check 1 | Update 1 | No prompt |
| Codex only | - | Check 1 | Update 1 | No prompt |
| Both installed | - | Check 2 | Update 2 | Prompt |
| --platform=both | Install 2 | - | - | Uninstall 2 |
| --all flag | - | - | - | Uninstall all |
| Non-interactive | Default Claude | - | - | Error if multiple |
| v0.2 → v0.3 migration | Over-install | Check 1 | - | - |
| Local + global | Install 2 | Check 2 | Update 2 | Per-scope |
| Rollback on failure | Rolled back | - | - | - |
| Post-install smoke | - | - | - | - |
