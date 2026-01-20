## GSD - Get Stuff Done
## CLI entry point for installer and hooks

import std/[os, strutils, parseopt, options, json]
import config, install, statusline, update

const
  HelpText = """
GSD - Get Stuff Done
A meta-prompting system for Claude Code (Codex CLI planned)

Usage: gsd <command> [options]

Commands:
  install       Install GSD to config directory
  uninstall     Remove GSD from config directory
  doctor        Validate installation health
  check-update  Check for available updates
  statusline    Output formatted statusline (called by hook)

Install options:
  -g, --global              Install to ~/.claude (default)
  -l, --local               Install to ./.claude
  -c, --config-dir <path>   Custom config directory
  --force-statusline        Replace existing statusline
  --verbose                 Verbose output

Other options:
  -h, --help                Show this help
  -v, --version             Show version

Examples:
  gsd install --global      Standard global install
  gsd install --local       Project-only install
  gsd doctor                Check installation health
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
  var opts = InstallOptions(
    installType: itGlobal,
    forceStatusline: false,
    verbose: false
  )

  var p = initOptParser(args)
  while true:
    p.next()
    case p.kind
    of cmdEnd: break
    of cmdShortOption, cmdLongOption:
      case p.key
      of "g", "global":
        opts.installType = itGlobal
      of "l", "local":
        opts.installType = itLocal
      of "c", "config-dir":
        opts.configDir = p.val
        opts.installType = itCustom
      of "force-statusline":
        opts.forceStatusline = true
      of "verbose":
        opts.verbose = true
      of "h", "help":
        echo "Usage: gsd install [options]"
        echo ""
        echo "Options:"
        echo "  -g, --global              Install to ~/.claude (default)"
        echo "  -l, --local               Install to ./.claude"
        echo "  -c, --config-dir <path>   Custom config directory"
        echo "  --force-statusline        Replace existing statusline"
        echo "  --verbose                 Verbose output"
        quit(0)
      else:
        stderr.writeLine "Unknown option: ", p.key
        quit(1)
    of cmdArgument:
      discard

  let sourceDir = findSourceDir()

  # Verify source directory has required content
  if not dirExists(sourceDir / "gsd") or not dirExists(sourceDir / "commands"):
    stderr.writeLine "Error: Cannot find GSD source files."
    stderr.writeLine "Make sure you're running the installer from the GSD directory,"
    stderr.writeLine "or that the binary is located alongside the gsd/ and commands/ directories."
    quit(1)

  let result = install(sourceDir, opts)

  if result.success:
    echo ""
    echo "Done! Use your tool's GSD entry point to get started (e.g., /gsd:help in Claude Code)."
  else:
    stderr.writeLine "Error: ", result.message
    quit(1)

proc cmdUninstall(args: seq[string]) =
  var configDir = ""
  var verbose = false

  var p = initOptParser(args)
  while true:
    p.next()
    case p.kind
    of cmdEnd: break
    of cmdShortOption, cmdLongOption:
      case p.key
      of "g", "global":
        configDir = getGlobalConfigDir()
      of "l", "local":
        configDir = getLocalConfigDir()
      of "c", "config-dir":
        configDir = p.val
      of "verbose":
        verbose = true
      else:
        discard
    of cmdArgument:
      discard

  # If no explicit dir, try to find one
  if configDir.len == 0:
    let found = findConfigDir()
    if found.isNone:
      stderr.writeLine "Error: No GSD installation found."
      quit(1)
    configDir = found.get()

  discard uninstall(configDir, verbose)

proc cmdDoctor(args: seq[string]) =
  ## Validate installation health
  var configDir = ""

  var p = initOptParser(args)
  while true:
    p.next()
    case p.kind
    of cmdEnd: break
    of cmdShortOption, cmdLongOption:
      case p.key
      of "c", "config-dir":
        configDir = p.val
      else:
        discard
    of cmdArgument:
      discard

  # Find config directory
  let resolvedDir = if configDir.len > 0:
    expandPath(configDir)
  else:
    let found = findConfigDir()
    if found.isNone:
      echo "No GSD installation found."
      echo ""
      echo "Run 'gsd install' to install GSD."
      quit(1)
    found.get()

  echo "Checking GSD installation at ", resolvedDir, "..."
  echo ""

  var issues: seq[string] = @[]
  var warnings: seq[string] = @[]

  # Check gsd-config.json
  let configPath = resolvedDir / ConfigFileName
  if fileExists(configPath):
    echo "[OK] gsd-config.json exists"
    let cfg = loadConfig(resolvedDir)
    if cfg.isNone:
      issues.add("gsd-config.json is corrupted")
  else:
    issues.add("gsd-config.json missing")

  # Check VERSION file
  let versionPath = resolvedDir / GsdDirName / VersionFileName
  if fileExists(versionPath):
    let version = readFile(versionPath).strip()
    echo "[OK] VERSION: ", version
  else:
    issues.add("VERSION file missing")

  # Check gsd/ directory
  let gsdDir = resolvedDir / GsdDirName
  if dirExists(gsdDir):
    echo "[OK] gsd/ directory exists"

    # Check subdirectories
    for subdir in ["templates", "workflows", "references"]:
      if not dirExists(gsdDir / subdir):
        warnings.add("gsd/" & subdir & " directory missing")
  else:
    issues.add("gsd/ directory missing")

  # Check commands/gsd/
  let commandsDir = resolvedDir / "commands" / "gsd"
  if dirExists(commandsDir):
    var cmdCount = 0
    for _ in walkDir(commandsDir):
      cmdCount.inc
    echo "[OK] commands/gsd/ exists (", cmdCount, " files)"
  else:
    issues.add("commands/gsd/ directory missing")

  # Check agents/
  let agentsDir = resolvedDir / "agents"
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

  # Check settings.json
  let settingsPath = resolvedDir / "settings.json"
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

  # Summary
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

    if issues.len > 0:
      echo ""
      echo "Run 'gsd install' to fix issues."
      quit(1)

proc cmdCheckUpdate(args: seq[string]) =
  var silent = true
  var configDir = ""

  var p = initOptParser(args)
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
      else:
        discard
    of cmdArgument:
      discard

  runCheckUpdate(silent, configDir)

proc cmdStatusline(args: seq[string]) =
  var configDir = ""

  var p = initOptParser(args)
  while true:
    p.next()
    case p.kind
    of cmdEnd: break
    of cmdShortOption, cmdLongOption:
      case p.key
      of "c", "config-dir":
        configDir = p.val
      else:
        discard
    of cmdArgument:
      discard

  runStatusline(configDir)

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
