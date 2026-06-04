# claude-elementor-pro Studio-Layer Reshape — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reshape `claude-elementor-pro` into the studio's Elementor capability anchored on our fork engine — slim the 872-line SKILL via progressive-disclosure references, add 5 studio verticals, lifecycle glue, an engine-vs-Premium doc, and a simplified single-plugin install.

**Architecture:** A Claude skill repo (markdown + bash installers). The build SKILL stays here (the fork bundles no skill). Work is mostly relocating content into `files/references/` + adding new reference docs + fixing the installers to (a) copy the `references/` tree and (b) install our fork (not the 4.x-broken free upstream). No application code; verification is content-preservation diffs, link-resolve checks, and the repo's bats/shell CI.

**Tech Stack:** Markdown, Bash (`INSTALL.sh`/`.bat`/`.ps1`, `setup-elementor-mcp.sh`, `new-client.sh`), bats tests.

**Spec:** `docs/superpowers/specs/2026-06-04-claude-elementor-pro-studio-layer-design.md`

---

## File structure (after reshape)

```
files/
├── SKILL.md                     # slimmed core (decision spine + pointers)
├── setup-elementor-mcp.sh       # single-plugin install (fork bundles the adapter)
└── references/
    ├── forms.md                 # NEW (extracted ## Forms)
    ├── dynamic-data.md          # NEW (extracted ## Dynamic data stacks)
    ├── pro-widgets.md           # NEW (extracted ## Pro-only widgets & features)
    ├── header-footer.md         # NEW (extracted ## Header/Footer notes)
    ├── atomic-v4.md             # NEW (extracted ## Building on Elementor 4)
    ├── recipes.md               # exists
    ├── brand-kit.md             # exists
    ├── engine-and-premium.md    # NEW
    ├── lifecycle.md             # NEW
    └── verticals/{dental,salon,car-wash,local-business,portfolio}.md  # NEW
INSTALL.sh / INSTALL.bat / INSTALL.ps1   # MODIFY: also copy references/ tree
new-client.sh                            # MODIFY: install the fork, drop separate adapter
docs/WHATS_INSTALLED.md                  # MODIFY: single-plugin + references note
```

**Branch:** create `feat/studio-layer` off `main` for all tasks.

```bash
cd /Users/digitizer/Documents/GitHub/claude-elementor-pro
git checkout main && git pull --ff-only
git checkout -b feat/studio-layer
```

---

## Task 1: Make installers copy the `references/` tree (prerequisite)

Progressive disclosure is useless if the references aren't installed next to SKILL.md. Today `INSTALL.sh` copies only `SKILL.md`. Fix all three installers.

**Files:**
- Modify: `INSTALL.sh` (after the SKILL.md copy block, ~line 60)
- Modify: `INSTALL.bat`, `INSTALL.ps1` (mirror the change)

- [ ] **Step 1: Read the current copy logic**

```bash
sed -n '20,90p' INSTALL.sh
```
Note `SRC_FILES` (source `files/` dir) and `SKILL_DIR="$HOME/.claude/skills/elementor-mcp"`.

- [ ] **Step 2: Add a references copy to INSTALL.sh**

After the block that installs `SKILL.md` (the `cp "$SRC_FILES/SKILL.md" "$SKILL_DIR/SKILL.md"` lines), insert:

```bash
# Install the reference docs (progressive disclosure — SKILL.md points to these)
if [ -d "$SRC_FILES/references" ]; then
  mkdir -p "$SKILL_DIR/references"
  cp -R "$SRC_FILES/references/." "$SKILL_DIR/references/"
  ok "Installed references/ ($(find "$SRC_FILES/references" -name '*.md' | wc -l | tr -d ' ') docs)"
fi
```

- [ ] **Step 3: Mirror in INSTALL.bat and INSTALL.ps1**

