# /goal Dispatch — sustained multi-agent work assignment

When the project owner wants Codex and Claude to work on a build task in parallel
(Codex=executor, Claude=second opinion), use the `/goal` dispatch pattern.
Proven 2026-06-08 on `feat/sim-pipeline-mvp`.

## When to use

- the project owner says "让 codex 和 claude 同时开工" or similar
- The task is a build (not a review/audit) that needs code produced
- Two distinct roles: one builds, one reviews
- The task is bounded — a clear deliverable, not an open-ended exploration

## Steps

1. **Write a BRIEF.md.** Put it in `workstreams/YYYY-MM-DD-<name>/BRIEF.md`.
   Sections: Goal, scope, existing assets, MVP deliverable, design constraints,
   execution roles. Keep it concrete — what to build, what NOT to build,
   what data to use.

2. **Create the branch.** `git checkout -b feat/<name>` off main (or the
   appropriate base). Commit the BRIEF.

3. **(Optional) Pre-build design review.** If the task has a canonical
   contract (upstream spec, architecture doc, interface definition), have
   Claude review the BRIEF *against that contract* before Codex writes
   code. Claude catches contract drift (missing fields, type mismatches,
   seam violations) while the fix costs nothing. Send:

   ```
   rt-say claude question "pre-build review: <brief path> vs <contract path>.
   检查 contract drift / missing fields / type mismatch before Codex 开工。"
   ```

   Claude's review becomes a committed flag file. Hermes forwards the
   findings to Codex with the `/goal` dispatch. This pattern caught
   3 SimResult gaps + 1 seam leak on sim-pipeline-mvp before a single
   line was written — saved hours of rework.

4. **Send /goal to both agents.** Use `rt-say <agent> directive` with
   `/goal` as the first word. Give each agent a distinct role description:

   ```
   rt-say codex directive "/goal <task summary>. 完整 brief 在 <path>。
   你的角色：executor — <specific build instructions>。"

   rt-say claude directive "/goal <task summary>. 完整 brief 在 <path>。
   你的角色：second opinion — <specific review instructions>。"
   ```

5. **Ack their sync-ack responses.** They'll confirm receipt before starting.

## Pitfalls

- **Don't over-specify the how.** BRIEF.md defines the seams and the output
  shape; let agents choose implementation details.
- **Codex builds, Claude reviews, never both build.** Parallel builds on the
  same code create merge conflicts. If both need to build, split the territory
  explicitly in the brief.
- **Don't /goal for open-ended research.** /goal is for build tasks with a
  clear deliverable. For research/discovery, use `rt-say question` instead.
- **Branch must exist before sending.** Agents pull the latest branch on
  startup. Create and commit the BRIEF first.
- **Mid-build course correction — use `correction` kind.** If the project owner or Hermes
  changes the approach after agents have started (e.g. switching from
  WeightedSumEngine to ZOXEXIVO), send `rt-say <agent> correction` with the
  new directive. Don't let agents continue on the wrong path — stop and
  redirect immediately.
- **Verify agent branch after dispatch.** Agents may start on whatever branch
  their terminal was last on. After `/goal` dispatch, use `cmux read-screen`
  on each surface and check the prompt line for `git:<branch>`. If wrong,
  send a `correction` with `git checkout <branch>`.
- **After agent restart, rebuild topology BEFORE re-dispatching.** Agent
  restarts shuffle surface assignments. Always `rt-refresh` → `rt-resolve` →
  `cmux read-screen` → re-send directives. See roundtable pitfall #4.
- **Mid-build corrections go to BOTH agents simultaneously.** When Hermes
  changes scope (e.g. "改用 ZOXEXIVO 而非 WeightedSum"), Codex needs to
  stop wrong work AND Claude needs to update review criteria. Send correction
  to both at once, not one at a time.
- **The review loop is serial, not parallel.** Codex commits → Claude reviews
  the commit → if issues, Codex fixes → Claude re-reviews. Claude cannot
  review code that doesn't exist yet. Don't expect simultaneous work;
  the dependency chain is natural and correct.
- **the project owner's scope rule — only what he explicitly omits IS omitted.** When
  scoping an MVP, list what's OUT explicitly. Everything else must be
  verified with real data (not synthetic), real engines (not statistical
  substitutes), and full attribute sets (not compressed vocabularies).
  If the project owner says "use the most detailed open-source engine" and the
  executor builds a weighted-sum statistical model, that's a scope
  violation — correct immediately. the project owner: "我没说可以省略的步骤，
  要全量验证."
