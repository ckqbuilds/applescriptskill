# AppleScript Scripting Guide

Rules and patterns for writing AppleScript that executes correctly on the first run.
Read this before generating any AppleScript.

## Script Structure

### Standalone scripts (`.applescript` files)

Use `on run argv` to accept command-line arguments:

```applescript
-- Description of what this script does.
-- Usage: osascript script-name.applescript "arg1" "arg2"

on run argv
    set firstArg to item 1 of argv
    -- logic here
end run
```

Arguments arrive as a list of strings. Always coerce types explicitly:

```applescript
set maxResults to (item 2 of argv) as integer
```

### Inline scripts (heredoc preferred)

For one-off execution without a file, **always use a heredoc**. The Bash tool
shell can mangle double quotes into smart quotes when using `osascript -e`,
causing cryptic `-2741` errors.

```bash
osascript <<'APPLESCRIPT'
tell application "Reminders"
    make new reminder in list "Reminders" with properties {name:"Buy milk"}
end tell
APPLESCRIPT
```

The single quotes around `'APPLESCRIPT'` prevent interpolation and quote mangling.

Avoid `osascript -e` via the Bash tool. If you must use it (true single-line
commands only), test carefully for quote corruption.

## Syntax Essentials

### Tell blocks

All app interactions must be inside a `tell` block:

```applescript
tell application "Mail"
    -- Mail commands go here
end tell
```

Nested tells for sub-objects:

```applescript
tell application "Calendar"
    tell calendar "Home"
        -- event commands
    end tell
end tell
```

### Properties and records

Set multiple properties using record syntax with curly braces:

```applescript
make new reminder in list "Reminders" with properties {name:"Title", body:"Notes", due date:dueDate}
```

Rules:
- Property names use **spaces** not camelCase: `due date`, `start date`, `read status`
- String values use **double quotes** only: `"text"`
- Booleans are `true` / `false` (lowercase)
- Records use curly braces: `{key:value, key:value}`
- Lists use curly braces: `{"item1", "item2"}`

### Variables

```applescript
set myVar to "hello"
set myList to {"a", "b", "c"}
set myNum to 42
```

No declaration keyword — just `set`. Variables are dynamically typed.

### String concatenation

Use `&` to join strings:

```applescript
set output to "Name: " & userName & linefeed & "Email: " & userEmail
```

