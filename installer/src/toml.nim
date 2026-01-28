## Minimal TOML writer for Codex CLI config.toml manipulation
## Supports reading, merging, and writing TOML config files

import std/[os, strutils, tables, options]

type
  TomlValueKind* = enum
    tvkString
    tvkInt
    tvkFloat
    tvkBool
    tvkArray
    tvkTable

  TomlValue* = ref object
    case kind*: TomlValueKind
    of tvkString:
      strVal*: string
    of tvkInt:
      intVal*: int64
    of tvkFloat:
      floatVal*: float64
    of tvkBool:
      boolVal*: bool
    of tvkArray:
      arrayVal*: seq[TomlValue]
    of tvkTable:
      tableVal*: OrderedTable[string, TomlValue]

  TomlDocument* = object
    root*: OrderedTable[string, TomlValue]

proc newTomlString*(s: string): TomlValue =
  TomlValue(kind: tvkString, strVal: s)

proc newTomlInt*(i: int64): TomlValue =
  TomlValue(kind: tvkInt, intVal: i)

proc newTomlBool*(b: bool): TomlValue =
  TomlValue(kind: tvkBool, boolVal: b)

proc newTomlFloat*(f: float64): TomlValue =
  TomlValue(kind: tvkFloat, floatVal: f)

proc newTomlArray*(arr: seq[TomlValue]): TomlValue =
  TomlValue(kind: tvkArray, arrayVal: arr)

proc newTomlTable*(): TomlValue =
  TomlValue(kind: tvkTable, tableVal: initOrderedTable[string, TomlValue]())

proc escapeTomlString(s: string): string =
  ## Escape a string for TOML output
  result = "\""
  for c in s:
    case c
    of '"': result.add("\\\"")
    of '\\': result.add("\\\\")
    of '\n': result.add("\\n")
    of '\r': result.add("\\r")
    of '\t': result.add("\\t")
    else: result.add(c)
  result.add("\"")

proc toTomlString*(val: TomlValue, indent: int = 0): string =
  ## Convert a TomlValue to TOML string representation
  # Note: indent parameter reserved for future nested table support
  case val.kind
  of tvkString:
    return escapeTomlString(val.strVal)
  of tvkInt:
    return $val.intVal
  of tvkFloat:
    return $val.floatVal
  of tvkBool:
    return if val.boolVal: "true" else: "false"
  of tvkArray:
    var parts: seq[string] = @[]
    for item in val.arrayVal:
      parts.add(item.toTomlString(indent))
    return "[" & parts.join(", ") & "]"
  of tvkTable:
    # Tables are handled specially in document serialization
    return "{}"

proc serializeToml*(doc: TomlDocument): string =
  ## Serialize a TOML document to string
  var lines: seq[string] = @[]

  # First pass: emit simple key-value pairs at root level
  for key, val in doc.root.pairs:
    if val.kind != tvkTable and val.kind != tvkArray:
      lines.add(key & " = " & val.toTomlString())
    elif val.kind == tvkArray:
      # Check if array contains tables
      if val.arrayVal.len > 0 and val.arrayVal[0].kind == tvkTable:
        # Array of tables - handled later
        discard
      else:
        lines.add(key & " = " & val.toTomlString())

  # Second pass: emit tables
  for key, val in doc.root.pairs:
    if val.kind == tvkTable:
      if lines.len > 0:
        lines.add("")
      lines.add("[" & key & "]")
      for subKey, subVal in val.tableVal.pairs:
        if subVal.kind != tvkTable:
          lines.add(subKey & " = " & subVal.toTomlString())

  # Third pass: emit array of tables (e.g., [[notify]])
  for key, val in doc.root.pairs:
    if val.kind == tvkArray and val.arrayVal.len > 0 and val.arrayVal[0].kind == tvkTable:
      for item in val.arrayVal:
        if lines.len > 0:
          lines.add("")
        lines.add("[[" & key & "]]")
        if item.kind == tvkTable:
          for subKey, subVal in item.tableVal.pairs:
            lines.add(subKey & " = " & subVal.toTomlString())

  return lines.join("\n") & "\n"

