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
    platforms*: seq[Platform]
    gsdDir*: string
    installedAt*: string

  InstalledConfig* = object
    platform*: Platform
    dir*: string ## the .gsd/ directory

proc loadConfig*(configDir: string): Option[GsdConfig]

const
  Version* = "0.3.2"
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
    let rest = if path.len > 2: path[2 ..^ 1] else: ""
    return (getHomeDir() / rest).normalizedPath
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
        let rest = if path.len > 14: path[14 ..^ 1] else: ""
        return (home / rest).normalizedPath

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

proc inferInstallType*(dir: string): InstallType =
  ## Infer install type from a .gsd/ directory path
  let resolved = resolvedPath(expandPath(dir))
  if resolved == resolvedPath(platform.getLocalGsdDir()):
    return itLocal
  if resolved == resolvedPath(platform.getGlobalGsdDir()):
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
  ## Returns ./.gsd
  result = platform.getLocalGsdDir()

proc getGlobalConfigDir*(): string =
  ## Returns ~/.gsd
  result = platform.getGlobalGsdDir()

proc getLocalConfigDirFor*(p: Platform): string =
  ## Returns ./.<platform-config-dir> (tool-specific dir)
  result = platform.getLocalConfigDir(p)

proc getGlobalConfigDirFor*(p: Platform): string =
  ## Returns ~/.<platform-config-dir> (tool-specific dir)
  result = platform.getGlobalConfigDir(p)

proc findConfigDir*(explicit: string = ""): Option[string] =
  ## Resolve .gsd/ config directory in priority order:
  ## 1. Explicit --config-dir flag
  ## 2. GSD_CONFIG_DIR env var
  ## 3. Local ./.gsd/gsd-config.json
  ## 4. Global ~/.gsd/gsd-config.json
  ## 5. Legacy fallback: .claude/ or .codex/ (v0.2 compat)

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

  # v0.3: Check .gsd/ (local then global)
  let localDir = getLocalConfigDir()
  let localConfig = localDir / ConfigFileName
  if fileExists(localConfig):
    return some(localDir)

  let globalDir = getGlobalConfigDir()
  let globalConfig = globalDir / ConfigFileName
  if fileExists(globalConfig):
    return some(globalDir)

  # v0.2 legacy fallback: Check tool dirs
  for p in [pClaudeCode, pCodexCli]:
    for dir in [platform.getLocalConfigDir(p), platform.getGlobalConfigDir(p)]:
      if fileExists(dir / ConfigFileName):
        return some(dir)

  return none(string)

proc findConfigDir*(p: Platform, explicit: string = ""): Option[string] =
  ## Resolve .gsd/ config directory that includes a given platform.
  ## v0.3: checks .gsd/gsd-config.json for platforms array
  ## v0.2 fallback: checks tool-specific dirs

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
    if cfg.isSome and p in cfg.get().platforms:
      return envDir

  # v0.3: Check .gsd/ (local then global)
  for gsdDir in [platform.getLocalGsdDir(), platform.getGlobalGsdDir()]:
    let configPath = gsdDir / ConfigFileName
    if fileExists(configPath):
      let cfg = loadConfig(gsdDir)
      if cfg.isSome and p in cfg.get().platforms:
        return some(gsdDir)

  # v0.2 fallback: Check tool-specific dirs
  let localDir = platform.getLocalConfigDir(p)
  let localConfig = localDir / ConfigFileName
  if fileExists(localConfig):
    return some(localDir)

  let globalDir = platform.getGlobalConfigDir(p)
  let globalConfig = globalDir / ConfigFileName
  if fileExists(globalConfig):
    return some(globalDir)

  return none(string)

proc addInstalledConfig(installs: var seq[InstalledConfig], p: Platform, dir: string) =
  for item in installs:
    if item.platform == p and item.dir == dir:
      return
  installs.add(InstalledConfig(platform: p, dir: dir))

