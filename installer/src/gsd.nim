## GSD - Get Stuff Done
## CLI entry point for installer and hooks

import std/[os, strutils, parseopt, options, json, terminal, sequtils]
import config, install, statusline, update, platform

proc isInteractive(): bool =
  ## Check if stdin is a TTY (interactive terminal)
  try:
    return isatty(stdin)
  except CatchableError:
    return false

proc promptPlatformChoice(): PlatformChoice =
  ## Prompt user to select platform(s) for installation
  echo ""
  echo "Select platform to install GSD:"
  echo "  1) Claude Code"
  echo "  2) Codex CLI"
  echo "  3) Both"
  echo ""
  echo "Shared resources install to ~/.gsd/"
  echo ""
  stdout.write "Enter choice [1-3]: "
  stdout.flushFile()

  let input = stdin.readLine().strip()

  case input
  of "1", "claude":
    return pcClaude
  of "2", "codex":
    return pcCodex
  of "3", "both", "all":
    return pcBoth
  else:
    echo "Invalid choice. Defaulting to Claude Code."
    return pcClaude

proc promptUninstallChoice(installed: seq[InstalledConfig]): seq[InstalledConfig] =
  ## Prompt user to select platform(s) for uninstallation
  if installed.len == 0:
    return @[]

  if installed.len == 1:
    return installed

  echo ""
  echo "GSD is installed for multiple platforms. Select which to uninstall:"
  var idx = 1
  for install in installed:
    echo "  ", idx, ") ", $install.platform, " (", install.dir, ")"
    idx.inc
  echo "  ", idx, ") All"
  echo ""
  stdout.write "Enter choice [1-", idx, "]: "
  stdout.flushFile()

  let input = stdin.readLine().strip()

  try:
    let choice = parseInt(input)
    if choice >= 1 and choice <= installed.len:
      return @[installed[choice - 1]]
    elif choice == idx:
      return installed
  except ValueError:
    discard

  echo "Invalid choice. Aborting."
  quit(1)

const
  HelpText = """
GSD - Get Stuff Done
A meta-prompting system for Claude Code and Codex CLI

Usage: gsd <command> [options]

Commands:
  install       Install GSD to config directory
  uninstall     Remove GSD from config directory
  update        Update all installed platforms
  doctor        Validate installation health
  check-update  Check for available updates (silent)
  statusline    Output formatted statusline (called by hook)

Install options:
  -g, --global              Install to ~/.<platform> (default)
  -l, --local               Install to ./.<platform>
  -c, --config-dir <path>   Custom config directory
  -p, --platform <name>     Target: claude, codex, or both
  --dry-run                 Preview changes without writing files
  --force-statusline        Replace existing statusline (Claude only)
  --verbose                 Verbose output

Other options:
  --dry-run                 Also supported by uninstall and update
  -h, --help                Show this help
  -v, --version             Show version

Examples:
  gsd install                       Interactive platform selection
  gsd install --dry-run             Preview installation changes
  gsd install --platform=both       Install for both platforms
  gsd install --platform=codex      Install for Codex CLI only
  gsd update                        Update all installed platforms
  gsd doctor                        Check all installations
"""

proc showHelp() =
  echo HelpText
  quit(0)

proc showVersion() =
  echo "gsd ", Version
  quit(0)

proc findSourceDir(): string =
  ## Find the source directory containing gsd/, commands/, agents/
  ## This is where the installer binary is run from

  # Check current directory
  if dirExists("gsd") and dirExists("commands"):
    return getCurrentDir()

  # Check directory containing the binary
  let binDir = parentDir(getAppFilename())
  if dirExists(binDir / "gsd") and dirExists(binDir / "commands"):
    return binDir

  # Check parent of bin directory (common release structure)
  let parentOfBin = parentDir(binDir)
  if dirExists(parentOfBin / "gsd") and dirExists(parentOfBin / "commands"):
    return parentOfBin

  # Fallback to current directory
  return getCurrentDir()

