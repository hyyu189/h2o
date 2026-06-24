#!/bin/bash
#
# h2o — install script
#
# Installs the roundtable coordination layer for cmux users.
# Detects installed AI coding agent harnesses and wires symlinks.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="${ROUNDTABLE_INSTALL_DIR:-$HOME/.roundtable}"
SKILL_DIR="${ROUNDTABLE_SKILL_DIR:-$HOME/.skills/shared/roundtable}"

BOLD="\033[1m"
GREEN="\033[32m"
YELLOW="\033[33m"
RED="\033[31m"
RESET="\033[0m"

info()  { echo -e "${GREEN}✓${RESET} $1"; }
warn()  { echo -e "${YELLOW}⚠${RESET} $1"; }
fail()  { echo -e "${RED}✗${RESET} $1"; exit 1; }

# --- preflight ---
echo -e "${BOLD}h2o installer${RESET}"
echo ""

# Check cmux
if ! command -v cmux &>/dev/null; then
    fail "cmux not found on PATH. Install cmux first: https://cmux.com"
fi
CMUX_VER=$(cmux version 2>/dev/null | head -1 || echo "unknown")
info "cmux found: $CMUX_VER"

# Check Python 3
if ! command -v python3 &>/dev/null; then
    fail "python3 not found. Install Python 3.8+ first."
fi
info "python3 found: $(python3 --version)"

# Check PyYAML
if ! python3 -c "import yaml" 2>/dev/null; then
    warn "PyYAML not found — installing..."
    pip3 install pyyaml --user 2>/dev/null || pip3 install pyyaml 2>/dev/null || warn "could not install PyYAML (rt-* tools need it)"
fi
python3 -c "import yaml" 2>/dev/null && info "PyYAML OK" || warn "PyYAML missing — rt-* tools will fail to read agents.yaml"

echo ""

# --- install bin/ ---
echo -e "${BOLD}Installing tools to ${INSTALL_DIR}/bin/${RESET}"
mkdir -p "$INSTALL_DIR/bin"
for f in _rtlib.py rt-say rt-ack rt-resolve rt-refresh rt-watch rt-watch-ensure rt-inbox roundtable-init; do
    src="$SCRIPT_DIR/bin/$f"
    dst="$INSTALL_DIR/bin/$f"
    if [ ! -f "$src" ]; then
        warn "missing: $f"
        continue
    fi
    cp "$src" "$dst"
    chmod +x "$dst" 2>/dev/null || true
    info "installed: $f"
done

# --- install skill ---
echo ""
echo -e "${BOLD}Installing skill to ${SKILL_DIR}${RESET}"
mkdir -p "$SKILL_DIR"
cp "$SCRIPT_DIR/skill/SKILL.md" "$SKILL_DIR/SKILL.md"
info "skill installed: $SKILL_DIR/SKILL.md"

# --- install templates ---
echo ""
echo -e "${BOLD}Installing templates to ${INSTALL_DIR}/templates/${RESET}"
mkdir -p "$INSTALL_DIR/templates"
cp "$SCRIPT_DIR/templates/"* "$INSTALL_DIR/templates/"
info "templates installed"

# --- install docs ---
echo ""
echo -e "${BOLD}Installing docs to ${INSTALL_DIR}/docs/${RESET}"
mkdir -p "$INSTALL_DIR/docs/workflows"
cp "$SCRIPT_DIR/docs/cmux-events.md" "$INSTALL_DIR/docs/"
cp "$SCRIPT_DIR/docs/workflows/"* "$INSTALL_DIR/docs/workflows/"
info "docs installed"

# --- wire harness symlinks ---
echo ""
echo -e "${BOLD}Wiring harness skill symlinks${RESET}"

link_skill() {
    local harness_dir="$1"
    local harness_name="$2"
    if [ -d "$harness_dir" ]; then
        if [ -L "$harness_dir/roundtable" ]; then
            rm "$harness_dir/roundtable"
        elif [ -d "$harness_dir/roundtable" ]; then
            warn "$harness_name: roundtable dir exists (not a symlink), skipping"
            return
        fi
        ln -s "$SKILL_DIR" "$harness_dir/roundtable"
        info "$harness_name: skill linked"
    else
        warn "$harness_name: not installed, skipping"
    fi
}

link_skill "$HOME/.claude/skills" "Claude Code"
link_skill "$HOME/.codex/skills" "Codex"
link_skill "$HOME/.agents/skills" "Codex (agents dir)"
link_skill "$HOME/.hermes/skills" "Hermes"

# --- PATH setup ---
echo ""
echo -e "${BOLD}PATH setup${RESET}"
SHELL_NAME="$(basename "$SHELL")"

case "$SHELL_NAME" in
    fish)
        RC_FILE="$HOME/.config/fish/config.fish"
        PATH_LINE="set -gx PATH $INSTALL_DIR/bin \$PATH"
        ;;
    zsh)
        RC_FILE="$HOME/.zshrc"
        PATH_LINE="export PATH=\"$INSTALL_DIR/bin:\$PATH\""
        ;;
    bash)
        RC_FILE="$HOME/.bashrc"
        PATH_LINE="export PATH=\"$INSTALL_DIR/bin:\$PATH\""
        ;;
    *)
        RC_FILE="$HOME/.profile"
        PATH_LINE="export PATH=\"$INSTALL_DIR/bin:\$PATH\""
        ;;
esac

if grep -qF "$INSTALL_DIR/bin" "$RC_FILE" 2>/dev/null; then
    info "PATH already configured in $RC_FILE"
else
    echo "" >> "$RC_FILE"
    echo "# h2o tools" >> "$RC_FILE"
    printf '%s\n' "$PATH_LINE" >> "$RC_FILE"
    info "PATH added to $RC_FILE"
    warn "run 'source $RC_FILE' or start a new shell"
fi

# --- install cmux hooks ---
echo ""
echo -e "${BOLD}cmux agent hooks${RESET}"
if cmux hooks setup --yes 2>/dev/null; then
    info "cmux hooks installed"
else
    warn "cmux hooks setup failed (you can run 'cmux hooks setup' manually later)"
fi

# --- done ---
echo ""
echo -e "${GREEN}${BOLD}✓ Installation complete!${RESET}"
echo ""
echo "Quick start:"
echo "  1. Create a project:  roundtable-init my-project"
echo "  2. cd my-project"
echo "  3. Bind workspace:    rt-refresh --bind-current"
echo "  4. Start watcher:     rt-watch-ensure"
echo "  5. Check agents:      rt-resolve claude"
echo ""
echo "Docs: $INSTALL_DIR/docs/"
echo "Skill: $SKILL_DIR/SKILL.md"
