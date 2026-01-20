## GSD Statusline hook
## Reads JSON from stdin, outputs formatted ANSI statusline

import std/[json, options, strutils, os, nre]
import config

when defined(windows):
  import std/winlean

  var vtEnabled = false

  proc enableVirtualTerminal(): bool =
    ## Enable ANSI escape sequences on Windows
    ## Returns true if successful, false if ANSI should be stripped
    let handle = getStdHandle(STD_OUTPUT_HANDLE)
    if handle == INVALID_HANDLE_VALUE:
      return false

    var mode: DWORD
    if getConsoleMode(handle, addr mode) == 0:
      return false

    mode = mode or ENABLE_VIRTUAL_TERMINAL_PROCESSING
    if setConsoleMode(handle, mode) == 0:
      return false

    return true

proc stripAnsi*(s: string): string =
  ## Remove ANSI escape sequences from a string
  result = s.replace(re"\e\[[0-9;]*m", "")

# ANSI color codes
const
  Reset = "\e[0m"
  Dim = "\e[2m"
  Blink = "\e[5m"

  # Foreground colors
  Green = "\e[32m"
  Yellow = "\e[33m"
  Red = "\e[31m"
  Cyan = "\e[36m"
  White = "\e[37m"

  # Bar characters
  BarFilled = "█"
  BarEmpty = "░"
  BarWidth = 10

  Separator = " │ "

  # Task display
  MaxTaskLength = 30

type
  StatusInput* = object
    model*: Option[string]
    workspace*: Option[string]
    sessionId*: Option[string]
    contextRemaining*: Option[int]

proc parseInput*(jsonStr: string): Option[StatusInput] =
  ## Parse the JSON input from Claude Code
  try:
    let json = parseJson(jsonStr)
    var input = StatusInput()

    # Extract model name
    if json.hasKey("model") and json["model"].hasKey("display_name"):
      input.model = some(json["model"]["display_name"].getStr())

    # Extract workspace/project
    if json.hasKey("workspace") and json["workspace"].hasKey("current_dir"):
      let dir = json["workspace"]["current_dir"].getStr()
      input.workspace = some(extractFilename(dir))

    # Extract session ID
    if json.hasKey("session_id"):
      input.sessionId = some(json["session_id"].getStr())

    # Extract context remaining percentage
    if json.hasKey("context_window") and json["context_window"].hasKey("remaining_percentage"):
      input.contextRemaining = some(json["context_window"]["remaining_percentage"].getInt())

    return some(input)
  except JsonParsingError, KeyError:
    return none(StatusInput)

proc getContextColor*(remaining: int): string =
  ## Get color based on context usage
  ## remaining is percentage remaining (100 = empty, 0 = full)
  let used = 100 - remaining
  if used < 50:
    return Green
  elif used < 65:
    return Yellow
  elif used < 80:
    return Yellow  # Could use orange if terminal supports
  else:
    return Red & Blink

proc renderContextBar*(remaining: int): string =
  ## Render a visual context usage bar
  let used = 100 - remaining
  let filledCount = (used * BarWidth) div 100
  let emptyCount = BarWidth - filledCount

  let color = getContextColor(remaining)
  result = color & BarFilled.repeat(filledCount) & Dim & BarEmpty.repeat(emptyCount) & Reset
  result &= " " & $used & "%"

proc extractAfterMarker*(line: string, marker: string): Option[string] =
  ## Extract text after a marker pattern like "**Current:**"
  let pos = line.find(marker)
  if pos >= 0:
    let afterMarker = line[pos + marker.len .. ^1].strip()
    if afterMarker.len > 0:
      return some(afterMarker)
  return none(string)

proc getCurrentTask(): Option[string] =
  ## Try to read current task from STATE.md or todos
  # Check for .planning/STATE.md
  let statePath = getCurrentDir() / ".planning" / "STATE.md"
  if fileExists(statePath):
    try:
      let content = readFile(statePath)
      # Look for "**Current:**" or "**Working on:**" patterns
      for line in content.splitLines():
        for marker in ["**Current:**", "**Working on:**"]:
          let task = extractAfterMarker(line, marker)
          if task.isSome:
            return task
    except IOError:
      discard

  return none(string)

proc checkUpdateAvailable(configDir: string = ""): bool =
  ## Check if an update is available (from cached check)
  var locations: seq[string] = @[]

  # If explicit config dir, only check there
  if configDir.len > 0:
    locations.add(configDir / "cache" / "gsd-update-check.json")
  else:
    # Check both possible cache locations
    locations.add(getCurrentDir() / ".claude" / "cache" / "gsd-update-check.json")
    locations.add(getHomeDir() / ".claude" / "cache" / "gsd-update-check.json")

  for cachePath in locations:
    if fileExists(cachePath):
      try:
        let content = readFile(cachePath)
        let json = parseJson(content)
        if json.hasKey("update_available"):
          return json["update_available"].getBool(false)
      except JsonParsingError, IOError:
        discard

  return false

proc formatStatusline(input: StatusInput, configDir: string = ""): string =
  ## Format the statusline output
  var parts: seq[string] = @[]

  # Model name
  if input.model.isSome:
    parts.add(Cyan & input.model.get() & Reset)

  # Current task (if available)
  let task = getCurrentTask()
  if task.isSome:
    let taskText = if task.get().len > MaxTaskLength:
      task.get()[0 .. MaxTaskLength - 3] & "..."
    else:
      task.get()
    parts.add(White & taskText & Reset)

  # Project/workspace name
  if input.workspace.isSome:
    parts.add(Dim & input.workspace.get() & Reset)

  # Context bar
  if input.contextRemaining.isSome:
    parts.add(renderContextBar(input.contextRemaining.get()))

  # Update indicator
  if checkUpdateAvailable(configDir):
    parts.add(Yellow & "⬆ update" & Reset)

  result = parts.join(Separator)

proc runStatusline*(configDir: string = "") =
  ## Main statusline entry point
  when defined(windows):
    vtEnabled = enableVirtualTerminal()

  let resolvedConfigDir = if configDir.len > 0: expandPath(configDir) else: ""

  # Read JSON from stdin
  var jsonInput = ""
  try:
    jsonInput = readAll(stdin)
  except IOError:
    # No input, output empty line
    echo ""
    return

  if jsonInput.len == 0:
    echo ""
    return

  let input = parseInput(jsonInput)
  if input.isNone:
    # Failed to parse, output empty line
    echo ""
    return

  var output = formatStatusline(input.get(), resolvedConfigDir)

  # Strip ANSI codes on Windows if VT mode failed
  when defined(windows):
    if not vtEnabled:
      output = stripAnsi(output)

  echo output