proc parseTomlLine(line: string): tuple[key: string, value: string, isTable: bool, isArrayTable: bool] =
  ## Parse a single TOML line, returning key-value or table header
  let stripped = line.strip()

  if stripped.len == 0 or stripped.startsWith("#"):
    return ("", "", false, false)

  # Array of tables: [[name]]
  if stripped.startsWith("[[") and stripped.endsWith("]]"):
    return (stripped[2..^3].strip(), "", false, true)

  # Table: [name]
  if stripped.startsWith("[") and stripped.endsWith("]"):
    return (stripped[1..^2].strip(), "", true, false)

  # Key-value pair
  let eqPos = stripped.find('=')
  if eqPos > 0:
    let key = stripped[0..<eqPos].strip()
    let value = stripped[eqPos+1..^1].strip()
    return (key, value, false, false)

  return ("", "", false, false)

proc parseTomlValue(s: string): TomlValue =
  ## Parse a TOML value string
  let stripped = s.strip()

  if stripped.len == 0:
    return newTomlString("")

  # Boolean
  if stripped == "true":
    return newTomlBool(true)
  if stripped == "false":
    return newTomlBool(false)

  # String (quoted)
  if stripped.startsWith("\"") and stripped.endsWith("\""):
    var inner = stripped[1..^2]
    # Unescape basic sequences
    inner = inner.replace("\\\"", "\"")
    inner = inner.replace("\\\\", "\\")
    inner = inner.replace("\\n", "\n")
    inner = inner.replace("\\t", "\t")
    return newTomlString(inner)

  # Array
  if stripped.startsWith("[") and stripped.endsWith("]"):
    var arr: seq[TomlValue] = @[]
    let inner = stripped[1..^2].strip()
    if inner.len > 0:
      # Simple comma-separated parsing (doesn't handle nested arrays well)
      var items = inner.split(',')
      for item in items:
        let trimmed = item.strip()
        if trimmed.len > 0:
          arr.add(parseTomlValue(trimmed))
    return newTomlArray(arr)

  # Integer
  try:
    let intVal = parseInt(stripped)
    return newTomlInt(intVal.int64)
  except ValueError:
    discard

  # Float
  try:
    let floatVal = parseFloat(stripped)
    return newTomlFloat(floatVal)
  except ValueError:
    discard

  # Default: treat as unquoted string
  return newTomlString(stripped)

proc parseToml*(content: string): TomlDocument =
  ## Parse TOML content into a document
  result = TomlDocument(root: initOrderedTable[string, TomlValue]())

  var currentTable = ""
  var currentArrayTable = ""
  var arrayTableIdx = -1

  for line in content.splitLines():
    let (key, value, isTable, isArrayTable) = parseTomlLine(line)

    if isArrayTable:
      currentArrayTable = key
      currentTable = ""
      arrayTableIdx += 1
      if not result.root.hasKey(key):
        result.root[key] = newTomlArray(@[])
      result.root[key].arrayVal.add(newTomlTable())
    elif isTable:
      currentTable = key
      currentArrayTable = ""
      arrayTableIdx = -1
      if not result.root.hasKey(key):
        result.root[key] = newTomlTable()
    elif key.len > 0:
      let parsed = parseTomlValue(value)
      if currentArrayTable.len > 0 and arrayTableIdx >= 0:
        # Inside array of tables
        let arr = result.root[currentArrayTable]
        arr.arrayVal[arrayTableIdx].tableVal[key] = parsed
      elif currentTable.len > 0:
        # Inside a table
        result.root[currentTable].tableVal[key] = parsed
      else:
        # Root level
        result.root[key] = parsed

proc loadToml*(path: string): Option[TomlDocument] =
  ## Load TOML from file
  if not fileExists(path):
    return none(TomlDocument)
  try:
    let content = readFile(path)
    return some(parseToml(content))
  except IOError:
    return none(TomlDocument)

proc saveToml*(doc: TomlDocument, path: string): bool =
  ## Save TOML document to file
  try:
    writeFile(path, serializeToml(doc))
    return true
  except IOError:
    return false

