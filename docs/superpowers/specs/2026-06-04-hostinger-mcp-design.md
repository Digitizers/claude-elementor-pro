# hostinger-mcp — design spec

**Date:** 2026-06-04
**Repo to build:** `Digitizers/hostinger-mcp` (public, currently empty)
**Pattern:** clone the `cloudways-mcp` kit, adapted to Hostinger's local-npm / stdio model.

## Goal

A public Claude Code & OpenClaw skill that wraps the official Hostinger MCP server (`hostinger/api-mcp-server`, npm `hostinger-api-mcp`) for operational management of Hostinger VPS, hosting, domains, DNS, email (Reach), and billing — with write-confirmation safety and a tool-loading strategy that keeps Claude Code's context lean.

## Upstream facts (verified from hostinger/api-mcp-server README, 2026-06-04)

- **Install:** `npm install -g hostinger-api-mcp` (also yarn/pnpm). **Node.js v24+**.
- **Transport:** stdio (default, `hostinger-api-mcp`) or HTTP (`hostinger-api-mcp --http --host 127.0.0.1 --port 8100`).
- **Auth:**
  - `HOSTINGER_API_TOKEN` env (Bearer `Authorization` header) — from Hostinger **hPanel**. Recommended for CI/scripts and **required for HTTP mode**.
  - OAuth 2.0 + PKCE (interactive) — triggered when no token; `--login` / `--logout`; creds at `~/.config/hostinger-mcp/credentials.json`. **stdio only.**
- **127 tools total**, split into per-category binaries:
  - `hostinger-api-mcp` — all 127
  - `hostinger-vps-mcp` — 62
  - `hostinger-hosting-mcp` — 22
  - `hostinger-domains-mcp` — 18
  - `hostinger-reach-mcp` — 10 (email marketing)
  - `hostinger-dns-mcp` — 8
  - `hostinger-billing-mcp` — 7
- **Tool naming:** `<Category>_<action>V<n>` — e.g. `VPS_getVirtualMachinesV1`, `VPS_recreateVirtualMachineV1`, `VPS_createFirewallRuleV1`, `domains_checkDomainAvailabilityV1`, `domains_purchaseNewDomainV1`, `domains_enableDomainLockV1`, `DNS_getDNSRecordsV1`, `DNS_updateDNSRecordsV1`, `DNS_restoreDNSSnapshotV1`, `hosting_createWebsiteV1`, `hosting_importWordpressWebsite`, `hosting_deployJsApplication`, `billing_getSubscriptionListV1`, `reach_listContactsV1`.
- **Multi-account:** the OAuth flow stores one central credential per machine (single user). For multiple Hostinger accounts → one MCP connection per account, each with its own `HOSTINGER_API_TOKEN`.

## Key design decisions (confirmed with user)

