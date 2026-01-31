## Tests for platform.nim

import std/[unittest, os]
import ../src/platform

suite "Platform enum":
  test "platform enum values are correct":
    check $pClaudeCode == "claude"
    check $pCodexCli == "codex"

suite "getConfigDirName":
  test "Claude Code returns .claude":
    check pClaudeCode.getConfigDirName() == ".claude"

  test "Codex CLI returns .codex":
    check pCodexCli.getConfigDirName() == ".codex"

suite "getSettingsFileName":
  test "Claude Code returns settings.json":
    check pClaudeCode.getSettingsFileName() == "settings.json"

  test "Codex CLI returns config.toml":
    check pCodexCli.getSettingsFileName() == "config.toml"

suite "getCommandsDirName":
  test "Claude Code returns commands":
    check pClaudeCode.getCommandsDirName() == "commands"

  test "Codex CLI returns prompts":
    check pCodexCli.getCommandsDirName() == "prompts"

suite "getPathPrefix":
  test "Claude Code returns ~/.claude":
    check pClaudeCode.getPathPrefix() == "~/.claude"

  test "Codex CLI returns ~/.codex":
    check pCodexCli.getPathPrefix() == "~/.codex"

suite "getLocalConfigDir":
  test "Claude Code returns .claude in current directory":
    let result = pClaudeCode.getLocalConfigDir()
    check result == getCurrentDir() / ".claude"

  test "Codex CLI returns .codex in current directory":
    let result = pCodexCli.getLocalConfigDir()
    check result == getCurrentDir() / ".codex"

suite "getGlobalConfigDir":
  test "Claude Code returns .claude in home directory":
    let result = pClaudeCode.getGlobalConfigDir()
    check result == getHomeDir() / ".claude"

  test "Codex CLI returns .codex in home directory":
    let result = pCodexCli.getGlobalConfigDir()
    check result == getHomeDir() / ".codex"

suite "GSD own directory":
  test "GsdOwnDirName is .gsd":
    check GsdOwnDirName == ".gsd"

  test "getLocalGsdDir returns .gsd in current directory":
    let result = getLocalGsdDir()
    check result == getCurrentDir() / ".gsd"

  test "getGlobalGsdDir returns .gsd in home directory":
    let result = getGlobalGsdDir()
    check result == getHomeDir() / ".gsd"

suite "parsePlatform":
  test "parses 'claude' correctly":
    check parsePlatform("claude") == pClaudeCode

  test "parses 'claude-code' correctly":
    check parsePlatform("claude-code") == pClaudeCode

  test "parses 'claudecode' correctly":
    check parsePlatform("claudecode") == pClaudeCode

  test "parses 'codex' correctly":
    check parsePlatform("codex") == pCodexCli

  test "parses 'codex-cli' correctly":
    check parsePlatform("codex-cli") == pCodexCli

  test "parses 'codexcli' correctly":
    check parsePlatform("codexcli") == pCodexCli

  test "case insensitive parsing":
    check parsePlatform("CLAUDE") == pClaudeCode
    check parsePlatform("CODEX") == pCodexCli
    check parsePlatform("Claude-Code") == pClaudeCode

  test "raises ValueError for unknown platform":
    expect ValueError:
      discard parsePlatform("unknown")

    expect ValueError:
      discard parsePlatform("")

    expect ValueError:
      discard parsePlatform("vscode")

suite "detectPlatform":
  # Note: detectPlatform behavior depends on filesystem state
  # These tests verify it returns a valid platform
  test "returns valid platform":
    let p = detectPlatform()
    check p in {pClaudeCode, pCodexCli}

suite "PlatformChoice enum":
  test "platform choice enum values are correct":
    check $pcClaude == "claude"
    check $pcCodex == "codex"
    check $pcBoth == "both"

suite "parsePlatformChoice":
  test "parses 'claude' correctly":
    check parsePlatformChoice("claude") == pcClaude

  test "parses 'codex' correctly":
    check parsePlatformChoice("codex") == pcCodex

  test "parses 'both' correctly":
    check parsePlatformChoice("both") == pcBoth

  test "parses 'all' as both":
    check parsePlatformChoice("all") == pcBoth

  test "case insensitive parsing":
    check parsePlatformChoice("CLAUDE") == pcClaude
    check parsePlatformChoice("CODEX") == pcCodex
    check parsePlatformChoice("BOTH") == pcBoth

  test "raises ValueError for unknown platform choice":
    expect ValueError:
      discard parsePlatformChoice("unknown")

suite "platformChoiceToSeq":
  test "claude returns single platform":
    let result = platformChoiceToSeq(pcClaude)
    check result.len == 1
    check result[0] == pClaudeCode

  test "codex returns single platform":
    let result = platformChoiceToSeq(pcCodex)
    check result.len == 1
    check result[0] == pCodexCli

  test "both returns both platforms":
    let result = platformChoiceToSeq(pcBoth)
    check result.len == 2
    check pClaudeCode in result
    check pCodexCli in result

suite "findInstalledPlatforms":
  # Note: findInstalledPlatforms behavior depends on filesystem state
  # These tests verify it returns a valid sequence
  test "returns valid sequence":
    let platforms = findInstalledPlatforms()
    for p in platforms:
      check p in {pClaudeCode, pCodexCli}
