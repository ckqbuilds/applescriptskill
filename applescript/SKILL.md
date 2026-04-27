---
name: applescript
description: >-
  Automate native macOS applications using AppleScript via osascript. Use when
  users ask to interact with Reminders, Calendar, Notes, Mail, Finder, Notification
  Center, System Events, or any scriptable Mac app. The agent dynamically generates
  AppleScript tailored to each request — there is no fixed action library. Covers
  creating reminders and calendar events, managing notes, sending notifications,
  reading/writing the clipboard, driving UI elements via System Events, and
  composing Mail messages. Also use when the user wants to generate styled HTML
  output: HTML-bodied email drafts in Mail (via clipboard paste), HTML-to-PDF
  rendering with branded templates (via Swift + WebKit), or any task that
  involves authoring HTML/CSS for delivery on macOS. Includes fast Swift readers
  for Calendar and Reminders (~100x faster than AppleScript reads). macOS only.
  Requires osascript (built-in); swiftc/swift needed for PDF and Swift readers.
license: Apache-2.0
compatibility: macOS only. Requires osascript (built-in, no install).
metadata:
  author: Christopher Quarcoo
  version: "1.0"
allowed-tools:
  - Bash(osascript:*)
  - Bash(sdef:*)
  - Bash(swiftc:*)
  - Bash(swift:*)
---

# AppleScript Automation Skill

## Design Philosophy

This skill does **not** ship a fixed library of actions. Instead, the agent dynamically
generates AppleScript at runtime based on the user's intent. Every macOS app that
supports the AppleScript dictionary can be automated — the reference patterns in
`references/` are starting points, not limits.

## Executing AppleScript

Use `osascript` to run AppleScript. For multi-line scripts, **always use a
heredoc** to avoid smart quote mangling (see `references/scripting-guide.md`):

```bash
osascript <<'APPLESCRIPT'
tell application "Reminders"
    make new reminder in list "Reminders" with properties {name:"Buy milk"}
end tell
APPLESCRIPT
```

To run a saved script file:

```bash
osascript scripts/mail/search-by-sender.applescript "sender@example.com"
```

## Date Formatting

AppleScript parses date strings using the **system's locale format**. The safest
portable format is: `"April 2, 2026 at 3:05:00 PM"`.

**Critical rules:**
- No zero-padding on day or hour: `2` not `02`, `3` not `03`
- Full month name: `April` not `04`
- 12-hour clock with `AM`/`PM`

See [`references/date-formatting.md`](references/date-formatting.md) for
full details on why zero-padded values cause errors.

## Scripting Guide

Before generating any AppleScript, read [`references/scripting-guide.md`](references/scripting-guide.md).
It covers script structure, syntax rules, `whose` filtering, error handling,
output formatting, text item delimiters, and common pitfalls. Following these
patterns significantly increases the chance of first-run success.

## Agent Workflow

When a user asks to automate a macOS app:

1. **Identify the target app** and the operation (create, read, update, delete).
   For requests involving styled output ("a report," "a styled email," "a PDF,"
   "an HTML newsletter"), see **Rendering HTML** below to pick between the
   PDF and Mail-draft paths before doing anything else.
2. **Check permissions** — see the table below. If the app requires approval,
   warn the user before running.
3. **Check for a ready-made script** in `scripts/`. If one exists for the task,
   run it directly with the appropriate arguments — no need to generate AppleScript.
4. **Otherwise, generate AppleScript** dynamically. Read `references/scripting-guide.md`
   for syntax and patterns, then consult the relevant app reference in `references/`.
5. **Handle dates** — if the task involves dates or times, format as
   `"Month D, YYYY at H:MM:SS AM/PM"` with no zero-padding (see Date Formatting above).
6. **Execute** via `osascript` using a heredoc. **If the script
   fails, do not stop.** Read stderr, diagnose using the dictionary lookup and
   error diagnosis sections in `references/scripting-guide.md`, fix the script,
   and retry (up to 3 attempts). Only ask the user for help after exhausting
   retries or hitting a permission error that requires user action.
7. **Parse output** — `osascript` prints the result of the last expression to
   stdout. Parse it to confirm success or extract data.
8. **Save reusable scripts** — If the generated AppleScript handles a discrete,
   reusable task, save it as a `.applescript` file under `scripts/<app>/`.
   Follow the conventions in [`references/script-authoring.md`](references/script-authoring.md).
   Verify it runs correctly before considering the task complete.
9. **Report back** — tell the user what happened in plain language.

## macOS Permissions Table

| Application          | Permission Required                        | First-Run Behavior                          |
|----------------------|--------------------------------------------|---------------------------------------------|
| Reminders            | Reminders access                           | macOS prompts automatically on first use    |
| Calendar             | Calendar access (Full Disk or Calendars)   | macOS prompts automatically on first use    |
| Notes                | Automation permission for Notes.app        | macOS prompts; user must click Allow        |
| Notification Center  | None (display notification is unprompted)   | Works immediately                           |
| System Events / UI   | Accessibility (System Settings > Privacy)  | Must be enabled manually before scripting   |
| Mail (HTML drafts)   | Accessibility (for the ⌘V paste step)     | Same as System Events — enable Accessibility for the calling app |

