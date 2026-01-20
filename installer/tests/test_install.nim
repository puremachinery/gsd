## Tests for install.nim

import std/[unittest, json, options, strutils, os]
import ../src/install
import ../src/platform
import ../src/config

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

suite "rewritePathReferences":
  test "global install keeps paths unchanged":
    let content = "@~/.claude/gsd/workflows/execute.md"
    let result = rewritePathReferences(content, "global", "")

    check result == "@~/.claude/gsd/workflows/execute.md"

  test "local install converts to relative paths":
    let content = "@~/.claude/gsd/workflows/execute.md"
    let result = rewritePathReferences(content, "local", "")

    check result == "@.claude/gsd/workflows/execute.md"

  test "local install converts non-@ references too":
    let content = "See ~/.claude/gsd/templates/ for more info"
    let result = rewritePathReferences(content, "local", "")

    check result == "See .claude/gsd/templates/ for more info"

  test "custom install uses custom path":
    let content = "@~/.claude/gsd/workflows/execute.md"
    let result = rewritePathReferences(content, "custom", "/opt/myconfig")

    check result == "@/opt/myconfig/gsd/workflows/execute.md"

  test "custom install handles non-@ references":
    let content = "Located at ~/.claude/gsd/references/"
    let result = rewritePathReferences(content, "custom", "/home/user/custom")

    check result == "Located at /home/user/custom/gsd/references/"

  test "handles multiple references in one file":
    let content = """
@~/.claude/gsd/workflows/execute.md
@~/.claude/gsd/templates/plan.md
See ~/.claude/ for config
"""
    let result = rewritePathReferences(content, "local", "")

    check result.contains("@.claude/gsd/workflows/execute.md")
    check result.contains("@.claude/gsd/templates/plan.md")
    check result.contains("See .claude/ for config")

  test "does not affect other paths":
    let content = "@/usr/local/bin/something ~/other/path"
    let result = rewritePathReferences(content, "local", "")

    check result.contains("@/usr/local/bin/something")
    check result.contains("~/other/path")  # Only ~/.claude/ is rewritten

suite "rewritePathReferences with Codex platform":
  test "global Codex install uses ~/.codex paths":
    let content = "@~/.claude/gsd/workflows/execute.md"
    let result = rewritePathReferences(content, "global", "", pCodexCli)

    check result == "@~/.codex/gsd/workflows/execute.md"

  test "local Codex install uses .codex paths":
    let content = "@~/.claude/gsd/workflows/execute.md"
    let result = rewritePathReferences(content, "local", "", pCodexCli)

    check result == "@.codex/gsd/workflows/execute.md"

  test "Codex rewrites non-@ references":
    let content = "See ~/.claude/gsd/templates/ for more info"
    let result = rewritePathReferences(content, "global", "", pCodexCli)

    check result == "See ~/.codex/gsd/templates/ for more info"

  test "custom Codex install uses custom path":
    let content = "@~/.claude/gsd/workflows/execute.md"
    let result = rewritePathReferences(content, "custom", "/opt/codex", pCodexCli)

    check result == "@/opt/codex/gsd/workflows/execute.md"

