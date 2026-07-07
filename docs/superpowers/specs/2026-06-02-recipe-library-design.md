# Section recipe library (P1b)

**Date:** 2026-06-02
**Status:** Approved (design), pending implementation
**Repo:** `Digitizers/siteagent-elementor-studio`
**Branch:** `feat/recipe-library`
**Depends on:** P1a brand-kit tokens (PR #10) — recipes reference those tokens by name.

## Problem

The studio rebuilds the same section types (hero, services, CTA, contact…) from
scratch every client — inconsistent, slow, no compounding reuse. P1a established
brand tokens; nothing yet tells the skill *how to assemble* a section from them. A
recipe library is the studio's compounding asset: proven, brand-token-driven build
sequences the skill follows.

## Goal

A library of 10 reusable section recipes the skill consults before building a
section — each a classic-first build sequence bound to brand tokens, with short
variant notes for Pro and atomic where they diverge.

## Recipe format

Each recipe is one section in `files/references/recipes.md`:

- **When to use** — one line.
- **Structure** — the container tree as an indented list: outer container (full-width,
  token background, vertical padding) → inner container (boxed, max-width ~1200–1360px,
  centered) → content widgets. Nesting explicit.
- **Tokens & scale** — which brand tokens bind where (bg/`bg`|`surface`, headings
  `heading`, body `text`, accents `brand`/`accent`, hairlines `border`) and which
  type-scale step each text uses (h1/h2/h3/body-lg/body/small).
- **Key settings** — the few settings that matter (alignment, gap, columns,
  button style), in the flat-param convention the skill already uses.
- **Responsive** — the one or two things to change on mobile (stack columns, shrink
  hero scale).
- **Variants** — short notes only: **Pro** (e.g. dynamic grid → Loop Grid; real form
  → Form widget) and **Atomic/V4** (container → e-flexbox; the diverging bit). Not a
  full second tree.

## The 10 recipes (v1)

1. **Hero** — outer(`bg`) → boxed → eyebrow(small,`accent`) · h1(`heading`) ·
   lead(body-lg,`text`) · button row (primary `brand`, secondary outline `border`).
2. **Services / feature grid** — section(`surface`) → boxed → heading block → 3-col
   container of cards (`bg`, `border`, radius): icon · h3 · body. Pro+dynamic → Loop
   Grid; else duplicate-element ×N.
3. **Split (image + text)** — boxed 2-col: media one side, text stack other (h2,
   body, button). Alternate sides down the page; stack on mobile.
4. **Stats band** — section(`brand` bg, inverted text) → boxed → 3–4 col: big
   number(h1/h2) + label(small). Inverted token usage noted.
5. **Testimonials** — section(`surface`) → boxed → heading → quote card(s) (`bg`,
   `border`): quote(body-lg) · name(body) · role(small,`muted`). Pro → carousel.
6. **CTA band** — full-width(`brand`) → boxed centered → h2(inverted) · body ·
   button(contrast). Compact vertical padding band.
7. **Contact** — boxed 2-col: left text/details, right form. Pro → native Form
   widget; free → Fluent Forms (per existing Forms section). Token-bound labels.
8. **FAQ** — boxed narrow (max-w ~800) → heading → accordion/toggle items
   (question h4, answer body); `border` between items.
9. **Pricing** — section(`surface`) → boxed → heading → 3-col plan cards (`bg`,
   `border`, featured card `brand` accent): plan name(h3) · price(h2) · feature
   list(body) · button. Featured card emphasis noted.
10. **Logos / clients strip** — section(`bg`) → boxed → optional caption(small,
    `muted`) → single row of logos (grayscale, even gaps), wrap/scroll on mobile.

## File structure

- Create `files/references/recipes.md` — intro (how to use a recipe + the rules) +
  the 10 recipe sections (each an H2/H3 with the format above).
- Modify `files/SKILL.md` — new `## Recipe library` section: lists the 10 recipes
  with one-line "when to use", the rule ("consult the matching recipe before building
  a section; bind to brand tokens; classic-first, apply the variant note for Pro/V4"),
  and a pointer to `references/recipes.md`. Build-order step 4 ("Build sections")
  references the library.
- Modify `.github/workflows/ci.yml` — assert recipes.md has all 10 recipe headings,
  SKILL links it, and recipes reference brand tokens.

## Discipline ties (reuse, don't restate)

Recipes assume and reinforce the skill's existing rules: tokens by name (P1a),
native widgets not HTML dumps, container model, `duplicate-element` for fixed card
sets / Loop Grid for dynamic (Pro), the flat-param widget convention. Recipes point
to those sections rather than duplicating them.

## Non-goals (YAGNI)

- Full dual classic+atomic trees (variant notes only).
- Per-recipe files / a recipe "engine" (single markdown file; split later if it grows).
- Header/footer (already covered by the Header/Footer section) and team/about-bio,
  blog-feed — future additions.
- A runnable generator — building is Claude driving the MCP, not a script.

## Testing / verification

Skill-documentation feature; no runtime code.

- CI: recipes.md contains all 10 expected recipe titles; SKILL.md links
  `references/recipes.md`; recipes.md mentions brand tokens (e.g. `brand`, `surface`).
- SKILL frontmatter lint stays green.
- **Live verify (documented, manual/second-session):** build one recipe (e.g. Hero)
  on SoftLab using the brand tokens → renders to spec, tokens bound. Acceptance check,
  not automated.

## Follow-ups

- More recipes (team, pricing variants, blog feed, logos animations).
- Optional: a recipe → live screenshot gallery once P2 (Playwright fidelity loop) exists.
