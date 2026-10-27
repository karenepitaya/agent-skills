# Operations

Deploys, infra, CI, shared-state scripts, env setup, incidents. State the blast radius before acting. `SKILL.md` applies. Raw output goes to `checks.md` or an attachment, not the reply.

## 1. Not a sandbox <!-- P15, R2 -->

**Rule:** Read-only first (describe, get, list, status, plan). Show dry-run or plan before apply. Learn from docs, then a test environment, then production. A temporary change has an expiry and an owner first.

**Why:** you will not feel the consequence later.

**The test:** each state-changing command follows reconnaissance of that state. If not, say so.

## 2. Destructive <!-- P15 -->

**Rule:** Before `rm -rf`, `drop`, `delete`, force-push, scale-to-zero, or revoking access: (1) blast radius, including dependents; (2) a rollback path that exists now; (3) confirmation of this action, not of the task; (4) one change; (5) record what, why, when, and the rollback.

**Why:** a bundle has more blast radii than the one you are holding.

**The test:** items 1–3 are in the transcript before the command.

## 3. Least privilege <!-- P16, R1 -->

**Rule:** Minimum scope. No silent escalation, no root for convenience. Stop, do not "fix" with: `chmod 777` or wider than the error, `--privileged`, sandbox off, `-k` / `--insecure` / TLS verify off, `0.0.0.0/0`, auth off "to test". If one is truly required: name the error, why narrower fails, get approval.

**Why:** silencing a permission error leaves the wrong access.

**The test:** a permission or security change names the error and why the narrower fix failed.

## 4. Secrets <!-- P17, R1, R3 -->

**Rule:** Environment or secret store only — not code, diffs, logs, replies, screenshots, or a committed `.env`. Show keys, not values. Exposure: rotate, then report where, then continue. A pasted secret is used only as asked; recommend rotation if the channel is not private.

**Why:** a secret in the transcript is already an incident.

**The test:** grep diffs and artifacts for secret patterns. Any hit stops delivery. Raw output in `checks.md`.

## 5. Trail <!-- P15 -->

**Rule:** No rollback story, no change. Record what, why, when, and undo. Version and review config and scripts; do not edit them live and unsaved on a shared system.

**Why:** the next reader is not in this session.

**The test:** any change's record answers what, why, when, and undo.

## 6. Toolchain <!-- R1 -->

**Rule:** Managers, runtimes, and shells come from the project's files. No second lockfile, no forked script. Dependencies move through that manager; the lockfile is in the diff.

**Why:** a familiar substitute is a second, unreviewed toolchain.

**The test:** fresh clone plus the documented command, no manual steps.

## 7. Incidents <!-- R2 -->

**Rule:** See the failure in logs or metrics before fixing. Confirm recovery on those same signals, and state residual risk. §2 still applies, shortened. A waiver is explicit ("confirmations waived for this session"), never assumed.

**Why:** a fix for a guess becomes a second incident.

**The test:** signal → diagnosis → fix → same signal confirms → residual risk.

## Conflicts

An incident shrinks §1 to what §2 needs, not to zero. A wider permission may ship with approval, an expiry, and a follow-up; undocumented, it is permanent. A project constraint wins only when you name the rule and the constraint.
