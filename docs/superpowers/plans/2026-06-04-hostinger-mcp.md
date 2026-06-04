# hostinger-mcp Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the `hostinger-mcp` public Claude Code & OpenClaw skill (in repo `Digitizers/hostinger-mcp`) wrapping the official Hostinger MCP server, following the `cloudways-mcp` kit pattern.

**Architecture:** A documentation/skill repo — no application code. A skill payload under `.claude/skills/hostinger-mcp/` (SKILL.md + 4 references) plus kit-standard repo furniture (README, CI, ClawHub publish workflow, package.json, CHANGELOG, LICENSE, .mcp.json.example, .gitignore). Verification is CI-replica bash checks, not unit tests.

**Tech Stack:** Markdown + YAML (GitHub Actions) + JSON. Reference template: the local `cloudways-mcp` repo at `/Users/digitizer/Documents/GitHub/cloudways-mcp` — read its equivalent files for exact structure/voice when building each Hostinger counterpart.

**Upstream source of truth:** `hostinger/api-mcp-server` (npm `hostinger-api-mcp`). Facts captured in the spec `docs/superpowers/specs/2026-06-04-hostinger-mcp-design.md`.

---

## File structure (what gets created in `Digitizers/hostinger-mcp`)

```
hostinger-mcp/
├── .claude/skills/hostinger-mcp/
│   ├── SKILL.md                       # core: category-binary loading, safety, multi-account, auth
│   └── references/
│       ├── installation.md            # npm install, token, 7 binaries, Claude config, multi-account
│       ├── tools-catalog.md           # all 127 tools, 7 categories, R/W/W!
│       └── workflows-vps.md           # flagship VPS playbook
├── .github/workflows/
│   ├── ci.yml                         # frontmatter lint + ref-link check + no-leak guard
│   └── publish-clawhub.yml            # publish with --slug hostinger-mcp --name "Hostinger MCP"
├── .mcp.json.example
├── .gitignore
├── CHANGELOG.md
├── LICENSE
├── README.md
└── package.json
```

All paths below are relative to the cloned repo root unless absolute.

---

## Task 0: Clone the empty repo + scaffold dirs

**Files:**
- Create: working clone at `/Users/digitizer/Documents/GitHub/hostinger-mcp`

- [ ] **Step 1: Clone + branch**

```bash
cd /Users/digitizer/Documents/GitHub
gh repo clone Digitizers/hostinger-mcp
cd hostinger-mcp
git checkout -b feat/initial-skill 2>/dev/null || git checkout -b feat/initial-skill
mkdir -p .claude/skills/hostinger-mcp/references .github/workflows
```

- [ ] **Step 2: Verify empty + on branch**

```bash
git rev-parse --abbrev-ref HEAD   # feat/initial-skill
ls -A                              # only .git + new dirs
```

---

## Task 1: Fetch the authoritative 127-tool list from upstream

The catalog must use real tool names, not invented ones. Pull them from the installed package.

**Files:**
- Create: `/tmp/hostinger-tools.txt` (working artifact, not committed)

- [ ] **Step 1: Install the package + dump tool names**

```bash
npm install -g hostinger-api-mcp 2>&1 | tail -2
# Try the most reliable enumeration paths, in order; keep whichever yields the full list:
hostinger-api-mcp --help 2>&1 | head -40
# Enumerate via each category binary if a --list/--tools flag exists; else inspect the package:
PKG=$(npm root -g)/hostinger-api-mcp
ls "$PKG" 2>/dev/null
grep -rhoE '"(VPS|DNS|domains|hosting|reach|billing)_[A-Za-z0-9]+"' "$PKG" 2>/dev/null | tr -d '"' | sort -u > /tmp/hostinger-tools.txt
wc -l /tmp/hostinger-tools.txt
```

- [ ] **Step 2: Confirm counts per category match the spec (62/22/18/10/8/7 = 127)**

