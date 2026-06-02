# Harden the kit for scale — CI + tests

**Date:** 2026-06-02
**Status:** Approved (design), pending implementation
**Branch:** `feat/ci-and-tests`

## Problem

`claude-elementor-pro` is a client-onboarding kit (two bash scripts + a skill file). It has
**no CI and no tests**. At multi-client scale the two failure modes that hurt are:

1. **Silent parse-failure bugs.** The scripts parse WordPress `/wp-json/` output with inline
   Python. A parser that silently returns empty can let the flow proceed on bad data. The
   real-world `WP_UID` regression (`UID` is a readonly shell builtin → auth check always
   "passed") is exactly this class and shipped undetected.
2. **Edge-input crashes.** Malformed JSON from hardened hosts, missing fields, unusual plugin
   layouts — no guard rail catches a script that breaks on these.

## Goal

Add a lightweight safety net that catches both classes without changing how the kit is used,
and without sacrificing `new-client.sh`'s "single standalone droppable script" property.

## Non-goals (YAGNI)

- No Windows CI runner (document Windows support only).
- No PHPUnit here — PHP tests live in `elementor-mcp`, not this kit.
- No shared-library refactor (`files/lib.sh`). It would couple `new-client.sh` to an external
  file and kill its drop-anywhere portability. The cross-script duplication
  (base64 helper, plugin-detect snippet) is accepted and marked with a one-line comment.

## Scope

### 1. CI workflow — `.github/workflows/ci.yml`

Runs on push + PR. Ubuntu runner. Steps:

- **shellcheck** on `INSTALL.sh`, `files/setup-elementor-mcp.sh`, `new-client.sh`.
  Treat findings as failures; fix all current findings (or inline-disable with justification).
- **`bash -n`** syntax check on the same three scripts.
- **dry-run smoke:** invoke `new-client.sh --dry-run` with dummy flags and assert exit 0 and
  no network call is attempted (the dry-run path must not curl). Guards against the script
  crashing before it even reaches its work.
- **SKILL.md frontmatter lint:** assert `files/SKILL.md` has a YAML frontmatter block with
  non-empty `name` and `description`. A malformed skill header makes the skill silently fail
  to load in Claude Code.
- **bats tests:** run `tests/run.sh`.

### 2. Test harness — `tests/`

```
tests/
  run.sh            # entry: ensure bats present (apt/brew/git-submodule fallback), run *.bats
  parsers.bats      # unit tests for the pure parsing functions
  fixtures/         # sample inputs
    wp-json-root.json        # well-formed /wp-json/ namespaces
    wp-json-malformed.json   # leading garbage before JSON (hardened-host case)
    plugins.json             # plugin list incl. elementor active, pro inactive
    users-me.json            # /users/me payload
```

Tests to lock in:

- `detect`/plugin-active parsing → correct active/inactive verdict from `plugins.json`.
- base64 auth-header builder → known input produces known base64 (no trailing newline).
- release-zip URL extractor → picks the `.zip` asset, falls back to `zipball_url`.
- **auth-abort regression:** bad credentials must abort, not pass. This is the `WP_UID` guard.
- lenient JSON parse tolerates `wp-json-malformed.json` (leading non-JSON) and still extracts.

### 3. Exposing functions to tests without breaking standalone use

`new-client.sh` must still run normally when executed directly, but expose its functions when
a test sources it. Use the standard guard:

```bash
# at the very bottom of new-client.sh, wrap the "main" invocation:
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  main "$@"   # only runs when executed, not when sourced
fi
```

Parsing logic moves into named functions (most already are) so a sourcing test can call them
in isolation. No behavior change when run normally.

### 4. Portability touch-up

- `files/setup-elementor-mcp.sh`: add a Linux Local-by-Flywheel path candidate alongside the
  macOS `~/Library/Application Support/Local/` lookup (one extra candidate dir + existing
  resolution loop). Document Windows as "use Git Bash; Local path manual".

## Verification

1. `shellcheck` + `bash -n` clean locally on all three scripts.
2. `tests/run.sh` green locally (bats).
3. CI green on the PR.
4. Manual: `new-client.sh --dry-run` with dummy flags exits 0, no network.
5. Regression proof: temporarily reintroduce the `UID`/bad-creds bug → the auth-abort test
   goes red. Revert.

## Out of scope / follow-ups

- Crocoblock/ACF Tier-0 (next task, separate spec).
- Cross-script dedup via shared lib (rejected; revisit only if a third script appears).
