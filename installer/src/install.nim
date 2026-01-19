## GSD Installation logic
## Handles file copying, settings.json merging, and cleanup

import std/[os, json, options, strutils, times]
import config

const
  # Old GSD statusline patterns to auto-migrate (don't prompt)
  OldStatuslinePatterns = [
    "node ~/.claude/hooks/statusline.js",
    "node \"$HOME/.claude/hooks/statusline.js\"",
    "node .claude/hooks/statusline.js",
    "node $HOME/.claude/hooks/statusline.js"
  ]

type
  InstallOptions* = object
    configDir*: string
    installType*: InstallType
    forceStatusline*: bool
    verbose*: bool

  InstallResult* = object
    success*: bool
    message*: string
    configDir*: string

proc log(msg: string, verbose: bool) =
  if verbose:
    echo "  ", msg

proc isOldGsdStatusline*(command: string): bool =
  ## Check if a statusline command is from old GSD (auto-migrate)
  for pattern in OldStatuslinePatterns:
    if command.contains(pattern) or command == pattern:
      return true
  return false

proc copyDirRecursive(src, dest: string, verbose: bool): bool =
  ## Helper: recursively copy directory contents (no deletion)
  try:
    createDir(dest)
    for kind, path in walkDir(src):
      let destPath = dest / extractFilename(path)
      case kind
      of pcFile:
        copyFile(path, destPath)
        log("Copied: " & extractFilename(path), verbose)
      of pcDir:
        if not copyDirRecursive(path, destPath, verbose):
          return false
      else:
        discard
    return true
  except OSError as e:
    stderr.writeLine "Error copying directory: ", e.msg
    return false

proc parseJsonSafe(content: string): Option[JsonNode] =
  ## Parse JSON with error handling
  try:
    return some(parseJson(content))
  except JsonParsingError:
    return none(JsonNode)

proc loadSettings(settingsPath: string): JsonNode =
  ## Load settings.json or return empty object
  if not fileExists(settingsPath):
    return %*{}

  var content: string
  try:
    content = readFile(settingsPath)
  except IOError as e:
    stderr.writeLine "Warning: Could not read settings.json: ", e.msg
    return %*{}

  let parsed = parseJsonSafe(content)

  if parsed.isNone:
    # Backup corrupted file
    let backupPath = settingsPath & ".bak"
    try:
      copyFile(settingsPath, backupPath)
      stderr.writeLine "Warning: settings.json was corrupted, backed up to settings.json.bak"
    except OSError:
      stderr.writeLine "Warning: settings.json was corrupted and could not be backed up"
    return %*{}

  return parsed.get()

proc isGsdHookCommand(command: string): bool =
  ## Check if a command string is a GSD hook
  command.contains("#gsd") or command.contains("gsd check-update") or
    command.contains("gsd-check-update") or isOldGsdStatusline(command)

