# Freeze Workflow — cross-agent branch freeze & merge

When the project owner wants to freeze a project branch and merge to main, get cross-agent
signoff first. This pattern was proven 2026-06-08 on `feat/match-chatbot` → `main`.

## When to use

- the project owner asks "what's different between X and main" or "freeze this project"
- The branch has contributions from multiple agents (Claude/Codex/Hermes)
- Merge will change main — other agents should confirm nothing is missed

## Steps

1. **Analyze the diff.** `git log main..<branch> --oneline`, `git diff --stat`,
   `git log <branch>..main --oneline` (both directions). Check for dirty
   working tree (`git status --short`), stashes, untracked files, submodule
   drift.

2. **Check existing tags.** `git tag --list 'archive/*'` to see what's already
   frozen.

3. **Write handoff.** Summarize the branch layers, dirty state, tag situation,
   and the proposed freeze plan in `handoff/freeze-check-<date>.md`. Keep it
   under 3KB — just enough for agents to verify.

4. **Send to both agents.** Use `rt-say claude question` and `rt-say codex
   question` with a short pointer to the handoff file. Give Claude the "review
   architecture/carry-over accuracy" angle; give Codex the "verify tests/build
   still green" angle.

5. **Wait for both reviews.** They'll ack first, then reply with their review
   (usually also in handoff files). Ack each inbound message with `rt-ack <id>`.

6. **Synthesize.** Read both reviews, find the consensus. Report back to the project owner
   with a table of agreed/divergent points and a recommendation.

7. **Execute.** the project owner's call. Typical freeze: commit any drift → tag
   `archive/<project>-v<N>` → `git checkout main && git merge <branch>`.

## Pitfalls

- **Don't fix docs unless asked.** the project owner's preference: minimal intervention.
  Stale READMEs, doc inconsistencies, dead UI links — note them in the freeze
  record, don't fix them.
- **Docs submodule drift is common.** The `docs/` submodule (private docs hub)
  often drifts. Check whether the uncommitted pointer is on origin/main before
  deciding commit vs reset.
- **Agents may commit their review to the branch.** That's fine — Claude
  sometimes does this. Their review becomes part of the merge.
