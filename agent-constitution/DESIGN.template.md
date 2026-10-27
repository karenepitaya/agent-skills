# DESIGN.md — [FILL: project name] Design System

> **How to use this file (instructions for the agent — do not delete):**
>
> 1. This file has two layers: **fixed instructions** (rules, apply to every project) and **parameters** (`[FILL: ...]` blanks, filled per project). Never edit fixed instructions silently — amendments go through the user.
> 2. Copy this template into the project, **delete sections the project doesn't need**, and fill the rest. On-demand extraction is intended; silent omission is not — deleted sections are listed in §0.
> 3. **No page code until §0's mandatory blanks are resolved.** Grep for `[FILL:` — any hit in a mandatory section blocks page work (`frontend.md` §2).
> 4. Every style value in code must trace to a token defined here. Ad-hoc values are bugs.
> 5. Precedence: once this file exists it replaces the frontend scenario's default forbidden list (gradients, glassmorphism, and the rest). That list applies only when no `DESIGN.md` exists. Behavior rules in `frontend.md` still apply. Fill §3's gradient line explicitly.

---

## 0. Status

- Mandatory blanks resolved: §1 direction, §2 stack, §3 color core, §4 type scale. *(All others may be deferred with a stated reason.)*
- Sections deleted as not-needed: [FILL: list, or "none"]
- Approved by / date: [FILL]

---

## 1. Design Direction

**Adjectives are not direction. Direction = references + concrete decisions derived from them.**

- References (products/sites this should feel like): [FILL: 1–3, with one sentence each on *what specifically* to borrow — its density, its restraint, its typography]
- Anti-references (what this must NOT look like): [FILL: at least 1]
- Audience and context of use: [FILL: who, and in what situation — e.g. "on-call engineer scanning at 3am" drives density and contrast decisions differently than "first-time visitor evaluating the product"]
- Personality, translated into decisions: [FILL: e.g. "serious" → no rounded-full buttons, no playful illustration, neutral palette with one accent]

---

## 2. Framework & Libraries — Fixed Instructions

**Primitives come from libraries. Hand-rolling is the AI-slop factory: a hand-rolled button regresses to the mean; a library button imports a designer's decisions.**

- **Component library (mandatory):** [FILL: e.g. shadcn/ui, MUI, Ant Design, Arco]
  - Rule: buttons, inputs, tables, dialogs, menus, toasts — always from the library. Custom CSS is for what the library doesn't cover, and is named as such.
  - Rule: don't restyle library components past the theme tokens. If the design needs a component the library doesn't have, say so — that's a decision, not a one-off hack.
- **Animation library (mandatory if any motion exists):** [FILL: e.g. Framer Motion, GSAP, CSS transitions via the component library, or "no motion"]
  - Rule: motion uses the library's primitives and the tokens in §6. No bespoke `@keyframes` without justification.
  - Rule: if "no motion" is chosen, that's a legitimate design decision — write it down, and then §6 is deleted.
- **Icon library (mandatory):** [FILL: e.g. Lucide, Heroicons, iconfont set] — emoji as icons are forbidden unless §10 amends this.
- **CSS approach:** [FILL: e.g. Tailwind, CSS Modules, library theme system] — one approach, not a mixture.

---

## 3. Color Tokens

**Define roles, not just colors. Code references roles (`bg-surface`, `text-muted`), never raw hex.**

- Core palette: [FILL: background / surface / border / text-primary / text-muted / accent / danger / success / warning]
- Dark mode: [FILL: "yes — tokens must come in pairs" or "no — explicitly out of scope"]
- Rules:
  - One accent color. If everything is accented, nothing is.
  - Contrast ratios: body text ≥ 4.5:1, large text ≥ 3:1 (WCAG AA) — verify, don't estimate.
  - Gradients and glassmorphism: [FILL: "forbidden" (default) or explicitly permitted, with where and why]

---