```bash
for p in VPS hosting domains reach DNS billing; do
  echo "$p: $(grep -cE "^${p}_" /tmp/hostinger-tools.txt)"
done
echo "total: $(wc -l < /tmp/hostinger-tools.txt)"
```

Expected: totals near 62/22/18/10/8/7. If a category differs from the spec, the **live package wins** — record the actual numbers and use them in the catalog (note the delta in CHANGELOG).

- [ ] **Step 3: If enumeration fails (no names in the package source)**

Fallback: connect the server in HTTP mode and list tools over MCP, or read the upstream generated docs:

```bash
HOSTINGER_API_TOKEN=dummy hostinger-api-mcp --http --host 127.0.0.1 --port 8100 &
sleep 2
# MCP tools/list over HTTP:
curl -s http://127.0.0.1:8100/ -H 'content-type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/list"}' 2>/dev/null \
  | python3 -c "import sys,json; d=json.load(sys.stdin); [print(t['name']) for t in d.get('result',{}).get('tools',[])]" > /tmp/hostinger-tools.txt
kill %1 2>/dev/null
wc -l /tmp/hostinger-tools.txt
```

If still blank, STOP and report — do not invent names. The catalog cannot be written without the real list.

---

## Task 2: Write `tools-catalog.md`

**Files:**
- Create: `.claude/skills/hostinger-mcp/references/tools-catalog.md`
- Reference: read `/Users/digitizer/Documents/GitHub/cloudways-mcp/.claude/skills/cloudways-mcp/references/tools-catalog.md` for the exact header + table + R/W/W! conventions.

- [ ] **Step 1: Write the header + per-category tables**

Use this header verbatim, then one `##` section per category with a `| Tool | Flag | What it does |` table populated from `/tmp/hostinger-tools.txt`:

```markdown
# Tools Catalog — Hostinger MCP

The official tool catalog for the **Hostinger MCP server** (npm `hostinger-api-mcp`), from [hostinger/api-mcp-server](https://github.com/hostinger/api-mcp-server). 127 tools across 7 categories, each also available as a standalone category binary. Tools appear in Claude as `mcp__hostinger-<account>__<tool>`.

Flags: **R** = read-only · **W** = write (requires confirmation) · **W!** = destructive or money-spending (requires double confirmation).

> **Load only the category binaries you need** (see `installation.md`) — connecting all 127 tools at once bloats context. The live server is the source of truth if Hostinger changes tool names.

> 💸 **Money-spending tools** (domain/VPS purchase, subscriptions, payment-method changes) are flagged **W!** — always confirm the cost and the account before executing.
```

Then sections (in this order, with tool counts in the heading): `## VPS`, `## Hosting`, `## Domains`, `## DNS`, `## Reach (email marketing)`, `## Billing`. Each row = one tool from `/tmp/hostinger-tools.txt`.

- [ ] **Step 2: Assign R/W/W! flags by verb**

Apply consistently from the tool name verb:
- `get*`, `list*`, `check*`, `*List*`, `*Info*`, `getDNSRecords*` → **R**
- `create*`, `update*`, `set*`, `enable*`, `disable*`, `add*`, `restore*`, `deploy*`, `import*`, `start*`, `stop*`, `restart*` → **W**
- `delete*`, `recreate*`, `purchaseNew*` (domain/VPS — spends money), `setDefaultPaymentMethod*`, subscription purchase/cancel → **W!**

- [ ] **Step 3: Verify every tool from the list appears exactly once**

```bash
F=.claude/skills/hostinger-mcp/references/tools-catalog.md
missing=0
while read t; do grep -q "\`$t\`" "$F" || { echo "MISSING: $t"; missing=1; }; done < /tmp/hostinger-tools.txt
[ $missing -eq 0 ] && echo "all tools present ✓"
```

Expected: `all tools present ✓`.

- [ ] **Step 4: Commit**

```bash
git add .claude/skills/hostinger-mcp/references/tools-catalog.md
git commit -m "docs: hostinger tools catalog (127 tools, 7 categories)"
```

