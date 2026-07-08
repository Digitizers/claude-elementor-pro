# Engine & the Premium plugin — what runs the build

**Engine = our fork `Digitizers/elementor-mcp` (v1.24.0)** — **up to 118** MCP tools,
Elementor 4.x-correct. It bundles the WordPress MCP Adapter, so it installs as a **single
plugin** — no separate adapter plugin needed.

Tool counts scale with the site: **61 / 100 / 105** on a classic (v3) install
(free / Pro / Pro + WooCommerce), and **74 / 113 / 118** when the Elementor 4.0+ atomic
engine is active (the +13 atomic tools). The v1.13–v1.24 fork work adds the design-system
CRUD + governance surface on top (see below).

## What the fork adds over the upstream base (the reason we run it)

The fork started from upstream's 1.x line and has diverged substantially:

- **Elementor 4.x GA atomic correctness** — `is_v4()` schema gating, corrected `$$type` prop
  shapes, style-controls compiled into local style classes, atomic detection by
  element-type registration. Upstream's classic-only schema breaks on 4.1.x.
- **GPL tool set enabled** (v1.13.0) — the brand-kit / SEO / a11y / Widget-Builder tools
  register for everyone (no license gate).
- **v4 design-system CRUD** (v1.14–v1.16) — Global Classes, Variables (with
  `restore-variable`), Interactions (with `edit-interaction`).
- **SiteAgent-governed writes** — page writes are snapshot-first + optional Ed25519
  approval grants + optional post-write render-check auto-revert (v1.17–v1.19); **design-token
  writes (system kit, global palette, Variables) are snapshot-governed too** (v1.24.0).
- **Schema-in-error** (v1.20–v1.21) + **numeric range constraints** in `get-widget-schema`
  (v1.23) — one-round-trip self-correction.

## No Freemius / no phone-home

The vendored Freemius SDK and the upstream hosted "Pro marketplace" (Templates / Skills
fetchers that pulled licensed content from `emcp.msrbuilds.com`) were **removed in v1.22.0**.
The fork has **no license gate, no auto-update channel, and no phone-home** — it is
distributed via GitHub releases (this skill's installer pins/pulls them). The **free**
bundled sample-prompts + brand-kit apply/backup/restore are retained.

## Do NOT run the paid "MCP Tools for Elementor (Premium)" (`emcp-pro`) at the same time

The fork and upstream Premium share the same code lineage (same class names
`Elementor_MCP_*`, same `ELEMENTOR_MCP_VERSION` constant, no PHP namespace). Activating both
= `Cannot redeclare class` fatal. **Only one can be active.**

| | Upstream Premium `emcp-pro` (3.0.0) | fork `elementor-mcp` (1.24.0) |
|---|---|---|
| Elementor 4.x GA atomic engine | ❌ classic-only schema (breaks on 4.1.x) | ✅ 4.x-correct |
| v4 design-system CRUD (classes / variables / interactions) | ❌ | ✅ |
| Governed writes (snapshot + grant + render-check) | ❌ | ✅ (page **and** design-token) |
| Schema-in-error + numeric-range hints | ❌ | ✅ |
| Freemius license / hosted marketplace / phone-home | ✅ | ❌ (removed v1.22) |
| Direction | horizontal (WP content/plugin/theme CRUD, PHP-snippet authoring) | Elementor-4 depth + governance |

**We run the fork.** It is the Elementor-4-correct, design-system-capable, governed engine
this skill is built around. There is no reason to switch to Premium for Elementor page
building; Premium went horizontal (site-wide CRUD) rather than deepening Elementor 4.

## Switching (one active at a time)

```bash
wp plugin deactivate elementor-mcp && wp plugin activate emcp-pro    # → Premium
wp plugin deactivate emcp-pro && wp plugin activate elementor-mcp    # → fork
```

Both share the options `elementor_mcp_disabled_tools` and `elementor_mcp_low_tool_mode` —
a low-tools/disabled-tools state set under one carries to the other.

## Production hygiene

Neither plugin should stay active on a client's **production** server — both are build-time
authoring tools. Deactivate (or remove) at handoff. (The fork's governance — grants +
render-check — is opt-in and needs SiteAgent; it makes *authoring* writes reversible, not a
reason to leave the tool live in production.)
