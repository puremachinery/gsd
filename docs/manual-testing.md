# GSD QA Testing Guide

Manual test scenarios for validating GSD installation and multi-platform support.

**Prerequisites:**
- Built `gsd` binary (run `nimble build` in `installer/`)
- Access to a terminal
- Clean state recommended: back up and remove `~/.claude` and `~/.codex` before testing

---

## Scenario 1: Interactive Install (Fresh System)

**Setup:**
```bash
rm -rf ~/.claude ~/.codex
```

**Steps:**

1. Run install without flags:
   ```bash
   ./gsd install
   ```

2. **Expected:** Interactive menu appears:
   ```
   Select platform to install GSD:
     1) Claude Code (~/.claude/)
     2) Codex CLI (~/.codex/)
     3) Both

   Enter choice [1-3]:
   ```

3. Enter `3` and press Enter.

4. **Expected output:**
   ```
   Installing GSD to /Users/<you>/.claude...
     Installed gsd resources
     Installed commands/gsd
     Installed agents

   Installing GSD to /Users/<you>/.codex (Codex CLI)...
     Installed gsd resources
     Installed prompts
     Generated AGENTS.md

   Claude Code: Use /gsd:help to get started.
   Codex CLI: Use /prompts:gsd-help to get started.
   ```

5. **Verify files exist:**
   ```bash
   ls ~/.claude/gsd-config.json ~/.claude/gsd/VERSION
   ls ~/.codex/gsd-config.json ~/.codex/gsd/VERSION
   ```

---

## Scenario 2: Install with --platform=both Flag

**Setup:**
```bash
rm -rf ~/.claude ~/.codex
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
   Checking GSD installation at /Users/<you>/.claude (claude)...
   [OK] gsd-config.json exists
   ...
   Installation is healthy!

   ---

   Checking GSD installation at /Users/<you>/.codex (codex)...
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
rm -rf ~/.claude ~/.codex
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
   ls ~/.claude/gsd-config.json    # Should exist
   ls ~/.codex/gsd-config.json     # Should fail: No such file
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
rm -rf ~/.claude ~/.codex
```

**Steps:**

1. Run with explicit flag:
   ```bash
   ./gsd install --platform=codex
   ```

2. **Expected:** Only Codex CLI installs.

3. **Verify:**
   ```bash
   ls ~/.codex/gsd-config.json     # Should exist
   ls ~/.codex/prompts/gsd-help.md # Should exist
   ls ~/.codex/AGENTS.md           # Should exist
   ls ~/.claude/gsd-config.json    # Should fail: No such file
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
   Checking GSD installation at ~/.claude (claude)...
   ...
   Installation is healthy!

   ---

   Checking GSD installation at ~/.codex (codex)...
   ...
   Installation is healthy!

   ===

   All 2 installations are healthy!
   ```

**Note:** If you also have local installs (./.claude and/or ./.codex), doctor will include them too.

3. Run doctor for specific platform:
   ```bash
   ./gsd doctor --platform=codex
   ```

4. **Expected:** Only checks Codex installation.

---

## Scenario 6: Doctor with No Installation

**Setup:**
```bash
rm -rf ~/.claude ~/.codex
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
   Installing GSD to /Users/<you>/.claude...
     Installed gsd resources
     Installed commands/gsd
     Installed agents

   Installing GSD to /Users/<you>/.codex (Codex CLI)...
     Installed gsd resources
     Installed prompts
     Generated AGENTS.md

   Update complete!
   ```

**Note:** If local installs exist, they are updated too.

3. **Verify versions match:**
   ```bash
   cat ~/.claude/gsd/VERSION
   cat ~/.codex/gsd/VERSION
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
rm -rf ~/.claude ~/.codex
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
     1) claude (/Users/<you>/.claude)
     2) codex (/Users/<you>/.codex)
     3) All

   Enter choice [1-3]:
   ```

   **Note:** Paths reflect the actual install location (local or global).

3. Enter `1` to uninstall Claude only.

4. **Expected:**
   ```
   Uninstalling GSD from /Users/<you>/.claude...
   GSD uninstalled.
   ```

5. **Verify:**
   ```bash
   ls ~/.claude/gsd-config.json    # Should fail
   ls ~/.codex/gsd-config.json     # Should exist
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
   GSD uninstalled.
   ```

**Note:** If local installs exist, they are removed too.

3. **Verify:**
   ```bash
   ls ~/.claude/gsd-config.json    # Should fail
   ls ~/.codex/gsd-config.json     # Should fail
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
   ls ~/.claude/gsd-config.json    # Should exist
   ls ~/.codex/gsd-config.json     # Should fail
   ```

---

## Scenario 13: Uninstall Single Installation (No Prompt)

**Setup:** Only Claude installed.
```bash
rm -rf ~/.claude ~/.codex
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
rm -rf ~/.claude ~/.codex
```

**Steps:**

1. Run install with stdin not a TTY:
   ```bash
   echo "" | ./gsd install
   ```

2. **Expected:** No prompt, defaults to Claude Code only.

3. **Verify:**
   ```bash
   ls ~/.claude/gsd-config.json    # Should exist
   ls ~/.codex/gsd-config.json     # Should fail
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

2. **Expected:** Version string like `gsd 0.2.0`

---

## Edge Cases

### Invalid Platform Flag
```bash
./gsd install --platform=vscode
```
**Expected:** Error message and exit code 1.

### Uninstall Non-Existent Platform
```bash
rm -rf ~/.codex
./gsd uninstall --platform=codex
```
**Expected:** Error message about no installation found.

### Doctor on Corrupted Installation
```bash
rm ~/.claude/gsd/VERSION
./gsd doctor --platform=claude
```
**Expected:** Reports "VERSION file missing" as an issue.

---

## Scenario 19: Local + Global Installs (Same Platform)

**Setup:** Install both local and global for Claude.
```bash
rm -rf ~/.claude ./.claude
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
   Checking GSD installation at /Users/<you>/.claude (claude)...
   ...

   ---

   Checking GSD installation at /path/to/project/.claude (claude)...
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

## Scenario 20: GSD_CONFIG_DIR Override

**Setup:** Custom config directory containing a valid gsd-config.json.

**Steps:**

1. Set override:
   ```bash
   export GSD_CONFIG_DIR="/custom/gsd/config"
   ```

2. Run doctor:
   ```bash
   ./gsd doctor --config-dir "$GSD_CONFIG_DIR"
   ```

3. **Expected:** Only the specified directory is checked.

**Note:** `GSD_CONFIG_DIR` is ignored for platform-specific commands if the config’s platform doesn’t match the requested platform.

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
