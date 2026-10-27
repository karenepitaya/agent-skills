# AGENTS.md

Agents in this repo follow [`agent-constitution/SKILL.md`](agent-constitution/SKILL.md).

## Project Constraints

**Toolchain defaults. Don't substitute without asking.**

Python:

- Use `uv` for environments and dependencies. Don't hand-roll `venv`, don't `pip install` into an ambient interpreter.
- `uv add` / `uv remove` to change dependencies, `uv run <cmd>` to execute inside the project environment, `uv sync` to reconcile from the lockfile.
- `uv.lock` is committed. Treat a lockfile change as part of the diff, not noise.

Frontend:

- `pnpm` is the package manager. Not npm, not yarn — a second lockfile is a bug, not a style difference.
- `pnpm add` to install, `pnpm dlx` instead of `npx`.
- `pnpm-lock.yaml` is committed.

Windows:

- Use `pwsh` (PowerShell 7+), not `cmd.exe` and not Windows PowerShell 5.1.
- Write PowerShell, not bash in disguise: `$env:NAME` for environment variables, `Join-Path` for paths, PowerShell cmdlets instead of assuming `sed`, `grep`, or `rm -rf` exist.
- If a script must run on both Windows and POSIX, say so and pick one portable mechanism — don't emit two divergent copies.

The test: a fresh clone plus the documented command works, with no manual environment steps in between.
