# AppleScript Automation Skill

An agent skill that enables AI coding assistants to automate native macOS applications using AppleScript. The agent dynamically generates AppleScript at runtime — there is no fixed action library.

## Supported Applications

Reminders, Calendar, Notes, Mail, Finder, Notification Center, System Events, Clipboard, and any other scriptable Mac app.

## Requirements

- macOS (AppleScript is not available on other platforms)
- `osascript` (built-in on macOS)
- Python 3.11+ (for date formatting helpers)

## File Structure

```
applescript/
├── SKILL.md                  # Main skill definition — the entry point agents read
└── references/
    └── patterns.md           # Copy-paste-ready AppleScript snippets for common tasks
```

### `applescript/SKILL.md`

The core skill file. Contains:

- **Design philosophy** — why the agent generates scripts dynamically instead of using a fixed library
- **`run_applescript()` utility** — a Python wrapper for executing AppleScript via `osascript`
- **Date formatting helper** — converts ISO 8601 dates to AppleScript's required format
- **Agent workflow** — step-by-step instructions for how the agent should handle automation requests
- **macOS permissions table** — which apps require user approval and what to expect on first run

### `applescript/references/patterns.md`

A reference library of vetted AppleScript snippets covering:

- Notification Center, Reminders, Calendar, Notes
- Clipboard, Dialogs, System Events / UI Scripting
- Finder, Mail
- Date formatting gotchas (why zero-padded dates break)

These patterns are starting points the agent adapts to each request, not a fixed API.

## Installation

### Claude Code (Superpowers)

Copy the `applescript/` directory into your Superpowers skills directory:

```bash
cp -r applescript/ ~/.claude/skills/applescript/
```

The skill will be automatically discovered by the Superpowers plugin.

### Generic Agent Setup

1. Copy the `applescript/` directory into wherever your agent reads skill definitions.
2. Point your agent's skill loader at `applescript/SKILL.md` as the entry point.
3. Ensure the agent has permission to run `osascript` and `python3` via Bash.

The `allowed-tools` frontmatter in `SKILL.md` declares the required tool permissions:

```yaml
allowed-tools:
  - Bash(osascript:*)
  - Bash(python3:*)
```

## Usage

Once installed, ask your agent to do things like:

- "Remind me to call the dentist tomorrow at 9am"
- "Create a calendar event for Friday at 2pm called Team Sync"
- "Show me my incomplete reminders"
- "Send a notification that the build finished"
- "Draft an email to team@example.com with this week's update"

The agent reads the skill definition, generates the appropriate AppleScript, and executes it on your Mac.

## License

Apache License 2.0 — see [LICENSE](LICENSE) for details.
