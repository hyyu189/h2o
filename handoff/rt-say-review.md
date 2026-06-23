# rt-say routing fix — review (Claude)

Reviewer: Claude · 2026-06-23 · Commit under review: `7590a7e`
(fix(rt-say): stop auto-refresh, add surface-agent mismatch guard)

## Verdict
The intent is right and three of the four changes are sound. But the commit's headline
guarantee — "the topology map can't shuffle between rt-resolve and the send" — is **not
actually achieved**, because the resolve path still auto-refreshes. And the new guard has
a **multi-instance false-positive that breaks `rt-say <instance-id>` entirely**. Fix both
before relying on this.

---

## Per-change assessment

### 1. `read_runtime()` drops the project-mismatch auto-refresh → fails loudly ✅
Correct. `runtime.project` is always written as `str(ROOT)` by rt-refresh, so a mismatch
means a stale/cross-project file — self-rebuilding that silently was hiding a real
problem. Failing is the right behavior. Bootstrap refresh (missing/empty file) is retained.

### 2. `infer_sender()` no auto-refresh, returns `RT_FROM` ✅ (one nit)
Consistent with the no-shuffle goal. This is exactly why a send from a not-yet-mapped
surface now needs `RT_FROM` (observed live). **Nit:** `RT_FROM` is returned unvalidated —
if it names a non-existent agent, the message is recorded `from` a bogus sender with no
error. Consider validating `RT_FROM` against `runtime["agents"]` and erroring on unknown.

### 3. `main()` reads the map once, no forced refresh, drops the redundant second read ✅
Good — one consistent snapshot instead of two reads that could disagree, and it removes
the forced refresh that was the main shuffle source. See the gap below, though.

### 4. Surface-agent mismatch guard ⚠️ has a real bug
Right idea (catches the "resolved to a surface that's actually another agent" class — the
codex→watcher mismap). Two problems:

**4a. 🔴 Multi-instance false positive — breaks instance addressing.**
`rt-resolve` prints `agent={base} instance={id}` (`rt-resolve:112`), so `parse_resolve`
sets `route["agent"] = base`. The guard then uses `target_agent = route.get("agent")`
(`rt-say:320`) = the **base** name. But `rt-refresh` keys multi-instance agents in
runtime by **instance id** (`codex`, `codex#1`, `codex-build`, …). So for
`rt-say codex#1 …`:
- route_surface = surface:50 (codex#1's surface)
- runtime agent at surface:50 has `name = "codex#1"`
- guard: `name("codex#1") != target_agent("codex")` → **raises "route mismatch"** on a
  perfectly correct route.

Single-instance is unaffected (base == instance key). But every multi-instance send now
fails. **Fix:** compare against the resolved instance id, not the base:
```python
resolved = {route.get("agent"), route.get("instance")}
if agent_data.get("surface_ref") == route_surface and name not in resolved:
    raise SystemExit(...)
```

**4b. ⚠️ The guard runs against a snapshot taken *before* resolution — see the gap.**

---

## 🔴 The headline guarantee has a gap: resolution still auto-refreshes

The commit stops rt-say from refreshing, but `route = parse_resolve(target)`
(`rt-say:106`) shells out to **`rt-resolve`**, and rt-resolve **auto-refreshes**:
- `rt-resolve:95-96` — if the target isn't found in the current map, it runs `rt-refresh`
  and reloads (self-heal), and `load_runtime` also refreshes a missing/empty file.

So the sequence in `main()` is:
1. `runtime = read_runtime()` → **snapshot A** (no refresh) — used by `infer_sender`,
   `guard_route_in_runtime`, and the new mismatch guard.
2. `route = parse_resolve(target)` → may **rewrite runtime.json** (snapshot B) and returns
   a route from B.
3. Guards compare **route (from B)** against **snapshot A**.

When the target wasn't already mapped (the fresh/just-moved-agent case — precisely the
risky one), B ≠ A and:
- the mismatch guard can **false-negative** (route_surface absent from A → no check), or
- **false-positive** (a different agent occupied that surface in A).

So the very shuffle the commit set out to kill still happens through the resolve path.
**Fix options (in order of preference):**
- **Best:** extract resolution into a shared `_rtlib` function and call it in-process
  against snapshot A (no subprocess, no second read, no refresh) — see Simplification #1.
- Or: re-read runtime *after* `parse_resolve` and run all guards against that single
  post-resolve snapshot.
- Or: give rt-resolve a `--no-refresh` mode and have rt-say use it.

---

## Simplification across rt-say / rt-refresh / rt-resolve

The writer/reader split is healthy — **don't merge the tools**. `rt-refresh` as the sole
runtime.json *writer*, `rt-resolve`/`rt-say` as *readers*, is good separation. The wins
are in extracting shared logic, not collapsing CLIs.

**1. (highest value) Extract agent resolution into `_rtlib`.** Today rt-say resolves by
spawning `rt-resolve` and **parsing its `key=value` stdout** (`parse_resolve`,
`rt-say:105-112`) — a brittle text contract (breaks if any value ever contains a space or
`=`), plus a subprocess, plus a *second* runtime read inside rt-resolve. Move
`resolve_config_target` + `pick_runtime_agent` into `_rtlib` as
`resolve_agent(root, runtime, target)`. Then:
- `rt-resolve` becomes a thin CLI that formats the result;
- `rt-say` calls it in-process against its own snapshot — which **simultaneously fixes the
  shuffle gap (4b/§above), removes the fragile text parse, and drops the double read.**
One refactor closes three issues.

**2. Prune dead `session_id` machinery in `rt-resolve`.** The slim agents.yaml schema
dropped `instances[].session_id`, and rt-refresh now writes `session_checkpoint_id`
(`rt-refresh:369`), not `session_id`. But rt-resolve still carries a whole `session_id`
pathway: defaults at `:36,:40,:43,:52`, the matching branch `pick_runtime_agent:73-81`
(matches `value.get("session_id")` which runtime never sets → dead), and the print at
`:113-114`. It's all unreachable now — delete it. (If per-session addressing is still
wanted, re-key it on `session_checkpoint_id` instead.)

**3. Unify the instance model.** Both `rt-refresh.assign_agents` (cwd/title `match`) and
`rt-resolve.resolve_config_target` (instances → runtime entry) independently interpret
`instances[]`. Consider one shared "instance config" parser in `_rtlib` so the two can't
drift. Lower priority than #1/#2.

**4. Minor:** `infer_sender` (surface→name) and `pick_runtime_agent` (name→surface) both
walk `runtime["agents"]`; a single index built once from the snapshot would serve both.

## Fix order
1. **4a** (multi-instance false positive — functional regression).
2. **§gap / 4b** via Simplification **#1** (closes the shuffle hole *and* the brittle parse
   *and* the double read in one move).
3. **#2** dead session_id prune. 4. #3, #4, infer_sender RT_FROM validation.
