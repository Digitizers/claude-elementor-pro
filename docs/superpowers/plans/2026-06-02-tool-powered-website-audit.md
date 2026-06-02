# Tool-powered Website Audit (Tier-1) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans. Steps use checkbox (`- [ ]`) syntax.

**Goal:** A no-auth, one-command Tier-1 site audit (`site_audit.py`) that emits findings against the audit engine's thresholds, plus wiring the engine doc + wp-api-pro packaging.

**Architecture:** New stdlib-only `wordpress-api-pro/scripts/site_audit.py` (pure parser fns + a fetching `main`), offline parser unit tests, CI hookup, version bump; and an upgrade to `digitizer-os/engines/website-audit-engine.md` (Tier-1 runs the script; Tier-2 references authed scripts).

**Tech Stack:** Python 3 stdlib (urllib/ssl/socket/re/json), PageSpeed Insights API (optional key). Two repos.

**Branches:** `feat/site-audit` in `/Users/digitizer/Documents/GitHub/wordpress-api-pro`; `feat/audit-tool-powered` in `/Users/digitizer/Documents/GitHub/digitizer-os`.

---

## File Structure

- Create `wordpress-api-pro/scripts/site_audit.py` — the audit.
- Create `wordpress-api-pro/tests/test_site_audit.py` — offline parser tests.
- Modify `wordpress-api-pro/.github/workflows/ci.yml` — run the new test.
- Modify `wordpress-api-pro/wordpress-api-pro/SKILL.md`, `package.json`, `CHANGELOG.md` — doc + 3.7.0.
- Modify `digitizer-os/digitizer-os/engines/website-audit-engine.md` — wire Tier-1/2.

---

## Task 0: Branch (wp-api-pro)

```bash
cd /Users/digitizer/Documents/GitHub/wordpress-api-pro
git checkout main && git pull --ff-only
git checkout -b feat/site-audit
```

---

## Task 1: `site_audit.py` (pure parsers, TDD)

**Files:** Create `wordpress-api-pro/scripts/site_audit.py`, `wordpress-api-pro/tests/test_site_audit.py`

- [ ] **Step 1: Write the failing tests**

Create `tests/test_site_audit.py`:

```python
import os, sys, unittest

SCRIPTS = os.path.join(os.path.dirname(__file__), "..", "wordpress-api-pro", "scripts")
sys.path.insert(0, os.path.abspath(SCRIPTS))

import site_audit as sa  # noqa: E402


class CmsTest(unittest.TestCase):
    def test_detects_wordpress_and_version_from_generator(self):
        html = '<meta name="generator" content="WordPress 6.5.2" />'
        out = sa.parse_cms(html, {})
        self.assertTrue(out["is_wordpress"])
        self.assertEqual(out["wp_version"], "6.5.2")

    def test_detects_wp_from_wp_content_when_no_generator(self):
        html = '<link href="/wp-content/themes/x/style.css">'
        out = sa.parse_cms(html, {})
        self.assertTrue(out["is_wordpress"])

    def test_php_version_from_x_powered_by(self):
        out = sa.parse_cms("", {"X-Powered-By": "PHP/8.1.27"})
        self.assertEqual(out["php_version"], "8.1.27")

    def test_non_wp(self):
        self.assertFalse(sa.parse_cms("<html>nothing</html>", {})["is_wordpress"])


class SeoTest(unittest.TestCase):
    def test_extracts_title_and_description_and_h1_and_canonical(self):
        html = ('<title>Acme — Home</title>'
                '<meta name="description" content="We build things.">'
                '<link rel="canonical" href="https://acme/"><h1>Hi</h1>')
        out = sa.parse_seo(html)
        self.assertEqual(out["title"], "Acme — Home")
        self.assertEqual(out["meta_description"], "We build things.")
        self.assertEqual(out["h1_count"], 1)
        self.assertTrue(out["has_canonical"])

    def test_missing_fields(self):
        out = sa.parse_seo("<html></html>")
        self.assertIsNone(out["title"])
        self.assertIsNone(out["meta_description"])
        self.assertEqual(out["h1_count"], 0)
        self.assertFalse(out["has_canonical"])


class HeadersTest(unittest.TestCase):
    def test_present_and_missing_security_headers(self):
        out = sa.analyze_headers({
            "Strict-Transport-Security": "max-age=63072000",
            "X-Content-Type-Options": "nosniff",
        })
        self.assertIn("Strict-Transport-Security", out["present"])
        self.assertIn("Content-Security-Policy", out["missing"])
        self.assertIn("X-Frame-Options", out["missing"])


class SslTest(unittest.TestCase):
    def test_days_left_positive(self):
        # Fixed "now" so the test is deterministic.
        now = sa._parse_cert_time("Jan  1 00:00:00 2026 GMT")
        days = sa.ssl_days_left("Mar  2 00:00:00 2026 GMT", now=now)
        self.assertEqual(days, 60)


class PageSpeedTest(unittest.TestCase):
    def test_grade(self):
        self.assertEqual(sa.grade_pagespeed(0.95), "pass")
        self.assertEqual(sa.grade_pagespeed(0.80), "warn")
        self.assertEqual(sa.grade_pagespeed(0.50), "fail")


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run — expect failure**

Run: `python3 tests/test_site_audit.py`
Expected: `ModuleNotFoundError: No module named 'site_audit'`.

- [ ] **Step 3: Write `site_audit.py`**

Create `wordpress-api-pro/scripts/site_audit.py`:

```python
#!/usr/bin/env python3
"""No-auth Tier-1 website audit — public signals only (PageSpeed/SSL/headers/CMS/SEO).

Run cold, before any engagement, as the sales-hook quick scan. Read-only public
fetches; no credentials. Outputs findings JSON (default) or a 1-page --summary.

Usage:
    python3 site_audit.py https://example.com
    python3 site_audit.py https://example.com --summary
Env (optional): PAGESPEED_API_KEY  (higher PageSpeed Insights quota)
"""
import argparse, json, re, ssl, socket, sys, urllib.request, urllib.parse
from datetime import datetime, timezone