proc mergeHooks*(existing: JsonNode, gsdHooks: JsonNode): JsonNode =
  ## Merge GSD hooks into existing hooks object, avoiding duplicates
  ## Claude Code format: { "EventName": [{ "matcher": "...", "hooks": [...] }] }
  ## Also handles legacy array format for backwards compatibility
  result = newJObject()

  # Start with existing hooks if present
  if existing.hasKey("hooks"):
    let hooks = existing["hooks"]

    if hooks.kind == JObject:
      # New object format: { "EventName": [...] }
      for eventName, eventHooks in hooks.pairs:
        if eventHooks.kind != JArray:
          continue

        var filteredEntries = newJArray()
        for hookEntry in eventHooks:
          # Check legacy flat format (command directly on hook entry)
          let legacyCmd = hookEntry.getOrDefault("command").getStr("")
          if isGsdHookCommand(legacyCmd):
            # Skip entire entry if it's a legacy GSD hook
            continue

          # Filter individual inner hooks, keeping non-GSD ones
          if hookEntry.hasKey("hooks") and hookEntry["hooks"].kind == JArray:
            var filteredInnerHooks = newJArray()
            for h in hookEntry["hooks"]:
              let cmd = h.getOrDefault("command").getStr("")
              if not isGsdHookCommand(cmd):
                filteredInnerHooks.add(h)

            # Only keep entry if it has non-GSD hooks remaining
            if filteredInnerHooks.len > 0:
              var newEntry = copy(hookEntry)
              newEntry["hooks"] = filteredInnerHooks
              filteredEntries.add(newEntry)
          else:
            # No inner hooks array - keep the entry as-is
            filteredEntries.add(hookEntry)

        if filteredEntries.len > 0:
          result[eventName] = filteredEntries

    elif hooks.kind == JArray:
      # Legacy array format: [ { "event": "...", "command": "..." }, ... ]
      # Convert to new object format while preserving non-GSD hooks
      for hookEntry in hooks:
        let eventName = hookEntry.getOrDefault("event").getStr("")
        let cmd = hookEntry.getOrDefault("command").getStr("")

        # Skip GSD hooks
        if isGsdHookCommand(cmd):
          continue

        # Skip entries without event name
        if eventName.len == 0:
          continue

        # Convert to new format
        if not result.hasKey(eventName):
          result[eventName] = newJArray()

        # Build new format hook entry
        var newEntry = newJObject()
        let matcher = hookEntry.getOrDefault("matcher")
        if matcher.isNil or matcher.kind == JNull:
          newEntry["matcher"] = %""
        else:
          newEntry["matcher"] = matcher

        var innerHooks = newJArray()
        var innerHook = newJObject()
        innerHook["type"] = %"command"
        innerHook["command"] = %cmd
        innerHooks.add(innerHook)
        newEntry["hooks"] = innerHooks

        result[eventName].add(newEntry)

  # Merge in GSD hooks
  for eventName, eventHooks in gsdHooks.pairs:
    if not result.hasKey(eventName):
      result[eventName] = newJArray()

    for hookEntry in eventHooks:
      result[eventName].add(hookEntry)

proc getStatuslineCommand(statusLine: JsonNode): string =
  ## Extract command from statusLine config (handles both string and object formats)
  if statusLine.kind == JString:
    return statusLine.getStr("")
  elif statusLine.kind == JObject and statusLine.hasKey("command"):
    return statusLine["command"].getStr("")
  return ""

proc isGsdStatusline(statusLine: JsonNode): bool =
  ## Check if a statusLine config is GSD's
  let cmd = getStatuslineCommand(statusLine)
  cmd.contains("#gsd") or cmd.contains("gsd statusline")

proc mergeStatusline*(existing: JsonNode, gsdStatusline: JsonNode,
                      forceStatusline: bool): tuple[config: JsonNode, changed: bool] =
  ## Merge statusLine setting (Claude Code uses camelCase statusLine)
  ## Returns (new statusLine config, whether it was changed)

  # Check both statusLine (correct) and statusline (legacy) keys
  let hasStatusLine = existing.hasKey("statusLine")
  let hasLegacy = existing.hasKey("statusline")

  if not hasStatusLine and not hasLegacy:
    return (gsdStatusline, true)

  # Prefer statusLine over legacy statusline
  let current = if hasStatusLine: existing["statusLine"] else: existing["statusline"]
  let currentCmd = getStatuslineCommand(current)

  if currentCmd.len == 0:
    return (gsdStatusline, true)

  # Auto-migrate old GSD statuslines (both node-based and old gsd)
  if isOldGsdStatusline(currentCmd) or isGsdStatusline(current):
    return (gsdStatusline, true)

  # Force flag overrides
  if forceStatusline:
    return (gsdStatusline, true)

  # Keep existing custom statusline (convert to new format if needed)
  if current.kind == JString:
    return (%*{"type": "command", "command": currentCmd}, false)
  return (current, false)

