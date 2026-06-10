# elementor-mcp fork — selective upstream port (v1.9.0 → v1.10.0) — design spec

**Date:** 2026-06-11
**Repo:** `Digitizers/elementor-mcp` (the fork; `upstream` = `msrbuilds/elementor-mcp`)
**Fork state:** 16 ahead / 15 behind `upstream/main`. Fork deliberately diverged: kept the 4.x-correct atomic work, did NOT adopt the upstream `emcp-tools` slug/folder rename or the v2.1.0 bootstrap/migration refactor.

## Goal

Port three high-value upstream improvements into the fork **selectively** (cherry-pick, not merge), preserving the fork's identity (`elementor-mcp` slug, `Elementor_MCP_*` classes, its 4.x atomic correctness). Skip the rename, the structural refactor, the PHP Snippets sandbox, README/logo docs, and the LICENSE-only commit.

## Constraint: no local PHP toolchain

This machine has no `php` / `composer` / `vendor/`. The fork has **no test CI**. Therefore: **CI is the verification backbone.** Step 0 adds a phpunit GitHub Actions workflow to the fork; every subsequent port is verified by that CI on its PR. Conflict resolutions are done by careful static review, then proven by CI — not by local runs.

## What is being ported (verified against upstream commits)

### Port 0 — add phpunit CI (enabler, standalone value)
The fork already ships `composer.json` + `phpunit.xml(.dist)` + 52 `*Test.php` files but never runs them in CI. Add `.github/workflows/tests.yml` (PHP matrix, `composer install`, `vendor/bin/phpunit`). This establishes the real baseline and verifies the ports. The fork's suite is expected to have **pre-existing failures** (prior local run: ~18 errors / 15 failures, largely Widget/CustomCode `setUp` + Security tests referencing the pre-rename layout). The bar for the ports is **"no NEW failures vs the Port 0 baseline,"** and ideally fewer (Port A carries upstream's test-suite fixes).

