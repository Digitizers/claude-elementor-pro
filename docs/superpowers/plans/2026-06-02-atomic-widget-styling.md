# Atomic Widget Styling Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the text atomic widgets (`add-atomic-heading/paragraph/button`) and the bare `add-atomic-widget` styling + typography props, written into the element `styles` map, by reusing the `create_flexbox` styling flow.

**Architecture:** Add `Atomic_Styles::build_typography_props()`; add a `$style_props` param to `create_atomic_widget()` that builds common+typography CSS and applies a local style class (exactly like `create_flexbox`); have the three text abilities collect a style allow-list from input and the bare tool pass a `style_props` object through; expose the props in each `input_schema`.

**Tech Stack:** PHP 8.2, PHPUnit 10 (phar at `/tmp/phpunit10.phar`), WordPress plugin in `/Users/digitizer/Documents/GitHub/elementor-mcp`.

**Repo / branch:** `msrbuilds/elementor-mcp` via the Digitizers fork at `/Users/digitizer/Documents/GitHub/elementor-mcp`. Create branch `feat/atomic-widget-styling` off `main`.

**Run tests:** `PHP=$(find "$HOME/Library/Application Support/Local/lightning-services" -maxdepth 6 -name php -type f | head -1); "$PHP" /tmp/phpunit10.phar --filter <Name>`

---

## File Structure

- **Modify** `includes/class-atomic-styles.php` — add `build_typography_props()`.
- **Modify** `includes/class-element-factory.php` — `create_atomic_widget()` gains `$style_props`.
- **Modify** `includes/abilities/class-atomic-widget-abilities.php` — heading/paragraph/button collect style keys; bare `add-atomic-widget` passes `style_props`; input schemas extended.
- **Create** `tests/unit/AtomicStylesTypographyTest.php` — unit tests for `build_typography_props`.
- **Create** `tests/unit/functional/AtomicWidgetStyleFunctionalTest.php` — abilities produce a `styles` map.

---

## Task 0: Branch

- [ ] **Step 1: Create the branch off synced main**

```bash
cd /Users/digitizer/Documents/GitHub/elementor-mcp
git checkout main && git pull --ff-only
git checkout -b feat/atomic-widget-styling
```

---

## Task 1: `build_typography_props()`

**Files:**
- Modify: `includes/class-atomic-styles.php`
- Test: `tests/unit/AtomicStylesTypographyTest.php`

- [ ] **Step 1: Write the failing test**

Create `tests/unit/AtomicStylesTypographyTest.php`:

```php
<?php
/**
 * Unit tests — Atomic_Styles::build_typography_props().
 *
 * @group unit
 * @group atomic
 * @package Elementor_MCP\Tests
 */

namespace Elementor_MCP\Tests;

use PHPUnit\Framework\TestCase;

class AtomicStylesTypographyTest extends TestCase {

	public function test_empty_params_produce_no_props(): void {
		$this->assertSame( [], \Elementor_MCP_Atomic_Styles::build_typography_props( [] ) );
	}

	public function test_font_size_maps_to_size_prop_with_default_px(): void {
		$props = \Elementor_MCP_Atomic_Styles::build_typography_props( [ 'font_size' => 32 ] );
		$this->assertArrayHasKey( 'font-size', $props );
		$this->assertSame( 'size', $props['font-size']['$$type'] );
		$this->assertSame( 32.0, $props['font-size']['value']['size'] );
		$this->assertSame( 'px', $props['font-size']['value']['unit'] );
	}

	public function test_font_size_honors_explicit_unit(): void {
		$props = \Elementor_MCP_Atomic_Styles::build_typography_props( [ 'font_size' => 2, 'font_size_unit' => 'rem' ] );
		$this->assertSame( 'rem', $props['font-size']['value']['unit'] );
	}

	public function test_line_height_defaults_to_em(): void {
		$props = \Elementor_MCP_Atomic_Styles::build_typography_props( [ 'line_height' => 1.4 ] );
		$this->assertSame( 'line-height', array_key_first( $props ) );
		$this->assertSame( 'em', $props['line-height']['value']['unit'] );
	}

	public function test_letter_spacing_defaults_to_px(): void {
		$props = \Elementor_MCP_Atomic_Styles::build_typography_props( [ 'letter_spacing' => 1 ] );
		$this->assertSame( 'px', $props['letter-spacing']['value']['unit'] );
	}

	public function test_string_props_map_to_string_type(): void {
		$props = \Elementor_MCP_Atomic_Styles::build_typography_props( [
			'font_family' => 'Rubik',
			'font_weight' => '700',
			'text_align'  => 'center',
		] );
		$this->assertSame( 'string', $props['font-family']['$$type'] );
		$this->assertSame( 'Rubik', $props['font-family']['value'] );
		$this->assertSame( '700', $props['font-weight']['value'] );
		$this->assertSame( 'center', $props['text-align']['value'] );
	}

	public function test_unknown_keys_ignored(): void {
		$props = \Elementor_MCP_Atomic_Styles::build_typography_props( [ 'nonsense' => 1, 'color' => '#fff' ] );
		$this->assertSame( [], $props );
	}
}
```

