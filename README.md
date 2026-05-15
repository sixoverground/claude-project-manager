# Claude Project Manager

A local macOS scheduler that polls GitHub and fires Claude Code routines as soon as phase PRs merge — so a phased implementation plan can advance autonomously while you're away.

```
   ┌──────────────┐    every 30m    ┌──────────────┐
   │   launchd    │ ───────────────▶│  cpm script  │
   └──────────────┘                 └──────┬───────┘
                                           │ poll merged PRs
                                           ▼
                                    ┌──────────────┐
                                    │   GitHub     │
                                    └──────┬───────┘
                                           │ phase N merged
                                           ▼
                                    ┌──────────────┐
                                    │ Claude       │
                                    │ routine      │──▶ opens phase N+1 PR
                                    └──────────────┘
```

## What it does (in 30 seconds)

You break a project into phases, where each phase is one PR. You create a Claude Code routine that knows how to read the plan and open the next PR. `cpm` runs on your Mac every 30 minutes — when it sees the latest phase PR has just merged, it fires the routine to start the next phase. Merge, repeat. Walk away.

## The mental model

Four concepts you need to know:

- **Phased plan** — a markdown file (typically `docs/plans/<name>.md`) in *your project repo* listing the work as a sequence of PRs. Each phase is independently mergeable, small enough to finish in one Claude session.
- **Claude routine** — a saved Claude Code prompt that, when invoked, reads the plan and works on the next phase. One routine per project.
- **Trigger** — the remote handle for a routine. Created in Claude Code; identified by a string like `trig_abc123…`.
- **Orchestrator (`cpm`)** — this tool. Watches your repos on a 30-minute loop and fires triggers when the next phase is ready to start.

## Prerequisites

