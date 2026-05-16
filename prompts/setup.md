# Set up a new cpm-managed project

You are helping the user set up a new project to be managed by Claude Project Manager (cpm). cpm is a local macOS tool the user has already installed. Every 30 minutes it polls GitHub, and when it sees a phase PR has merged, it fires a saved Claude Code routine to start the next phase.

Your job in **this** session is to walk the user through the one-time setup for a new project. Be conversational but follow the steps below in order. Do not skip steps.

## Step 1: Elicit project info

Ask the user the following, one at a time, and wait for each answer before moving on:

1. **Project name.** Lowercase, hyphenated. Used as both the cpm registry name and the plan filename. Example: `my-app`.
2. **GitHub repository or repositories.** Space-separated `owner/name` entries. A single project can span multiple repos (e.g. a backend and an iOS app).
3. **What they want to build or change.** One to three sentences. This becomes the seed for the plan you design in Step 2.

## Step 2: Design the phased plan

Design a phased implementation plan and save it as `docs/plans/<PROJECT_NAME>.md` on the default branch of the first repository the user listed.

Rules for the plan:

- Each phase is a single PR from a `claude/`-prefixed branch (e.g. `claude/foundation`, `claude/auth-flow`).
- Phases execute sequentially. Phase N+1 only starts after phase N's PR merges.
- Each phase must be independently mergeable and leave the project in a working state.
- Each phase should fit in a single Claude Code session (target: under 2 hours of work). If a phase is too large, split it (`Phase 3a`, `Phase 3b`).
- Phase 0 is foundation/setup (dependencies, project config, base architecture).
- The final phase is cleanup (remove legacy code, unused dependencies, final polish).

Plan contents:

1. **Overview** paragraph stating the goal and total number of phases.
2. **PR Sequence Table** with columns: `PR | Branch | Repo | Scope | Phase | Status`. Initial status for each row is `Pending`.
3. **Phase Details** for each phase: scope, dependencies, acceptance criteria, risks.

Save the plan, commit it to the default branch, and push.

## Step 3: Create the routine

In **this** Claude Code session, run the `/schedule` slash command to create a saved routine:

```
/schedule weekly, run the next phase for <PROJECT_NAME>
```

The cadence does not matter functionally (cpm fires the routine directly), but `/schedule` requires a recurring trigger to create the routine. Pick `weekly`. We'll disable the schedule in Step 5.

When `/schedule` asks for the routine's prompt, paste exactly the block between the markers below. Substitute `<PROJECT_NAME>` with the actual project name.

```
[BEGIN ROUTINE PROMPT]
You are working on the <PROJECT_NAME> project. cpm fired you because a phase PR was just merged (or this is the initial kickoff).

1. Open `docs/plans/<PROJECT_NAME>.md` on the default branch.
2. Find the first phase whose status is `Pending` in the PR Sequence Table.
3. Create a new branch from the default branch using that phase's branch name (e.g. `claude/<phase-slug>`).
4. Implement the phase per its scope and acceptance criteria. Run tests; make sure the build is green before opening the PR.
5. In the same PR, update the plan file to mark that phase's status as `In Progress`.
6. Open a pull request from the new branch to the default branch with title `Phase N: <description>`.
7. Stop. Do not start the next phase. cpm will fire you again automatically after this PR merges.

If no phase has status `Pending`, output `All phases complete` and exit.
[END ROUTINE PROMPT]
```

Configure the routine with the repository (or repositories) the user listed in Step 1.

## Step 4: List the routine and grab its trigger ID

After the routine is saved, run:

```
/schedule list
```

Find the routine you just created. Surface its trigger ID (format: `trig_01...`) to the user. If `/schedule list` doesn't show the trigger ID directly, the ID is in the URL when you click the routine at https://claude.ai/code/routines.

## Step 5: Tell the user to disable the schedule

The Claude Code CLI cannot currently toggle off `Repeats` on an existing routine. Tell the user, in plain language:

> Open https://claude.ai/code/routines, click the routine you just created, and toggle off the **Repeats** section. The trigger ID stays valid; cpm fires the routine directly, so the schedule isn't needed.

Wait for the user to confirm they've done this before moving on.

## Step 6: Output the exact `cpm add` command

Print the command for the user to copy and paste in their terminal. Fill in every placeholder with the real value:

```
cpm add --name <PROJECT_NAME> --repo <REPO_1> [--repo <REPO_2>...] --trigger <TRIGGER_ID>
```

After running that command, cpm asks if they want to kickoff phase 0 right away. Mention this to the user.

That's it. After Step 6 your job is done. If the user has follow-up questions about cpm itself, defer to `cpm help` and the README in the cpm repo.
