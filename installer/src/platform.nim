## Platform abstraction for GSD
## Handles differences between Claude Code and Codex CLI

import std/[os, strutils, json]

type
  Platform* = enum
    pClaudeCode = "claude"
    pCodexCli = "codex"

  PlatformChoice* = enum
    pcClaude = "claude"
    pcCodex = "codex"
    pcBoth = "both"

const
  # Duplicated from config.nim to avoid circular dependency
  GsdConfigFileName = "gsd-config.json"

const
  GsdOwnDirName* = ".gsd"
  ClaudeConfigDirName* = ".claude"
  CodexConfigDirName* = ".codex"

  ClaudeSettingsFile* = "settings.json"
  CodexConfigFile* = "config.toml"

  ClaudeCommandsDir* = "commands"
  CodexPromptsDir* = "prompts"

  ClaudeAgentsDir* = "agents"
  CodexAgentsMdFile* = "AGENTS.md"

proc getConfigDirName*(p: Platform): string =
  ## Get the config directory name for a platform
  case p
  of pClaudeCode: ClaudeConfigDirName
  of pCodexCli: CodexConfigDirName

proc getSettingsFileName*(p: Platform): string =
  ## Get the settings file name for a platform
  case p
  of pClaudeCode: ClaudeSettingsFile
  of pCodexCli: CodexConfigFile

proc getCommandsDirName*(p: Platform): string =
  ## Get the commands/prompts directory name for a platform
  case p
  of pClaudeCode: ClaudeCommandsDir
  of pCodexCli: CodexPromptsDir

proc getLocalConfigDir*(p: Platform): string =
  ## Returns ./.<platform-config-dir> for a platform
  result = getCurrentDir() / p.getConfigDirName()

proc getGlobalConfigDir*(p: Platform): string =
  ## Returns ~/.<platform-config-dir> for a platform
  result = getHomeDir() / p.getConfigDirName()

proc getLocalGsdDir*(): string =
  ## Returns ./.gsd
  result = getCurrentDir() / GsdOwnDirName

proc getGlobalGsdDir*(): string =
  ## Returns ~/.gsd
  result = getHomeDir() / GsdOwnDirName

proc resolvedPath*(path: string): string =
  ## Resolve symlinks in path for reliable comparison
  ## On macOS, /var is a symlink to /private/var which can cause mismatches
  try:
    return expandFilename(path)
  except OSError:
    return path

proc getPathPrefix*(p: Platform): string =
  ## Get the path prefix for file references (e.g., ~/.claude or ~/.codex)
  result = "~/" & p.getConfigDirName()

proc detectPlatform*(): Platform =
  ## Detect installed platform based on which config directory exists
  ## Prefers Claude Code if both exist, falls back to Codex

  # Check for Claude Code first (preferred)
  let claudeGlobal = getHomeDir() / ClaudeConfigDirName
  let claudeLocal = getCurrentDir() / ClaudeConfigDirName

  if dirExists(claudeLocal) or dirExists(claudeGlobal):
    return pClaudeCode

  # Check for Codex CLI
  let codexGlobal = getHomeDir() / CodexConfigDirName
  let codexLocal = getCurrentDir() / CodexConfigDirName

  if dirExists(codexLocal) or dirExists(codexGlobal):
    return pCodexCli

  # Default to Claude Code if nothing exists
  return pClaudeCode

proc parsePlatform*(s: string): Platform =
  ## Parse platform from string (for CLI flags)
  ## Accepts: "claude", "claude-code", "codex", "codex-cli"
  case s.toLowerAscii()
  of "claude", "claude-code", "claudecode":
    return pClaudeCode
  of "codex", "codex-cli", "codexcli":
    return pCodexCli
  else:
    raise newException(ValueError, "Unknown platform: " & s & ". Use 'claude' or 'codex'.")

proc parsePlatformChoice*(s: string): PlatformChoice =
  ## Parse platform choice from string (for CLI flags)
  ## Accepts: "claude", "codex", "both"
  case s.toLowerAscii()
  of "claude", "claude-code", "claudecode":
    return pcClaude
  of "codex", "codex-cli", "codexcli":
    return pcCodex
  of "both", "all":
    return pcBoth
  else:
    raise newException(ValueError, "Unknown platform: " & s & ". Use 'claude', 'codex', or 'both'.")

proc findInstalledPlatforms*(): seq[Platform] =
  ## Find all platforms with GSD installed
  ## v0.3+: reads platforms array from .gsd/gsd-config.json
  ## v0.2 fallback: checks each tool dir for gsd-config.json
  result = @[]

  # v0.3: Check .gsd/gsd-config.json (local then global)
  for gsdDir in [getLocalGsdDir(), getGlobalGsdDir()]:
    let configPath = gsdDir / GsdConfigFileName
    if fileExists(configPath):
      try:
        let content = readFile(configPath)
        let jsonNode = parseJson(content)
        if jsonNode.hasKey("platforms") and jsonNode["platforms"].kind == JArray:
          for item in jsonNode["platforms"]:
            let platStr = item.getStr("")
            try:
              result.add(parsePlatform(platStr))
            except ValueError:
              discard
          if result.len > 0:
            return
      except CatchableError:
        discard

  # v0.2 fallback: Check each tool dir
  let claudeGlobal = getHomeDir() / ClaudeConfigDirName
  let claudeLocal = getCurrentDir() / ClaudeConfigDirName

  if fileExists(claudeGlobal / GsdConfigFileName) or fileExists(claudeLocal / GsdConfigFileName):
    result.add(pClaudeCode)

  let codexGlobal = getHomeDir() / CodexConfigDirName
  let codexLocal = getCurrentDir() / CodexConfigDirName

  if fileExists(codexGlobal / GsdConfigFileName) or fileExists(codexLocal / GsdConfigFileName):
    result.add(pCodexCli)

proc platformChoiceToSeq*(choice: PlatformChoice): seq[Platform] =
  ## Convert a PlatformChoice to a sequence of Platform values
  case choice
  of pcClaude:
    return @[pClaudeCode]
  of pcCodex:
    return @[pCodexCli]
  of pcBoth:
    return @[pClaudeCode, pCodexCli]
