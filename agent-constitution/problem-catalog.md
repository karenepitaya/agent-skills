# Problem Catalog — AI Slop & Failure Modes

**Purpose:** the problem-side reference archive for the scenario files in this skill. Every problem has an ID, symptoms, mechanism, and detection method.
Every rule in a scenario file must trace back to an ID here. Rules without a problem don't enter the scenario files; problems without a rule must be explicitly marked "accepted risk".

Do not load this file to perform a task. Load it only to trace why a rule exists or to change one. The rules to execute are `SKILL.md` and the scenario file it routes to.

---

## 1. Root Causes

### R1 — Mean Regression
With no constraints, model output regresses to the "greatest common divisor" of its training corpus. Frontend training data is highly homogeneous (landing pages, portfolios, Awwwards-style work over-sampled), so the default output is the same "average face".
**Corollary:** adjectives ("clean and premium") get translated back into the mean. Only explicit constraints and concrete references swap the prior. The same pull produces unrequested code: speculative abstraction and drive-by edits. Simplicity and surgical-change rules cite R1 for that reason.

### R2 — Missing Feedback Loop
The model writes CSS blind; it has never seen its own rendered output. Frontend correctness is not machine-checkable and is strongly context-dependent (who the user is — information it has zero of). Layout failures come from predicting instead of observing.
**Corollary:** every quality dimension invisible in a single sample (narrow viewports, long copy, empty states, error states) has zero gradient in its definition of "done".

### R3 — Process and Product Share One Channel
Conversation is the model's only expressive medium, so every step in its head risks leaking into the artifact: design self-doubt → annotation microtext; revision history → "modified because..." in the body text; long-context anchor loss → sycophancy or stupidity. Humans externalize process (git log, comments, verbal handoff); the model has no concept of an external channel.
**Corollary:** channel separation (what enters the artifact vs. what stays in conversation) cannot be self-enforced by the model. Rules must hold the line. The same single channel produces hedging in the reply (P23): uncertainty is performed as questions and option lists because asking feels cheaper than deciding.

### R4 — English Prior
Its knowledge of font stacks, type metrics, and design trends is almost entirely Latin/English-context. Chinese is passively reached through fallback, so fonts, sizes, line-heights, and line-breaking all arrive mismatched. The same prior also produces translationese (P20): concepts formed in English are rendered word-by-word into Chinese instead of being re-expressed natively.
**Corollary:** this is the easiest class to eliminate with hard constraints — it's a parameter error, not a taste problem.

---

## 2. Problems

### P1 — AI-Slop Visual Pattern
**Symptoms:** purple-blue gradients, blanket glassmorphism, centered hero + three feature cards, emoji as icons, universal `shadow-lg`, cards nesting cards, floating animations everywhere, over-polished perfect symmetry.
**Mechanism:** R1. The greatest common divisor of landing-page training data.
**Detection:** the blacklist is grep-able (`linear-gradient`, `backdrop-filter`, emoji codepoints); the hero-plus-three-cards layout is visual-inspection detectable — it is the fingerprint of the training distribution, and its presence is probable cause. A project `DESIGN.md` replaces this blacklist, including permitting an item on it. The list is the default only when no `DESIGN.md` exists. Full names of the shortened rule tokens: centered hero + three feature cards; floating animations; decorative drop shadows; translucent panels over imagery.

### P2 — Hollow Content Corrupts Layout
**Symptoms:** placeholder copy ("empower your business", "unlock infinite possibilities"), obviously fake data (three equal-length testimonials), 99.9% / 10,000+ numbers. (Chinese equivalents: 赋能, 释放无限可能, 一站式.)
**Mechanism:** R1 + R2. Fake data sets the card size rhythm; when real content arrives the layout is forced to reflow — fake content infects visual design.
**Detection:** does the layout survive substitution with the real longest copy? Full-text search for buzzwords.

### P3 — CJK Font Fallback & Shrunken Type
**Symptoms:** pages render with a SimSun/宋体 feel; body text universally one size too small (13–14px), Chinese glyphs cramped and blurry.
**Mechanism:** R4. Font stacks are designed for Latin (`'Playfair Display', Georgia, serif`); every CJK glyph falls through to the generic `serif` family → maps to SimSun-class fonts on Windows/macOS. Latin 13px metrics applied directly to Han characters.
**Detection:** grep CSS for bare `serif`; check `font-family` stacks for explicit CJK families (PingFang SC / Microsoft YaHei / Noto Sans SC); body base size ≥15px and line-height ≥1.6.

