## GSD Installation logic
## Handles file copying, settings.json merging, and cleanup

import std/[os, json, options, strutils, times, algorithm, sequtils]
import config, platform, toml

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
    platform*: Platform
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

proc createGsdHooks(gsdBinaryPath, gsdDir: string): JsonNode =
  ## Create the GSD hook definitions in Claude Code's expected format
  ## Format: { "EventName": [{ "matcher": "...", "hooks": [{ "type": "command", "command": "..." }] }] }
  ## Passes --config-dir pointing to .gsd/ directory
  ## Both paths are quoted to handle spaces in paths
  result = %*{
    "SessionStart": [
      {
        "matcher": "",  # Empty matcher = always run
        "hooks": [
          {
            "type": "command",
            "command": "\"" & gsdBinaryPath & "\" check-update --config-dir \"" & gsdDir & "\" #gsd"
          }
        ]
      }
    ]
  }

proc createStatuslineConfig(gsdBinaryPath, gsdDir: string): JsonNode =
  ## Create the statusLine config in Claude Code's expected format
  ## Passes --config-dir pointing to .gsd/ directory
  ## Both paths are quoted to handle spaces in paths
  result = %*{
    "type": "command",
    "command": "\"" & gsdBinaryPath & "\" statusline --config-dir \"" & gsdDir & "\" #gsd"
  }

proc writeVersionFile(gsdDir: string): bool =
  ## Write VERSION file to .gsd/ directory
  let versionPath = gsdDir / VersionFileName
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

proc findGsdBinary(): tuple[path: string, notFound: bool] =
  ## Find the gsd binary path (for settings.json commands)
  ## Returns (path, notFound) where notFound=true means binary wasn't found
  ## in standard locations and we're falling back to bare "gsd" (assumes PATH)

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

proc rewritePathReferences*(content, installType, gsdDir: string): string =
  ## Rewrite @~/.gsd/ references based on install type
  ## For local installs, use relative paths
  ## For custom installs, use the actual custom gsd path
  ## For global installs, no rewriting needed (source form is correct)
  if installType == "local":
    result = content.replace("@~/.gsd/", "@.gsd/")
    result = result.replace("~/.gsd/", ".gsd/")
  elif installType == "custom" and gsdDir.len > 0:
    result = content.replace("@~/.gsd/", "@" & gsdDir & "/")
    result = result.replace("~/.gsd/", gsdDir & "/")
  else:
    result = content  # No rewriting for global

proc copyAndRewriteDir(src, dest, installType, gsdDir: string, verbose: bool): bool =
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
          let rewritten = rewritePathReferences(content, installType, gsdDir)
          writeFile(destPath, rewritten)
          log("Processed: " & extractFilename(path), verbose)
        else:
          copyFile(path, destPath)
          log("Copied: " & extractFilename(path), verbose)
      of pcDir:
        if not copyAndRewriteDir(path, destPath, installType, gsdDir, verbose):
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

proc copyResourceDirWithRewrite(src, dest, installType, gsdDir: string, verbose: bool): bool =
  ## Safely copy a directory using atomic rename, with path rewriting
  let tempDest = dest & ".tmp." & $epochTime().int

  # Copy to temp location with rewriting
  if not copyAndRewriteDir(src, tempDest, installType, gsdDir, verbose):
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

proc installSharedResources(sourceGsdDir, destGsdDir, installTypeStr, gsdDir: string, verbose: bool): bool =
  ## Install shared resources from gsd/ source to .gsd/ destination
  ## Copies each subdirectory atomically without replacing the .gsd/ root,
  ## so gsd-config.json, VERSION, and cache/ are preserved.
  if not dirExists(sourceGsdDir):
    return true

  if not dirExists(destGsdDir):
    try:
      createDir(destGsdDir)
    except OSError as e:
      stderr.writeLine "Error creating .gsd/ directory: ", e.msg
      return false

  for kind, path in walkDir(sourceGsdDir):
    let name = extractFilename(path)
    let dest = destGsdDir / name
    case kind
    of pcDir:
      if not copyResourceDirWithRewrite(path, dest, installTypeStr, gsdDir, verbose):
        return false
    of pcFile:
      try:
        if path.endsWith(".md"):
          let content = readFile(path)
          let rewritten = rewritePathReferences(content, installTypeStr, gsdDir)
          writeFile(dest, rewritten)
        else:
          copyFile(path, dest)
        log("Installed: " & name, verbose)
      except IOError as e:
        stderr.writeLine "Error copying file: ", e.msg
        return false
    else:
      discard
  return true