---

## Task 3: Write `SKILL.md`

**Files:**
- Create: `.claude/skills/hostinger-mcp/SKILL.md`
- Reference: `/Users/digitizer/Documents/GitHub/cloudways-mcp/.claude/skills/cloudways-mcp/SKILL.md` for structure (frontmatter, Quick Route, Safety rules, confirmation pattern, multi-account, auth, versioning).

- [ ] **Step 1: Write the frontmatter**

```yaml
---
name: hostinger-mcp
version: 1.0.0
license: MIT
description: |
  Operational guide for managing Hostinger infrastructure — VPS, websites/hosting, domains, DNS, email marketing (Reach), and billing — via the official Hostinger MCP server (npm hostinger-api-mcp), across one or several Hostinger accounts.
  Use whenever the user mentions Hostinger, hPanel, a Hostinger VPS, a Hostinger-hosted site, Hostinger domains/DNS, domain purchase/transfer/lock, Hostinger email/Reach contacts, or Hostinger billing/subscriptions.
  Any write operation (create/update/delete/recreate a VPS, change firewall/DNS, purchase a domain or VPS, change a subscription or payment method, deploy/import a site) requires explicit confirmation of the target resource and intended action — and the cost, for money-spending operations — before execution.
---
```

- [ ] **Step 2: Write the body sections** (mirror cloudways SKILL.md, adapted):
  1. **Connection / tool loading (headline):** the server is a local npm process (`hostinger-api-mcp`, Node 24+). **Load only the category binaries you need** — list the 7 binaries with tool counts (`hostinger-vps-mcp` 62, `hostinger-hosting-mcp` 22, `hostinger-domains-mcp` 18, `hostinger-reach-mcp` 10, `hostinger-dns-mcp` 8, `hostinger-billing-mcp` 7, `hostinger-api-mcp` all 127). Default to the smallest set covering the task. See `references/installation.md`.
  2. **Quick Route table** → installation / tools-catalog / workflows-vps.
  3. **Safety rules** (numbered): (1) identify the **account** first (multi-account); (2) write ops require explicit confirmation; (3) **money-spending ops** (`domains_purchaseNewDomainV1`, VPS purchase, subscription changes, `billing_setDefaultPaymentMethodV1`) require cost-confirmation; (4) destructive ops (`VPS_recreateVirtualMachineV1`, VPS delete-class, `DNS_updateDNSRecordsV1`/`DNS_restoreDNSSnapshotV1` on production) double-confirm; (5) credentials — `HOSTINGER_API_TOKEN` per account, never print it; (6) read-only by default.
  4. **Confirmation pattern** block (account · tool · target · params · impact/cost · proceed?).
  5. **Multi-account:** token-per-connection, `hostinger-<account>` prefix; identify before every op; never reuse a token or cross resource IDs between accounts.
  6. **Authentication — quick overview:** `HOSTINGER_API_TOKEN` (Bearer, from hPanel) is the default; OAuth 2.0 PKCE is the interactive alternative (stdio only, `--login`). Full account access, no per-tool permission at the MCP layer; never print the token.
  7. **Versioning & source of truth:** tool names match the upstream package; the live `mcp__hostinger*__*` tools win if Hostinger changes them; every W/W! tool goes through confirmation.

- [ ] **Step 3: Verify frontmatter lints + references resolve**

```bash
SKILL=.claude/skills/hostinger-mcp/SKILL.md python3 - <<'PY'
import re,os,pathlib
p=pathlib.Path(os.environ["SKILL"]); t=p.read_text()
m=re.match(r'^---\n(.*?)\n---\n',t,re.S); assert m,"no frontmatter"
for k in ("name","version","license","description"):
    mm=re.search(rf'^{k}:\s*(.+)$',m.group(1),re.M); assert mm and mm.group(1).strip(),f"missing {k}"
refs=set(re.findall(r'references/[A-Za-z0-9_-]+\.md',t))
print("frontmatter OK; refs:",sorted(refs))
PY
```