### Port A — security hardening (upstream `4bcefc5`, in v2.2.0)
Discrete fixes to shared ability files:
- **F-004:** `add-custom-css` neutralises the `</style>` end-tag (the only CSS-in-`<style>` breakout) with a bypass-proof loop strip; valid CSS (combinators, media-range, `content` strings) preserved. → `class-custom-code-abilities.php` (auto-merges clean).
- **F-008:** SVG sanitiser matches `on*=` handlers **across line breaks** (multiline bypass). → `class-svg-icon-abilities.php` (auto-merges clean).
- **F-020:** admin Connection tab no longer localises the absolute server path to page JS — exposes only the filename. → `class-admin.php` (**conflict** — fork diverged on admin/branding; resolve to keep fork's branding + apply the filename-only change).
- **null-save** guard + **query perf** → `class-elementor-data.php` (**conflict** — fork's data layer; resolve carefully) + `class-query-abilities.php` (clean).
- Test updates: `F004CssHtmlInjectionTest`, `F007PluginHeaderTest`, `F008SvgRegexDotallTest`, `tests/bootstrap.php` (clean); `F006PhpVersionCompatTest`, `F015UninstallTest` (**conflict** — reference upstream's renamed file / removed `uninstall.php`; resolve to the fork's actual slug + uninstall state, or skip the upstream-specific assertions).

Dry cherry-pick result: 8 paths auto-merge, **4 conflict** (`class-admin.php`, `class-elementor-data.php`, `F006…`, `F015…`).

Ships as its own PR (#1) — highest value, standalone.

### Port B — Global Classes reader (upstream `#55`, introduced in v2.1.0; `#57` defensive fix in v2.2.0)
The fork has **no** `class-global-classes-abilities.php` — this is net-new (like the earlier `list-media` port). Tool `list-global-classes`: read-only, Elementor 4.0+, resolves Elementor's Class Manager — maps opaque `g-037bb9c` IDs → human names (`card-base`) + the CSS each defines per breakpoint/state. Include the **#57** defensive per-class resolution (one malformed entry can't abort resolve-all).
- Port the **v2.2.0** version of `class-global-classes-abilities.php`, adapted to fork naming (`Elementor_MCP_Global_Classes_Abilities`, fork's `elementor_mcp_register_ability(...)` helper, category, the fork's `Elementor_MCP_Data` constructor pattern — mirror `class-media-library-abilities.php`).
- Wire: `require_once` in `elementor-mcp.php`; register in `class-ability-registrar.php::register_all()`; add to `tests/bootstrap.php` autoloader map.
- Port/adapt the upstream global-classes test(s) and add a fork capability test (mirror `MediaLibraryCapabilityTest`).
- No structural-refactor dependency: verify the upstream ability doesn't call v2.1.0 bootstrap/migration internals; if it references a helper the fork lacks, inline/adapt it.

### Port C — leaner widget schemas + `get-widget-schema` completeness + atomic `#56` (upstream `d9362e0`, in v2.2.0)
The trickiest — overlaps the fork's diverged 4.x code. Pieces:
- **#56 atomic prop fix:** `add-atomic-paragraph` must write the `e-paragraph` `paragraph` prop (was `text` → blank paragraphs); `add-atomic-youtube` must write the `e-youtube` `source` prop (was `url`). → `class-atomic-widget-abilities.php`. **First verify whether the fork already writes the correct props** (it may, given its 4.x work); only apply if the bug is present.
- **Leaner convenience-widget schemas:** each per-widget tool publishes only core params (content + primary layout + colours); everything else passes through to Elementor and stays discoverable via `get-widget-schema`. ~36% off the widget tool list. → `class-widget-abilities.php` (**conflict**).
- **`get-widget-schema` full control set:** opt into Elementor's full controls (`Performance::set_use_style_controls`) so style controls (typography/colour/shadow) are discoverable outside the editor; **non-fatal validation** — unknown keys pass through to Elementor instead of aborting. → `class-schema-generator.php` (clean) + `class-settings-validator.php` (**conflict**).
- Depends on Port B (the commit also touches `class-global-classes-abilities.php`, which only exists after B).
- **Regression bar:** the fork's existing atomic correctness must not regress — verify the fork's atomic tests still pass in CI after resolution.

Ships with Port B as PR (#2).

## Sequencing

1. **Port 0** (CI) → branch + PR, read the baseline (record the failing test set).
2. **Port A** (security) → branch off main, cherry-pick `4bcefc5 -n`, resolve the 4 conflicts, adapt tests, PR #1, verify CI ≤ baseline failures, merge.
3. **Port B** (Global Classes) → branch off the post-A main.
4. **Port C** (widget-schema/#56) → same branch as B (C depends on B's new file). PR #2, verify CI, merge.

Version → **v1.10.0** (bump `elementor-mcp.php`, `package.json`, `CHANGELOG.md`) on the B+C PR (or stage A=1.9.1 security, B+C=1.10.0 — decide at plan time; default: A=1.9.1, B+C=1.10.0).

## Out of scope (skip deliberately)
- `emcp-tools` slug/folder rename (`06e9ce2`, `f32ac33`) — breaks the fork's identity + studio installers pointing at `Digitizers/elementor-mcp`.
- v2.1.0 structural refactor (`class-bootstrap.php`, `class-migration.php`, `class-php-snippet-loader.php`) — large, conflicts with fork structure.
- **PHP Snippets sandbox** (`#3`) — executes server-side PHP; security-sensitive; explicitly deferred.
- README logo/docs commits, LICENSE-only commit.

## Verification
- Port 0 CI runs the fork's phpunit and records the baseline failing set.
- Each port PR: CI must show **no new failures** vs baseline (ideally fewer for Port A).
- Static review of every conflict resolution: confirm fork branding/slug/4.x behavior preserved; confirm the upstream security/feature change is actually applied (not lost in conflict resolution).
- Port B: `list-global-classes` registered exactly once; capability test green.
- Port C: fork atomic tests green; `#56` props correct; `get-widget-schema` returns style controls.
- No `emcp-tools` rename, no `uninstall.php` resurrection, no studio/personal-name leakage.

## Risks
- Conflict resolution could silently drop a security fix → mitigated by reviewing the applied diff against the upstream commit per file.
- Fork's red baseline could mask a new failure → mitigated by diffing the failing-test set vs the Port 0 baseline, not just "is it green."
- Port C could regress the fork's 4.x atomic correctness → mitigated by the regression bar + atomic test review.