suite "generateAgentsMd":
  test "generates AGENTS.md from agent files":
    let tempDir = getTempDir() / "gsd_test_agents"
    createDir(tempDir)
    defer: removeDir(tempDir)

    # Create test agent files
    let agent1Path = tempDir / "gsd-agent1.md"
    let agent2Path = tempDir / "gsd-agent2.md"

    writeFile(agent1Path, """# Agent 1
This agent does task 1.
Path: @~/.claude/gsd/ref.md
""")
    writeFile(agent2Path, """# Agent 2
This agent does task 2.
""")

    let destPath = tempDir / "AGENTS.md"
    let success = generateAgentsMd(@[agent1Path, agent2Path], destPath, "global", "", pCodexCli)

    check success == true
    check fileExists(destPath)

    let content = readFile(destPath)
    check content.contains("# GSD Agents")
    check content.contains("auto-generated")
    check content.contains("## gsd-agent1")
    check content.contains("## gsd-agent2")
    check content.contains("This agent does task 1")
    check content.contains("This agent does task 2")
    # Check path rewriting for Codex
    check content.contains("@~/.codex/gsd/ref.md")
    check not content.contains("@~/.claude/")

  test "sorts agent files for consistent order":
    let tempDir = getTempDir() / "gsd_test_agents_sort"
    createDir(tempDir)
    defer: removeDir(tempDir)

    let agentZ = tempDir / "gsd-zebra.md"
    let agentA = tempDir / "gsd-alpha.md"

    writeFile(agentZ, "# Zebra agent")
    writeFile(agentA, "# Alpha agent")

    let destPath = tempDir / "AGENTS.md"
    # Pass in reverse order
    discard generateAgentsMd(@[agentZ, agentA], destPath, "global", "", pCodexCli)

    let content = readFile(destPath)
    let alphaPos = content.find("gsd-alpha")
    let zebraPos = content.find("gsd-zebra")

    # Alpha should come before Zebra due to sorting
    check alphaPos < zebraPos

  test "handles empty agent list":
    let tempDir = getTempDir() / "gsd_test_agents_empty"
    createDir(tempDir)
    defer: removeDir(tempDir)

    let destPath = tempDir / "AGENTS.md"
    let success = generateAgentsMd(@[], destPath, "global", "", pCodexCli)

    check success == true
    check fileExists(destPath)

    let content = readFile(destPath)
    check content.contains("# GSD Agents")

