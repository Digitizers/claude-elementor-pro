# cloudways-mcp — genericize + kit-standard (SP1, publish-ready)

**Date:** 2026-06-02
**Status:** Approved (design), pending implementation
**Repos:** `Digitizers/cloudways-mcp` (genericize + packaging) + `Digitizers/digitizer-os` (relocated internal notes)
**Branch:** `feat/genericize-kit-standard` (cloudways-mcp)

## Problem

cloudways-mcp is a high-quality operational skill the studio wants to open-source. It's
currently **private** and carries **Digitizer-specific framing** (~17 mentions across 5
files, incl. names "Ben/Avi" in a report template) that should not ship in a public,
generic skill. A security audit confirmed **no real secrets/keys/clients/IPs** in the
working tree or git history (6 commits) — only placeholders + internal framing. So the
work to make it publish-ready is: genericize the framing (relocating the genuinely-internal
bits to the private brain) and bring it to the kit standard (CI, version, CHANGELOG,
ClawHub publish workflow). Flipping the repo public is a **separate, gated step (SP2)**.

## Goal

Make cloudways-mcp a clean, generic, kit-standard skill that is **publish-ready** — so SP2
is just "flip visibility + run publish". No publishing in SP1.

## Audit result (carried from brainstorming)

- ✅ No secrets/keys/client names/IPs/server-IDs in tree or history — placeholders only.
- ⚠️ Digitizer framing to genericize: SKILL.md (2), installation.md (5), workflows-onboarding.md
  (4, incl. `Auditor: Digitizer (Ben/Avi)`), workflows-automation.md (5), README.md (1).
- Infisical/OpenBao appear as **generic security-vault examples** — keep them as examples.

## Component 1 — Genericize the skill (cloudways-mcp)

Sweep the 5 files; replace Digitizer-specific framing with neutral wording, preserving all
technical content:

- "הקשר Digitizer" / "בנוי במיוחד ל-Digitizer stack" / "ל-Digitizer יש" → generic ("for
  day-to-day agency/team management", "your stack", "if you manage several Cloudways
  accounts"). The USD-not-₪ note stays (it's a factual API detail).
- `workflows-onboarding.md` title "(Digitizer client takeover)" → "(agency client takeover)";
  "המלצה סטנדרטית של Digitizer" → "המלצה סטנדרטית"; **`Auditor: Digitizer (Ben/Avi)` →
  `Auditor: [your name]`** (remove the personal names).
- Infisical/OpenBao/1Password stay as **examples** of a secrets vault (generic best practice).
- README "בנוי לעבודה היומיומית של Digitizer" → generic.

Result: zero "Digitizer"/"דיגיטייזר" and no personal names anywhere in the skill.

## Component 2 — Relocate the internal bits (digitizer-os)

The genuinely studio-specific knowledge (so it isn't lost when stripped from the public
skill): add a short note to digitizer-os — a `## Cloudways ops (internal)` block in
`knowledge/studio-toolbox.md` under the cloudways-mcp entry, capturing: the studio uses
cloudways-mcp for client-takeover/onboarding audits; per-client secrets live in separate
Infisical/OpenBao projects; multi-account = one connection per client account. (Private brain.)

## Component 3 — Kit-standard packaging (cloudways-mcp)

Mirror wordpress-api-pro:

- **`.claude/skills/cloudways-mcp/SKILL.md` frontmatter:** add `version: 1.0.0`.
- **`package.json`** (name `cloudways-mcp`, version `1.0.0`, private:false, the skill dir).
- **`CHANGELOG.md`** — `## 1.0.0` entry (genericized + kit-standard; first public-ready cut).
- **`.github/workflows/ci.yml`:**
  - SKILL.md frontmatter lint (non-empty `name`, `description`, `version`).
  - Reference-link check: every `references/*.md` linked from SKILL.md exists.
  - **No-leak guard (critical for a soon-public repo):** CI **fails** if the skill payload
    contains the string `Digitizer`/`דיגיטייזר`, a personal name from the removed set, or a
    secret-shaped pattern (a long `api_key=...`/`Bearer ...` that isn't a placeholder). This
    keeps the repo clean as it heads to public.
- **`.github/workflows/publish-clawhub.yml`** — copy wp-api-pro's, with
  `SKILL_DIR: .claude/skills/cloudways-mcp` and version read from that SKILL.md. Triggers on
  release + manual dispatch (dry-run default). **Dormant until SP2** (needs `CLAWHUB_TOKEN`
  secret + public repo).

## Non-goals (SP2 / later)

- Flipping the repo to public — SP2, gated, user-triggered.
- Running an actual ClawHub publish — SP2.
- Deciding keep-history vs fresh-repo — SP2 (history has no secrets, so "keep" is safe;
  defer the choice).
- Verifying against a live Cloudways MCP server (uncertain availability) — out of scope;
  the skill is documentation that activates when a server is connected.

## Verification

- CI green: frontmatter lint + reference-link check + **no-leak guard** (the guard is the
  real test — it proves the genericize is complete).
- Manual: `grep -ri "digitizer\|ben\|avi" .claude/ README.md` → only false positives (none of
  the removed framing/names).
- Relocated note present in digitizer-os.
- `package.json` + both workflows parse.

## Follow-up (SP2 — separate spec, gated, you trigger)

1. Decide keep-history vs fresh-repo (no secrets → keep is safe).
2. `gh repo edit Digitizers/cloudways-mcp --visibility public`.
3. Add `CLAWHUB_TOKEN` secret; run the publish workflow (dry-run → real).
4. Optionally: verify + fix the skill against a live Cloudways MCP when available.