- macOS (uses launchd for scheduling)
- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) (`claude`), authenticated
- [GitHub CLI](https://cli.github.com/) (`gh`), authenticated to your repos
- `jq` — `brew install jq`

## Quick start (5 minutes)

```bash
git clone git@github.com:sixoverground/claude-project-manager.git
cd claude-project-manager
chmod +x cpm
ln -s "$(pwd)/cpm" /opt/homebrew/bin/cpm   # optional: put cpm on PATH

cpm init        # generate plist + empty projects.json
cpm doctor      # verify gh, jq, claude are installed and authenticated
cpm new <name>  # walk through onboarding your first project
cpm start       # enable the 30-minute launchd scheduler
```

`cpm init` is idempotent — safe to re-run. It won't overwrite your `projects.json` and won't regenerate the plist unless you pass `--force`.

## Concepts

### Phased plan

A phased plan lives at `docs/plans/<plan-name>.md` *in your project repo*. It describes the work as a numbered sequence of PRs, each scoped tightly enough to finish in a single Claude Code session.

The canonical prompt for designing such a plan is at [`prompts/routine.md`](prompts/routine.md). To get it into Claude Code:

```bash
cpm prompt --copy   # copies the prompt to your clipboard
# or
cpm prompt --save docs/plans/my-plan.md   # writes the prompt to a file
```

Paste it into Claude Code in your project repo and describe what you want to build. Claude will produce a plan with a PR sequence table, per-phase scope/risks/acceptance criteria, and an "Autonomous Workflow" section that references `cpm`.

### Claude routine

In Claude Code, a *routine* is a saved prompt you can invoke remotely. For a cpm-managed project, you create one routine per project — its job is "read `docs/plans/<name>.md`, find the next phase, do the work, open a PR."

Use the same prompt from `cpm prompt`. Save it as a routine. The routine's Trigger ID (`trig_…`) is what you put in `projects.json`.

### Trigger

The Trigger ID is how `cpm` calls the routine. `cpm` dispatches via:

```bash
claude -p --allowed-tools "RemoteTrigger" --dangerously-skip-permissions \
  --no-session-persistence \
  "Run the remote trigger with ID trig_… ..."
```

You don't need to remember that — `cpm` handles it. You just need the trigger_id.

### Orchestrator (`cpm`)

A zsh script + launchd plist. Every 30 minutes it walks `projects.json`, checks each project's repos via `gh`, and dispatches the next phase when the previous one merged and no session is currently active. See [How it works](#how-it-works) below or [CLAUDE.md](CLAUDE.md) for the full step-by-step.

## Set up your first project

End-to-end walkthrough — assumes you've already run `cpm init`, `cpm doctor`, and the prerequisites pass.

1. **In your project repo, write a phased plan.**
   ```bash
   cd ~/Code/my-app
   cpm prompt --copy
   ```
   Open Claude Code in that repo. Paste the prompt and add a description of what you want to build. Claude writes `docs/plans/<name>.md`. Review it, then commit and push to `main`.

2. **Create a Claude routine.** In Claude Code, create a new routine using the same prompt. Save it so it persists. Find its Trigger ID in the Claude Code UI or via `claude trigger list` (depending on your Claude Code version).

3. **Register the project with cpm.**
   ```bash
   cpm new my-app
   ```
   The wizard walks you through repos, branch prefix, and trigger_id. If you'd rather pass everything as flags:
   ```bash
   cpm add --name my-app --repo yourorg/my-app --trigger trig_abc123
   ```

4. **Fire phase 0 to kick things off.**
   ```bash
   cpm trigger my-app
   ```
   The routine starts, works on phase 0, opens a PR. Review and merge it. The next time `cpm` runs (within 30 minutes), it sees the merge and dispatches phase 1 automatically.

5. **Watch progress.**
   ```bash
   cpm status   # one-line summary per project
   cpm logs     # tail the orchestrator log
   ```

## Commands

| Command | Description |
|---------|-------------|
| `cpm init`           | One-time setup. Generate plist and empty projects.json. |
| `cpm doctor`         | Verify deps, auth, projects.json, plist, scheduler state. |
| `cpm new <name>`     | Interactive wizard to onboard a new project. |
| `cpm add ...`        | Add a project via flags (scriptable). |
| `cpm remove <name>`  | Delete a project from the registry. |
| `cpm pause <name>`   | Skip this project during runs. |
| `cpm resume <name>`  | Un-pause. |
| `cpm prompt`         | Print the routine prompt. `--copy` to clipboard, `--save <path>` to file. |
| `cpm run`            | Execute the orchestrator once. |
| `cpm start`          | Enable the launchd scheduler (every 30 min). |
| `cpm stop`           | Disable the scheduler. |
| `cpm status`         | Show project states and scheduler status. |
| `cpm logs`           | Tail recent orchestrator logs. |
| `cpm trigger <name>` | Manually dispatch a project's routine. |

## Configuration

### `projects.json`

Each project entry defines the repos to monitor and the routine to dispatch.

```json
{
  "projects": [
    {
      "name": "my-fullstack-app",
      "repos": [
        { "repo": "yourorg/my-app-web" },
        { "repo": "yourorg/my-app-ios" }
      ],
      "trigger_id": "trig_abc123",
      "paused": false
    }
  ]
}
```

| Field | Required | Description |
|-------|----------|-------------|
| `name`          | Yes | Display name. Used in CLI commands. |
| `repos`         | Yes | Array of `{ "repo": "owner/name" }` objects. |
| `trigger_id`    | Yes | The routine's trigger ID (`trig_…`). |
| `branch_prefix` | No  | Branch prefix to monitor. Default: `claude/`. |
| `paused`        | No  | `true` to skip this project. Default: `false`. |

Each repo entry can also override `branch_prefix` if repos within a project use different conventions:

```json
{ "repo": "yourorg/legacy-api", "branch_prefix": "cpm/" }
```

### Multi-repo projects

A single routine can operate across multiple repos. The orchestrator checks all repos before dispatching:

- If **any** repo has an open phase PR, the project is skipped.
- The most recent merge **across all repos** determines dispatch timing.
- If **any** repo has branch activity within 2 hours, the project is skipped.

## How it works

`cpm` checks each project on a 30-minute loop:

1. **Open PR?** Any repo has an open phase PR (matching `branch_prefix`)? → SKIP.
2. **Recent merge?** Find the most recent merged phase PR across all repos. If it was within the last 4 hours, this project is a candidate.
3. **Active session?** If any repo has branch activity within the last 2 hours, → SKIP (a session is likely running).
4. **Dispatch dedup.** Each merged PR gets at most 3 dispatches, spaced 2 hours apart. This prevents runaway dispatches when the routine can't open a new PR quickly enough.
5. **Dispatch.** Fire the routine via `claude -p` + `RemoteTrigger`.

Decision matrix:

| Open PR | Merged (< 4h) | Active branch (< 2h) | Action |
|:-------:|:--------------:|:---------------------:|--------|
| Yes | – | – | SKIP |
| No  | Yes | No  | DISPATCH |
| No  | Yes | Yes | SKIP |
| No  | No  | –   | SKIP |

**Exception:** if a PR was merged more than 4 hours ago with no open PR and no recent activity, `cpm` dispatches anyway — the previous run may have failed.

State is kept in `.cpm-state.json` (gitignored) to track dispatch counts per PR. See [CLAUDE.md](CLAUDE.md) for the full operational narrative.

## Troubleshooting

**`cpm start` says "plist not found"** — Run `cpm init` first to generate the plist.

**`cpm doctor` says `gh auth: not authenticated`** — Run `gh auth login` and follow the prompts.

**"I created a routine but where's the Trigger ID?"** — Triggers are listed under your routine in Claude Code's UI. Depending on your Claude Code version, `claude trigger list` may also work from the CLI. The ID starts with `trig_`.

**Routine fires but no PR appears** — Most often a permission prompt blocking the routine. `cpm` dispatches with `--dangerously-skip-permissions`, which should bypass interactive prompts, but a sandboxed environment can still block. Check `cpm logs` for the dispatch output and Claude Code's own logs for the routine's session.

**Same PR keeps re-dispatching** — `cpm` caps dispatches per merged PR at 3 attempts, spaced 2 hours apart. If you hit the cap, `cpm status` shows "Max retries hit for #N." Usually means the routine isn't producing a new branch — investigate the routine itself.

**Routine runs on the wrong branch** — Check `branch_prefix` in `projects.json`. The default is `claude/`. The routine must produce branches that match.

**How do I see what cpm decided last run?** — `cpm logs` tails the most recent daily log. Look for `[<name>] SKIP: ...` or `[<name>] DISPATCH: ...` lines.

## Logs

Logs live at `~/Library/Logs/claude-orchestrator/`:

- `orchestrator-YYYY-MM-DD.log` — one per day, rotated after 14 days.
- `launchd-stdout.log` / `launchd-stderr.log` — captured launchd output, truncated when over 1 MB.

## Contributing

This repo dogfoods its own orchestrator. Significant changes are organized as phased plans and shipped one phase per PR. See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT — see [LICENSE](LICENSE).
