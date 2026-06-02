#!/usr/bin/env bash
# =============================================================================
# new-client.sh — Non-interactive client onboarding for the Elementor MCP kit.
#
# One command to wire Claude Code to a (new) WordPress + Elementor site:
#   1. Resolve the site (Local-by-Flywheel via sites.json, or a live URL)
#   2. Verify connectivity + REST auth
#   3. Detect Elementor + Elementor Pro (report which tools will be available)
#   4. Install the MCP Adapter + elementor-mcp plugins
#        - Local: via Local's bundled WP-CLI (auto-finds the per-site socket)
#        - Live:  prints the two zip paths for manual upload
#   5. Verify the /mcp/elementor-mcp-server route
#   6. Write .mcp.json into the project directory
#   7. (optional) install the wordpress-api-pro companion skill into ~/.claude
#
# Unlike setup-elementor-mcp.sh (the interactive wizard), this is flag-driven
# and headless — built for spinning up many client sites quickly. Idempotent.
#
# Usage:
#   bash new-client.sh --local "<SiteName>"  --user <wp_user> --app-pass "<app password>" [opts]
#   bash new-client.sh --live  "<https://url>" --user <wp_user> --app-pass "<app password>" [opts]
#
# Options:
#   --project-dir <path>   Where to write .mcp.json (default: Local site root, else cwd)
#   --name <id>            MCP server name in .mcp.json (default: elementor)
#   --with-api-pro [path]  Also install the wordpress-api-pro skill. Optional path
#                          to the repo (default: sibling ../wordpress-api-pro)
#   --dry-run              Report only — no installs, no file writes
#   -h | --help
# =============================================================================

set -uo pipefail

BOLD=$'\033[1m'; DIM=$'\033[2m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'
RED=$'\033[31m'; CYAN=$'\033[36m'; RESET=$'\033[0m'
step(){ printf "\n${BOLD}${CYAN}▸ %s${RESET}\n" "$*"; }
ok(){   printf "  ${GREEN}✓${RESET} %s\n" "$*"; }
warn(){ printf "  ${YELLOW}⚠${RESET} %s\n" "$*"; }
fail(){ printf "  ${RED}✗${RESET} %s\n" "$*"; }
info(){ printf "  ${DIM}%s${RESET}\n" "$*"; }
abort(){ fail "$1"; exit 1; }

need(){ command -v "$1" >/dev/null 2>&1 || abort "Missing required command: $1"; }
need python3   # parsers need python3; curl is checked once we start real work

# ---- pure parsers (stdin/arg based; unit-tested via --self-test-fn) ----------
# Kept inline (not a shared lib) so this script stays a single droppable file.
# NB: these intentionally duplicate a base64 helper that also exists in
# setup-elementor-mcp.sh — accepted duplication, do not factor into a lib.

