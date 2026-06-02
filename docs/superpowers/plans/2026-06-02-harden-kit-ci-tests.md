# Harden the Kit for Scale — CI + Tests Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a CI workflow + a bats test harness that catch the two scale-killers (silent parse-failure bugs, edge-input crashes) without changing how the kit is used.

**Architecture:** Extract `new-client.sh`'s inline parsers into pure, stdin/arg-based functions reachable via a hidden `--self-test-fn` dispatch (keeps the script a single standalone droppable file — no shared lib, no full `main()` rewrite). Add `tests/` (bats + JSON fixtures) and `.github/workflows/ci.yml` (shellcheck + `bash -n` + frontmatter lint + dry-run smoke + bats).

**Tech Stack:** bash, bats-core, shellcheck, GitHub Actions, python3 (already a script dependency).

---

## File Structure

- **Create** `.github/workflows/ci.yml` — CI: shellcheck, `bash -n`, frontmatter lint, dry-run smoke, bats.
- **Modify** `new-client.sh` — hoist 5 pure parser functions to the top, add `--self-test-fn` dispatch, repoint call sites. No behavior change when run normally.
- **Modify** `files/setup-elementor-mcp.sh` — add a Linux Local-by-Flywheel path candidate.
- **Create** `tests/run.sh` — bats bootstrap + runner.
- **Create** `tests/parsers.bats` — unit tests for the hoisted parsers + the readonly-name regression guard.
- **Create** `tests/fixtures/{plugins.json,plugins-malformed.json,users-me.json,release.json,release-no-asset.json}` — sample inputs.

Reconciliation with the spec: the spec mentions "lenient JSON parse … still extracts" against a malformed fixture. That lenient-extract behavior lives in `setup-elementor-mcp.sh`'s `jq_lenient`, not in `new-client.sh` (which uses strict `json.load`). Testing `jq_lenient` would require sourcing the interactive wizard. So this plan scopes `new-client.sh` malformed tests to **graceful degradation** (no crash → empty/"no"), and defers true lenient-extract unit tests to a follow-up (noted at the end).

---

## Task 1: Hoist `new-client.sh` parsers + add self-test dispatch

Extract the inline one-liner parsers into named, side-effect-free functions placed near the top, add a `--self-test-fn` dispatch so tests can invoke a single function and exit, and repoint the existing call sites. The procedural flow stays byte-for-byte equivalent in behavior.

**Files:**
- Modify: `new-client.sh`

- [ ] **Step 1: Add the pure-functions block + dispatch**

In `new-client.sh`, immediately after the `need curl; need python3` line (currently line 44), the script jumps straight into `# ---- args ----`. Insert a new block between them. Replace:

```bash
need(){ command -v "$1" >/dev/null 2>&1 || abort "Missing required command: $1"; }
need curl; need python3

# ---- args -------------------------------------------------------------------
```

with:

```bash
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
```

- [ ] **Step 2: Repoint the WP user-id call site**

Replace (currently lines 108–112):

```bash
ME=$(curl -s -u "$WP_USER:$WP_APP_PWD" --max-time 10 "$SITE_URL/wp-json/wp/v2/users/me" || echo '{}')
WP_UID=$(printf '%s' "$ME" | python3 -c 'import sys,json
try: print(json.load(sys.stdin).get("id",""))
except Exception: print("")' 2>/dev/null)
[ -n "$WP_UID" ] || abort "Auth failed for user '$WP_USER'. Check the application password / username slug."
```

with:

```bash
ME=$(curl -s -u "$WP_USER:$WP_APP_PWD" --max-time 10 "$SITE_URL/wp-json/wp/v2/users/me" || echo '{}')
WP_UID=$(printf '%s' "$ME" | parse_user_id)
[ -n "$WP_UID" ] || abort "Auth failed for user '$WP_USER'. Check the application password / username slug."
```

- [ ] **Step 3: Repoint the plugin-detect call site**

Replace (currently lines 117–123):

