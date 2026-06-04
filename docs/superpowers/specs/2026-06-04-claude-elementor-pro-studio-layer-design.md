# claude-elementor-pro → studio-layer reshape — design spec

**Date:** 2026-06-04
**Repo:** `Digitizers/claude-elementor-pro`
**Trigger:** Field Report #3 — the paid `emcp-pro` (Premium) is the same lineage as our fork but **behind on Elementor 4.x GA** (76 tools, 3.x schema) while our **fork** `Digitizers/elementor-mcp` v1.9.0 is 4.x-correct (94 tools, PR #52). Decision: anchor the studio's Elementor capability on the **fork**, focus this skill on the **studio layer**.

## Positioning

`claude-elementor-pro` is the studio's Elementor capability:
- **Engine = the fork** `Digitizers/elementor-mcp` v1.9.0 (94 tools, 4.x-correct). **Not** Premium — Premium is behind on 4.x GA and shares the fork's class names (`Elementor_MCP_*`, constant `ELEMENTOR_MCP_VERSION`), so the two are **mutually exclusive** (co-activation = redeclare fatal).
- **Build guide = this skill's SKILL.md** (the fork bundles no skill — only Premium does). So the build mechanics MUST stay here.
- **Studio layer** (this reshape) = verticals, lifecycle glue, brand/voice, and a slimmer SKILL.

## Confirmed facts (verified on disk, 2026-06-04)

- Fork v1.9.0 **bundles the MCP Adapter** (`includes/vendors/mcp-adapter/` + `class-mcp-adapter-bootstrap.php`). It is self-contained → installing the fork no longer needs a *separate* MCP Adapter plugin.
- Current `files/SKILL.md` is **872 lines** — a comprehensive monolith. Big extractable sections (line ranges approximate, re-locate by heading at implementation time):
  - Forms (native Form + Fluent Forms fallback) — `## Forms` … through end (~587–788, ~200 lines)
  - Dynamic data stacks — ACF & Crocoblock/JetEngine — `## Dynamic data stacks` (~528–586)
  - Pro-only widgets & features — Loop Grid, Popups, Dynamic Tags, Sticky/Motion — `## Pro-only widgets & features` (~463–527)
  - Header/Footer notes — Theme Builder vs UAE/HFE — `## Header/Footer notes` (~408–462)
  - Building on Elementor 4 (atomic/V4) — `## Building on Elementor 4` (~259–321)
- Premium's 5 prompts (`docs/refs/emcp-pro/prompts/*.md`, gitignored) are **paid assets**. Their *structure* (CRITICAL LAYOUT RULES + DESIGN SYSTEM: color palette, typography, section flow) is a useful template, but the studio verticals must be **written in Digitizer's own voice**, not copied verbatim (public repo + licensing).

## Decisions (confirmed with user)

1. **Build mechanics stay in claude-elementor-pro** (the fork has no bundled skill). The reshape repositions + slims; it does not gut the mechanics.
2. Build all four studio-layer workstreams: **verticals, lifecycle glue, brand/voice + Premium relationship doc, slim the SKILL.**

## Architecture / file structure (after reshape)

```
files/
├── SKILL.md                     # SLIMMED core: first-action protocol, Pro/Free + engine
│                                #   (classic vs atomic-V4) detection, widget-vs-HTML decision,
│                                #   build/edit/inspect/explore modes, brand-kit + recipe pointers,
│                                #   safety, tool-loading discipline, quick-ref, + ref/vertical pointers
└── references/
    ├── forms.md                 # NEW (extracted): native Form (Pro) + Fluent Forms (free) fallback
    ├── dynamic-data.md          # NEW (extracted): ACF + Crocoblock/JetEngine (Tier-0)
    ├── pro-widgets.md           # NEW (extracted): Loop Grid/Carousel, Popups, Dynamic Tags, Sticky/Motion
    ├── header-footer.md         # NEW (extracted): Theme Builder (Pro) vs UAE/HFE (free)
    ├── atomic-v4.md             # NEW (extracted): Elementor 4 atomic model, atomic tool family, build order
    ├── recipes.md               # exists — unchanged
    ├── brand-kit.md             # exists — add cross-ref to the fork's brand-kit tools
    ├── engine-and-premium.md    # NEW: engine=fork rationale; do NOT co-run Premium; 4.x gap table;
    │                            #   the `wp plugin deactivate/activate` switch; adapter is bundled
    ├── lifecycle.md             # NEW: audit→build→host glue + "where am I in the lifecycle" router
    └── verticals/
        ├── dental.md
        ├── salon.md
        ├── car-wash.md
        ├── local-business.md
        └── portfolio.md         # NEW (5): studio-voice vertical packs
```

