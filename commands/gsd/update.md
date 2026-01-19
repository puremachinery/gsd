---
name: gsd:update
description: Update GSD to latest version with changelog display
---

<objective>
Check for GSD updates, install if available, and display what changed.
</objective>

<process>

<step name="get_installed_version">
Check for VERSION file (local install takes priority over global):

```bash
# Try local first, then global
if [ -f "./.claude/gsd/VERSION" ]; then
  cat ./.claude/gsd/VERSION
elif [ -f ~/.claude/gsd/VERSION ]; then
  cat ~/.claude/gsd/VERSION
else
  echo "not-installed"
fi
```

**If VERSION file missing:**
```
## GSD Update

**Installed version:** Unknown

Your installation doesn't include version tracking.

Please reinstall GSD from https://github.com/puremachinery/gsd/releases
```

Proceed to check step (treat as version 0.0.0 for comparison).
</step>

<step name="check_latest_version">
Check GitHub API for latest release:

Use WebFetch tool with:
- URL: `https://api.github.com/repos/puremachinery/gsd/releases/latest`
- Prompt: "Extract the tag_name field (version number) from this GitHub release JSON. If the response is a 404 or 'Not Found', return 'no-releases'."

**If response is 404 or "Not Found"** (no releases published yet):
```
## GSD Update

No releases published yet. You're running a development version.

Check https://github.com/puremachinery/gsd/releases for future releases.
```

STOP here if no releases.

**If fetch fails for other reasons** (network error, timeout):
```
Couldn't check for updates (offline or GitHub unavailable).

Check manually: https://github.com/puremachinery/gsd/releases
```

STOP here if GitHub unavailable.
</step>

<step name="compare_versions">
Compare installed vs latest:

**If installed == latest:**
```
## GSD Update

**Installed:** X.Y.Z
**Latest:** X.Y.Z

You're already on the latest version.
```

STOP here if already up to date.

**If installed > latest:**
```
## GSD Update

**Installed:** X.Y.Z
**Latest:** A.B.C

You're ahead of the latest release (development version?).
```

STOP here if ahead.
</step>

<step name="show_changes_and_confirm">
**If update available**, fetch and show what's new BEFORE updating:

1. Fetch changelog from GitHub
2. Extract entries between installed and latest versions
3. Display preview and ask for confirmation:

```
## GSD Update Available

**Installed:** X.Y.Z
**Latest:** X.Y.Z+1

### What's New
────────────────────────────────────────────────────────────

[Changelog entries extracted from CHANGELOG.md]

────────────────────────────────────────────────────────────
```

Use AskUserQuestion:
- Question: "Proceed with update?"
- Options:
  - "Yes, update now"
  - "No, cancel"

**If user cancels:** STOP here.
</step>

<step name="run_update">
Guide user to download and install. **Match the install type detected in step 1:**

**If local VERSION was found** (`./.claude/gsd/VERSION`):
```
Download the latest release for your platform:
https://github.com/puremachinery/gsd/releases/latest

Then run: gsd install --local
```

**If global VERSION was found** (`~/.claude/gsd/VERSION`):
```
Download the latest release for your platform:
https://github.com/puremachinery/gsd/releases/latest

Then run: gsd install --global
```

Clear the update cache so statusline indicator disappears:

```bash
# Clear from the detected install location
rm -f ./.claude/cache/gsd-update-check.json 2>/dev/null   # if local
rm -f ~/.claude/cache/gsd-update-check.json 2>/dev/null   # if global
```
</step>

<step name="display_result">
Format completion message:

```
╔═══════════════════════════════════════════════════════════╗
║  GSD Updated: vX.Y.Z → vX.Y.Z+1                           ║
╚═══════════════════════════════════════════════════════════╝

Restart your tool (Claude Code; Codex CLI planned) to pick up the new commands.

View full changelog: https://github.com/puremachinery/gsd/blob/master/CHANGELOG.md
```
</step>

</process>

<success_criteria>
- [ ] Installed version read correctly
- [ ] Latest version checked via GitHub API
- [ ] Update skipped if already current
- [ ] Changelog fetched and displayed BEFORE update
- [ ] User confirmation obtained
- [ ] Update executed successfully
- [ ] Restart reminder shown
</success_criteria>
