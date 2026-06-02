# wordpress-api-pro — CPT content seeding (Tier-1 dynamic content)

**Date:** 2026-06-02
**Status:** Approved (design), pending implementation
**Repo:** `Digitizers/wordpress-api-pro`
**Branch:** `feat/cpt-seeding`

## Problem

The studio builds dynamic sites (portfolio/projects, team, properties, listings)
where Elementor/JetEngine/ACF render **custom post type** entries. `wordpress-api-pro`
can already read/write ACF + JetEngine field *values* on a post, but:

- `create_post.py` is hardcoded to `/wp-json/wp/v2/posts` — it can only create the
  default `post` type, **not** CPT entries. So you can set fields but cannot create
  the dynamic content the listings display.
- No taxonomy assignment on create (only `featured_media`).
- No way to seed a whole dataset (e.g. 12 projects) — each entry is a manual chain
  of create + acf-set + jet-set + image.
- No schema discovery — nothing tells Claude which ACF/meta keys a CPT uses, so
  populating correctly is guesswork.

## Goal

Let the studio **seed a dynamic dataset in one command**: create CPT entries with
ACF/Jet fields, taxonomies, and featured images, dry-run first.

## Non-goals (YAGNI / out of scope)

- Creating CPTs, taxonomies, or ACF field-groups — these are admin-side and mostly
  not REST-writable. The CPT/taxonomy/field-group must already exist (registered by
  the theme/JetEngine/ACF). We populate, we don't define structure.
- Repeater / flexible-content / relational ACF fields beyond flat scalar/array
  values — v1 handles flat values; complex nested fields noted as follow-up.
- New auth/transport — reuse the existing app-password + REST approach.

## Design (Approach A — reuse existing scripts as importable modules)

### Prerequisite refactor

`create_post.py`, `acf_fields.py`, `jetengine_fields.py`, `upload_media.py` run
`argparse` at module top level, so importing them executes the CLI. Wrap each
script's CLI body in `if __name__ == "__main__":` so its functions are importable
without side effects. No behavior change when run directly. (`upload_media.py`
already exposes `upload_media()` + `set_featured_image()`; `create_post.py` exposes
`create_post()`; `acf_fields.py`/`jetengine_fields.py` expose `set_*_fields()`.)

### 1. `create_post.py` — CPT + taxonomy support

- Add `--post-type` (default `post`). Resolve its REST base: GET
  `/wp-json/wp/v2/types/<post_type>`, read `rest_base`; fall back to the post_type
  slug if the lookup fails. POST to `/wp-json/wp/v2/<rest_base>`.
- Add `--terms` (JSON object `{ "<taxonomy>": ["Name or id", ...] }`). For each
  taxonomy, resolve names → term ids via GET `/wp/v2/<tax_rest_base>?search=`, and
  create the term (POST) when missing. Attach resolved ids to the create payload
  under the taxonomy's REST key.
- Keep `--featured-media`, `--status` (default `draft`).
- Expose `resolve_rest_base(base_url, auth, post_type)` and
  `resolve_terms(base_url, auth, terms_dict, create_missing=True)` as importable
  functions (the seeder and tests use them).

### 2. `describe_cpt.py` (new)

Input: `--post-type`. Output (JSON): `rest_base`, registered `taxonomies` (from
`/types/<slug>`), and `field_keys` — the ACF/meta keys discovered by sampling one
existing entry of that type (GET newest entry → its non-private meta + ACF). If no
entries exist, report `field_keys: []` with a note to supply keys manually. This is
read-only; safe to run anytime.

### 3. `seed_content.py` (new)

Input: `--dataset <path-to.json>` — an array of entries:

```json
[
  {
    "post_type": "projects",
    "title": "Acme Rebrand",
    "content": "<p>...</p>",
    "status": "draft",
    "terms": { "project_category": ["Branding"] },
    "featured_image": "https://.../hero.jpg",
    "acf": { "client": "Acme", "year": 2025 },
    "jet": { "duration_weeks": 6 }
  }
]
```

Per entry, in order: create (via `create_post()` with post_type + terms) → set ACF
(`set_acf_fields()`) → set Jet (`set_jetengine_fields()`) → featured image: if
`featured_image` is an int treat as media id; if a URL/path, `upload_media()` →
`set_featured_image()`. `featured_image` URL fetch requires the existing
`allow_remote_url` safety flag (pass `--allow-remote-url` through).

Flags: `--dry-run` (DEFAULT — validates dataset shape, resolves rest_base + terms
read-only, prints the planned actions per entry, writes nothing) and `--execute`
(performs writes). `--allow-remote-url` to permit remote image fetches. Per-entry
errors are caught, collected, and reported in a final summary; one bad entry does
not abort the batch.

## Data flow

`dataset.json` → `seed_content` loop → for each: `create_post(post_type, terms)` →
`set_acf_fields` → `set_jetengine_fields` → featured image → collect `{id, url,
status}`. Dry-run resolves rest_base/terms (read-only GETs) and prints the plan.

## Error handling

- Missing CPT / rest_base unresolved → entry fails with a clear message, batch
  continues.
- Term not found + `create_missing` → created; on failure, entry flagged.
- ACF write needs `show_in_rest`/registered meta — on REST failure the existing
  postmeta fallback applies; if both fail, entry flagged (not silent).
- Final summary: created ids, skipped/failed entries with reasons. Non-zero exit if
  any entry failed under `--execute`.

## Testing

No test framework exists (CI = `bash -n` + `compileall`). Add:

- **Unit (unittest + mock):** `resolve_rest_base` (uses `rest_base`, falls back to
  slug on 404), `resolve_terms` (name→id, create-missing), and `seed_content`
  dataset parsing/validation. HTTP mocked — no network.
- **Offline dry-run smoke:** `seed_content.py --dataset tests/fixtures/seed.json
  --dry-run` with a stub base URL must exit 0, attempt no writes, and print a plan
  line per entry. Wire into CI alongside `compileall`.
- Fixtures: `tests/fixtures/seed.json` (2 entries — one with media id, one with
  URL image; ACF + Jet + terms).

## Files

- Modify: `wordpress-api-pro/scripts/create_post.py` (CPT + terms + `__main__` guard + helpers)
- Modify: `wordpress-api-pro/scripts/acf_fields.py` (`__main__` guard)
- Modify: `wordpress-api-pro/scripts/jetengine_fields.py` (`__main__` guard)
- Modify: `wordpress-api-pro/scripts/upload_media.py` (`__main__` guard)
- Create: `wordpress-api-pro/scripts/describe_cpt.py`
- Create: `wordpress-api-pro/scripts/seed_content.py`
- Create: `tests/` (unittest) + `tests/fixtures/seed.json`
- Modify: `.github/workflows/*.yml` (run unit tests + dry-run smoke)
- Modify: `wordpress-api-pro/SKILL.md` (document CPT seeding + describe_cpt + seeder, dry-run-first)
- Bump: `package.json` + `SKILL.md` version, `CHANGELOG.md`

## Out of scope / follow-ups

- Repeater/flexible-content/relational ACF fields.
- Creating CPTs / taxonomies / ACF field-groups (admin-side).
- Update-existing-by-key (idempotent re-seed) — v1 creates; re-run makes duplicates.
  Note this in SKILL.md; add a `--match-by` upsert later if needed.
