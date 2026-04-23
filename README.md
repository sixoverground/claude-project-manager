# Claude Project Manager

A local orchestrator that monitors GitHub repos for merged phase PRs and dispatches Claude routines to start the next phase automatically.

## How it works

Claude Project Manager (`cpm`) runs on a 30-minute schedule via macOS launchd. For each project in your registry, it:

1. Checks all repos for open phase PRs (branch prefix `claude/` by default)
2. Finds the most recently merged phase PR across all repos
3. Guards against dispatching into an active session (branch activity < 2h)
4. Dispatches the project's Claude routine via `claude trigger run`

This keeps phased plans moving without manual intervention — merge a PR, and the next phase starts automatically.

## Prerequisites

- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) (`claude`)
- [GitHub CLI](https://cli.github.com/) (`gh`) authenticated to your repos
- `jq` for JSON parsing
- macOS (uses launchd for scheduling)

## Setup

```bash
# Clone the repo
git clone git@github.com:sixoverground/claude-project-manager.git
cd claude-project-manager

# Create your projects registry from the example
cp example-projects.json projects.json
# Edit projects.json with your repos and trigger IDs

# Make cpm executable
chmod +x cpm

# Optional: add to PATH
ln -s "$(pwd)/cpm" /opt/homebrew/bin/cpm
```

## Commands

```bash
cpm run      # Execute the orchestrator once
cpm start    # Enable the launchd scheduler (every 30 min)
cpm stop     # Disable the launchd scheduler
cpm status   # Show project states and scheduler status
cpm logs     # Tail recent orchestrator logs
```

## Configuration

### projects.json

Each project entry defines the repos to monitor and the Claude routine to trigger.

```json
{
  "projects": [
    {
      "name": "my-fullstack-app",
      "repos": [
        { "repo": "yourorg/my-app-web" },
        { "repo": "yourorg/my-app-ios" }
      ],
      "trigger_id": "trig_YOUR_TRIGGER_ID",
      "paused": false
    }
  ]
}
```

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Display name for the project |
| `repos` | Yes | Array of `{ "repo": "owner/name" }` objects |
| `trigger_id` | Yes | Claude routine trigger ID (`claude trigger list`) |
| `branch_prefix` | No | Branch prefix to monitor (default: `claude/`) |
| `paused` | No | Set `true` to skip this project (default: `false`) |

Each repo entry can also override `branch_prefix` if repos within a project use different conventions.

### Multi-repo projects

A single routine can operate across multiple repos. The orchestrator checks all repos before dispatching:

- If **any** repo has an open phase PR, the project is skipped
- The most recent merge **across all repos** determines dispatch timing
- If **any** repo has branch activity within 2 hours, the project is skipped

### Branch prefix

The default branch prefix is `claude/`. Phase PRs use branches like `claude/auth-flow`, `claude/data-layer`, etc. Override per-project or per-repo if needed.

## Decision logic

| Open PR | Merged (< 4h) | Active branch (< 2h) | Action |
|:-------:|:--------------:|:---------------------:|--------|
| Yes | - | - | SKIP |
| No | Yes | No | DISPATCH |
| No | Yes | Yes | SKIP |
| No | No | - | SKIP |

**Exception:** If a PR was merged more than 4 hours ago with no open PR and no recent activity, it dispatches anyway (the previous run may have failed).

## Logs

Logs are written to `~/Library/Logs/claude-orchestrator/`. Log files rotate daily and are cleaned up after 14 days.

## Phased plan design

See [EXAMPLE_PROMPT.md](EXAMPLE_PROMPT.md) for a prompt template you can use when having Claude design a phased implementation plan compatible with this orchestrator.
