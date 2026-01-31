# Verification Patterns

How to verify different types of artifacts are real implementations, not stubs or placeholders.

<core_principle>
**Existence != Implementation**

A file existing does not mean the feature works. Verification must check:
1. **Exists** - File is present at expected path
2. **Substantive** - Content is real implementation, not placeholder
3. **Wired** - Connected to the rest of the system
4. **Functional** - Actually works when invoked

Levels 1-3 can be checked programmatically. Level 4 often requires human verification.
</core_principle>

<stub_detection>

## Universal Stub Patterns

These patterns indicate placeholder code regardless of file type:

**Comment-based stubs:**
```bash
# Grep patterns for stub comments
grep -E "(TODO|FIXME|XXX|HACK|PLACEHOLDER)" "$file"
grep -E "implement|add later|coming soon|will be" "$file" -i
grep -E "// \\.\\.\.|/\* \\.\\.\. \*/|# \\.\\.\." "$file"
```

**Placeholder text in output:**
```bash
# UI placeholder patterns
grep -E "placeholder|lorem ipsum|coming soon|under construction" "$file" -i
grep -E "sample|example|test data|dummy" "$file" -i
grep -E "\[.*\]|<.*>|\{.*\}" "$file"  # Template brackets left in
```

**Empty or trivial implementations:**
```bash
# Functions that do nothing
grep -E "return null|return undefined|return \{\}|return \[]" "$file"
grep -E "pass$|\.\.\.|\bnothing\b" "$file"
grep -E "logger\.(info|warn|error).*only" "$file"  # Log-only functions
```

**Hardcoded values where dynamic expected:**
```bash
# Hardcoded IDs, counts, or content
grep -E "id.*=.*['"].*['"]" "$file"  # Hardcoded string IDs
grep -E "count.*=.*\d+|length.*=.*\d+" "$file"  # Hardcoded counts
grep -E "\\$\d+\.\d{2}|\d+ items" "$file"  # Hardcoded display values
```

</stub_detection>

<ui_components>

## UI Modules / Views

**Existence check:**
```bash
# File exists and declares a UI module (adjust pattern to your stack)
[ -f "$component_path" ] && grep -E "component|module|view|template|render" "$component_path"
```

**Substantive check:**
```bash
# Produces UI output, not placeholder
grep -E "render|template|markup|return" "$component_path" | grep -vi "placeholder|coming soon|todo"

# Has meaningful content (not just a wrapper)
grep -E "event|handler|bind|class=|style=|text=|title=" "$component_path"

# Uses inputs or state (not static)
grep -E "inputs?\.|params\.|args\.|stateHook|lifecycle hook|contextHook" "$component_path"
```

**Stub patterns specific to UI modules:**
```text
// RED FLAGS - These are stubs:
return "<Component>"
return "<Placeholder>"
return "<!-- TODO -->"
return "Coming soon"
return null / empty output

// Also stubs - empty handlers:
onAction=() => {}
onInput=() => log("clicked")
onSubmit=(event) => preventDefault  // Only prevents default, does nothing
```

**Wiring check:**
```bash
# Module imports what it needs
grep -E "import|require|include" "$component_path"

# Inputs are actually used (not just received)
grep -E "inputs?\.|params\.|args\." "$component_path"

# Service calls exist (for data-calling modules)
grep -E "callService\(|clientCall\.|dataFetch|queryHelper" "$component_path"
```

**Functional verification (human required):**
- Does the module render visible content?
- Do interactive elements respond to actions?
- Does data load and display?
- Do error states show appropriately?

</ui_components>

<service_handlers>

## Service Handlers (Generic)

**Existence check:**
```bash
# Handler file exists
[ -f "$handler_path" ]

# Exports handler entry points
grep -E "(handle|process|execute|handler)" "$handler_path"

# Or service-style handlers
grep -E "\.(handle|process|execute)\(" "$handler_path"
```