The installer (`INSTALL.*`) still copies `files/SKILL.md` + `files/setup-elementor-mcp.sh` to `~/.claude/`. The reference files live alongside SKILL.md under `~/.claude/skills/elementor-mcp/references/` and load on demand (progressive disclosure) — confirm the installer copies the `references/` tree (it must, for the pointers to resolve).

## Workstreams

### W1 — Slim the SKILL (progressive disclosure)
- Move the 5 big sections out of `files/SKILL.md` into the new `references/*.md`, verbatim (no content change — relocation only).
- In SKILL.md, replace each moved section with a 2–4 line summary + a pointer ("Forms → load `references/forms.md`"). Keep the **decision spine** in core: when to use which path, the Pro/free + classic/atomic branch, the widget-vs-HTML rule, build order.
- Update the Quick-Route / tool-loading section to list the new refs.
- **No mechanics lost** — verify by diffing the moved blocks against the originals.

### W2 — Verticals (5 studio packs)
- Create `references/verticals/<slug>.md` for dental, salon, car-wash, local-business, portfolio.
- Each pack: studio brand voice + a design system (color palette, typography, spacing) + section flow + the brand-kit/recipe combo to use. Structured like a build brief the core can route to.
- **Written in Digitizer's voice**, informed by (not copied from) Premium's prompt structure. No verbatim paid content.
- SKILL core gains a short "vertical routing" note: when the client matches a vertical, load its pack first.

### W3 — Lifecycle glue
- `references/lifecycle.md`: the studio toolbox handoffs — **audit** (`wordpress-api-pro` `site_audit.py`) → **build** (this skill) → **host** (`cloudways-mcp` / `hostinger-mcp`), plus content (`wordpress-api-pro`) and ads (`meta-ads-mcp`) touchpoints. A "where am I in the lifecycle / what's the next tool" router.
- SKILL core gains a one-line pointer to it (keeps the existing `## Companion tooling — wordpress-api-pro` and extends it to the full toolbox).

### W4 — Brand/voice + Premium relationship doc
- `references/engine-and-premium.md`: states engine = fork v1.9.0 (94 tools, 4.x-correct); a short gap table vs Premium (76 tools, 3.x); the hard rule **never co-activate Premium and the fork** (same class names → fatal); the switch commands (`wp plugin deactivate elementor-mcp && wp plugin activate emcp-pro` and back); note the adapter is bundled (no separate install); note both share the `elementor_mcp_*` options.
- SKILL core gains a short studio brand-voice default (tone, defaults) + a one-line pointer to engine-and-premium.md in the setup section.

### Install simplification (within W4 / setup)
- The fork bundles the MCP Adapter → `files/setup-elementor-mcp.sh` should install **one** plugin (the fork), not the MCP-Adapter-plus-elementor-mcp pair. Verify the current script's plugin-install step and drop the now-redundant separate adapter install; keep app-password wiring + `.mcp.json` generation. Adjust `docs/WHATS_INSTALLED.md` to match.

## Out of scope (YAGNI)

- Bundling the SKILL into the fork (rejected — keep mechanics here).
- Migrating to Premium (rejected — Premium is 4.x-behind; revisit only after upstream merges the 4.x work and Premium ships it).
- New build tools / engine changes (the fork is the engine; its tools are out of scope here).
- More than 5 verticals (start with the 5 we have prompt-structure for).

## Verification

- SKILL core: every moved section replaced by a summary + a resolvable pointer; the decision spine intact.
- **No content loss:** each extracted reference contains the original section's full content (diff the moved blocks).
- All `references/*.md` referenced in SKILL.md exist (link-resolve check).
- Verticals are studio-voice (no verbatim paid-prompt text — spot check against `docs/refs/emcp-pro/prompts/`).
- Installer copies `references/` (so pointers resolve on a real install); setup script installs only the fork; `WHATS_INSTALLED.md` matches.
- CI green (the repo's existing bats/shell checks); house-style README intact.
- Manual: a fresh build session can still reach every capability via progressive disclosure (load core → follow a pointer → mechanics present).

## Open implementation notes

- Re-locate the extract points by **heading**, not the approximate line numbers above (the file may have shifted).
- Confirm whether `INSTALL.sh`/`new-client.sh` already copy a `references/` dir; if not, add it (the current skill referenced `files/references/recipes.md` + `brand-kit.md`, so the path likely already works — verify).
