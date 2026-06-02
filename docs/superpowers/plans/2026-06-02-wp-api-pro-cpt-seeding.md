# wordpress-api-pro CPT Content Seeding — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Seed dynamic CPT datasets in one command — create CPT entries with ACF/Jet fields, taxonomies, and featured images, dry-run first.

**Architecture:** Make `create_post.py`/`upload_media.py` importable (`__main__` guards); add CPT + taxonomy support to `create_post.py`; add `describe_cpt.py` (schema discovery) and `seed_content.py` (batch seeder that imports the other scripts). Dry-run default. CI gains unit tests + an offline dry-run smoke.

**Tech Stack:** Python 3 (stdlib `urllib`/`json` for create/seed; `requests` already used by acf/jet), WordPress REST API, app-password auth.

**Repo / branch:** `/Users/digitizer/Documents/GitHub/wordpress-api-pro`, branch `feat/cpt-seeding` off `main`. Scripts live in `wordpress-api-pro/scripts/`. Run python: `python3`.

**Note:** `acf_fields.py` and `jetengine_fields.py` are already `__main__`-guarded and importable (`set_acf_fields()` / `set_jetengine_fields()` return dicts). Only `create_post.py` and `upload_media.py` need guards.

---

## File Structure

- Modify `wordpress-api-pro/scripts/create_post.py` — CPT + terms + helpers + `__main__` guard; `create_post()` raises instead of `sys.exit`.
- Modify `wordpress-api-pro/scripts/upload_media.py` — wrap CLI in `__main__` guard.
- Create `wordpress-api-pro/scripts/describe_cpt.py` — schema discovery.
- Create `wordpress-api-pro/scripts/seed_content.py` — batch seeder.
- Create `tests/test_cpt_seeding.py` — unittest + mock.
- Create `tests/fixtures/seed.json` — sample dataset.
- Modify `.github/workflows/*.yml` — run tests + dry-run smoke.
- Modify `wordpress-api-pro/SKILL.md`, `package.json`, `CHANGELOG.md` — docs + version bump.

---

## Task 0: Branch

- [ ] **Step 1**

```bash
cd /Users/digitizer/Documents/GitHub/wordpress-api-pro
git checkout main && git pull --ff-only
git checkout -b feat/cpt-seeding
mkdir -p tests/fixtures
```

---

## Task 1: `create_post.py` — CPT, taxonomy, importable

**Files:** Modify `wordpress-api-pro/scripts/create_post.py`; Test `tests/test_cpt_seeding.py`

- [ ] **Step 1: Write failing unit tests**

Create `tests/test_cpt_seeding.py`:

```python
import json, os, sys, unittest
from unittest import mock

SCRIPTS = os.path.join(os.path.dirname(__file__), "..", "wordpress-api-pro", "scripts")
sys.path.insert(0, os.path.abspath(SCRIPTS))

import create_post  # noqa: E402


class FakeResp:
    def __init__(self, payload, code=200):
        self._b = json.dumps(payload).encode()
        self.status = code
    def read(self): return self._b
    def __enter__(self): return self
    def __exit__(self, *a): return False


class ResolveRestBaseTest(unittest.TestCase):
    def test_uses_rest_base_from_types(self):
        with mock.patch.object(create_post.urllib.request, "urlopen",
                               return_value=FakeResp({"rest_base": "projects"})):
            self.assertEqual(
                create_post.resolve_rest_base("http://x", "a", "projects"), "projects")

    def test_falls_back_to_slug_on_error(self):
        with mock.patch.object(create_post.urllib.request, "urlopen",
                               side_effect=Exception("404")):
            self.assertEqual(
                create_post.resolve_rest_base("http://x", "a", "team"), "team")


class ResolveTermsTest(unittest.TestCase):
    def test_existing_term_resolves_to_id(self):
        # /types lookup for taxonomy rest_base, then term search returns an id.
        responses = [
            FakeResp({"rest_base": "project_category"}),   # taxonomy rest base
            FakeResp([{"id": 5, "name": "Branding"}]),     # term search hit
        ]
        with mock.patch.object(create_post.urllib.request, "urlopen",
                               side_effect=responses):
            out = create_post.resolve_terms("http://x", "a",
                                             {"project_category": ["Branding"]},
                                             create_missing=False)
            self.assertEqual(out, {"project_category": [5]})


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run — expect failure**

Run: `python3 tests/test_cpt_seeding.py`
Expected: `AttributeError: module 'create_post' has no attribute 'resolve_rest_base'` (and the import currently triggers argparse — that error too). Both fixed in Step 3.

- [ ] **Step 3: Rewrite `create_post.py`**

Replace the entire file with:

```python
#!/usr/bin/env python3
"""Create a WordPress post or CPT entry via REST API (with taxonomy support)."""
import argparse, json, os, sys, urllib.request, urllib.parse
from base64 import b64encode


