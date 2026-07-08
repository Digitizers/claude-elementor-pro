# Changelog

All notable changes to the siteagent-elementor-studio skill kit are documented here.

The format is loosely based on [Keep a Changelog](https://keepachangelog.com/),
and the kit is versioned via the `version:` field in `files/SKILL.md`.

## 1.3.1 — 2026-07-08

- Refresh `references/engine-and-premium.md` (and the SKILL.md engine line) to current facts: the fork is **v1.24.0**, **up to 118 tools**, and — since **v1.22.0** — carries **no Freemius / no hosted marketplace / no phone-home**. Corrects the stale "v1.9.0 / 94 tools / Freemius auto-update" text, documents the v1.13–v1.24 capability surface (design-system CRUD, governed page + design-token writes, schema-in-error, numeric-range hints), and updates the fork-vs-upstream-Premium (`emcp-pro` 3.0.0) comparison. No skill-behavior change.

## 1.3.0 — 2026-07-08

Capability upgrade — teaches the fork's v1.14–v1.23 contract surface (all claims source-verified against `Digitizers/elementor-mcp`). Four additions:

- **Responsive value rules.** New "Responsive values" section in `SKILL.md`: classic widgets take per-breakpoint values as **suffixed keys** (`typography_font_size_tablet`, `align_mobile`) on the same base control with the same value shape; the suffix set is **breakpoint-dependent** (derives from Elementor's active breakpoints — `_tablet`/`_mobile` plus `_widescreen`/`_laptop`/custom, not a fixed list). Atomic (V4) responsive is **variants**, not suffixes — documented in `references/atomic-v4.md`.
- **`settings.classes` wiring for atomic local styles.** `references/atomic-v4.md` now explains the two coupled pieces — the typed `settings.classes` reference list **and** the separate top-level `styles` map that defines each class — the rule that every class id must resolve (local style def or Global Class `g-` id), that the local `styles` map is built **at creation** (`add-atomic-*` / `add-flexbox` / the universal `add-atomic-widget`), and that `update-atomic-widget` merges `settings` only — it can change `settings.classes` references but **cannot** write the `styles` map, so restyle by recreating or via a Global Class.
- **New `references/v3-to-v4-conversion.md`** — rebuilding a classic (V3) design on the atomic (V4) engine: the classic→atomic tool map, never-mix rule, `$$type` envelope cross-reference, styling parity (local styles vs. Global Classes / Variables), a worked hero example, and a conversion checklist.
- **New v1.14–v1.23 fork surface.** New `references/design-system-crud.md` documents the Elementor 4 design-system CRUD tools — Global Classes (`create-/update-/delete-/apply-global-class`), Variables (`list-/get-/create-/edit-/delete-/restore-variable`), and Interactions (`list-/add-/edit-/delete-interaction`), calling out `restore-variable` + `edit-interaction` as fork-superset capabilities, with Pro gating, caps, and permissions. New `references/error-recovery.md` covers governance errors (`governance_grant_required`/`_grant_invalid`/`_render_failed`/`_rollback_failed` — all opt-in, with retry semantics), schema-in-error recovery loops (`invalid_widget_type`/`widget_not_found` inline suggestions; atomic `save_rejected` inline prop schema), and `get-widget-schema` numeric range hints (`minimum`/`maximum`/`multipleOf`, slider unit enums). `SKILL.md` gains focused sections linking out to all three.

## 1.2.1 — 2026-07-08

- Fix the skill's H1 title in `files/SKILL.md` (`# Elementor Pro Studio Skill` → `# SiteAgent Elementor Studio Skill`) — a leftover from before the rename that ClawHub renders as the listing header. Also aligns the ClawHub publish display name to **"SiteAgent Elementor Studio"**. No functional change.

## 1.2.0 — 2026-07-07

- **Renamed: `claude-elementor-pro` → `siteagent-elementor-studio`.** The kit's brand tokens (repo name, install URLs, README title) **and the skill's own invocation name** (`elementor-pro-studio` → `siteagent-elementor-studio`) are rebranded, avoiding the trademark overlap of a name that stacked "Claude" and "Elementor **Pro**" (Elementor's flagship product). Descriptive references — "for Claude Code", Anthropic attribution, Elementor **Pro**-compatibility badges, and the `emersimeon/claude-elementor-kit` upstream credit — are unchanged (nominative/descriptive use).
- **Upgrade note (1.1.x → 1.2.0):** the skill now installs to `~/.claude/skills/siteagent-elementor-studio` and is invoked as `/siteagent-elementor-studio` (previously `elementor-pro-studio`). `INSTALL.sh`/`INSTALL.ps1` detect and offer to remove the prior `elementor-pro-studio` (and older `elementor-mcp`) skill directories so Claude doesn't load two copies. The old GitHub URL redirects.

## 1.1.2 — 2026-06-14

Security hardening (ClawHub audit — siteagent-elementor-studio 1.1.1):
- Read the WordPress application password silently (`read -rs`) so it no longer echoes to the terminal.
- Removed the username-enumeration fallback on auth failure (generic error instead).
- Declared the skill's shell/network/filesystem/env permissions in SKILL.md; noted shell/setup runs only on explicit confirmation.
- `.mcp.json` credential file is now git-ignored on write with a rotation/least-privilege warning.
- Framed companion tooling (content/SEO/media/ACF/Woo) as optional, opt-in, separately-credentialed.
- Added an optional `EMCP_PIN_VERSION` to pin the plugin release (default remains latest from the trusted Digitizers fork over HTTPS).

## 1.1.1 — 2026-06-13

- Point all operational references at our fork `Digitizers/elementor-mcp` (the Elementor 4.x-correct engine the skill drives); msrbuilds/elementor-mcp is retained as end-credit attribution only.
- Fix the post-install prompt to say `/siteagent-elementor-studio` (was still `/elementor-mcp`).
- `publish-clawhub.yml` dry-run now calls the real `clawhub skill publish --dry-run` (confirmed a genuine CLI flag) instead of just echoing the command.

## 1.1.0 — 2026-06-12

- Renamed the skill's invocation name to `siteagent-elementor-studio` (OpenClaw-neutral) and published to ClawHub under "Elementor Pro Studio". The GitHub repo remains `siteagent-elementor-studio`.
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

- Initial release of the SiteAgent Elementor Studio skill kit.
