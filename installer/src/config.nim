## Config resolution for GSD
## Determines install location (local vs global) and reads gsd-config.json

import std/[os, json, options, strutils]
import platform

type
  InstallType* = enum
    itGlobal = "global"
    itLocal = "local"
    itCustom = "custom"

  GsdConfig* = object
    version*: string
    installType*: InstallType
    platform*: Platform
    configDir*: string
    installedAt*: string

  InstalledConfig* = object
    platform*: Platform
    dir*: string

proc loadConfig*(configDir: string): Option[GsdConfig]

const
  Version* = "0.2.0"
  ConfigFileName* = "gsd-config.json"
  GsdDirName* = "gsd"
  CacheDirName* = "cache"
  VersionFileName* = "VERSION"
  ConfigEnvVar* = "GSD_CONFIG_DIR"

proc expandPath*(path: string): string =
  ## Expand home directory references to absolute paths
  ## Handles:
  ##   ~ and ~/path (Unix style)
  ##   %USERPROFILE% (Windows style)

  # Handle ~ expansion (works on both platforms via getHomeDir)
  if path == "~":
    return getHomeDir().normalizedPath
  elif path.startsWith("~/") or path.startsWith("~\\"):
    return (getHomeDir() / path[2..^1]).normalizedPath
  elif path.startsWith("~"):
    # ~username style - not supported, return as-is
    return path

  # Handle Windows %USERPROFILE%
  when defined(windows):
    if path.startsWith("%USERPROFILE%"):
      let home = getHomeDir()
      if path == "%USERPROFILE%":
        return home.normalizedPath
      elif path.len > 13 and path[13] in {'/', '\\'}:
        return (home / path[14..^1]).normalizedPath

  return path

proc getEnvConfigDir(): Option[string] =
  ## Resolve config directory from GSD_CONFIG_DIR env var
  let envDir = getEnv(ConfigEnvVar)
  if envDir.len == 0:
    return none(string)
  let expanded = expandPath(envDir)
  if dirExists(expanded):
    return some(expanded)
  return none(string)

proc inferInstallType*(dir: string, p: Platform): InstallType =
  ## Infer install type from a config directory path
  let expanded = expandPath(dir)
  if expanded == platform.getLocalConfigDir(p):
    return itLocal
  if expanded == platform.getGlobalConfigDir(p):
    return itGlobal
  return itCustom

proc hasGsdPrefixedFiles(dir: string): bool =
  if not dirExists(dir):
    return false
  for kind, path in walkDir(dir):
    if kind == pcFile:
      let filename = extractFilename(path)
      if filename.startsWith("gsd-") and filename.endsWith(".md"):
        return true
  return false

proc inferPlatformFromDir*(configDir: string): Option[Platform] =
  ## Infer platform from config directory contents
  let expanded = expandPath(configDir)
  if expanded.len == 0 or not dirExists(expanded):
    return none(Platform)

  let hasClaudeCommands = dirExists(expanded / "commands" / "gsd")
  let hasClaudeAgents = hasGsdPrefixedFiles(expanded / "agents")
  let hasCodexPrompts = hasGsdPrefixedFiles(expanded / CodexPromptsDir)
  let hasCodexAgents = fileExists(expanded / CodexAgentsMdFile)

  let claudeScore = (if hasClaudeCommands: 2 else: 0) + (if hasClaudeAgents: 1 else: 0)
  let codexScore = (if hasCodexPrompts: 2 else: 0) + (if hasCodexAgents: 1 else: 0)

  if claudeScore > 0 and codexScore == 0:
    return some(pClaudeCode)
  if codexScore > 0 and claudeScore == 0:
    return some(pCodexCli)
  return none(Platform)

proc getLocalConfigDir*(): string =
  ## Returns ./.claude (Claude Code default)
  result = getCurrentDir() / ".claude"

proc getGlobalConfigDir*(): string =
  ## Returns ~/.claude (Claude Code default)
  result = getHomeDir() / ".claude"

proc getLocalConfigDirFor*(p: Platform): string =
  ## Returns ./.<platform-config-dir>
  result = platform.getLocalConfigDir(p)

proc getGlobalConfigDirFor*(p: Platform): string =
  ## Returns ~/.<platform-config-dir>
  result = platform.getGlobalConfigDir(p)

proc findConfigDir*(explicit: string = ""): Option[string] =
  ## Resolve config directory in priority order:
  ## 1. Explicit --config-dir flag
  ## 2. GSD_CONFIG_DIR env var
  ## 3. Local ./.claude/gsd-config.json
  ## 4. Global ~/.claude/gsd-config.json
  ## 5. Local ./.codex/gsd-config.json
  ## 6. Global ~/.codex/gsd-config.json

  # Explicit takes priority
  if explicit.len > 0:
    let expanded = expandPath(explicit)
    if dirExists(expanded):
      return some(expanded)
    return none(string)

  # Environment variable override
  let envDir = getEnvConfigDir()
  if envDir.isSome:
    return envDir

  # Check local first
  let localDir = getLocalConfigDir()
  let localConfig = localDir / ConfigFileName
  if fileExists(localConfig):
    return some(localDir)

  # Check global
  let globalDir = getGlobalConfigDir()
  let globalConfig = globalDir / ConfigFileName
  if fileExists(globalConfig):
    return some(globalDir)

  # Check Codex (if Claude not found)
  let codexLocal = platform.getLocalConfigDir(pCodexCli)
  let codexLocalConfig = codexLocal / ConfigFileName
  if fileExists(codexLocalConfig):
    return some(codexLocal)

  let codexGlobal = platform.getGlobalConfigDir(pCodexCli)
  let codexGlobalConfig = codexGlobal / ConfigFileName
  if fileExists(codexGlobalConfig):
    return some(codexGlobal)

  return none(string)