proc installGsdAgents(sourceDir, destDir, installType, gsdDir: string, verbose: bool): bool =
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
        let rewritten = rewritePathReferences(content, installType, gsdDir)
        writeFile(destPath, rewritten)
        log("Installed: " & agentFile, verbose)
      except OSError as e:
        stderr.writeLine "Error copying agent file: ", e.msg
        return false
      except IOError as e:
        stderr.writeLine "Error processing agent file: ", e.msg
        return false

  return true

proc generateAgentsMd*(agentFiles: seq[string], destPath: string, installType, gsdDir: string): bool =
  ## Generate a single AGENTS.md by concatenating individual agent files
  ## Used for Codex CLI which expects agents in a single file
  try:
    var content = "# GSD Agents\n\n"
    content.add "This file is auto-generated by GSD installer. Do not edit manually.\n\n"

    # Sort files for consistent ordering
    var sortedFiles = agentFiles
    sortedFiles.sort()

    for agentPath in sortedFiles:
      if fileExists(agentPath):
        let filename = extractFilename(agentPath)
        let agentContent = readFile(agentPath)
        let rewritten = rewritePathReferences(agentContent, installType, gsdDir)
        content.add "---\n\n"
        content.add "## " & filename.replace(".md", "") & "\n\n"
        content.add rewritten
        content.add "\n\n"

    writeFile(destPath, content)
    return true
  except IOError as e:
    stderr.writeLine "Error generating AGENTS.md: ", e.msg
    return false

proc installCodexPrompts(sourceDir, destDir, installType, gsdDir: string, verbose: bool): bool =
  ## Install commands as Codex prompts (gsd-*.md files)
  ## Codex uses ~/.codex/prompts/ for custom commands
  if not dirExists(destDir):
    try:
      createDir(destDir)
    except OSError as e:
      stderr.writeLine "Error creating prompts directory: ", e.msg
      return false

  # Copy each command file, renaming to gsd-*.md format
  let commandsSource = sourceDir / "commands" / "gsd"
  if not dirExists(commandsSource):
    return true  # No commands to install

  for kind, path in walkDir(commandsSource):
    if kind == pcFile and path.endsWith(".md"):
      let filename = extractFilename(path)
      # Rename from e.g., "help.md" to "gsd-help.md"
      let destFilename = "gsd-" & filename
      let destPath = destDir / destFilename
      try:
        let content = readFile(path)
        let rewritten = rewritePathReferences(content, installType, gsdDir)
        writeFile(destPath, rewritten)
        log("Installed prompt: " & destFilename, verbose)
      except IOError as e:
        stderr.writeLine "Error installing prompt: ", e.msg
        return false

  return true

