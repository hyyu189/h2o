---
name: roundtable
description: >-
  Coordination layer for collocated agents (Hermes, Claude, Codex) that share one
  cmux workspace and message each other through the rt-* CLI tools. Invoke whenever
  the project has .roundtable/agents.yaml, an inbound [FROM→TO kind id=...] message
  arrives, or the user mentions another collocated agent, rt-say, rt-ack, handoff,
  or coordinating with another agent — even if the skill isn't named. Missing an
  inbound message silently breaks the exchange, so trigger eagerly.
version: 5.0.0
author: Roundtable contributors
license: MIT
platforms: [linux, macos]
---

# Roundtable

Collocated agents (Hermes, Claude, Codex) share one cmux workspace and talk through
the `rt-*` CLI tools. Address agents by **name**, never by surface id — the tools
resolve which surface an agent occupies and how to submit to it, and both drift as
agents restart and move.

## Tools (on PATH via ~/.roundtable/bin/)

| Tool | Purpose |
|------|---------|
| `rt-say <agent> <kind> "body"` | Send — resolves the surface, picks the submit key, tags it, blocks self-echo. |
| `rt-ack <id>[,<id>...] ["note"]` | Acknowledge received message(s). Comma-batches. |
| `rt-inbox` | List un-ack'd inbound messages. |
| `rt-resolve <agent>` | Print an agent's status + current surface ref. |
| `rt-refresh` | Rebuild the topology map (runtime.json) from the live cmux tree. |

Run them from a project root (a dir with `.roundtable/agents.yaml`). Outside one,
set `ROUNDTABLE_PROJECT_DIR` or `RT_FALLBACK_PROJECT` to point at a fallback project.

## Sending

`rt-say <agent> <kind> "body"`. `kind` is a free triage label (fyi, question,
answer, proposal, review, correction, directive, urgent) with no effect on delivery
— pick the closest and move on. For anything long, write `handoff/<topic>.md`,
commit, and rt-say a one-line pointer instead of pasting walls of text.

## Receiving

1. Inbound arrives as `[FROM→YOU kind id=<msg_id>] body`.
2. Do what it asks.
3. `rt-ack <msg_id> ["note"]` — batch with commas: `rt-ack id1,id2,id3`.

Ack because it's the sender's only delivery confirmation; un-ack'd, they can't tell
whether you saw it.

## Multi-instance

A harness can run more than one instance, each in its own **cmux-launched** surface.
Define them under `instances:` in `agents.yaml` and address each by its `id`
(verbatim, never auto-numbered); a single instance just reuses the base name
(`codex`). `rt-refresh` maps each instance to its surface from cmux's authoritative
`surface.list` binding, distinguishing same-harness instances by launch `cwd`
(primary anchor) then terminal `title`:

```yaml
instances:
  - { id: codex-build,  match: { cwd: /path/to/build } }
  - { id: codex-review, match: { title: review } }
```

Instances must be cmux-launched — that's how roundtable agents normally start. An
agent typed into a plain shell carries no cmux binding and won't be tracked.

## Raw cmux/tmux fallback

`rt-say` is a convenience wrapper, not a gate. If it's unavailable or misbehaving,
send directly with `cmux send` / `cmux send-key` (or `tmux send-keys`) — but do the
two things the wrapper normally handles for you:

1. **Resolve the surface first** (`rt-resolve <agent>`); cached ids go stale.
2. **Match the submit key to the target's state** — wrong key on a *busy* agent can
   submit into the wrong prompt:

   | Agent | Idle | Busy |
   |-------|------|------|
   | Claude | text + Enter | text only, no Enter (interrupt-safe) |
   | Codex | text + Enter | text + **Tab** (Enter submits the wrong prompt) |
   | Hermes | text + Enter | prepend `/steer`, then Enter (injects next turn) |

## When messages vanish

`rt-say` says `sent` but the target never reacts → the topology map is stale (a
surface moved on restart). `rt-refresh`, confirm with `rt-resolve` / `cmux
read-screen`, resend. Most common failure — reach for it first.

## More

Optional multi-agent playbooks (cross-agent freeze/merge signoff, `/goal` build
dispatch) live in `~/.roundtable/docs/workflows/` — not needed for ordinary messaging.