proc createGsdHooks(gsdBinaryPath, configDir: string): JsonNode =
  ## Create the GSD hook definitions in Claude Code's expected format
  ## Format: { "EventName": [{ "matcher": "...", "hooks": [{ "type": "command", "command": "..." }] }] }
  ## Passes --config-dir to ensure correct cache location for custom installs
  ## Both paths are quoted to handle spaces in paths
  result = %*{
    "SessionStart": [
      {
        "matcher": "",  # Empty matcher = always run
        "hooks": [
          {
            "type": "command",
            "command": "\"" & gsdBinaryPath & "\" check-update --config-dir \"" & configDir & "\" #gsd"
          }
        ]
      }
    ]
  }

proc createStatuslineConfig(gsdBinaryPath, configDir: string): JsonNode =
  ## Create the statusLine config in Claude Code's expected format
  ## Passes --config-dir to ensure correct cache location for custom installs
  ## Both paths are quoted to handle spaces in paths
  result = %*{
    "type": "command",
    "command": "\"" & gsdBinaryPath & "\" statusline --config-dir \"" & configDir & "\" #gsd"
  }

proc writeVersionFile(configDir: string): bool =
  ## Write VERSION file
  let versionPath = configDir / GsdDirName / VersionFileName
  try:
    writeFile(versionPath, Version)
    return true
  except IOError:
    return false

proc cleanupOldFiles(configDir: string, verbose: bool) =
  ## Remove legacy hook files from previous installations
  let oldFiles = [
    configDir / "hooks" / "statusline.js",
    configDir / "hooks" / "gsd-check-update.js",
    configDir / "gsd" / "bin" / "install.js",
    configDir / "gsd-notify.sh"  # Orphaned from older versions
  ]

  for path in oldFiles:
    if fileExists(path):
      try:
        removeFile(path)
        log("Removed old file: " & path, verbose)
      except OSError:
        discard

  # Remove old hooks directory if empty
  let hooksDir = configDir / "hooks"
  if dirExists(hooksDir):
    try:
      var isEmpty = true
      for _ in walkDir(hooksDir):
        isEmpty = false
        break
      if isEmpty:
        removeDir(hooksDir)
        log("Removed empty hooks directory", verbose)
    except OSError:
      discard

proc findGsdBinary(): tuple[path: string, inPath: bool] =
  ## Find the gsd binary path (for settings.json commands)
  ## Returns (path, inPath) where inPath=true means we fell back to PATH lookup

  # First check if we're running from a known location
  let selfPath = getAppFilename()
  if selfPath.len > 0 and fileExists(selfPath):
    return (selfPath, false)

  # Check common locations
  let locations = [
    "/usr/local/bin/gsd",
    getHomeDir() / ".local" / "bin" / "gsd",
    getHomeDir() / "bin" / "gsd"
  ]

  for loc in locations:
    if fileExists(loc):
      return (loc, false)

  # Fallback to just "gsd" (assumes in PATH)
  return ("gsd", true)

const
  # GSD agent files - only these are installed/removed
  GsdAgentFiles* = [
    "gsd-project-researcher.md",
    "gsd-research-synthesizer.md",
    "gsd-roadmapper.md",
    "gsd-integration-checker.md",
    "gsd-plan-checker.md",
    "gsd-codebase-mapper.md",
    "gsd-debugger.md",
    "gsd-phase-researcher.md",
    "gsd-executor.md",
    "gsd-verifier.md",
    "gsd-planner.md"
  ]

