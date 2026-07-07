# Studio Toolbox Hub — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Make digitizer-os the toolbox hub — an accurate catalog of the 5 flagship studio tools + a client-lifecycle router mapping each stage to the right tool(s). Route-only (the brain knows + points; no engine rewiring).

**Architecture:** Two new knowledge docs (`studio-toolbox.md` catalog, `client-lifecycle.md` router) + a `studio_flagship_tools` block added to `tools-and-repos.json` + SKILL.md Quick Route/Rules pointing at them. All inside `Digitizers/digitizer-os`. No runtime code.

**Repo / branch:** `/Users/digitizer/Documents/GitHub/digitizer-os`, branch `feat/toolbox-hub` off `main`. Remote `Digitizers/digitizer-os` (private). Knowledge docs live under `digitizer-os/knowledge/`.

---

## File Structure

- Create `digitizer-os/knowledge/studio-toolbox.md` — flagship-tool catalog.
- Create `digitizer-os/knowledge/client-lifecycle.md` — stage→tool router.
- Modify `digitizer-os/knowledge/tools-and-repos.json` — add `studio_flagship_tools`.
- Modify `SKILL.md` — Quick Route rows + a Rules line.

---

## Task 0: Branch

```bash
cd /Users/digitizer/Documents/GitHub/digitizer-os
git checkout main && git pull --ff-only
git checkout -b feat/toolbox-hub
```

---

## Task 1: `studio-toolbox.md`

**Files:** Create `digitizer-os/knowledge/studio-toolbox.md`

- [ ] **Step 1: Write the catalog**

Intro line: "The studio's OWN built tools. Route here before deciding how to deliver
— know the arsenal first." Then the table (from the spec) with columns
`Tool | Repo | What it does | When to use | Status`, covering the 5:
siteagent-elementor-studio, wordpress-api-pro, elementor-mcp (fork), cloudways-mcp,
digitizer-os. Add per-tool "key capabilities" bullets under the table and the status
notes (elementor-mcp fork = the engine behind elementor-pro; cloudways-mcp = new,
MCP server availability uncertain). Each tool name must appear verbatim.

- [ ] **Step 2: Validate**

```bash
python3 - <<'PY'
import pathlib
md = pathlib.Path("digitizer-os/knowledge/studio-toolbox.md").read_text()
for t in ["siteagent-elementor-studio","wordpress-api-pro","elementor-mcp","cloudways-mcp","digitizer-os"]:
    assert t in md, f"missing tool {t}"
print("toolbox catalog ok (5 tools)")
PY
```
Expected: `toolbox catalog ok (5 tools)`.

- [ ] **Step 3: Commit**

```bash
git add digitizer-os/knowledge/studio-toolbox.md
git commit -m "feat(os): add studio toolbox catalog (5 flagship tools)"
```

---

## Task 2: `client-lifecycle.md`

**Files:** Create `digitizer-os/knowledge/client-lifecycle.md`

- [ ] **Step 1: Write the router**

Intro: "End-to-end client flow → which tool runs each stage. Read with
`studio-toolbox.md`." Then the 8-stage table (from spec): Lead/qualify · Pre-sale
audit · Proposal/pricing · Onboard · Brand setup · Build · Content/SEO/dynamic data ·
Host/monitor/maintain — each mapped to its tool(s) + a one-line handoff note. Every
stage maps to ≥1 named tool.

- [ ] **Step 2: Validate**

```bash
python3 - <<'PY'
import pathlib
md = pathlib.Path("digitizer-os/knowledge/client-lifecycle.md").read_text()
stages = ["Lead","audit","Proposal","Onboard","Brand","Build","Content","Host"]
miss = [s for s in stages if s not in md]
assert not miss, f"missing stages: {miss}"
for t in ["siteagent-elementor-studio","wordpress-api-pro","cloudways-mcp","digitizer-os"]:
    assert t in md, f"lifecycle missing tool {t}"
print(f"lifecycle ok ({len(stages)} stages)")
PY
```
Expected: `lifecycle ok (8 stages)`.

- [ ] **Step 3: Commit**

```bash
git add digitizer-os/knowledge/client-lifecycle.md
git commit -m "feat(os): add client-lifecycle router (stage -> tool)"
```

---

## Task 3: Refresh `tools-and-repos.json`

**Files:** Modify `digitizer-os/knowledge/tools-and-repos.json`

- [ ] **Step 1: Add `studio_flagship_tools` block**

Insert a top-level `"studio_flagship_tools"` key (after `"installed_skills"`), an
object keyed by tool name, each `{repo, role, status}`, plus a
`"_canonical": "knowledge/studio-toolbox.md"` pointer. Do not delete existing keys.

