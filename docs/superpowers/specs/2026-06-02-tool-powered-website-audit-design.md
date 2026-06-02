# Tool-powered website audit (Tier-1)

**Date:** 2026-06-02
**Status:** Approved (design), pending implementation
**Repos:** `Digitizers/wordpress-api-pro` (the script) + `Digitizers/digitizer-os` (the engine doc)
**Branches:** `feat/site-audit` (wp-api-pro), `feat/audit-tool-powered` (digitizer-os)

## Problem

digitizer-os's website-audit-engine is a strong **manual** checklist (4 tiers, pass/fail
thresholds, scorecard, report template). Tier-1 ("Quick Scan — free, sales tool") is
exactly the kind of repeatable, no-auth check that should be **automated** — it's run
cold, before any engagement, as a sales hook. Today it's done by hand. The studio now
has the tooling to run it; nothing wires the audit to it.

## Goal

Make the Tier-1 pre-sale audit **runnable in one command** — public, no-credentials
probes that emit findings against the engine's existing pass/fail thresholds — and wire
the engine doc to it. Higher tiers stay as they are (Tier-2 references authed
wp-api-pro scripts; Tier-3/4 strategic/manual).

## Auth split (the core design constraint)

- **Tier-1 = NO auth.** It runs against a prospect's site before any relationship, so
  it may only use **public** signals (HTTP fetches, SSL, PageSpeed API). → a new
  self-contained script.
- **Tier-2 = authed.** Full plugin/SEO inventory needs an app-password → the existing
  `detect_plugins.py` / `seo_meta.py` (auth). Doc-only wiring.

## Component 1 — `wordpress-api-pro/scripts/site_audit.py` (new)

No-auth, **stdlib only** (urllib/ssl/socket/re/json — consistent with `create_post.py`;
no `requests`). Input: a URL (positional or `--url`). Output: findings JSON (default) or
`--summary` for a human 1-pager. Read-only public fetches; honors redirects (http→https).

Checks (mapped to the engine's thresholds):

| group | check | how (public) |
|---|---|---|
| Reach | final URL, status, http→https redirect | HEAD/GET follow redirects |
| Security | SSL valid + days-to-expiry | `ssl`/`socket` cert |
| Security | security headers (HSTS, CSP, X-Frame-Options, X-Content-Type-Options, Referrer-Policy) | response headers |
| CMS | WordPress? + version + PHP version (if exposed) | `/wp-json/` 200 + `<meta generator>` + `X-Powered-By` header + `/wp-content/` refs |
| SEO | `<title>`, meta description present + length | homepage HTML |
| SEO | single `<h1>` | count `<h1>` in HTML |
| SEO | canonical tag present | homepage HTML |
| SEO | `/sitemap.xml`, `/robots.txt` present | GET each |
| Perf | PageSpeed mobile + desktop score, LCP/CLS/INP | PageSpeed Insights API (keyless low-volume, or `PAGESPEED_API_KEY`); degrade gracefully on network/quota |

Each finding: `{group, check, value, status: pass|warn|fail, note}` using the engine's
thresholds (e.g. PSI mobile ≥90 pass / <70 fail; SSL A-grade; security-headers presence).
A top-level `score_hint` rolls the groups into the engine's 5-dimension 1–5 guidance
(advisory; the human finalizes the scorecard).

Pure parser functions (testable, no network): `parse_cms(html, headers)`,
`parse_seo(html)`, `analyze_headers(headers)`, `ssl_days_left(notafter)`,
`grade_pagespeed(score)`. The `main()` does the fetching and calls them.

Failure handling: unreachable site → a single clear finding + non-zero exit; PageSpeed
unavailable → that group reported `status: skipped, note: PSI unavailable`, the rest
still run.

## Component 2 — `digitizer-os/engines/website-audit-engine.md` (upgrade)

- **Tier 1 section:** add "**Run it:** `python3 <wp-api-pro>/scripts/site_audit.py <url> --summary`
  (no credentials needed) → findings against the thresholds below → drop the 3–5 top items
  into the 1-page summary / cold-message snippet."
- **Audit Checklist:** mark which rows `site_audit.py` automates (PageSpeed mobile/desktop,
  SSL, WP/PHP version, security headers, sitemap, robots, meta titles/descriptions, single
  H1) vs which stay manual/authed.
- **Tier 2 section:** add "full plugin + SEO inventory → `detect_plugins.py` / `seo_meta.py`
  (needs the client's app-password, post-onboard)."
- Keep tiers/scorecard/report template unchanged otherwise.

## Component 3 — wp-api-pro packaging

- SKILL.md: a bullet under integrations — `scripts/site_audit.py` — no-auth Tier-1 site
  audit (PageSpeed/SSL/headers/CMS/SEO).
- Version → 3.7.0, CHANGELOG entry.
- Tests: `tests/test_site_audit.py` — unit tests for the pure parsers (CMS fingerprint,
  SEO extraction, header analysis, SSL-days, pagespeed grading) with fixture HTML/headers,
  no network. CI: `compileall` already covers it; add `python3 tests/test_site_audit.py`
  to the test job (alongside the existing CPT-seeding tests).

## Non-goals (YAGNI)

- Scripting Tier-2/3/4 (auth + judgment heavy).
- Cloudways infra checks (uncertain MCP server) — note as optional enrichment in the engine.
- A PDF/HTML report generator — the engine's markdown template + the JSON findings are enough.
- Crawling beyond the homepage + sitemap/robots probes (single-page Tier-1 by design).

## Verification

- `tests/test_site_audit.py` green (offline, mocked HTML/headers/cert).
- Live run: `site_audit.py https://digitizer.co.il --summary` produces a sensible 1-pager.
- wp-api-pro CI green.

## Follow-ups

- Tier-2 automation (authed inventory → structured report).
- Optional Playwright screenshot/visual checks (ties to a future P2 fidelity loop).
- Cloudways enrichment once that MCP path is solid.