# stdin: /wp-json/wp/v2/users/me JSON -> the numeric id (empty on bad auth/garbage)
parse_user_id(){ python3 -c 'import sys,json
try: print(json.load(sys.stdin).get("id",""))
except Exception: print("")' 2>/dev/null; }

# stdin: /wp-json/wp/v2/plugins JSON ; arg1: slug -> "yes"|"no" (graceful "no" on garbage)
plugin_active(){ python3 -c 'import sys,json
slug=sys.argv[1]
try: d=json.load(sys.stdin)
except Exception: d=[]
print("yes" if isinstance(d,list) and any(p.get("plugin","").startswith(slug+"/") and p.get("status")=="active" for p in d) else "no")' "$1" 2>/dev/null; }

# stdin: GitHub releases/latest JSON -> first .zip asset url, else zipball_url, else ""
release_zip_url(){ python3 -c 'import sys,json
try: d=json.load(sys.stdin)
except Exception: d={}
a=[x for x in d.get("assets",[]) if str(x.get("name","")).endswith(".zip")]
print(a[0]["browser_download_url"] if a else d.get("zipball_url",""))' 2>/dev/null; }

# arg1: user ; arg2: app password -> base64("user:pass") with no trailing newline
b64_auth(){ printf '%s:%s' "$1" "$2" | python3 -c 'import sys,base64;sys.stdout.write(base64.b64encode(sys.stdin.buffer.read()).decode())'; }

# arg1: sites.json path ; arg2: site name -> "<path>\t<domain>" (empty if not found)
resolve_local_site(){ python3 - "$1" "$2" <<'PY' 2>/dev/null
import json,sys
try: d=json.load(open(sys.argv[1]))
except Exception: sys.exit(0)
name=sys.argv[2]
for v in (d.values() if isinstance(d,dict) else d):
    if isinstance(v,dict) and v.get("name")==name:
        print("\t".join([v.get("path",""), v.get("domain","")])); break
PY
}

# Hidden test hook: `new-client.sh --self-test-fn <fn> [args...]` runs one
# function (reading stdin) and exits. Never touches the network.
if [ "${1:-}" = "--self-test-fn" ]; then shift; fn="$1"; shift || true; "$fn" "$@"; exit $?; fi

# ---- args -------------------------------------------------------------------
MODE=""; SITE_REF=""; WP_USER=""; WP_APP_PWD=""
PROJECT_DIR=""; MCP_NAME="elementor"; WITH_API_PRO=""; API_PRO_PATH=""; DRY_RUN=""
while [ $# -gt 0 ]; do
  case "$1" in
    --local)       MODE="local"; SITE_REF="${2:-}"; shift 2 ;;
    --live)        MODE="live";  SITE_REF="${2:-}"; shift 2 ;;
    --user)        WP_USER="${2:-}"; shift 2 ;;
    --app-pass)    WP_APP_PWD="${2:-}"; shift 2 ;;
    --project-dir) PROJECT_DIR="${2:-}"; shift 2 ;;
    --name)        MCP_NAME="${2:-}"; shift 2 ;;
    --with-api-pro)
      WITH_API_PRO="yes"
      case "${2:-}" in ""|--*) shift 1 ;; *) API_PRO_PATH="$2"; shift 2 ;; esac ;;
    --dry-run)     DRY_RUN="yes"; shift 1 ;;
    -h|--help)     sed -n '2,40p' "$0"; exit 0 ;;
    *) abort "Unknown arg: $1 (try --help)" ;;
  esac
done

[ -n "$MODE" ]       || abort "Pass --local <SiteName> or --live <url>"
[ -n "$SITE_REF" ]   || abort "Missing site reference after --$MODE"
[ -n "$WP_USER" ]    || abort "Missing --user"
[ -n "$WP_APP_PWD" ] || abort "Missing --app-pass"

need curl   # real work starts here; parsers above already validated python3

# ---- 1. resolve site --------------------------------------------------------
step "1/7  Resolve site ($MODE)"
SITE_PATH=""; SITE_URL=""
if [ "$MODE" = "local" ]; then
  SITES_JSON="$HOME/Library/Application Support/Local/sites.json"
  RESOLVED=$(resolve_local_site "$SITES_JSON" "$SITE_REF")
  if [ -n "$RESOLVED" ]; then
    SITE_PATH="$(printf '%s' "$RESOLVED" | cut -f1)/app/public"
    SITE_URL="http://$(printf '%s' "$RESOLVED" | cut -f2)"
  else
    SITE_PATH="$HOME/Local Sites/$SITE_REF/app/public"
    SITE_URL="http://${SITE_REF}.local"
    warn "Site '$SITE_REF' not in sites.json — falling back to legacy path."
  fi
  [ -f "$SITE_PATH/wp-config.php" ] || abort "No wp-config.php at $SITE_PATH (site name correct? started in Local?)"
  ok "Path: $SITE_PATH"
else
  SITE_URL="${SITE_REF%/}"
  [[ "$SITE_URL" =~ ^https?:// ]] || abort "Live URL must start with http(s)://"
fi
ok "URL:  $SITE_URL"

# ---- 2. connectivity + auth -------------------------------------------------
step "2/7  Connectivity + auth"
CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$SITE_URL/wp-json/" || echo 000)
case "$CODE" in 200|301|302) ok "REST reachable ($CODE)";; 000) abort "Cannot reach $SITE_URL — is the site running?";; *) warn "REST returned $CODE — continuing";; esac

