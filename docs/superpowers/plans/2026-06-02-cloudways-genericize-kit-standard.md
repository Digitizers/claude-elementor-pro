# cloudways-mcp Genericize + Kit-standard (SP1) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Make cloudways-mcp generic + kit-standard (CI, version, CHANGELOG, ClawHub workflow) so it's publish-ready. No publishing (that's SP2).

**Architecture:** Genericize the 5 skill files (strip "Digitizer"/names, keep technical + generic security guidance); relocate the internal bits to digitizer-os; add packaging + a CI "no-leak guard" that fails if Digitizer/names/secret-patterns reappear.

**Repos/branches:** `Digitizers/cloudways-mcp` branch `feat/genericize-kit-standard`; a small commit to `Digitizers/digitizer-os` (branch `feat/cloudways-internal-note`).

---

## Task 0: Branch (cloudways-mcp)

```bash
cd /Users/digitizer/Documents/GitHub/cloudways-mcp
git checkout main && git pull --ff-only
git checkout -b feat/genericize-kit-standard
```

---

## Task 1: Genericize the 5 skill files

**Files:** `README.md`, `.claude/skills/cloudways-mcp/SKILL.md`, `.claude/skills/cloudways-mcp/references/{installation,workflows-onboarding,workflows-automation}.md`

- [ ] **Step 1: Replace the Digitizer framing**

Apply these content-anchored replacements (keep all surrounding technical text):

- SKILL.md L20 `> **הקשר Digitizer:** הסקיל נבנה כדי לתמוך בעבודה היומיומית של ניהול לקוחות על Cloudways`
  → `> **הקשר:** הסקיל בנוי לעבודה יומיומית של ניהול לקוחות/סביבות על Cloudways` (keep the rest of the line, incl. the USD-not-₪ note).
- SKILL.md L125 `ל-Digitizer יש **כמה חשבונות Cloudways**` → `לרוב יש **כמה חשבונות Cloudways**`.
- README.md L8 `הסקיל בנוי לעבודה היומיומית של Digitizer:` → `הסקיל בנוי לעבודה יומיומית של ניהול תשתית:`.
- installation.md L125 `> **הקשר Digitizer:** הקשר ישיר ל-Infisical / OpenBao שאתה בודק —`
  → `> **טיפ אבטחה:** `ENCRYPTION_KEY` הוא בדיוק הסוג של secret שכדאי לשמור ב-vault (Infisical / OpenBao / 1Password), לא ב-`.env` plain text.` (drop "שאתה בודק").
- installation.md L209 `ל-Digitizer יש **כמה חשבונות Cloudways**.` → `נניח שיש **כמה חשבונות Cloudways**.`
- workflows-onboarding.md L1 `# Workflows — Onboarding & Audit (Digitizer client takeover)` → `# Workflows — Onboarding & Audit (agency client takeover)`.
- workflows-onboarding.md L3 `תרחיש מרכזי ל-Digitizer: לקוח חדש` → `תרחיש מרכזי: לקוח חדש`.
- workflows-onboarding.md L133 `**המלצה סטנדרטית של Digitizer:**` → `**המלצה סטנדרטית:**`.
- workflows-onboarding.md L179 `Auditor: Digitizer (Ben/Avi)` → `Auditor: [your name]`.
- workflows-automation.md L3 `בנוי במיוחד ל-Digitizer stack.` → `מתאים לכל stack של ניהול תשתית.`
- workflows-automation.md L58 `## 2. n8n workflows (Digitizer stack)` → `## 2. n8n workflows`.
- workflows-automation.md L128 `ה-Make.com Custom App של Digitizer (אם בנוי)` → `Make.com Custom App ייעודי (אם בנוי)`.
- workflows-automation.md L268 `אם Digitizer מנהל מספר חשבונות Cloudways` → `אם אתה מנהל מספר חשבונות Cloudways`.

(Use the exact source strings via Read/Edit or a python replace; verify each anchor exists before replacing.)

- [ ] **Step 2: Verify zero leakage**

Run:
```bash
grep -rniE "digitizer|דיגייזר|דיגיטייזר|\(Ben/Avi\)|Ben/Avi" .claude/ README.md ; echo "exit=$?"
```
Expected: no matches (`exit=1` from grep). If any remain, fix them.

- [ ] **Step 3: Commit**

```bash
git add README.md .claude
git commit -m "refactor(skill): genericize — remove Digitizer-specific framing + names"
```

---

## Task 2: Relocate the internal note (digitizer-os)

**Files:** `Digitizers/digitizer-os` — `digitizer-os/knowledge/studio-toolbox.md`

- [ ] **Step 1: Branch + add the note**