1. **Tool loading = category binaries (headline rule).** The skill teaches connecting only the category binaries needed (`hostinger-vps-mcp`, `hostinger-dns-mcp`, …) rather than the 127-tool all-in-one, to keep context lean and tool selection fast. The all-in-one is documented as an option.
2. **Workflow playbook = VPS only.** The full 127-tool catalog is documented by category, but only VPS gets a dedicated operational playbook (it is Hostinger's core + largest surface). Other categories are catalog-only.
3. **Auth default = API token** (from hPanel); OAuth 2.0 PKCE documented as the interactive alternative.
4. **License = MIT** (matches cloudways-mcp).
5. **Multi-account = token-per-connection**, named `hostinger-<account>` → tools appear as `mcp__hostinger-<account>__<tool>`.

## Deliverables

### Skill payload — `.claude/skills/hostinger-mcp/`

- **SKILL.md**
  - Frontmatter: `name: hostinger-mcp`, `version: 1.0.0`, `license: MIT`, `description` (operational guide; triggers on Hostinger / VPS / hPanel / domains / DNS / hosting / Reach / billing).
  - **Category-binary loading** as the headline rule: connect only the binaries needed; list the 7 binaries + tool counts; default to the smallest set that covers the task.
  - **Safety rules:** write-confirmation pattern (target + action + account before execution); double-confirm destructive/irreversible tools (`VPS_recreateVirtualMachineV1`, `VPS_deleteVirtualMachineV1`-class, `domains_purchaseNewDomainV1` (spends money), `DNS_updateDNSRecordsV1` on production, billing payment-method changes). Money-spending operations (domain purchase, VPS purchase, subscriptions) are explicitly flagged as confirm-with-cost.
  - **Multi-account:** token-per-connection, `hostinger-<account>` prefix; identify account before every op; never reuse a token or cross IDs between accounts.
  - **Auth overview:** `HOSTINGER_API_TOKEN` (hPanel) Bearer; OAuth 2.0 PKCE alt (stdio only); never print the token.
  - **Quick-route table** → references.
- **references/installation.md**
  - `npm i -g hostinger-api-mcp` (Node 24+); get API token from hPanel; OAuth alt (`--login`).
  - The 7 category binaries + when to use each (tool counts).
  - Claude Code config: stdio `command:` entries per category binary, with `HOSTINGER_API_TOKEN` env; `claude mcp add` form.
  - Multi-account (one connection per account/token).
  - HTTP mode note (`--http`, token required, OAuth unsupported).
  - Verify: list VPS / domains as the liveness + auth check.
- **references/tools-catalog.md**
  - All 127 tools by 7 categories, R/W/W! tags, one-line descriptions. (Full names pulled from the upstream package/docs during implementation.)
  - Money-spending + destructive tools clearly marked.
- **references/workflows-vps.md**
  - Flagship VPS playbook: inventory (`VPS_getVirtualMachinesV1`), provision (`VPS_purchaseNewVirtualMachineV1` — cost-confirm), lifecycle (start/stop/restart), recreate/snapshots (destructive — double-confirm), firewall (`VPS_createFirewallRuleV1`), projects (`VPS_getProjectListV1`). Confirmation gates throughout.

### Repo furniture (kit-standard, from cloudways-mcp)

- `README.md` — house style: `# Hostinger MCP — Claude Code & OpenClaw Skill`, badge row (CI · Claude Code · OpenClaw · Hostinger · License: MIT · version), marketing tagline + operational-playbook authority line, Features ✅ list, Links + `Built with ❤️ for OpenClaw by Digitizer` footer.
- `.github/workflows/ci.yml` — frontmatter lint + reference-link check + no-leak guard (payload studio-neutral; README brand allowed; block personal names + secrets).
- `.github/workflows/publish-clawhub.yml` — reads version from SKILL.md; publishes with `--slug hostinger-mcp --name "Hostinger MCP"`; dormant until token set.
- `package.json` (name, version 1.0.0, license MIT, files allowlist `.claude/skills/hostinger-mcp`).
- `CHANGELOG.md` (1.0.0).
- `LICENSE` (MIT).
- `.mcp.json.example` — per-account, per-category-binary stdio entries with `HOSTINGER_API_TOKEN` placeholder; gitignored real `.mcp.json`.
- `.gitignore` — `.mcp.json`, `*.docx`.

## Out of scope (YAGNI)

- Workflow docs for hosting / domains / DNS / reach / billing (catalog-only for now; add later if needed).
- HTTP-mode-first setup (stdio is the default; HTTP noted briefly).
- A live ClawHub publish in this cycle (workflow added but firing it is a separate ops step, like cloudways).

## Verification

- CI replicas pass locally (frontmatter lint, reference links resolve, no-leak guard).
- Tool-name spot-check against the upstream package (names match `Category_actionVn`).
- `.mcp.json.example` is valid JSON.
- No studio framing / personal names / secrets in the payload; README carries only the Digitizer brand.
- Tool counts per category match upstream (62/22/18/10/8/7 = 127).

## Open implementation note

The full list of 127 exact tool names must be pulled during implementation from the upstream package (`npm view` / the installed binary's tool list / the repo's generated docs), not invented. If the live list diverges from the README's category counts, the live package wins and the catalog notes it.
