---
name: gsd:whats-new
description: See what's new in GSD since your installed version
---

<objective>
Display changes between installed version and latest available version.

Shows version comparison, changelog entries for missed versions, and update instructions.
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
## GSD What's New

**Installed version:** Unknown

Your installation doesn't include version tracking.

**To fix:** Download and reinstall from https://github.com/puremachinery/gsd/releases
```

STOP here if no VERSION file.
</step>

<step name="fetch_remote_changelog">
Fetch latest CHANGELOG.md from GitHub:

Use WebFetch tool with:
- URL: `https://raw.githubusercontent.com/puremachinery/gsd/master/CHANGELOG.md`
- Prompt: "Extract all version entries with their dates and changes. Return in Keep-a-Changelog format."

**If fetch fails:**
Fall back to local changelog (using resolved config dir):
```bash
# Try local first, then global
if [ -f "./.claude/gsd/CHANGELOG.md" ]; then
  cat ./.claude/gsd/CHANGELOG.md
elif [ -f ~/.claude/gsd/CHANGELOG.md ]; then
  cat ~/.claude/gsd/CHANGELOG.md
fi
```

Note to user: "Couldn't check for updates (offline or GitHub unavailable). Showing local changelog."
</step>

<step name="parse_versions">
From the remote (or local) changelog:

1. **Extract latest version** - First `## [X.Y.Z]` line after `## [Unreleased]`
2. **Compare with installed** - From VERSION file
3. **Extract entries between** - All version sections from latest down to (but not including) installed

**If no version sections found** (only `[Unreleased]`):
```
## GSD What's New

**Installed:** (your version)
**Latest:** No releases yet

This project hasn't published any releases yet. You're running a development version.

Check https://github.com/puremachinery/gsd/releases for updates.
```

**Version comparison:**
- If no releases yet: Show "no releases" message above
- If installed == latest: "You're on the latest version"
- If installed < latest: Show changes since installed version
- If installed > latest: "You're ahead of latest release (development version?)"
</step>

<step name="display_output">
Format output clearly:

**If up to date:**
```
## GSD What's New

**Installed:** X.Y.Z
**Latest:** X.Y.Z

You're on the latest version.

[View full changelog](https://github.com/puremachinery/gsd/blob/master/CHANGELOG.md)
```

**If updates available:**
```
## GSD What's New

**Installed:** X.Y.Z
**Latest:** X.Y.Z+1

---

### Changes since your version:

[Changelog entries extracted from CHANGELOG.md]

---

[View full changelog](https://github.com/puremachinery/gsd/blob/master/CHANGELOG.md)

**To update:** `gsd update` or download from https://github.com/puremachinery/gsd/releases
```

**Breaking changes:** Surface prominently with **BREAKING:** prefix in the output.
</step>

</process>

<success_criteria>
- [ ] Installed version read from VERSION file
- [ ] Remote changelog fetched (or graceful fallback to local)
- [ ] Version comparison displayed clearly
- [ ] Changes since installed version shown (if any)
- [ ] Update instructions provided when behind
</success_criteria>