```bash
PLUGINS=$(curl -s -u "$WP_USER:$WP_APP_PWD" --max-time 10 "$SITE_URL/wp-json/wp/v2/plugins" || echo '[]')
detect(){ printf '%s' "$PLUGINS" | python3 -c 'import sys,json
slug=sys.argv[1]
try: d=json.load(sys.stdin)
except Exception: d=[]
print("yes" if isinstance(d,list) and any(p.get("plugin","").startswith(slug+"/") and p.get("status")=="active" for p in d) else "no")' "$1" 2>/dev/null; }
HAS_EL=$(detect elementor); HAS_PRO=$(detect elementor-pro)
```

with:

```bash
PLUGINS=$(curl -s -u "$WP_USER:$WP_APP_PWD" --max-time 10 "$SITE_URL/wp-json/wp/v2/plugins" || echo '[]')
HAS_EL=$(printf '%s' "$PLUGINS" | plugin_active elementor)
HAS_PRO=$(printf '%s' "$PLUGINS" | plugin_active elementor-pro)
```

- [ ] **Step 4: Repoint the release-url call site**

Replace (currently line 147):

```bash
  dl(){ curl -s "https://api.github.com/repos/$1/releases/latest" | python3 -c 'import sys,json;d=json.load(sys.stdin);a=[x for x in d.get("assets",[]) if x["name"].endswith(".zip")];print(a[0]["browser_download_url"] if a else d.get("zipball_url",""))'; }
```

with:

```bash
  dl(){ curl -s "https://api.github.com/repos/$1/releases/latest" | release_zip_url; }
```

- [ ] **Step 5: Repoint the base64 call site**

Replace (currently line 184):

```bash
AUTH_B64=$(printf '%s:%s' "$WP_USER" "$WP_APP_PWD" | python3 -c 'import sys,base64;sys.stdout.write(base64.b64encode(sys.stdin.buffer.read()).decode())')
```

with:

```bash
AUTH_B64=$(b64_auth "$WP_USER" "$WP_APP_PWD")
```

- [ ] **Step 6: Repoint the resolve-local-site call site**

Replace (currently lines 76–85):

```bash
  RESOLVED=$(python3 - "$SITES_JSON" "$SITE_REF" <<'PY' 2>/dev/null
import json,sys
try: d=json.load(open(sys.argv[1]))
except Exception: sys.exit(0)
name=sys.argv[2]
for v in (d.values() if isinstance(d,dict) else d):
    if isinstance(v,dict) and v.get("name")==name:
        print("\t".join([v.get("path",""), v.get("domain","")])); break
PY
)
```

with:

```bash
  RESOLVED=$(resolve_local_site "$SITES_JSON" "$SITE_REF")
```

- [ ] **Step 7: Verify no behavior change (syntax + dry-run smoke)**

Run:
```bash
bash -n new-client.sh
bash new-client.sh --dry-run --local "NoSuchSite__xyz" --user u --app-pass p; echo "exit=$?"
```
Expected: `bash -n` prints nothing (exit 0). The dry-run aborts at site resolution (`No wp-config.php …`, exit 1) **without any network call** — that's the existing behavior for a nonexistent site and is the correct smoke target. Confirm it printed the resolve step and aborted cleanly (no python traceback, no curl hang).

- [ ] **Step 8: Verify the self-test hook works**

Run:
```bash
echo '{"id":42}' | bash new-client.sh --self-test-fn parse_user_id
printf '[{"plugin":"elementor/elementor.php","status":"active"}]' | bash new-client.sh --self-test-fn plugin_active elementor
bash new-client.sh --self-test-fn b64_auth Digitizer secret | python3 -c 'import sys,base64;print(base64.b64decode(sys.stdin.read()).decode())'
```
Expected: `42`, then `yes`, then `Digitizer:secret`.

- [ ] **Step 9: Commit**