**Substantive check:**
```bash
# Has actual logic, not just return statement
wc -l "$handler_path"  # More than 10-15 lines suggests real implementation

# Interacts with data source
grep -E "orm-tool\.|db\.|sql|query|find|create|update|delete" "$handler_path" -i

# Has error handling
grep -E "try|catch|throw|error|Error" "$handler_path"

# Returns meaningful response
grep -E "return.*data|emit|send|result|return.*\{" "$handler_path" | grep -v "message.*not implemented" -i
```

**Stub patterns specific to service handlers:**
```text
// RED FLAGS - These are stubs:
export async function handle() {
  return { error: "Not implemented" }
}

export async function handleRead() {
  return []  // Empty result with no data access
}

export async function handleWrite(input) {
  return {}  // Empty result with no side effects
}

// Log-only:
export async function handleUpdate(input) {
  logger.info(input)
  return { ok: true }
}
```

**Wiring check:**
```bash
# Imports data/service clients
grep -E "^import.*data|^import.*client" "$handler_path"

# Actually uses input payload (for write/update)
grep -E "input|payload|body" "$handler_path"

# Validates input (not just trusting request)
grep -E "schema\.parse|validate|check|assert" "$handler_path"
```

**Functional verification (human or automated):**
- Does read handler return real data from data source?
- Does write handler actually create a record?
- Does error response have correct error handling?
- Are auth checks actually enforced?

</service_handlers>

<database_schema>

## Data Schema (Generic)

**Existence check:**
```bash
# Schema file exists
[ -f "data/schema.ext" ] || [ -f "db/schema.ext" ] || [ -f "schema.sql" ]

# Model/table is defined
grep -E "model $model_name|CREATE TABLE $table_name|define $table_name" "$schema_path"
```

**Substantive check:**
```bash
# Has expected fields (not just id)
grep -A 20 "$model_name" "$schema_path" | grep -E "\w+\s+\w+"

# Has relationships if expected
grep -E "relation|REFERENCES|FOREIGN KEY" "$schema_path"

# Has appropriate field types (not all string)
grep -A 20 "$model_name" "$schema_path" | grep -E "Int|DateTime|Boolean|Float|Decimal|Json" -i
```

**Stub patterns specific to schemas:**
```text
// RED FLAGS - These are stubs:
model User {
  id String @id
  // TODO: add fields
}

model Message {
  id        String @id
  content   String  // Only one real field
}

// Missing critical fields:
model Order {
  id     String @id
  // No: userId, items, total, status, createdAt
}
```

**Wiring check:**
```bash
# Migrations exist and are applied
ls db/migrations/ 2>/dev/null | wc -l  # Should be > 0

# Client or schema artifacts generated (if applicable)
[ -d "deps/.data/client" ]
```

**Functional verification:**
```bash
# Can query the table (automated)
query-cli --execute "SELECT COUNT(*) FROM $table_name"
```

</database_schema>

<hooks_utilities>

## Hooks and Utilities

**Existence check:**
```bash
# File exists and exports function
[ -f "$hook_path" ] && grep -E "(function|const|def)" "$hook_path"
```

**Substantive check:**
```bash
# Uses lifecycle/state helpers (if applicable)
grep -E "stateHook|lifecycle hook|callbackHook|memoHook|refHook|contextHook" "$hook_path"

# Has meaningful return value
grep -E "return \{|return \[]" "$hook_path"

# More than trivial length
[ $(wc -l < "$hook_path") -gt 10 ]
```

**Stub patterns specific to hooks:**
```text
// RED FLAGS - These are stubs:
export function useAuth() {
  return { user: null, login: () => {}, logout: () => {} }
}

export function useCart() {
  const [items, setItems] = stateHook([])
  return { items, addItem: () => logger.info('add'), removeItem: () => {} }
}

// Hardcoded return:
export function useUser() {
  return { name: "Test User", email: "test@example.com" }
}
```

**Wiring check:**
```bash
# Hook is actually imported somewhere
grep -r "import.*$hook_name" src/ --include="*.ext" | grep -v "$hook_path"

# Hook is actually called
grep -r "$hook_name()" src/ --include="*.ext" | grep -v "$hook_path"
```