## 4. Typography — Role-Based Type Scale

**Typography is designed by roles, not improvised per element. Every text on every page maps to exactly one role.**

- Font stacks (mandatory, per `frontend.md` §3 and §4):
  - Latin: [FILL]
  - CJK: [FILL: must name families explicitly — e.g. `'PingFang SC', 'Microsoft YaHei', 'Noto Sans SC'` — bare generic families forbidden]
  - Monospace (code/data): [FILL]
  - Every stack ends in local system fonts (`-apple-system`, `PingFang SC`, `system-ui`, or the platform equivalent). A remote font may only precede that ending.
  - Users in mainland China: self-host or mirror Google Fonts. Do not depend on `fonts.googleapis.com`.
- Type scale: [FILL: display / h1 / h2 / h3 / body / body-small / caption — each with size, weight, line-height; CJK body ≥15px, line-height ≥1.6, captions ≥12px]
- Rules:
  - Weight and size carry hierarchy — not color tricks, not all-caps decoration.
  - letter-spacing: 0 for CJK runs; Latin tracking adjustments only on display/caption roles.
  - Numbers in data contexts use tabular figures (`font-variant-numeric: tabular-nums`) — columns of numbers must not jitter.

---

## 5. Space, Radius, Shadow, Grid

- Spacing scale: [FILL: e.g. 4pt grid — 4/8/12/16/24/32/48]
- Radius: [FILL: e.g. 6px default; decide once, use everywhere]
- Shadows: [FILL: one elevation scale, or "none — flat design"] — decorative shadows on every card are forbidden.
- Layout: [FILL: max content width, grid or single-column, breakpoints — must include mobile behavior, see `frontend.md` §5]
- Density statement: [FILL: one sentence — e.g. "dense tool, whitespace is functional not decorative" or "marketing pace, generous whitespace"]

---

## 6. Motion

- Durations: [FILL: e.g. micro 100–150ms, transitions 200–300ms, nothing exceeds 500ms]
- Easing: [FILL: e.g. ease-out for entrances, ease-in for exits]
- What animates: [FILL: state changes, entrances of important elements, feedback on action]
- What never animates: [FILL: default answer — large layout shifts, text content, anything on scroll-repeat]
- Rule: motion is feedback, not decoration. Every animation answers "what does this tell the user?" No ambient floating, no animation that delays access to content. Respect `prefers-reduced-motion`.

---

## 7. Components Inventory

- Components this project needs: [FILL: list — e.g. data table, filter bar, stat card, empty state, form layout]
- For each: which library component backs it, and any project-specific variants (as tokens, not ad-hoc CSS).
- Every component's four states are designed here, not improvised in code: loading / empty / error / populated (`frontend.md` §5). Empty-state copy tone: [FILL: one sentence, e.g. "helpful, tells the user what to do next"]

---

## 8. UX Patterns

**UX is decisions about flow and feedback, written down before they're needed.**

- Navigation model: [FILL: how many levels, what persists, how the user knows where they are]
- Feedback: every user action gets visible feedback within 100ms — [FILL: patterns for success/failure/progress, e.g. toast vs inline]
- Forms: [FILL: validation timing (on blur / on submit), error message placement, required-field marking]
- Destructive actions in the UI: [FILL: confirmation pattern — never undo-less and silent]
- Word budget per view: [FILL: e.g. "first screen ≤ 40 words; helper text off by default" — see `frontend.md` §8]

---

## 9. Accessibility Baseline

- Focus-visible styles on every interactive element; keyboard operability everywhere.
- Color is never the only carrier of meaning (icons/text accompany status colors).
- Touch targets ≥ 44px on mobile.

---

## 10. Amendment Protocol

- Anything the design needs that this file doesn't define: propose the amendment here first, get it approved, then use it. Never smuggle ad-hoc values into code.
- When this file and a screenshot of the result disagree, the screenshot wins the argument — but the fix lands here first, then in code.
