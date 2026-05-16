# Claude Project Manager

A local macOS scheduler that polls GitHub and fires Claude Code routines as soon as phase PRs merge, so a phased implementation plan can advance autonomously while you're away.

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

You break a project into phases, where each phase is one PR. You create a Claude Code routine that knows how to read the plan and open the next PR. `cpm` runs on your Mac every 30 minutes. When it sees the latest phase PR has just merged, it fires the routine to start the next phase. Merge, repeat. Walk away.

## The mental model

Four concepts you need to know:

- **Phased plan**: a markdown file (typically `docs/plans/<name>.md`) in *your project repo* listing the work as a sequence of PRs. Each phase is independently mergeable, small enough to finish in one Claude session.
- **Claude routine**: a saved Claude Code prompt that, when invoked, reads the plan and works on the next phase. One routine per project.
- **Trigger**: the remote handle for a routine. Created in Claude Code; identified by a string like `trig_abc123...`.
- **Claude Project Manager (`cpm`)**: this tool. Watches your repos on a 30-minute loop and fires triggers when the next phase is ready to start.

## Prerequisites

- macOS (uses launchd for scheduling)
- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) (`claude`), authenticated
- [GitHub CLI](https://cli.github.com/) (`gh`), authenticated to your repos
- `jq` (`brew install jq`)

## Quick start (5 minutes)

```bash
brew install sixoverground/tap/cpm

cpm init        # check deps, generate plist + empty projects.json, offer to start the scheduler
cpm new         # copy the new-project setup prompt to your clipboard
```

Then paste that prompt into Claude Code in your project repo. Claude does the rest and tells you the exact `cpm add` command to run when it's done. See [Set up your first project](#set-up-your-first-project) for the full walkthrough.

`cpm init` is idempotent and safe to re-run. It won't overwrite your `projects.json` and won't regenerate the plist unless you pass `--force`.

### File layout

After installation:

- **Bundled assets** (templates, prompts) live under `$(brew --prefix)/share/cpm/` (typically `/opt/homebrew/share/cpm/`). `brew upgrade cpm` rewrites these.
- **Your data** lives under `~/.cpm/`: `projects.json`, the rendered launchd plist, and `.cpm-state.json`. Brew never touches this directory.
- **Logs** live under `~/Library/Logs/claude-project-manager/`.
- **The launchd plist** is installed to `~/Library/LaunchAgents/claude-project-manager.plist` by `cpm start`.

You can override `CPM_SHARE` and `CPM_DATA` via environment variables if you want non-default locations (mostly useful when developing cpm itself).

### Develop in-tree

If you'd rather hack on cpm directly instead of installing via brew:

```bash
git clone git@github.com:sixoverground/claude-project-manager.git
cd claude-project-manager
chmod +x cpm
ln -s "$(pwd)/cpm" /opt/homebrew/bin/cpm   # optional: put cpm on PATH

cpm init   # auto-detects the in-tree templates/ and prompts/ as CPM_SHARE
```

In dev mode, `CPM_SHARE` is set to the cloned repo automatically. `CPM_DATA` still defaults to `~/.cpm/` so you're working against the same project registry you'd use under a brew install.

## Concepts

### Phased plan

A phased plan lives at `docs/plans/<plan-name>.md` *in your project repo*. It describes the work as a numbered sequence of PRs, each scoped tightly enough to finish in a single Claude Code session. You don't write this yourself; Claude Code drafts it during `cpm new` (see the walkthrough below).

### Claude routine

In Claude Code, a *routine* is a saved prompt that runs autonomously in the cloud when invoked. For a cpm-managed project, you create one routine per project. Its job is to read `docs/plans/<name>.md`, find the next Pending phase, do the work, and open a PR. cpm fires the routine each time the previous phase's PR merges.

### Trigger

The Trigger ID (`trig_...`) is how cpm calls a routine. cpm dispatches via:

```bash
claude -p --allowed-tools "RemoteTrigger" --dangerously-skip-permissions \
  --no-session-persistence \
  "Run the remote trigger with ID trig_... ..."
```

You don't need to remember that. cpm handles it. You just need to record the trigger_id in your registry, which `cpm add` does for you.

### Claude Project Manager (`cpm`)

A zsh script + launchd plist. Every 30 minutes it walks `projects.json`, checks each project's repos via `gh`, and dispatches the next phase when the previous one merged and no session is currently active. See [How it works](#how-it-works) below or [CLAUDE.md](CLAUDE.md) for the full step-by-step.

## Set up your first project

End-to-end walkthrough. Assumes you've already run `cpm init` and the prerequisites pass.

1. **Run `cpm new`.**
   ```bash
   cpm new
   ```
   This copies the new-project setup prompt to your clipboard and tells you what to do next. No arguments needed.

2. **Open Claude Code in your project repo and paste the prompt.**
   ```bash
   cd ~/Code/my-app
   claude
   ```
   Then paste from your clipboard. Claude walks you through the whole setup:
   - Asks for the project name, repo(s), and what you want to build
   - Designs a phased plan and writes it to `docs/plans/<name>.md` (committed to main)
   - Creates a routine via `/schedule` with the right execution prompt
   - Surfaces the routine's trigger ID
   - Tells you to toggle off **Repeats** at [claude.ai/code/routines](https://claude.ai/code/routines) (the CLI can't disable a routine's schedule yet)
   - Ends by printing an exact `cpm add` command for you to copy

3. **Run the `cpm add` command Claude gave you.**
   ```bash
   cpm add --name my-app --repo yourorg/my-app --trigger trig_01ABCDE...
   ```
   cpm appends the project to `projects.json` and asks if you want to kickoff phase 0 now. Say Y to fire the routine immediately. If you'd rather skip that, say n and run `cpm trigger my-app` whenever you're ready.

4. **Watch progress.**
   ```bash
   cpm status   # one-line summary per project
   cpm logs     # tail the run log
   ```
   Once phase 0's PR is opened, review and merge it. The next time `cpm` runs (within 30 minutes), it sees the merge and dispatches phase 1 automatically. Repeat until done.

If you closed your terminal mid-setup, you can recover by running `cpm add` with no arguments. It will prompt for the project name, repo(s), and trigger ID; the trigger ID is visible via `/schedule list` in any Claude Code session, or as part of the URL at [claude.ai/code/routines](https://claude.ai/code/routines).

## Commands

| Command | Description |
|---------|-------------|
| `cpm init`           | One-time setup. Checks deps, generates plist + empty projects.json, optionally starts the scheduler. |
| `cpm doctor`         | Verify deps, auth, projects.json, plist, scheduler state. |
| `cpm new`            | Copy the new-project setup prompt to the clipboard. |
| `cpm add ...`        | Register a project (flag-based, or interactive when called with no flags). |
| `cpm remove <name>`  | Delete a project from the registry. |
| `cpm pause <name>`   | Skip this project during runs. |
| `cpm resume <name>`  | Un-pause. |
| `cpm run`            | Execute cpm once (check all projects, dispatch as needed). |
| `cpm start`          | Enable the launchd scheduler (every 30 min). |
| `cpm stop`           | Disable the scheduler. |
| `cpm status`         | Show project states and scheduler status. |
| `cpm logs`           | Tail recent cpm logs. |
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
| `trigger_id`    | Yes | The routine's trigger ID (`trig_...`). |
| `branch_prefix` | No  | Branch prefix to monitor. Default: `claude/`. |
| `paused`        | No  | `true` to skip this project. Default: `false`. |

Each repo entry can also override `branch_prefix` if repos within a project use different conventions.

### Multi-repo projects

A single routine can operate across multiple repos. cpm checks all repos before dispatching:

- If **any** repo has an open phase PR, the project is skipped.
- The most recent merge **across all repos** determines dispatch timing.
- If **any** repo has branch activity within 2 hours, the project is skipped.

## How it works

`cpm` checks each project on a 30-minute loop:

1. **Open PR?** Any repo has an open phase PR (matching `branch_prefix`)? If so, SKIP.
2. **Recent merge?** Find the most recent merged phase PR across all repos. If it was within the last 4 hours, this project is a candidate.
3. **Active session?** If any repo has branch activity within the last 2 hours, SKIP (a session is likely running).
4. **Dispatch dedup.** Each merged PR gets at most 3 dispatches, spaced 2 hours apart. This prevents runaway dispatches when the routine can't open a new PR quickly enough.
5. **Dispatch.** Fire the routine via `claude -p` + `RemoteTrigger`.

Decision matrix:

| Open PR | Merged (< 4h) | Active branch (< 2h) | Action |
|:-------:|:--------------:|:---------------------:|--------|
| Yes | any | any | SKIP |
| No  | Yes | No  | DISPATCH |
| No  | Yes | Yes | SKIP |
| No  | No  | any | SKIP |

**Exception:** if a PR was merged more than 4 hours ago with no open PR and no recent activity, `cpm` dispatches anyway. The previous run may have failed.

State is kept in `.cpm-state.json` (gitignored) to track dispatch counts per PR. See [CLAUDE.md](CLAUDE.md) for the full operational narrative.

## Troubleshooting

**`cpm start` says "plist not found".** Run `cpm init` first to generate the plist.

**`cpm doctor` says `gh auth: not authenticated`.** Run `gh auth login` and follow the prompts.

**"I created a routine but where's the Trigger ID?"** Triggers are listed under your routine in Claude Code's UI. Depending on your Claude Code version, `claude trigger list` may also work from the CLI. The ID starts with `trig_`.

**Routine fires but no PR appears.** Most often a permission prompt blocking the routine. `cpm` dispatches with `--dangerously-skip-permissions`, which should bypass interactive prompts, but a sandboxed environment can still block. Check `cpm logs` for the dispatch output and Claude Code's own logs for the routine's session.

**Same PR keeps re-dispatching.** `cpm` caps dispatches per merged PR at 3 attempts, spaced 2 hours apart. If you hit the cap, `cpm status` shows "Max retries hit for #N." Usually means the routine isn't producing a new branch, so investigate the routine itself.

**Routine runs on the wrong branch.** Check `branch_prefix` in `projects.json`. The default is `claude/`. The routine must produce branches that match.

**How do I see what cpm decided last run?** `cpm logs` tails the most recent daily log. Look for `[<name>] SKIP: ...` or `[<name>] DISPATCH: ...` lines.

## Logs

Logs live at `~/Library/Logs/claude-project-manager/`:

- `cpm-YYYY-MM-DD.log` is the daily run log, rotated after 14 days.
- `launchd-stdout.log` / `launchd-stderr.log` capture launchd output, truncated when over 1 MB.

## Contributing

This repo dogfoods itself. Significant changes are organized as phased plans and shipped one phase per PR. See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT. See [LICENSE](LICENSE).