proc rewritePathReferences*(content, installType, configDir: string): string =
  ## Rewrite ~/.claude/gsd/ references based on install type
  ## For local installs, use relative paths
  ## For custom installs, use the actual custom config path
  ## For global installs, keep the default ~/.claude path
  if installType == "local":
    # For local installs, use relative .claude path
    result = content.replace("@~/.claude/gsd/", "@.claude/gsd/")
    result = result.replace("@~/.claude/", "@.claude/")
    # Also handle non-@ references in prose/documentation
    result = result.replace("~/.claude/gsd/", ".claude/gsd/")
    result = result.replace("~/.claude/", ".claude/")
  elif installType == "custom" and configDir.len > 0:
    # For custom installs, rewrite to the actual custom path
    result = content.replace("@~/.claude/gsd/", "@" & configDir & "/gsd/")
    result = result.replace("@~/.claude/", "@" & configDir & "/")
    # Also handle non-@ references in prose/documentation
    result = result.replace("~/.claude/gsd/", configDir & "/gsd/")
    result = result.replace("~/.claude/", configDir & "/")
  else:
    # For global installs, keep the ~/.claude path
    result = content

proc copyAndRewriteDir(src, dest, installType, configDir: string, verbose: bool): bool =
  ## Copy directory, rewriting path references in .md files
  try:
    createDir(dest)
    for kind, path in walkDir(src):
      let destPath = dest / extractFilename(path)
      case kind
      of pcFile:
        if path.endsWith(".md"):
          # Rewrite path references in markdown files
          let content = readFile(path)
          let rewritten = rewritePathReferences(content, installType, configDir)
          writeFile(destPath, rewritten)
          log("Processed: " & extractFilename(path), verbose)
        else:
          copyFile(path, destPath)
          log("Copied: " & extractFilename(path), verbose)
      of pcDir:
        if not copyAndRewriteDir(path, destPath, installType, configDir, verbose):
          return false
      else:
        discard
    return true
  except OSError as e:
    stderr.writeLine "Error copying directory: ", e.msg
    return false
  except IOError as e:
    stderr.writeLine "Error processing file: ", e.msg
    return false

proc copyResourceDirWithRewrite(src, dest, installType, configDir: string, verbose: bool): bool =
  ## Safely copy a directory using atomic rename, with path rewriting
  let tempDest = dest & ".tmp." & $epochTime().int

  # Copy to temp location with rewriting
  if not copyAndRewriteDir(src, tempDest, installType, configDir, verbose):
    try:
      removeDir(tempDest)
    except OSError:
      discard
    return false

  # Backup existing, then atomic rename
  let backupDest = dest & ".bak"
  try:
    if dirExists(dest):
      if dirExists(backupDest):
        removeDir(backupDest)
      moveDir(dest, backupDest)

    moveDir(tempDest, dest)

    if dirExists(backupDest):
      removeDir(backupDest)

    return true
  except OSError as e:
    stderr.writeLine "Error during atomic rename: ", e.msg
    if dirExists(backupDest) and not dirExists(dest):
      try:
        moveDir(backupDest, dest)
        echo "Restored previous version from backup"
      except OSError:
        discard
    try:
      removeDir(tempDest)
    except OSError:
      discard
    return false

proc installGsdAgents(sourceDir, destDir, installType, configDir: string, verbose: bool): bool =
  ## Install only GSD agent files, preserving user's custom agents
  ## This merges rather than replacing the entire directory
  ## Path references are rewritten for local/custom installs
  if not dirExists(destDir):
    try:
      createDir(destDir)
    except OSError as e:
      stderr.writeLine "Error creating agents directory: ", e.msg
      return false

  for agentFile in GsdAgentFiles:
    let srcPath = sourceDir / agentFile
    let destPath = destDir / agentFile
    if fileExists(srcPath):
      try:
        # Agent files are markdown - rewrite path references
        let content = readFile(srcPath)
        let rewritten = rewritePathReferences(content, installType, configDir)
        writeFile(destPath, rewritten)
        log("Installed: " & agentFile, verbose)
      except OSError as e:
        stderr.writeLine "Error copying agent file: ", e.msg
        return false
      except IOError as e:
        stderr.writeLine "Error processing agent file: ", e.msg
        return false

  return true

