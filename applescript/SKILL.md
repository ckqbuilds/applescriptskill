---
name: applescript
description: >-
  Automate native macOS applications using AppleScript via osascript. Use when
  users ask to interact with Reminders, Calendar, Notes, Mail, Finder, Notification
  Center, System Events, or any scriptable Mac app. The agent dynamically generates
  AppleScript tailored to each request — there is no fixed action library. Covers
  creating reminders and calendar events, managing notes, sending notifications,
  reading/writing the clipboard, driving UI elements via System Events, and
  composing Mail messages. macOS only. Requires osascript (built-in) and Python 3.11+
  for date formatting.
license: Apache-2.0
compatibility: macOS only. Requires osascript (built-in, no install). Python 3.11+ for date formatting.
metadata:
  author: Christopher Quarcoo
  version: "1.0"
allowed-tools:
  - Bash(osascript:*)
  - Bash(python3:*)
---

# AppleScript Automation Skill

## Design Philosophy

This skill does **not** ship a fixed library of actions. Instead, the agent dynamically
generates AppleScript at runtime based on the user's intent. Every macOS app that
supports the AppleScript dictionary can be automated — the reference patterns in
`references/patterns.md` are starting points, not limits.

### Why AppleScript, Never JXA

JavaScript for Automation (JXA) was introduced in OS X Yosemite as an alternative
to AppleScript. **Always prefer AppleScript over JXA** for these reasons:

1. **Reliability** — JXA has known, unfixed bugs with `StandardAdditions`, date
   handling, and `System Events` UI scripting that cause silent failures.
2. **Documentation** — Nearly all Apple scripting documentation, Stack Overflow
   answers, and app dictionaries target AppleScript. JXA examples are scarce.
3. **App support** — Some apps expose AppleScript-only scripting suites. JXA
   bridges can miss properties or fail on complex record types.
4. **Stability** — Apple has not actively developed JXA since 2016. AppleScript
   continues to receive maintenance and works reliably on every macOS release.

## Shared Utility — `run_applescript()`

Use this Python wrapper for all AppleScript execution. It handles error reporting
and returns stdout cleanly.

```python
import subprocess, sys

def run_applescript(script: str) -> str:
    """Execute an AppleScript string via osascript and return stdout."""
    result = subprocess.run(
        ["osascript", "-e", script],
        capture_output=True, text=True
    )
    if result.returncode != 0:
        print(f"AppleScript error: {result.stderr.strip()}", file=sys.stderr)
        sys.exit(1)
    return result.stdout.strip()
```

For multi-line scripts, pass each line as a separate `-e` argument or use a
heredoc in Bash:

```bash
osascript <<'APPLESCRIPT'
tell application "Reminders"
    set newReminder to make new reminder in list "Reminders" with properties {name:"Buy milk"}
end tell
APPLESCRIPT
```

## Date Formatting Helper

AppleScript parses date strings using the **system's locale format**. The safest
portable format is: `"April 2, 2026 at 3:05:00 PM"`.

```python
from datetime import datetime

def format_applescript_date(iso_str: str) -> str:
    """Convert ISO 8601 to AppleScript-safe date string.

    Uses %-d and %-I to avoid zero-padding, which AppleScript
    rejects on most locale configurations.
    """
    dt = datetime.fromisoformat(iso_str)
    return dt.strftime("%B %-d, %Y at %-I:%M:%S %p")
```

**Critical**: See the "Date Formatting Gotchas" section in `references/patterns.md`
for why `%-d` and `%-I` are required.

## Agent Workflow

When a user asks to automate a macOS app:

1. **Identify the target app** and the operation (create, read, update, delete).
2. **Check permissions** — see the table below. If the app requires approval,
   warn the user before running.
3. **Generate AppleScript** dynamically. Use `references/patterns.md` as a
   starting point, then adapt to the exact request.
4. **Handle dates** — if the task involves dates or times, use `format_applescript_date()`
   to convert from ISO 8601.
5. **Execute** via `run_applescript()` or `osascript` in Bash.
6. **Parse output** — `osascript` prints the result of the last expression to
   stdout. Parse it to confirm success or extract data.
7. **Report back** — tell the user what happened in plain language.

## macOS Permissions Table

| Application          | Permission Required                        | First-Run Behavior                          |
|----------------------|--------------------------------------------|---------------------------------------------|
| Reminders            | Reminders access                           | macOS prompts automatically on first use    |
| Calendar             | Calendar access (Full Disk or Calendars)   | macOS prompts automatically on first use    |
| Notes                | Automation permission for Notes.app        | macOS prompts; user must click Allow        |
| Notification Center  | None (display notification is unprompted)   | Works immediately                           |
| System Events / UI   | Accessibility (System Settings > Privacy)  | Must be enabled manually before scripting   |

**Accessibility note**: UI scripting via `System Events` requires the calling app
(e.g., Terminal, iTerm, VS Code) to have Accessibility access. If the script
fails with "not allowed assistive access," instruct the user to enable it in
**System Settings > Privacy & Security > Accessibility**.

## Reference Patterns

See [`references/patterns.md`](references/patterns.md) for vetted, copy-paste-ready
AppleScript snippets covering Notification Center, Reminders, Calendar, Notes,
Clipboard, Dialogs, System Events, Finder, and Mail.

These patterns are starting points. The agent should adapt and compose them to
match exactly what the user needs.
