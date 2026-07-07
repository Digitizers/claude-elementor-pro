# Studio toolbox hub in digitizer-os

**Date:** 2026-06-02
**Status:** Approved (design), pending implementation
**Repo:** `Digitizers/digitizer-os` (private studio brain)
**Branch:** `feat/toolbox-hub`

## Problem

The studio now has 5 flagship tools spanning the full client lifecycle — but they're
**siloed**. digitizer-os (the strategic brain) is the natural hub, yet its
`knowledge/tools-and-repos.json` is **stale and flat**: it lists generic skill names,
omits `cloudways-mcp` entirely, and doesn't capture the recent `siteagent-elementor-studio`
capabilities (brand-kit, recipes, CPT seeding, V4 fixes). Its engines (e.g.
website-audit) are manual checklists that don't point at the operational tools. So
when a session asks "which tool do we use for X" or "run the full client flow", the
brain can't route — it doesn't know its own arsenal.

## Goal

Make digitizer-os the toolbox hub: an accurate catalog of the studio's flagship
tools + an end-to-end client-lifecycle router that maps each stage to the right
tool(s). v1 is **route-only** — the brain *knows and points*; it does not yet rewire
engines to call the tools.

## The 5 flagship tools (catalog content)

| tool | repo | what it does | when to use |
|---|---|---|---|
| **siteagent-elementor-studio** | `Digitizers/siteagent-elementor-studio` | Skill kit to build Elementor sites via the MCP — Pro/free + classic/V4 detection, brand-kit token intake, 10 section recipes, `new-client.sh` headless onboarding, Tier-0 ACF/JetEngine | building/onboarding a client Elementor site |
| **wordpress-api-pro** | `Digitizers/wordpress-api-pro` | WP REST ops skill — posts/pages/media, SEO meta (RankMath/Yoast), ACF/JetEngine fields, WooCommerce, Elementor data, **CPT content seeding** | content/SEO/media/dynamic-data ops on a WP site |
| **elementor-mcp (fork)** | `Digitizers/elementor-mcp` | The MCP **plugin** that exposes Elementor to the agent — Digitizers fork with the V4/atomic detection + save + styling fixes (the engine `siteagent-elementor-studio` drives) | installed on the site; the build layer underneath elementor-pro |
| **cloudways-mcp** | `Digitizers/cloudways-mcp` | Skill to manage Cloudways hosting via MCP — multi-account, monitoring, maintenance, SSL/cache/backups, onboarding/audit, write-confirmation safety | hosting/server ops, audits, maintenance on Cloudways-hosted clients |
| **digitizer-os** | `Digitizers/digitizer-os` | This brain — strategy, sales, pricing, services, delivery, risks, growth, competitive intel, engines/cases/agents | deals, pricing, strategy, the hub itself |

Status column: siteagent-elementor-studio / wordpress-api-pro / elementor-mcp = active &
shipping; cloudways-mcp = new, MCP server availability uncertain (cw-mcp 404 /
official Q2 2026); digitizer-os = active.

## Client-lifecycle router (stage → tool)

| stage | tool(s) |
|---|---|
| Lead / qualify | digitizer-os (`5_sales`, `7_risks`, `engines/deal-analyzer`) |
| Pre-sale audit | digitizer-os `engines/website-audit-engine` + wordpress-api-pro (CMS/plugin/SEO detect) + cloudways-mcp (server/SSL/disk, if hosted there) |
| Proposal / pricing | digitizer-os (`engines/offer-builder`, `engines/profitability-calculator`) |
| Onboard | siteagent-elementor-studio `new-client.sh` (wire the MCP + auth) + cloudways-mcp onboarding/audit |
| Brand setup | siteagent-elementor-studio brand-kit intake (`references/brand-kit.md`) |
| Build | siteagent-elementor-studio + recipes (`references/recipes.md`); elementor-mcp fork is the engine |
| Content / SEO / dynamic data | wordpress-api-pro (posts/SEO/media/CPT seeding/ACF/Jet) |
| Host / monitor / maintain | cloudways-mcp (monitoring, maintenance, SSL/backup) |

## Components

1. **Create `digitizer-os/knowledge/studio-toolbox.md`** — canonical catalog (the
   table above + the status notes + repo links). Short intro: "the studio's own
   tools; route here before deciding how to deliver."
2. **Create `digitizer-os/knowledge/client-lifecycle.md`** — the stage→tool router
   (table above) + a one-line note per stage on the handoff.
3. **Refresh `digitizer-os/knowledge/tools-and-repos.json`** — add a
   `studio_flagship_tools` block with the 5 tools (name, repo, role, status),
   pointing to `studio-toolbox.md` as canonical; leave the existing
   `installed_skills` list but add a note that flagship tools are catalogued
   separately. Don't delete existing data.
4. **Update `digitizer-os/SKILL.md`** — Quick Route rows: "Which tool for X / what
   can we deliver" → `knowledge/studio-toolbox.md`; "Run the full client flow /
   onboarding sequence" → `knowledge/client-lifecycle.md`. Add a Rules line: for
   delivery/how-to-execute questions, consult the toolbox before answering.

## Non-goals (YAGNI)

- Rewiring engines (website-audit etc.) to actually call the operational tools —
  separate follow-up (the "tool-powered audit" option).
- Bringing cloudways-mcp to kit-standard (CI/version/ClawHub) — separate follow-up.
- Auto-syncing the catalog from the repos — manual for now; refresh when a tool
  ships a major capability.
- Touching the other tools' repos — this change is entirely within digitizer-os.

## Verification

Doc feature; digitizer-os is a private skill (no GitHub CI assumed). A local
consistency check (small python/grep), run before commit:
- `studio-toolbox.md` names all 5 tools (siteagent-elementor-studio, wordpress-api-pro,
  elementor-mcp, cloudways-mcp, digitizer-os).
- `client-lifecycle.md` has all 8 stages, each mapping to ≥1 tool.
- `SKILL.md` routes to both new docs.
- `tools-and-repos.json` still parses and contains the `studio_flagship_tools` block.

## Follow-ups

- Tool-powered website-audit (engine calls wp-api-pro + cloudways-mcp).
- cloudways-mcp → kit standard (CI, version, ClawHub).
- Optional: a single "client lifecycle" runnable checklist the brain can execute
  step-by-step.
