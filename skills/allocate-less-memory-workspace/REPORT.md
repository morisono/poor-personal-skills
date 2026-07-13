# allocate-less-memory — Iteration 1 Engineering Report (2026-07-10)

Candidate: v0.2.0 (working tree). Baseline: v0.1.0 (`skill-snapshot/`, commit 161d1e6).
Decision: **Promote candidate v0.2.0.**

## 1. Diagnostic report (v0.1.0)

| # | Finding | Severity | Evidence |
|---|---------|----------|----------|
| D1 | `--pattern` semantics inverted across scripts: protect-list in `.sh`/`.ps1`, target-list in `.py`. `.sh`/`.ps1` killed big non-dev processes and spared the stale dev helpers the skill targets. | critical | Code review; live demo in eval run `eval-4/old_skill` — old `.sh` scan returned zero candidates while 500+ MB stale helpers existed. |
| D2 | `.py` printed `starttime` clock-ticks as "elapsed seconds" (`stat[21]`), breaking the skill's own age heuristic. | high | Code review; fixed version prints sane values (764s vs ticks). |
| D3 | `.py` `/proc/<pid>/stat` parsed with naive `split()` — wrong fields for comm names containing spaces/parens. | medium | Known /proc parsing pitfall. |
| D4 | `.sh` kill pass re-ran `ps` — killed list could diverge from displayed list. | medium | Code review. |
| D5 | `--root-pid` protected only direct children in `.sh`/`.ps1`; SKILL.md promises tree semantics. | medium | Code review. |
| D6 | Description had zero user-phrase trigger signals; body carried a `### Activation` section that loads only after triggering (dead weight). | high | Contrast with sibling `free-up-space` house style. |
| D7 | Redundancy: TERM→KILL stated 3× (SKILL.md, thresholds.md ×2 contexts); tree-over-blanket stated 2×. | low | Text audit. |
| D8 | `scripts/` referenced without invocation docs — every consumer must reverse-engineer flags. | medium | v0.1.0 SKILL.md L43. |
| D9 | Helper pattern `node` substring-matches `nodev` mount flag → all snapfuse mounts false-positive. | medium | Discovered independently by 3 of 12 eval runs. |
| D10 | `author: you` placeholder; `manifest.txt` not house style (deletion declined by permission gate — retained, updated). | low | Frontmatter. |

## 2. Redundancy analysis / compression

- Removed: `### Activation` body section (folded into description), duplicate TERM→KILL block in thresholds.md, duplicate tree-over-blanket phrasing.
- Merged: Purpose/Workflow overlap; workflow now a single numbered scan→classify→confirm→kill→verify→escalate sequence.
- Added (capability, not bloat): script invocation + flags in Workflow step 1 (removes per-run rediscovery cost), "core host services" exclusion made explicit (postgres trap), residue-by-parentage-not-size principle.
- Net body: 43 → 76 lines. Growth is invocation documentation; redundant text removed. Measured per-run tokens went **down** (see §6), i.e. the added lines pay for themselves at run time.

## 3. Trigger analysis

- New description follows proven sibling pattern: concrete symptom phrases (OOM kills, frozen/sluggish WSL, vmmemWSL toward cap, orphaned/duplicate helpers), "even if they never say memory", plus explicit anti-triggers (in-code leak fixing/allocation tuning; disk space → free-up-space) to defuse the misleading skill name.
- 20-query eval set created (`trigger_evals.json`): 10 positive incl. Japanese-language and indirect phrasings, 10 hard negatives (pandas "allocate less memory", express heap leak, vhdx disk full, k8s OOMKilled, chrome CPU kill).
- Measured trigger accuracy: **Insufficient data.** `run_eval.py`'s command-file simulation never triggered for either description, any query, even the strongest positive on the session-grade model (sanity probe 0/1 positive, 1/1 negative). Harness non-functional in this environment (heavily customized ~/.claude with hook wrappers + large competing skill population). Old-vs-new false-positive/false-negative rates therefore analytic only.

