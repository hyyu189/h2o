#!/bin/bash
#
# h2o — uninstall script
#
# Removes only files installed by install.sh, using a manifest.
# Does NOT remove ~/.roundtable/ wholesale — only tracked subpaths.
#
set -euo pipefail

INSTALL_DIR="${ROUNDTABLE_INSTALL_DIR:-$HOME/.roundtable}"
SKILL_DIR="${ROUNDTABLE_SKILL_DIR:-$HOME/.skills/shared/roundtable}"

BOLD="\033[1m"
GREEN="\033[32m"
YELLOW="\033[33m"
RESET="\033[0m"

info()  { echo -e "${GREEN}✓${RESET} $1"; }
warn()  { echo -e "${YELLOW}⚠${RESET} $1"; }

echo -e "${BOLD}h2o uninstaller${RESET}"
echo ""

# Files installed by install.sh (deterministic list)
BIN_FILES="_rtlib.py rt-say rt-ack rt-resolve rt-refresh rt-watch rt-watch-ensure rt-inbox roundtable-init"
TEMPLATE_FILES="AGENTS.md.tmpl agents.yaml.tmpl BRIEF.md.tmpl CLAUDE.md.tmpl decision.md.tmpl HERMES.md.tmpl PROTOCOL.md.tmpl README.md.tmpl root-gitignore.tmpl roundtable-gitignore.tmpl"
DOC_FILES="cmux-events.md"
DOC_WORKFLOW_FILES="freeze-workflow.md goal-dispatch.md"

# Remove harness symlinks
echo "Removing harness symlinks..."
for dir in "$HOME/.claude/skills" "$HOME/.codex/skills" "$HOME/.agents/skills" "$HOME/.hermes/skills"; do
    if [ -L "$dir/roundtable" ]; then
        rm "$dir/roundtable"
        info "removed symlink: $dir/roundtable"
    fi
done

# Remove skill (only the SKILL.md we placed)
echo ""
echo "Removing skill..."
if [ -f "$SKILL_DIR/SKILL.md" ]; then
    rm "$SKILL_DIR/SKILL.md"
    info "removed: $SKILL_DIR/SKILL.md"
    # Remove skill dir only if empty
    rmdir "$SKILL_DIR" 2>/dev/null && info "removed empty: $SKILL_DIR" || true
fi

# Remove bin files individually
echo ""
echo "Removing tools..."
for f in $BIN_FILES; do
    target="$INSTALL_DIR/bin/$f"
    if [ -f "$target" ]; then
        rm "$target"
        info "removed: bin/$f"
    fi
done
# Remove bin dir only if empty
rmdir "$INSTALL_DIR/bin" 2>/dev/null && info "removed empty: bin/" || true

# Remove template files individually
echo ""
echo "Removing templates..."
for f in $TEMPLATE_FILES; do
    target="$INSTALL_DIR/templates/$f"
    if [ -f "$target" ]; then
        rm "$target"
        info "removed: templates/$f"
    fi
done
rmdir "$INSTALL_DIR/templates" 2>/dev/null && info "removed empty: templates/" || true

# Remove doc files individually
echo ""
echo "Removing docs..."
for f in $DOC_FILES; do
    target="$INSTALL_DIR/docs/$f"
    if [ -f "$target" ]; then
        rm "$target"
        info "removed: docs/$f"
    fi
done
for f in $DOC_WORKFLOW_FILES; do
    target="$INSTALL_DIR/docs/workflows/$f"
    if [ -f "$target" ]; then
        rm "$target"
        info "removed: docs/workflows/$f"
    fi
done
rmdir "$INSTALL_DIR/docs/workflows" 2>/dev/null && true
rmdir "$INSTALL_DIR/docs" 2>/dev/null && info "removed empty: docs/" || true

# Note: we don't remove $INSTALL_DIR itself (may have other files)
# Note: existing projects' .roundtable/ dirs are untouched
# Note: cmux hooks still installed — run 'cmux hooks uninstall' manually

echo ""
echo -e "${GREEN}${BOLD}✓ Uninstalled.${RESET}"
echo ""
echo "Note: existing projects' .roundtable/ dirs are untouched."
echo "Note: cmux hooks still installed — run 'cmux hooks uninstall' to remove them."
echo ""
echo "To remove PATH entry, edit your shell rc file and delete the '# h2o tools' block."