proc installCodex*(sourceDir: string, opts: InstallOptions): InstallResult =
  ## Installation procedure for Codex CLI (two-phase)
  ## Phase A: Shared resources → .gsd/
  ## Phase B: Tool-specific files → .codex/

  # Resolve gsdDir (.gsd/ directory)
  let gsdDir = if opts.configDir.len > 0:
    expandPath(opts.configDir)
  elif opts.installType == itLocal:
    platform.getLocalGsdDir()
  else:
    platform.getGlobalGsdDir()

  # Resolve toolDir (.codex/ directory)
  let toolDir = if opts.installType == itLocal:
    platform.getLocalConfigDir(opts.platform)
  else:
    platform.getGlobalConfigDir(opts.platform)

  result.configDir = gsdDir

  # Create directories if needed
  for dir in [gsdDir, toolDir]:
    if not dirExists(dir):
      try:
        createDir(dir)
      except OSError as e:
        result.success = false
        result.message = "Failed to create directory: " & e.msg
        return

  echo "Installing GSD to ", gsdDir, " + ", toolDir, " (Codex CLI)..."

  # Determine install type for path rewriting
  let installTypeStr = if opts.configDir.len > 0:
    "custom"
  elif opts.installType == itLocal:
    "local"
  else:
    "global"

  # Phase A: Shared resources to .gsd/
  let gsdSource = sourceDir / "gsd"
  if dirExists(gsdSource):
    if not installSharedResources(gsdSource, gsdDir, installTypeStr, gsdDir, opts.verbose):
      result.success = false
      result.message = "Failed to copy gsd resources"
      return
    echo "  Installed shared resources to ", gsdDir

  # Write VERSION to .gsd/
  if not writeVersionFile(gsdDir):
    result.success = false
    result.message = "Failed to write VERSION file"
    return

  # Create cache in .gsd/
  let cacheDir = getGsdCacheDir(gsdDir)
  if not dirExists(cacheDir):
    try:
      createDir(cacheDir)
    except OSError:
      discard  # Non-fatal

  # Phase B: Tool-specific files to .codex/

  # Install commands as prompts (gsd-*.md)
  let promptsDir = toolDir / CodexPromptsDir
  if not installCodexPrompts(sourceDir, promptsDir, installTypeStr, gsdDir, opts.verbose):
    result.success = false
    result.message = "Failed to install prompts"
    return
  echo "  Installed prompts"

  # Generate AGENTS.md from individual agent files
  let agentsSource = sourceDir / "agents"
  if dirExists(agentsSource):
    var agentPaths: seq[string] = @[]
    for agentFile in GsdAgentFiles:
      let agentPath = agentsSource / agentFile
      if fileExists(agentPath):
        agentPaths.add(agentPath)

    let agentsMdPath = toolDir / CodexAgentsMdFile
    if not generateAgentsMd(agentPaths, agentsMdPath, installTypeStr, gsdDir):
      result.success = false
      result.message = "Failed to generate AGENTS.md"
      return
    echo "  Generated AGENTS.md"

  # Update config.toml (using text-based merge to preserve unknown content)
  let configTomlPath = toolDir / CodexConfigFile

  let (gsdBinaryPath, gsdNotFound) = findGsdBinary()

  if gsdNotFound:
    echo "  Warning: gsd binary not found in standard locations."
    echo "           Hooks will use 'gsd' and assume it's in PATH."
    echo "           Consider moving gsd to /usr/local/bin/ or ~/.local/bin/"

  # Merge notify hooks using text-based approach (--config-dir points to .gsd/)
  let gsdNotifyHooks = createGsdNotifyHooks(gsdBinaryPath, gsdDir)
  let existingContent = if fileExists(configTomlPath): readFile(configTomlPath) else: ""
  let newContent = mergeCodexNotifyText(existingContent, gsdNotifyHooks)

  try:
    writeFile(configTomlPath, newContent)
  except IOError as e:
    result.success = false
    result.message = "Failed to write config.toml: " & e.msg
    return
  log("Updated config.toml", opts.verbose)

  # Write gsd-config.json to .gsd/ (update platforms list)
  var gsdConfig: GsdConfig
  let existingCfg = loadConfig(gsdDir)
  if existingCfg.isSome:
    gsdConfig = existingCfg.get()
    if opts.platform notin gsdConfig.platforms:
      gsdConfig.platforms.add(opts.platform)
  else:
    gsdConfig = GsdConfig(
      version: Version,
      installType: opts.installType,
      platforms: @[opts.platform],
      gsdDir: gsdDir,
      installedAt: now().utc.format("yyyy-MM-dd'T'HH:mm:ss'Z'")
    )
  gsdConfig.version = Version
  gsdConfig.gsdDir = gsdDir
  if not saveConfig(gsdConfig, gsdDir):
    result.success = false
    result.message = "Failed to write gsd-config.json"
    return

  result.success = true
  result.message = "Installation complete"

