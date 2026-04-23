# Phased Plan Design Instructions

You are designing a phased implementation plan for this project. The plan will be executed autonomously by Claude via remote triggers, orchestrated by a central `claude-project-manager` that monitors GitHub for merged PRs and dispatches the next phase.

## Constraints

- Each phase must be a single PR from a `cpm/`-prefixed branch (e.g., `cpm/auth-flow`, `cpm/data-layer`)
- Phases execute sequentially — phase N+1 only starts after phase N's PR is merged
- Each phase must be independently mergeable and leave the project in a working state
- Each phase should be completable in a single Claude session (target: under 2 hours of work)
- If a phase is too large, split it into sub-phases (e.g., `Phase 3a`, `Phase 3b`)

## What to produce

Create a `docs/plans/<PLAN_NAME>.md` file with:

### 1. Overview
- One paragraph describing the goal of this plan
- The total number of phases and estimated timeline

### 2. PR Sequence Table

| PR | Branch | Scope | Phase | Status |
|----|--------|-------|-------|--------|
| 1 | `cpm/foundation` | Project setup, dependencies, base config | Phase 0: Foundation | Pending |
| 2 | `cpm/auth-flow` | Authentication screens and logic | Phase 1: Auth | Pending |
| ... | ... | ... | ... | ... |

### 3. Phase Details

For each phase, include:
- **Scope**: What files/features are added or changed
- **Dependencies**: What must exist from prior phases
- **Acceptance criteria**: How to verify this phase works before merging
- **Risks**: Anything that could block or complicate this phase

### 4. Autonomous Workflow

Include this section verbatim, filling in the project-specific values:

```
Phase progression is managed by a central orchestrator (`claude-project-manager`).

- Orchestrator polls every 30 minutes
- Detects merged `cpm/` PRs and dispatches the next phase via remote trigger
- Branch prefix: `cpm/`
- Trigger ID: [to be assigned after `claude trigger create`]
```

## Multi-repo routines

When a plan spans multiple repos (e.g., a backend and an iOS app), a single routine and trigger handle both. Each phase specifies which repo(s) it targets: one repo, the other, or both.

In the PR Sequence Table, add a **Repo** column:

| PR | Branch | Repo | Scope | Phase | Status |
|----|--------|------|-------|-------|--------|
| 1 | `claude/security` | next | Input validation | Phase 1a | Pending |
| 2 | `claude/metering-ios` | ios | 429 handling | Phase 1b | Pending |
| 3 | `claude/tracking` | both | Shot status + reorder | Phase 2 | Pending |

The orchestrator checks all repos in the group before dispatching — if any repo has an open PR or recent branch activity, the next phase is held.

## Guidelines for phase design

- **Phase 0** should always be foundation/setup — dependencies, project config, base architecture
- **Final phase** should be cleanup — remove legacy code, unused dependencies, final polish
- Group related work into the same phase (e.g., all auth screens together)
- Avoid phases that touch the same files as other phases to minimize merge conflicts
- Each phase's PR title should follow the format: `Phase N: Short Description`
- Prefer many small phases over few large ones — a phase that takes multiple sessions will stall the pipeline
- Include CI/test setup early (Phase 0 or 1) so subsequent phases get automated validation