### P4 — Responsive Design Absent
**Symptoms:** designed only for the 1440px desktop screenshot; overflow and squeezing at narrow widths; stacking order nonsense; the "responsive" part is a lone `flex-wrap` — it technically deforms, but no stacking decisions were made.
**Mechanism:** R2. The artifact's final review scene is one desktop screenshot; all other viewport quality is invisible in single-point sampling. Responsiveness is a series of UX decisions (what collapses, what goes into a drawer, what keeps priority), not a technical property.
**Detection:** screenshots at 375 / 768 / 1440 fed back for review; any horizontal overflow is failure.

### P5 — Copy Length Welded into Layout (i18n Absent)
**Symptoms:** widths fixed to the current copy's length; longer text breaks the layout; strings never externalized.
**Mechanism:** R1 + R2. i18n is invisible infrastructure in the training corpus; demos all hardcode strings.
**Detection:** the red line "strings never participate in width calculations" is grep-able (fixed-width text containers combined with `overflow: hidden` and no truncation strategy); break-test with copy at 150% length. Strings never externalized is the layout half of i18n. The language-policy half — one language, string keys, no ad-hoc translation — is P22.

### P6 — Interaction States Missing
**Symptoms:** hover-brighten only; no loading / empty / error states; motion either absent or everything floats.
**Mechanism:** R2. These states don't appear in the one screenshot being reviewed.
**Detection:** for every data-driven block, require loading / empty / error / populated rendered side by side.

### P7 — Chattiness on the Page (Annotation Microtext)
**Symptoms:** clean pages possessed by explanatory small print; explanations everywhere for the maximally confused user; deliverables read like a confessional with footnotes.
**Mechanism:** R3. The model can't distinguish "answering you" from "making a product"; text is its native tongue, so every design insecurity gets translated into a textual patch; defensive completeness — redundant explanation for an imagined worst-case reader.
**Detection:** word budgets (e.g. first screen ≤40 words); the delete pass — for each sentence, ask "if deleted, does the interface already express this?" — if yes, delete.

### P8 — Version-Iteration Pollution
**Symptoms:** filenames on a downward escalator ("revised" → "final" → "final-final" → "final-closing"); body text sprouting "because X, modified to Y" microtext; revision process leaking into the final artifact.
**Mechanism:** R3. Conversation history is forever present to the model, so it feels obliged to account for it — the equivalent of inlining git log into source files.
**Detection:** grep explanatory copy only — sentences, helper text, captions — not control labels or product verbs such as 修改密码. Patterns, not bare substrings: 由于…所以修改, 本次修改, 上一版, "updated because", "revised", "previous version". Bare 由于, 故, 本次, or 修改 are not search keys; they match ordinary words and buttons. Filenames carry no version vocabulary (revised, final, final-v2, final-final, 结案, 修订版, 最终版). The reader is a third party who has never seen any previous version.

### P9 — Long-Context Drift
**Symptoms:** after the thread grows long, intent loses its anchor — either sycophancy (every recent message treated as supreme directive) or stupidity (answering questions from three turns ago, repeating itself).
**Mechanism:** attention dilution; early constraints decay; the model falls back to its training-prior "safe personality".
**Detection:** a sudden quality shift after a major direction change is the signal. The countermeasure is procedural: squash — distill confirmed decisions into a clean spec, start a new session, never patch the old thread.

### P10 — Over-Orderliness, No Deliberate Asymmetry
**Symptoms:** perfect symmetry, uniform whitespace, uniform density — "correct but boring"; lacking the intentional density contrast and rule-breaking of genuinely good design.
**Mechanism:** R1. A taste-calibration problem — the hardest class to encode.
**Detection:** visual inspection only. This is currently the one problem humans must own. Admit it, concentrate human review effort here, and don't waste rules on it.

---