proc listInstalledConfigs*(): seq[InstalledConfig] =
  ## List all detected installations
  ## v0.3: reads platforms from .gsd/gsd-config.json
  ## v0.2 fallback: checks each tool dir
  result = @[]

  # v0.3: Check .gsd/ (local then global)
  for gsdDir in [platform.getLocalGsdDir(), platform.getGlobalGsdDir()]:
    if fileExists(gsdDir / ConfigFileName):
      let cfg = loadConfig(gsdDir)
      if cfg.isSome:
        for p in cfg.get().platforms:
          addInstalledConfig(result, p, gsdDir)

  # v0.2 fallback: Check each tool dir
  if result.len == 0:
    for p in [pClaudeCode, pCodexCli]:
      for dir in [platform.getLocalConfigDir(p), platform.getGlobalConfigDir(p)]:
        if fileExists(dir / ConfigFileName):
          addInstalledConfig(result, p, dir)

  # Environment variable override
  let envDir = getEnvConfigDir()
  if envDir.isSome:
    let cfg = loadConfig(envDir.get())
    if cfg.isSome:
      for p in cfg.get().platforms:
        addInstalledConfig(result, p, envDir.get())

proc findVersionFile*(explicit: string = ""): Option[string] =
  ## Find VERSION file in .gsd/ directory
  ## Returns the path if found

  if explicit.len > 0:
    let expanded = expandPath(explicit)
    let versionPath = expanded / VersionFileName
    if fileExists(versionPath):
      return some(versionPath)
    return none(string)

  # Check local .gsd/ first
  let localVersion = getLocalConfigDir() / VersionFileName
  if fileExists(localVersion):
    return some(localVersion)

  # Check global ~/.gsd/
  let globalVersion = getGlobalConfigDir() / VersionFileName
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
    return false # Explicit is treated as custom

  let localVersion = getLocalConfigDir() / VersionFileName
  return fileExists(localVersion)

proc loadConfig*(configDir: string): Option[GsdConfig] =
  ## Load gsd-config.json from specified directory
  ## Handles both v0.3 format (platforms array, gsd_dir) and
  ## v0.2 format (platform string, config_dir) for backward compat
  let configPath = configDir / ConfigFileName
  if not fileExists(configPath):
    return none(GsdConfig)

  try:
    let content = readFile(configPath)
    let json = parseJson(content)

    var config = GsdConfig()
    config.version = json.getOrDefault("version").getStr("0.0.0")
    config.installedAt = json.getOrDefault("installed_at").getStr("")

    let installTypeStr = json.getOrDefault("install_type").getStr("global")
    case installTypeStr
    of "local": config.installType = itLocal
    of "custom": config.installType = itCustom
    else: config.installType = itGlobal

    # v0.3 format: gsd_dir and platforms array
    if json.hasKey("gsd_dir"):
      config.gsdDir = json["gsd_dir"].getStr(configDir)
    elif json.hasKey("config_dir"):
      # v0.2 fallback
      config.gsdDir = json["config_dir"].getStr(configDir)
    else:
      config.gsdDir = configDir

    # v0.3 format: platforms array
    if json.hasKey("platforms") and json["platforms"].kind == JArray:
      config.platforms = @[]
      for item in json["platforms"]:
        let platStr = item.getStr("")
        try:
          config.platforms.add(parsePlatform(platStr))
        except ValueError:
          discard
    elif json.hasKey("platform"):
      # v0.2 fallback: single platform string
      let platformStr = json["platform"].getStr("claude")
      try:
        config.platforms = @[parsePlatform(platformStr)]
      except ValueError:
        config.platforms = @[pClaudeCode]
    else:
      config.platforms = @[pClaudeCode]

    return some(config)
  except JsonParsingError, IOError:
    return none(GsdConfig)

proc saveConfig*(config: GsdConfig, configDir: string): bool =
  ## Save gsd-config.json to specified directory (v0.3 format)
  let configPath = configDir / ConfigFileName

  try:
    var platformsArr = newJArray()
    for p in config.platforms:
      platformsArr.add(%($p))

    let json = %*{
      "version": config.version,
      "install_type": $config.installType,
      "gsd_dir": config.gsdDir,
      "platforms": platformsArr,
      "installed_at": config.installedAt
    }
    writeFile(configPath, json.pretty())
    return true
  except IOError:
    return false

proc getGsdCacheDir*(gsdDir: string): string =
  ## Get cache directory within .gsd/
  result = gsdDir / CacheDirName

proc getGsdDir*(gsdDir: string): string =
  ## Get .gsd/ resource directory (returns gsdDir directly)
  result = gsdDir
