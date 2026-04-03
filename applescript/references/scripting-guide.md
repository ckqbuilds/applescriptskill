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

### Inline scripts (heredoc or `-e`)

For one-off execution without a file:

```bash
osascript <<'APPLESCRIPT'
tell application "Reminders"
    make new reminder in list "Reminders" with properties {name:"Buy milk"}
end tell
APPLESCRIPT
```

Or single-line:

```bash
osascript -e 'display notification "Done" with title "Build"'
```

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