### P11 — Black Speech: Borrowed Jargon & Self-Coined Terms
**Symptoms:** (a) borrowed corporate slang used as a professionalism signal — Chinese: 赋能, 抓手, 闭环, 颗粒度, 对齐, 打法; English: leverage, synergy, seamless, robust, best-practice; (b) self-coined pseudo-frameworks — the model invents impressive-sounding methodology names that have no definition, no source, no existence outside this document; (c) abstract nominalizations where a concrete verb would do.
**Mechanism:** R1. Corporate/consulting prose reads as "professional" in the training distribution; unable to *be* authoritative, the model optimizes for *sounding* authoritative. Species (b) is the more dangerous one: readers assume the term is real and blame themselves for not knowing it.
**Detection:** jargon grep list (both languages); the define test — pick any five abstract terms, demand a one-sentence concrete definition for each, any failure → rewrite; the deletion test — if removing an adjective loses no information, it was decoration.

**Incident-caught register** (kept so the next check is mechanical): 夺舍, 牛仔运维, 破版, 回喂, 狗粮测试/吃狗粮 are meme or calque register — for the last, say 自测 or 用自己的规则检查自己的产物. 爆炸半径 is legitimate where the audience is SRE and "blast radius" has a fixed meaning; anywhere else prefer 影响范围. A coined framework name presented as if the reader should already know it is fabricated authority; coin only as "we call this X" and define it on first use. Concrete verb over nominalization: "cut review time by half", not "realize efficiency enablement".

### P12 — Fabricated Facts & Citations in Documents
**Symptoms:** invented references, links, standards numbers; plausible but nonexistent quotes; precise-looking statistics with no source; gaps silently filled with made-up data.
**Mechanism:** R1 + R2. The model is trained to always produce an answer, and documents have no compile step — a fabricated citation reads exactly like a real one.
**Detection:** the source test — pick any five numbers, quotes, or citations and demand the source for each; anything unverifiable is marked `[unverified]` or deleted. Never "probably true".

### P13 — Tests That Can't Fail (Self-Agreement)
**Symptoms:** the model writes implementation and test from the same (possibly wrong) understanding — they agree with each other and both are wrong; expected values copied from the implementation's actual output; mocks so complete the test becomes a tautology; tests that pass on the first run and never went red.
**Mechanism:** R2. No external oracle: agreement between code and test is not evidence of correctness when both share one author and one misunderstanding.
**Detection:** the origin test — for each assertion, "where did this expected value come from: the spec, or the implementation's output?"; red-before-green must be demonstrated, including failing for the *right* reason.

### P14 — Test Environment Contamination
**Symptoms:** real credentials, PII, or production snapshots in fixtures; tests hitting live or shared services; tests requiring elevated privileges; order-dependent tests polluting shared state.
**Mechanism:** R1 (demo corpus hardcodes real-looking secrets) + R2 (contamination is invisible in the test output — the suite passes while leaking).
**Detection:** grep fixtures/snapshots for credential patterns and PII; the suite runs hermetically (network off, no shared services) and passes under random ordering.

### P15 — Cowboy Operations
**Symptoms:** destructive commands (`rm -rf`, `drop table`, `kubectl delete`) executed without a stated blast radius, without confirmation, without a verified rollback path; unrelated changes bundled into one action; no record of what was changed or why.
**Mechanism:** R1 (tutorials normalize YOLO commands) + R2 (the model never experiences consequences).
**Detection:** every state-changing action is preceded by a blast-radius statement and explicit confirmation; every change answers "how do I undo this" *before* execution.

### P16 — Privilege Escalation as Problem-Solving
**Symptoms:** `chmod 777`, `--privileged`, disabling TLS verification, security groups opened to `0.0.0.0/0`, running as root/admin — applied to silence a permission error.
**Mechanism:** R1. Q&A corpus is full of these as "fixes"; they silence the symptom without understanding the error.
**Detection:** any permission or security-control change must name the underlying error it addresses and why narrower scoping is insufficient. "It works now" is not an explanation.

### P17 — Secrets Exposure
**Symptoms:** secrets echoed into logs, chat replies, committed `.env` files, scripts, or screenshots.
**Mechanism:** R1 + R3 — process leaks into artifacts, and the model treats secrets as ordinary strings.
**Detection:** grep diffs and outputs for secret patterns; any exposure is an incident — rotate first, report, then continue.