</hooks_utilities>

<environment_config>

## Environment Variables and Configuration

**Existence check:**
```bash
# .env file exists
[ -f ".env" ] || [ -f ".env.local" ]

# Required variable is defined
grep -E "^$VAR_NAME=" .env .env.local 2>/dev/null
```

**Substantive check:**
```bash
# Variable has actual value (not placeholder)
grep -E "^$VAR_NAME=.+" .env .env.local 2>/dev/null | grep -v "your-.*-here|xxx|placeholder|TODO" -i
```

**Stub patterns specific to env:**
```bash
# RED FLAGS - These are stubs:
DATABASE_URL=your-database-url-here
SERVICE_KEY=key_test_xxx
SERVICE_KEY=placeholder
PUBLIC_SERVICE_URL=http://localhost:3000  # Still pointing to localhost in prod
```

**Wiring check:**
```bash
# Variable is actually used in code
grep -r "env\.$VAR_NAME|ENV\[$VAR_NAME\]" src/ --include="*.ext"

# Variable is in validation schema (if using a config schema)
grep -E "$VAR_NAME" src/env.ext config/env.ext 2>/dev/null
```

</environment_config>

<wiring_verification>

## Wiring Verification Patterns

Wiring verification checks that modules actually communicate. This is where most stubs hide.

### Pattern: Module -> Service

**Check:** Does the module actually call the service?

```bash
# Find the callService/clientCall call
grep -E "callService\(['"].*$api_path|clientCall\.(get|post).*$api_path" "$component_path"

# Verify it's not commented out
grep -E "callService\(|clientCall\." "$component_path" | grep -v "^.*//.*service call"

# Check the response is used
grep -E "await.*callService|\.then\(|setData|setState" "$component_path"
```

**Red flags:**
```text
// Call exists but response ignored:
callService('messages')  // No await, no then, no assignment

// Call in comment:
// callService('messages').then(r => r.json()).then(setMessages)

// Call to wrong target:
callService('message')  // Typo - should be 'messages'
```

### Pattern: Service -> Data Store

**Check:** Does the service handler actually query the data store?

```bash
# Find the data call
grep -E "data\.$model|db\.query|Model\.find" "$handler_path"

# Verify it's awaited
grep -E "await.*data|await.*db\." "$handler_path"

# Check result is returned
grep -E "return.*data|return.*result|send\(" "$handler_path"
```

**Red flags:**
```text
// Query exists but result not returned:
await data.message.findMany()
return { ok: true }  // Returns static, not query result

// Query not awaited:
const messages = data.message.findMany()  // Missing await
return messages  // Returns Promise, not data
```

### Pattern: Form -> Handler

**Check:** Does the form submission actually do something?

```bash
# Find onSubmit handler
grep -E "onSubmit=\{|handleSubmit" "$component_path"

# Check handler has content
grep -A 10 "onSubmit.*=" "$component_path" | grep -E "callService|clientCall|mutate|dispatch"

# Verify not just preventDefault
grep -A 5 "onSubmit" "$component_path" | grep -v "only.*preventDefault" -i
```

**Red flags:**
```text
// Handler only prevents default:
onSubmit=(event) => preventDefault

// Handler only logs:
const handleSubmit = (data) => {
  logger.info(data)
}

// Handler is empty:
onSubmit=() => {}
```

### Pattern: State -> Render

**Check:** Does the module render state, not hardcoded content?

```bash
# Find state usage in output
grep -E "\{.*messages.*\}|\{.*data.*\}|\{.*items.*\}" "$component_path"

# Check map/render of state
grep -E "\.map\(|\.filter\(|\.reduce\(" "$component_path"

# Verify dynamic content
grep -E "\{[a-zA-Z_]+\." "$component_path"  # Variable interpolation
```

**Red flags:**
```text
// Hardcoded instead of state:
return "Message 1"
return "Message 2"

// State exists but not rendered:
const [messages, setMessages] = stateHook([])
return "No messages"  // Always shows placeholder

// Wrong state rendered:
const [messages, setMessages] = stateHook([])
return renderList(otherData)  // Uses different data
```

