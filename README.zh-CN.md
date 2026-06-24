# h2o

[English](./README.md) | **中文**

一个为共享 [cmux](https://cmux.com) 工作区的多个 AI 编程 agent 提供协调通信的层。

**H2O = Harness Over Harness** —— 一个 harness 编排另一个，跨 cmux surface。多个 agent（Claude Code、Codex、Hermes —— 或任意组合）通过 `rt-*` CLI 工具互发消息，自动追踪拓扑、管理提交按键、检测忙碌状态。

## 前置要求

- **macOS**（cmux 仅支持 macOS）
- **cmux** 0.64.11+ — [安装](https://cmux.com)
- **Python 3.8+** 及 PyYAML
- 至少一个 AI 编程 agent：
  - [Claude Code](https://docs.anthropic.com/en/docs/claude-code)
  - [Codex CLI](https://github.com/openai/codex)
  - [Hermes Agent](https://github.com/NousResearch/hermes-agent)
  - 或任何 cmux 支持的 agent（Grok、OpenCode、Kiro、Cursor 等）

## 安装

### 一行命令

```bash
git clone https://github.com/hyyu189/h2o.git && cd h2o && chmod +x install.sh && ./install.sh
```

### 手动安装

```bash
git clone https://github.com/hyyu189/h2o.git
cd h2o
chmod +x install.sh
./install.sh
```

安装脚本会：
1. 将 `rt-*` 工具复制到 `~/.roundtable/bin/`（加入 PATH）
2. 将 `roundtable` skill 安装到 `~/.skills/shared/roundtable/`
3. 自动检测已安装的 harness，在各自的 skill 目录创建 symlink
4. 安装 cmux agent hooks（事件追踪）
5. 将 `~/.roundtable/bin` 加入 shell PATH（支持 zsh/bash/fish）

### Agent 友好安装（给 AI agent 看的）

如果你是一个 AI agent，被指示安装 h2o：

```bash
# 1. 克隆并安装
git clone https://github.com/hyyu189/h2o.git /tmp/h2o
cd /tmp/h2o && chmod +x install.sh && ./install.sh

# 2. 刷新 shell 配置以获取 rt-* 命令
source ~/.zshrc  # 或 ~/.bashrc

# 3. 验证
rt-resolve --help
roundtable-init --help

# 4. 创建项目并开始协作
roundtable-init my-project
cd my-project
rt-refresh --bind-current
rt-watch-ensure
```

不需要 sudo。所有文件都在 `~/.roundtable/`、`~/.skills/` 和各 harness 的 skill 目录下。

## 快速开始

```bash
# 1. 创建项目
roundtable-init my-project
cd my-project

# 2. 将当前 cmux 工作区绑定到此项目
rt-refresh --bind-current

# 3. 启动拓扑监听器（会在 cmux 里开一个专用 surface）
rt-watch-ensure

# 4. 在 cmux 里启动你的 agent（每个 agent 一个 surface）
#    cmux hooks 已经自动安装了事件追踪

# 5. 查看 agent 状态
rt-resolve claude
rt-resolve codex

# 6. 发消息
rt-say codex question "build 过了吗？"
rt-say claude proposal "新 API 设计在 handoff/design.md"

# 7. 确认收到消息
rt-ack <msg_id> "收到"
```

## 标准发送流程

**始终：`rt-refresh → rt-resolve → rt-say`**

```bash
rt-refresh                    # 1. 从 cmux 重建拓扑
rt-resolve codex              # 2. 确认目标已映射且位置正确
rt-say codex question "..."   # 3. 发送（使用现有拓扑——不会自动刷新）
```

`rt-say` 故意不在内部自动刷新。在 resolve 和 send 之间刷新会导致拓扑变化，消息可能发到错误的 surface。先刷新，再发送。

## 工作原理

```
┌─ cmux 工作区 ────────────────────────────────────────┐
│                                                      │
│  ┌─ Surface 1 ─┐  ┌─ Surface 2 ─┐  ┌─ Surface 3 ─┐  │
│  │ Claude Code  │  │   Codex      │  │   Hermes    │  │
│  │              │  │              │  │             │  │
│  └──────┬───────┘  └──────┬───────┘  └──────┬──────┘  │
│         │                  │                  │        │
│         └──────────┬───────┴──────────┬───────┘        │
│                    │                  │                │
│              cmux socket API    cmux events            │
│                    │                  │                │
│              ┌─────┴──────┐  ┌───────┴───────┐        │
│              │  rt-say    │  │   rt-watch     │        │
│              │  rt-ack    │  │   (拓扑追踪)    │        │
│              │  rt-resolve│  │                │        │
│              └────────────┘  └────────────────┘        │
│                                                      │
│  .roundtable/                                        │
│    agents.yaml    ← agent 配置（提交策略）             │
│    runtime.json   ← 实时拓扑缓存                      │
│    messages/      ← 消息账本（JSONL）                  │
└──────────────────────────────────────────────────────┘
```

**rt-say** 解析目标 agent 在哪个 cmux surface 上，选择正确的提交按键（Enter / Tab / send-only / /steer，根据 agent 和忙碌状态），打 tag 后发送。自动阻止自发自收和 surface-agent 不匹配。

**rt-watch** 监听 `cmux events --category agent`，实时追踪 agent 生命周期（busy / idle / in-tool / waiting-permission），更新 `runtime.json`。

**rt-refresh** 从 cmux 的 `surface.list` API 重建拓扑。使用屏幕 banner 探测交叉校验 cmux binding（处理 agent 重启后 surface 复用导致 binding 过期的情况）。

## 配置

### agents.yaml

每个项目有 `.roundtable/agents.yaml`：

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

### 添加自定义 agent

任何 cmux 支持的 agent 都可以用——只需加到 `agents.yaml`：

```yaml
agents:
  grok:
    harness: grok
    instances:
      - id: grok
    submit:
      idle: enter
      busy: send_only
    detect:
      screen: ["Grok CLI"]
```

### 多实例

同一个 harness 跑多个实例：

```yaml
agents:
  codex:
    instances:
      - id: codex-build
        match: { cwd: /path/to/build }
      - id: codex-review
        match: { title: review }
```

按 `id` 寻址：`rt-say codex-build question "..."`

## 工具列表

| 工具 | 用途 |
|------|------|
| `rt-say <agent> <kind> "body"` | 向另一个 agent 发消息 |
| `rt-ack <msg_id>[,<id>...] ["note"]` | 确认收到消息（支持批量） |
| `rt-inbox` | 列出未确认的收件 |
| `rt-resolve <agent>` | 打印 agent 状态 + 当前 surface |
| `rt-refresh` | 从 cmux 重建拓扑 |
| `rt-refresh --bind-current` | 刷新 + 绑定当前 cmux 工作区 |
| `rt-refresh --bind <workspace_ref>` | 绑定到指定工作区 |
| `roundtable-init <name>` | 创建新项目 |
| `rt-watch-ensure` | 启动/复用拓扑监听 surface |

## 消息类型

`question` · `answer` · `proposal` · `fyi` · `directive` · `review` · `correction` · `urgent`

类型仅用于分类，不影响投递。

## 环境变量

| 变量 | 默认值 | 用途 |
|------|--------|------|
| `ROUNDTABLE_PROJECT_DIR` | (无) | 覆盖项目根目录 |
| `RT_FALLBACK_PROJECT` | (无) | 不在项目内时的兜底项目 |
| `RT_PROJECTS_DIR` | (无) | 项目所在目录（用于工作区绑定查找） |
| `ROUNDTABLE_INSTALL_DIR` | `~/.roundtable` | 工具/模板/文档安装位置 |
| `ROUNDTABLE_SKILL_DIR` | `~/.skills/shared/roundtable` | skill 安装位置 |
| `RT_FROM` | (无) | 覆盖发送者身份（自动检测失败时用） |

## 卸载

```bash
cd h2o
./uninstall.sh
```

逐文件删除工具、skill、symlink 和模板（不是 `rm -rf`）。已有项目的 `.roundtable/` 目录不受影响。

## 开源协议

[MIT](./LICENSE)

## 致谢

由 [Ocean Yu](https://github.com/hyyu189) 与 Claude Code、Codex、Hermes Agent 作为原始三 agent 圆桌系统共同构建。系统在生产级多 agent 工作流中经过实战验证后提取为本插件。