### P18 — Compliance Theater
**Symptoms:** checks claimed as performed ("responsive verified", "delete pass done") without actually being run; self-audit reports are narrative, not evidence; the failure surfaces only when a human re-runs the check by hand.
**Mechanism:** R2. A check that was run and a check that was claimed produce identical text — nothing in the output distinguishes them. And claiming is free while running takes effort, so the gradient points the wrong way.
**Detection:** any mechanically runnable check (grep, word count, screenshot) ships as raw output in a checks file or attachment (`checks.md` by default), not in the chat reply. The reply states what was delivered, what was verified, and the human-review list. A narrative claim of compliance is rejected. *Origin: caught in production — a landing page shipped with its own banned-list word (闭环) in it, one day after the list was written.*

### P19 — Register Leak
**Symptoms:** the conversation's tone, memes, and inside jokes appear in the deliverable; in-group phrasing used for a general audience; decorative bilingual fragments carried over from chat. The artifact reads like the room it was made in, not like something for a reader who wasn't there.
**Mechanism:** R3. The conversation is the model's whole world; its register bleeds into the artifact. Distinct from P7 (quantity of words) and P8 (revision history) — this is a *tone* contamination.
**Detection:** the third-party-reader pass — flag every phrase whose meaning depends on having been in the conversation; after each incident, add the caught words to the project's jargon grep list.

### P20 — Translationese (直译腔)
**Symptoms:** Chinese output whose syntax betrays an English source, even when word choice is innocent: calques (爆炸半径 for "blast radius"); passive-voice overuse (被设计用来); stacked 的-attributives ("一个被广泛用于构建现代应用的框架"); 进行+verb (进行分析 instead of 分析); article-echo (一个/一种 for every English a/an); possessive overuse (你的/我们的 where Chinese drops them); English marketing idioms rendered literally (强大的, 无缝, 毫不费力).
**Mechanism:** R4. Concepts are formed in English and rendered word-by-word into Chinese instead of being re-expressed natively. Distinct from P11: P11 is word *choice* for signaling professionalism; P20 is *syntax and phrasing* leaking from English regardless of intent.
**Detection:** marker grep (进行, 值得注意, 在某种程度上, 对于…来说, 通过…来, 3+ 的-chains, 你的/我们的 density); the translate-back test — if the English original is audible behind the Chinese sentence, rewrite it; the native read-aloud test for anything gray. Three zones: where an established Chinese expression exists, use it; where the English term is the standard (API, SDK, N+1), keep the English; the literal-calque middle is the banned zone.

### P21 — Remote Font, No Local Fallback
**Symptoms:** text or digits render in an unintended generic face. Origin: a timer's digits drew in a serif fallback on iPhone because Google Fonts did not load and the stack named no local family. In mainland China, `fonts.googleapis.com` often fails outright.
**Mechanism:** R4 + R2. Stacks copied from Latin demos name a remote family and stop. The failed load is invisible to the model, which never sees the fallback.
**Detection:** every `font-family` ends with local system fonts (`-apple-system`, `PingFang SC`, `system-ui`, or the platform equivalent). A remote font may only precede that ending. China-targeted pages self-host or mirror Google Fonts. Bare `serif` / `sans-serif` still fail (P3).

### P22 — Ad-hoc Second Language
**Symptoms:** a single-language UI gains a translated twin mid-task; strings hardcoded in two languages; copy translated in place instead of through keys.
**Mechanism:** R4 + R1. Translation feels helpful. Distinct from P5, which is layout welded to the current string and strings never externalized. P22 is the language policy: one language unless the spec says otherwise, all copy behind keys, no ad-hoc translation.
**Detection:** user-facing strings are key lookups in one locale. A second language in the diff, without a spec that asks for it, is a failure.

### P23 — Hedging and Over-asking (多嘴)
**Symptoms:** option lists for reversible, in-scope choices; several clarifying questions where one decision would do; "I could do either" with no pick; caveats that do not change the action.
**Mechanism:** R3. Uncertainty is performed in the conversation because that channel is always open and being wrong feels costlier than asking.
**Detection:** a reversible in-scope choice is a decision plus a one-line reason. A question appears only for an irreversible action (delete, send, pay), ambiguity that materially changes the result, or pure personal taste, and it is one question with a recommended option. The assumption is still stated, including what problem the work solves. A simpler approach, or a request that is a workaround, is still named.
**Retired wording this replaces:** "If uncertain, ask." "If multiple interpretations exist, present them — never pick silently." "If something is unclear, stop. Name what's confusing. Ask." "Biases toward caution over speed." Those sentences trained the hedging. Kept from them: state assumptions, including what problem this solves; push back when a simpler path exists or the request is a workaround.