```bash
git add new-client.sh
git commit -m "refactor(new-client): hoist pure parsers + add --self-test-fn hook

Extracts the inline JSON parsers (user id, plugin-active, release url,
base64 auth, local-site resolve) into named stdin/arg-based functions and
adds a hidden --self-test-fn dispatch so they can be unit-tested without
sourcing or network. No behavior change to the normal run path.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 2: Test fixtures

Create the JSON inputs the bats tests feed to the parsers.

**Files:**
- Create: `tests/fixtures/plugins.json`
- Create: `tests/fixtures/plugins-malformed.json`
- Create: `tests/fixtures/users-me.json`
- Create: `tests/fixtures/release.json`
- Create: `tests/fixtures/release-no-asset.json`

- [ ] **Step 1: Create `tests/fixtures/plugins.json`**

```json
[
  { "plugin": "elementor/elementor.php", "status": "active" },
  { "plugin": "elementor-pro/elementor-pro.php", "status": "inactive" },
  { "plugin": "hello-elementor/hello-elementor.php", "status": "active" }
]
```

- [ ] **Step 2: Create `tests/fixtures/plugins-malformed.json`**

(Leading garbage before the JSON — the hardened-host case. Strict parsers must degrade to "no", not crash.)

```
<!-- WP warning -->
[ { "plugin": "elementor/elementor.php", "status": "active" } ]
```

- [ ] **Step 3: Create `tests/fixtures/users-me.json`**

```json
{ "id": 7, "name": "Digitizer", "slug": "digitizer" }
```

- [ ] **Step 4: Create `tests/fixtures/release.json`**

```json
{
  "zipball_url": "https://api.github.com/repos/acme/widget/zipball/v1",
  "assets": [
    { "name": "widget-dev.txt", "browser_download_url": "https://example.com/dev.txt" },
    { "name": "widget.zip", "browser_download_url": "https://example.com/widget.zip" }
  ]
}
```

- [ ] **Step 5: Create `tests/fixtures/release-no-asset.json`**

```json
{ "zipball_url": "https://api.github.com/repos/acme/widget/zipball/v1", "assets": [] }
```

- [ ] **Step 6: Commit**

```bash
git add tests/fixtures
git commit -m "test(fixtures): sample WP/plugins/release JSON for parser tests

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 3: bats parser tests + the readonly-name regression guard

Write the tests that lock in parser behavior and prevent the `WP_UID`-class regression (assigning to a readonly shell builtin name, which silently no-ops under `set +e`).

**Files:**
- Create: `tests/parsers.bats`

- [ ] **Step 1: Write the failing tests**

Create `tests/parsers.bats`:

```bash
#!/usr/bin/env bats
# Unit tests for new-client.sh pure parsers, invoked via its --self-test-fn hook.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  SCRIPT="$REPO_ROOT/new-client.sh"
  FIX="$BATS_TEST_DIRNAME/fixtures"
}

# ---- parse_user_id ----
@test "parse_user_id extracts id from users/me" {
  run bash -c "'$SCRIPT' --self-test-fn parse_user_id < '$FIX/users-me.json'"
  [ "$status" -eq 0 ]
  [ "$output" = "7" ]
}

@test "parse_user_id returns empty on bad-auth payload {}" {
  run bash -c "printf '{}' | '$SCRIPT' --self-test-fn parse_user_id"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "parse_user_id degrades to empty on garbage (no crash)" {
  run bash -c "printf 'not json' | '$SCRIPT' --self-test-fn parse_user_id"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# ---- plugin_active ----
@test "plugin_active yes for active elementor" {
  run bash -c "'$SCRIPT' --self-test-fn plugin_active elementor < '$FIX/plugins.json'"
  [ "$output" = "yes" ]
}

@test "plugin_active no for inactive elementor-pro" {
  run bash -c "'$SCRIPT' --self-test-fn plugin_active elementor-pro < '$FIX/plugins.json'"
  [ "$output" = "no" ]
}

@test "plugin_active does not prefix-false-match (element vs elementor)" {
  run bash -c "'$SCRIPT' --self-test-fn plugin_active element < '$FIX/plugins.json'"
  [ "$output" = "no" ]
}

@test "plugin_active degrades to no on malformed json (no crash)" {
  run bash -c "'$SCRIPT' --self-test-fn plugin_active elementor < '$FIX/plugins-malformed.json'"
  [ "$status" -eq 0 ]
  [ "$output" = "no" ]
}

# ---- release_zip_url ----
@test "release_zip_url picks the .zip asset over the .txt" {
  run bash -c "'$SCRIPT' --self-test-fn release_zip_url < '$FIX/release.json'"
  [ "$output" = "https://example.com/widget.zip" ]
}

@test "release_zip_url falls back to zipball_url when no asset" {
  run bash -c "'$SCRIPT' --self-test-fn release_zip_url < '$FIX/release-no-asset.json'"
  [ "$output" = "https://api.github.com/repos/acme/widget/zipball/v1" ]
}

# ---- b64_auth ----
@test "b64_auth produces correct base64 with no trailing newline" {
  run "$SCRIPT" --self-test-fn b64_auth Digitizer secret
  [ "$output" = "RGlnaXRpemVyOnNlY3JldA==" ]
}

# ---- regression: readonly builtin name (the WP_UID bug) ----
@test "script never assigns to readonly shell builtin names" {
  # UID/EUID/PPID/BASHPID are readonly; assigning silently no-ops under set +e,
  # which is how the original auth-bypass shipped. Guard at the source level.
  run grep -nE '^\s*(UID|EUID|PPID|BASHPID)=' "$SCRIPT"
  [ "$status" -ne 0 ]   # grep found nothing -> good
}
```