In `INSTALL.ps1`, after the SKILL.md copy:
```powershell
$refsSrc = Join-Path $SrcFiles "references"
if (Test-Path $refsSrc) {
  $refsDst = Join-Path $SkillDir "references"
  New-Item -ItemType Directory -Force -Path $refsDst | Out-Null
  Copy-Item -Recurse -Force (Join-Path $refsSrc "*") $refsDst
  Ok "Installed references/"
}
```
In `INSTALL.bat`, after the SKILL.md copy:
```bat
if exist "%SRC_FILES%\references" (
  if not exist "%SKILL_DIR%\references" mkdir "%SKILL_DIR%\references"
  xcopy /E /I /Y "%SRC_FILES%\references" "%SKILL_DIR%\references" >nul
  echo Installed references/
)
```
(Match each file's existing variable names — read the file first; the names above are indicative.)

- [ ] **Step 4: Verify INSTALL.sh syntax + dry behavior**

```bash
bash -n INSTALL.sh && echo "syntax OK"
# Simulate into a temp HOME:
TMPH=$(mktemp -d); HOME="$TMPH" bash INSTALL.sh </dev/null >/dev/null 2>&1 || true
find "$TMPH/.claude/skills/elementor-mcp" -type f | sed "s#$TMPH##"
```
Expected: lists `SKILL.md` AND `references/recipes.md`, `references/brand-kit.md` (the refs that exist today). Clean up: `rm -rf "$TMPH"`.

- [ ] **Step 5: Commit**

```bash
git add INSTALL.sh INSTALL.bat INSTALL.ps1
git commit -m "$(printf 'fix(install): copy references/ tree so SKILL pointers resolve\n\nCo-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>')"
```

---

## Task 2: Slim SKILL.md — extract 5 sections to references (no content loss)

Relocate, don't rewrite. Each extracted block is moved verbatim; the SKILL section is replaced by a 2–4 line summary + pointer.

**Files:**
- Create: `files/references/atomic-v4.md`, `header-footer.md`, `pro-widgets.md`, `dynamic-data.md`, `forms.md`
- Modify: `files/SKILL.md`

**Extraction boundaries (heading → up to but excluding the next `##`):**
| Section heading in SKILL.md | Extract to | Ends before |
|---|---|---|
| `## Building on Elementor 4 (atomic / V4)` | `references/atomic-v4.md` | `## Brand kit — intake & tokens` |
| `## Header/Footer notes` | `references/header-footer.md` | `## Pro-only widgets & features` |
| `## Pro-only widgets & features` | `references/pro-widgets.md` | `## Dynamic data stacks` |
| `## Dynamic data stacks — ACF & Crocoblock/JetEngine (Tier-0)` | `references/dynamic-data.md` | `## Forms` |
| `## Forms` | `references/forms.md` | `## Setup gotchas (what bit me last time)` |

- [ ] **Step 1: Extract each section by heading into its reference file**

For EACH row, run an awk that captures from the start heading up to (excluding) the end heading, and write it to the ref file with a 1-line title prefix. Example for Forms:

```bash
cd /Users/digitizer/Documents/GitHub/claude-elementor-pro
awk '/^## Forms$/{f=1} /^## Setup gotchas \(what bit me last time\)$/{f=0} f' files/SKILL.md > /tmp/forms-block.md
{ echo "# Forms — Elementor MCP (reference)"; echo; cat /tmp/forms-block.md; } > files/references/forms.md
wc -l files/references/forms.md
```
Repeat with the exact headings for the other four (atomic-v4, header-footer, pro-widgets, dynamic-data). Use the precise heading text from the table (anchor `^## …$`).

- [ ] **Step 2: Verify each ref contains the full original block (no loss)**

```bash
for s in forms dynamic-data pro-widgets header-footer atomic-v4; do
  echo "== $s : $(wc -l < files/references/$s.md) lines =="
done
# Spot-check the Forms block's first/last real lines survived:
grep -c 'Fluent Forms' files/references/forms.md   # >0
grep -c 'Loop Grid' files/references/pro-widgets.md # >0
grep -c 'JetEngine' files/references/dynamic-data.md # >0
```

- [ ] **Step 3: Replace each section in SKILL.md with a summary + pointer**

Delete the original block from `files/SKILL.md` and put a stub in its place. Do this by rebuilding SKILL.md: keep everything, but for each of the 5 sections, replace the block with its stub. Concretely, use awk to drop each block and inject the stub. Stub texts:

`## Building on Elementor 4 (atomic / V4)`
```markdown
## Building on Elementor 4 (atomic / V4)

Elementor 4 uses an atomic/V4 data model — classic widget writes don't persist on a V4 page. Detect the engine first (see core detection above), then use the atomic tool family. **Full atomic model, tool family, and build order → load `references/atomic-v4.md`.**
```

`## Header/Footer notes`
```markdown
## Header/Footer notes

Theme Builder (Pro) is the preferred header/footer path; UAE/HFE is the free fallback. **Full patterns (Theme Builder vs UAE/HFE, nav menu, site-wide header/footer) → load `references/header-footer.md`.**
```

`## Pro-only widgets & features`
```markdown
## Pro-only widgets & features

When Pro is active, native widgets beat HTML: Loop Grid/Carousel, Popups, Dynamic Tags, Sticky header + Motion Effects. **Full per-feature guidance → load `references/pro-widgets.md`.**
```

`## Dynamic data stacks — ACF & Crocoblock/JetEngine (Tier-0)`
```markdown
## Dynamic data stacks — ACF & Crocoblock/JetEngine (Tier-0)

Bind ACF via Pro dynamic tags; place Jet widgets via `add-widget` with runtime-verified types. Tier-0 scope only. **Full ACF + Crocoblock/JetEngine guidance → load `references/dynamic-data.md`.**
```

`## Forms`
```markdown
## Forms

If Pro → native Form widget (preferred). If free → Fluent Forms (fallback). **Full form guidance (native Form settings, Fluent Forms class map, alternatives) → load `references/forms.md`.**
```

Implementation approach (per section): use awk to emit everything except the lines between the start heading and the end heading, inserting the stub where the block was. Verify after each that the file still parses and only that block changed.

- [ ] **Step 4: Verify SKILL.md shrank and pointers resolve**

```bash
wc -l files/SKILL.md   # expect well under 872 (~450-500)
# every references/*.md mentioned in SKILL.md must exist:
for r in $(grep -ohE 'references/[a-z0-9-]+\.md' files/SKILL.md | sort -u); do
  test -f "files/$r" && echo "OK  $r" || echo "MISSING $r"
done
# the 5 stubs are present:
for s in atomic-v4 header-footer pro-widgets dynamic-data forms; do grep -q "references/$s.md" files/SKILL.md && echo "stub→$s ok"; done
```
Expected: all `OK`, all stubs ok, no `MISSING`.

- [ ] **Step 5: Prove no mechanics were lost (union check)**

```bash
# Concatenate slimmed SKILL + all refs, confirm key phrases from the originals all survive somewhere:
cat files/SKILL.md files/references/*.md > /tmp/all.md
for phrase in 'Fluent Forms' 'Loop Grid' 'JetEngine' 'Theme Builder' 'add-flexbox' 'Dynamic Tags' 'Motion Effects' 'Popups'; do
  grep -q "$phrase" /tmp/all.md && echo "kept: $phrase" || echo "LOST: $phrase"
done
```
Expected: every phrase `kept`. If any `LOST`, the extraction dropped content — fix before committing.

- [ ] **Step 6: Commit**

```bash
git add files/SKILL.md files/references/forms.md files/references/dynamic-data.md files/references/pro-widgets.md files/references/header-footer.md files/references/atomic-v4.md
git commit -m "$(printf 'refactor(skill): slim SKILL.md via progressive-disclosure references\n\nMove Forms, dynamic-data, Pro-widgets, header/footer, and atomic-V4 sections\ninto files/references/*. SKILL.md keeps the decision spine + pointers.\nNo mechanics lost (union-checked).\n\nCo-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>')"
```

---

## Task 3: Engine-and-Premium doc + single-plugin install

**Files:**
- Create: `files/references/engine-and-premium.md`
- Modify: `files/SKILL.md` (add a short pointer in the setup section), `new-client.sh`, `files/setup-elementor-mcp.sh`, `docs/WHATS_INSTALLED.md`

- [ ] **Step 1: Write `files/references/engine-and-premium.md`**

```markdown
# Engine & the Premium plugin — what runs the build

**Engine = our fork `Digitizers/elementor-mcp` v1.9.0** (94 MCP tools, Elementor 4.x-correct).
It bundles the WordPress MCP Adapter, so it installs as a **single plugin** — no separate
adapter plugin needed.

## Do NOT run the paid "MCP Tools for Elementor (Premium)" (`emcp-pro`) at the same time

The fork and Premium are the same code lineage (same class names `Elementor_MCP_*`, same
constant `ELEMENTOR_MCP_VERSION`, no PHP namespace). Activating both = `Cannot redeclare class`
fatal. **Only one can be active.**

| | Premium `emcp-pro` 1.7.4 | fork `elementor-mcp` 1.9.0 |
|---|---|---|
| MCP tools | 76 | **94** |
| Elementor 4.x GA schema | ❌ 3.x (breaks on 4.1.1) | ✅ correct (PR #52) |
| Auto-update / license | ✅ Freemius | ❌ (snapshot) |
| Bundled prompts/skill | ✅ | ❌ (this skill is the guide) |

**We run the fork** — it is 4.x-correct and has more tools. Premium's real value is the license/
auto-update channel + its prompt/skill assets, not capability. Migrate to Premium only after the
4.x work lands upstream and Premium ships a 4.x release.

## Switching (one active at a time)

```bash
wp plugin deactivate elementor-mcp && wp plugin activate emcp-pro    # → Premium
wp plugin deactivate emcp-pro && wp plugin activate elementor-mcp    # → fork
```

Both share the options `elementor_mcp_disabled_tools` and `elementor_mcp_low_tool_mode` —
a low-tools/disabled-tools state set under one carries to the other.

## Production hygiene

Neither plugin should stay active on a client's **production** server — both are build-time
authoring tools. Deactivate (or remove) at handoff.
```

- [ ] **Step 2: Repoint `new-client.sh` at the fork + drop the separate adapter**

Read the install section:
```bash
sed -n '1,20p;190,230p' new-client.sh
```
Change the elementor-mcp download source from `msrbuilds/elementor-mcp` (free upstream, 4.x-broken) to our fork `Digitizers/elementor-mcp`. Find the line:
```bash
curl -sL -o "$WORK/em-src.zip" "$(dl msrbuilds/elementor-mcp)" || abort "elementor-mcp download failed"
```
Replace `msrbuilds/elementor-mcp` → `Digitizers/elementor-mcp`. Then remove the now-redundant **separate MCP Adapter** install (the fork bundles it): locate any `WP ... plugin install` step that fetches a standalone `mcp-adapter`/`McpAdapter` and delete it; update the header comment (line ~9 `Install the MCP Adapter + elementor-mcp plugins`) to `Install the elementor-mcp fork (bundles the MCP Adapter)`.

- [ ] **Step 3: Trim `files/setup-elementor-mcp.sh` similarly**

```bash
grep -nE 'mcp-adapter|McpAdapter|adapter|msrbuilds/elementor-mcp|Digitizers/elementor-mcp' files/setup-elementor-mcp.sh
```
If the interactive setup installs a separate MCP Adapter plugin, drop that step (fork bundles it). If it references the upstream source, point it at `Digitizers/elementor-mcp`. Keep app-password wiring + `.mcp.json` generation untouched.

- [ ] **Step 4: Add a one-line pointer + brand-voice note to SKILL.md**

In the SKILL.md setup/first-session area, add:
```markdown
> **Engine:** this skill drives our fork `Digitizers/elementor-mcp` (94 tools, 4.x-correct), a single self-contained plugin. **Never run it alongside the paid "MCP Tools for Elementor (Premium)" — same class names → fatal.** Details + switch commands → `references/engine-and-premium.md`.
```
And in the build-voice area, add a brief studio default (one or two lines), e.g.:
```markdown
**Studio voice default:** clean, confident, conversion-focused; real copy (no lorem); accessible contrast; consistent spacing scale. Per-client tone comes from the matched vertical (see `references/verticals/`).
```

- [ ] **Step 5: Update `docs/WHATS_INSTALLED.md`**

Reflect: single plugin (the fork, bundles the adapter), and that `references/` is installed beside SKILL.md. Read it first, then edit the plugin list + the installed-files map.

- [ ] **Step 6: Verify scripts still parse + commit**

```bash
bash -n new-client.sh && bash -n files/setup-elementor-mcp.sh && echo "scripts OK"
grep -q 'Digitizers/elementor-mcp' new-client.sh && echo "fork source ok"
git add files/references/engine-and-premium.md files/SKILL.md new-client.sh files/setup-elementor-mcp.sh docs/WHATS_INSTALLED.md
git commit -m "$(printf 'feat(studio): engine-and-premium doc + single-plugin (fork) install\n\nInstall our fork (4.x-correct, bundles the MCP Adapter) instead of the free\nupstream; drop the separate adapter step; document the do-not-co-run-Premium\nrule + switch commands.\n\nCo-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>')"
```

---

## Task 4: Lifecycle glue

**Files:**
- Create: `files/references/lifecycle.md`
- Modify: `files/SKILL.md` (extend the existing `## Companion tooling` pointer)

- [ ] **Step 1: Write `files/references/lifecycle.md`**

```markdown
# Studio lifecycle — where the Elementor build fits

The Elementor build is one stage of the studio toolbox. Hand off cleanly to the neighbours.

| Stage | Tool | Use it for |
|---|---|---|
| **Audit** (pre-sale / onboarding) | `wordpress-api-pro` → `site_audit.py` | No-auth Tier-1 scan of a prospect/client site (CMS, SEO, headers, SSL, PageSpeed) before proposing a build. |
| **Content / commerce** | `wordpress-api-pro` (WP REST) | Seed posts/pages/CPTs, media, WooCommerce products, SEO meta, ACF/JetEngine fields — before or alongside the Elementor build. |
| **Build** (this skill) | the fork `elementor-mcp` | Design + build pages/templates in Elementor. |
| **Host** | `cloudways-mcp` / `hostinger-mcp` | Provision/monitor/maintain the server the site runs on; SSL/cache/backups (Cloudways UI/API for SSL — not an MCP tool). |
| **Ads** | `meta-ads-mcp` | Launch/manage the campaign that drives traffic to the built site. |

## Handoffs

- **Audit → Build:** run `site_audit.py` first; its findings (CMS, theme, current builder, SEO gaps) scope the build brief and tell you whether Elementor/Pro is even present.
- **Build → Content:** use `wordpress-api-pro` to populate real content into the structures you built (drafts-first, dry-run for bulk).
- **Build → Host:** confirm the target server in `cloudways-mcp`/`hostinger-mcp`; clear cache after a deploy; never leave the MCP build plugins active on production.

## "Where am I?" router

- Prospect, no site access yet → **Audit** (`site_audit.py`).
- Site access, needs pages → **Build** (here).
- Pages built, needs real content/products → **Content** (`wordpress-api-pro`).
- Site done, needs server ops/SSL/cache → **Host** (`cloudways-mcp`/`hostinger-mcp`).
- Site live, needs traffic → **Ads** (`meta-ads-mcp`).
```

- [ ] **Step 2: Extend the SKILL pointer**

In SKILL.md's `## Companion tooling — wordpress-api-pro` section, add a line:
```markdown
This skill is one stage of the studio toolbox (audit → build → content → host → ads). **Full handoffs + a "where am I" router → load `references/lifecycle.md`.**
```

- [ ] **Step 3: Verify + commit**

```bash
test -f files/references/lifecycle.md && grep -q 'references/lifecycle.md' files/SKILL.md && echo "lifecycle wired ok"
git add files/references/lifecycle.md files/SKILL.md
git commit -m "$(printf 'feat(studio): lifecycle glue across the toolbox\n\nCo-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>')"
```

---

## Task 5: Studio verticals (5 packs, studio voice)

Five reusable build briefs. **Written in Digitizer's own voice** — informed by the *shape* of the
Premium prompts (`docs/refs/emcp-pro/prompts/`, gitignored, paid) but **not copied**. No verbatim
paid-prompt text.

**Files:**
- Create: `files/references/verticals/{dental,salon,car-wash,local-business,portfolio}.md`
- Modify: `files/SKILL.md` (vertical-routing note)

- [ ] **Step 1: Define the shared vertical pack template**

Every vertical file uses this shape (this is OUR structure, generic — fill per vertical):
```markdown
# <Vertical> — studio build pack

**When to use:** <one line — the kind of client this matches>

## Voice & positioning
<2-3 lines: tone, the visitor's job-to-be-done, the primary conversion (call/book/quote/contact).>

## Design system
- **Palette:** primary / primary-dark / accent / dark / body-text / muted (hex) — pick a tasteful, on-brand set for this vertical.
- **Typography:** heading + body pairing; weights; scale.
- **Spacing/rhythm:** section padding, container width (boxed default).

## Section flow (top → bottom)
1. Hero — headline + subhead + primary CTA.
2. <trust / services / gallery / pricing — vertical-appropriate>
3. … (5-8 sections typical)
N. Contact / booking + footer.

## Build notes
- Brand kit / recipe combo to use (cross-ref `references/brand-kit.md`, `references/recipes.md`).
- Vertical-specific gotchas (e.g. compliance lines, required disclaimers).
```

- [ ] **Step 2: Write each of the 5 packs**

Create one file per vertical with the template, authored in studio voice with a vertical-appropriate palette/flow:
- `dental.md` — clean/medical/trustworthy; book-appointment CTA; services, team, insurance, reviews.
- `salon.md` — stylish/warm; book-now CTA; services menu, gallery, stylists, offers.
- `car-wash.md` — bold/energetic; plans CTA; packages/pricing, locations/hours, membership.
- `local-business.md` — versatile/credible; contact/quote CTA; services, about, testimonials, service-area.
- `portfolio.md` — minimal/confident (web-developer/creative); hire-me CTA; work grid, skills, about, contact.

Each must be self-authored prose (no copy-paste from `docs/refs/emcp-pro/prompts/`).

- [ ] **Step 3: Add the routing note to SKILL.md**

In SKILL.md (near build order / first-action), add:
```markdown
**Vertical routing:** if the client matches a known vertical, load its pack first for voice + design system + section flow: `references/verticals/{dental,salon,car-wash,local-business,portfolio}.md`. No match → proceed with the studio voice default + the recipe library.
```

- [ ] **Step 4: Verify no verbatim paid content + commit**

```bash
# Ensure none of the vertical files copy a distinctive Premium line (spot-check a known phrase):
grep -rn 'BrightSmile' files/references/verticals/ && echo "WARNING: looks copied" || echo "no copied sample names ✓"
for v in dental salon car-wash local-business portfolio; do test -f files/references/verticals/$v.md && echo "ok $v" || echo "MISSING $v"; done
grep -q 'references/verticals' files/SKILL.md && echo "routing wired ok"
git add files/references/verticals files/SKILL.md
git commit -m "$(printf 'feat(studio): 5 studio vertical packs + routing\n\nDental, salon, car-wash, local-business, portfolio — studio-voiced build\nbriefs (design system + section flow), authored fresh (not copied from the\npaid prompts). SKILL routes to a pack when the client matches.\n\nCo-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>')"
```

---

## Task 6: Full validation + PR

- [ ] **Step 1: Link-resolve + content checks**

```bash
cd /Users/digitizer/Documents/GitHub/claude-elementor-pro
# every references/*.md mentioned in SKILL.md exists
for r in $(grep -ohE 'references/[a-z0-9/-]+\.md' files/SKILL.md | sort -u); do test -f "files/$r" && echo "OK $r" || echo "MISSING $r"; done
# SKILL shrank
echo "SKILL lines: $(wc -l < files/SKILL.md)"
# union no-loss recheck
cat files/SKILL.md files/references/*.md files/references/verticals/*.md > /tmp/all.md
for p in 'Fluent Forms' 'Loop Grid' 'JetEngine' 'Theme Builder' 'add-flexbox' 'Motion Effects'; do grep -q "$p" /tmp/all.md && echo "kept: $p" || echo "LOST: $p"; done
```
Expected: all `OK`, no `MISSING`, no `LOST`, SKILL well under 872.

- [ ] **Step 2: Installer dry-run installs the full tree**

```bash
TMPH=$(mktemp -d); HOME="$TMPH" bash INSTALL.sh </dev/null >/dev/null 2>&1 || true
echo "installed refs: $(find "$TMPH/.claude/skills/elementor-mcp/references" -name '*.md' | wc -l | tr -d ' ')"
find "$TMPH/.claude/skills/elementor-mcp/references/verticals" -name '*.md' | wc -l
rm -rf "$TMPH"
```
Expected: refs count ≥ 9 + 5 verticals.

- [ ] **Step 3: Run the repo's tests (bats/shell)**

```bash
ls tests/ 2>/dev/null && bash tests/run.sh 2>&1 | tail -15 || echo "(no tests/run.sh — rely on CI)"
bash -n INSTALL.sh new-client.sh files/setup-elementor-mcp.sh 2>/dev/null; echo "scripts parse ok"
```

- [ ] **Step 4: Push + PR**

```bash
git push -u origin feat/studio-layer
gh pr create --base main --head feat/studio-layer \
  --title "feat: studio-layer reshape (fork engine, slim SKILL, verticals, lifecycle)" \
  --body "$(printf 'Reshape claude-elementor-pro into the studio Elementor layer anchored on our fork.\n\n- Slim the 872-line SKILL via progressive-disclosure references (no mechanics lost).\n- 5 studio vertical packs (studio voice, not copied from paid prompts).\n- Lifecycle glue across the toolbox (audit -> build -> content -> host -> ads).\n- engine-and-premium doc: run the fork, never co-run Premium (same classes -> fatal).\n- Single-plugin install (fork bundles the MCP Adapter); installers now copy references/.\n\n🤖 Generated with [Claude Code](https://claude.com/claude-code)')"
```

- [ ] **Step 5: Confirm CI green**

```bash
sleep 25; gh pr checks 1 2>&1 | head
```

- [ ] **Step 6: Report** PR URL + CI status. Do not merge without user go.

---

## Notes for the executor

- **Relocate by heading, not line number** (the file shifts as you edit). Use the exact `^## …$` anchors in Task 2's table.
- **No content loss is the hard invariant** for Task 2 — the union check (Step 5) must pass before committing.
- **No verbatim paid content** in verticals (Task 5) — author fresh in studio voice.
- Read each installer (`INSTALL.sh/.bat/.ps1`, `new-client.sh`, `setup-elementor-mcp.sh`) before editing; match its existing variable names and style.
- Commit trailer on every commit: `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.
- Do not merge or change repo visibility; PR only, user merges.