- [ ] **Step 2: Run it — expect failure (method missing)**

Run: `"$PHP" /tmp/phpunit10.phar --filter AtomicStylesTypographyTest`
Expected: errors — `Call to undefined method ...::build_typography_props()`.

- [ ] **Step 3: Implement `build_typography_props()`**

In `includes/class-atomic-styles.php`, immediately after the `build_common_props()` method (after its closing `}`, before `apply_to_element`'s docblock), insert:

```php
	/**
	 * Builds typography CSS props from flat params.
	 *
	 * Sibling to build_common_props() — covers the text-styling props that
	 * one (color/spacing) does not. Only keys present in $params produce
	 * output; unknown keys are ignored.
	 *
	 * @param array $params Flat typography params.
	 * @return array Map of CSS prop name => $$type-wrapped value.
	 */
	public static function build_typography_props( array $params ): array {
		$props = array();

		// size-typed props: input key => [ css prop, default unit ].
		$size_props = array(
			'font_size'      => array( 'font-size', 'px' ),
			'line_height'    => array( 'line-height', 'em' ),
			'letter_spacing' => array( 'letter-spacing', 'px' ),
		);
		foreach ( $size_props as $input_key => $meta ) {
			if ( isset( $params[ $input_key ] ) ) {
				$unit                  = $params[ $input_key . '_unit' ] ?? $meta[1];
				$props[ $meta[0] ]     = Elementor_MCP_Atomic_Props::size( (float) $params[ $input_key ], $unit );
			}
		}

		// string-typed props: input key => css prop.
		$string_props = array(
			'font_family' => 'font-family',
			'font_weight' => 'font-weight',
			'text_align'  => 'text-align',
		);
		foreach ( $string_props as $input_key => $css_prop ) {
			if ( isset( $params[ $input_key ] ) ) {
				$props[ $css_prop ] = Elementor_MCP_Atomic_Props::string( (string) $params[ $input_key ] );
			}
		}

		return $props;
	}
```

- [ ] **Step 4: Run — expect pass**

Run: `"$PHP" /tmp/phpunit10.phar --filter AtomicStylesTypographyTest`
Expected: `OK (7 tests, ...)`.

Note: the test references `Elementor_MCP_Atomic_Styles`. Confirm it is in the test autoload map (`tests/bootstrap.php`) — it was added in the atomic-save fix. If not present, add `'Elementor_MCP_Atomic_Styles' => 'includes/class-atomic-styles.php',`.

- [ ] **Step 5: Commit**

```bash
git add includes/class-atomic-styles.php tests/unit/AtomicStylesTypographyTest.php
git commit -m "feat(atomic): add Atomic_Styles::build_typography_props()

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 2: `create_atomic_widget()` applies style props

**Files:**
- Modify: `includes/class-element-factory.php:188-205` (`create_atomic_widget`)
- Test: `tests/unit/functional/AtomicWidgetStyleFunctionalTest.php`

- [ ] **Step 1: Write the failing test**

Create `tests/unit/functional/AtomicWidgetStyleFunctionalTest.php`:

```php
<?php
/**
 * Functional — atomic widgets carry a styles map when style props are passed.
 *
 * @group functional
 * @group atomic
 * @package Elementor_MCP\Tests\Functional
 */

namespace Elementor_MCP\Tests\Functional;

require_once dirname( __DIR__ ) . '/class-ability-test-case.php';

use Elementor_MCP\Tests\Ability_Test_Case;

class AtomicWidgetStyleFunctionalTest extends Ability_Test_Case {

	public function test_factory_widget_without_style_props_has_empty_styles(): void {
		$el = $this->make_factory()->create_atomic_widget( 'e-heading', array() );
		$this->assertSame( array(), $el['styles'] );
	}

	public function test_factory_widget_with_style_props_populates_styles_and_classes(): void {
		$el = $this->make_factory()->create_atomic_widget(
			'e-heading',
			array(),
			array( 'color' => '#112233', 'font_size' => 40 )
		);
		$this->assertNotEmpty( $el['styles'], 'styles map should be populated' );
		// apply_to_element adds the local class id to settings.classes.
		$this->assertArrayHasKey( 'classes', $el['settings'] );
		$this->assertNotEmpty( $el['settings']['classes']['value'] );
	}
}
```

- [ ] **Step 2: Run — expect failure**

Run: `"$PHP" /tmp/phpunit10.phar --filter AtomicWidgetStyleFunctionalTest`
Expected: `test_factory_widget_with_style_props_...` errors — `create_atomic_widget()` takes 2 args / styles stays empty.

- [ ] **Step 3: Implement the `$style_props` param**

Replace `create_atomic_widget()` in `includes/class-element-factory.php` (currently lines 188–205) with:

```php
	public function create_atomic_widget( string $widget_type, array $settings = array(), array $style_props = array() ): array {
		$id = Elementor_MCP_Id_Generator::generate();

		if ( ! isset( $settings['classes'] ) ) {
			$settings['classes'] = Elementor_MCP_Atomic_Props::classes();
		}

		$element = array(
			'id'              => $id,
			'elType'          => 'widget',
			'widgetType'      => $widget_type,
			'isInner'         => false,
			'settings'        => $settings,
			'elements'        => array(),
			'styles'          => array(),
			'interactions'    => array(),
			'editor_settings' => array(),
			'version'         => defined( 'ELEMENTOR_VERSION' ) ? ELEMENTOR_VERSION : '',
		);

		// Build and apply widget styles if provided (mirrors create_flexbox).
		$common_css = Elementor_MCP_Atomic_Styles::build_common_props( $style_props );
		$typo_css   = Elementor_MCP_Atomic_Styles::build_typography_props( $style_props );
		$all_css    = array_merge( $common_css, $typo_css );

		if ( ! empty( $all_css ) ) {
			$style = Elementor_MCP_Atomic_Styles::create_local_class( $id, $all_css );
			Elementor_MCP_Atomic_Styles::apply_to_element( $element, $style['class_id'], $style['style_def'] );
		}

		return $element;
	}
```

- [ ] **Step 4: Run — expect pass**

Run: `"$PHP" /tmp/phpunit10.phar --filter AtomicWidgetStyleFunctionalTest`
Expected: `OK (2 tests, ...)`.

- [ ] **Step 5: Commit**

```bash
git add includes/class-element-factory.php tests/unit/functional/AtomicWidgetStyleFunctionalTest.php
git commit -m "feat(atomic): create_atomic_widget() applies a local style class from style props

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 3: Abilities collect style props + schema

**Files:**
- Modify: `includes/abilities/class-atomic-widget-abilities.php`
- Test: extend `tests/unit/functional/AtomicWidgetStyleFunctionalTest.php`

First read the three convenience executors (heading ~320, paragraph ~350, button ~380) and `execute_add_atomic_widget` (~133) to confirm exact lines. The edits below are content-anchored.

- [ ] **Step 1: Write the failing ability test (append to the functional test)**

Append these methods inside `AtomicWidgetStyleFunctionalTest` (before the closing `}`):

```php
	private function ability(): \Elementor_MCP_Atomic_Widget_Abilities {
		// Data stub: empty page, save succeeds. insert_element runs real (top-level append).
		$data = new class extends \Elementor_MCP_Data {
			public function __construct() {}
			public function get_page_data( int $post_id ): array { return array(); }
			public function save_page_data( int $post_id, array $data ): bool {
				$GLOBALS['_saved_page'] = $data; // capture for assertions
				return true;
			}
		};
		return new \Elementor_MCP_Atomic_Widget_Abilities( $data, $this->make_factory() );
	}

	public function test_add_atomic_heading_with_typography_writes_styles(): void {
		$GLOBALS['_saved_page'] = null;
		$res = $this->ability()->execute_add_atomic_heading( array(
			'post_id'   => 7,
			'title'     => 'Hi',
			'font_size' => 48,
			'color'     => '#0a0a0a',
		) );
		$this->assertNotWPError( $res );
		$saved = $GLOBALS['_saved_page'];
		$this->assertNotEmpty( $saved[0]['styles'], 'heading element should have a styles map' );
	}

	public function test_add_atomic_widget_passthrough_style_props_writes_styles(): void {
		$GLOBALS['_saved_page'] = null;
		$res = $this->ability()->execute_add_atomic_widget( array(
			'post_id'     => 7,
			'widget_type' => 'e-heading',
			'settings'    => array(),
			'style_props' => array( 'color' => '#fff', 'font_size' => 20 ),
		) );
		$this->assertNotWPError( $res );
		$this->assertNotEmpty( $GLOBALS['_saved_page'][0]['styles'] );
	}
```

- [ ] **Step 2: Run — expect failure**

Run: `"$PHP" /tmp/phpunit10.phar --filter AtomicWidgetStyleFunctionalTest`
Expected: the two new tests fail — styles map empty (abilities don't forward style props yet).

- [ ] **Step 3: Add a shared style-key collector + wire the three text tools**

In `class-atomic-widget-abilities.php`, add a private helper (place it just below the class's `__construct`):

```php
	/**
	 * Extracts the atomic styling allow-list from a tool input array.
	 *
	 * @param array $input Raw tool input.
	 * @return array Flat style params for create_atomic_widget()'s 3rd arg.
	 */
	private function collect_style_props( array $input ): array {
		$keys = array(
			// typography
			'font_size', 'font_size_unit', 'font_family', 'font_weight',
			'line_height', 'line_height_unit', 'letter_spacing', 'letter_spacing_unit', 'text_align',
			// common
			'color', 'background_color',
			'padding', 'padding_unit', 'padding_top', 'padding_right', 'padding_bottom', 'padding_left',
			'margin_top', 'margin_bottom', 'width', 'width_unit', 'min_height', 'min_height_unit',
			'border_radius', 'border_radius_unit',
		);
		$out = array();
		foreach ( $keys as $k ) {
			if ( isset( $input[ $k ] ) ) {
				$out[ $k ] = $input[ $k ];
			}
		}
		return $out;
	}
```

Then in each of `execute_add_atomic_heading`, `execute_add_atomic_paragraph`, `execute_add_atomic_button`, find the `create_atomic_widget(` call (it currently passes `( $type, $settings )`) and add the third arg. Example for heading — change:

```php
		$element = $this->factory->create_atomic_widget( 'e-heading', $settings );
```

to:

```php
		$element = $this->factory->create_atomic_widget( 'e-heading', $settings, $this->collect_style_props( $input ) );
```

Apply the same one-line change to the paragraph (`'e-paragraph'`) and button (`'e-button'`) executors. (Confirm the exact widget-type literal each uses while editing.)

- [ ] **Step 4: Wire the bare `execute_add_atomic_widget` passthrough**

In `execute_add_atomic_widget`, find:

```php
		$element = $this->factory->create_atomic_widget( $widget_type, $settings );
```

Replace with:

```php
		$style_props = isset( $input['style_props'] ) && is_array( $input['style_props'] ) ? $input['style_props'] : array();
		$element     = $this->factory->create_atomic_widget( $widget_type, $settings, $style_props );
```

- [ ] **Step 5: Run — expect pass**

Run: `"$PHP" /tmp/phpunit10.phar --filter AtomicWidgetStyleFunctionalTest`
Expected: `OK (4 tests, ...)`.

- [ ] **Step 6: Extend the `input_schema` for the four tools**

For `add-atomic-heading`, `add-atomic-paragraph`, `add-atomic-button`: in each registration's `input_schema.properties`, add (alongside the existing `title`/`content`/`text`, `link`, `css_id`):

```php
						'font_size'        => array( 'type' => 'number', 'description' => __( 'Font size value.', 'elementor-mcp' ) ),
						'font_size_unit'   => array( 'type' => 'string', 'description' => __( 'Font size unit (px, em, rem). Default px.', 'elementor-mcp' ) ),
						'font_family'      => array( 'type' => 'string', 'description' => __( 'Font family name.', 'elementor-mcp' ) ),
						'font_weight'      => array( 'type' => 'string', 'description' => __( 'Font weight (e.g. 400, 700).', 'elementor-mcp' ) ),
						'line_height'      => array( 'type' => 'number', 'description' => __( 'Line height value. Default unit em.', 'elementor-mcp' ) ),
						'letter_spacing'   => array( 'type' => 'number', 'description' => __( 'Letter spacing value. Default unit px.', 'elementor-mcp' ) ),
						'text_align'       => array( 'type' => 'string', 'description' => __( 'Text alignment (left, center, right, justify).', 'elementor-mcp' ) ),
						'color'            => array( 'type' => 'string', 'description' => __( 'Text color (hex/rgb).', 'elementor-mcp' ) ),
						'background_color' => array( 'type' => 'string', 'description' => __( 'Background color (hex/rgb).', 'elementor-mcp' ) ),
						'padding'          => array( 'type' => 'number', 'description' => __( 'Uniform padding value.', 'elementor-mcp' ) ),
						'border_radius'    => array( 'type' => 'number', 'description' => __( 'Border radius value.', 'elementor-mcp' ) ),
```

For `add-atomic-widget`: add to its `input_schema.properties`:

```php
						'style_props' => array( 'type' => 'object', 'description' => __( 'Optional flat styling params (color, font_size, padding, etc.) applied as a local style class.', 'elementor-mcp' ) ),
```

(Keep it to this representative subset in the schema — the ability accepts the full allow-list from `collect_style_props()` regardless; the schema documents the common ones so agents discover the capability without bloating every tool.)

- [ ] **Step 7: Lint + full suite**

Run:
```bash
"$PHP" -l includes/abilities/class-atomic-widget-abilities.php
"$PHP" -l includes/class-element-factory.php
"$PHP" -l includes/class-atomic-styles.php
"$PHP" /tmp/phpunit10.phar 2>&1 | tail -4
```
Expected: no syntax errors; suite shows the new tests passing and the pre-existing 18 errors / 15 failures unchanged (baseline unrelated to this work).

- [ ] **Step 8: Commit**

```bash
git add includes/abilities/class-atomic-widget-abilities.php tests/unit/functional/AtomicWidgetStyleFunctionalTest.php
git commit -m "feat(atomic): text widgets + bare add-atomic-widget accept styling props

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 4: Ship — push, PR, fork main, SoftLab

**Files:** none (git/gh + WP-CLI)

- [ ] **Step 1: Push + open upstream PR**

```bash
cd /Users/digitizer/Documents/GitHub/elementor-mcp
git push -u origin feat/atomic-widget-styling
gh pr create --repo msrbuilds/elementor-mcp --base main --head Digitizers:feat/atomic-widget-styling \
  --title "feat: atomic text widgets accept styling + typography props" \
  --body "Mirrors add-flexbox styling onto add-atomic-heading/paragraph/button (and a style_props passthrough on add-atomic-widget). Adds Atomic_Styles::build_typography_props() for font-size/family/weight/line-height/letter-spacing/text-align; create_atomic_widget() now builds + applies a local style class like create_flexbox. Without style props, behavior is unchanged (empty styles map). Tests: build_typography_props unit + functional (styles map populated only when props passed).

🤖 Generated with [Claude Code](https://claude.com/claude-code)"
```

- [ ] **Step 2: Merge into Digitizers fork main**

```bash
git checkout main
git merge feat/atomic-widget-styling --no-edit
git push origin main
```

- [ ] **Step 3: Reinstall the fork build on SoftLab**

```bash
SITE_PATH="/Users/digitizer/Documents/GitHub/SoftLab/app/public"
LOCAL_PHP=$(find "$HOME/Library/Application Support/Local/lightning-services" -maxdepth 6 -name php -type f | head -1)
LOCAL_WP="/Applications/Local.app/Contents/Resources/extraResources/bin/wp-cli/posix/wp"
cd /Users/digitizer/Documents/GitHub/elementor-mcp
rm -f /tmp/elementor-mcp-fork.zip
git archive --format=zip --prefix=elementor-mcp/ HEAD -o /tmp/elementor-mcp-fork.zip
SOCK=""
while IFS= read -r -d '' s; do
  if "$LOCAL_PHP" -d "mysqli.default_socket=$s" -d "pdo_mysql.default_socket=$s" "$LOCAL_WP" --path="$SITE_PATH" --skip-plugins --skip-themes core version >/dev/null 2>&1; then SOCK="$s"; break; fi
done < <(find "$HOME/Library/Application Support/Local/run" -name mysqld.sock -print0 2>/dev/null)
WP(){ "$LOCAL_PHP" -d "mysqli.default_socket=$SOCK" -d "pdo_mysql.default_socket=$SOCK" "$LOCAL_WP" --path="$SITE_PATH" "$@"; }
WP --skip-themes plugin install /tmp/elementor-mcp-fork.zip --force --activate 2>&1 | tail -2
```

Expected: `Success: Installed 1 of 1 plugins.` Second session must restart Claude Code to pick up the new build; the styling props then appear in the `add-atomic-*` tool schemas.

---

## Self-Review notes (author)

- **Spec coverage:** `build_typography_props` (Task 1) ✓; `create_atomic_widget` `$style_props` (Task 2) ✓; three text abilities collect style keys + bare passthrough + input_schema (Task 3) ✓; unit + functional tests (Tasks 1–3) ✓; ship upstream+fork+SoftLab (Task 4) ✓; YAGNI scope (svg/image/etc excluded) ✓.
- **Placeholder scan:** every code step shows full code; the only "confirm exact line while editing" notes are content-anchored edits (the literal to find is quoted), not placeholders.
- **Type consistency:** `build_typography_props(array): array`, `create_atomic_widget(string,array,array): array`, `collect_style_props(array): array` used identically across tasks; `$$type` shapes (`size`/`string`) match `Elementor_MCP_Atomic_Props::size/string` already in the codebase.