proc cmdInstall(args: seq[string]) =
  var baseOpts = InstallOptions(
    installType: itGlobal,
    platform: pClaudeCode,
    forceStatusline: false,
    verbose: false,
    dryRun: false
  )

  var platformExplicit = false
  var platformChoice = pcClaude

  var p = initOptParser(
    args,
    shortNoVal = {'g', 'l', 'h'},
    longNoVal = @["global", "local", "force-statusline", "verbose", "dry-run", "help"]
  )
  while true:
    p.next()
    case p.kind
    of cmdEnd: break
    of cmdShortOption, cmdLongOption:
      case p.key
      of "g", "global":
        baseOpts.installType = itGlobal
      of "l", "local":
        baseOpts.installType = itLocal
      of "c", "config-dir":
        baseOpts.configDir = p.val
        baseOpts.installType = itCustom
      of "p", "platform":
        try:
          platformChoice = parsePlatformChoice(p.val)
          platformExplicit = true
        except ValueError as e:
          stderr.writeLine "Error: ", e.msg
          quit(1)
      of "force-statusline":
        baseOpts.forceStatusline = true
      of "verbose":
        baseOpts.verbose = true
      of "dry-run":
        baseOpts.dryRun = true
      of "h", "help":
        echo "Usage: gsd install [options]"
        echo ""
        echo "Options:"
        echo "  -g, --global              Install to ~/.<platform> (default)"
        echo "  -l, --local               Install to ./.<platform>"
        echo "  -c, --config-dir <path>   Custom config directory"
        echo "  -p, --platform <name>     Target: claude, codex, or both"
        echo "  --dry-run                 Preview changes without writing files"
        echo "  --force-statusline        Replace existing statusline (Claude only)"
        echo "  --verbose                 Verbose output"
        quit(0)
      else:
        stderr.writeLine "Unknown option: ", p.key
        quit(1)
    of cmdArgument:
      discard

  # Prompt for platform if interactive and not explicitly specified
  if not platformExplicit:
    if isInteractive():
      platformChoice = promptPlatformChoice()
    else:
      # Non-interactive: default to Claude Code
      platformChoice = pcClaude

  if baseOpts.installType == itCustom and platformChoice == pcBoth:
    stderr.writeLine "Error: --config-dir cannot be used with --platform=both."
    stderr.writeLine "Install each platform separately with its own --config-dir."
    quit(1)

  let sourceDir = findSourceDir()

  # Verify source directory has required content
  if not dirExists(sourceDir / "gsd") or not dirExists(sourceDir / "commands"):
    stderr.writeLine "Error: Cannot find GSD source files."
    stderr.writeLine "Make sure you're running the installer from the GSD directory,"
    stderr.writeLine "or that the binary is located alongside the gsd/ and commands/ directories."
    quit(1)

  # Install to selected platform(s)
  let platforms = platformChoiceToSeq(platformChoice)
  var allSuccess = true
  var installedPlatforms: seq[Platform] = @[]

  for targetPlatform in platforms:
    var opts = baseOpts
    opts.platform = targetPlatform

    let result = install(sourceDir, opts)

    if result.success:
      installedPlatforms.add(targetPlatform)
    else:
      stderr.writeLine "Error installing for ", $targetPlatform, ": ", result.message
      allSuccess = false

  # Show summary
  if installedPlatforms.len > 0:
    echo ""
    if baseOpts.dryRun:
      echo "Dry run complete. No files were modified."
    else:
      for p in installedPlatforms:
        case p
        of pClaudeCode:
          echo "Claude Code: Use /gsd:help to get started."
        of pCodexCli:
          echo "Codex CLI: Use /prompts:gsd-help to get started."

  if not allSuccess:
    quit(1)

