# Testing

A test is evidence. Evidence can be faked; these rules make that visible. `SKILL.md` applies, including watch-it-fail-first. This file does not repeat that rule. Raw check output goes to `checks.md` or an attachment, not the reply.

## 1. Spec, not the implementation

<!-- P13, R2 -->

**Rule:** Expected values come from the spec, the user's statement, or the domain — not from running the code. If you took an expectation from the implementation's output, label it characterization, not verification. Re-read the requirement before asserting. When the user's description and the code disagree, the test follows the user, and you surface the disagreement.

**Why:** code and test written together can share one misunderstanding.

**The test:** for any five assertions, where did the expected value come from? "From what the code does" is circular — rewrite from the spec, or say the spec is unclear and ask.

## 2. Red for the right reason

<!-- P13 -->

**Rule:** Watch every new test fail before it passes. If it passed first time, break the implementation and confirm it goes red. The failure is the assertion, not a syntax error, import, or harness mistake. Deleting the feature turns tests red; otherwise delete the tests or make them real.

**Why:** a green first run did not show that the test can fail.

**The test:** report which tests went red and what made them red. No red observation, no claim of verification.

## 3. Mock only true externals

<!-- P13 -->

**Rule:** Mock vendor APIs, network, clocks, and randomness. Never mock your own code. Prefer a fake with real behavior over a script of expected calls. Assert outcomes, not that a mock was called with X.

**Why:** a fully mocked test checks that the mocks agree with themselves.

**The test:** name what each mock replaces. "The layer under test" means the test is a tautology.

## 4. Hygiene

<!-- P14, P17, R1 -->

**Rule:** Synthetic data only. No real credentials, tokens, connection strings, personal data, or production dumps in fixtures, snapshots, or examples. Tests run with the network off, touch no shared or live service, and need no elevated privileges. They clean up and pass in random order. Fixtures look fake (`example.com`, `test-key-...`).

**Why:** a passing suite can still leak, and shared state hides the bug it shares with production.

**The test:** (a) grep fixtures and snapshots for credential and PII patterns — zero hits, raw output in `checks.md`; (b) the suite passes isolated and in random order; (c) name any test that cannot be hermetic and justify it.

## 5. Flakes are bugs

<!-- P13, R2 -->

**Rule:** Fix a flaky test or delete it. Do not mute it and do not retry-until-green in CI. A pass-on-retry is a race the retry is hiding. Quarantine only with an owner and a deadline.

**Why:** a retry silences a failure the test has already detected.

**The test:** no `@skip`, `@ignore`, or retry config without a linked issue and an expiry.

## 6. Coverage is a floor

<!-- R2 -->

**Rule:** A hit line is not a tested line. For each behavior, ask which test goes red if that line breaks.

**Why:** coverage applauds decoration.

**The test:** name the three most important lines of the change and the test that kills each if broken.

## Conflicts

- No spec: characterization tests may start the work if labeled, with what would turn them into spec tests.
- Integration tests against staging are a separate suite, never the default run, never production.
- A real emergency may defer the red observation if you say so and file the follow-up. The deferral does not erase §2.
