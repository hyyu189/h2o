# /goal Dispatch — sustained multi-agent work assignment

When the project owner wants Codex and Claude to work a build task in parallel
(Codex = executor, Claude = second opinion), use the `/goal` dispatch pattern.

## When to use

- The project owner says "让 codex 和 claude 同时开工" or similar.
- The task is a build (not a review/audit) that needs code produced.
- Two distinct roles: one builds, one reviews.
- The task is bounded — a clear deliverable, not open-ended exploration.

## Steps

1. **Write a BRIEF.md** in `workstreams/YYYY-MM-DD-<name>/BRIEF.md`. Sections: goal,
   scope, existing assets, MVP deliverable, design constraints, execution roles. Be
   concrete — what to build, what NOT to build, what data to use.

2. **Create the branch.** `git checkout -b feat/<name>` off main (or the appropriate
   base). Commit the BRIEF.

3. **(Optional) Pre-build design review.** If the task has a canonical contract
   (upstream spec, architecture doc, interface definition), have Claude review the
   BRIEF *against that contract* before Codex writes code — it catches contract drift
   (missing fields, type mismatches, seam violations) while the fix costs nothing:

   ```
   rt-say claude question "pre-build review: <brief path> vs <contract path>.
   检查 contract drift / missing fields / type mismatch before Codex 开工。"
   ```

   Claude's review becomes a committed flag file; forward the findings to Codex with
   the `/goal` dispatch.

4. **Send /goal to both agents.** `rt-say <agent> directive` with `/goal` as the first
   word. Give each a distinct role:

   ```
   rt-say codex directive "/goal <task summary>. 完整 brief 在 <path>。
   你的角色：executor — <specific build instructions>。"

   rt-say claude directive "/goal <task summary>. 完整 brief 在 <path>。
   你的角色：second opinion — <specific review instructions>。"
   ```

5. **Ack their sync-acks.** They confirm receipt before starting.

## Pitfalls

- **Don't over-specify the how.** BRIEF.md defines the seams and output shape; let
  agents choose implementation details.
- **Codex builds, Claude reviews — never both build.** Parallel builds on the same
  code create conflicts. If both must build, split territory explicitly in the brief.
- **Don't /goal open-ended research.** /goal is for build tasks with a clear
  deliverable. For research/discovery use `rt-say question` instead.
- **Branch must exist before sending.** Agents pull the latest branch on startup —
  create and commit the BRIEF first.
- **Mid-build course correction — use the `correction` kind.** If the approach changes
  after agents start, send `rt-say <agent> correction` with the new directive to BOTH
  agents at once (executor stops the wrong work; reviewer updates its review criteria).
  Don't let them continue on the wrong path.
- **Verify agent branch after dispatch.** Agents may start on whatever branch their
  terminal was last on. After dispatch, `cmux read-screen` each surface and check the
  prompt's `git:<branch>`; if wrong, send a `correction` with `git checkout <branch>`.
- **After an agent restart, rebuild topology before re-dispatching.** Restarts shuffle
  surface assignments: always `rt-refresh` → `rt-resolve` → `cmux read-screen` →
  re-send.
- **The review loop is serial, not parallel.** Codex commits → Claude reviews → if
  issues, Codex fixes → Claude re-reviews. Claude can't review code that doesn't exist
  yet; the dependency chain is natural.
- **Scope rule — only what's explicitly omitted IS omitted.** When scoping an MVP,
  list what's OUT explicitly; everything else must be done fully — real data (not
  synthetic), real engines (not statistical substitutes), full attribute sets (not
  compressed). "我没说可以省略的步骤，要全量验证。"