proc install*(sourceDir: string, opts: InstallOptions): InstallResult =
  ## Main installation procedure - two-phase install
  ## Phase A: Shared resources → .gsd/
  ## Phase B: Tool-specific files → .claude/ or .codex/

  # Use Codex-specific installer if Codex platform
  if opts.platform == pCodexCli:
    return installCodex(sourceDir, opts)

  # Claude Code installation

  # Resolve gsdDir (.gsd/ directory)
  let gsdDir = if opts.configDir.len > 0:
    expandPath(opts.configDir)
  elif opts.installType == itLocal:
    platform.getLocalGsdDir()
  else:
    platform.getGlobalGsdDir()

  # Resolve toolDir (.claude/ directory)
  let toolDir = if opts.installType == itLocal:
    platform.getLocalConfigDir(opts.platform)
  else:
    platform.getGlobalConfigDir(opts.platform)

  result.configDir = gsdDir

  # Create directories if needed
  for dir in [gsdDir, toolDir]:
    if not dirExists(dir):
      try:
        createDir(dir)
      except OSError as e:
        result.success = false
        result.message = "Failed to create directory: " & e.msg
        return

  echo "Installing GSD to ", gsdDir, " + ", toolDir, "..."

  # Determine install type for path rewriting
  let installTypeStr = if opts.configDir.len > 0:
    "custom"
  elif opts.installType == itLocal:
    "local"
  else:
    "global"

  # Phase A: Shared resources to .gsd/

  # Copy gsd/ resources (templates, workflows, references)
  let gsdSource = sourceDir / "gsd"
  if dirExists(gsdSource):
    if not installSharedResources(gsdSource, gsdDir, installTypeStr, gsdDir, opts.verbose):
      result.success = false
      result.message = "Failed to copy gsd resources"
      return
    echo "  Installed shared resources to ", gsdDir

  # Write VERSION to .gsd/
  if not writeVersionFile(gsdDir):
    result.success = false
    result.message = "Failed to write VERSION file"
    return

  # Create cache in .gsd/
  let cacheDir = getGsdCacheDir(gsdDir)
  if not dirExists(cacheDir):
    try:
      createDir(cacheDir)
    except OSError:
      discard  # Non-fatal

  # Phase B: Tool-specific files to .claude/

  # Copy commands/gsd/ (with path rewriting)
  let commandsDir = toolDir / "commands" / "gsd"
  let commandsSource = sourceDir / "commands" / "gsd"
  if dirExists(commandsSource):
    createDir(toolDir / "commands")
    if not copyResourceDirWithRewrite(commandsSource, commandsDir, installTypeStr, gsdDir, opts.verbose):
      result.success = false
      result.message = "Failed to copy commands"
      return
    echo "  Installed commands/gsd"

  # Install agents (merge, don't replace - preserves user's custom agents)
  let agentsSource = sourceDir / "agents"
  let agentsDir = toolDir / "agents"
  if dirExists(agentsSource):
    if not installGsdAgents(agentsSource, agentsDir, installTypeStr, gsdDir, opts.verbose):
      result.success = false
      result.message = "Failed to install agents"
      return
    echo "  Installed agents"

  # Update settings.json (in tool dir)
  let settingsPath = toolDir / "settings.json"
  var settings = loadSettings(settingsPath)

  let (gsdBinaryPath, gsdNotFound) = findGsdBinary()

  if gsdNotFound:
    echo "  Warning: gsd binary not found in standard locations."
    echo "           Hooks will use 'gsd' and assume it's in PATH."
    echo "           Consider moving gsd to /usr/local/bin/ or ~/.local/bin/"

  # Merge hooks (--config-dir points to .gsd/)
  let gsdHooks = createGsdHooks(gsdBinaryPath, gsdDir)
  settings["hooks"] = mergeHooks(settings, gsdHooks)

  # Merge statusLine (note: camelCase is the correct Claude Code format)
  let statuslineConfig = createStatuslineConfig(gsdBinaryPath, gsdDir)
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

  # Cleanup old files from tool dir
  cleanupOldFiles(toolDir, opts.verbose)

  # Write gsd-config.json to .gsd/ (update platforms list)
  var gsdConfig: GsdConfig
  let existingCfg = loadConfig(gsdDir)
  if existingCfg.isSome:
    gsdConfig = existingCfg.get()
    if opts.platform notin gsdConfig.platforms:
      gsdConfig.platforms.add(opts.platform)
  else:
    gsdConfig = GsdConfig(
      version: Version,
      installType: opts.installType,
      platforms: @[opts.platform],
      gsdDir: gsdDir,
      installedAt: now().utc.format("yyyy-MM-dd'T'HH:mm:ss'Z'")
    )
  gsdConfig.version = Version
  gsdConfig.gsdDir = gsdDir
  if not saveConfig(gsdConfig, gsdDir):
    result.success = false
    result.message = "Failed to write gsd-config.json"
    return

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