```json
  "studio_flagship_tools": {
    "_canonical": "knowledge/studio-toolbox.md",
    "siteagent-elementor-studio": { "repo": "Digitizers/siteagent-elementor-studio", "role": "Build Elementor sites via MCP — Pro/V4 detect, brand-kit tokens, 10 recipes, new-client onboarding", "status": "active" },
    "wordpress-api-pro":    { "repo": "Digitizers/wordpress-api-pro", "role": "WP REST ops — content/SEO/media/ACF/Jet/WooCommerce + CPT seeding", "status": "active" },
    "elementor-mcp":        { "repo": "Digitizers/elementor-mcp", "role": "The MCP plugin (fork) — V4/atomic detect+save+styling fixes; engine behind siteagent-elementor-studio", "status": "active" },
    "cloudways-mcp":        { "repo": "Digitizers/cloudways-mcp", "role": "Cloudways hosting ops via MCP — multi-account, monitoring, maintenance, audit", "status": "new; MCP server availability uncertain (cw-mcp 404 / official Q2 2026)" },
    "digitizer-os":         { "repo": "Digitizers/digitizer-os", "role": "This brain — strategy/sales/pricing/services/delivery/growth", "status": "active" }
  },
```

- [ ] **Step 2: Validate JSON parses + block present**

```bash
python3 - <<'PY'
import json, pathlib
d = json.loads(pathlib.Path("digitizer-os/knowledge/tools-and-repos.json").read_text())
assert "studio_flagship_tools" in d
assert set(["siteagent-elementor-studio","wordpress-api-pro","elementor-mcp","cloudways-mcp","digitizer-os"]) <= set(d["studio_flagship_tools"])
assert "installed_skills" in d  # existing data preserved
print("json ok")
PY
```
Expected: `json ok`.

- [ ] **Step 3: Commit**

```bash
git add digitizer-os/knowledge/tools-and-repos.json
git commit -m "feat(os): catalog flagship tools in tools-and-repos.json"
```

---

## Task 4: SKILL.md routing

**Files:** Modify `SKILL.md`

- [ ] **Step 1: Add Quick Route rows**

In the `## Quick Route` table, add these two rows (after the last existing row):

```markdown
| Which tool for X / what can we deliver / our own tools | `knowledge/studio-toolbox.md` |
| Run the full client flow / onboarding sequence / stage→tool | `knowledge/client-lifecycle.md` |
```

- [ ] **Step 2: Add a Rules line**

In the `## Rules` list, add:

```markdown
- For delivery / "how do we execute this" / "which tool" questions, consult `knowledge/studio-toolbox.md` (the arsenal) and `knowledge/client-lifecycle.md` (stage→tool) before answering.
```

- [ ] **Step 3: Frontmatter intact + routes present**

```bash
python3 - <<'PY'
import re, pathlib
p = pathlib.Path("SKILL.md").read_text()
assert re.match(r'^---\n.*?\n---\n', p, re.S), "frontmatter"
assert "knowledge/studio-toolbox.md" in p and "knowledge/client-lifecycle.md" in p
print("skill routes ok")
PY
```
Expected: `skill routes ok`.

- [ ] **Step 4: Commit**

```bash
git add SKILL.md
git commit -m "feat(os): route to toolbox catalog + client-lifecycle"
```

---

## Task 5: Push + PR

```bash
git push -u origin feat/toolbox-hub
gh pr create --repo Digitizers/digitizer-os --base main --head feat/toolbox-hub \
  --title "feat: studio toolbox hub (catalog + client-lifecycle router)" \
  --body "$(cat <<'EOF'
## What
Makes digitizer-os the hub that knows the studio's own tools and routes the client lifecycle.

- `knowledge/studio-toolbox.md` — catalog of the 5 flagship tools (siteagent-elementor-studio, wordpress-api-pro, elementor-mcp fork, cloudways-mcp, digitizer-os): what each does, when to use, status.
- `knowledge/client-lifecycle.md` — stage→tool router: lead → audit → proposal → onboard → brand → build → content/SEO → host/monitor.
- `tools-and-repos.json` — adds a `studio_flagship_tools` block (existing data preserved), pointing to the catalog as canonical.
- `SKILL.md` — Quick Route + Rules now route "which tool / how do we deliver / full client flow" to the two docs.

## Scope
Route-only: the brain knows + points. Engine rewiring (audit→tools) and cloudways-mcp kit-standard are separate follow-ups.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

If `gh`/CI absent on this private repo, push the branch and report the compare URL.

---

## Self-Review notes (author)

- **Spec coverage:** catalog (Task 1) ✓; lifecycle router (Task 2) ✓; JSON refresh preserving data (Task 3) ✓; SKILL routing (Task 4) ✓; verification = the per-task python checks ✓; non-goals (route-only, no engine rewiring, digitizer-os-only) honored ✓.
- **Placeholder scan:** the JSON block is literal; the two docs' content is sourced from the spec's tables (Task 1/2 specify exact tools + stages).
- **Type consistency:** the 5 tool names + 8 stage names are identical across the catalog, lifecycle, JSON block, and validation checks.
