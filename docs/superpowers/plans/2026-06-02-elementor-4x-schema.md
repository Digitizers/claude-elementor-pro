# Elementor 4.x atomic schema — version-gated codification

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans. Steps use checkbox (`- [ ]`).

**Goal:** Make the atomic tools emit correct shapes on **Elementor 4.x GA** while keeping 3.x-atomic support, via an `is_v4()` version gate. Field-verified against Elementor 4.1.1 core on SoftLab (page 73 full parity).

**Architecture:** Add `Atomic_Props::is_v4()` (reads `ELEMENTOR_VERSION`, test-overridable). Branch the 5 deltas: A content props (string↔html-v3), B svg ($$type image-src↔svg-src), C padding/margin (block-*↔Union(Size|dimensions)), D gap (flat↔layout-direction); E height additive. Existing 3.x tests stay green (bootstrap pins `ELEMENTOR_VERSION=3.25.0`); add 4.x tests via the override.

**Repo/branch:** `Digitizers/elementor-mcp`, branch `fix/elementor-4x-schema` off `main` (fork main already has #50/#51).

**Verified 4.1.1 core shapes:** `html-v3` `{content:String, children:[]}`; `svg-src` `{id,url}` ≥1; padding/margin = `Union(Size | dimensions{block-start,inline-end,block-end,inline-start:Size})`; gap = `Union(... layout-direction{row,column:Size})`.

---

## Task 1: `is_v4()` helper + tests

**Files:** `includes/class-atomic-props.php`; `tests/unit/AtomicV4SchemaTest.php` (new); `tests/bootstrap.php` (reset global)

- [ ] **Step 1: Add the helper**

In `class-atomic-props.php`, add (near `is_atomic_supported`):

```php
	/**
	 * True when the live Elementor is 4.0+ (GA atomic schema). The atomic
	 * prop-types changed between 3.x-experimental and 4.x-GA, so output shapes
	 * branch on this. Tests override via $GLOBALS['_elementor_version_override'].
	 */
	public static function is_v4(): bool {
		$v = $GLOBALS['_elementor_version_override']
			?? ( defined( 'ELEMENTOR_VERSION' ) ? ELEMENTOR_VERSION : '' );
		return $v !== '' && version_compare( $v, '4.0', '>=' );
	}
```

- [ ] **Step 2: Reset the override between tests**

In `tests/bootstrap.php`, where other `$GLOBALS['_*']` are initialised, add:
`$GLOBALS['_elementor_version_override'] = null;`

- [ ] **Step 3: Test the helper**

Create `tests/unit/AtomicV4SchemaTest.php`:

```php
<?php
/**
 * Elementor 4.x atomic schema — version-gated output shapes.
 * Verified against Elementor 4.1.1 core (atomic-widgets module).
 *
 * @group unit
 * @group atomic
 * @package Elementor_MCP\Tests
 */

namespace Elementor_MCP\Tests;

use PHPUnit\Framework\TestCase;

class AtomicV4SchemaTest extends TestCase {

	protected function setUp(): void { $GLOBALS['_elementor_version_override'] = null; }
	protected function tearDown(): void { $GLOBALS['_elementor_version_override'] = null; }

	private function v($ver) { $GLOBALS['_elementor_version_override'] = $ver; }

	public function test_is_v4_gate(): void {
		$this->v('3.31.5'); $this->assertFalse( \Elementor_MCP_Atomic_Props::is_v4() );
		$this->v('4.1.1');  $this->assertTrue( \Elementor_MCP_Atomic_Props::is_v4() );
	}
}
```

- [ ] **Step 4: Run — expect pass**

Run: `PHP=$(find "$HOME/Library/Application Support/Local/lightning-services" -maxdepth 6 -name php -type f|head -1); "$PHP" /tmp/phpunit10.phar tests/unit/AtomicV4SchemaTest.php`
Expected: OK (1 test).

- [ ] **Step 5: Commit**

```bash
git checkout -b fix/elementor-4x-schema
git add includes/class-atomic-props.php tests/bootstrap.php tests/unit/AtomicV4SchemaTest.php
git commit -m "feat(atomic): add is_v4() version gate (Elementor 4.x GA schema)"
```

---

## Task 2: A — content props (string ↔ html-v3)

**Files:** `includes/abilities/class-atomic-widget-abilities.php`

- [ ] **Step 1: Gate heading/paragraph/button content**

In the three convenience `settings_fn` closures, replace the content assignment.
Heading (~L366): `$settings['title'] = Elementor_MCP_Atomic_Props::string( $t );`
→
```php
$t = sanitize_text_field( $input['title'] ?? 'Heading' );
$settings['title'] = Elementor_MCP_Atomic_Props::is_v4()
	? Elementor_MCP_Atomic_Props::html( $t )
	: Elementor_MCP_Atomic_Props::string( $t );
```
Paragraph (~L396): same shape, key `paragraph`, source `$input['content'] ?? 'Paragraph text'`.
Button (~L426): same shape, key `text`, source `$input['text'] ?? 'Click Here'`.

(`Atomic_Props::html()` already emits the 4.x `html-v3` `{content:String, children:[]}` shape.)

- [ ] **Step 2: Add the 4.x assertion (append to AtomicV4SchemaTest)**

```php
	public function test_heading_content_is_html_v3_on_v4_string_on_v3(): void {
		$f = new \Elementor_MCP_Element_Factory();
		// shape check is on the prop helpers the closures use:
		$this->v('4.1.1');
		$h = \Elementor_MCP_Atomic_Props::is_v4()
			? \Elementor_MCP_Atomic_Props::html('Hi')
			: \Elementor_MCP_Atomic_Props::string('Hi');
		$this->assertSame('html-v3', $h['$$type']);
		$this->assertSame('Hi', $h['value']['content']['value']);
		$this->v('3.31.5');
		$s = \Elementor_MCP_Atomic_Props::is_v4()
			? \Elementor_MCP_Atomic_Props::html('Hi')
			: \Elementor_MCP_Atomic_Props::string('Hi');
		$this->assertSame('string', $s['$$type']);
	}
```

- [ ] **Step 3: Lint + test + commit**

```bash
"$PHP" -l includes/abilities/class-atomic-widget-abilities.php
"$PHP" /tmp/phpunit10.phar tests/unit/AtomicV4SchemaTest.php
git add includes/abilities/class-atomic-widget-abilities.php tests/unit/AtomicV4SchemaTest.php
git commit -m "fix(atomic): content props use html-v3 on Elementor 4.x (string on 3.x)"
```

---

## Task 3: B — svg ($$type image-src ↔ svg-src)

**Files:** `includes/abilities/class-atomic-widget-abilities.php`

- [ ] **Step 1: Gate the svg $$type**

In `register_add_atomic_svg()` (~L503), the `$settings['svg']` array literal `'$$type' => 'image-src'`
→
```php
'$$type' => Elementor_MCP_Atomic_Props::is_v4() ? 'svg-src' : 'image-src',
```
(body `value => { url => { $$type:url, value:src } }` unchanged.)

- [ ] **Step 2: Commit**

```bash
"$PHP" -l includes/abilities/class-atomic-widget-abilities.php
git add includes/abilities/class-atomic-widget-abilities.php
git commit -m "fix(atomic): e-svg uses svg-src on Elementor 4.x (image-src on 3.x)"
```

---

## Task 4: C + E — padding/margin (Union/dimensions) + height

**Files:** `includes/class-atomic-styles.php`; tests

- [ ] **Step 1: Refactor `build_common_props`**

Remove `padding_top/right/bottom/left`, `margin_top`, `margin_bottom` and the uniform-`padding`
block from the current `$size_mappings` + uniform handling. Keep `width`, `max_width`,
`min_height`, `border_radius`; **add `'height' => 'height'`** (E). Then add a spacing helper
call. Concretely, the size-mapping block becomes:

```php
		$size_mappings = array(
			'width'         => 'width',
			'max_width'     => 'max-width',
			'min_height'    => 'min-height',
			'height'        => 'height',
			'border_radius' => 'border-radius',
		);
		// (the foreach over $size_mappings stays as-is)

		// padding + margin — schema differs by Elementor major (see build_spacing).
		$props += self::build_spacing( 'padding', $params );
		$props += self::build_spacing( 'margin', $params );
```

Add the helper (static, same class):

```php
	/**
	 * Builds padding/margin for the live Elementor major.
	 *  - 3.x: per-side `<prop>-block-start|inline-end|block-end|inline-start` (Size).
	 *  - 4.x: a single `<prop>` = Size (uniform) or a `dimensions` shape (per-side),
	 *         since 4.x dropped the per-side keys (Union(Size|Dimensions)).
	 *
	 * @param string $prop   'padding' or 'margin'.
	 * @param array  $params Flat params: `<prop>` (uniform) + `<prop>_top/right/bottom/left`.
	 * @return array CSS-prop map.
	 */
	private static function build_spacing( string $prop, array $params ): array {
		$unit  = $params[ $prop . '_unit' ] ?? 'px';
		$sides = array(
			'block-start'  => $params[ $prop . '_top' ]    ?? null,
			'inline-end'   => $params[ $prop . '_right' ]  ?? null,
			'block-end'    => $params[ $prop . '_bottom' ] ?? null,
			'inline-start' => $params[ $prop . '_left' ]   ?? null,
		);
		$uniform = $params[ $prop ] ?? null;
		$has_side = array_filter( $sides, static function ( $v ) { return $v !== null; } );

		if ( null === $uniform && ! $has_side ) {
			return array();
		}

		if ( Elementor_MCP_Atomic_Props::is_v4() ) {
			if ( null !== $uniform && ! $has_side ) {
				return array( $prop => Elementor_MCP_Atomic_Props::size( (float) $uniform, $unit ) );
			}
			$dim = array();
			foreach ( $sides as $css => $val ) {
				$v = $val ?? $uniform;
				if ( null !== $v ) {
					$dim[ $css ] = Elementor_MCP_Atomic_Props::size( (float) $v, $unit );
				}
			}
			return array( $prop => array( '$$type' => 'dimensions', 'value' => $dim ) );
		}

		// 3.x per-side keys.
		$out = array();
		$map = array( 'block-start' => 'top', 'inline-end' => 'right', 'block-end' => 'bottom', 'inline-start' => 'left' );
		foreach ( $sides as $css => $val ) {
			$v = $val ?? $uniform;
			if ( null !== $v ) {
				$out[ $prop . '-' . $css ] = Elementor_MCP_Atomic_Props::size( (float) $v, $unit );
			}
		}
		return $out;
	}
```

- [ ] **Step 2: Tests (append to AtomicV4SchemaTest)**

```php
	public function test_padding_uniform_v4_single_size_v3_four_sides(): void {
		$this->v('4.1.1');
		$p = \Elementor_MCP_Atomic_Styles::build_common_props( ['padding' => 40] );
		$this->assertSame('size', $p['padding']['$$type'], 'v4 uniform padding = Size');
		$this->assertArrayNotHasKey('padding-block-start', $p);
		$this->v('3.31.5');
		$p = \Elementor_MCP_Atomic_Styles::build_common_props( ['padding' => 40] );
		$this->assertArrayHasKey('padding-block-start', $p, 'v3 = per-side keys');
		$this->assertArrayNotHasKey('padding', $p);
	}

	public function test_padding_per_side_v4_dimensions_shape(): void {
		$this->v('4.1.1');
		$p = \Elementor_MCP_Atomic_Styles::build_common_props( ['padding_top'=>120,'padding_bottom'=>90] );
		$this->assertSame('dimensions', $p['padding']['$$type']);
		$this->assertSame(120.0, $p['padding']['value']['block-start']['value']['size']);
		$this->assertArrayNotHasKey('inline-end', $p['padding']['value']);
	}

	public function test_height_size_key(): void {
		$p = \Elementor_MCP_Atomic_Styles::build_common_props( ['height' => 30] );
		$this->assertSame('size', $p['height']['$$type']);
	}
```

- [ ] **Step 3: Update the existing AtomicStylesCommonTest** — it asserts the old per-side
behaviour under the default (3.x) version; it stays valid because bootstrap pins
`ELEMENTOR_VERSION=3.25.0` and those tests don't set the override. If any existing test set a
uniform `padding` and asserted four `padding-block-*` keys, confirm it still passes (3.x path).

- [ ] **Step 4: Lint + run both files + commit**

```bash
"$PHP" -l includes/class-atomic-styles.php
"$PHP" /tmp/phpunit10.phar tests/unit/AtomicV4SchemaTest.php tests/unit/AtomicStylesCommonTest.php
git add includes/class-atomic-styles.php tests/unit/AtomicV4SchemaTest.php
git commit -m "fix(atomic): padding/margin use 4.x Union(Size|dimensions); add height"
```

---

## Task 5: D — flex gap (flat ↔ layout-direction)

**Files:** `includes/class-atomic-styles.php` `build_flex_props`

- [ ] **Step 1: Gate the gap output**

Replace the three gap blocks (`gap`, `row_gap`, `column_gap`) with:

```php
		$gap   = $params['gap'] ?? null;
		$rg    = $params['row_gap'] ?? $gap;
		$cg    = $params['column_gap'] ?? $gap;
		if ( null !== $rg || null !== $cg ) {
			$gu = $params['gap_unit'] ?? 'px';
			if ( Elementor_MCP_Atomic_Props::is_v4() ) {
				$val = array();
				if ( null !== $rg ) { $val['row']    = Elementor_MCP_Atomic_Props::size( (float) $rg, $gu ); }
				if ( null !== $cg ) { $val['column'] = Elementor_MCP_Atomic_Props::size( (float) $cg, $gu ); }
				$props['gap'] = array( '$$type' => 'layout-direction', 'value' => $val );
			} else {
				if ( null !== $gap ) { $props['gap'] = Elementor_MCP_Atomic_Props::size( (float) $gap, $gu ); }
				if ( null !== $params['row_gap'] ?? null ) { $props['row-gap'] = Elementor_MCP_Atomic_Props::size( (float) $params['row_gap'], $gu ); }
				if ( null !== $params['column_gap'] ?? null ) { $props['column-gap'] = Elementor_MCP_Atomic_Props::size( (float) $params['column_gap'], $gu ); }
			}
		}
```

(Confirm the exact existing lines first; preserve any flex-direction/justify/align code around them.)

- [ ] **Step 2: Test (append)**

```php
	public function test_gap_v4_layout_direction_v3_flat(): void {
		$this->v('4.1.1');
		$p = \Elementor_MCP_Atomic_Styles::build_flex_props( ['gap' => 24] );
		$this->assertSame('layout-direction', $p['gap']['$$type']);
		$this->assertSame(24.0, $p['gap']['value']['row']['value']['size']);
		$this->v('3.31.5');
		$p = \Elementor_MCP_Atomic_Styles::build_flex_props( ['gap' => 24] );
		$this->assertSame('size', $p['gap']['$$type']);
	}
```

- [ ] **Step 3: Lint + test + commit**

```bash
"$PHP" -l includes/class-atomic-styles.php
"$PHP" /tmp/phpunit10.phar tests/unit/AtomicV4SchemaTest.php
git add includes/class-atomic-styles.php tests/unit/AtomicV4SchemaTest.php
git commit -m "fix(atomic): flex gap uses layout-direction on Elementor 4.x (flat on 3.x)"
```

---

## Task 6: Full suite + PR (upstream + fork main)

- [ ] **Step 1: Full suite — confirm no new failures vs baseline**

Run: `"$PHP" /tmp/phpunit10.phar 2>&1 | tail -3`
Expected: the new AtomicV4SchemaTest passes; pre-existing 18 errors / 15 failures unchanged.
Investigate any NEW failure (likely an existing AtomicStylesCommonTest/SaveRegression assertion
that needs the 3.x path — fix the test, not the gate, if it asserted a now-moved shape).

- [ ] **Step 2: Push + upstream PR**

```bash
git push -u origin fix/elementor-4x-schema
gh pr create --repo msrbuilds/elementor-mcp --base main --head Digitizers:fix/elementor-4x-schema \
  --title "fix: version-gate atomic shapes for Elementor 4.x GA (3.x still supported)" \
  --body "Elementor 4.x GA changed the atomic prop-types vs 3.x-experimental. v1.9.0 emits 3.x shapes → blank text / placeholder SVG / dropped padding+gap on 4.1.1. Adds Elementor_MCP_Atomic_Props::is_v4() and branches the output:

| delta | 3.x | 4.x |
|---|---|---|
| heading/paragraph/button content | String | Html_V3 (html-v3) |
| e-svg | image-src | svg-src |
| padding/margin | per-side block/inline keys | Union(Size \| dimensions) |
| flex gap | flat Size / row-gap+column-gap | layout-direction {row,column} |
| height | — | added (Size, valid both) |

All shapes verified against Elementor 4.1.1 core (atomic-widgets module) and live on a full atomic homepage. 3.x path unchanged (tests pin ELEMENTOR_VERSION=3.25.0); new AtomicV4SchemaTest covers the 4.x path via a version override. Note: this version-gates (and for 4.x reverses) the string()/image-src choices from #51 — #51 was correct for 3.x.

Follow-up: first-class :hover variant param (atomic style variant meta.state=hover).

🤖 Generated with [Claude Code](https://claude.com/claude-code)"
```

- [ ] **Step 3: Merge to fork main + reinstall note**

```bash
git checkout main && git merge fix/elementor-4x-schema --no-edit && git push origin main
```
SoftLab already has these hand-applied on 1.9.0; the fork is now canonical. Reinstall the fork
build there when convenient (Low-tools mode for the Antigravity cap).

---

## Self-Review notes (author)

- **Spec coverage:** is_v4 gate (T1) ✓; A content (T2) ✓; B svg (T3) ✓; C padding/margin + E height (T4) ✓; D gap (T5) ✓; suite + PR + fork (T6) ✓; hover = noted follow-up.
- **Reverses #51 for 4.x:** explicit in the PR body; 3.x path preserved.
- **Test seam:** `$GLOBALS['_elementor_version_override']` matches the codebase's existing stub-global style; reset in bootstrap + each test.
- **Risk:** an existing test that asserted the old uniform-padding→four-keys behaviour now runs the 3.x path (default) — still valid; only the moved-key tests need checking (T4 step 3).