proc removeCodexGsdPrompts(promptsDir: string, verbose: bool) =
  ## Remove GSD prompt files from Codex prompts directory
  if not dirExists(promptsDir):
    return

  for kind, path in walkDir(promptsDir):
    if kind == pcFile:
      let filename = extractFilename(path)
      if filename.startsWith("gsd-") and filename.endsWith(".md"):
        try:
          removeFile(path)
          log("Removed: " & path, verbose)
        except OSError:
          discard

proc uninstallCodex*(gsdDir: string, verbose: bool): bool =
  ## Remove GSD Codex CLI files from tool dir, update .gsd/ config
  ## gsdDir is the .gsd/ directory; tool dir is derived from platform

  # Derive tool dir (use resolved paths to handle symlinks like /var → /private/var)
  let toolDir = if resolvedPath(gsdDir) == resolvedPath(platform.getLocalGsdDir()):
    platform.getLocalConfigDir(pCodexCli)
  else:
    platform.getGlobalConfigDir(pCodexCli)

  echo "Uninstalling GSD from ", toolDir, " (Codex CLI)..."

  # Remove GSD prompt files (gsd-*.md)
  let promptsDir = toolDir / CodexPromptsDir
  removeCodexGsdPrompts(promptsDir, verbose)

  # Remove AGENTS.md
  let agentsMdFile = toolDir / CodexAgentsMdFile
  if fileExists(agentsMdFile):
    try:
      removeFile(agentsMdFile)
      log("Removed: " & agentsMdFile, verbose)
    except OSError:
      discard

  # Update config.toml to remove GSD hooks
  let configTomlPath = toolDir / CodexConfigFile
  if fileExists(configTomlPath):
    try:
      let existingContent = readFile(configTomlPath)
      let newContent = mergeCodexNotifyText(existingContent, @[])
      writeFile(configTomlPath, newContent)
      log("Updated config.toml", verbose)
    except IOError:
      stderr.writeLine "Warning: Could not update config.toml"

  # Update .gsd/gsd-config.json — remove platform from list
  let cfg = loadConfig(gsdDir)
  if cfg.isSome:
    var config = cfg.get()
    config.platforms = config.platforms.filterIt(it != pCodexCli)
    if config.platforms.len == 0:
      # No platforms left — remove .gsd/ entirely
      try:
        removeDir(gsdDir)
        log("Removed: " & gsdDir, verbose)
      except OSError as e:
        stderr.writeLine "Warning: Could not remove ", gsdDir, ": ", e.msg
    else:
      discard saveConfig(config, gsdDir)

  echo "GSD (Codex CLI) uninstalled."
  return true

proc uninstall*(gsdDir: string, verbose: bool, p: Platform = pClaudeCode): bool =
  ## Remove GSD from tool directory and update .gsd/ config
  ## gsdDir is the .gsd/ directory; tool dir is derived from platform

  if p == pCodexCli:
    return uninstallCodex(gsdDir, verbose)

  # Derive tool dir (use resolved paths to handle symlinks like /var → /private/var)
  let toolDir = if resolvedPath(gsdDir) == resolvedPath(platform.getLocalGsdDir()):
    platform.getLocalConfigDir(p)
  else:
    platform.getGlobalConfigDir(p)

  echo "Uninstalling GSD from ", toolDir, "..."

  # Remove commands/gsd/ from tool dir
  let commandsDir = toolDir / "commands" / "gsd"
  if dirExists(commandsDir):
    try:
      removeDir(commandsDir)
      log("Removed: " & commandsDir, verbose)
    except OSError as e:
      stderr.writeLine "Warning: Could not remove ", commandsDir, ": ", e.msg

  # Remove only GSD agent files, preserving user's custom agents
  let agentsDir = toolDir / "agents"
  removeGsdAgents(agentsDir, verbose)

  # Update settings.json to remove GSD hooks
  let settingsPath = toolDir / "settings.json"
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

  # Update .gsd/gsd-config.json — remove platform from list
  let cfg = loadConfig(gsdDir)
  if cfg.isSome:
    var config = cfg.get()
    config.platforms = config.platforms.filterIt(it != p)
    if config.platforms.len == 0:
      # No platforms left — remove .gsd/ entirely
      try:
        removeDir(gsdDir)
        log("Removed: " & gsdDir, verbose)
      except OSError as e:
        stderr.writeLine "Warning: Could not remove ", gsdDir, ": ", e.msg
    else:
      discard saveConfig(config, gsdDir)

  echo "GSD uninstalled."
  return true