proc install*(sourceDir: string, opts: InstallOptions): InstallResult =
  ## Main installation procedure

  let configDir = if opts.configDir.len > 0:
    expandPath(opts.configDir)
  elif opts.installType == itLocal:
    getLocalConfigDir()
  else:
    getGlobalConfigDir()

  result.configDir = configDir

  # Create config directory if needed
  if not dirExists(configDir):
    try:
      createDir(configDir)
    except OSError as e:
      result.success = false
      result.message = "Failed to create config directory: " & e.msg
      return

  echo "Installing GSD to ", configDir, "..."

  # Determine install type for path rewriting
  # Custom config-dir overrides default install type for path rewriting
  let installTypeStr = if opts.configDir.len > 0:
    "custom"
  elif opts.installType == itLocal:
    "local"
  else:
    "global"

  # 1. Copy resource directories (with path rewriting for local/custom installs)
  let gsdDir = configDir / GsdDirName
  let commandsDir = configDir / "commands" / "gsd"

  # Copy gsd/ resources (templates, workflows, references)
  let gsdSource = sourceDir / "gsd"
  if dirExists(gsdSource):
    if not copyResourceDirWithRewrite(gsdSource, gsdDir, installTypeStr, configDir, opts.verbose):
      result.success = false
      result.message = "Failed to copy gsd resources"
      return
    echo "  Installed gsd resources"

  # Copy commands/gsd/ (with path rewriting)
  let commandsSource = sourceDir / "commands" / "gsd"
  if dirExists(commandsSource):
    createDir(configDir / "commands")
    if not copyResourceDirWithRewrite(commandsSource, commandsDir, installTypeStr, configDir, opts.verbose):
      result.success = false
      result.message = "Failed to copy commands"
      return
    echo "  Installed commands/gsd"

  # Install agents (merge, don't replace - preserves user's custom agents)
  let agentsSource = sourceDir / "agents"
  let agentsDir = configDir / "agents"
  if dirExists(agentsSource):
    if not installGsdAgents(agentsSource, agentsDir, installTypeStr, configDir, opts.verbose):
      result.success = false
      result.message = "Failed to install agents"
      return
    echo "  Installed agents"

  # 2. Write VERSION file
  if not writeVersionFile(configDir):
    result.success = false
    result.message = "Failed to write VERSION file"
    return

  # 3. Update settings.json
  let settingsPath = configDir / "settings.json"
  var settings = loadSettings(settingsPath)

  let (gsdBinaryPath, gsdInPath) = findGsdBinary()

  if gsdInPath:
    echo "  Warning: gsd binary not found in standard locations."
    echo "           Hooks will use 'gsd' and assume it's in PATH."
    echo "           Consider moving gsd to /usr/local/bin/ or ~/.local/bin/"

  # Merge hooks (pass configDir so hooks use the correct cache location)
  let gsdHooks = createGsdHooks(gsdBinaryPath, configDir)
  settings["hooks"] = mergeHooks(settings, gsdHooks)

  # Merge statusLine (note: camelCase is the correct Claude Code format)
  let statuslineConfig = createStatuslineConfig(gsdBinaryPath, configDir)
  let (newStatusline, statuslineChanged) = mergeStatusline(
    settings, statuslineConfig, opts.forceStatusline
  )
  settings["statusLine"] = newStatusline

  # Remove legacy lowercase key if present
  if settings.hasKey("statusline"):
    settings.delete("statusline")

  if not statuslineChanged and not opts.forceStatusline:
    echo "  Kept existing custom statusline (use --force-statusline to override)"

  # Write settings
  try:
    writeFile(settingsPath, settings.pretty())
    log("Updated settings.json", opts.verbose)
  except IOError as e:
    result.success = false
    result.message = "Failed to write settings.json: " & e.msg
    return

  # 4. Write gsd-config.json
  let gsdConfig = GsdConfig(
    version: Version,
    installType: opts.installType,
    configDir: configDir,
    installedAt: now().utc.format("yyyy-MM-dd'T'HH:mm:ss'Z'")
  )
  if not saveConfig(gsdConfig, configDir):
    result.success = false
    result.message = "Failed to write gsd-config.json"
    return

  # 5. Cleanup old files
  cleanupOldFiles(configDir, opts.verbose)

  # 6. Create cache directory
  let cacheDir = getGsdCacheDir(configDir)
  if not dirExists(cacheDir):
    try:
      createDir(cacheDir)
    except OSError:
      discard  # Non-fatal

  result.success = true
  result.message = "Installation complete"