</wiring_verification>

<verification_checklist>

## Quick Verification Checklist

For each artifact type, run through this checklist:

### Component Checklist
- [ ] File exists at expected path
- [ ] Declares a module entry point
- [ ] Returns UI output (not null/empty)
- [ ] No placeholder text in render
- [ ] Uses inputs or state (not static)
- [ ] Event handlers have real implementations
- [ ] Imports resolve correctly
- [ ] Used somewhere in the app

### Service Handler Checklist
- [ ] File exists at expected path
- [ ] Exports handler entry points
- [ ] Handlers have more than 5 lines
- [ ] Queries data store or service
- [ ] Returns meaningful response (not empty/placeholder)
- [ ] Has error handling
- [ ] Validates input
- [ ] Called from modules

### Schema Checklist
- [ ] Model/table defined
- [ ] Has all expected fields
- [ ] Fields have appropriate types
- [ ] Relationships defined if needed
- [ ] Migrations exist and applied
- [ ] Client generated

### Hook/Utility Checklist
- [ ] File exists at expected path
- [ ] Exports function
- [ ] Has meaningful implementation (not empty returns)
- [ ] Used somewhere in the app
- [ ] Return values consumed

### Wiring Checklist
- [ ] Module -> Service: callService/clientCall call exists and uses response
- [ ] Service -> Data Store: query exists and result returned
- [ ] Form -> Handler: onSubmit calls service/mutation
- [ ] State -> Render: state variables appear in output

</verification_checklist>

<automated_verification_script>

## Automated Verification Approach

For the verification subagent, use this pattern:

```bash
# 1. Check existence
check_exists() {
  [ -f "$1" ] && echo "EXISTS: $1" || echo "MISSING: $1"
}

# 2. Check for stub patterns
check_stubs() {
  local file="$1"
  local stubs=$(grep -c -E "TODO|FIXME|placeholder|not implemented" "$file" 2>/dev/null || echo 0)
  [ "$stubs" -gt 0 ] && echo "STUB_PATTERNS: $stubs in $file"
}

# 3. Check wiring (module calls service)
check_wiring() {
  local module="$1"
  local service_id="$2"
  grep -q "$service_id" "$module" && echo "WIRED: $module -> $service_id" || echo "NOT_WIRED: $module -> $service_id"
}

# 4. Check substantive (more than N lines, has expected patterns)
check_substantive() {
  local file="$1"
  local min_lines="$2"
  local pattern="$3"
  local lines=$(wc -l < "$file" 2>/dev/null || echo 0)
  local has_pattern=$(grep -c -E "$pattern" "$file" 2>/dev/null || echo 0)
  [ "$lines" -ge "$min_lines" ] && [ "$has_pattern" -gt 0 ] && echo "SUBSTANTIVE: $file" || echo "THIN: $file ($lines lines, $has_pattern matches)"
}
```

Run these checks against each must-have artifact. Aggregate results into VERIFICATION.md.

</automated_verification_script>

<human_verification_triggers>

## When to Require Human Verification

Some things can't be verified programmatically. Flag these for human testing:

**Always human:**
- Visual appearance (does it look right?)
- User flow completion (can you actually do the thing?)
- Real-time behavior (live updates, streaming, sync)
- External service integration (payments, email, third-party APIs)
- Error message clarity (is the message helpful?)
- Performance feel (does it feel fast?)

**Human if uncertain:**
- Complex wiring that grep can't trace
- Dynamic behavior depending on state
- Edge cases and error states
- Mobile responsiveness
- Accessibility

**Format for human verification request:**
```markdown
## Human Verification Required

### 1. Message sending
**Test:** Type a message and click Send
**Expected:** Message appears in list, input clears
**Check:** Does message persist after refresh?

### 2. Error handling
**Test:** Disconnect network, try to send
**Expected:** Error message appears, message not lost
**Check:** Can retry after reconnect?
```

</human_verification_triggers>