proc findConfigDir*(p: Platform, explicit: string = ""): Option[string] =
  ## Resolve config directory for a specific platform in priority order:
  ## 1. Explicit --config-dir flag
  ## 2. GSD_CONFIG_DIR env var
  ## 3. Local ./.<platform>/gsd-config.json
  ## 4. Global ~/.<platform>/gsd-config.json

  # Explicit takes priority
  if explicit.len > 0:
    let expanded = expandPath(explicit)
    if dirExists(expanded):
      return some(expanded)
    return none(string)

  # Environment variable override
  let envDir = getEnvConfigDir()
  if envDir.isSome:
    let cfg = loadConfig(envDir.get())
    if cfg.isSome and cfg.get().platform == p:
      return envDir
    if cfg.isNone:
      let inferred = inferPlatformFromDir(envDir.get())
      if inferred.isSome and inferred.get() == p:
        return envDir

  # Check local first
  let localDir = platform.getLocalConfigDir(p)
  let localConfig = localDir / ConfigFileName
  if fileExists(localConfig):
    return some(localDir)

  # Check global
  let globalDir = platform.getGlobalConfigDir(p)
  let globalConfig = globalDir / ConfigFileName
  if fileExists(globalConfig):
    return some(globalDir)

  return none(string)

proc addInstalledConfig(installs: var seq[InstalledConfig], p: Platform, dir: string) =
  for item in installs:
    if item.dir == dir:
      return
  installs.add(InstalledConfig(platform: p, dir: dir))

proc listInstalledConfigs*(): seq[InstalledConfig] =
  ## List all detected installations (local/global + env var if valid)
  result = @[]

  for p in [pClaudeCode, pCodexCli]:
    for dir in [platform.getLocalConfigDir(p), platform.getGlobalConfigDir(p)]:
      if fileExists(dir / ConfigFileName):
        addInstalledConfig(result, p, dir)

  let envDir = getEnvConfigDir()
  if envDir.isSome:
    let cfg = loadConfig(envDir.get())
    if cfg.isSome:
      addInstalledConfig(result, cfg.get().platform, envDir.get())
    else:
      let inferred = inferPlatformFromDir(envDir.get())
      if inferred.isSome:
        addInstalledConfig(result, inferred.get(), envDir.get())

proc findVersionFile*(explicit: string = ""): Option[string] =
  ## Find VERSION file, checking local then global
  ## Returns the path if found

  if explicit.len > 0:
    let expanded = expandPath(explicit)
    let versionPath = expanded / GsdDirName / VersionFileName
    if fileExists(versionPath):
      return some(versionPath)
    return none(string)

  # Check local first
  let localVersion = getLocalConfigDir() / GsdDirName / VersionFileName
  if fileExists(localVersion):
    return some(localVersion)

  # Check global
  let globalVersion = getGlobalConfigDir() / GsdDirName / VersionFileName
  if fileExists(globalVersion):
    return some(globalVersion)

  return none(string)

proc getInstalledVersion*(explicit: string = ""): Option[string] =
  ## Read installed version from VERSION file
  let versionFile = findVersionFile(explicit)
  if versionFile.isNone:
    return none(string)

  try:
    result = some(readFile(versionFile.get()).strip())
  except IOError:
    result = none(string)

proc isLocalInstall*(explicit: string = ""): bool =
  ## Check if we're dealing with a local install
  if explicit.len > 0:
    return false  # Explicit is treated as custom

  let localVersion = getLocalConfigDir() / GsdDirName / VersionFileName
  return fileExists(localVersion)

proc loadConfig*(configDir: string): Option[GsdConfig] =
  ## Load gsd-config.json from specified directory
  let configPath = configDir / ConfigFileName
  if not fileExists(configPath):
    return none(GsdConfig)

  try:
    let content = readFile(configPath)
    let json = parseJson(content)

    var config = GsdConfig()
    config.version = json.getOrDefault("version").getStr("0.0.0")
    config.configDir = json.getOrDefault("config_dir").getStr(configDir)
    config.installedAt = json.getOrDefault("installed_at").getStr("")

    let installTypeStr = json.getOrDefault("install_type").getStr("global")
    case installTypeStr
    of "local": config.installType = itLocal
    of "custom": config.installType = itCustom
    else: config.installType = itGlobal

    # Parse platform (default to Claude Code for backward compatibility)
    let platformStr = json.getOrDefault("platform").getStr("claude")
    try:
      config.platform = parsePlatform(platformStr)
    except ValueError:
      config.platform = pClaudeCode

    return some(config)
  except JsonParsingError, IOError:
    return none(GsdConfig)

proc saveConfig*(config: GsdConfig, configDir: string): bool =
  ## Save gsd-config.json to specified directory
  let configPath = configDir / ConfigFileName

  try:
    let json = %*{
      "version": config.version,
      "install_type": $config.installType,
      "platform": $config.platform,
      "config_dir": config.configDir,
      "installed_at": config.installedAt
    }
    writeFile(configPath, json.pretty())
    return true
  except IOError:
    return false

proc getGsdCacheDir*(configDir: string): string =
  ## Get cache directory for a config dir
  result = configDir / CacheDirName

proc getGsdDir*(configDir: string): string =
  ## Get gsd resource directory for a config dir
  result = configDir / GsdDirName