UA = "Mozilla/5.0 (compatible; DigitizerAudit/1.0)"
SECURITY_HEADERS = [
    "Strict-Transport-Security", "Content-Security-Policy", "X-Frame-Options",
    "X-Content-Type-Options", "Referrer-Policy",
]


# ---- pure parsers (unit-tested, no network) --------------------------------
def parse_cms(html, headers):
    html = html or ""
    headers = {k.lower(): v for k, v in (headers or {}).items()}
    gen = re.search(r'<meta[^>]+name=["\']generator["\'][^>]+content=["\']([^"\']+)["\']', html, re.I)
    generator = gen.group(1) if gen else None
    is_wp = bool(generator and "wordpress" in generator.lower()) or "/wp-content/" in html or "/wp-json" in html
    wp_version = None
    if generator:
        m = re.search(r'WordPress\s+([0-9.]+)', generator, re.I)
        if m:
            wp_version = m.group(1)
    php = None
    xpb = headers.get("x-powered-by", "")
    mp = re.search(r'PHP/([0-9.]+)', xpb)
    if mp:
        php = mp.group(1)
    return {"is_wordpress": is_wp, "wp_version": wp_version, "php_version": php, "generator": generator}


def parse_seo(html):
    html = html or ""
    t = re.search(r'<title[^>]*>(.*?)</title>', html, re.I | re.S)
    d = re.search(r'<meta[^>]+name=["\']description["\'][^>]+content=["\'](.*?)["\']', html, re.I | re.S)
    return {
        "title": t.group(1).strip() if t else None,
        "meta_description": d.group(1).strip() if d else None,
        "h1_count": len(re.findall(r'<h1[\s>]', html, re.I)),
        "has_canonical": bool(re.search(r'<link[^>]+rel=["\']canonical["\']', html, re.I)),
    }


def analyze_headers(headers):
    present_keys = {k.lower() for k in (headers or {})}
    present, missing = [], []
    for h in SECURITY_HEADERS:
        (present if h.lower() in present_keys else missing).append(h)
    return {"present": present, "missing": missing}


def _parse_cert_time(s):
    # OpenSSL notAfter format, e.g. "Mar  2 00:00:00 2026 GMT"
    return datetime.strptime(s, "%b %d %H:%M:%S %Y %Z").replace(tzinfo=timezone.utc)


def ssl_days_left(notafter, now=None):
    end = _parse_cert_time(notafter)
    now = now or datetime.now(timezone.utc)
    return (end - now).days


