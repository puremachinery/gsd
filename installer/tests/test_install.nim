## Tests for install.nim

import std/[unittest, json, options, strutils, os, envvars]
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
    let content = "@~/.gsd/workflows/execute.md"
    let result = rewritePathReferences(content, "global", "")

    check result == "@~/.gsd/workflows/execute.md"

  test "local install converts to relative paths":
    let content = "@~/.gsd/workflows/execute.md"
    let result = rewritePathReferences(content, "local", "")

    check result == "@.gsd/workflows/execute.md"

  test "local install converts non-@ references too":
    let content = "See ~/.gsd/templates/ for more info"
    let result = rewritePathReferences(content, "local", "")

    check result == "See .gsd/templates/ for more info"

  test "custom install uses custom path":
    let content = "@~/.gsd/workflows/execute.md"
    let result = rewritePathReferences(content, "custom", "/opt/myconfig")

    check result == "@/opt/myconfig/workflows/execute.md"

  test "custom install handles non-@ references":
    let content = "Located at ~/.gsd/references/"
    let result = rewritePathReferences(content, "custom", "/home/user/custom")

    check result == "Located at /home/user/custom/references/"

  test "handles multiple references in one file":
    let content = """
@~/.gsd/workflows/execute.md
@~/.gsd/templates/plan.md
See ~/.gsd/ for resources
"""
    let result = rewritePathReferences(content, "local", "")

    check result.contains("@.gsd/workflows/execute.md")
    check result.contains("@.gsd/templates/plan.md")
    check result.contains("See .gsd/ for resources")

  test "does not affect other paths":
    let content = "@/usr/local/bin/something ~/other/path"
    let result = rewritePathReferences(content, "local", "")

    check result.contains("@/usr/local/bin/something")
    check result.contains("~/other/path")  # Only ~/.gsd/ is rewritten

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
Path: @~/.gsd/ref.md
""")
    writeFile(agent2Path, """# Agent 2