**Accessibility note**: UI scripting via `System Events` requires the calling app
(e.g., Terminal, iTerm, VS Code) to have Accessibility access. If the script
fails with "not allowed assistive access," instruct the user to enable it in
**System Settings > Privacy & Security > Accessibility**.

## Rendering HTML: Two Output Targets

The agent can generate HTML and render it in two different ways. These are
**distinct capabilities** — pick the one that matches what the user wants.

| User wants…                                  | Output    | How                                                                                  |
|----------------------------------------------|-----------|--------------------------------------------------------------------------------------|
| A document to save, share, or print          | **PDF**   | Compile `scripts/system/html2pdf.swift` once, then render via Swift + WebKit         |
| A styled email they can review and send      | **Mail draft** | Run `scripts/mail/draft-html.applescript` — sets the `html content` property on a new outgoing message |

Both paths start with the agent writing HTML. Authoring patterns (typography,
brand colors, callout boxes, tables) are in
[`references/pdf-generation.md`](references/pdf-generation.md). For email, drop
the `.page` wrapper and fixed page dimensions — see
[`references/html-email.md`](references/html-email.md) for the differences and
for email-client rendering caveats (e.g. Mail's compose view strips `<body>`
backgrounds; bgcolor must go on every section-wrapper `<td>`).

**Note on Mail's dictionary:** `sdef /System/Applications/Mail.app` marks the
`html content` property as deprecated and "does nothing." This is wrong on
modern macOS — verified live, the property does render HTML. Trust the live
behavior for this property; the dictionary description is stale.

## Ready-Made Scripts

Pre-built scripts the agent can run directly. These save tokens by avoiding
AppleScript generation for common tasks.

Scripts are organized by application under `scripts/`:

| Application | Directory | Description |
|-------------|-----------|-------------|
| Mail | `scripts/mail/` | Draft (plain text), draft (HTML body), reply, and cross-app actions (email &#8594; reminder/calendar) |
| Calendar | `scripts/calendar/` | Fast event reads via Swift + EventKit (`calendar-read.swift` &#8212; compile once with `swiftc`) |
| Reminders | `scripts/reminders/` | Fast reminder reads via Swift + EventKit (`reminders-read.swift` &#8212; compile once with `swiftc`) |
| System | `scripts/system/` | PDF generation (`html2pdf.swift` &#8212; compile once with `swiftc`) |

**Why some scripts are Swift, not AppleScript:** AppleScript reads from
Calendar/Reminders are slow (per-property IPC round-trips). Swift via EventKit
is roughly two orders of magnitude faster. AppleScript is still preferred for
writes (creating events, drafting mail) because writes are single-shot.

To use a script, browse the relevant directory and read the comment header at
the top of the file for usage and arguments. AppleScript files run via:

```bash
osascript scripts/<app>/<script>.applescript [args...]
```

Swift files (the readers and the PDF renderer) are compiled once with `swiftc`
— see the comment header in each `.swift` file for the exact command — and then
run as native binaries:

```bash
scripts/calendar/calendar-read --from 2026-04-21 --to 2026-04-25
scripts/system/html2pdf input.html output.pdf
```

Scripts that accept AppleScript date arguments expect strings like
`"April 5, 2026 at 9:00:00 AM"` (see Date Formatting above). Swift readers use
ISO format (`YYYY-MM-DD` or `YYYY-MM-DDTHH:mm`).

The agent should prefer ready-made scripts over generating AppleScript when
a script exists for the task.

## Reference Patterns

Vetted, copy-paste-ready AppleScript snippets are in `references/`, one file per app:

- [`references/scripting-guide.md`](references/scripting-guide.md) — syntax, structure, error handling, and pitfalls (read first)
- [`references/script-authoring.md`](references/script-authoring.md) — how to create, save, and verify new reusable scripts
- [`references/notification-center.md`](references/notification-center.md) — display notifications
- [`references/reminders.md`](references/reminders.md) — create, list, complete reminders
- [`references/calendar.md`](references/calendar.md) — create events, list calendars
- [`references/notes.md`](references/notes.md) — create, append, search notes
- [`references/clipboard.md`](references/clipboard.md) — read/write clipboard
- [`references/dialogs.md`](references/dialogs.md) — dialogs, alerts, choose from list
- [`references/system-events.md`](references/system-events.md) — UI scripting, keystrokes, menu clicks
- [`references/finder.md`](references/finder.md) — file/folder operations
- [`references/mail.md`](references/mail.md) — compose, send, search email (plain text)
- [`references/html-email.md`](references/html-email.md) — HTML-bodied email drafts via clipboard paste
- [`references/date-formatting.md`](references/date-formatting.md) — date parsing gotchas and helpers
- [`references/pdf-generation.md`](references/pdf-generation.md) — HTML-to-PDF pipeline, page layout, templates

These patterns are starting points. The agent should adapt and compose them to
match exactly what the user needs. Only load the reference files relevant to the
current task.

## Note: Always AppleScript, Never JXA

Always use AppleScript, never JavaScript for Automation (JXA). JXA has unfixed
bugs, scarce documentation, and incomplete app support. Apple hasn't actively
developed it since 2016. AppleScript is more reliable, better documented, and
works consistently across all macOS versions.
