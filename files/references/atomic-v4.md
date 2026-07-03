# Building on Elementor 4 (atomic / V4) — reference

## Building on Elementor 4 (atomic / V4)

Apply this section **only when you detected the atomic engine** (atomic tools
present). On a classic-engine site, ignore it and use the classic widget tools
everywhere. **Never mix:** classic `add-heading`/`add-container` writes do not
persist on an atomic page, and atomic writes don't belong on a classic page.

### Atomic tool family — use instead of the classic ones

| Need | Classic (don't use on V4) | **Atomic (V4)** |
|---|---|---|
| Flex container | `add-container` | `add-flexbox` *(direction/justify/align/gap/wrap/padding/background_color)* |
| Block container | `add-container` | `add-div-block` |
| Heading | `add-heading` | `add-atomic-heading` |
| Body text | `add-text-editor` | `add-atomic-paragraph` |
| Button | `add-button` | `add-atomic-button` |
| Image | `add-image` | `add-atomic-image` |
| SVG / video / divider | `add-icon` / `add-html` | `add-atomic-svg` / `add-atomic-youtube` / `add-atomic-video` / `add-atomic-divider` |
| Anything else | `add-widget` | `add-atomic-widget` *(any atomic type; pass raw `$$type`-shaped settings — see note)* / `update-atomic-widget` |

### The atomic data model (what's different)

- **Typed props (`$$type`).** Atomic settings are typed values, not flat strings.
  For the **dedicated** helper tools (`add-atomic-heading`, `add-atomic-paragraph`,
  `add-atomic-button`, `add-flexbox`, …) the MCP wraps them for you — **pass simple
  flat values** (e.g. `title: "Hello"`, a hex `color`, a `{size,unit}` dimension) and
  it stores them in the `$$type` format Elementor's atomic engine expects.
  **Exception — the universal `add-atomic-widget` / `update-atomic-widget` escape
  hatch does NOT wrap for you.** It writes settings verbatim, so it needs values
  already in raw `$$type` shape; flat values passed there are silently saved as
  empty/ignored settings. For those two tools, fetch the shape with
  `get-widget-schema` and build the typed props by hand.
- **Styles live in a separate `styles` map**, not inline on the element. Layout
  props on `add-flexbox` (direction/justify/align/gap) are written as local styles
  automatically — you don't hand-build the styles map.
- **Confirm keys per widget** with `get-widget-schema` before building anything
  non-trivial; the atomic prop names differ from the classic control names.

### Build order on V4

Same top-down discipline as classic, with atomic tools:

1. `update-global-colors` + `update-global-typography` (global kit still applies).
2. `create-page` → build the outer layout with `add-flexbox` (section) → inner
   `add-flexbox`/`add-div-block` (boxed content) → atomic widgets inside.
3. Card grids: build one card from atomic widgets, then `duplicate-element` +
   `update-atomic-widget` per copy (same pattern, atomic tools).
4. Verify after each section with `get-page-structure` + curl the front page.

### Pro widgets on V4 — the real limitation

Elementor has **not** shipped atomic equivalents for the Pro widgets yet (Form,
Loop Grid, Nav Menu, Theme Builder parts). On an atomic page they're classic
islands that **may not render**. So when the design needs them:

- **Contact form:** prefer a **Fluent Forms shortcode** dropped via an atomic
  widget (`add-atomic-widget` of a shortcode/HTML type), not the Pro Form widget.
  Flag to the user that the native Pro Form isn't V4-ready.
- **Dynamic listings:** if Loop Grid won't render, fall back to atomic cards built
  from a query you fetch out-of-band (or `wordpress-api-pro`), or accept a classic
  island only if it renders on this build.
- **Header/footer:** Theme Builder still works at the template level; build the
  template body with atomic tools where supported.

> If the user needs heavy Pro-widget functionality **and** doesn't specifically
> need V4, the lowest-friction path is a classic-engine site (turn off the V4
> page experiment under Elementor → Settings → Features). Surface this tradeoff
> rather than silently shipping a page where the form doesn't render.

