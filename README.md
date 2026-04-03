# AppleScript Automation Skill

An [agent skill](https://agentskills.io/home) that enables AI coding assistants to automate native macOS applications using AppleScript. The agent dynamically generates AppleScript at runtime — there is no fixed action library.

Supported by 30+ agent products including Claude Code, VS Code/Copilot, Cursor, Gemini CLI, OpenAI Codex, Goose, Roo Code, and more.

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

## How It Works: Progressive Disclosure

This skill follows the [agent skills progressive disclosure](https://agentskills.io/what-are-skills) model, which loads information in three stages to minimize context window usage:

1. **Discovery** — The agent sees only the skill's `name` and `description` from the SKILL.md frontmatter (~100 tokens). This is enough for the agent to decide whether the skill is relevant to the current task.

2. **Activation** — When the agent determines the skill matches the user's request, it loads the full `SKILL.md` instructions (the design philosophy, utilities, workflow, and permissions table).

3. **Execution** — As the agent works through the task, it pulls in `references/patterns.md` only when it needs specific AppleScript snippets. This keeps the reference material out of context until it's actually needed.

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
# Claude Code:
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
  - Bash(python3:*)
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
