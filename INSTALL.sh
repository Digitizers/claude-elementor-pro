#!/usr/bin/env bash
# =============================================================================
# Claude + Elementor Kit — Installer (Mac / Linux)
#
# Copies the skill and setup script into your ~/.claude/ folder so Claude Code
# can find them automatically. Safe to re-run.
# =============================================================================

set -euo pipefail

BOLD=$'\033[1m'; GREEN=$'\033[32m'; CYAN=$'\033[36m'; YELLOW=$'\033[33m'
RED=$'\033[31m'; DIM=$'\033[2m'; RESET=$'\033[0m'

ok()   { printf "  ${GREEN}✓${RESET} %s\n" "$*"; }
warn() { printf "  ${YELLOW}⚠${RESET} %s\n" "$*"; }
fail() { printf "  ${RED}✗${RESET} %s\n" "$*"; }
step() { printf "\n${BOLD}${CYAN}▸ %s${RESET}\n" "$*"; }

# Find where this installer lives — files/ should be next to it
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_FILES="$HERE/files"

[ -d "$SRC_FILES" ] || { fail "Cannot find $SRC_FILES — run this script from the kit folder."; exit 1; }
[ -f "$SRC_FILES/SKILL.md" ] || { fail "Missing SKILL.md in files/."; exit 1; }
[ -f "$SRC_FILES/setup-elementor-mcp.sh" ] || { fail "Missing setup-elementor-mcp.sh in files/."; exit 1; }

cat <<'BANNER'

  ╭───────────────────────────────────────────────╮
  │   Claude + Elementor Kit — Installer          │
  │   ───────────────────────────────             │
  │   Installs the skill + setup script into      │
  │   ~/.claude/ so Claude Code can find them.    │
  ╰───────────────────────────────────────────────╯

BANNER

step "Creating destination folders"
SKILL_DIR="$HOME/.claude/skills/siteagent-elementor-studio"
SCRIPT_DIR="$HOME/.claude/scripts"
mkdir -p "$SKILL_DIR"
mkdir -p "$SCRIPT_DIR"
ok "$SKILL_DIR"
ok "$SCRIPT_DIR"

# The skill was previously installed as "elementor-mcp" — migrate/remove that
# old directory so Claude doesn't end up loading both.
OLD_SKILL_DIR="$HOME/.claude/skills/elementor-mcp"
if [ -d "$OLD_SKILL_DIR" ]; then
  warn "Found a previous install at $OLD_SKILL_DIR (this kit's old skill name)."
  printf "    Remove it now that the skill installs as siteagent-elementor-studio? [y/N] "
  read -r ans
  if [[ "$ans" =~ ^[Yy]$ ]]; then
    rm -rf "$OLD_SKILL_DIR"
    ok "Removed old $OLD_SKILL_DIR"
  else
    warn "Leaving $OLD_SKILL_DIR in place — remove it manually to avoid Claude loading both the old and new skill."
  fi
fi

step "Copying files"

# Skill
if [ -f "$SKILL_DIR/SKILL.md" ]; then
  warn "SKILL.md already exists at $SKILL_DIR/"
  printf "    Overwrite? [y/N] "
  read -r ans
  if [[ "$ans" =~ ^[Yy]$ ]]; then
    cp "$SRC_FILES/SKILL.md" "$SKILL_DIR/SKILL.md"
    ok "Overwrote SKILL.md"
  else
    warn "Skipped SKILL.md"
  fi
else
  cp "$SRC_FILES/SKILL.md" "$SKILL_DIR/SKILL.md"
  ok "Installed SKILL.md"
fi

# Install the reference docs (progressive disclosure — SKILL.md points to these)
if [ -d "$SRC_FILES/references" ]; then
  mkdir -p "$SKILL_DIR/references"
  cp -R "$SRC_FILES/references/." "$SKILL_DIR/references/"
  ok "Installed references/ ($(find "$SRC_FILES/references" -name '*.md' | wc -l | tr -d ' ') docs)"
fi

# Script
if [ -f "$SCRIPT_DIR/setup-elementor-mcp.sh" ]; then
  warn "setup-elementor-mcp.sh already exists at $SCRIPT_DIR/"
  printf "    Overwrite? [y/N] "
  read -r ans
  if [[ "$ans" =~ ^[Yy]$ ]]; then
    cp "$SRC_FILES/setup-elementor-mcp.sh" "$SCRIPT_DIR/setup-elementor-mcp.sh"
    chmod +x "$SCRIPT_DIR/setup-elementor-mcp.sh"
    ok "Overwrote setup-elementor-mcp.sh"
  else
    warn "Skipped setup-elementor-mcp.sh"
  fi
else
  cp "$SRC_FILES/setup-elementor-mcp.sh" "$SCRIPT_DIR/setup-elementor-mcp.sh"
  chmod +x "$SCRIPT_DIR/setup-elementor-mcp.sh"
  ok "Installed setup-elementor-mcp.sh (executable)"
fi

cat <<EOF

  ${BOLD}${GREEN}✓ Install complete${RESET}

  ${BOLD}Files installed at:${RESET}
    ${DIM}~/.claude/skills/siteagent-elementor-studio/SKILL.md${RESET}
    ${DIM}~/.claude/scripts/setup-elementor-mcp.sh${RESET}

  ${BOLD}Next steps:${RESET}

    1. Open Terminal in your project folder.

    2. Run the setup wizard:
       ${CYAN}bash ~/.claude/scripts/setup-elementor-mcp.sh${RESET}

       It will ask you 4 questions and wire Claude Code
       to your WordPress site (~3 minutes).

    3. Quit and reopen Claude Code in that folder.

    4. Tell Claude: "use the elementor MCP to build my homepage"

  ${BOLD}Read the docs:${RESET}
    docs/QUICKSTART.md   — short guide
    docs/LESSONS.md      — deep dive

EOF