---

## 3. Root Cause × Problem Matrix

| Problem | Root causes | Eliminable by hard rules? |
|---|---|---|
| P1 AI-slop visuals | R1 | Mostly (blacklist + references + DESIGN.md) |
| P2 hollow content | R1, R2 | Yes (real data first) |
| P3 CJK typography | R4 | Fully (font stack + size baseline) |
| P4 responsive absent | R2 | Partially (verification loop; stacking decisions still need human review) |
| P5 copy welded in | R1, R2 | Mostly (red line + break tests) |
| P6 states missing | R2 | Yes (four-state screenshot review) |
| P7 chattiness | R3 | Yes (word budget + delete pass) |
| P8 version pollution | R3 | Yes (channel separation + external naming) |
| P9 context drift | R3 | Not by rules — procedural avoidance (squash & restart) |
| P10 over-orderly | R1 | No — humans own it |
| P11 black speech | R1 | Mostly (grep + define test + deletion test) |
| P12 fabricated facts | R1, R2 | Partially (sourcing rules force marking; verification stays human) |
| P13 self-agreement tests | R2 | Partially (origin test + red-before-green) |
| P14 test environment contamination | R1, R2 | Mostly (grep + hermeticity checks) |
| P15 cowboy operations | R1, R2 | Yes (blast-radius protocol) |
| P16 escalation as fix | R1 | Yes (forbidden-silencer list + justification rule) |
| P17 secrets exposure | R1, R3 | Yes (grep + incident rule) |
| P18 compliance theater | R2 | Yes (raw-output evidence rule) |
| P19 register leak | R3 | Mostly (third-party-reader pass + incident-driven grep list) |
| P20 translationese | R4 | Mostly (marker grep + translate-back test; native read-aloud stays human) |
| P21 remote font, no local fallback | R4, R2 | Fully (stack must end in local system fonts; China: self-host or mirror) |
| P22 ad-hoc second language | R4, R1 | Yes (one locale, string keys) |
| P23 hedging / over-asking | R3 | Yes (decide reversible work; one question with a recommendation) |

---

## 4. How to Use

1. When writing or editing scenario rules, annotate every rule with its traceability ID, e.g. `<!-- P3, R4 -->`.
2. Review rules bidirectionally: delete rules with no traceable problem; mark uncovered problems as "accepted risk" with a stated reason.
3. When a new problem appears, register it here first with an ID, then write the constraint — never let scenario files absorb problems directly. Keep the problem archive and the countermeasure archive separate.
4. This file is not part of normal execution. `SKILL.md` routes the task to one scenario file.

## 5. Notes Moved Out of the Rules

Longer explanations and examples removed while compressing the scenario files. The constraints themselves stayed in the scenario files.

- **Provenance.** The global rules derive from Andrej Karpathy's observations on LLM coding pitfalls. The old preface "biases toward caution over speed" was retired with P23; caution now means asking only when the action is irreversible, the ambiguity changes the result, or the choice is taste.
- **Toolchain scope.** Project-specific tooling and environment rules live in the project's own files, not in this constitution. Ops §6 is the behavioral rule. The core file does not name package managers, runtimes, or shells.
- **Office examples.** No throat-clearing such as "in today's fast-paced world". A heading states a conclusion ("Retention drops after week three"), not a topic ("Analysis"). A slide title is an assertion ("Churn concentrated in the first 30 days"), not "Churn Analysis".
- **Backend rules that originally had no `<!-- -->`.** They now cite the mechanism, not a newly invented problem: §1 stack R1; §2 noise R1 and R3; §3–§6, §8, §11, §12 R2 (the failure is invisible without an explicit invariant, timeout, or measurement); §7 integrity P15; §9 security P16 and P17; §10 tests P13. Global simplicity and surgical changes cite R1. Verified goals cite R2, P13, P18.