proc detectLegacyInstall*(): seq[InstalledConfig] =
  ## Detect v0.2 legacy installs (gsd-config.json in tool dirs, not .gsd/)
  result = @[]
  for p in [pClaudeCode, pCodexCli]:
    for dir in [platform.getLocalConfigDir(p), platform.getGlobalConfigDir(p)]:
      if fileExists(dir / ConfigFileName):
        # It's a legacy install only if it's a tool dir, not a .gsd/ dir
        if dir != platform.getLocalGsdDir() and dir != platform.getGlobalGsdDir():
          result.add(InstalledConfig(platform: p, dir: dir))

proc migrateLegacyInstall*(legacyConfigs: seq[InstalledConfig], verbose: bool): bool =
  ## Migrate from v0.2 (tool-dir-based) to v0.3 (.gsd/-based) layout
  ## Creates .gsd/, copies shared resources, cleans up old files.
  ## After migration, caller should run normal install to update tool-specific files.
  if legacyConfigs.len == 0:
    return true

  echo "Detected legacy v0.2 installation. Migrating to v0.3..."

  # Determine target gsdDir based on install type
  let firstCfg = loadConfig(legacyConfigs[0].dir)
  let isLocal = if firstCfg.isSome:
    firstCfg.get().installType == itLocal
  else:
    legacyConfigs[0].dir == platform.getLocalConfigDir(legacyConfigs[0].platform)

  let gsdDir = if isLocal: platform.getLocalGsdDir() else: platform.getGlobalGsdDir()

  # Create .gsd/ directory
  if not dirExists(gsdDir):
    try:
      createDir(gsdDir)
    except OSError as e:
      stderr.writeLine "Error creating .gsd/ directory: ", e.msg
      return false

  # Copy shared resources from first legacy dir's gsd/ subdirectory
  let legacyGsdDir = legacyConfigs[0].dir / "gsd"
  if dirExists(legacyGsdDir):
    if not copyDirRecursive(legacyGsdDir, gsdDir, verbose):
      stderr.writeLine "Error copying shared resources."
      return false
    echo "  Migrated shared resources to ", gsdDir

  # Move cache from first legacy dir
  let legacyCacheDir = legacyConfigs[0].dir / "cache"
  let newCacheDir = gsdDir / "cache"
  if dirExists(legacyCacheDir) and not dirExists(newCacheDir):
    try:
      moveDir(legacyCacheDir, newCacheDir)
      echo "  Migrated cache to ", newCacheDir
    except OSError:
      discard copyDirRecursive(legacyCacheDir, newCacheDir, verbose)

  if not dirExists(newCacheDir):
    try:
      createDir(newCacheDir)
    except OSError:
      discard

  # Write VERSION to .gsd/
  discard writeVersionFile(gsdDir)

  # Collect all platforms
  var platforms: seq[Platform] = @[]
  for legacy in legacyConfigs:
    if legacy.platform notin platforms:
      platforms.add(legacy.platform)

  # Write new gsd-config.json
  let installType = if firstCfg.isSome: firstCfg.get().installType else: itGlobal
  let gsdConfig = GsdConfig(
    version: Version,
    installType: installType,
    platforms: platforms,
    gsdDir: gsdDir,
    installedAt: now().utc.format("yyyy-MM-dd'T'HH:mm:ss'Z'")
  )
  discard saveConfig(gsdConfig, gsdDir)

  # Clean up old files from legacy tool dirs
  for legacy in legacyConfigs:
    let oldGsdDir = legacy.dir / "gsd"
    let oldCacheDir = legacy.dir / "cache"
    let oldConfigFile = legacy.dir / ConfigFileName

    if dirExists(oldGsdDir):
      try:
        removeDir(oldGsdDir)
        log("Removed legacy: " & oldGsdDir, verbose)
      except OSError:
        discard

    if dirExists(oldCacheDir):
      try:
        removeDir(oldCacheDir)
        log("Removed legacy: " & oldCacheDir, verbose)
      except OSError:
        discard

    if fileExists(oldConfigFile):
      try:
        removeFile(oldConfigFile)
        log("Removed legacy: " & oldConfigFile, verbose)
      except OSError:
        discard

  echo "  Migration complete. Legacy files cleaned up."
  return true