proc cmdUninstall(args: seq[string]) =
  var configDir = ""
  var verbose = false
  var dryRun = false
  var platformChoice = pcClaude
  var platformExplicit = false
  var useGlobal = false
  var useLocal = false
  var uninstallAll = false

  # First pass: parse all flags
  var p = initOptParser(
    args,
    shortNoVal = {'g', 'l', 'h'},
    longNoVal = @["global", "local", "all", "verbose", "dry-run", "help"]
  )
  while true:
    p.next()
    case p.kind
    of cmdEnd: break
    of cmdShortOption, cmdLongOption:
      case p.key
      of "g", "global":
        useGlobal = true
        useLocal = false
      of "l", "local":
        useLocal = true
        useGlobal = false
      of "c", "config-dir":
        configDir = p.val
        useGlobal = false
        useLocal = false
      of "p", "platform":
        try:
          platformChoice = parsePlatformChoice(p.val)
          platformExplicit = true
        except ValueError as e:
          stderr.writeLine "Error: ", e.msg
          quit(1)
      of "all":
        uninstallAll = true
      of "verbose":
        verbose = true
      of "dry-run":
        dryRun = true
      of "h", "help":
        echo "Usage: gsd uninstall [options]"
        echo ""
        echo "Options:"
        echo "  -g, --global              Target global install (~/.gsd)"
        echo "  -l, --local               Target local install (./.gsd)"
        echo "  -c, --config-dir <path>   Target specific .gsd directory"
        echo "  -p, --platform <name>     Target: claude, codex, or both"
        echo "  --all                     Uninstall all detected installations"
        echo "  --dry-run                 Preview changes without writing files"
        echo "  --verbose                 Verbose output"
        quit(0)
      else:
        discard
    of cmdArgument:
      discard

  # Normalize explicit config dir if provided
  if configDir.len > 0:
    configDir = expandPath(configDir)
    if not dirExists(configDir):
      stderr.writeLine "Error: Config directory not found: ", configDir
      quit(1)

    let cfg = loadConfig(configDir)
    if cfg.isNone:
      stderr.writeLine "Error: Unable to read ", ConfigFileName, " from ", configDir, "."
      stderr.writeLine "Refusing to uninstall with --config-dir without a valid config file."
      quit(1)

    var allSuccess = true
    if platformExplicit:
      # Uninstall specific platform(s) from this config dir
      let platforms = platformChoiceToSeq(platformChoice)
      for targetPlatform in platforms:
        if targetPlatform notin cfg.get().platforms:
          stderr.writeLine "Error: ", $targetPlatform, " not found in ", ConfigFileName, "."
          allSuccess = false
          continue
        if not uninstall(configDir, verbose, targetPlatform, dryRun):
          allSuccess = false
    else:
      # Uninstall all platforms listed in config
      for p in cfg.get().platforms:
        if not uninstall(configDir, verbose, p, dryRun):
          allSuccess = false

    if not allSuccess:
      quit(1)
    return

  # Handle --all flag
  if uninstallAll:
    let installed = listInstalledConfigs()
    if installed.len == 0:
      stderr.writeLine "Error: No GSD installation found."
      quit(1)

    for install in installed:
      discard uninstall(install.dir, verbose, install.platform, dryRun)
    return

  # Handle explicit platform choice (may include "both")
  if platformExplicit:
    let platforms = platformChoiceToSeq(platformChoice)
    let installed = listInstalledConfigs()
    var targets: seq[InstalledConfig] = @[]

    if useGlobal or useLocal:
      # v0.3: .gsd/ dirs, not tool dirs
      let gsdDir = if useGlobal:
        platform.getGlobalGsdDir()
      else:
        platform.getLocalGsdDir()

      if fileExists(gsdDir / ConfigFileName):
        let cfg = loadConfig(gsdDir)
        if cfg.isSome:
          for plat in platforms:
            if plat in cfg.get().platforms:
              targets.add(InstalledConfig(platform: plat, dir: gsdDir))
            else:
              stderr.writeLine "Error: No GSD installation found for ", $plat, "."
        else:
          stderr.writeLine "Error: Could not read config at ", gsdDir
      else:
        stderr.writeLine "Error: No GSD installation found at ", gsdDir
    else:
      for install in installed:
        if install.platform in platforms:
          targets.add(install)

    if targets.len == 0:
      quit(1)

    for target in targets:
      discard uninstall(target.dir, verbose, target.platform, dryRun)
    return

  # No explicit options - check what's installed
  let installed = listInstalledConfigs()

  if installed.len == 0:
    stderr.writeLine "Error: No GSD installation found."
    quit(1)

  # If only one platform installed, uninstall it
  if installed.len == 1:
    let install = installed[0]
    discard uninstall(install.dir, verbose, install.platform, dryRun)
    return

  # Multiple platforms installed - prompt if interactive
  if isInteractive():
    let toUninstall = promptUninstallChoice(installed)
    for install in toUninstall:
      discard uninstall(install.dir, verbose, install.platform, dryRun)
  else:
    # Non-interactive with multiple platforms - require explicit choice
    stderr.writeLine "Error: Multiple GSD installations found. Specify --platform or --all."
    quit(1)

