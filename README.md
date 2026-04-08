# AppleScript Automation Skill

An [agent skill](https://agentskills.io/home) that enables AI coding assistants to automate native macOS applications using AppleScript. The agent dynamically generates AppleScript at runtime — there is no fixed action library.

Supported by 30+ agent products including Claude Code, VS Code/Copilot, Cursor, Gemini CLI, OpenAI Codex, Goose, Roo Code, and more.

## Supported Applications

Reminders, Calendar, Notes, Mail, Finder, Notification Center, System Events, Clipboard, and any other scriptable Mac app.

## Requirements

- macOS (AppleScript is not available on other platforms)
- `osascript` (built-in on macOS)
- `sdef` (built-in on macOS, used for dictionary lookups)

## File Structure

```
applescript/
├── SKILL.md                            # Main skill definition — the entry point agents read
├── scripts/
│   └── mail/
│       ├── draft-new.applescript       # Draft a new email
│       ├── draft-reply.applescript     # Draft a reply to an email
│       ├── email-to-reminder.applescript   # Create a Reminder from an email
│       └── email-to-calendar.applescript   # Create a Calendar event from an email
└── references/
    ├── scripting-guide.md              # Syntax, error handling, dictionary lookup, retry logic
    ├── script-authoring.md             # How to create and verify new reusable scripts
    ├── notification-center.md          # Display notifications with sound
    ├── reminders.md                    # Create, list, complete reminders
    ├── calendar.md                     # Create events, list calendars, get today's events
    ├── notes.md                        # Create, append, search notes
    ├── clipboard.md                    # Read/write clipboard
    ├── dialogs.md                      # Dialogs, alerts, choose from list
    ├── system-events.md                # UI scripting, keystrokes, menu clicks
    ├── finder.md                       # File and folder operations
    ├── mail.md                         # Compose, send, search email
    └── date-formatting.md              # Date parsing gotchas and helpers
```

### `applescript/SKILL.md`

The core skill file. Contains:

- **Executing AppleScript** — how to run scripts via `osascript` with heredocs
- **Date formatting** — rules for AppleScript's locale-sensitive date parsing
- **Scripting guide** — pointer to syntax, error handling, and dictionary lookup reference
- **Agent workflow** — step-by-step instructions including error diagnosis and retry
- **macOS permissions table** — which apps require user approval and what to expect on first run
- **Ready-made scripts** — pre-built `.applescript` files the agent can run directly

### `applescript/scripts/`

Pre-built `.applescript` files the agent can run directly via `osascript`. These save tokens by avoiding AppleScript generation for common tasks. Each script has a comment header with usage and arguments.

### `applescript/references/`

Each file contains vetted, copy-paste-ready AppleScript snippets for a specific app or topic. The agent loads only the reference files relevant to the current task — this is part of the progressive disclosure model (see below).

## How It Works: Progressive Disclosure

This skill follows the [agent skills progressive disclosure](https://agentskills.io/what-are-skills) model, which loads information in three stages to minimize context window usage:

1. **Discovery** — The agent sees only the skill's `name` and `description` from the SKILL.md frontmatter (~100 tokens). This is enough for the agent to decide whether the skill is relevant to the current task.

2. **Activation** — When the agent determines the skill matches the user's request, it loads the full `SKILL.md` instructions (execution patterns, workflow, and permissions table).

3. **Execution** — As the agent works through the task, it pulls in specific reference files and scripts only when needed. This keeps detailed material out of context until it's actually required.

This means the skill costs almost nothing when it's not in use, and loads just what's needed when it is.

## Installation

### Step 1: Add the skill to your project

Copy the `applescript/` directory into the [cross-client skills directory](https://agentskills.io/client-implementation/adding-skills-support) at the root of your project:

```bash
# Cross-client location (works with Claude Code, Copilot, Cursor, Gemini CLI, etc.)
mkdir -p .agents/skills
cp -r applescript/ .agents/skills/applescript/
```

Or to install at the user level (available across all projects):

```bash
# User-level location (varies by client)
# Claude Code / Claude Desktop:
cp -r applescript/ ~/.claude/skills/applescript/
```

### Step 2: Reference in your system prompt (if needed)

Most skill-aware agents will auto-discover skills in `.agents/skills/`. If your agent requires manual registration, add the skill's name and description to your system prompt or tool catalog so the agent knows it's available:

```
Available skills:
- applescript: Automate native macOS applications using AppleScript via osascript.
  Use when users ask to interact with Reminders, Calendar, Notes, Mail, Finder,
  Notification Center, System Events, or any scriptable Mac app.
```

When the agent activates the skill, it should read `applescript/SKILL.md` and follow the instructions there. The `allowed-tools` frontmatter declares the required tool permissions:

```yaml
allowed-tools:
  - Bash(osascript:*)
  - Bash(sdef:*)
```

Ensure your agent has permission to run these tools via Bash.

## Usage

Once installed, ask your agent to do things like:

- "Remind me to call the dentist tomorrow at 9am"
- "Create a calendar event for Friday at 2pm called Team Sync"
- "Show me my incomplete reminders"
- "Send a notification that the build finished"
- "Draft an email to team@example.com with this week's update"

The agent reads the skill definition, generates the appropriate AppleScript, and executes it on your Mac.

## Customizing the Skill

If you want to modify this skill or create your own, here are the key resources from the [Agent Skills specification](https://agentskills.io/home):

| Topic | Link |
|-------|------|
| What are skills & how progressive disclosure works | [What Are Skills](https://agentskills.io/what-are-skills) |
| SKILL.md format, frontmatter fields, and validation | [Specification](https://agentskills.io/specification) |
| Creating a skill from scratch | [Quickstart](https://agentskills.io/skill-creation/quickstart) |
| Writing effective skill instructions | [Best Practices](https://agentskills.io/skill-creation/best-practices) |
| Writing good trigger descriptions | [Optimizing Descriptions](https://agentskills.io/skill-creation/optimizing-descriptions) |
| Adding scripts to your skill | [Using Scripts](https://agentskills.io/skill-creation/using-scripts) |
| Testing and evaluating skill quality | [Evaluating Skills](https://agentskills.io/skill-creation/evaluating-skills) |
| How agent clients discover and load skills | [Adding Skills Support](https://agentskills.io/client-implementation/adding-skills-support) |

## License

Apache License 2.0 — see [LICENSE](LICENSE) for details.