```bash
cd /Users/digitizer/Documents/GitHub/digitizer-os
git checkout main && git pull --ff-only
git checkout -b feat/cloudways-internal-note
```

Append to `digitizer-os/knowledge/studio-toolbox.md` (after the Notes section):

```markdown
## Cloudways ops (internal)

- We use **cloudways-mcp** for client **takeover/onboarding audits** — build a full
  picture of a new client's Cloudways setup before committing (servers, apps, SSL,
  disk, backups).
- **Per-client secrets** live in **separate Infisical/OpenBao projects** — never all
  keys in one `.env`. Multi-account = one MCP connection per client account.
- The public cloudways-mcp skill is generic; this is the studio-specific context.
```

- [ ] **Step 2: Commit + push + PR**

```bash
git add digitizer-os/knowledge/studio-toolbox.md
git commit -m "feat(os): capture cloudways internal ops context (relocated from public skill)"
git push -u origin feat/cloudways-internal-note
gh pr create --repo Digitizers/digitizer-os --base main --head feat/cloudways-internal-note \
  --title "feat: cloudways ops internal note" \
  --body "Captures the studio-specific cloudways context (client-takeover use, per-client Infisical projects) relocated from the now-generic public cloudways-mcp skill."
```

---

## Task 3: Kit-standard packaging (cloudways-mcp)

**Files:** `.claude/skills/cloudways-mcp/SKILL.md`, `package.json`, `CHANGELOG.md`, `.github/workflows/ci.yml`, `.github/workflows/publish-clawhub.yml`

- [ ] **Step 1: SKILL.md version + package.json + CHANGELOG**

Add `version: 1.0.0` to the SKILL.md frontmatter (after `name:`). Create `package.json`:

```json
{
  "name": "cloudways-mcp",
  "version": "1.0.0",
  "description": "Operational Claude skill for managing Cloudways infrastructure via the Cloudways MCP server (multi-account, monitoring, maintenance, audit, write-confirmation safety).",
  "private": false,
  "license": "MIT",
  "files": [".claude/skills/cloudways-mcp"]
}
```

Create `CHANGELOG.md`:

```markdown
# Changelog

## 1.0.0 - 2026-06-02
- First public-ready cut: genericized (removed studio-specific framing), kit-standard packaging (CI + ClawHub publish workflow), no-leak CI guard.
```

- [ ] **Step 2: CI workflow**

Create `.github/workflows/ci.yml`:

```yaml
name: CI

on:
  push:
    branches: [ main ]
  pull_request:

jobs:
  skill:
    runs-on: ubuntu-latest
    env:
      SKILL: .claude/skills/cloudways-mcp/SKILL.md
    steps:
      - uses: actions/checkout@v4

      - name: SKILL frontmatter lint
        run: |
          python3 - <<'PY'
          import re, pathlib, os
          p = pathlib.Path(os.environ["SKILL"]).read_text()
          m = re.match(r'^---\n(.*?)\n---\n', p, re.S)
          assert m, "missing frontmatter"
          fm = m.group(1)
          for k in ("name", "description", "version"):
              mm = re.search(rf'^{k}:\s*(.+)$', fm, re.M)
              assert mm and mm.group(1).strip(), f"frontmatter missing non-empty {k}"
          print("frontmatter OK")
          PY

      - name: Reference links exist
        run: |
          python3 - <<'PY'
          import re, pathlib, os
          skill = pathlib.Path(os.environ["SKILL"])
          base = skill.parent
          refs = re.findall(r'references/[A-Za-z0-9_-]+\.md', skill.read_text())
          missing = [r for r in set(refs) if not (base / r).exists()]
          assert not missing, f"missing referenced files: {missing}"
          print(f"references OK ({len(set(refs))} linked)")
          PY

      - name: No-leak guard
        run: |
          # Fail if studio-specific framing, personal names, or secret-shaped
          # strings reappear in the skill payload (this repo is heading public).
          if grep -rniE "digitizer|דיגיטייזר|Ben/Avi" .claude/ README.md; then
            echo "::error::studio-specific framing / names found — genericize before merge"; exit 1
          fi
          if grep -rniE "(api[_-]?key|bearer|secret|password)[\"'[:space:]=:]+[A-Za-z0-9/_-]{24,}" .claude/ \
             | grep -viE "your-|YOUR_|CLIENT_[AB]|example|<|\$\{|placeholder"; then
            echo "::error::possible real secret found"; exit 1
          fi
          echo "no-leak guard passed"
```

- [ ] **Step 3: ClawHub publish workflow (dormant until SP2)**

Create `.github/workflows/publish-clawhub.yml` — copy of wordpress-api-pro's, changing
only the skill dir + version path:

```yaml
name: Publish to ClawHub

on:
  release:
    types: [published]
  workflow_dispatch:
    inputs:
      dry_run:
        description: "Build the publish plan without uploading"
        type: boolean
        default: true

permissions:
  contents: read

concurrency:
  group: clawhub-publish
  cancel-in-progress: false

jobs:
  publish:
    name: Publish skill
    runs-on: ubuntu-latest
    env:
      SKILL_DIR: .claude/skills/cloudways-mcp
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: "22"
      - name: Install ClawHub CLI
        run: npm i -g clawhub
      - name: Read skill version from SKILL.md
        id: ver
        run: |
          VERSION=$(grep -m1 '^version:' "$SKILL_DIR/SKILL.md" | sed 's/^version:[[:space:]]*//' | tr -d '"' | tr -d "'" | xargs)
          [ -n "$VERSION" ] || { echo "::error::no version in $SKILL_DIR/SKILL.md"; exit 1; }
          echo "version=$VERSION" >> "$GITHUB_OUTPUT"
      - name: Authenticate
        env:
          CLAWHUB_TOKEN: ${{ secrets.CLAWHUB_TOKEN }}
        run: |
          [ -n "$CLAWHUB_TOKEN" ] || { echo "::error::CLAWHUB_TOKEN secret not set"; exit 1; }
          clawhub login --token "$CLAWHUB_TOKEN"
      - name: Publish
        env:
          DRY_RUN: ${{ github.event_name == 'workflow_dispatch' && inputs.dry_run || 'false' }}
        run: |
          if [ "$DRY_RUN" = "true" ]; then
            echo "Dry run — would publish: clawhub skill publish $SKILL_DIR --version ${{ steps.ver.outputs.version }}"
            exit 0
          fi
          clawhub skill publish "$SKILL_DIR" --version "${{ steps.ver.outputs.version }}"
```

- [ ] **Step 4: Verify locally + commit**

Run:
```bash
SKILL=.claude/skills/cloudways-mcp/SKILL.md
python3 -c "import re,pathlib;p=pathlib.Path('$SKILL').read_text();m=re.match(r'^---\n(.*?)\n---\n',p,re.S);assert m;[__import__('sys').exit('missing '+k) for k in ('name','description','version') if not re.search(rf'^{k}:\s*(.+)$',m.group(1),re.M)];print('frontmatter ok')"
python3 -c "import json;json.load(open('package.json'));print('package.json ok')"
grep -rniE "digitizer|Ben/Avi" .claude/ README.md && echo "LEAK" || echo "no-leak ok"
git add .claude package.json CHANGELOG.md .github
git commit -m "chore(skill): kit-standard — version 1.0.0, CI no-leak guard, ClawHub workflow"
```

- [ ] **Step 5: Push + PR**

```bash
git push -u origin feat/genericize-kit-standard
gh pr create --repo Digitizers/cloudways-mcp --base main --head feat/genericize-kit-standard \
  --title "Genericize + kit-standard (publish-ready)" \
  --body "$(cat <<'EOF'
Makes cloudways-mcp generic + kit-standard so it's publish-ready (flipping to public + publishing is a separate gated step).

- **Genericized**: removed all Digitizer-specific framing + personal names from the 5 skill files (technical content + generic security guidance kept; Infisical/OpenBao remain as vault examples). Internal context relocated to the private brain (digitizer-os).
- **Kit-standard**: `version: 1.0.0`, `package.json`, `CHANGELOG.md`, CI (frontmatter lint + reference-link check + **no-leak guard** that fails if Digitizer/names/secret-patterns reappear), and a ClawHub publish workflow (dormant until the repo is public + `CLAWHUB_TOKEN` is set).

Audit: no real secrets/keys/clients in tree or history — placeholders only.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

Watch CI: `gh pr checks --watch`.

---

## Self-Review notes (author)

- **Spec coverage:** genericize 5 files + names (Task 1) ✓; relocate internal note (Task 2) ✓; version/package/CHANGELOG (Task 3.1) ✓; CI frontmatter+reflinks+no-leak guard (Task 3.2) ✓; dormant ClawHub workflow (Task 3.3) ✓; verification incl. the guard (Task 3.4) ✓; SP2 (publish) explicitly out ✓.
- **Placeholder scan:** exact replacement strings + full workflow/JSON content given.
- **Type consistency:** `SKILL_DIR=.claude/skills/cloudways-mcp` consistent across CI + publish; version `1.0.0` in SKILL frontmatter + package.json + CHANGELOG.
- **Security note:** the no-leak guard is both the verification AND a standing protection as the repo heads public.
