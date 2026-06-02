# Atomic widget styling via MCP

**Date:** 2026-06-02
**Status:** Approved (design), pending implementation
**Repo:** `msrbuilds/elementor-mcp` (work on Digitizers fork → upstream PR)
**Branch:** `feat/atomic-widget-styling`

## Problem

The atomic (V4) convenience tools (`add-atomic-heading`, `add-atomic-paragraph`,
`add-atomic-button`) and the bare `add-atomic-widget` set **content only** —
`title/tag/link/css_id`, no styling. A live POC building an atomic homepage
confirmed every atomic widget renders with default styles (dark heading on a dark
background = invisible). `add-flexbox` already accepts styling and writes a
`styles` map via `Elementor_MCP_Atomic_Styles`; widgets have no equivalent path.

So atomic-via-MCP is not usable for real pages: you can place the structure and
text, but cannot style any widget.

## Goal

Give the text atomic widgets the same styling capability `add-flexbox` already
has — including **typography**, which is the highest-value gap for text — by
reusing the existing `create_flexbox` styling flow.

## Scope

- **Widgets:** `add-atomic-heading`, `add-atomic-paragraph`, `add-atomic-button`
  get full style + typography props. The bare `add-atomic-widget` gets an optional
  `style_props` passthrough.
- **Out (YAGNI):** `add-atomic-svg/image/divider/video/youtube` — non-text, add
  later if a real need appears.
- **Ship:** Digitizers fork main → reinstall on SoftLab → upstream PR to msrbuilds.

## Design

Mirror the proven `create_flexbox` path. Three layers:

### 1. `Elementor_MCP_Atomic_Styles::build_typography_props( array $params ): array`

New static method. `build_common_props` already covers color, background_color,
padding, margin_top/bottom, width, min_height, border_radius — but **no
typography**. Add a sibling that maps:

| input key | CSS prop | wrapper |
|---|---|---|
| `font_size` (+ `font_size_unit`, default `px`) | `font-size` | `Atomic_Props::size` |
| `font_family` | `font-family` | `Atomic_Props::string` |
| `font_weight` | `font-weight` | `Atomic_Props::string` |
| `line_height` (+ `line_height_unit`, default `em`) | `line-height` | `Atomic_Props::size` |
| `letter_spacing` (+ `letter_spacing_unit`, default `px`) | `letter-spacing` | `Atomic_Props::size` |
| `text_align` | `text-align` | `Atomic_Props::string` |

Only keys present in `$params` produce props (same convention as
`build_common_props`). Unknown keys ignored.

### 2. `Elementor_MCP_Element_Factory::create_atomic_widget( string $widget_type, array $settings = array(), array $style_props = array() ): array`

Add the third `$style_props` param (default `[]` → fully backward compatible).
When non-empty, mirror `create_flexbox`:

```php
$common_css = Elementor_MCP_Atomic_Styles::build_common_props( $style_props );
$typo_css   = Elementor_MCP_Atomic_Styles::build_typography_props( $style_props );
$all_css    = array_merge( $common_css, $typo_css );
if ( ! empty( $all_css ) ) {
    $id    = /* same local-class id source create_flexbox uses */;
    $style = Elementor_MCP_Atomic_Styles::create_local_class( $id, $all_css );
    Elementor_MCP_Atomic_Styles::apply_to_element( $element, $style['class_id'], $style['style_def'] );
}
```

(Read `create_flexbox` for the exact `$id` source and ordering; copy it.)

### 3. Abilities — collect style keys → pass `$style_props`

In `execute_add_atomic_heading/paragraph/button`: after building content
`$settings`, collect a `$style_keys` allow-list from `$input` into `$style_params`
(same loop shape as `execute_add_flexbox`), then call
`create_atomic_widget( $type, $settings, $style_params )`. Allow-list:

```
font_size, font_size_unit, font_family, font_weight, line_height,
line_height_unit, letter_spacing, letter_spacing_unit, text_align,
color, background_color, padding, padding_unit, padding_top, padding_right,
padding_bottom, padding_left, padding_*_unit, margin_top, margin_bottom,
width, width_unit, min_height, min_height_unit, border_radius, border_radius_unit
```

Extend each tool's `input_schema.properties` with these (typed `string`/`number`)
plus short descriptions, so agents discover them.

For the bare `execute_add_atomic_widget`: read an optional `style_props` object
from `$input` and pass it straight through to `create_atomic_widget`. Add
`style_props` (`type: object`) to its `input_schema`.

## Data flow

`add-atomic-heading {title, font_size, color, ...}`
→ ability splits content settings vs style_params
→ `create_atomic_widget('e-heading', $settings, $style_params)`
→ `build_common_props` + `build_typography_props` → `create_local_class` →
`apply_to_element` (adds class to `settings.classes` + def to `styles` map)
→ element inserted + saved.

## Error handling

- Unknown/empty style keys → no props (silent, matches existing convention).
- No style props at all → no styles map, identical to today (backward compatible).
- Invalid numeric values → `(float)` cast as `build_common_props` already does.

## Testing

- **Unit** (`build_typography_props`): each input key → correct CSS prop + wrapper
  type; units honored; absent keys omitted; empty input → `[]`.
- **Functional** (abilities): heading/paragraph/button with style props →
  returned/saved element has a non-empty `styles` map and a `classes` entry in
  settings; with no style props → no styles map (regression guard for backward
  compat). Reuse the existing functional harness + data stub.
- Full suite stays green (pre-existing 18err/15fail unrelated baseline unchanged).

## Out of scope / follow-ups

- Styling for svg/image/divider/video/youtube.
- Responsive (breakpoint-specific) styles — atomic supports them but the MCP
  styling path is desktop-only today; note, don't build.
- Global-class reuse (these are local classes per element, as `create_flexbox`
  already does).