- [ ] **Step 2: Confirm the tests fail without bats/script wiring**

Run (if bats present locally): `bats tests/parsers.bats`
Expected before Task 1 is merged: the self-test hook would be missing and `parse_user_id`/`plugin_active` tests fail. Since Task 1 is already done, instead confirm they now **pass** here — if any fail, fix the parser or test before continuing. (The b64 expectation `RGlnaXRpemVyOnNlY3JldA==` is `Digitizer:secret`.)

- [ ] **Step 3: Commit**

```bash
git add tests/parsers.bats
git commit -m "test: bats unit tests for new-client parsers + readonly-name guard

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 4: Test runner that bootstraps bats

A `tests/run.sh` that uses a local `bats` if present, otherwise vendors bats-core via a shallow git clone into `tests/.bats` (git-ignored), then runs the suite. CI and humans use the same entry point.

**Files:**
- Create: `tests/run.sh`
- Modify: `.gitignore`

- [ ] **Step 1: Create `tests/run.sh`**

```bash
#!/usr/bin/env bash
# Run the kit's bats test suite. Uses a system `bats` if available, else
# vendors bats-core into tests/.bats (git-ignored). Usage: bash tests/run.sh
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if command -v bats >/dev/null 2>&1; then
  BATS=bats
else
  VENDOR="$HERE/.bats"
  if [ ! -x "$VENDOR/bin/bats" ]; then
    echo "bats not found — vendoring bats-core into $VENDOR ..."
    rm -rf "$VENDOR"
    git clone --depth 1 https://github.com/bats-core/bats-core.git "$VENDOR" >/dev/null 2>&1
  fi
  BATS="$VENDOR/bin/bats"
fi