# NB: do NOT name this UID — that's a readonly shell builtin (the OS user id).
ME=$(curl -s -u "$WP_USER:$WP_APP_PWD" --max-time 10 "$SITE_URL/wp-json/wp/v2/users/me" || echo '{}')
WP_UID=$(printf '%s' "$ME" | parse_user_id)
[ -n "$WP_UID" ] || abort "Auth failed for user '$WP_USER'. Check the application password / username slug."
ok "Authenticated (WP user id $WP_UID)"

# ---- 3. detect Elementor + Pro ---------------------------------------------
step "3/7  Detect Elementor / Pro"
PLUGINS=$(curl -s -u "$WP_USER:$WP_APP_PWD" --max-time 10 "$SITE_URL/wp-json/wp/v2/plugins" || echo '[]')
HAS_EL=$(printf '%s' "$PLUGINS" | plugin_active elementor)
HAS_PRO=$(printf '%s' "$PLUGINS" | plugin_active elementor-pro)
[ "$HAS_EL" = "yes" ] && ok "Elementor — active" || warn "Elementor — NOT active (install it before building)"
if [ "$HAS_PRO" = "yes" ]; then
  ok "Elementor Pro — active (native Form / Theme Builder / Loop Grid / Popups available)"
else
  info "Elementor Pro — not active (free tier; UAE + Fluent Forms workarounds apply)"
fi

# ---- 4/5. install MCP plugins + verify route -------------------------------
PROJECT_DIR="${PROJECT_DIR:-}"
if [ -z "$PROJECT_DIR" ]; then
  if [ "$MODE" = "local" ]; then PROJECT_DIR="$(dirname "$(dirname "$SITE_PATH")")"; else PROJECT_DIR="$(pwd)"; fi
fi

has_route(){ curl -s -u "$WP_USER:$WP_APP_PWD" --max-time 10 "$SITE_URL/wp-json/" 2>/dev/null | grep -q "elementor-mcp-server"; }

step "4/7  MCP plugins"
if has_route; then
  ok "MCP route already registered — skipping install."
elif [ -n "$DRY_RUN" ]; then
  info "[dry-run] would download + install mcp-adapter + elementor-mcp"
else
  need unzip; need zip
  WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT
  dl(){ curl -s "https://api.github.com/repos/$1/releases/latest" | release_zip_url; }
  info "Downloading mcp-adapter + elementor-mcp..."
  curl -sL -o "$WORK/mcp-adapter.zip" "$(dl WordPress/mcp-adapter)" || abort "adapter download failed"
  curl -sL -o "$WORK/em-src.zip" "$(dl msrbuilds/elementor-mcp)" || abort "elementor-mcp download failed"
  ( cd "$WORK" && unzip -q em-src.zip )
  EM_DIR=$(find "$WORK" -maxdepth 1 -type d -name "*elementor-mcp*" | head -1)
  if [ -n "$EM_DIR" ] && [ "$(basename "$EM_DIR")" != "elementor-mcp" ]; then mv "$EM_DIR" "$WORK/elementor-mcp"; fi
  if [ -d "$WORK/elementor-mcp" ]; then ( cd "$WORK" && zip -qr elementor-mcp.zip elementor-mcp ); EM_ZIP="$WORK/elementor-mcp.zip"; else EM_ZIP="$WORK/em-src.zip"; fi

  if [ "$MODE" = "local" ]; then
    LOCAL_PHP=$(find "$HOME/Library/Application Support/Local/lightning-services" -maxdepth 6 -name php -type f 2>/dev/null | head -1)
    LOCAL_WP="/Applications/Local.app/Contents/Resources/extraResources/bin/wp-cli/posix/wp"
    [ -x "$LOCAL_PHP" ] && [ -f "$LOCAL_WP" ] || abort "Local PHP/WP-CLI binaries not found — is Local installed?"
    SOCK=""
    while IFS= read -r -d '' s; do
      if "$LOCAL_PHP" -d "mysqli.default_socket=$s" -d "pdo_mysql.default_socket=$s" "$LOCAL_WP" --path="$SITE_PATH" --skip-plugins --skip-themes core version >/dev/null 2>&1; then SOCK="$s"; break; fi
    done < <(find "$HOME/Library/Application Support/Local/run" -name mysqld.sock -print0 2>/dev/null)
    [ -n "$SOCK" ] || abort "No live MySQL socket for this site — start it in Local."
    WP(){ "$LOCAL_PHP" -d "mysqli.default_socket=$SOCK" -d "pdo_mysql.default_socket=$SOCK" "$LOCAL_WP" --path="$SITE_PATH" "$@"; }
    WP --skip-plugins --skip-themes plugin install "$WORK/mcp-adapter.zip" --activate --force >/dev/null 2>&1 && ok "mcp-adapter installed" || fail "mcp-adapter install failed"
    WP --skip-plugins --skip-themes plugin install "$EM_ZIP" --activate --force >/dev/null 2>&1 && ok "elementor-mcp installed" || fail "elementor-mcp install failed"
  else
    warn "Live host: REST can't install arbitrary zips. Upload these manually then re-run:"
    info "  $WORK/mcp-adapter.zip"; info "  $EM_ZIP"
    info "  via ${SITE_URL}/wp-admin/plugin-install.php?tab=upload"
    abort "Stopping — install the two plugins, then re-run new-client.sh."
  fi