proc runDoctorForPlatform(gsdDir: string, targetPlatform: Platform): tuple[issues: seq[string],
    warnings: seq[string]] =
  ## Run health check for a platform installation
  ## Checks both .gsd/ (shared) and tool dir (platform-specific)
  var issues: seq[string] = @[]
  var warnings: seq[string] = @[]

  # Derive tool dir
  let toolDir = if gsdDir == platform.getLocalGsdDir():
    platform.getLocalConfigDir(targetPlatform)
  else:
    platform.getGlobalConfigDir(targetPlatform)

  # Load config from .gsd/
  let cfg = loadConfig(gsdDir)

  # Check .gsd/gsd-config.json
  let configPath = gsdDir / ConfigFileName
  if fileExists(configPath):
    echo "[OK] gsd-config.json exists"
    if cfg.isNone:
      issues.add("gsd-config.json is corrupted")
    else:
      echo "[OK] Platforms: ", cfg.get().platforms.mapIt($it).join(", ")
  else:
    issues.add("gsd-config.json missing")

  # Check .gsd/VERSION
  let versionPath = gsdDir / VersionFileName
  if fileExists(versionPath):
    let version = readFile(versionPath).strip()
    echo "[OK] VERSION: ", version
  else:
    issues.add("VERSION file missing")

  # Check shared resources directly in .gsd/
  for subdir in ["templates", "workflows", "references"]:
    if dirExists(gsdDir / subdir):
      echo "[OK] ", subdir, "/ exists"
    else:
      warnings.add(subdir & "/ directory missing in .gsd/")

  # Platform-specific checks (in tool dir)
  echo ""
  echo "Tool directory: ", toolDir

  case targetPlatform
  of pClaudeCode:
    # Check commands/gsd/
    let commandsDir = toolDir / "commands" / "gsd"
    if dirExists(commandsDir):
      var cmdCount = 0
      for _ in walkDir(commandsDir):
        cmdCount.inc
      echo "[OK] commands/gsd/ exists (", cmdCount, " files)"
    else:
      issues.add("commands/gsd/ directory missing in " & toolDir)

    # Check agents/
    let agentsDir = toolDir / "agents"
    if dirExists(agentsDir):
      var agentCount = 0
      for _ in walkDir(agentsDir):
        agentCount.inc
      if agentCount > 0:
        echo "[OK] agents/ exists (", agentCount, " files)"
      else:
        warnings.add("agents/ directory is empty")
    else:
      warnings.add("agents/ directory missing")

  of pCodexCli:
    # Check prompts/
    let promptsDir = toolDir / CodexPromptsDir
    if dirExists(promptsDir):
      var promptCount = 0
      for kind, path in walkDir(promptsDir):
        if kind == pcFile and extractFilename(path).startsWith("gsd-"):
          promptCount.inc
      echo "[OK] prompts/ exists (", promptCount, " GSD prompts)"
    else:
      issues.add("prompts/ directory missing in " & toolDir)

    # Check AGENTS.md
    let agentsMdPath = toolDir / CodexAgentsMdFile
    if fileExists(agentsMdPath):
      echo "[OK] AGENTS.md exists"
    else:
      warnings.add("AGENTS.md missing")

  # Platform-specific config file checks (in tool dir)
  case targetPlatform
  of pClaudeCode:
    # Check settings.json
    let settingsPath = toolDir / "settings.json"
    if fileExists(settingsPath):
      echo "[OK] settings.json exists"

      try:
        let settings = parseJson(readFile(settingsPath))

        # Check hooks (new object format: hooks.SessionStart[].hooks[].command)
        if settings.hasKey("hooks"):
          var hasGsdHook = false
          if settings["hooks"].kind == JObject:
            for eventName, eventHooks in settings["hooks"].pairs:
              if eventHooks.kind == JArray:
                for hookEntry in eventHooks:
                  if hookEntry.hasKey("hooks") and hookEntry["hooks"].kind == JArray:
                    for h in hookEntry["hooks"]:
                      let cmd = h.getOrDefault("command").getStr("")
                      if cmd.contains("gsd") or cmd.contains("#gsd"):
                        hasGsdHook = true
                        break
          if hasGsdHook:
            echo "[OK] GSD hooks configured"
          else:
            warnings.add("No GSD hooks found in settings.json")
        else:
          warnings.add("No hooks object in settings.json")

        # Check statusLine (camelCase is correct format)
        let hasStatusLine = settings.hasKey("statusLine") or settings.hasKey("statusline")
        if hasStatusLine:
          let statusNode = if settings.hasKey("statusLine"): settings["statusLine"]
                           else: settings["statusline"]
          var cmd = ""
          if statusNode.kind == JString:
            cmd = statusNode.getStr("")
          elif statusNode.kind == JObject and statusNode.hasKey("command"):
            cmd = statusNode["command"].getStr("")
          if cmd.contains("gsd"):
            echo "[OK] GSD statusline configured"
          else:
            warnings.add("Statusline not using GSD (custom statusline)")
      except JsonParsingError:
        issues.add("settings.json is corrupted")
    else:
      warnings.add("settings.json missing (will be created on first use)")

  of pCodexCli:
    # Check config.toml
    let configTomlPath = toolDir / CodexConfigFile
    if fileExists(configTomlPath):
      echo "[OK] config.toml exists"
      let content = readFile(configTomlPath)
      if content.contains("#gsd") or content.contains("gsd "):
        echo "[OK] GSD hooks configured"
      else:
        warnings.add("No GSD hooks found in config.toml")
    else:
      warnings.add("config.toml missing (will be created on first use)")

  return (issues, warnings)

