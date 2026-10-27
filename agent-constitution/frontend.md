# Frontend
UI, pages, HTML, prototypes, slides. You cannot see rendered output. Project `AGENTS.md` wins. No `DESIGN.md`: §2's list is the default; a `DESIGN.md` replaces it.

## 1. Loop <!-- R2, P4, P6 -->
**Rule:** Screenshot 1440/768/375 after edits; look; fix. No shot: "unverified". Reported bug: screenshot first. Name three worst per shot; fix the worst.
**Why:** unseen = fake.
**The test:** each visual claim points at a shot in `checks.md`.

## 2. Tokens <!-- P1, R1 -->
**Rule:** Approved `DESIGN.md` before pages (else fill and approve `DESIGN.template.md`: palette, type, fonts, spacing, radius, shadow, motion). Color, font, size, spacing, and radius trace to tokens; amend, don't smuggle. No `DESIGN.md` forbids gradients (`linear-gradient`), glassmorphism (`backdrop-filter`, translucent panels), emoji icons, drop shadows, hero+3 feature cards, floating animations. Adjectives: one question recommending a reference or amendment.
**Why:** mean page.
**The test:** grep that list (zero hits, raw in `checks.md`) and name five tokens, or match `DESIGN.md`.

## 3. CJK <!-- P3, R4 -->
**Rule:** Name CJK families once in `DESIGN.md` (template §4). No bare `serif`/`sans-serif`. Body ≥15px (prefer 16), line-height ≥1.6, captions ≥12px. Chinese serif only if named there. From English: +1–2px, line-height +0.1–0.2, CJK tracking 0.
**Why:** SimSun-class fallback.
**The test:** grep those gaps; measure size and line-height; raw in `checks.md`.

## 4. Fonts <!-- P21, R4 -->
**Rule:** End stacks with local system fonts (`-apple-system`, `PingFang SC`, `system-ui`). Remote fonts only earlier. China: self-host or mirror Google Fonts.
**Why:** the last family shows.
**The test:** every `font-family` ends local; China pages do not use `fonts.googleapis.com`.

## 5. Space <!-- P4, P5, P6, R2 -->
**Rule:** Before code: collapse, stack, hide, or keep priority when narrow. Fluid type/spacing (`clamp()`, min/max). Strings never set width: truncate or wrap. Survive +50% copy. Blocks: loading, empty, error, populated. Hover, focus-visible, disabled, keyboard.
**Why:** one sample.
**The test:** three widths, no overflow; 150% copy; four states — in `checks.md`.

## 6. Language <!-- P22, P5 -->
**Rule:** One language unless the spec says so. UI copy is string keys. No ad-hoc translation, no second hardcoded language.
**Why:** a second UI.
**The test:** user-facing strings are one locale's keys.

## 7. Content <!-- P2, R1, R2, P20 -->
**Rule:** Real copy, else ask, else worst case (long, uneven, missing). Ban: empower, "unlock infinite possibilities", "seamless one-stop", 赋能, 释放无限可能, 一站式. Name the action. Chinese UI follows `office.md` §4.
**Why:** wrong boxes.
**The test:** longest real string fits; grep the ban; raw in `checks.md`.

## 8. Restraint <!-- P7, P8, P19, P18, R3 -->
**Rule:** Budget first (default one message/screen). No helper text the UI already says. A new sentence names the failed form: hierarchy, spacing, iconography, or flow. Delete what the UI already shows; record the count. No process text, chat-only phrase, `final`/`final-v2`/`final-final` filenames, commented-out code, or markup TODOs.
**Why:** no shared history.
**The test:** budget met; delete-pass count (0 = not done); grep explanatory copy, not labels (修改密码 is not a hit), for `由于…所以修改`, `本次修改`, `上一版`, `updated because`, `revised`, `previous version`; raw in `checks.md`.

## 9. Units <!-- R2, P10 -->
**Rule:** Nav, then table, then form; run §1 before the next. Taste: ≤2 options and a recommendation, not always symmetry.
**Why:** no decision.
**The test:** one screenshot loop and one review before the next unit.

## 10. Humans <!-- P9, P10, R3 -->
**Rule:** Long thread or a new direction: spec the decisions, restart. Flag re-answering or default agreement. Rhythm, asymmetry, density: human review.
**Why:** taste and drift.
**The test:** the reply ends with that list; empty fails on visual work.

## Conflicts
§5 states stay; their copy follows §8. New token: amend — don't smuggle or ship the bug. Name the constraint.
