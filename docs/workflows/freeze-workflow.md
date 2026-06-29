# Freeze Workflow — cross-agent branch freeze & merge

When the project owner wants to freeze a project branch and merge to main, and the
branch carries contributions from multiple agents, get cross-agent signoff first.

## When to use

- The project owner asks "what's different between X and main" or "freeze this project".
- The branch has contributions from multiple agents (Claude / Codex / Hermes).
- Merging will change main — other agents should confirm nothing is missed.

## Steps

1. **Analyze the diff — both directions.** `git log main..<branch> --oneline`,
   `git diff --stat`, `git log <branch>..main --oneline`. Check for a dirty working
   tree (`git status --short`), stashes, untracked files, and submodule drift.

2. **Check existing tags.** `git tag --list 'archive/*'` — see what's already frozen.

3. **Write a handoff.** Summarize the branch layers, dirty state, tag situation, and
   the proposed freeze plan in `handoff/freeze-check-<date>.md`. Keep it under ~3KB —
   just enough for agents to verify.

4. **Send to both agents.** `rt-say claude question` + `rt-say codex question` with a
   short pointer to the handoff. Give Claude the "review architecture / carry-over
   accuracy" angle; give Codex the "verify tests/build still green" angle.

5. **Wait for both reviews.** They ack first, then reply (often via their own handoff
   files). `rt-ack <id>` each inbound.

6. **Synthesize.** Read both reviews, find consensus, report back to the project owner
   with a table of agreed / divergent points and a recommendation.

7. **Execute — the project owner's call.** Typical freeze: commit any drift → tag
   `archive/<project>-v<N>` → `git checkout main && git merge <branch>`.

## Pitfalls

- **Don't fix docs unless asked.** Minimal intervention. Stale READMEs, doc
  inconsistencies, dead links — note them in the freeze record, don't fix them.
- **Submodule drift.** If the project uses submodules, the pointer often drifts. Check
  whether the uncommitted pointer is on `origin/main` before deciding commit vs reset.
- **Agents may commit their review to the branch.** That's fine — it becomes part of
  the merge.