proc isGsdNotifyHook*(table: TomlValue): bool =
  ## Check if a notify table entry is a GSD hook
  if table.kind != tvkTable:
    return false
  if table.tableVal.hasKey("command"):
    let cmd = table.tableVal["command"]
    if cmd.kind == tvkString:
      return cmd.strVal.contains("#gsd") or cmd.strVal.contains("gsd ")
  return false

proc mergeCodexNotify*(doc: var TomlDocument, gsdNotify: seq[TomlValue]) =
  ## Merge GSD notify hooks into Codex config
  ## Removes existing GSD hooks, adds new ones
  ## NOTE: This modifies the in-memory TomlDocument. For files with content
  ## this parser doesn't understand, use mergeCodexNotifyText instead.

  # Get or create notify array
  var notifyArr: seq[TomlValue]

  if doc.root.hasKey("notify"):
    let existing = doc.root["notify"]
    if existing.kind == tvkArray:
      # Filter out existing GSD hooks
      for item in existing.arrayVal:
        if not isGsdNotifyHook(item):
          notifyArr.add(item)

  # Add new GSD hooks
  for hook in gsdNotify:
    notifyArr.add(hook)

  doc.root["notify"] = newTomlArray(notifyArr)

proc isGsdNotifySection(lines: seq[string], startIdx: int): bool =
  ## Check if a [[notify]] section starting at startIdx is a GSD hook
  ## Looks for #gsd marker in the command within that section
  for i in startIdx + 1 ..< lines.len:
    let line = lines[i].strip()
    # Stop at next section header
    if line.startsWith("["):
      return false
    # Check for GSD marker in command
    if line.startsWith("command") and (line.contains("#gsd") or line.contains("\"gsd ")):
      return true
  return false

proc mergeCodexNotifyText*(content: string, gsdNotify: seq[TomlValue]): string =
  ## Merge GSD notify hooks into Codex config using text-based approach
  ## This preserves all content the parser doesn't understand (dotted keys,
  ## nested tables, multi-line strings, etc.)
  ##
  ## Strategy:
  ## 1. Remove existing [[notify]] sections that contain #gsd
  ## 2. Append new GSD [[notify]] sections at end

  var lines = content.splitLines()
  var resultLines: seq[string] = @[]
  var i = 0

  while i < lines.len:
    let line = lines[i]
    let stripped = line.strip()

    # Check if this is a [[notify]] section
    if stripped == "[[notify]]":
      # Check if it's a GSD hook section
      if isGsdNotifySection(lines, i):
        # Skip this entire section (until next section header or EOF)
        i += 1
        while i < lines.len:
          let nextLine = lines[i].strip()
          if nextLine.startsWith("["):
            break
          i += 1
        # Also skip any trailing blank lines from the removed section
        while resultLines.len > 0 and resultLines[^1].strip() == "":
          discard resultLines.pop()
        continue
      else:
        # Not a GSD hook, keep it
        resultLines.add(line)
    else:
      resultLines.add(line)
    i += 1

  # Remove trailing empty lines before adding new content
  while resultLines.len > 0 and resultLines[^1].strip() == "":
    discard resultLines.pop()

  # Append new GSD notify hooks
  if gsdNotify.len > 0:
    if resultLines.len > 0:
      resultLines.add("")  # Blank line separator

    for hook in gsdNotify:
      resultLines.add("[[notify]]")
      if hook.kind == tvkTable:
        for key, val in hook.tableVal.pairs:
          resultLines.add(key & " = " & val.toTomlString())
      resultLines.add("")

  # Ensure file ends with newline
  if resultLines.len > 0 and resultLines[^1] != "":
    resultLines.add("")

  return resultLines.join("\n")

proc createGsdNotifyHooks*(gsdBinaryPath, gsdDir: string): seq[TomlValue] =
  ## Create GSD notify hooks for Codex CLI
  ## Codex uses [[notify]] array of tables
  ## --config-dir points to .gsd/ directory
  var hooks: seq[TomlValue] = @[]

  # Session start hook for update checking
  var sessionHook = newTomlTable()
  sessionHook.tableVal["event"] = newTomlString("session_start")
  sessionHook.tableVal["command"] = newTomlString(
    "\"" & gsdBinaryPath & "\" check-update --config-dir \"" & gsdDir & "\" #gsd"
  )
  hooks.add(sessionHook)

  return hooks