Expected: prints OK + the reference filenames.

- [ ] **Step 4: Commit**

```bash
git add .claude/skills/hostinger-mcp/SKILL.md
git commit -m "docs: hostinger SKILL.md (category-binary loading, safety, multi-account)"
```

---

## Task 4: Write `installation.md`

**Files:**
- Create: `.claude/skills/hostinger-mcp/references/installation.md`
- Reference: `/Users/digitizer/Documents/GitHub/cloudways-mcp/.claude/skills/cloudways-mcp/references/installation.md`.

- [ ] **Step 1: Write the sections**
  1. **Prerequisites:** Hostinger account + **API token** from hPanel; **Node.js v24+**.
  2. **Step 1 — Install:** `npm install -g hostinger-api-mcp` (yarn/pnpm alts).
  3. **Step 2 — Get the API token:** hPanel → API; note it's Bearer `Authorization`; OAuth alt (`hostinger-api-mcp --login`, stdio only, creds at `~/.config/hostinger-mcp/credentials.json`).
  4. **Step 3 — Pick category binaries:** table of the 7 binaries + tool counts + "use the smallest set covering your task."
  5. **Step 4 — Connect Claude Code:** one `claude mcp add` per binary you need, stdio, with the token in env. Example:

```bash
claude mcp add --transport stdio \
  -e HOSTINGER_API_TOKEN=YOUR_TOKEN \
  -s user \
  hostinger-vps hostinger-vps-mcp
```

  6. **Multi-account:** one connection per account, name `hostinger-<account>-<category>` (or `hostinger-<account>` for the all-in-one), each with its own `HOSTINGER_API_TOKEN`. Note: OAuth stores one central credential per machine, so **use API tokens for multi-account**.
  7. **HTTP mode:** `hostinger-api-mcp --http --host 127.0.0.1 --port 8100` (token required; OAuth unsupported in HTTP).
  8. **Verify:** ask "list my Hostinger VPS" (`VPS_getVirtualMachinesV1`) or "list my domains" — that round-trip confirms install + token.
  9. **Tools not appearing:** restart Claude Code after `claude mcp add` (stdio servers load on session start).

- [ ] **Step 2: Commit**

```bash
git add .claude/skills/hostinger-mcp/references/installation.md
git commit -m "docs: hostinger installation (npm, token, category binaries, multi-account)"
```

---

## Task 5: Write `workflows-vps.md`

**Files:**
- Create: `.claude/skills/hostinger-mcp/references/workflows-vps.md`
- Reference: `/Users/digitizer/Documents/GitHub/cloudways-mcp/.claude/skills/cloudways-mcp/references/workflows-maintenance.md` for the confirmation-gated workflow style.

- [ ] **Step 1: Write VPS playbook sections** (use real tool names from `/tmp/hostinger-tools.txt`; the ones below are confirmed from upstream):
  1. **Inventory:** `VPS_getVirtualMachinesV1` (R), `VPS_getProjectListV1` (R) — list machines + projects; identify the account first.
  2. **Inspect:** get one VM's details/metrics (use the real `VPS_get*V1` detail tool from the list).
  3. **Lifecycle:** start / stop / restart (W — confirm; note other workloads on the VM).
  4. **Provision (money):** `VPS_purchaseNewVirtualMachineV1` (W! — confirm plan + **cost** + account).
  5. **Recreate / snapshots (destructive):** `VPS_recreateVirtualMachineV1` (W! — wipes the VM; double-confirm + check for a snapshot/backup first).
  6. **Firewall:** `VPS_createFirewallRuleV1` and the related list/delete rule tools (W — confirm; warn that a wrong rule can lock out SSH).
  7. Each write step uses the SKILL confirmation block (account · tool · target · cost/impact · proceed?).

- [ ] **Step 2: Verify only real tool names are referenced**