def _auth(username, password):
    return 'Basic ' + b64encode(f"{username}:{password}".encode()).decode()


def _get(url, auth):
    req = urllib.request.Request(url, method='GET')
    req.add_header('Authorization', auth)
    with urllib.request.urlopen(req) as r:
        return json.loads(r.read().decode())


def _post(url, auth, payload):
    req = urllib.request.Request(url, data=json.dumps(payload).encode(), method='POST')
    req.add_header('Authorization', auth)
    req.add_header('Content-Type', 'application/json')
    with urllib.request.urlopen(req) as r:
        return json.loads(r.read().decode())


def resolve_rest_base(base_url, auth, post_type):
    """Resolve a post type's REST base; fall back to the slug on any error."""
    try:
        info = _get(f"{base_url.rstrip('/')}/wp-json/wp/v2/types/{post_type}", auth)
        return info.get('rest_base') or post_type
    except Exception:
        return post_type


def resolve_terms(base_url, auth, terms_dict, create_missing=True):
    """Map {taxonomy: [name|id, ...]} -> {taxonomy: [id, ...]}.

    Names are resolved (and optionally created) via the taxonomy's REST base.
    Integer-like values pass through as ids.
    """
    base_url = base_url.rstrip('/')
    out = {}
    for taxonomy, values in (terms_dict or {}).items():
        tax_base = resolve_rest_base(base_url, auth, taxonomy)  # taxonomy rest_base
        ids = []
        for v in values:
            if isinstance(v, int) or (isinstance(v, str) and v.isdigit()):
                ids.append(int(v)); continue
            q = urllib.parse.quote(str(v))
            hits = _get(f"{base_url}/wp-json/wp/v2/{tax_base}?search={q}", auth)
            match = next((t for t in hits if str(t.get('name', '')).lower() == str(v).lower()), None)
            if match:
                ids.append(match['id'])
            elif create_missing:
                created = _post(f"{base_url}/wp-json/wp/v2/{tax_base}", auth, {'name': v})
                ids.append(created['id'])
            else:
                raise ValueError(f"Term '{v}' not found in '{taxonomy}'")
        out[taxonomy] = ids
    return out


def create_post(url, username, password, title, content, status='draft',
                post_type='post', featured_media=None, terms=None):
    """Create a post/CPT entry. Returns the created object dict. Raises on error."""
    auth = _auth(username, password)
    base = url.rstrip('/')
    rest_base = resolve_rest_base(base, auth, post_type)

    data = {'title': title, 'content': content, 'status': status}
    if featured_media:
        data['featured_media'] = int(featured_media)
    if terms:
        resolved = resolve_terms(base, auth, terms)
        for taxonomy, ids in resolved.items():
            data[taxonomy] = ids  # REST accepts the taxonomy key with term ids

    return _post(f"{base}/wp-json/wp/v2/{rest_base}", auth, data)


