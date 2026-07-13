# Claude Project Manager: Run Logic

This is the canonical reference for what `cpm` does on each run. For setup and CLI usage, see [README.md](README.md).

## How to operate

1. Read `projects.json` for the list of managed projects.
2. For each non-paused project, check GitHub state.
3. Dispatch project routines when a phase has merged and the next one needs to start.
4. Print a summary table of all decisions at the end.

## Check logic (for each project)

Each project may have one or more repos. All repos are checked before making a dispatch decision. `branch_prefix` defaults to `claude/` when not specified. `target_branch` is optional; when set, it is appended to the PR search as `base:{target_branch}` so only PRs targeting that branch count. Both fields can be overridden per repo inside a project.

### Step 1: Check for open phase PR

```bash
gh pr list --repo {repo} --state open --search "head:{branch_prefix}" --json number,headRefName,baseRefName
```

When `target_branch` is configured, ` base:{target_branch}` is appended to the search string so only PRs targeting that base count.

If **any** repo has an open phase PR, SKIP (current phase still in progress).

### Step 2: Check for recently merged phase PR

```bash
gh pr list --repo {repo} --state merged --search "head:{branch_prefix}" --json number,mergedAt,headRefName,baseRefName --jq 'sort_by(.mergedAt) | last'
```

Same `base:{target_branch}` rule applies when configured.

If the most recently merged phase PR (across all repos) was merged within the last 4 hours, a new phase should be started.

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

If **any** repo has branch activity less than 2 hours old, SKIP (session likely active or just finished).

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
| Yes | any | any | SKIP (work in progress) |
| No | Yes | No | **DISPATCH** (start next phase) |
| No | Yes | Yes | SKIP (session likely active) |
| No | No | any | SKIP (no recent merges) |

**Exception:** If a phase PR was merged more than 4 hours ago AND there is no open PR AND no recent branch activity, still dispatch. The previous run may have failed.

### YOLO mode overlay

When a project has `"yolo": true`, an additional branch runs whenever there is an open phase PR. Before falling through to SKIP, cpm attempts to auto-merge:

| Open phase PR | YOLO gates pass | Under cap + past cooldown | Action |
|:-:|:-:|:-:|---|
| Yes | Yes | Yes | **MERGE** (then SKIP for this run; next run dispatches next phase) |
| Yes | Yes | No  | SKIP (logged as YOLO COOLDOWN or YOLO STUCK) |
| Yes | No  | any | SKIP (gate diagnostic logged) |

The merge is `gh pr merge <pr> --squash --delete-branch`. The next cpm cycle handles the dispatch via the existing path.

## YOLO check logic

All five gates must pass before cpm calls `gh pr merge`:

1. **Not draft.** `gh pr view <pr> --json isDraft` is `false`.
2. **No blocking labels.** PR carries none of `do-not-merge`, `wip`, `blocked` (hardcoded for now).
3. **CI green.** `gh pr checks <pr> --json state` has zero `PENDING|IN_PROGRESS|QUEUED` rows and every other row is either `SUCCESS` or `SKIPPED`. Any other state (`FAILURE`, `ERROR`, `CANCELLED`, `TIMED_OUT`, `NEUTRAL`, `ACTION_REQUIRED`, `STARTUP_FAILURE`, `STALE`) blocks. At least one check must exist (zero checks is treated as failsafe-block).
4. **No `CHANGES_REQUESTED` outstanding.** For each reviewer, only their latest review counts. The check passes when no reviewer's most recent review is `CHANGES_REQUESTED` (which means a CHANGES_REQUESTED that the same reviewer later superseded with an APPROVE or COMMENT no longer blocks).
5. **AI reviewer satisfied.** Reviewer-agnostic and anchored to the reviewed commit SHA (no timestamps, no marker commits). Gate 5 passes when BOTH hold, via a single GraphQL query for `headRefOid`, `reviews { author.login, commit.oid }`, and `reviewThreads { isResolved }`:
   - A configured reviewer login has a review whose `commit.oid == headRefOid` (the reviewer evaluated the current head). Login matching is case-insensitive and strips a trailing `[bot]`, because GraphQL reports bot actors without that suffix.
   - Every `reviewThread` on the PR has `isResolved == true`.

   The reviewer login list is configured per project via `yolo_reviewer` (repo-overridable). Omitted defaults to Copilot (`copilot-pull-request-reviewer`, `github-copilot`, `copilot`). `"yolo_reviewer": false` skips gate 5 entirely. Because only diff-anchored review comments form resolvable threads, the reviewer must post **inline** review comments (Copilot does natively; Claude's review workflow must be set to inline review submission), and re-review-on-push should be enabled so `commit.oid` tracks the head (Copilot: "Review new pushes" ruleset; Claude: `synchronize` trigger). The dispatched routine addresses each thread and resolves it via the `resolveReviewThread` GraphQL mutation; a human can un-resolve to block.

### State + dedup

YOLO attempts are recorded in `.cpm-state.json` alongside dispatch state:

```json
{
  "project-name": {
    "last_dispatched_for_pr": "...",
    "last_dispatched_at": "...",
    "dispatch_count": 1,
    "last_yolo_attempt_for_pr": "owner/repo#42",
    "last_yolo_attempt_at": "2026-06-01T14:00:00Z",
    "yolo_attempt_count": 1
  }
}
```

`YOLO_ATTEMPT_MAX=5` per PR, `YOLO_COOLDOWN_HOURS=1` between attempts. Hitting the cap logs `YOLO STUCK` and surfaces in `cpm status`.

## Summary output

After checking all projects, print a table:

```
| Project              | Status    | Action   | Reason                          |
|----------------------|-----------|----------|---------------------------------|
| acme-ios             | merged 2h | DISPATCH | Phase 5 merged, starting next   |
| acme-android         | open PR   | SKIP     | PR #23 in progress              |
| acme-rails           | no merge  | SKIP     | No recent merges                |
| widget-nextjs        | paused    | SKIP     | Project paused                  |
```

## Why local

cpm runs locally via the `cpm` zsh script, not as a remote Claude routine. This avoids GitHub token scoping issues since `gh` is already authenticated on the user's machine. The check logic (steps 1-3) is implemented directly in bash, with no LLM needed. Claude is only invoked for the dispatch step via `claude -p` with the `RemoteTrigger` tool.
