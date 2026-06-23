# roundtable-cmux

A coordination layer for collocated AI coding agents that share a [cmux](https://cmux.com) workspace. Three agents (Claude Code, Codex, Hermes — or any combination) message each other through `rt-*` CLI tools, with automatic topology tracking, submit-key management, and busy-state detection.

## Requirements

- **macOS** (cmux is macOS-only)
- **cmux** 0.64.11+ — [install](https://cmux.com)
- **Python 3.8+** with PyYAML
- At least one AI coding agent harness installed:
  - [Claude Code](https://docs.anthropic.com/en/docs/claude-code)
  - [Codex CLI](https://github.com/openai/codex)
  - [Hermes Agent](https://github.com/NousResearch/hermes-agent)
  - Or any other cmux-supported agent (Grok, OpenCode, Kiro, Cursor, etc.)

## Install

```bash
git clone https://github.com/YOUR/roundtable-cmux.git
cd roundtable-cmux
chmod +x install.sh
./install.sh
```

The installer will:
1. Copy `rt-*` tools to `~/.roundtable/bin/` (on PATH)
2. Install the `roundtable` skill to `~/.skills/shared/roundtable/`
3. Wire symlinks into each detected harness skill directory
4. Install cmux agent hooks for event tracking
5. Add `~/.roundtable/bin` to your shell PATH

## Quick start

```bash
# 1. Create a project
roundtable-init my-project
cd my-project

# 2. Bind the current cmux workspace to this project
rt-refresh --bind-current

# 3. Start the topology watcher
rt-watch-ensure

# 4. Launch your agents in cmux (one per workspace surface)
#    cmux hooks setup already wired event tracking

# 5. Check agent status
rt-resolve claude
rt-resolve codex

# 6. Send a message
rt-say codex question "is the build passing?"
rt-say claude proposal "see handoff/design.md for the new API"

# 7. Acknowledge received messages
rt-ack <msg_id> "received"
```

## How it works

```
┌─ cmux workspace ────────────────────────────────────┐
│                                                     │
│  ┌─ Surface 1 ─┐  ┌─ Surface 2 ─┐  ┌─ Surface 3 ─┐ │
│  │  Claude Code │  │   Codex      │  │   Hermes    │ │
│  │              │  │              │  │             │ │
│  └──────┬───────┘  └──────┬───────┘  └──────┬──────┘ │
│         │                  │                  │       │
│         └──────────┬───────┴──────────┬───────┘       │
│                    │                  │               │
│              cmux socket API    cmux events           │
│                    │                  │               │
│              ┌─────┴──────┐  ┌───────┴───────┐       │
│              │  rt-say    │  │   rt-watch     │       │
│              │  rt-ack    │  │   (topology)   │       │
│              │  rt-resolve│  │                │       │
│              └────────────┘  └────────────────┘       │
│                                                     │
│  .roundtable/                                       │
│    agents.yaml    ← agent config (submit policy)     │
│    runtime.json   ← live topology cache              │
│    messages/      ← message ledger (JSONL)           │
└─────────────────────────────────────────────────────┘
```

**rt-say** resolves which cmux surface an agent occupies, picks the right submit key (Enter / Tab / send-only / /steer based on agent + busy state), tags the message, and sends it. Self-echo is blocked automatically.

**rt-watch** listens to `cmux events --category agent` and tracks agent lifecycle (busy / idle / in-tool / waiting-permission) in real time, updating `runtime.json` so `rt-say` always targets the right surface.

## Configuration

### agents.yaml

Each project has `.roundtable/agents.yaml`:

```yaml
schema: roundtable.agents.v1
project: /path/to/my-project
agents:
  claude:
    harness: claude-code
    instances:
      - id: claude
    submit:
      idle: enter
      busy: send_only
    detect:
      screen: ["Claude Code"]

  codex:
    harness: codex
    instances:
      - id: codex
    submit:
      idle: enter
      busy: tab
    detect:
      screen: ["OpenAI Codex"]

  hermes:
    harness: hermes-agent
    instances:
      - id: hermes
    submit:
      idle: enter
      busy: steer
    detect:
      screen: ["Welcome to Hermes Agent"]
```

### Multi-instance

Run multiple instances of the same harness:

```yaml
agents:
  codex:
    instances:
      - id: codex-build
        match: { cwd: /path/to/build }
      - id: codex-review
        match: { title: review }
```

Address each by its `id`: `rt-say codex-build question "..."`

## Tools

| Tool | Purpose |
|------|---------|
| `rt-say <agent> <kind> "body"` | Send a message to another agent |
| `rt-ack <msg_id>[,<id>...] ["note"]` | Acknowledge received message(s) |
| `rt-inbox` | List un-ack'd inbound messages |
| `rt-resolve <agent>` | Print agent status + current surface ref |
| `rt-refresh` | Rebuild topology map from cmux tree |
| `rt-refresh --bind-current` | Refresh + bind current cmux workspace |
| `roundtable-init <name>` | Scaffold a new roundtable project |
| `rt-watch-ensure` | Start/reuse the topology watcher surface |

## Message kinds

`question` · `answer` · `proposal` · `fyi` · `directive` · `review` · `correction` · `urgent`

Kinds are documentary — they help receivers triage. No delivery difference.

## Environment variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `ROUNDTABLE_PROJECT_DIR` | (none) | Override project root |
| `RT_FALLBACK_PROJECT` | (none) | Fallback project when cwd isn't in one |
| `RT_PROJECTS_DIR` | (none) | Directory containing roundtable projects (for workspace binding lookup) |
| `ROUNDTABLE_INSTALL_DIR` | `~/.roundtable` | Where tools/templates/docs are installed |
| `ROUNDTABLE_SKILL_DIR` | `~/.skills/shared/roundtable` | Where the skill is installed |

## Uninstall

```bash
./uninstall.sh
```

Removes tools, skill, symlinks, and templates. Existing projects' `.roundtable/` directories are untouched.

## License

MIT

## Acknowledgments

Built by Ocean (haiyangyu) with Claude Code, Codex, and Hermes Agent as the original three-agent roundtable.
