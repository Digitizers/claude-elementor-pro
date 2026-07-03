# Changelog

All notable changes to the claude-elementor-pro skill kit are documented here.

The format is loosely based on [Keep a Changelog](https://keepachangelog.com/),
and the kit is versioned via the `version:` field in `files/SKILL.md`.

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
