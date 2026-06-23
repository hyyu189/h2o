# cmux Agent Events — schema and migration notes

Reference for roundtable tool authors. Covers the `cmux events --category agent`
stream that `rt-watch` consumes.

## Event structure

```json
{
  "boot_id": "F1976710-...",
  "category": "agent",
  "id": "F1976710-...-136",
  "name": "agent.hook.SessionStart",
  "occurred_at": "2026-06-08T19:36:59.326Z",
  "payload": {
    "_source": "claude",
    "_received_at": "...",
    "hook_event_name": "SessionStart",
    "phase": "received",
    "session_id": "...",
    "cwd": "/Users/...",
    "workspace_id": "..."
  },
  "protocol": "cmux-events",
  "seq": 136,
  "source": "claude",
  "type": "event",
  "version": 1,
  "workspace_id": "..."
}
```

## Hook event names (as of cmux ≥0.64.14)

| hook_event_name | phase values | meaning |
|-----------------|-------------|---------|
| `SessionStart` | received, completed | Agent session begins |
| `SessionEnd` | received, completed | Agent session ends (replaced `Stop`) |
| `UserPromptSubmit` | received, completed | User submitted a prompt |
| `PreToolUse` | received, completed | Agent about to call a tool |
| `PostToolUse` | received, completed | Agent finished tool call (new in ≥0.64.11) |

## Migration: `Stop` → `SessionEnd`

**Breaking change for rt-watch.** The old `Stop` hook is gone. All agent
lifecycle endings now emit `SessionEnd`.

rt-watch's `status_from_frame()` checks `hook == "Stop"` to mark agents as
`"idle"`. This no longer fires. Fix: add `or hook == "SessionEnd"` to the
condition.

Also: `SessionEnd` has `phase: "completed"` with `result.status: "acknowledged"`,
same shape as the old `Stop`.

## Agent source identifiers

cmux events use different source strings per agent:
- `claude`, `codex`, `grok`, `opencode`, `pi`, `cursor`, `gemini`, `kiro`, `copilot`, `codebuddy`, `factory`, `qoder`
- `hermes-agent` (with hyphen!) — NOT `hermes`
- `antigravity` (alias: `agy`)

rt-watch's `frame_agent()` does substring matching (`"hermes" in "hermes-agent"`)
so it resolves correctly. Custom tooling doing exact string comparison must
account for this.

## `PermissionRequest` no longer in event stream

Permission requests now route exclusively through the Feed system
(`cmux hooks feed`), not through `cmux events --category agent`.

## `cmux events` CLI flags (≥0.64.14)

```
cmux events
  --after <seq>          Replay after sequence number
  --cursor-file <path>   Persistent cursor (rt-watch uses this)
  --name <event>         Filter by name, repeatable
  --category <name>      Filter by category, repeatable
  --reconnect            Auto-reconnect on disconnect
  --limit <n>            Exit after N events
  --no-ack               Skip subscription ack frame
  --no-heartbeat         Suppress heartbeat frames
```

## Feed sidebar gating (≥0.64.12)

Feed is gated behind Beta Features, default OFF. If any roundtable workflow
depends on `cmux hooks feed` for inter-agent communication, the user must
enable it:

```json
// ~/.config/cmux/cmux.json
{ "rightSidebar": { "beta": { "feed": { "enabled": true } } } }
```

Roundtable's core message-passing (`rt-say`/`rt-ack`) uses `cmux send`, not
Feed, so the gating doesn't affect basic communication.
