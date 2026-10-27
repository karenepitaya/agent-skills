# Office

Reports, memos, email, slide words. The reader never saw this chat. `SKILL.md` applies. Pixels: `frontend.md`. Checks → `checks.md`, not the reply.

## 1. Standalone <!-- P8, R3, P19 -->

**Rule:** No prior version, prompt, "as you asked", or "per your feedback" in the file. Background the reader needs is in the file. No meme or phrase that needs this chat. Caught words join §4.
**Why:** process text addresses a participant.
**The test:** a stranger is not confused by how the file was made.

## 2. External versions <!-- P8, R3 -->

**Rule:** One current file, named by the user or project (git, a version tool, a dated folder). Banned in filenames: "revised", "final", "final-v2", "final-final", "结案", "修订版", "最终版". Ship the clean next version; what changed goes in the reply or change-notes. No "changed from X" unless they asked for a redline (its own artifact).
**Why:** in-file history is a pasted git log.
**The test:** filename has none of those tokens. Grep explanatory copy only — not a label such as 修改密码 — for `由于…所以修改`, `本次修改`, `上一版`, `updated because`, `revised`, `previous version`. Raw in `checks.md`.

## 3. Earn the sentence <!-- P7, R3, P18 -->

**Rule:** No throat-clearing, no restating the assignment, no point said twice. Headings are conclusions or concrete names. Set a word budget and meet it. Delete a paragraph that loses nothing; record the count.
**Why:** padding is chattiness.
**The test:** budget met; delete-pass count (0 = not done); headings are claims or names; counts in `checks.md`.

## 4. Plain language <!-- P11, P20, R1, P18 -->

**Rule:** Drop these, or justify a fixed meaning. Jargon: leverage, synergy, seamless, empower, robust, best-in-class, unlock, elevate, holistically; 赋能, 抓手, 闭环, 颗粒度, 对齐, 打法, 心智, 链路. Register: 夺舍, 牛仔运维, 破版, 回喂, 狗粮测试, 吃狗粮 — say 自测 or 用自己的规则检查自己的产物. 爆炸半径 only for SRE; else 影响范围. Coin only as "we call this X", defined on first use. Translationese: use the existing Chinese phrase, keep English where it is the term (API, SDK, N+1), do not calque. Markers: 进行+verb, 值得注意, 在某种程度上, 对于…来说, 通过…来, 被 where Chinese is active, 3+ 的, echo 一个/一种, extra 你的/我们的, 强大的, 无缝, 毫不费力. Concrete verbs. Cut an adjective that adds nothing.
**Why:** opaque words perform expertise.
**The test:** grep (zero or a justified hit, raw in `checks.md`); define five abstract terms in one concrete sentence; adjective cut; five Chinese sentences — rewrite if the English is audible; gray cases, read aloud.

## 5. Conclusion first <!-- R1 -->

**Rule:** First paragraph is the conclusion. One message per section and per slide. Titles are assertions. Numbers before adjectives.
**Why:** busy readers start at the top.
**The test:** first paragraph plus headings reconstruct the argument.

## 6. Facts <!-- P12, R1, R2 -->

**Rule:** Numbers, quotes, citations, standards, and names come from user material or a source opened this session. A gap stays a gap. Label an estimate and how it was made. Mark `[unverified]` what you could not check, and list it in the notes. One figure, one value, in prose, tables, and charts.
**Why:** a fake citation looks real.
**The test:** source any five claims. A miss stops delivery.

## 7. Audience <!-- R3 -->

**Rule:** State who reads, what they know, and what they will do. Use their terms. No note from you in the file ("I hope this helps"). Hedge once, at the real uncertainty.
**Why:** depth follows that reader.
**The test:** the reader assumption is in the notes; register holds throughout.

## Conflicts

Missing points become sections, not longer paragraphs. A field's fixed term passes §4's define test. For narrative, say so and say where the conclusion is. Name any project constraint that beats a rule.
