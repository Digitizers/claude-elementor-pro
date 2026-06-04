# sumit-mcp — design spec

**Date:** 2026-06-05
**Repo to build:** `Digitizers/sumit-mcp` (public GitHub repo, currently does not exist)
**Pattern:** **a built MCP server** — unlike cloudways/hostinger/meta-ads (skills documenting an *existing* server), SUMIT has no MCP server, so this project writes the server itself (Node/TS, `@modelcontextprotocol/sdk`, stdio) on top of the in-house `sumit-api` library.

## Goal

A Claude Code & OpenClaw MCP server + skill for **SUMIT** (formerly OfficeGuy) Israeli billing/invoicing. It gives an agent operational tools to **read** (documents, debt, catalog items), **write** (issue invoices/receipts/quotes, manage customers), and **charge** (one-off + recurring money movement) — with the strongest safety model in the studio toolbox, because it moves money and handles PII.

## Upstream facts (verified 2026-06-05)

- **`sumit-api`** (in-house, `Digitizers/sumit-api`, npm `sumit-api` v0.3.1, zero runtime deps) is **payload-builder + response-normalizer + redaction only** — it ships **no transport** (`fetch` is the integrator's job) and **no read methods**. Exports used here: `buildOneOffChargePayload`, `buildRecurringChargePayload`, `buildCreateDocumentPayload`, `normalizeChargeResponse`, `normalizeCreateDocumentResponse`, `normalizeSumitIncomingPayload`, `redactSumitPayload`, `redactSensitiveText`, `SUMIT_DOCUMENT_TYPE`, `SUMIT_LANGUAGE`, currency helpers.
- **`sumit-react`** (v0.2.0) is the browser/Next runtime companion — out of scope here.
- **Base URL:** `https://api.sumit.co.il`. All calls are `POST` JSON.
- **Auth:** every request body carries `Credentials: { CompanyID: number, APIKey: string }`. `APIKey` is a server-side secret. `APIPublicKey` (browser tokenization) is *not* used by this server.
- **Response envelope:** `{ Status, UserErrorMessage, TechnicalErrorDetails, Data }`. `Status` is framework-level; payment status lives on `Data.Payment.Status`.
- **Endpoints verified against the official OpenAPI spec** (`https://app.sumit.co.il/swagger/v1/swagger.json`):
  - Read: `/accounting/documents/list/`, `/accounting/documents/getdetails/`, `/accounting/documents/getpdf/`, `/accounting/documents/getdebt/`, `/accounting/documents/getdebtreport/`, `/accounting/incomeitems/list/`, `/accounting/customers/getdetailsurl/`.
  - Write: `/accounting/documents/create/`, `/accounting/documents/send/`, `/accounting/documents/cancel/`, `/accounting/customers/create/`, `/accounting/customers/update/`, `/accounting/incomeitems/create/`.
  - Charge: `/billing/payments/charge/` (one-off), `/billing/recurring/charge/` (recurring).
  - **Confirmed absent:** no "list/search customers returning data" endpoint (only create/update upsert + `getdetailsurl` link + debt lookups); no "list payments" endpoint (payment status comes from the charge response or the document).

## Key design decisions (confirmed with user)

1. **Reuse boundary = MCP owns transport + read.** `sumit-mcp` implements its own `fetch` client and read calls; it imports `sumit-api` only for the existing builders, normalizers, and redaction. `sumit-api` stays pure/zero-dep.
2. **Charge safety = layered.** All of: (a) `SUMIT_ALLOW_CHARGE=1` env capability flag (charge tools refuse without it; read/write always available); (b) `prepare_charge` → `execute_charge` two-step with a binding `confirmation_token`; (c) per-account amount cap `SUMIT_MAX_CHARGE`; (d) redacted audit log of every prepare/execute. Safety is server-side, not reliant on the host's permission prompt (openclaw may auto-approve).
3. **Distribution = public GitHub repo only.** No npm publish, no ClawHub publish this cycle — field-test in session 2 first. `.mcp.json` points to a local build (`node ./dist/index.js`). Publish workflows can be added later.
4. **Server structure = modular** (`client` / `accounts` / `safety` / `tools/{read,write,charge}` / `redact` / `index`), to isolate the charge + safety code from read.
5. **License = MIT** (matches the toolbox).
6. **Multi-account = creds-per-account from env**, named accounts → an optional `account` param per tool.

## Deliverables

### MCP server — `src/`

- **`index.ts`** — bootstraps the `@modelcontextprotocol/sdk` server over stdio, registers all tools, wires the client + safety layer.
- **`client.ts`** — `SumitClient.post(path, body)`: injects `Credentials`, POSTs JSON to `https://api.sumit.co.il`, unwraps the envelope (`Status !== "Success"` → mapped error carrying redacted `UserErrorMessage`), surfaces network errors cleanly. All logging passes through `redact`.
- **`accounts.ts`** — loads accounts from env (`SUMIT_<ACCT>_COMPANY_ID` + `SUMIT_<ACCT>_API_KEY`, `SUMIT_DEFAULT_ACCOUNT`); resolves the account for a call (default or explicit `account` param).
- **`safety.ts`** — capability flag check; confirmation-token mint/verify (HMAC over `account|customer|amount|currency|items_hash|nonce|exp`, in-memory single-use store, 5-min TTL); amount-cap enforcement; redacted audit log.
- **`redact.ts`** — wraps `sumit-api`'s `redactSumitPayload` / `redactSensitiveText` so every log line and error is scrubbed of card data, API keys, Upay codes, and IDs.
- **`tools/read.ts`**, **`tools/write.ts`**, **`tools/charge.ts`** — tool definitions + handlers per group.

### Tool surface (v1 — 14 tools, all grounded in the verified spec)

**Read (read-only, no side effects):**
- `sumit_list_documents` — filter by date range / type / customer → document list.
- `sumit_get_document` — by ID or type+number → details.
- `sumit_get_document_pdf` — PDF (URL or base64) for a document.
- `sumit_get_customer_debt` — outstanding debt for one customer.
- `sumit_get_debt_report` — debt across all customers.
- `sumit_list_income_items` — catalog/income items.
- `sumit_get_customer_url` — `getdetailsurl` link to a customer's page.

**Write (creates accounting artifacts; no money movement):**
- `sumit_create_document` — issue invoice / receipt / proforma (חשבון עסקה) / quote via `buildCreateDocumentPayload`; `OnlyDocument`-style, no card charge.
- `sumit_send_document` — email a document to its recipient.
- `sumit_cancel_document` — cancel / credit a document.
- `sumit_upsert_customer` — create or update a customer (by `ExternalIdentifier`, SearchMode 2).
- `sumit_create_income_item` — create a catalog income item.

**Charge (money movement — layered safety):**
- `sumit_prepare_charge` — validates inputs, builds the one-off/recurring payload, returns a human-readable summary (customer, amount, currency, items, recurrence) **plus** a `confirmation_token`. **Does not charge.**
- `sumit_execute_charge` — requires a matching, unexpired, unused `confirmation_token`; performs the charge; returns the normalized event (redacted). Gated by `SUMIT_ALLOW_CHARGE=1`, the amount cap, and token TTL.

### Safety design (the core)

- **Capability flag:** charge tools hard-refuse unless `SUMIT_ALLOW_CHARGE=1`. Read + write are always available.
- **Two-step binding:** `prepare_charge` mints `token = HMAC(server_secret, account|customer|amount|currency|items_hash|nonce|exp)`, stored in an in-memory `nonce → record` map (TTL 5 min, single-use). `execute_charge` rejects on expiry, reuse, or any mismatch between the token's bound fields and the execute parameters — preventing silent parameter drift between preview and execution.
- **Amount cap:** `SUMIT_MAX_CHARGE` per account; `execute_charge` refuses above it.
- **Audit:** every prepare/execute appends a redacted log line (no card, no APIKey, Upay codes stripped) via `redact`.
- **Secret hygiene:** `APIKey` is read from env only, never echoed in tool output or logs. The HMAC server secret is from env (`SUMIT_CONFIRM_SECRET`), generated if unset (with a note that a fixed secret is needed for cross-process stability).

### Auth / accounts / config

- Env: `SUMIT_<ACCT>_COMPANY_ID`, `SUMIT_<ACCT>_API_KEY` per account; `SUMIT_DEFAULT_ACCOUNT`; `SUMIT_ALLOW_CHARGE`, `SUMIT_MAX_CHARGE`, `SUMIT_CONFIRM_SECRET`.
- Every tool takes an optional `account` param (falls back to default).
- `.mcp.json.example` → `command: node`, `args: ["./dist/index.js"]`, env placeholders. Real `.mcp.json` is gitignored. Keys are added by the user via their own env / `claude mcp add` — never pasted in chat.

### Skill payload — `.claude/skills/sumit-mcp/`

- **SKILL.md** — frontmatter (`name: sumit-mcp`, `version: 1.0.0`, `license: MIT`, description triggering on SUMIT / OfficeGuy / חשבונית / קבלה / billing / invoice / Israeli invoicing). Headline = the **read → write → charge** safety ladder and the **prepare → show user → execute** charge protocol. Multi-account note; auth overview (never print the APIKey); quick-route table → references.
- **references/installation.md** — clone + build the server, get CompanyID + APIKey from SUMIT (app.sumit.co.il developers), env setup, `claude mcp add` form, multi-account, the `SUMIT_ALLOW_CHARGE` opt-in, liveness check (`sumit_list_documents`).
- **references/tools-catalog.md** — all 14 tools, R/W/$ tags, one-line descriptions, the SUMIT document-type table (חשבונית מס / חשבונית מס-קבלה / קבלה / חשבון עסקה / הצעת מחיר), money-movement tools clearly flagged.
- **references/workflows-billing.md** — operational playbooks: accepted quote → issue invoice → send → track debt; set up a monthly retainer (prepare → confirm → execute recurring); reconcile debt report.

### Repo furniture (kit-standard)

- `README.md` — house style: `# SUMIT MCP — Claude Code & OpenClaw Skill`, badge row (CI · Claude Code · OpenClaw · SUMIT · License: MIT · version), marketing tagline + operational-playbook authority line, Features ✅ list, `Built with ❤️ for OpenClaw by Digitizer` footer.
- `.github/workflows/ci.yml` — TypeScript build + typecheck + unit tests + no-leak guard (payload studio-neutral; README brand allowed; block personal names + secret-shaped strings).
- `package.json` — name `sumit-mcp`, version 1.0.0, license MIT, `bin`, `dependencies`: `@modelcontextprotocol/sdk` + `sumit-api`; scripts build/test/typecheck.
- `tsconfig.json`, `vitest.config.ts` (mirror `sumit-api`'s setup).
- `CHANGELOG.md` (1.0.0), `LICENSE` (MIT).
- `.mcp.json.example` (local-build stdio entry, env placeholders), `.gitignore` (`.mcp.json`, `dist`, `node_modules`, `*.docx`).
- **No** `publish-clawhub.yml` / `publish-npm.yml` this cycle (distribution decision).

## Testing

- Unit (fetch mocked, no live SUMIT calls in CI):
  - `client`: envelope unwrap on success; `Status !== "Success"` → mapped error; network failure handling.
  - `redact`: APIKey / card / Upay code never survive a logged payload.
  - `safety`: token mint→verify happy path; reject on expiry, reuse, amount-field drift, customer drift; cap enforcement; capability-flag gate.
  - `accounts`: default + named resolution; missing-account error.
- Live validation (real CompanyID + APIKey) is done as field-testing in session 2, not in CI.

## Out of scope (YAGNI)

- `sumit-react` runtime concerns (browser tokenization, checkout) — that's the runtime libs' job.
- npm + ClawHub publishing (deferred; repo-only this cycle).
- A "list/search customers" or "list payments" tool — no such endpoint exists; debt + document tools cover the read need.
- Expense documents, debt-report scheduling, HTTP transport — add later if a workflow needs them.

## Open implementation note

`sumit-mcp`'s charge tools require a `SingleUseToken` (browser tokenization), which an agent cannot mint. During implementation, read the charge endpoints' schema in the OpenAPI spec to confirm whether SUMIT accepts a stored `PaymentMethodID` / `CustomerID` for agent-initiated charging. If it does, `execute_charge` supports charging a stored method directly. If it is token-only, `execute_charge` accepts a caller-supplied `single_use_token` (from a real checkout) and "agent-initiated charge on a stored card" is documented as a limitation. The live spec wins over assumptions.

## Verification

- CI replicas pass locally (build, typecheck, unit tests, no-leak guard).
- Every tool maps to a real endpoint from the verified list — no invented paths.
- `.mcp.json.example` is valid JSON.
- No studio framing / personal names / secrets in the payload; README carries only the Digitizer brand.
- Safety tests prove charge cannot fire without the capability flag, a valid token, and an under-cap amount.