echo "Using bats: $BATS"
"$BATS" "$HERE"/*.bats
```

- [ ] **Step 2: Make it executable + ignore the vendor dir**

Run:
```bash
chmod +x tests/run.sh
```
Append to `.gitignore`:
```
# vendored test runner
tests/.bats/
```

- [ ] **Step 3: Run the suite end to end**

Run: `bash tests/run.sh`
Expected: `Using bats: …` then all tests from `parsers.bats` pass (11 tests, 0 failures). If `git clone` is unavailable offline, install bats via `brew install bats-core` and re-run.

- [ ] **Step 4: Commit**

```bash
git add tests/run.sh .gitignore
git commit -m "test: bats bootstrap runner (system bats or vendored bats-core)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 5: Linux Local-by-Flywheel path candidate

`setup-elementor-mcp.sh` resolves Local's `sites.json` only at the macOS path. Add the Linux location so the wizard works for Linux teammates. Find the macOS lookup and add a candidate-loop.

**Files:**
- Modify: `files/setup-elementor-mcp.sh`

- [ ] **Step 1: Locate the sites.json resolution**

Run: `grep -n "Application Support/Local/sites.json\|/.config/Local\|sites.json" files/setup-elementor-mcp.sh`
Expected: one or more lines referencing the macOS `~/Library/Application Support/Local/sites.json`. Note the exact variable assignment line (call it `SITES_JSON=...`).

- [ ] **Step 2: Replace the single-path assignment with a candidate loop**

Wherever `SITES_JSON` is assigned to the hardcoded macOS path, replace that single assignment with:

```bash
# Local stores sites.json under different roots per OS. Pick the first that exists.
SITES_JSON=""
for cand in \
  "$HOME/Library/Application Support/Local/sites.json" \
  "$HOME/.config/Local/sites.json" \
  "$HOME/.local/share/Local/sites.json"; do
  if [ -f "$cand" ]; then SITES_JSON="$cand"; break; fi
done
# Fall back to the macOS path for the existing not-found messaging.
SITES_JSON="${SITES_JSON:-$HOME/Library/Application Support/Local/sites.json}"
```

(Adapt the variable name to match what the script already uses if it differs.)

- [ ] **Step 3: Syntax check**

Run: `bash -n files/setup-elementor-mcp.sh`
Expected: no output, exit 0.

- [ ] **Step 4: Commit**

```bash
git add files/setup-elementor-mcp.sh
git commit -m "fix(setup): resolve Local sites.json on Linux too (add .config/.local candidates)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 6: Fix shellcheck findings across the three scripts

Get all scripts clean under shellcheck so CI can enforce it.

**Files:**
- Modify (as needed): `INSTALL.sh`, `files/setup-elementor-mcp.sh`, `new-client.sh`

- [ ] **Step 1: Run shellcheck and capture findings**

Run:
```bash
shellcheck -S warning INSTALL.sh new-client.sh files/setup-elementor-mcp.sh || true
```
(If `shellcheck` is not installed: `brew install shellcheck`.)
Expected: a list of SC codes. Common ones here: SC2155 (declare+assign), SC2034 (unused color vars), SC2207, SC2046.

- [ ] **Step 2: Fix real findings; justify-and-disable the rest**

For each finding: fix it if it's a real issue. For intentional patterns (e.g. the color escape vars that *are* used, or word-splitting we rely on), add a scoped `# shellcheck disable=SCXXXX` with a one-line reason directly above the line. Do not blanket-disable at file top. Re-run Step 1 until clean at `-S warning`.

- [ ] **Step 3: Re-verify nothing broke**

Run:
```bash
bash -n INSTALL.sh new-client.sh files/setup-elementor-mcp.sh
bash tests/run.sh
bash new-client.sh --dry-run --local "NoSuchSite__xyz" --user u --app-pass p; echo "exit=$?"
```
Expected: syntax clean; bats green; dry-run aborts at resolve (exit 1) with no traceback.

- [ ] **Step 4: Commit**

```bash
git add INSTALL.sh new-client.sh files/setup-elementor-mcp.sh
git commit -m "style: resolve shellcheck warnings across kit scripts

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 7: CI workflow

Wire the checks into GitHub Actions so every push/PR runs them.

**Files:**
- Create: `.github/workflows/ci.yml`

- [ ] **Step 1: Create `.github/workflows/ci.yml`**

```yaml
name: CI

on:
  push:
    branches: [ main ]
  pull_request:

jobs:
  shell:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: shellcheck
        uses: ludeeus/action-shellcheck@master
        with:
          severity: warning
          scandir: '.'
          additional_files: 'new-client.sh INSTALL.sh'
        env:
          SHELLCHECK_OPTS: -e SC1091

      - name: bash -n syntax
        run: |
          for f in INSTALL.sh new-client.sh files/setup-elementor-mcp.sh; do
            echo "syntax: $f"; bash -n "$f"
          done

      - name: SKILL.md frontmatter lint
        run: |
          python3 - <<'PY'
          import sys, re, pathlib
          p = pathlib.Path("files/SKILL.md").read_text()
          m = re.match(r'^---\n(.*?)\n---\n', p, re.S)
          assert m, "SKILL.md missing YAML frontmatter block"
          fm = m.group(1)
          for key in ("name", "description"):
              mm = re.search(rf'^{key}:\s*(.+)$', fm, re.M)
              assert mm and mm.group(1).strip(), f"SKILL.md frontmatter missing non-empty {key}"
          print("SKILL.md frontmatter OK")
          PY

      - name: dry-run smoke (no network)
        run: |
          set +e
          bash new-client.sh --dry-run --local "NoSuchSite__xyz" --user u --app-pass p
          code=$?
          # nonexistent local site aborts at resolution (exit 1); a crash/traceback
          # would be a different failure. Accept 0 or 1, reject anything else.
          if [ "$code" -gt 1 ]; then echo "unexpected exit $code"; exit 1; fi
          echo "dry-run smoke ok (exit $code)"

  bats:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install bats
        run: sudo apt-get update && sudo apt-get install -y bats
      - name: Run tests
        run: bash tests/run.sh
```

- [ ] **Step 2: Lint the workflow locally**

Run: `python3 -c 'import yaml,sys; yaml.safe_load(open(".github/workflows/ci.yml")); print("yaml ok")'`
Expected: `yaml ok`. (If pyyaml absent: `pip install pyyaml` or skip — CI will parse it.)

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/ci.yml
git commit -m "ci: shellcheck + bash -n + SKILL frontmatter lint + dry-run smoke + bats

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 8: Open the PR

**Files:** none (git/gh only)

- [ ] **Step 1: Push the branch**

Run:
```bash
git push -u origin feat/ci-and-tests
```

- [ ] **Step 2: Open the PR against the Digitizers fork**

Run:
```bash
gh pr create --repo Digitizers/claude-elementor-pro --base main --head feat/ci-and-tests \
  --title "Harden the kit for scale: CI + bats tests" \
  --body "$(cat <<'EOF'
## What
Adds the kit's first CI + test safety net.

- **CI** (`.github/workflows/ci.yml`): shellcheck (`-S warning`), `bash -n` on all three scripts, SKILL.md frontmatter lint, a network-free `--dry-run` smoke, and the bats suite.
- **Tests** (`tests/`): bats unit tests for `new-client.sh`'s parsers via a new hidden `--self-test-fn` hook, plus a regression guard that the script never assigns to readonly shell builtin names (the `WP_UID`/auth-bypass bug class).
- **Refactor**: `new-client.sh` parsers hoisted into pure stdin/arg functions — no behavior change to the normal run path; the script stays a single droppable file (no shared lib).
- **Portability**: `setup-elementor-mcp.sh` now resolves Local's `sites.json` on Linux too.
- **shellcheck**: all current findings resolved.

## Why
First multi-client-scale safety net. Locks in the two real failure modes — silent parse-failure bugs and edge-input crashes.

## Test plan
- `bash tests/run.sh` → green locally.
- `bash -n` clean on all three scripts.
- `new-client.sh --dry-run` exits without network.
- CI green on this PR.

## Out of scope / follow-up
- Unit tests for `setup-elementor-mcp.sh`'s lenient `jq_lenient` extractor (needs the wizard refactored to be sourceable).
- Crocoblock/ACF Tier-0 detection (separate PR).

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

- [ ] **Step 3: Confirm CI is running**

Run: `gh pr checks --repo Digitizers/claude-elementor-pro --watch` (or report the PR URL and that checks were triggered).
Expected: the `shell` and `bats` jobs run. If red, read logs and fix forward on the branch.

---

## Self-Review notes (author)

- **Spec coverage:** CI workflow (Task 7) ✓; bats harness + fixtures + parser tests (Tasks 2–4) ✓; `--self-test-fn` exposure without breaking standalone use (Task 1) ✓; Linux portability touch-up (Task 5) ✓; shellcheck clean (Task 6) ✓; dry-run smoke + frontmatter lint (Task 7) ✓; auth-abort/`WP_UID` regression (Task 3, readonly-name guard + empty-on-`{}` test) ✓.
- **Reconciled deviation from spec:** the spec's "lenient parse still extracts" against a malformed fixture targets `setup-elementor-mcp.sh`'s `jq_lenient`, which isn't sourceable without refactoring the wizard. Scoped `new-client.sh` malformed tests to graceful-degradation instead; logged the lenient-extract unit test as an explicit follow-up.
- **No placeholders:** every code/edit step shows full content; every run step shows the command + expected output.
- **Name consistency:** `parse_user_id`, `plugin_active`, `release_zip_url`, `b64_auth`, `resolve_local_site`, and the `--self-test-fn` hook are used identically across Tasks 1, 3, and the fixtures.
