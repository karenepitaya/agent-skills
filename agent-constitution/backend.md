# Backend

Decisions, not a stack. Project `AGENTS.md` wins; name a bent rule. Trust boundary: what you do not control. Output → `checks.md`.

## 1. Stack <!-- R1 -->

**Rule:** From existing code, skills, operations, lifespan — not familiarity. One sentence: the choice and each rejection. Prefer boring; justify novelty by risk. A dependency says why this stack cannot. No framework for one function. Do not hand-roll the standard library.
**Why:** fashion is not a constraint.
**The test:** That sentence on every new dependency or service. "Popular" or "standard practice" fails.

## 2. Noise <!-- R1, R3 -->

**Rule:** Inside: validate once, then trust. No catch you cannot handle; no catch-log-continue. No code for what types, schema, or constraints forbid — fix the boundary. No silent fallback (guessed config, assumed timezone, empty required value); fail at startup. One caller: no abstraction, no spare knobs. Comments say why, not what. No commented-out code, changelog comments, or TODOs. Logs: transitions and failures, not entry/exit.
**Why:** repeated checks are chatter.
**The test:** For each try/catch, validation, and fallback: the failure, and the caller gain. Delete "just in case" and what-comments.

## 3. Data <!-- R2 -->

**Rule:** Model and invariants before endpoints, enforced beside the data (constraints, transactions), not in callers or the UI. Each write names the invariant and the layer. One source of truth per fact. Label derived or cached state and its invalidation.
**Why:** callers do not enforce it.
**The test:** Name both. "The caller checks" is a bug.

## 4. Contract <!-- R2 -->

**Rule:** One error shape, machine-readable codes; no parsing prose. Validate once (§2). Breaking changes are versioned, migrated, or rejected — never silent. Client errors say what to do; no stack, schema, or query.
**Why:** the promise comes first.
**The test:** One shape; every failure is handleable without prose.

## 5. Outside <!-- R2 -->

**Rule:** Each external call: timeout, retry or explicit no-retry, and caller-visible failure. Retries are idempotent or forbidden. Name what the user sees when X is down. Fail loudly or degrade on purpose; do not swallow.
**Why:** silence is not a policy.
**The test:** Timeout, retries, down-behavior — per call.

## 6. Concurrency <!-- R2 -->

**Rule:** Assume twice, out of order, or concurrent. Transactions stay small and never wrap a network call. Name shared state: owner, writers, reader consistency. Writes are idempotent or guarded.
**Why:** double submits happen.
**The test:** "Twice at once — what happens?" Not "probably fine".

## 7. Integrity <!-- P15 -->

**Rule:** Schema changes ship a migration, reversible or the reason not. No destructive op without backup or export. No unaudited hand-edit of production. Review the migration as code.
**Why:** it rewrites history.
**The test:** Rollback, and rows written since, in the change notes.

## 8. Observe <!-- R2 -->

**Rule:** Correlation ID through logs and downstream calls. Logs alone diagnose. Log decisions only — never secrets, credentials, or full payloads. Health splits process-up from dependencies-up.
**Why:** local repro means logging failed.
**The test:** "User X at 14:03" finds the request and the failing call.

## 9. Security <!-- P16, P17 -->

**Rule:** Each endpoint states authorization. Deny by default; "internal" is not a rule. Validate, parameterize, escape. Secrets from the environment or a secret store — not code, logs, or the diff. Ship closed.
**Why:** open defaults fail quietly.
**The test:** Grep secrets (raw in `checks.md`). Each new endpoint names its rule.

## 10. Tests <!-- P13 -->

**Rule:** Test at HTTP or the database. Mock only real externals, never your own code. Red first (SKILL.md). Deleting the feature goes red, else delete the tests. Names: behavior and expectation, not method names.
**Why:** the test can share the bug.
**The test:** Name the test that goes red if the endpoint disappears. Else write it.

## 11. Speed <!-- R2 -->

**Rule:** No optimization without a measurement. List pagination and a max page size. Know queries per request; N+1 is a bug. Indexes follow queries, in that migration. A cache states invalidation (§3).
**Why:** unbounded work shows in prod.
**The test:** Queries per request and max payload. Bound any "depends".

## 12. Boot <!-- R2 -->

**Rule:** Config from the environment. Documented env and one command boot a fresh clone. Shutdown: stop accepting, finish in-flight work, exit. Missing required config fails boot.
**Why:** manual steps hide breakage.
**The test:** Clone + documented env + one command runs.

## Conflicts

§2 inside the boundary, §5 outside. Say if you cannot tell which. Name a project constraint that beats a rule.
