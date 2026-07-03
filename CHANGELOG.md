# Changelog

All notable changes to the claude-elementor-pro skill kit are documented here.

The format is loosely based on [Keep a Changelog](https://keepachangelog.com/),
and the kit is versioned via the `version:` field in `files/SKILL.md`.

## 1.1.2 — 2026-06-14

Security hardening (ClawHub audit — elementor-pro-studio 1.1.1):
- Read the WordPress application password silently (`read -rs`) so it no longer echoes to the terminal.
- Removed the username-enumeration fallback on auth failure (generic error instead).
- Declared the skill's shell/network/filesystem/env permissions in SKILL.md; noted shell/setup runs only on explicit confirmation.
- `.mcp.json` credential file is now git-ignored on write with a rotation/least-privilege warning.
- Framed companion tooling (content/SEO/media/ACF/Woo) as optional, opt-in, separately-credentialed.
- Added an optional `EMCP_PIN_VERSION` to pin the plugin release (default remains latest from the trusted Digitizers fork over HTTPS).

## 1.1.1 — 2026-06-13

- Point all operational references at our fork `Digitizers/elementor-mcp` (the Elementor 4.x-correct engine the skill drives); msrbuilds/elementor-mcp is retained as end-credit attribution only.
- Fix the post-install prompt to say `/elementor-pro-studio` (was still `/elementor-mcp`).
- `publish-clawhub.yml` dry-run now calls the real `clawhub skill publish --dry-run` (confirmed a genuine CLI flag) instead of just echoing the command.

## 1.1.0 — 2026-06-12

- Renamed the skill's invocation name to `elementor-pro-studio` (OpenClaw-neutral) and published to ClawHub under "Elementor Pro Studio". The GitHub repo remains `claude-elementor-pro`.
- Added a ClawHub publish workflow.

## [1.0.1] - 2026-07-03

Addresses Codex review findings across the installers and reference docs.

### Fixed

- **`new-client.sh` (HIGH):** live-host onboarding now copies the plugin zip to a
  durable path (`$PROJECT_DIR`, else `$HOME`) **before** aborting. The `EXIT` trap
  (`rm -rf "$WORK"`) previously deleted the zip the instant the script aborted, so the
  printed upload instructions pointed at an already-gone file.
- **`references/recipes.md` FAQ (HIGH):** dropped the "a mixed page is fine" guidance,
  which contradicted the never-mix rule (a classic accordion on a V4/atomic page does
  not persist). The div-block + `<details>` atomic pattern is now the only documented
  V4 path for the FAQ recipe.
- **`new-client.sh` (MED):** a local plugin-install failure is now fatal (`abort`),
  and the route check is fatal after an attempted install — no more false
  "Client ready" with a broken `.mcp.json`.
- **`setup-elementor-mcp.sh` (MED):** the MCP install step now supports Linux Local
  data roots (`~/.config/Local`, `~/.local/share/Local`) and app-resource paths,
  falling back to a clear manual-upload flow when the bundled WP-CLI toolchain can't be
  located — instead of resolving the site then aborting on macOS-only paths.
- **`setup-elementor-mcp.sh` (MED):** reinstall no longer skips solely because a
  generic `mcp` namespace is present. It now detects the old `mcp-adapter` +
  upstream `elementor-mcp` pair (standalone adapter plugin, or a pre-fork version)
  and offers to (re)install the bundled Digitizers fork over it.
- **`setup-elementor-mcp.sh` (P1, Codex follow-up):** accepting that (re)install no
  longer just warns and installs the fork on top of the old setup. A new
  `remove_plugin` helper deactivates + deletes the standalone `mcp-adapter` plugin
  via REST and re-verifies (via `refresh_plugins_json` + `plugin_is_installed`) that
  it's actually gone before the fork install proceeds. If REST removal fails, the
  script pauses in a recheck loop (or aborts on request) instead of ever installing
  the bundled fork alongside the still-present standalone adapter — which would
  double-load the MCP transport and break the route.
- **`references/recipes.md` Contact (MED):** added an `*Atomic/V4*` variant — a
  Fluent Forms shortcode dropped via `add-atomic-widget`, flagging that the native Pro
  Form widget isn't V4-ready.
- **`references/atomic-v4.md` (LOW):** clarified that "pass simple flat values" applies
  to the dedicated atomic helper tools; the universal `add-atomic-widget` /
  `update-atomic-widget` escape hatch needs raw `$$type`-shaped settings (flat values
  there are saved as empty/ignored).
- **`setup-elementor-mcp.sh` + `new-client.sh` (LOW):** a leading `~` in a resolved
  Local path from `sites.json` is now expanded to `$HOME` before the `wp-config.php`
  probe, which otherwise looked for a literal `~/...` directory and aborted.

## [1.0.0]

- Initial release of the Claude + Elementor Pro skill kit.