proc removeGsdAgents(agentsDir: string, verbose: bool) =
  ## Remove only GSD-owned agent files, preserving user's custom agents
  if not dirExists(agentsDir):
    return

  for agentFile in GsdAgentFiles:
    let path = agentsDir / agentFile
    if fileExists(path):
      try:
        removeFile(path)
        log("Removed: " & path, verbose)
      except OSError:
        discard

  # Remove agents/ directory only if empty
  try:
    var isEmpty = true
    for _ in walkDir(agentsDir):
      isEmpty = false
      break
    if isEmpty:
      removeDir(agentsDir)
      log("Removed empty agents directory", verbose)
  except OSError:
    discard

proc uninstall*(configDir: string, verbose: bool): bool =
  ## Remove GSD from a config directory
  let gsdDir = configDir / GsdDirName
  let commandsDir = configDir / "commands" / "gsd"
  let agentsDir = configDir / "agents"
  let configFile = configDir / ConfigFileName

  echo "Uninstalling GSD from ", configDir, "..."

  # Remove gsd/ and commands/gsd/ directories entirely (GSD-owned)
  for dir in [gsdDir, commandsDir]:
    if dirExists(dir):
      try:
        removeDir(dir)
        log("Removed: " & dir, verbose)
      except OSError as e:
        stderr.writeLine "Warning: Could not remove ", dir, ": ", e.msg

  # Remove only GSD agent files, preserving user's custom agents
  removeGsdAgents(agentsDir, verbose)

  # Remove config file
  if fileExists(configFile):
    try:
      removeFile(configFile)
      log("Removed: " & configFile, verbose)
    except OSError:
      discard

  # Update settings.json to remove GSD hooks
  let settingsPath = configDir / "settings.json"
  if fileExists(settingsPath):
    var settings = loadSettings(settingsPath)

    # Remove GSD hooks (handles new object format)
    if settings.hasKey("hooks") and settings["hooks"].kind == JObject:
      var newHooks = newJObject()
      for eventName, eventHooks in settings["hooks"].pairs:
        if eventHooks.kind != JArray:
          continue
        var filteredHooks = newJArray()
        for hookEntry in eventHooks:
          var isGsdHook = false
          # Check nested hooks array
          if hookEntry.hasKey("hooks") and hookEntry["hooks"].kind == JArray:
            for h in hookEntry["hooks"]:
              let cmd = h.getOrDefault("command").getStr("")
              if isGsdHookCommand(cmd):
                isGsdHook = true
                break
          if not isGsdHook:
            filteredHooks.add(hookEntry)
        if filteredHooks.len > 0:
          newHooks[eventName] = filteredHooks
      settings["hooks"] = newHooks

    # Clear statusLine if it's GSD's (camelCase is correct format)
    if settings.hasKey("statusLine"):
      if isGsdStatusline(settings["statusLine"]):
        settings.delete("statusLine")

    # Also clean up legacy lowercase key
    if settings.hasKey("statusline"):
      let cmd = getStatuslineCommand(settings["statusline"])
      if cmd.contains("#gsd") or cmd.contains("gsd statusline"):
        settings.delete("statusline")

    try:
      writeFile(settingsPath, settings.pretty())
    except IOError:
      stderr.writeLine "Warning: Could not update settings.json"

  echo "GSD uninstalled."
  return true