This agent does task 2.
""")

    let destPath = tempDir / "AGENTS.md"
    let success = generateAgentsMd(@[agent1Path, agent2Path], destPath, "global", "")

    check success == true
    check fileExists(destPath)

    let content = readFile(destPath)
    check content.contains("# GSD Agents")
    check content.contains("auto-generated")
    check content.contains("## gsd-agent1")
    check content.contains("## gsd-agent2")
    check content.contains("This agent does task 1")
    check content.contains("This agent does task 2")
    # Global install - paths stay as @~/.gsd/
    check content.contains("@~/.gsd/ref.md")

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
    discard generateAgentsMd(@[agentZ, agentA], destPath, "global", "")

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
    let success = generateAgentsMd(@[], destPath, "global", "")

    check success == true
    check fileExists(destPath)

    let content = readFile(destPath)
    check content.contains("# GSD Agents")

suite "Codex install integration":
  test "full Codex install creates expected structure":
    let originalDir = getCurrentDir()
    let tempWork = getTempDir() / "gsd_test_codex_install"
    let tempHome = getTempDir() / "gsd_test_codex_install_home"
    let sourceDir = getTempDir() / "gsd_test_codex_source"

    createDir(tempWork)
    createDir(tempHome)

    # Create source structure
    createDir(sourceDir / "gsd" / "templates")
    createDir(sourceDir / "gsd" / "workflows")
    createDir(sourceDir / "commands" / "gsd")
    createDir(sourceDir / "agents")

    writeFile(sourceDir / "gsd" / "templates" / "plan.md", "# Plan template\nPath: @~/.gsd/")
    writeFile(sourceDir / "gsd" / "workflows" / "exec.md", "# Workflow")
    writeFile(sourceDir / "commands" / "gsd" / "help.md", "# Help command\nSee ~/.gsd/")
    writeFile(sourceDir / "commands" / "gsd" / "new-project.md", "# New project")
    writeFile(sourceDir / "agents" / "gsd-planner.md", "# Planner agent")
    writeFile(sourceDir / "agents" / "gsd-executor.md", "# Executor agent")

    let oldHome = getEnv("HOME")
    putEnv("HOME", tempHome)
    setCurrentDir(tempWork)
    # Use getCurrentDir() to get resolved path (handles /var → /private/var symlinks)
    let resolvedWork = getCurrentDir()
    defer:
      setCurrentDir(originalDir)
      if oldHome.len > 0: putEnv("HOME", oldHome) else: delEnv("HOME")
      removeDir(tempWork)
      removeDir(tempHome)
      removeDir(sourceDir)

    let opts = InstallOptions(
      configDir: "",
      installType: itLocal,
      platform: pCodexCli,
      forceStatusline: false,
      verbose: false
    )

    let result = install(sourceDir, opts)
    let gsdDir = resolvedWork / ".gsd"
    let toolDir = resolvedWork / ".codex"

    check result.success == true
    check result.configDir == gsdDir

    # Check shared resources in .gsd/
    check dirExists(gsdDir)
    check dirExists(gsdDir / "templates")
    check fileExists(gsdDir / "templates" / "plan.md")

    # Check path rewriting in shared resources (local → relative .gsd/)
    let planContent = readFile(gsdDir / "templates" / "plan.md")
    check planContent.contains("@.gsd/")
    check not planContent.contains("@~/.gsd/")

    # Check prompts/ directory in tool dir (Codex-specific)
    check dirExists(toolDir / "prompts")
    check fileExists(toolDir / "prompts" / "gsd-help.md")
    check fileExists(toolDir / "prompts" / "gsd-new-project.md")

    # Check prompt content has rewritten paths
    let helpContent = readFile(toolDir / "prompts" / "gsd-help.md")
    check helpContent.contains(".gsd/")

    # Check AGENTS.md in tool dir (Codex-specific)
    check fileExists(toolDir / "AGENTS.md")
    let agentsContent = readFile(toolDir / "AGENTS.md")
    check agentsContent.contains("gsd-planner")
    check agentsContent.contains("gsd-executor")

    # Check config.toml in tool dir
    check fileExists(toolDir / "config.toml")
    let tomlContent = readFile(toolDir / "config.toml")
    check tomlContent.contains("[[notify]]")
    check tomlContent.contains("#gsd")

    # Check gsd-config.json in .gsd/
    check fileExists(gsdDir / "gsd-config.json")
    let cfg = loadConfig(gsdDir)
    check cfg.isSome
    check pCodexCli in cfg.get().platforms

    # Check VERSION file in .gsd/
    check fileExists(gsdDir / "VERSION")

    # Check cache directory in .gsd/
    check dirExists(gsdDir / "cache")

  test "Codex uninstall removes tool files and updates .gsd/ config":
    let originalDir = getCurrentDir()
    let tempWork = getTempDir() / "gsd_test_codex_uninstall"
    let tempHome = getTempDir() / "gsd_test_codex_uninstall_home"
    createDir(tempWork)
    createDir(tempHome)

    let oldHome = getEnv("HOME")
    putEnv("HOME", tempHome)
    setCurrentDir(tempWork)
    let resolvedWork = getCurrentDir()
    defer:
      setCurrentDir(originalDir)
      if oldHome.len > 0: putEnv("HOME", oldHome) else: delEnv("HOME")
      removeDir(tempWork)
      removeDir(tempHome)

    let gsdDir = resolvedWork / ".gsd"
    let toolDir = resolvedWork / ".codex"

    # Set up .gsd/ (shared)
    createDir(gsdDir)
    createDir(gsdDir / "templates")
    createDir(gsdDir / "cache")
    writeFile(gsdDir / "VERSION", "0.2.0")
    writeFile(gsdDir / ConfigFileName, """{"platforms":["codex"],"gsd_dir":"""" & gsdDir & """","version":"0.2.0"}""")

    # Set up .codex/ (tool-specific)
    createDir(toolDir)
    createDir(toolDir / "prompts")
    writeFile(toolDir / "AGENTS.md", "# GSD Agents")
    writeFile(toolDir / "prompts" / "gsd-help.md", "# GSD Help")
    writeFile(toolDir / "prompts" / "gsd-new-project.md", "# GSD New Project")

    # User files that should be preserved
    writeFile(toolDir / "prompts" / "my-custom-prompt.md", "# My Custom Prompt")
    writeFile(toolDir / "config.toml", """
# User config
model = "gpt-4"

[[notify]]
event = "session_start"
command = "gsd check-update #gsd"

[[notify]]
event = "other"
command = "my-custom-hook"
""")

    let success = uninstall(gsdDir, false, pCodexCli)

    check success == true

    # Tool-specific files should be removed
    check not fileExists(toolDir / "AGENTS.md")
    check not fileExists(toolDir / "prompts" / "gsd-help.md")
    check not fileExists(toolDir / "prompts" / "gsd-new-project.md")

    # User files should be preserved
    check fileExists(toolDir / "prompts" / "my-custom-prompt.md")
    check fileExists(toolDir / "config.toml")

    # config.toml should have GSD hooks removed but user content preserved
    let tomlContent = readFile(toolDir / "config.toml")
    check tomlContent.contains("model = \"gpt-4\"")
    check tomlContent.contains("my-custom-hook")
    check not tomlContent.contains("#gsd")

    # .gsd/ should be removed (only platform was codex, now empty)
    check not dirExists(gsdDir)

  test "Codex install then uninstall is clean":
    let originalDir = getCurrentDir()
    let tempWork = getTempDir() / "gsd_test_codex_roundtrip"
    let tempHome = getTempDir() / "gsd_test_codex_roundtrip_home"
    let sourceDir = getTempDir() / "gsd_test_codex_roundtrip_src"

    createDir(tempWork)
    createDir(tempHome)
    createDir(sourceDir / "gsd")
    createDir(sourceDir / "commands" / "gsd")
    createDir(sourceDir / "agents")

    writeFile(sourceDir / "gsd" / "test.md", "# Test")
    writeFile(sourceDir / "commands" / "gsd" / "help.md", "# Help")
    writeFile(sourceDir / "agents" / "gsd-planner.md", "# Planner")

    let oldHome = getEnv("HOME")
    putEnv("HOME", tempHome)
    setCurrentDir(tempWork)
    let resolvedWork = getCurrentDir()
    defer:
      setCurrentDir(originalDir)
      if oldHome.len > 0: putEnv("HOME", oldHome) else: delEnv("HOME")
      removeDir(tempWork)
      removeDir(tempHome)
      removeDir(sourceDir)

    let gsdDir = resolvedWork / ".gsd"
    let toolDir = resolvedWork / ".codex"

    # Install
    let opts = InstallOptions(
      configDir: "",
      installType: itLocal,
      platform: pCodexCli,
      forceStatusline: false,
      verbose: false
    )
    let installResult = install(sourceDir, opts)
    check installResult.success == true

    # Uninstall
    let uninstallResult = uninstall(gsdDir, false, pCodexCli)
    check uninstallResult == true

    # .gsd/ should be removed entirely (only platform was codex)
    check not dirExists(gsdDir)

    # Tool dir should have no GSD files
    check not fileExists(toolDir / "AGENTS.md")
    if dirExists(toolDir / "prompts"):
      for kind, path in walkDir(toolDir / "prompts"):
        check not extractFilename(path).startsWith("gsd-")