proc cmdDoctor(args: seq[string]) =
  ## Validate installation health
  var configDir = ""
  var targetPlatform = pClaudeCode
  var platformExplicit = false

  var p = initOptParser(
    args,
    shortNoVal = {'h'},
    longNoVal = @["help"]
  )
  while true:
    p.next()
    case p.kind
    of cmdEnd: break
    of cmdShortOption, cmdLongOption:
      case p.key
      of "c", "config-dir":
        configDir = p.val
      of "p", "platform":
        try:
          targetPlatform = parsePlatform(p.val)
          platformExplicit = true
        except ValueError as e:
          stderr.writeLine "Error: ", e.msg
          quit(1)
      of "h", "help":
        echo "Usage: gsd doctor [options]"
        echo ""
        echo "Options:"
        echo "  -c, --config-dir <path>   Check a specific config directory"
        echo "  -p, --platform <name>     Target: claude or codex"
        quit(0)
      else:
        discard
    of cmdArgument:
      discard

  # If specific config-dir provided, check just that
  if configDir.len > 0:
    let resolvedDir = expandPath(configDir)
    let cfg = loadConfig(resolvedDir)

    # Determine which platforms to check
    var platformsToCheck: seq[Platform] = @[]
    if platformExplicit:
      platformsToCheck = @[targetPlatform]
      if cfg.isSome and targetPlatform notin cfg.get().platforms:
        stderr.writeLine "Warning: ", $targetPlatform, " not in gsd-config.json platforms list."
    elif cfg.isSome:
      platformsToCheck = cfg.get().platforms
    else:
      platformsToCheck = @[pClaudeCode]
      echo "Warning: Unable to determine platforms for ", resolvedDir, "; defaulting to claude."

    var totalIssues = 0
    var totalWarnings = 0

    for i, plat in platformsToCheck:
      if i > 0:
        echo ""
        echo "---"
        echo ""
      echo "Checking GSD installation at ", resolvedDir, " (", $plat, ")..."
      echo ""

      let (issues, warnings) = runDoctorForPlatform(resolvedDir, plat)

      echo ""
      if issues.len == 0 and warnings.len == 0:
        echo "Installation is healthy!"
      else:
        if issues.len > 0:
          echo "Issues:"
          for issue in issues:
            echo "  - ", issue
        if warnings.len > 0:
          echo "Warnings:"
          for warning in warnings:
            echo "  - ", warning

      totalIssues += issues.len
      totalWarnings += warnings.len

    if totalIssues > 0:
      echo ""
      echo "Run 'gsd install' to fix issues."
      quit(1)
    return

  # If specific platform provided, check just that
  if platformExplicit:
    let installed = listInstalledConfigs()
    var targets: seq[InstalledConfig] = @[]
    for install in installed:
      if install.platform == targetPlatform:
        targets.add(install)

    if targets.len == 0:
      echo "No GSD installation found for ", $targetPlatform, "."
      echo ""
      echo "Run 'gsd install --platform=", $targetPlatform, "' to install GSD."
      quit(1)

    var totalIssues = 0
    var totalWarnings = 0

    for i, install in targets:
      if i > 0:
        echo ""
        echo "---"
        echo ""

      echo "Checking GSD installation at ", install.dir, " (", $install.platform, ")..."
      echo ""

      let (issues, warnings) = runDoctorForPlatform(install.dir, install.platform)

      echo ""
      if issues.len == 0 and warnings.len == 0:
        echo "Installation is healthy!"
      else:
        if issues.len > 0:
          echo "Issues:"
          for issue in issues:
            echo "  - ", issue
        if warnings.len > 0:
          echo "Warnings:"
          for warning in warnings:
            echo "  - ", warning

      totalIssues += issues.len
      totalWarnings += warnings.len

    if targets.len > 1:
      echo ""
      echo "==="
      echo ""
      if totalIssues == 0 and totalWarnings == 0:
        echo "All ", targets.len, " installations are healthy!"
      else:
        echo "Summary: ", totalIssues, " issue(s), ", totalWarnings, " warning(s) across ",
            targets.len, " installation(s)"

    if totalIssues > 0:
      echo ""
      echo "Run 'gsd install' to fix issues."
      quit(1)
    return

  # No specific platform/dir - check all installed platforms
  let installed = listInstalledConfigs()

  if installed.len == 0:
    echo "No GSD installation found."
    echo ""
    echo "Run 'gsd install' to install GSD."
    quit(1)

  var totalIssues = 0
  var totalWarnings = 0

  for i, install in installed:
    if i > 0:
      echo ""
      echo "---"
      echo ""

    echo "Checking GSD installation at ", install.dir, " (", $install.platform, ")..."
    echo ""

    let (issues, warnings) = runDoctorForPlatform(install.dir, install.platform)

    echo ""
    if issues.len == 0 and warnings.len == 0:
      echo "Installation is healthy!"
    else:
      if issues.len > 0:
        echo "Issues:"
        for issue in issues:
          echo "  - ", issue
      if warnings.len > 0:
        echo "Warnings:"
        for warning in warnings:
          echo "  - ", warning

    totalIssues += issues.len
    totalWarnings += warnings.len

  # Summary for multiple platforms
  if installed.len > 1:
    echo ""
    echo "==="
    echo ""
    if totalIssues == 0 and totalWarnings == 0:
      echo "All ", installed.len, " installations are healthy!"
    else:
      echo "Summary: ", totalIssues, " issue(s), ", totalWarnings, " warning(s) across ",
          installed.len, " installation(s)"

  if totalIssues > 0:
    echo ""
    echo "Run 'gsd install' to fix issues."
    quit(1)