def grade_pagespeed(score):
    # score is 0..1 (Lighthouse). >=0.9 pass, >=0.7 warn, else fail.
    if score is None:
        return "skipped"
    if score >= 0.9:
        return "pass"
    if score >= 0.7:
        return "warn"
    return "fail"


# ---- fetching (network; not unit-tested) -----------------------------------
def _get(url, method="GET", timeout=15):
    req = urllib.request.Request(url, method=method, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        body = r.read().decode("utf-8", "replace") if method == "GET" else ""
        return r.getcode(), dict(r.headers), r.geturl(), body


def _ssl_notafter(host, port=443, timeout=10):
    ctx = ssl.create_default_context()
    with socket.create_connection((host, port), timeout=timeout) as sock:
        with ctx.wrap_socket(sock, server_hostname=host) as ssock:
            return ssock.getpeercert().get("notAfter")


def _url_exists(url):
    try:
        code, _, _, _ = _get(url, method="GET", timeout=10)
        return 200 <= code < 400
    except Exception:
        return False


def _pagespeed(url, strategy, api_key=None):
    base = "https://www.googleapis.com/pagespeedonline/v5/runPagespeed"
    q = {"url": url, "strategy": strategy}
    if api_key:
        q["key"] = api_key
    try:
        _, _, _, body = _get(base + "?" + urllib.parse.urlencode(q), timeout=60)
        data = json.loads(body)
        return data["lighthouseResult"]["categories"]["performance"]["score"]
    except Exception:
        return None


def audit(url, api_key=None):
    findings = []

    def add(group, check, value, status, note=""):
        findings.append({"group": group, "check": check, "value": value, "status": status, "note": note})

    try:
        code, headers, final_url, html = _get(url)
    except Exception as e:
        add("reach", "reachable", str(e), "fail", "site did not respond")
        return {"url": url, "reachable": False, "findings": findings}

    add("reach", "status", code, "pass" if code < 400 else "fail")
    add("reach", "https", final_url.startswith("https://"), "pass" if final_url.startswith("https://") else "fail",
        "no HTTPS redirect" if not final_url.startswith("https://") else "")

    host = urllib.parse.urlparse(final_url).hostname
    if final_url.startswith("https://") and host:
        try:
            na = _ssl_notafter(host)
            days = ssl_days_left(na) if na else None
            st = "pass" if (days or 0) > 20 else ("warn" if (days or 0) > 0 else "fail")
            add("security", "ssl_days_left", days, st, f"expires {na}")
        except Exception as e:
            add("security", "ssl", str(e), "fail", "SSL check failed")

    hdr = analyze_headers(headers)
    add("security", "security_headers", f"{len(hdr['present'])}/5",
        "pass" if len(hdr["present"]) >= 4 else ("warn" if hdr["present"] else "fail"),
        "missing: " + ", ".join(hdr["missing"]) if hdr["missing"] else "")

    cms = parse_cms(html, headers)
    add("cms", "wordpress", cms["is_wordpress"], "pass" if cms["is_wordpress"] else "warn",
        f"version {cms['wp_version']}" if cms["wp_version"] else "version hidden")
    if cms["php_version"]:
        php_ok = cms["php_version"].startswith(("8.1", "8.2", "8.3", "8.4"))
        add("security", "php_version", cms["php_version"], "pass" if php_ok else "fail",
            "EOL PHP" if not php_ok else "")

    seo = parse_seo(html)
    add("seo", "title", seo["title"], "pass" if seo["title"] else "fail")
    add("seo", "meta_description", seo["meta_description"], "pass" if seo["meta_description"] else "fail")
    add("seo", "single_h1", seo["h1_count"], "pass" if seo["h1_count"] == 1 else "warn",
        f"{seo['h1_count']} H1s")
    add("seo", "canonical", seo["has_canonical"], "pass" if seo["has_canonical"] else "warn")

    origin = f"{urllib.parse.urlparse(final_url).scheme}://{host}"
    add("seo", "sitemap.xml", _url_exists(origin + "/sitemap.xml"), "pass" if _url_exists(origin + "/sitemap.xml") else "fail")
    add("seo", "robots.txt", _url_exists(origin + "/robots.txt"), "pass" if _url_exists(origin + "/robots.txt") else "warn")

    for strat in ("mobile", "desktop"):
        score = _pagespeed(final_url, strat, api_key)
        add("performance", f"pagespeed_{strat}", round(score * 100) if score is not None else None,
            grade_pagespeed(score), "PSI unavailable" if score is None else "")

    return {"url": final_url, "reachable": True, "findings": findings}


def _summary(result):
    lines = [f"# Quick audit — {result['url']}", ""]
    if not result["reachable"]:
        return "\n".join(lines + ["Site unreachable."])
    order = {"fail": 0, "warn": 1, "skipped": 2, "pass": 3}
    icon = {"pass": "🟢", "warn": "🟡", "fail": "🔴", "skipped": "⚪"}
    for f in sorted(result["findings"], key=lambda x: order.get(x["status"], 9)):
        note = f" — {f['note']}" if f["note"] else ""
        lines.append(f"{icon.get(f['status'],'')} [{f['group']}] {f['check']}: {f['value']}{note}")
    return "\n".join(lines)


def main():
    p = argparse.ArgumentParser(description="No-auth Tier-1 website audit")
    p.add_argument("url", nargs="?", help="Site URL (http(s)://...)")
    p.add_argument("--url", dest="url_opt")
    p.add_argument("--summary", action="store_true", help="Human 1-page summary instead of JSON")
    import os
    a = p.parse_args()
    url = a.url or a.url_opt
    if not url:
        print(json.dumps({"error": "URL required"}), file=sys.stderr); sys.exit(1)
    if not url.startswith(("http://", "https://")):
        url = "https://" + url
    result = audit(url, api_key=os.getenv("PAGESPEED_API_KEY"))
    print(_summary(result) if a.summary else json.dumps(result, indent=2))
    if result["reachable"] and any(f["status"] == "fail" for f in result["findings"]):
        sys.exit(2)  # findings present (non-zero, but distinct from unreachable=1-ish)


if __name__ == "__main__":
    main()
```

- [ ] **Step 4: Run — expect pass**

Run: `python3 tests/test_site_audit.py`
Expected: `OK` (12 tests).

- [ ] **Step 5: Compile + commit**

```bash
python3 -m py_compile wordpress-api-pro/scripts/site_audit.py
git add wordpress-api-pro/scripts/site_audit.py tests/test_site_audit.py
git commit -m "feat(api-pro): add site_audit.py — no-auth Tier-1 website audit

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 2: CI + SKILL + version (wp-api-pro)

**Files:** Modify `.github/workflows/ci.yml`, `wordpress-api-pro/SKILL.md`, `package.json`, `CHANGELOG.md`

- [ ] **Step 1: CI — run the new test**

In `.github/workflows/ci.yml`, in the `Unit tests` step (currently runs
`tests/test_cpt_seeding.py`), add a line:

```yaml
      - name: Unit tests
        run: |
          python3 tests/test_cpt_seeding.py
          python3 tests/test_site_audit.py
```

- [ ] **Step 2: SKILL bullet**

Under `## Plugin integrations` in `wordpress-api-pro/SKILL.md`, add:

```markdown
- `scripts/site_audit.py` — no-auth Tier-1 website audit (PageSpeed/SSL/security headers/CMS+PHP/SEO basics). Public probes only; run cold pre-sale.
```

- [ ] **Step 3: Version 3.7.0 + CHANGELOG**

Set `version: 3.7.0` in `wordpress-api-pro/SKILL.md` frontmatter and `"version": "3.7.0"`
in `package.json`. Prepend to `CHANGELOG.md`:

```markdown
## 3.7.0 - 2026-06-02
- Add `site_audit.py` — no-auth Tier-1 website audit (PageSpeed, SSL, security headers, CMS/PHP detection, SEO basics) emitting findings against the audit-engine thresholds. Stdlib-only; the sales-hook quick scan.
```

- [ ] **Step 4: Verify + commit**

```bash
python3 -m compileall -q wordpress-api-pro/scripts
python3 tests/test_site_audit.py
grep -h "3.7.0" wordpress-api-pro/SKILL.md package.json CHANGELOG.md
git add .github/workflows/ci.yml wordpress-api-pro/SKILL.md package.json CHANGELOG.md
git commit -m "ci/docs(api-pro): run site_audit tests; document; bump to 3.7.0

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

- [ ] **Step 5: Push + PR**

```bash
git push -u origin feat/site-audit
gh pr create --repo Digitizers/wordpress-api-pro --base main --head feat/site-audit \
  --title "feat: site_audit.py — no-auth Tier-1 website audit" \
  --body "Runnable, credential-free Tier-1 site audit (PageSpeed/SSL/security headers/CMS+PHP/SEO basics) emitting findings against the audit-engine thresholds — the studio's pre-sale quick-scan, automated. Stdlib-only; pure parsers unit-tested offline; wired into CI. Bumped to 3.7.0.

🤖 Generated with [Claude Code](https://claude.com/claude-code)"
```

Watch CI: `gh pr checks --watch`.

---

## Task 3: Wire the audit engine (digitizer-os)

**Files:** Modify `digitizer-os/digitizer-os/engines/website-audit-engine.md`

- [ ] **Step 1: Branch**

```bash
cd /Users/digitizer/Documents/GitHub/digitizer-os
git checkout main && git pull --ff-only
git checkout -b feat/audit-tool-powered
```

- [ ] **Step 2: Upgrade Tier 1**

Replace the Tier 1 bullet list (`### Tier 1: Quick Scan ...`) body with the same intent
plus a **Run it** line:

```markdown
**Run it (no credentials):** `python3 <wordpress-api-pro>/scripts/site_audit.py <url> --summary`
— probes PageSpeed (mobile+desktop), SSL, security headers, WordPress/PHP version, and
SEO basics (title, meta description, single H1, sitemap, robots), scored against the
thresholds in the checklist below. Drop the 3–5 worst findings into the 1-page summary /
cold-message snippet. (Manual add: obvious UX/navigation issues.)
```

Keep the existing "**Output:** 1-page summary…" line.

- [ ] **Step 3: Wire Tier 2 + annotate the checklist**

In `### Tier 2`, add:

```markdown
**Authed inventory:** with the client's app-password (post-onboard), run
`detect_plugins.py` (full plugin list) and `seo_meta.py` (RankMath/Yoast meta) from
wordpress-api-pro for the deep technical + SEO inventory.
```

At the top of `## Audit Checklist`, add a note:

```markdown
> Rows marked **(auto)** are produced by `wordpress-api-pro/scripts/site_audit.py` (no
> auth). The rest are manual or need the client's credentials (Tier 2+).
```

Append `(auto)` to the PageSpeed Mobile/Desktop, SSL/TLS, WordPress version, PHP version,
Security headers, Sitemap, Robots.txt, Meta titles, Meta descriptions, and "Page titles
as H1" check rows.

- [ ] **Step 4: Commit + push + PR**

```bash
git add digitizer-os/engines/website-audit-engine.md
git commit -m "feat(os): wire website-audit Tier-1 to site_audit.py; Tier-2 to authed scripts

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
git push -u origin feat/audit-tool-powered
gh pr create --repo Digitizers/digitizer-os --base main --head feat/audit-tool-powered \
  --title "feat: tool-powered website audit (Tier-1 runnable)" \
  --body "Tier-1 quick scan now runs via wordpress-api-pro/scripts/site_audit.py (no creds) — automated PageSpeed/SSL/headers/CMS/SEO against the existing thresholds; checklist rows marked (auto). Tier-2 wired to detect_plugins/seo_meta (authed). Higher tiers unchanged.

🤖 Generated with [Claude Code](https://claude.com/claude-code)"
```

---

## Self-Review notes (author)

- **Spec coverage:** site_audit.py with all listed checks (Task 1) ✓; offline parser tests + CI (Tasks 1–2) ✓; SKILL+version+CHANGELOG (Task 2) ✓; engine Tier-1 run + Tier-2 authed + checklist (auto) annotations (Task 3) ✓; non-goals honored (no Tier-2/3 scripting, no cloudways, no PDF, single-page) ✓.
- **Placeholder scan:** full code for the script + tests; engine edits are content-anchored to existing headings.
- **Type consistency:** parser fn names (`parse_cms`, `parse_seo`, `analyze_headers`, `ssl_days_left`, `_parse_cert_time`, `grade_pagespeed`) identical across `site_audit.py` and `test_site_audit.py`; finding shape `{group,check,value,status,note}` consistent.
