## Config resolution for GSD
## Determines install location (local vs global) and reads gsd-config.json

import std/[os, json, options, strutils]

type
  InstallType* = enum
    itGlobal = "global"
    itLocal = "local"
    itCustom = "custom"

  GsdConfig* = object
    version*: string
    installType*: InstallType
    configDir*: string
    installedAt*: string

const
  Version* = "0.1.0"
  ConfigFileName* = "gsd-config.json"
  GsdDirName* = "gsd"
  CacheDirName* = "cache"
  VersionFileName* = "VERSION"

proc expandPath*(path: string): string =
  ## Expand ~ to home directory
  if path == "~":
    return getHomeDir()
  elif path.startsWith("~/"):
    return getHomeDir() / path[2..^1]
  elif path.startsWith("~"):
    # ~username style - not supported, return as-is
    return path
  return path

proc getLocalConfigDir*(): string =
  ## Returns ./.claude if it exists
  result = getCurrentDir() / ".claude"

proc getGlobalConfigDir*(): string =
  ## Returns ~/.claude
  result = getHomeDir() / ".claude"

proc findConfigDir*(explicit: string = ""): Option[string] =
  ## Resolve config directory in priority order:
  ## 1. Explicit --config-dir flag
  ## 2. Local ./.claude/gsd-config.json
  ## 3. Global ~/.claude/gsd-config.json

  # Explicit takes priority
  if explicit.len > 0:
    let expanded = expandPath(explicit)
    if dirExists(expanded):
      return some(expanded)
    return none(string)

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

  return none(string)

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
