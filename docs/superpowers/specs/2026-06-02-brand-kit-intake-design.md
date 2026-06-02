# Brand-kit intake & token vocabulary (P1a)

**Date:** 2026-06-02
**Status:** Approved (design), pending implementation
**Repo:** `Digitizers/claude-elementor-pro` (the skill kit)
**Branch:** `feat/brand-kit-intake`

## Problem

SKILL.md tells Claude to "establish design tokens" via `update-global-colors` /
`update-global-typography` as build step 1, but there is **no token vocabulary, no
intake flow, and no discipline** to reference tokens consistently. Each client build
re-decides colors/fonts ad hoc and hard-codes raw hex into widgets. For a studio
running many client sites, that means inconsistency and no compounding reuse — and
it blocks the recipe library (P1b), which must reference brand tokens by name.

## Goal

A documented brand-token vocabulary + an intake flow that maps a client's brand onto
**named Elementor global colors/typography** (fully MCP-settable), plus the
discipline that every later build references tokens **by name, never raw hex**. This
is the foundation the recipe library (P1b) consumes.

## Grounding (verified in elementor-mcp fork)

- `update-global-colors` accepts `[{_id, title, color}]` and merges them by `_id`
  into the kit's **`custom_colors`** (it does NOT overwrite the 4 system slots).
- `update-global-typography` accepts `[{_id, title, typography_*}]` merged by `_id`
  into **`custom_typography`**.

So the entire token set maps to **named custom globals** — each token is a
first-class entry Elementor's global picker exposes. No dependency on the 4 system
slots.

## Token vocabulary

### Colors (8 named custom globals)

| token `_id` | title | role |
|---|---|---|
| `brand` | Brand | primary brand color (buttons, links, emphasis) |
| `accent` | Accent | secondary highlight |
| `heading` | Heading | heading text color |
| `text` | Text | body text color |
| `bg` | Background | page background |
| `surface` | Surface | card/section panel background |
| `muted` | Muted | secondary/subtle text, captions |
| `border` | Border | hairlines, dividers, card borders |

### Typography (2 named custom globals + a scale)

| token `_id` | title | role |
|---|---|---|
| `heading-font` | Heading Font | font family for headings |
| `body-font` | Body Font | font family for body/UI |

A documented **type scale** (not a global object — applied per-widget by recipes):
`h1 48 / h2 36 / h3 28 / h4 22 / body-lg 18 / body 16 / small 14` (px desktop;
recipes scale down responsively). Heading weight, line-height, and letter-spacing
defaults included.

### Logo

Recorded as a media id / URL in the intake record; used by header recipes (Site Logo
widget or a Heading fallback). Not a global object.

## Intake flow (new SKILL.md section)

Triggers on new-client / "set up the brand" / brand-kit requests. Steps:

1. **Gather** the brand: the 8 colors (hex), 2 font families, logo — from the user's
   brief, a Figma file, or by asking. Where the client gives fewer than 8 colors,
   derive the rest sensibly (e.g. `surface` = a tint of `bg`; `muted` = `text` at
   lower contrast) and state the derivation.
2. **Map** to the token vocabulary above.
3. **Apply:**
   - `update-global-colors` with the 8 `{_id, title, color}` entries.
   - `update-global-typography` with the 2 font entries.
4. **Record** the token→value map back to the user (and it lives in the page/project
   notes) so recipes and later edits reference it.
5. **Verify** with `get-global-settings` — confirm the 8 colors + 2 fonts are present.

**Discipline (the core rule):** after intake, **every build references tokens by
their global name, never a raw hex/font**. In Elementor that means binding a
widget's color to the global color, or — when a recipe sets a value directly — using
the recorded token value, never an ad-hoc one. This is what makes recipes
brand-driven and clients consistent.

## Deliverables

1. **`files/references/brand-kit.md`** (new) — the token vocabulary table, the
   Elementor custom-global mapping, the type scale, a fillable **intake template**
   (a small JSON/table the studio fills per client), and a worked example.
2. **SKILL.md — new `## Brand kit — intake & tokens` section** — lean: when it
   triggers, the 5-step flow, the by-name discipline, and a pointer to
   `references/brand-kit.md` for the full schema (progressive disclosure).
3. SKILL.md build-order step 1 updated to point at the brand-kit flow instead of the
   bare "establish design tokens" line.

## Non-goals (YAGNI)

- The recipe library itself (P1b — separate spec; it consumes these tokens).
- A brand-apply CLI/script — the apply path is Claude driving the MCP, not a CLI.
- Overwriting Elementor's 4 system color slots (the tool targets custom globals;
  named customs are the cleaner home anyway).
- Dark-mode / multi-theme token sets — single brand kit per site for v1.

## Testing / verification

This is a skill-documentation feature; no runtime code.

- SKILL.md frontmatter lint (already in CI) stays green.
- `references/brand-kit.md` is well-formed markdown; the intake-template JSON example
  parses (a tiny CI step: `python3 -c "json.load(...)"` on the fenced example, or a
  manual check).
- **Live verify (documented, manual/second-session):** run the intake flow on
  SoftLab with a sample brand → `get-global-settings` shows the 8 custom colors + 2
  custom typography entries by name. Recorded as the acceptance check, not automated
  (needs the MCP/HTTP session).

## Follow-ups

- P1b recipe library — references these tokens.
- Optional later: a JSON brand-intake file the new-client onboarding can carry, so
  brand setup is part of headless onboarding.