```bash
F=.claude/skills/hostinger-mcp/references/workflows-vps.md
bad=0
for t in $(grep -ohE '\b(VPS|DNS|domains|hosting|reach|billing)_[A-Za-z0-9]+' "$F" | sort -u); do
  grep -q "^$t$" /tmp/hostinger-tools.txt || { echo "NOT A REAL TOOL: $t"; bad=1; }
done
[ $bad -eq 0 ] && echo "all referenced tools are real ✓"
```

Expected: `all referenced tools are real ✓`.

- [ ] **Step 3: Commit**

```bash
git add .claude/skills/hostinger-mcp/references/workflows-vps.md
git commit -m "docs: hostinger VPS workflow playbook"
```

---

## Task 6: Repo furniture — README, LICENSE, package.json, CHANGELOG, .gitignore, .mcp.json.example

**Files:**
- Create: `README.md`, `LICENSE`, `package.json`, `CHANGELOG.md`, `.gitignore`, `.mcp.json.example`
- Reference: the cloudways-mcp equivalents for README house style + footer.

- [ ] **Step 1: `.gitignore`**

```
# Real MCP config may contain Hostinger API tokens — keep it local
.mcp.json
*.docx
```

- [ ] **Step 2: `LICENSE`** — standard MIT, `Copyright (c) 2026 Digitizer`.

- [ ] **Step 3: `package.json`**

```json
{
  "name": "hostinger-mcp",
  "version": "1.0.0",
  "description": "Operational Claude Code & OpenClaw skill for managing Hostinger infrastructure (VPS, hosting, domains, DNS, Reach, billing) via the official Hostinger MCP server — category-binary loading, multi-account, write-confirmation safety.",
  "private": false,
  "license": "MIT",
  "files": [".claude/skills/hostinger-mcp"]
}
```

- [ ] **Step 4: `.mcp.json.example`** — per-account, per-category stdio entries (valid JSON):

```json
{
  "_comment": "Copy to .mcp.json (gitignored) and fill real tokens; never commit them. One connection per category binary you need (keeps context lean) and one per Hostinger account. Get the API token from hPanel. Node.js v24+ required.",
  "mcpServers": {
    "hostinger-acctA-vps": {
      "type": "stdio",
      "command": "hostinger-vps-mcp",
      "env": { "HOSTINGER_API_TOKEN": "ACCT_A_TOKEN" }
    },
    "hostinger-acctA-dns": {
      "type": "stdio",
      "command": "hostinger-dns-mcp",
      "env": { "HOSTINGER_API_TOKEN": "ACCT_A_TOKEN" }
    },
    "hostinger-acctB-vps": {
      "type": "stdio",
      "command": "hostinger-vps-mcp",
      "env": { "HOSTINGER_API_TOKEN": "ACCT_B_TOKEN" }
    }
  }
}
```

- [ ] **Step 5: `README.md`** — house style (mirror cloudways README header exactly):

