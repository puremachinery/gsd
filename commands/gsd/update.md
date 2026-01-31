---
name: gsd:update
description: Update GSD to latest version with changelog display
---

<objective>
Check for GSD updates, show what changed, and guide the update.
</objective>

<process>

<step name="list_installed_versions">
(Optional) list installed versions across local/global installs:

```bash
for root in ".claude" ".codex" "$HOME/.claude" "$HOME/.codex"; do
  if [ -f "$root/gsd/VERSION" ]; then
    echo "$root -> $(cat "$root/gsd/VERSION")"
  fi
done
```

If no VERSION files are found, continue with update instructions anyway.
</step>

<step name="check_latest_version">
Check GitHub API for latest release (if your tool supports web browsing/fetch):

- URL: `https://api.github.com/repos/puremachinery/gsd/releases/latest`
- Extract the `tag_name` field (version number). If the response is a 404 or "Not Found", treat as "no-releases".

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

Proceed to update instructions.
</step>

<step name="show_changes_and_confirm">
**If update available**, fetch and show what's new BEFORE updating:

1. Fetch changelog from GitHub
2. Extract entries between installed and latest versions
3. Display preview and ask for confirmation:

```
## GSD Update Available

**Latest:** X.Y.Z

### What's New
────────────────────────────────────────────────────────────

[Changelog entries extracted from CHANGELOG.md]

────────────────────────────────────────────────────────────
```

Ask the user:
- "Proceed with update?"
- Options: "Yes, update now" / "No, cancel"

**If user cancels:** STOP here.
</step>

<step name="run_update">
Preferred update path (works for Claude Code and Codex CLI):

```
# Updates all detected installs (local + global)
gsd update

# Or target a specific platform
# gsd update --platform=claude
# gsd update --platform=codex
```

If `gsd update` fails with "Cannot find GSD source files" or `gsd` is not on PATH:

1. Download the latest release bundle for your platform:
   https://github.com/puremachinery/gsd/releases/latest
2. Run the updater from the extracted bundle directory:
   ```bash
   ./gsd update
   ```

If you prefer a manual reinstall, use:
```
./gsd install --platform=claude --global   # or --local
./gsd install --platform=codex  --global   # or --local
```
</step>

<step name="display_result">
Format completion message:

```
╔═══════════════════════════════════════════════════════════╗
║  GSD Updated                                               ║
╚═══════════════════════════════════════════════════════════╝

Restart your tool (Claude Code or Codex CLI) to pick up the new commands.

View full changelog: https://github.com/puremachinery/gsd/blob/master/CHANGELOG.md
```
</step>

</process>

<success_criteria>
- [ ] Latest version checked (or manual check instructed)
- [ ] Changelog preview shown when available
- [ ] User confirmation obtained before update
- [ ] Update executed successfully (or manual instructions provided)
- [ ] Restart reminder shown
</success_criteria>