proc cmdCheckUpdate(args: seq[string]) =
  var silent = true
  var configDir = ""

  var p = initOptParser(
    args,
    shortNoVal = {'v', 'h'},
    longNoVal = @["verbose", "help"]
  )
  while true:
    p.next()
    case p.kind
    of cmdEnd: break
    of cmdShortOption, cmdLongOption:
      case p.key
      of "v", "verbose":
        silent = false
      of "c", "config-dir":
        configDir = p.val
      of "h", "help":
        echo "Usage: gsd check-update [options]"
        echo ""
        echo "Options:"
        echo "  -v, --verbose             Show update status"
        echo "  -c, --config-dir <path>   Check a specific config directory"
        quit(0)
      else:
        discard
    of cmdArgument:
      discard

  runCheckUpdate(silent, configDir)

proc cmdStatusline(args: seq[string]) =
  var configDir = ""

  var p = initOptParser(
    args,
    shortNoVal = {'h'},
    longNoVal = @["help"]
  )
  while true:
    p.next()
    case p.kind
    of cmdEnd: break
    of cmdShortOption, cmdLongOption:
      case p.key
      of "c", "config-dir":
        configDir = p.val
      of "h", "help":
        echo "Usage: gsd statusline [options]"
        echo ""
        echo "Options:"
        echo "  -c, --config-dir <path>   Use a specific config directory"
        quit(0)
      else:
        discard
    of cmdArgument:
      discard

  runStatusline(configDir)