```markdown
# Hostinger MCP — Claude Code & OpenClaw Skill

[![CI](https://github.com/Digitizers/hostinger-mcp/actions/workflows/ci.yml/badge.svg)](https://github.com/Digitizers/hostinger-mcp/actions/workflows/ci.yml)
![Claude Code Skill](https://img.shields.io/badge/Claude_Code-Skill-d97757)
![OpenClaw Skill](https://img.shields.io/badge/OpenClaw-Skill-purple)
![Hostinger](https://img.shields.io/badge/Hostinger-MCP-673de6)
![License: MIT](https://img.shields.io/badge/License-MIT-green)
![Version](https://img.shields.io/badge/version-1.0.0-blue)

A production-grade **Claude Code & OpenClaw skill** for managing [Hostinger](https://www.hostinger.com/) infrastructure — VPS, websites, domains, DNS, email (Reach), and billing — through the official **Hostinger MCP server**, across one or many accounts, with a safety rule on every write.

This is not just a tool reference. It is an operational playbook for running Hostinger responsibly: category-scoped tool loading (so you never drown in 127 tools at once), VPS provisioning and lifecycle, domain/DNS changes, and money-spending guardrails — with write-confirmation on anything that changes state or costs money.

## Features

- ✅ **Official Hostinger MCP** — the npm `hostinger-api-mcp` server (Node 24+), stdio or HTTP.
- ✅ **Category-binary loading** — connect only `hostinger-vps-mcp` / `hostinger-dns-mcp` / … instead of all 127 tools; keep context lean.
- ✅ **Full tool catalog** — 127 tools across VPS, hosting, domains, DNS, Reach, and billing, tagged R / W / W!.
- ✅ **Write- and cost-confirmation safety** — state-changing and money-spending operations require explicit, account-scoped confirmation; destructive ops double-confirm.
- ✅ **Multi-account** — one connection per account/token, each with its own prefix; no cross-account mixing.
- ✅ **VPS playbook** — provision, lifecycle, firewall, recreate/snapshots, projects.

## Structure

(structure tree of `.claude/skills/hostinger-mcp/` — copy the layout from the File Structure section of the plan)

## Activation

The skill activates when Hostinger is discussed and a `hostinger-*` MCP server is connected (tools appear as `mcp__hostinger*__*`). For setup — see [`installation.md`](.claude/skills/hostinger-mcp/references/installation.md) and [`.mcp.json.example`](.mcp.json.example). Install with `npm i -g hostinger-api-mcp`; authenticate with a `HOSTINGER_API_TOKEN` from hPanel.

## Sources

- [hostinger/api-mcp-server](https://github.com/hostinger/api-mcp-server) (official MCP server)
- [Hostinger API docs](https://developers.hostinger.com/)

## Links

- **Repository:** https://github.com/Digitizers/hostinger-mcp
- **OpenClaw:** https://openclaw.ai
- **Hostinger:** https://www.hostinger.com/
- **Digitizer:** https://www.digitizer.studio

## License

MIT

---

Built with ❤️ for OpenClaw by [Digitizer](https://www.digitizer.studio)
```

- [ ] **Step 6: `CHANGELOG.md`**

```markdown
# Changelog

## 1.0.0 - 2026-06-04
- First public cut: skill wrapping the official Hostinger MCP server (hostinger/api-mcp-server). Category-binary tool loading, full 127-tool catalog (7 categories, R/W/W!), VPS workflow playbook, multi-account (token per connection), write/cost-confirmation safety. Kit-standard packaging (CI + ClawHub publish workflow, no-leak guard).
```

- [ ] **Step 7: Validate JSON + commit**

```bash
python3 -c "import json;json.load(open('.mcp.json.example'));print('valid JSON ✓')"
git add README.md LICENSE package.json CHANGELOG.md .gitignore .mcp.json.example
git commit -m "chore: repo furniture (README house style, LICENSE, package, changelog, mcp example)"
```

---

## Task 7: CI + ClawHub publish workflows

**Files:**
- Create: `.github/workflows/ci.yml`, `.github/workflows/publish-clawhub.yml`
- Reference: copy from `/Users/digitizer/Documents/GitHub/cloudways-mcp/.github/workflows/` and adapt paths/slug/name.

- [ ] **Step 1: `ci.yml`** — copy cloudways `ci.yml`, change `SKILL: .claude/skills/hostinger-mcp/SKILL.md`, keep the three steps (frontmatter lint, reference-link check, no-leak guard). Use the **relaxed** no-leak guard form (payload studio-neutral, README brand allowed):

```yaml
      - name: No-leak guard
        run: |
          if grep -rniE "digitizer|דיגיטייזר|Ben/Avi" .claude/; then
            echo "::error::studio framing / personal names in the skill payload — keep .claude/ generic"; exit 1
          fi
          if grep -rniE "Ben/Avi|benkalsky" README.md; then
            echo "::error::personal name in README — use the studio brand, not personal names"; exit 1
          fi
          if grep -rniE "(api[_-]?key|bearer|secret|password|token)[\"'[:space:]=:]+[A-Za-z0-9/_-]{24,}" .claude/ \
             | grep -viE "your-|YOUR_|ACCT_[AB]|example|<|\$\{|placeholder|HOSTINGER_API_TOKEN"; then
            echo "::error::possible real secret found"; exit 1
          fi
          echo "no-leak guard passed"
```

