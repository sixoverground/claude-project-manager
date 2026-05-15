# Claude Project Manager — Orchestrator Logic

This is the canonical reference for what `cpm` does on each run. For setup and CLI usage, see [README.md](README.md).

## How to operate

1. Read `projects.json` for the list of managed projects.
2. For each non-paused project, check GitHub state.
3. Dispatch project routines when a phase has merged and the next one needs to start.
4. Print a summary table of all decisions at the end.

## Check logic (for each project)

Each project may have one or more repos. All repos are checked before making a dispatch decision. `branch_prefix` defaults to `claude/` when not specified.

### Step 1: Check for open phase PR

```bash
gh pr list --repo {repo} --state open --search "head:{branch_prefix}" --json number,headRefName,createdAt
```

If **any** repo has an open phase PR → **SKIP** (current phase still in progress).

### Step 2: Check for recently merged phase PR

```bash
gh pr list --repo {repo} --state merged --search "head:{branch_prefix}" --json number,mergedAt,headRefName --jq 'sort_by(.mergedAt) | last'
```

If the most recently merged phase PR (across all repos) was merged within the last 4 hours → a new phase should be started.

### Step 3: Guard against duplicate sessions

Use the GraphQL refs API to find the most recent committer date for any branch matching the prefix:

```bash
gh api graphql -f query='query($owner:String!,$repo:String!,$prefix:String!) {
  repository(owner:$owner, name:$repo) {
    refs(refPrefix:$prefix, first:100) {
      nodes { target { ... on Commit { committedDate } } }
    }
  }
}' -F owner=... -F repo=... -F prefix="refs/heads/{branch_prefix}"
```

(The REST `/repos/X/branches` endpoint doesn't return `committer.date`, so GraphQL is required.)

If **any** repo has branch activity less than 2 hours old → **SKIP** (session likely active or just finished).

### Step 4: Dispatch dedup

Each merged PR gets at most 3 dispatches, spaced 2 hours apart. State lives in `.cpm-state.json`. This prevents runaway dispatches when the routine can't open a PR quickly enough for the open-PR / activity guards to detect it.

### Step 5: Dispatch

Fire the routine via:

```bash
claude -p --allowed-tools "RemoteTrigger" --dangerously-skip-permissions \
  --no-session-persistence \
  "Run the remote trigger with ID {trigger_id}. Use the RemoteTrigger tool with action 'run' and trigger_id '{trigger_id}'. Output only the result."
```

## Decision matrix

| Open phase PR | Merged PR (last 4h) | Recent branch activity (< 2h) | Action |
|:-:|:-:|:-:|---|
| Yes | – | – | SKIP — work in progress |
| No | Yes | No | **DISPATCH** — start next phase |
| No | Yes | Yes | SKIP — session likely active |
| No | No | – | SKIP — no recent merges |

**Exception:** If a phase PR was merged more than 4 hours ago AND there is no open PR AND no recent branch activity, still dispatch — the previous run may have failed.

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

## Why local

The orchestrator runs locally via the `cpm` zsh script, not as a remote Claude routine. This avoids GitHub token scoping issues since `gh` is already authenticated on the user's machine. The check logic (steps 1-3) is implemented directly in bash — no LLM needed. Claude is only invoked for the dispatch step via `claude -p` with the `RemoteTrigger` tool.