fi

step "5/7  Verify route"
sleep 2
if has_route; then ok "/wp-json/mcp/elementor-mcp-server registered"
elif [ -n "$DRY_RUN" ]; then info "[dry-run] skipped"
else warn "Route not visible yet — check both MCP plugins are active in WP Admin."; fi

# ---- 6. write .mcp.json -----------------------------------------------------
step "6/7  .mcp.json → $PROJECT_DIR"
AUTH_B64=$(b64_auth "$WP_USER" "$WP_APP_PWD")
read -r -d '' CONFIG <<JSON
{
  "mcpServers": {
    "${MCP_NAME}": {
      "type": "http",
      "url": "${SITE_URL}/wp-json/mcp/elementor-mcp-server",
      "headers": { "Authorization": "Basic ${AUTH_B64}" }
    }
  }
}
JSON
if [ -n "$DRY_RUN" ]; then
  info "[dry-run] would write:"; printf '%s\n' "$CONFIG" | sed 's/^/      /'
else
  [ -d "$PROJECT_DIR" ] || mkdir -p "$PROJECT_DIR"
  if [ -f "$PROJECT_DIR/.mcp.json" ]; then warn ".mcp.json exists — backing up to .mcp.json.bak"; cp "$PROJECT_DIR/.mcp.json" "$PROJECT_DIR/.mcp.json.bak"; fi
  printf '%s\n' "$CONFIG" > "$PROJECT_DIR/.mcp.json"
  ok "Wrote $PROJECT_DIR/.mcp.json"
fi

# ---- 7. optional: wordpress-api-pro companion ------------------------------
step "7/7  Companion: wordpress-api-pro"
if [ "$WITH_API_PRO" = "yes" ]; then
  HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  CANDIDATE="${API_PRO_PATH:-$(dirname "$HERE")/wordpress-api-pro}"
  if [ -f "$CANDIDATE/INSTALL.sh" ]; then
    if [ -n "$DRY_RUN" ]; then info "[dry-run] would run $CANDIDATE/INSTALL.sh"
    else printf 'y\n' | bash "$CANDIDATE/INSTALL.sh" >/dev/null 2>&1 && ok "Installed wordpress-api-pro skill into ~/.claude/skills/" || warn "api-pro install failed — run $CANDIDATE/INSTALL.sh manually"; fi
  else
    warn "wordpress-api-pro not found at $CANDIDATE"
    info "Clone it and run INSTALL.sh: https://github.com/Digitizers/wordpress-api-pro"
  fi
else
  info "Skipped (pass --with-api-pro to install the content/SEO/media companion)."
fi

# ---- done -------------------------------------------------------------------
printf "\n${BOLD}${GREEN}✓ Client ready${RESET}\n"
[ "$HAS_PRO" = "yes" ] && printf "  ${DIM}Elementor Pro detected — native Form / Theme Builder / Loop Grid / Popups.${RESET}\n"
printf "  ${BOLD}Next:${RESET} open Claude Code in ${CYAN}%s${RESET}, approve the '%s' MCP, then build.\n" "$PROJECT_DIR" "$MCP_NAME"
