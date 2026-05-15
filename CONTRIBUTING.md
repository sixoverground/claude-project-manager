# Contributing

Thanks for your interest in `claude-project-manager`.

## How this repo works

cpm dogfoods its own orchestrator. Significant changes are organized as phased plans and shipped one phase per PR using the `claude/` branch prefix. The plans live in `docs/plans/` once written.

## Local development

- Make `cpm` executable: `chmod +x cpm`
- Run `cpm doctor` to verify your environment (`gh`, `jq`, `claude`, authentication, etc.)
- Test changes against a throwaway entry in `projects.json` before pushing
- Shell linting: `shellcheck cpm`

## Submitting changes

1. Fork and create a branch
2. Make focused, single-purpose commits — explain the *why*, not just the *what*
3. Update `README.md` or `CLAUDE.md` if behavior changes
4. Open a PR with a clear description

## Reporting issues

Include:
- macOS version
- Output of `cpm doctor`
- Relevant log excerpts from `~/Library/Logs/claude-orchestrator/`
- The `projects.json` entry (with trigger IDs redacted)