- [ ] **Step 2: `publish-clawhub.yml`** — copy cloudways `publish-clawhub.yml`, set `SKILL_DIR: .claude/skills/hostinger-mcp`, and the publish line:

```bash
clawhub skill publish "$SKILL_DIR" --slug hostinger-mcp --name "Hostinger MCP" --version "${{ steps.ver.outputs.version }}"
```

(and the matching dry-run echo line).

- [ ] **Step 3: Lint the YAML locally**

```bash
python3 -c "import yaml,glob; [yaml.safe_load(open(f)) for f in glob.glob('.github/workflows/*.yml')]; print('yaml OK')"
```

Expected: `yaml OK`.

- [ ] **Step 4: Commit**

```bash
git add .github/workflows/
git commit -m "ci: frontmatter/ref-link/no-leak guard + ClawHub publish workflow"
```

---

## Task 8: Full validation, push, PR

- [ ] **Step 1: Run all CI replicas locally**

```bash
SKILL=.claude/skills/hostinger-mcp/SKILL.md
# frontmatter
python3 - <<PY
import re,pathlib
t=pathlib.Path("$SKILL").read_text(); m=re.match(r'^---\n(.*?)\n---\n',t,re.S); assert m
for k in ("name","description","version"): assert re.search(rf'^{k}:\s*\S',m.group(1),re.M),k
print("frontmatter OK")
PY
# reference links exist
python3 - <<PY
import re,pathlib
s=pathlib.Path("$SKILL"); base=s.parent
refs=set(re.findall(r'references/[A-Za-z0-9_-]+\.md',s.read_text()))
miss=[r for r in refs if not (base/r).exists()]; assert not miss,miss
print(f"references OK ({len(refs)})")
PY
# no-leak (payload generic, README brand allowed)
grep -rniE "digitizer|דיגיטייזר|Ben/Avi" .claude/ && echo "PAYLOAD LEAK" || echo "payload clean"
grep -rniE "Ben/Avi|benkalsky" README.md && echo "README NAME LEAK" || echo "README clean"
# json
python3 -c "import json;json.load(open('.mcp.json.example'));print('json OK')"
```

Expected: frontmatter OK · references OK (3) · payload clean · README clean · json OK.

- [ ] **Step 2: Push + open PR**

```bash
git push -u origin feat/initial-skill
gh pr create --base main --head feat/initial-skill \
  --title "feat: hostinger-mcp skill (v1.0.0)" \
  --body "Public Claude Code & OpenClaw skill wrapping the official Hostinger MCP server. Category-binary loading, 127-tool catalog (7 categories), VPS playbook, multi-account, write/cost-confirmation safety, kit-standard packaging.

🤖 Generated with [Claude Code](https://claude.com/claude-code)"
```

- [ ] **Step 3: Confirm CI green**

```bash
sleep 25; gh pr checks 1
```

Expected: the `skill` (CI) check passes.

- [ ] **Step 4: Report** — PR URL + CI status to the user. Do NOT merge or publish to ClawHub without explicit user go (the publish is an irreversible outward step; the token is the user's to add as a repo/org secret).

---

## Notes for the executor

- **Never invent tool names.** Everything in the catalog and workflows must trace to `/tmp/hostinger-tools.txt` (Task 1). If Task 1 can't produce the list, stop and report.
- **Read the cloudways-mcp counterparts** for exact voice/structure before writing each file — this skill should read identically in tone.
- **Commit trailer:** end commits with `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.
- **Do not add the CLAWHUB_TOKEN, flip anything public, or run the publish** — repo is already public; publishing is a later, user-gated ops step.