def main():
    p = argparse.ArgumentParser(description='Create WordPress post or CPT entry')
    p.add_argument('--url', default=os.getenv('WP_URL') or os.getenv('WP_SITE_URL'))
    p.add_argument('--username', default=os.getenv('WP_USERNAME') or os.getenv('WP_USER'))
    p.add_argument('--app-password', default=os.getenv('WP_APP_PASSWORD'))
    p.add_argument('--title', required=True)
    p.add_argument('--content', required=True)
    p.add_argument('--status', default='draft', choices=['publish', 'draft', 'pending'])
    p.add_argument('--post-type', default='post')
    p.add_argument('--featured-media', type=int)
    p.add_argument('--terms', help='JSON {"taxonomy": ["Name or id", ...]}')
    a = p.parse_args()
    if not all([a.url, a.username, a.app_password]):
        print(json.dumps({"error": "Missing required credentials"}), file=sys.stderr)
        sys.exit(1)
    try:
        result = create_post(a.url, a.username, a.app_password, a.title, a.content,
                             a.status, post_type=a.post_type,
                             featured_media=a.featured_media,
                             terms=json.loads(a.terms) if a.terms else None)
        print(json.dumps(result, indent=2))
    except Exception as e:
        print(json.dumps({"error": str(e)}), file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    main()
```

- [ ] **Step 4: Run — expect pass**

Run: `python3 tests/test_cpt_seeding.py`
Expected: `OK` (3 tests).

- [ ] **Step 5: Compile check + commit**

```bash
python3 -m py_compile wordpress-api-pro/scripts/create_post.py
git add wordpress-api-pro/scripts/create_post.py tests/test_cpt_seeding.py
git commit -m "feat(api-pro): create_post supports CPT + taxonomy terms; importable helpers

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 2: `upload_media.py` — `__main__` guard

**Files:** Modify `wordpress-api-pro/scripts/upload_media.py`

- [ ] **Step 1: Wrap the CLI body**

In `upload_media.py`, the `argparse` block and everything after it currently runs at
module top level. Move it into a `main()` function and guard it. Concretely: find the
line `parser = argparse.ArgumentParser(` near the bottom, insert `def main():` above it,
indent the argparse-through-final-`print` block one level, and append:

```python
if __name__ == '__main__':
    main()
```

Keep `upload_media()` and `set_featured_image()` (the importable functions) at module
level, unchanged.

- [ ] **Step 2: Verify importable + still runs**

Run:
```bash
python3 -c "import sys; sys.path.insert(0,'wordpress-api-pro/scripts'); import upload_media; print('import ok', hasattr(upload_media,'upload_media'), hasattr(upload_media,'set_featured_image'))"
python3 -m py_compile wordpress-api-pro/scripts/upload_media.py
python3 wordpress-api-pro/scripts/upload_media.py --help >/dev/null && echo "cli ok"
```
Expected: `import ok True True`, no compile error, `cli ok`.

- [ ] **Step 3: Commit**

```bash
git add wordpress-api-pro/scripts/upload_media.py
git commit -m "refactor(api-pro): make upload_media importable (__main__ guard)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 3: `describe_cpt.py`

**Files:** Create `wordpress-api-pro/scripts/describe_cpt.py`

- [ ] **Step 1: Create the script**

```python
#!/usr/bin/env python3
"""Describe a custom post type: rest_base, taxonomies, and discovered field keys.

Read-only. Samples the newest existing entry to surface ACF/meta keys so a caller
knows what to populate when seeding.

Usage:
    python3 describe_cpt.py --post-type projects
Env: WP_URL/WP_SITE_URL, WP_USERNAME/WP_USER, WP_APP_PASSWORD
"""
import argparse, json, os, sys, urllib.request
from base64 import b64encode


def _auth(u, p): return 'Basic ' + b64encode(f"{u}:{p}".encode()).decode()


def _get(url, auth):
    req = urllib.request.Request(url, method='GET')
    req.add_header('Authorization', auth)
    with urllib.request.urlopen(req) as r:
        return json.loads(r.read().decode())


def describe_cpt(base_url, username, password, post_type):
    auth = _auth(username, password)
    base = base_url.rstrip('/')
    info = _get(f"{base}/wp-json/wp/v2/types/{post_type}", auth)
    rest_base = info.get('rest_base') or post_type
    taxonomies = info.get('taxonomies', [])

    field_keys, sampled_id = [], None
    try:
        entries = _get(f"{base}/wp-json/wp/v2/{rest_base}?per_page=1&orderby=date", auth)
        if entries:
            sampled_id = entries[0].get('id')
            meta = entries[0].get('meta', {}) or {}
            acf = entries[0].get('acf', {}) or {}
            keys = set(k for k in meta if not k.startswith('_')) | set(acf.keys())
            field_keys = sorted(keys)
    except Exception:
        pass

    return {
        'post_type': post_type, 'rest_base': rest_base,
        'taxonomies': taxonomies, 'field_keys': field_keys,
        'sampled_entry_id': sampled_id,
        'note': '' if field_keys else 'No entries to sample; supply field keys manually.',
    }


def main():
    p = argparse.ArgumentParser(description='Describe a CPT for seeding')
    p.add_argument('--url', default=os.getenv('WP_URL') or os.getenv('WP_SITE_URL'))
    p.add_argument('--username', default=os.getenv('WP_USERNAME') or os.getenv('WP_USER'))
    p.add_argument('--app-password', default=os.getenv('WP_APP_PASSWORD'))
    p.add_argument('--post-type', required=True)
    a = p.parse_args()
    if not all([a.url, a.username, a.app_password]):
        print(json.dumps({"error": "Missing required credentials"}), file=sys.stderr); sys.exit(1)
    try:
        print(json.dumps(describe_cpt(a.url, a.username, a.app_password, a.post_type), indent=2))
    except Exception as e:
        print(json.dumps({"error": str(e)}), file=sys.stderr); sys.exit(1)


if __name__ == '__main__':
    main()
```

- [ ] **Step 2: Compile + commit**

```bash
python3 -m py_compile wordpress-api-pro/scripts/describe_cpt.py
git add wordpress-api-pro/scripts/describe_cpt.py
git commit -m "feat(api-pro): add describe_cpt.py schema discovery

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 4: `seed_content.py` (batch seeder)

**Files:** Create `wordpress-api-pro/scripts/seed_content.py`, `tests/fixtures/seed.json`; extend `tests/test_cpt_seeding.py`

- [ ] **Step 1: Create the fixture**

`tests/fixtures/seed.json`:

```json
[
  {
    "post_type": "projects",
    "title": "Acme Rebrand",
    "content": "<p>Full brand refresh.</p>",
    "status": "draft",
    "terms": { "project_category": ["Branding"] },
    "featured_image": 42,
    "acf": { "client": "Acme", "year": 2025 },
    "jet": { "duration_weeks": 6 }
  },
  {
    "post_type": "projects",
    "title": "Globex Site",
    "content": "<p>Marketing site.</p>",
    "status": "draft",
    "terms": { "project_category": ["Web"] },
    "featured_image": "https://example.com/globex.jpg",
    "acf": { "client": "Globex", "year": 2024 }
  }
]
```

- [ ] **Step 2: Write the failing dry-run test (append to `tests/test_cpt_seeding.py`)**

```python
import seed_content  # noqa: E402

class SeedDryRunTest(unittest.TestCase):
    def test_dry_run_plans_every_entry_without_network(self):
        fixture = os.path.join(os.path.dirname(__file__), "fixtures", "seed.json")
        with open(fixture) as f:
            dataset = json.load(f)
        # plan_seed must NOT perform any network call in dry-run.
        plan = seed_content.plan_seed(dataset)
        self.assertEqual(len(plan), 2)
        self.assertEqual(plan[0]["post_type"], "projects")
        self.assertIn("acf", plan[0]["will_set"])
        self.assertIn("terms", plan[0]["will_set"])
        self.assertEqual(plan[1]["featured_image_kind"], "url")
        self.assertEqual(plan[0]["featured_image_kind"], "media_id")
```

- [ ] **Step 3: Run — expect failure**

Run: `python3 tests/test_cpt_seeding.py`
Expected: `ModuleNotFoundError: No module named 'seed_content'`.

- [ ] **Step 4: Create `seed_content.py`**

```python
#!/usr/bin/env python3
"""Seed a dataset of CPT entries with ACF/Jet fields, taxonomies, and images.

Dry-run by default — validates and prints a per-entry plan with NO writes.
Pass --execute to perform writes. Reuses create_post / acf_fields /
jetengine_fields / upload_media.

Usage:
    python3 seed_content.py --dataset data.json            # dry-run (default)
    python3 seed_content.py --dataset data.json --execute  # write
Env: WP_URL/WP_SITE_URL, WP_USERNAME/WP_USER, WP_APP_PASSWORD
"""
import argparse, json, os, sys

import create_post as _cp
import acf_fields as _acf
import jetengine_fields as _jet
import upload_media as _media


def plan_seed(dataset):
    """Pure planning — no network. Returns a list of per-entry plan dicts."""
    plan = []
    for i, e in enumerate(dataset):
        fi = e.get('featured_image')
        kind = None
        if isinstance(fi, int) or (isinstance(fi, str) and str(fi).isdigit()):
            kind = 'media_id'
        elif isinstance(fi, str) and fi:
            kind = 'url' if fi.lower().startswith(('http://', 'https://')) else 'path'
        will_set = []
        if e.get('acf'): will_set.append('acf')
        if e.get('jet'): will_set.append('jet')
        if e.get('terms'): will_set.append('terms')
        if fi is not None: will_set.append('featured_image')
        plan.append({
            'index': i, 'title': e.get('title', '(no title)'),
            'post_type': e.get('post_type', 'post'),
            'status': e.get('status', 'draft'),
            'will_set': will_set, 'featured_image_kind': kind,
        })
    return plan


def _resolve_image(url, user, pw, fi, allow_remote):
    if isinstance(fi, int) or (isinstance(fi, str) and str(fi).isdigit()):
        return int(fi)
    res = _media.upload_media(url, user, pw, fi, allow_remote_url=allow_remote)
    return res.get('id') if isinstance(res, dict) else None


def seed(url, user, pw, dataset, allow_remote=False):
    """Execute the seed. Returns {created: [...], failed: [...]}."""
    created, failed = [], []
    for e in dataset:
        try:
            post = _cp.create_post(
                url, user, pw, e['title'], e.get('content', ''),
                e.get('status', 'draft'), post_type=e.get('post_type', 'post'),
                terms=e.get('terms'))
            pid = post['id']
            if e.get('acf'):
                _acf.set_acf_fields(url, user, pw, pid, e['acf'])
            if e.get('jet'):
                _jet.set_jetengine_fields(url, user, pw, pid, e['jet'])
            if e.get('featured_image') is not None:
                mid = _resolve_image(url, user, pw, e['featured_image'], allow_remote)
                if mid:
                    _media.set_featured_image(url, user, pw, pid, mid)
            created.append({'id': pid, 'title': e['title']})
        except Exception as ex:
            failed.append({'title': e.get('title', '(no title)'), 'error': str(ex)})
    return {'created': created, 'failed': failed}


def main():
    p = argparse.ArgumentParser(description='Seed CPT entries from a JSON dataset')
    p.add_argument('--url', default=os.getenv('WP_URL') or os.getenv('WP_SITE_URL'))
    p.add_argument('--username', default=os.getenv('WP_USERNAME') or os.getenv('WP_USER'))
    p.add_argument('--app-password', default=os.getenv('WP_APP_PASSWORD'))
    p.add_argument('--dataset', required=True, help='Path to JSON array of entries')
    p.add_argument('--execute', action='store_true', help='Perform writes (default: dry-run)')
    p.add_argument('--allow-remote-url', action='store_true', help='Permit remote image fetches')
    a = p.parse_args()

    with open(a.dataset) as f:
        dataset = json.load(f)
    if not isinstance(dataset, list):
        print(json.dumps({"error": "dataset must be a JSON array"}), file=sys.stderr); sys.exit(1)

    if not a.execute:
        print(json.dumps({"dry_run": True, "plan": plan_seed(dataset)}, indent=2))
        return

    if not all([a.url, a.username, a.app_password]):
        print(json.dumps({"error": "Missing required credentials"}), file=sys.stderr); sys.exit(1)
    result = seed(a.url, a.username, a.app_password, dataset, allow_remote=a.allow_remote_url)
    print(json.dumps(result, indent=2))
    if result['failed']:
        sys.exit(1)


if __name__ == '__main__':
    main()
```

- [ ] **Step 5: Run — expect pass**

Run: `python3 tests/test_cpt_seeding.py`
Expected: `OK` (4 tests). The seed import works because acf/jet/create/upload are all `__main__`-guarded.

- [ ] **Step 6: Offline dry-run smoke**

Run:
```bash
python3 wordpress-api-pro/scripts/seed_content.py --dataset tests/fixtures/seed.json
echo "exit=$?"
```
Expected: prints `{"dry_run": true, "plan": [...]}` with 2 entries, exit 0, no network.

- [ ] **Step 7: Commit**

```bash
python3 -m py_compile wordpress-api-pro/scripts/seed_content.py
git add wordpress-api-pro/scripts/seed_content.py tests/fixtures/seed.json tests/test_cpt_seeding.py
git commit -m "feat(api-pro): add seed_content.py batch CPT seeder (dry-run default)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 5: CI — run tests + dry-run smoke

**Files:** Modify `.github/workflows/<the test workflow>.yml`

- [ ] **Step 1: Find the workflow + the existing test job**

Run: `ls .github/workflows && grep -n "compileall\|bash -n" .github/workflows/*.yml`

- [ ] **Step 2: Add steps after `compileall`**

In the `test` job, after the `Compile Python scripts` step, add:

```yaml
      - name: Unit tests
        run: python3 tests/test_cpt_seeding.py
      - name: Seed dry-run smoke (no network)
        run: |
          python3 wordpress-api-pro/scripts/seed_content.py --dataset tests/fixtures/seed.json > /tmp/plan.json
          python3 -c "import json;d=json.load(open('/tmp/plan.json'));assert d['dry_run'] and len(d['plan'])==2;print('smoke ok')"
```

- [ ] **Step 3: Commit**

```bash
git add .github/workflows
git commit -m "ci(api-pro): run CPT-seeding unit tests + dry-run smoke

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 6: SKILL.md + version bump

**Files:** Modify `wordpress-api-pro/SKILL.md`, `package.json`, `CHANGELOG.md`

- [ ] **Step 1: Document in SKILL.md**

Under `## Plugin integrations`, add bullets:

```markdown
- `scripts/describe_cpt.py` — discover a CPT's rest_base, taxonomies, and field keys (read-only).
- `scripts/seed_content.py` — batch-create CPT entries with ACF/Jet fields, taxonomies, and featured images from a JSON dataset. **Dry-run by default; pass `--execute` to write.**
```

Add a short subsection after `## Media upload`:

```markdown
## Seeding dynamic content (CPT)

For dynamic sites (JetEngine/ACF listings), populate the entries the listings render:

1. `describe_cpt.py --post-type projects` — learn the rest_base, taxonomies, field keys.
2. Write a JSON dataset (array of `{post_type, title, content, status, terms, featured_image, acf, jet}`).
3. `seed_content.py --dataset data.json` — review the dry-run plan.
4. `seed_content.py --dataset data.json --execute` — create (drafts by default).

Notes: the CPT, taxonomies, and ACF field-groups must already exist (admin-side).
`featured_image` accepts a media id or a URL/path (URL fetch needs `--allow-remote-url`).
Re-running creates duplicates (no upsert yet).
```

- [ ] **Step 2: Bump version**

In `wordpress-api-pro/SKILL.md` frontmatter `version:` and `package.json` `"version"`: set to `3.6.0`. Prepend a `CHANGELOG.md` entry:

```markdown
## 3.6.0
- Add CPT content seeding: `create_post.py` supports `--post-type` + `--terms`; new `describe_cpt.py` (schema discovery) and `seed_content.py` (batch seeder, dry-run by default).
- Make `create_post.py` / `upload_media.py` importable.
```

- [ ] **Step 3: Commit**

```bash
git add wordpress-api-pro/SKILL.md package.json CHANGELOG.md
git commit -m "docs(api-pro): document CPT seeding; bump to 3.6.0

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 7: Push + PR

- [ ] **Step 1**

```bash
git push -u origin feat/cpt-seeding
gh pr create --repo Digitizers/wordpress-api-pro --base main --head feat/cpt-seeding \
  --title "feat: CPT content seeding (Tier-1 dynamic content)" \
  --body "$(cat <<'EOF'
## What
Seed dynamic CPT datasets in one command — the content JetEngine/ACF listings render.

- `create_post.py`: `--post-type` (resolves rest_base via `/wp/v2/types`) + `--terms` (name→id, create-missing). Now importable.
- `describe_cpt.py` (new): rest_base + taxonomies + field keys sampled from an existing entry.
- `seed_content.py` (new): JSON dataset → create entry + ACF + Jet + terms + featured image. **Dry-run by default**, `--execute` to write; per-entry errors collected, batch continues.
- Tests: unit (rest_base/terms resolution, dry-run planning) + an offline dry-run smoke, wired into CI.

## Scope
Populates existing CPTs/taxonomies/field-groups; creating those is admin-side (out of scope). Flat ACF values (repeater/relational later). No upsert yet (re-run duplicates).

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

- [ ] **Step 2: Watch CI**

Run: `gh pr checks --repo Digitizers/wordpress-api-pro --watch` (or report URL). Fix forward if red.

---

## Self-Review notes (author)

- **Spec coverage:** CPT+terms create (Task 1) ✓; importable guards — create_post (Task 1), upload_media (Task 2); acf/jet already guarded (noted) ✓; describe_cpt (Task 3) ✓; seed_content dry-run-first (Task 4) ✓; tests + CI smoke (Tasks 4–5) ✓; SKILL + version (Task 6) ✓; PR (Task 7) ✓; non-goals (no CPT/field-group creation, flat ACF) carried into SKILL + PR ✓.
- **Placeholder scan:** full code in every code step; "find the workflow" (Task 5) is a locate step with the exact grep, not a placeholder.
- **Type consistency:** `resolve_rest_base(base_url, auth, post_type)`, `resolve_terms(base_url, auth, terms_dict, create_missing)`, `create_post(..., post_type, featured_media, terms)`, `plan_seed(dataset)`, `seed(url,user,pw,dataset,allow_remote)` used identically across tasks and tests. `set_acf_fields`/`set_jetengine_fields`/`upload_media`/`set_featured_image` match the existing scripts' signatures.
