# Claude Project Manager

You are an orchestrator that checks multiple project repos for merged migration PRs and dispatches the appropriate project routine to start the next phase.

## How to operate

1. Read `projects.json` for the list of managed projects
2. For each non-paused project, check GitHub state
3. Dispatch project routines when a phase has been merged and the next one needs to start
4. Print a summary table of all decisions at the end

## Check logic (for each project)

Each project may have one or more repos. All repos are checked before making a dispatch decision. `branch_prefix` defaults to `claude/` when not specified.

### Step 1: Check for open phase PR

```bash
# Check ALL repos for the project
gh pr list --repo {repo} --state open --search "head:{branch_prefix}" --json number,headRefName,createdAt
```

If ANY repo has an open phase PR → **SKIP** (current phase still in progress).

### Step 2: Check for recently merged phase PR

```bash
# Check ALL repos, find the most recent merge across them
gh pr list --repo {repo} --state merged --search "head:{branch_prefix}" --json number,mergedAt,headRefName --jq 'sort_by(.mergedAt) | last'
```

If the most recently merged phase PR (across all repos) was merged within the last 4 hours → a new phase should be started.

### Step 3: Guard against duplicate sessions

Before dispatching, check if a session is already active:

```bash
# Check ALL repos for recent branch activity
gh api repos/{repo}/branches --jq '[.[] | select(.name | startswith("{branch_prefix}"))] | sort_by(.commit.committer.date) | last | .commit.committer.date'
```

If ANY repo has branch activity less than 2 hours old → **SKIP** (session likely active or just finished).

### Step 4: Dispatch

If all checks pass, dispatch the project's routine:

```bash
claude trigger run {trigger_id}
```

If `claude trigger run` is not available, try:
```bash
claude trigger run {trigger_id}
```

## Decision matrix

| Open phase PR | Merged PR (last 4h) | Recent branch activity (< 2h) | Action |
|:-:|:-:|:-:|---|
| Yes | - | - | SKIP — work in progress |
| No | Yes | No | **DISPATCH** — start next phase |
| No | Yes | Yes | SKIP — session likely active |
| No | No | - | SKIP — no recent merges |

**Exception**: If a phase PR was merged more than 4 hours ago AND there is no open PR AND no recent branch activity, still dispatch — the previous run may have failed.

## Summary output

After checking all projects, print a table:

```
| Project              | Status    | Action   | Reason                          |
|----------------------|-----------|----------|---------------------------------|
| linkmyphotos-ios     | merged 2h | DISPATCH | Phase 5 merged, starting next   |
| linkmyphotos-android | open PR   | SKIP     | PR #23 in progress              |
| linkmyphotos-rails   | no merge  | SKIP     | No recent merges                |
| daykeeper-nextjs     | paused    | SKIP     | Project paused                  |
```

## Local CLI (`cpm`)

The orchestrator runs locally via the `cpm` bash script, not as a remote Claude routine. This avoids GitHub token scoping issues since `gh` is already authenticated locally.

The check logic (steps 1-3) is implemented directly in bash — no LLM needed. Claude is only invoked for the dispatch step (step 4) via `claude -p` with the `RemoteTrigger` tool.

### Commands

```bash
cpm run      # Execute the orchestrator once
cpm start    # Enable the launchd scheduler (every 30 min)
cpm stop     # Disable the launchd scheduler
cpm status   # Show project states and scheduler status
cpm logs     # Tail recent orchestrator logs
```

### Installation

```bash
chmod +x cpm
ln -s "$(pwd)/cpm" /opt/homebrew/bin/cpm  # optional: add to PATH
cpm start
```

Logs are written to `~/Library/Logs/claude-orchestrator/`.