## 4. Evaluation results (assertion grading)

3 evals × 2 reps × 2 configs, Sonnet subagents, 14 assertions/config/rep:

| Eval | with_skill (v0.2.0) | old_skill (v0.1.0) |
|------|--------------------|--------------------|
| orphan-triage (fixture triage, postgres + active-rustc traps) | 5/5, 5/5 | 5/5, 5/5 |
| dry-run-scan (bundled script, flags, no kill) | 5/5, 5/5 | 5/5, 5/5 |
| wslconfig-cap (cap+swap=0 advice) | 4/4, 4/4 | 4/4, 4/4 |

Both 100%. No capability regression. Assertion suite non-discriminating at this difficulty — see §10.

## 5–7. Benchmark, variance, regression

From `iteration-1/benchmark.json` (n=6 runs/config):

| Metric | old_skill | with_skill | Δ (with−old) | paired 95% CI |
|--------|-----------|------------|---------------|----------------|
| Pass rate | 100% ± 0% | 100% ± 0% | 0 | — |
| Time | 211.9s ± 34.5s | 194.4s ± 69.3s | −17.5s (−8.3%) | [−29s, +64s] |
| Tokens | 56,880 ± 5,146 | 54,566 ± 6,253 | −2,314 (−4.1%) | [−1.7k, +6.3k] |

- Efficiency deltas directionally favor the candidate but are **not statistically significant** at n=6; treat as "no worse, likely slightly better".
- Variance: candidate time stddev higher, driven by one fast outlier (87s dry-run-scan). No increased-variance concern on tokens.
- Regressions detected: none. Capability additions verified outside the model loop: old `.sh` produced a functionally empty scan (D1) where new `.sh`/`.py` agree on 7 real candidates; snapfuse false positives 11→0 after D9 fix (deterministic smoke test, both scripts).

## 8. Version selection

**Promote v0.2.0.** Evidence: zero regression on 28 graded assertions; two objective correctness bugs (D1, D2) whose failure modes appeared live during evaluation of the old version; deterministic verification of script fixes; efficiency neutral-to-positive. Not committed — working tree only, snapshot preserved at `skill-snapshot/`.

## 9. Artifacts

- `iteration-1/` — 12 runs with outputs, grading.json, timing.json
- `iteration-1/benchmark.{json,md}` — aggregated stats
- `review.html` — static eval viewer (Outputs + Benchmark tabs)
- `evals/evals.json`, `trigger_evals.json`, `fixtures/ps_snapshot.txt` — reusable suite
- `trigger_{old,new,sanity}.json` — trigger measurement attempts (invalid, kept for provenance)

## 10. Next improvement hypotheses

1. Add outcome assertion to dry-run-scan ("scan surfaces ≥1 known stale helper above threshold") — would have failed old `.sh` and made the suite discriminate on D1-class bugs.
2. Add an escalation eval: ambiguous candidate attached to live tree; correct behavior = stop and ask, not kill. Tests the Escalation section, currently unexercised.
3. Re-run trigger measurement in a clean `.claude` project (no hook wrappers, minimal skill population); alternatively A/B via real session logs.
4. PPID==1 orphan heuristic misfires under systemd (services are legitimately parented to 1). Consider session-id (`ps -o sess`) or start-time-vs-boot discrimination before widening kill defaults.
5. Consider `[experimental] autoMemoryReclaim` guidance in `references/wsl.md` — surfaced independently by 3 of 4 wslconfig-cap runs from live Microsoft docs; currently absent from the reference.

## Environment finding (outside skill scope, affects all local agent work)

All 12 subagents and several main-thread shell calls hit lean-ctx wrapper interference: `Read` returning false "unchanged since last read" dedup placeholders on first reads, `cat`/`head`/`ps` aliased to missing `_lc`/`rtk` shims breaking pipes, one spurious WARN injected into file output. Agents recovered via `command cat`/`bash -c`, but this layer actively corrupts tool I/O and inflates token use; worth auditing the lean-ctx MCP/hook install.
