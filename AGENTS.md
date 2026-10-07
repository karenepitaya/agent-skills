# Karpathy Guidelines

Behavioral guidelines to reduce common LLM coding mistakes, derived from [Andrej Karpathy's observations](https://x.com/karpathy/status/2015883857489522876) on LLM coding pitfalls.

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:

- State your assumptions explicitly — including your assumption about what problem this solves. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists — or if the request looks like a workaround for a different problem — say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" And: can you say why the simplest version fails? If you can't, that's the version you write.

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:

- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:

- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: read your own diff before presenting it. Every changed line must trace directly to the user's request — name any that don't.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:

- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

**Watch it fail first.** A test that never went red proves nothing. If it passes on the first run, break the implementation on purpose and confirm it goes red.

For multi-step tasks, state a brief plan:

```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Before you loop, attack them: name an input that satisfies the criteria and is still wrong. Weak criteria ("make it work") require constant clarification.

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