Use `linefeed` for newlines (not `\n` — that's literal text in AppleScript).
Use `return` for carriage return. Use `tab` for tab characters.

### Comparisons

```applescript
-- Equality
if x is "hello" then ...
if x is not 5 then ...

-- String matching
if subject contains "invoice" then ...
if name begins with "Re:" then ...
if name ends with ".pdf" then ...

-- Numeric
if count > 10 then ...
if x ≥ 5 then ...    -- or: x >= 5
```

## Dictionary Lookup (sdef)

macOS ships with scripting dictionaries (`.sdef` files) for every scriptable app.
These are the **authoritative source** for command names, parameter names, property
names, and types. When in doubt about syntax, look it up.

### How to query from AppleScript

Use `do shell script` to run the `sdef` command through the existing tool:

```applescript
-- Get the full dictionary for an app
do shell script "sdef /System/Applications/Mail.app"

-- Search for a specific command
do shell script "sdef /System/Applications/Mail.app | grep -A 15 'command name=\"reply\"'"

-- Search for a class (object type)
do shell script "sdef /System/Applications/Reminders.app | grep -A 20 'class name=\"reminder\"'"

-- Search for a property
do shell script "sdef /System/Applications/Calendar.app | grep 'property name='"
```

### App dictionary paths

| App | sdef path |
|-----|-----------|
| Mail | `/System/Applications/Mail.app` |
| Reminders | `/System/Applications/Reminders.app` |
| Calendar | `/System/Applications/Calendar.app` |
| Notes | `/System/Applications/Notes.app` |
| Finder | `/System/Library/CoreServices/Finder.app` |
| System Events | `/System/Library/CoreServices/System Events.app` |
| StandardAdditions (notifications, dialogs, clipboard) | `/System/Library/ScriptingAdditions/StandardAdditions.osax` |

### Reading sdef XML

The output is XML. Key elements:

| XML element | Meaning | AppleScript usage |
|-------------|---------|-------------------|
| `<command name="X">` | A command you can call | `X` |
| `<direct-parameter>` | First unlabeled argument | Goes right after the command name |
| `<parameter name="X">` | A named parameter | `X value` in AppleScript |
| `<class name="X">` | An object type | Used in `tell`, `make new X`, etc. |
| `<property name="X">` | A property of a class | `X of objectRef` |
| `<element type="X">` | Child objects a class contains | `every X of parentRef` |
| `optional="yes"` | Parameter is optional | Can be omitted |

### Worked example: diagnosing a real error

The agent generates:
```applescript
display notification with title "Workout" message "Do 10 pushups"
```

This fails with: `syntax error: A identifier can't go after this "". (-2740)`

**Diagnosis**: Look up the command in StandardAdditions:
```applescript
do shell script "sdef /System/Library/ScriptingAdditions/StandardAdditions.osax | grep -A 10 'command name=\"display notification\"'"
```

The sdef shows:
- `<direct-parameter type="text">` — body text goes first, unlabeled
- `<parameter name="with title">` — not just `title`
- `<parameter name="subtitle">` — not `message`
- `<parameter name="sound name">` — optional

**Fix**:
```applescript
display notification "Do 10 pushups" with title "Workout"
```

### When to look up sdef

- **Before generating** AppleScript for a command you haven't used recently
- **After any error** mentioning an unexpected identifier, wrong parameter, or unknown property
- **When unsure** about parameter names, order, or types

## Filtering with `whose`

The `whose` clause filters objects at the application level — far faster than
looping with `repeat`:

```applescript
-- Good: filtered at app level
set msgs to messages of inbox whose sender contains "example.com"

-- Bad: iterates every message over Apple Events
set allMsgs to every message of inbox
repeat with msg in allMsgs
    if sender of msg contains "example.com" then ...
end repeat
```

Combine conditions with `and` / `or`:

```applescript
messages of inbox whose read status is false and subject contains "urgent"
```

Get the first match:

```applescript
first message of inbox whose subject contains "report"
```

## Limiting Results

```applescript
-- First N items from a container
messages 1 thru 10 of inbox

-- First N from a filtered result
set matches to (messages of inbox whose sender contains "boss@work.com")
if (count of matches) > 10 then
    set matches to items 1 thru 10 of matches
end if
```

Always limit results when querying large mailboxes or containers to avoid timeouts.

## Error Handling

### Basic try/on error

Always wrap operations that can fail (network-dependent apps, missing objects):

```applescript
try
    set msg to first message of inbox whose subject contains "nonexistent"
    set msgSubject to subject of msg
on error errMsg number errNum
    return "Error " & errNum & ": " & errMsg
end try
```

### Common error numbers

| Number | Meaning | Typical cause |
|--------|---------|---------------|
| `-1728` | Can't get object | No matching item found (empty `whose` result) |
| `-1712` | Event timed out | Operation took longer than 60s default |
| `-10004` | Privilege violation | Missing permissions (Accessibility, Automation) |
| `-49` | File already open | Attachment conflict |
| `-128` | User canceled | User clicked Cancel in a dialog |

### Timeout handling

The default Apple Event timeout is 60 seconds. For large operations:

```applescript
with timeout of 120 seconds
    tell application "Mail"
        set msgs to messages of inbox whose read status is false
    end tell
end timeout
```

### Per-item error handling in loops

Don't let one bad item abort the whole loop:

```applescript
repeat with msg in messages 1 thru 20 of inbox
    try
        set subj to subject of msg
        set sndr to sender of msg
        -- process...
    on error
        -- skip this message, continue with next
    end try
end repeat
```

## Output Formatting

`osascript` prints the result of the last expression to stdout. Design scripts
to return structured, parseable output:

```applescript
-- Tab-separated fields, one record per line
set output to ""
repeat with msg in matchingMsgs
    set output to output & subject of msg & tab & sender of msg & tab & (date received of msg as string) & linefeed
end repeat
return output
```

Conventions for this skill's scripts:
- Use `tab` as field separator
- Use `linefeed` as record separator
- Return human-readable messages for empty results: `"No messages found"`
- Return error context on failure: `"Error: " & errMsg`

## Text Item Delimiters

AppleScript's way to split and join strings:

```applescript
-- Extract email from "Name <email@example.com>"
set AppleScript's text item delimiters to "<"
set parts to every text item of senderString
set AppleScript's text item delimiters to ">"
set emailAddr to first text item of item 2 of parts
set AppleScript's text item delimiters to ""  -- always reset
```

**Always reset delimiters to `""`** after use. Failing to reset causes subtle
bugs in subsequent string operations.

## Common Pitfalls

| Pitfall | Fix |
|---------|-----|
| Using `\n` for newlines | Use `linefeed` or `return` |
| Zero-padded dates (`"04/02/2026"`) | Use `format_applescript_date()` — see `references/date-formatting.md` |
| Forgetting `end tell` | Every `tell` needs a matching `end tell` |
| Using JXA instead of AppleScript | Always use AppleScript (see SKILL.md design philosophy) |
| Not resetting text item delimiters | Always set back to `""` after splitting |
| Iterating instead of using `whose` | Use `whose` for filtering — it's faster |
| No `try` around app queries | Wrap in `try`/`on error` — objects may not exist |
| Missing `with timeout` on large queries | Add `with timeout of N seconds` for bulk operations |
| Passing unquoted args with spaces | Caller must quote: `osascript script.applescript "my arg"` |
| Assuming `reply to` can be set on outgoing messages | It can't — this is a Mail.app limitation |
| Smart quote mangling with `osascript -e` via Bash tool | The Bash tool shell can convert `"` to curly quotes `""`, causing error `-2741`. **Always use a heredoc** instead of `-e` (see below) |

### Smart Quote Mangling (Bash Tool)

When running `osascript -e '...'` through the Bash tool, double quotes can get
silently converted to smart/curly quotes, causing:

```
syntax error: Expected """ but found unknown token. (-2741)
```

**Always use a heredoc** when executing AppleScript via the Bash tool:

```bash
osascript <<'APPLESCRIPT'
display notification "Hello" with title "Test"
APPLESCRIPT
```

The single quotes around `'APPLESCRIPT'` prevent any interpolation or character
mangling. This issue only affects execution via the Bash tool shell —
`subprocess.run` in Python does not have this problem.

## Error Diagnosis & Retry

**Never report failure on the first error.** Read stderr, diagnose the problem,
fix the script, and re-run. Retry up to 3 times before asking the user for help.
Permission errors are the only exception — inform the user immediately.

### Diagnosis workflow

1. **Read the full stderr** output from osascript
2. **Classify the error**:
   - **Syntax error** (happens at compile time) → wrong parameter name, missing `end tell`, bad quoting
   - **Runtime error** (happens during execution) → object not found, timeout, type mismatch
   - **Permission error** → user must grant access in System Settings
3. **For syntax errors**: look up the correct command/parameter names via sdef (see Dictionary Lookup section above), check block nesting, check string quoting
4. **For runtime errors**: consult the error-to-fix table below, adjust the script
5. **For permission errors**: tell the user what to enable — do not retry

### Error-to-fix table

| Error | Cause | Fix |
|-------|-------|-----|
| `-2740` / "A identifier can't go after this" | Wrong parameter name or parameter order | Look up correct parameter names via `sdef`. Check that the direct parameter comes first (unlabeled), then named parameters. |
| `-2741` / "Expected end of line but found identifier" | Missing `end tell`, wrong block nesting, or invalid keyword | Count your `tell`/`end tell` pairs. Check for typos in keywords. |
| `-1728` / "Can't get" | `whose` matched nothing, or wrong property/container name | Broaden the filter. Check property and container names against sdef. Verify the target object exists. |
| `-1712` / "Event timed out" | Operation took longer than 60s default | Add `with timeout of 120 seconds`. Limit results with `messages 1 thru N`. Narrow `whose` filter. |
| `-10004` / "Not authorized to send Apple events" | Missing Automation or Accessibility permission | **Do not retry.** Tell user to enable in System Settings > Privacy & Security. |
| `-1743` / "Can't make X into type Y" | Type coercion failure | Add explicit `as integer`, `as string`, or `as date`. Check that the value matches the expected type in sdef. |
| `-600` / "Connection is invalid" | Target app is not running | The `tell application` block normally auto-launches the app. If still failing, add `activate` before the tell block or `launch` inside it. |
| `-128` / "User canceled" | User clicked Cancel in a dialog | Not a real error — handle gracefully with `try`/`on error`. |

### Common stderr patterns

These are exact strings you'll see in stderr. Match them to diagnose quickly:

| stderr contains | Diagnosis | Action |
|-----------------|-----------|--------|
| `"A identifier can't go after this \""` | Parameter name doesn't exist for this command | Run sdef lookup for the command, use correct parameter names |
| `"Expected end of line but found"` | Block structure broken or unknown keyword | Check `tell`/`end tell` balance, look for typos |
| `"Can't get"` followed by an object reference | Object doesn't exist or filter matched nothing | Verify object exists, broaden `whose`, check spelling |
| `"Can't make"` ... `"into type"` | Wrong type passed to a parameter or coercion | Check sdef for expected type, add explicit coercion |
| `"not allowed to send Apple events"` | Permission not granted | Tell user to enable in System Settings — stop retrying |
| `"not allowed assistive access"` | Accessibility permission missing for UI scripting | Tell user to enable in System Settings > Accessibility |
| `"Connection is invalid"` | App not running or crashed | Try `activate` or `launch`, then retry |
| `"AppleEvent timed out"` | Slow operation | Add `with timeout`, reduce scope |
| `"Expected \"\"\""` or `-2741` with garbled quotes | Smart quote mangling from Bash tool shell | Switch from `osascript -e` to heredoc: `osascript <<'APPLESCRIPT'` |

### Retry example

```
Attempt 1: display notification with title "X" message "Y"
  → stderr: "A identifier can't go after this" (-2740)
  → Diagnosis: "message" is not a valid parameter
  → Action: sdef lookup → correct params are direct-parameter, "with title", "subtitle"

Attempt 2: display notification "Y" with title "X"
  → Success
```