proc cmdUpdate(args: seq[string]) =
  ## Update GSD for all installed platforms
  var verbose = false
  var dryRun = false
  var platformChoice: Option[PlatformChoice] = none(PlatformChoice)

  var p = initOptParser(
    args,
    shortNoVal = {'h'},
    longNoVal = @["verbose", "dry-run", "help"]
  )
  while true:
    p.next()
    case p.kind
    of cmdEnd: break
    of cmdShortOption, cmdLongOption:
      case p.key
      of "p", "platform":
        try:
          platformChoice = some(parsePlatformChoice(p.val))
        except ValueError as e:
          stderr.writeLine "Error: ", e.msg
          quit(1)
      of "verbose":
        verbose = true
      of "dry-run":
        dryRun = true
      of "h", "help":
        echo "Usage: gsd update [options]"
        echo ""
        echo "Re-installs GSD for all installed platforms (or specified platform)."
        echo ""
        echo "Options:"
        echo "  -p, --platform <name>     Target: claude, codex, or both"
        echo "  --dry-run                 Preview changes without writing files"
        echo "  --verbose                 Verbose output"
        quit(0)
      else:
        discard
    of cmdArgument:
      discard

  let sourceDir = findSourceDir()

  # Verify source directory has required content
  if not dirExists(sourceDir / "gsd") or not dirExists(sourceDir / "commands"):
    stderr.writeLine "Error: Cannot find GSD source files."
    stderr.writeLine "Make sure you're running the update from the GSD directory,"
    stderr.writeLine "or that the binary is located alongside the gsd/ and commands/ directories."
    quit(1)

  # Detect and migrate legacy v0.2 installs
  let legacyConfigs = detectLegacyInstall()
  if legacyConfigs.len > 0:
    if dryRun:
      echo "[dry-run] Would migrate ", legacyConfigs.len,
          " legacy v0.2 installation(s) to .gsd/ layout before update."
    else:
      if not migrateLegacyInstall(legacyConfigs, verbose):
        stderr.writeLine "Error: Legacy migration failed."
        quit(1)

  # Determine which platforms to update
  let installed = listInstalledConfigs()
  if installed.len == 0:
    echo "No GSD installation found. Run 'gsd install' first."
    quit(1)

  var targets: seq[InstalledConfig] = @[]
  var platforms: seq[Platform] = @[]
  var missingPlatform = false
  if platformChoice.isSome:
    platforms = platformChoiceToSeq(platformChoice.get())
    for install in installed:
      if install.platform in platforms:
        targets.add(install)

    for plat in platforms:
      var found = false
      for install in targets:
        if install.platform == plat:
          found = true
          break
      if not found:
        stderr.writeLine "Error: No GSD installation found for ", $plat, "."
        missingPlatform = true
  else:
    targets = installed

  var allSuccess = true

  for target in targets:
    let cfg = loadConfig(target.dir)
    var opts = InstallOptions(
      installType: if cfg.isSome: cfg.get().installType else: inferInstallType(target.dir),
      platform: target.platform,
      forceStatusline: false,
      verbose: verbose,
      dryRun: dryRun
    )

    # If it was a custom install, preserve the path
    if opts.installType == itCustom:
      if cfg.isSome and cfg.get().gsdDir.len > 0:
        opts.configDir = cfg.get().gsdDir
      else:
        opts.configDir = target.dir

    let result = install(sourceDir, opts)

    if result.success:
      if not dryRun:
        clearUpdateCache(target.dir)
    else:
      stderr.writeLine "Error updating ", $target.platform, ": ", result.message
      allSuccess = false

  if missingPlatform:
    allSuccess = false

  if allSuccess:
    echo ""
    if dryRun:
      echo "Dry run complete. No files were modified."
    else:
      echo "Update complete!"
  else:
    quit(1)

proc main() =
  let args = commandLineParams()

  if args.len == 0:
    showHelp()

  let command = args[0].toLowerAscii()
  let restArgs = if args.len > 1: args[1..^1] else: @[]

  case command
  of "install":
    cmdInstall(restArgs)
  of "uninstall":
    cmdUninstall(restArgs)
  of "update":
    cmdUpdate(restArgs)
  of "doctor":
    cmdDoctor(restArgs)
  of "check-update":
    cmdCheckUpdate(restArgs)
  of "statusline":
    cmdStatusline(restArgs)
  of "-h", "--help", "help":
    showHelp()
  of "-v", "--version", "version":
    showVersion()
  else:
    stderr.writeLine "Unknown command: ", command
    stderr.writeLine "Run 'gsd --help' for usage."
    quit(1)

when isMainModule:
  main()
