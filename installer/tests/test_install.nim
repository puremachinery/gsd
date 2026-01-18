## Tests for install.nim

import std/[unittest, json, options, strutils]
import ../src/install

suite "isOldGsdStatusline":
  test "detects node statusline.js pattern":
    check isOldGsdStatusline("node ~/.claude/hooks/statusline.js") == true

  test "detects quoted home path pattern":
    check isOldGsdStatusline("node \"$HOME/.claude/hooks/statusline.js\"") == true

  test "detects relative path pattern":
    check isOldGsdStatusline("node .claude/hooks/statusline.js") == true

  test "detects $HOME pattern":
    check isOldGsdStatusline("node $HOME/.claude/hooks/statusline.js") == true

  test "rejects new gsd statusline":
    check isOldGsdStatusline("gsd statusline #gsd") == false

  test "rejects custom statusline":
    check isOldGsdStatusline("my-custom-statusline") == false

  test "rejects empty string":
    check isOldGsdStatusline("") == false

  test "detects pattern within longer command":
    check isOldGsdStatusline("env VAR=1 node ~/.claude/hooks/statusline.js") == true

suite "mergeHooks":
  # Tests use Claude Code's object format: { EventName: [{ matcher, hooks: [{ type, command }] }] }
  test "adds GSD hooks to empty settings":
    let existing = %*{}
    let gsdHooks = %*{
      "SessionStart": [{
        "matcher": "",
        "hooks": [{"type": "command", "command": "gsd check-update #gsd"}]
      }]
    }

    let result = mergeHooks(existing, gsdHooks)

    check result.kind == JObject
    check result.hasKey("SessionStart")
    check result["SessionStart"].len == 1

  test "preserves non-GSD hooks":
    let existing = %*{
      "hooks": {
        "SessionStart": [{
          "matcher": "",
          "hooks": [{"type": "command", "command": "custom-hook"}]
        }]
      }
    }
    let gsdHooks = %*{
      "SessionStart": [{
        "matcher": "",
        "hooks": [{"type": "command", "command": "gsd check-update #gsd"}]
      }]
    }

    let result = mergeHooks(existing, gsdHooks)

    check result["SessionStart"].len == 2

  test "replaces existing GSD hooks":
    let existing = %*{
      "hooks": {
        "SessionStart": [{
          "matcher": "",
          "hooks": [{"type": "command", "command": "gsd old-command #gsd"}]
        }]
      }
    }
    let gsdHooks = %*{
      "SessionStart": [{
        "matcher": "",
        "hooks": [{"type": "command", "command": "gsd new-command #gsd"}]
      }]
    }

    let result = mergeHooks(existing, gsdHooks)

    # Old GSD hook filtered, new one added
    check result["SessionStart"].len == 1

  test "removes old node statusline hooks":
    let existing = %*{
      "hooks": {
        "SessionStart": [{
          "matcher": "",
          "hooks": [{"type": "command", "command": "node ~/.claude/hooks/statusline.js"}]
        }]
      }
    }
    let gsdHooks = %*{
      "SessionStart": [{
        "matcher": "",
        "hooks": [{"type": "command", "command": "gsd check-update #gsd"}]
      }]
    }

    let result = mergeHooks(existing, gsdHooks)

    check result["SessionStart"].len == 1

  test "preserves legacy array-style hooks":
    # Legacy format: hooks as flat array with event field
    let existing = %*{
      "hooks": [
        {"event": "SessionStart", "command": "my-custom-hook", "matcher": ""},
        {"event": "SessionEnd", "command": "my-cleanup-hook"}
      ]
    }
    let gsdHooks = %*{
      "SessionStart": [{
        "matcher": "",
        "hooks": [{"type": "command", "command": "gsd check-update #gsd"}]
      }]
    }

    let result = mergeHooks(existing, gsdHooks)

    # Should have SessionStart with both custom and GSD hooks
    check result.hasKey("SessionStart")
    check result["SessionStart"].len == 2

    # Should have SessionEnd with custom hook preserved
    check result.hasKey("SessionEnd")
    check result["SessionEnd"].len == 1

  test "filters GSD hooks from legacy array format":
    let existing = %*{
      "hooks": [
        {"event": "SessionStart", "command": "gsd old-command #gsd"},
        {"event": "SessionStart", "command": "my-custom-hook"}
      ]
    }
    let gsdHooks = %*{
      "SessionStart": [{
        "matcher": "",
        "hooks": [{"type": "command", "command": "gsd check-update #gsd"}]
      }]
    }

    let result = mergeHooks(existing, gsdHooks)

    # Should only have 2 hooks: custom hook (converted) + new GSD hook
    check result["SessionStart"].len == 2

  test "preserves non-GSD hooks bundled in same entry":
    # Single entry with both GSD and custom hooks in inner array
    let existing = %*{
      "hooks": {
        "SessionStart": [{
          "matcher": "",
          "hooks": [
            {"type": "command", "command": "gsd old-command #gsd"},
            {"type": "command", "command": "my-custom-hook"},
            {"type": "command", "command": "another-custom-hook"}
          ]
        }]
      }
    }
    let gsdHooks = %*{
      "SessionStart": [{
        "matcher": "",
        "hooks": [{"type": "command", "command": "gsd check-update #gsd"}]
      }]
    }

    let result = mergeHooks(existing, gsdHooks)

    # Should have 2 entries: preserved entry with custom hooks + new GSD entry
    check result["SessionStart"].len == 2

    # The preserved entry should have 2 custom hooks (GSD hook filtered out)
    var foundCustomEntry = false
    for entry in result["SessionStart"]:
      if entry["hooks"].len == 2:
        foundCustomEntry = true
        # Verify both are custom hooks
        for h in entry["hooks"]:
          check not h["command"].getStr().contains("#gsd")
    check foundCustomEntry

suite "mergeStatusline":
  # Tests use Claude Code's object format: { type: "command", command: "..." }
  let gsdStatusline = %*{"type": "command", "command": "gsd statusline #gsd"}

  test "sets statusline when none exists":
    let existing = %*{}
    let (config, changed) = mergeStatusline(existing, gsdStatusline, false)

    check config["command"].getStr() == "gsd statusline #gsd"
    check changed == true

  test "sets statusline when empty":
    let existing = %*{"statusLine": {"type": "command", "command": ""}}
    let (config, changed) = mergeStatusline(existing, gsdStatusline, false)

    check config["command"].getStr() == "gsd statusline #gsd"
    check changed == true

  test "keeps custom statusline without force":
    let existing = %*{"statusLine": {"type": "command", "command": "my-custom-statusline"}}
    let (config, changed) = mergeStatusline(existing, gsdStatusline, false)

    check config["command"].getStr() == "my-custom-statusline"
    check changed == false

  test "replaces custom statusline with force":
    let existing = %*{"statusLine": {"type": "command", "command": "my-custom-statusline"}}
    let (config, changed) = mergeStatusline(existing, gsdStatusline, true)

    check config["command"].getStr() == "gsd statusline #gsd"
    check changed == true

  test "auto-migrates old node statusline":
    let existing = %*{"statusLine": {"type": "command", "command": "node ~/.claude/hooks/statusline.js"}}
    let (config, changed) = mergeStatusline(existing, gsdStatusline, false)

    check config["command"].getStr() == "gsd statusline #gsd"
    check changed == true

  test "handles legacy string format":
    let existing = %*{"statusline": "node ~/.claude/hooks/statusline.js"}
    let (config, changed) = mergeStatusline(existing, gsdStatusline, false)

    check config["command"].getStr() == "gsd statusline #gsd"
    check changed == true