suite "Codex install integration":
  test "full Codex install creates expected structure":
    let tempDir = getTempDir() / "gsd_test_codex_install"
    let sourceDir = getTempDir() / "gsd_test_codex_source"

    # Create source structure
    createDir(sourceDir / "gsd" / "templates")
    createDir(sourceDir / "gsd" / "workflows")
    createDir(sourceDir / "commands" / "gsd")
    createDir(sourceDir / "agents")

    writeFile(sourceDir / "gsd" / "templates" / "plan.md", "# Plan template\nPath: @~/.claude/gsd/")
    writeFile(sourceDir / "gsd" / "workflows" / "exec.md", "# Workflow")
    writeFile(sourceDir / "commands" / "gsd" / "help.md", "# Help command\nSee ~/.claude/gsd/")
    writeFile(sourceDir / "commands" / "gsd" / "new-project.md", "# New project")
    writeFile(sourceDir / "agents" / "gsd-planner.md", "# Planner agent")
    writeFile(sourceDir / "agents" / "gsd-executor.md", "# Executor agent")

    defer:
      removeDir(tempDir)
      removeDir(sourceDir)

    let opts = InstallOptions(
      configDir: tempDir,
      installType: itCustom,
      platform: pCodexCli,
      forceStatusline: false,
      verbose: false
    )

    let result = install(sourceDir, opts)

    check result.success == true
    check result.configDir == tempDir

    # Check gsd/ resources copied
    check dirExists(tempDir / "gsd")
    check dirExists(tempDir / "gsd" / "templates")
    check fileExists(tempDir / "gsd" / "templates" / "plan.md")

    # Check path rewriting in gsd resources
    let planContent = readFile(tempDir / "gsd" / "templates" / "plan.md")
    check planContent.contains("@" & tempDir & "/gsd/")
    check not planContent.contains("@~/.claude/")

    # Check prompts/ directory (Codex-specific)
    check dirExists(tempDir / "prompts")
    check fileExists(tempDir / "prompts" / "gsd-help.md")
    check fileExists(tempDir / "prompts" / "gsd-new-project.md")

    # Check prompt content has rewritten paths
    let helpContent = readFile(tempDir / "prompts" / "gsd-help.md")
    check helpContent.contains(tempDir & "/gsd/")
    check not helpContent.contains("~/.claude/")

    # Check AGENTS.md generated (Codex-specific)
    check fileExists(tempDir / "AGENTS.md")
    let agentsContent = readFile(tempDir / "AGENTS.md")
    check agentsContent.contains("gsd-planner")
    check agentsContent.contains("gsd-executor")

    # Check config.toml created with hooks
    check fileExists(tempDir / "config.toml")
    let tomlContent = readFile(tempDir / "config.toml")
    check tomlContent.contains("[[notify]]")
    check tomlContent.contains("#gsd")

    # Check gsd-config.json
    check fileExists(tempDir / "gsd-config.json")
    let cfg = loadConfig(tempDir)
    check cfg.isSome
    check cfg.get().platform == pCodexCli

    # Check VERSION file
    check fileExists(tempDir / "gsd" / "VERSION")

    # Check cache directory
    check dirExists(tempDir / "cache")

  test "Codex uninstall removes GSD files but preserves user content":
    let tempDir = getTempDir() / "gsd_test_codex_uninstall"
    createDir(tempDir)
    createDir(tempDir / "gsd")
    createDir(tempDir / "prompts")
    createDir(tempDir / "cache")

    # GSD files
    writeFile(tempDir / "gsd-config.json", """{"platform": "codex"}""")
    writeFile(tempDir / "gsd" / "VERSION", "0.2.0")
    writeFile(tempDir / "AGENTS.md", "# GSD Agents")
    writeFile(tempDir / "prompts" / "gsd-help.md", "# GSD Help")
    writeFile(tempDir / "prompts" / "gsd-new-project.md", "# GSD New Project")

    # User files that should be preserved
    writeFile(tempDir / "prompts" / "my-custom-prompt.md", "# My Custom Prompt")
    writeFile(tempDir / "config.toml", """
# User config
model = "gpt-4"

[[notify]]
event = "session_start"
command = "gsd check-update #gsd"

[[notify]]
event = "other"
command = "my-custom-hook"
""")

    defer: removeDir(tempDir)

    let success = uninstall(tempDir, false, pCodexCli)

    check success == true

    # GSD files should be removed
    check not fileExists(tempDir / "gsd-config.json")
    check not dirExists(tempDir / "gsd")
    check not fileExists(tempDir / "AGENTS.md")
    check not fileExists(tempDir / "prompts" / "gsd-help.md")
    check not fileExists(tempDir / "prompts" / "gsd-new-project.md")

    # User files should be preserved
    check fileExists(tempDir / "prompts" / "my-custom-prompt.md")
    check fileExists(tempDir / "config.toml")

    # config.toml should have GSD hooks removed but user content preserved
    let tomlContent = readFile(tempDir / "config.toml")
    check tomlContent.contains("model = \"gpt-4\"")
    check tomlContent.contains("my-custom-hook")
    check not tomlContent.contains("#gsd")

  test "Codex install then uninstall is clean":
    let tempDir = getTempDir() / "gsd_test_codex_roundtrip"
    let sourceDir = getTempDir() / "gsd_test_codex_roundtrip_src"

    createDir(sourceDir / "gsd")
    createDir(sourceDir / "commands" / "gsd")
    createDir(sourceDir / "agents")

    writeFile(sourceDir / "gsd" / "test.md", "# Test")
    writeFile(sourceDir / "commands" / "gsd" / "help.md", "# Help")
    writeFile(sourceDir / "agents" / "gsd-planner.md", "# Planner")

    defer:
      removeDir(tempDir)
      removeDir(sourceDir)

    # Install
    let opts = InstallOptions(
      configDir: tempDir,
      installType: itCustom,
      platform: pCodexCli,
      forceStatusline: false,
      verbose: false
    )
    let installResult = install(sourceDir, opts)
    check installResult.success == true

    # Uninstall
    let uninstallResult = uninstall(tempDir, false, pCodexCli)
    check uninstallResult == true

    # Directory should be mostly empty (only cache might remain)
    check not fileExists(tempDir / "gsd-config.json")
    check not dirExists(tempDir / "gsd")
    check not fileExists(tempDir / "AGENTS.md")

    # prompts dir might remain if empty, but no gsd- files
    if dirExists(tempDir / "prompts"):
      for kind, path in walkDir(tempDir / "prompts"):
        check not extractFilename(path).startsWith("gsd-")
