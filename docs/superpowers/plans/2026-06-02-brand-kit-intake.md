# Brand-kit Intake — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (or subagent-driven-development) to implement. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Add a brand-token vocabulary + intake flow to the skill kit so a client's brand maps to named Elementor global colors/typography, referenced by name in every later build.

**Architecture:** A new `files/references/brand-kit.md` (full token schema + intake template + worked example with exact MCP tool shapes) and a lean `## Brand kit — intake & tokens` section in `files/SKILL.md` pointing to it; build-order step 1 updated to invoke the flow. CI gains a check that the intake-template JSON example parses and that SKILL references the file. No runtime code.

**Tech Stack:** Markdown (skill docs), GitHub Actions (existing `ci.yml`).

**Repo / branch:** `/Users/digitizer/Documents/GitHub/claude-elementor-pro`, branch `feat/brand-kit-intake` off `main`.

**Verified MCP tool shapes:**
- `update-global-colors`: `{ "colors": [{ "_id", "title", "color" }] }`
- `update-global-typography`: `{ "typography": [{ "_id", "title", "typography_font_family", "typography_font_size": {size,unit}, "typography_font_weight", "typography_line_height": {size,unit}, "typography_letter_spacing": {size,unit} }] }`

---

## File Structure

- Create `files/references/brand-kit.md` — token vocabulary, mapping, type scale, intake template, worked example.
- Modify `files/SKILL.md` — add brand-kit section; update build-order step 1.
- Modify `.github/workflows/ci.yml` — assert the intake-template JSON parses + SKILL references the file.

---

## Task 0: Branch

- [ ] **Step 1**

```bash
cd /Users/digitizer/Documents/GitHub/claude-elementor-pro
git checkout main && git pull --ff-only
git checkout -b feat/brand-kit-intake
mkdir -p files/references
```

---

## Task 1: `files/references/brand-kit.md`

**Files:** Create `files/references/brand-kit.md`

- [ ] **Step 1: Write the reference**

Create `files/references/brand-kit.md` with this exact content:

````markdown
# Brand kit — token vocabulary & intake

The studio's brand tokens. Every client site sets these once; every build
references them **by name, never raw hex/font**. Tokens map to **named Elementor
custom globals** (the `update-global-colors` / `update-global-typography` tools
write `custom_colors` / `custom_typography`, merged by `_id`).

## Color tokens (8 named custom globals)

| token `_id` | title | role |
|---|---|---|
| `brand` | Brand | primary brand color — buttons, links, emphasis |
| `accent` | Accent | secondary highlight |
| `heading` | Heading | heading text color |
| `text` | Text | body text color |
| `bg` | Background | page background |
| `surface` | Surface | card / section panel background |
| `muted` | Muted | secondary / subtle text, captions |
| `border` | Border | hairlines, dividers, card borders |

If a client supplies fewer than 8, derive and state it: `surface` = a light tint of
`bg`; `muted` = `text` at ~60% contrast; `border` = `text` at ~12% / a light grey.

## Typography tokens (2 named custom globals)

| token `_id` | title | role |
|---|---|---|
| `heading-font` | Heading Font | headings |
| `body-font` | Body Font | body / UI |

## Type scale (applied per-widget by recipes — not a global object)

| step | size (px, desktop) | typical use |
|---|---|---|
| h1 | 48 | hero title |
| h2 | 36 | section title |
| h3 | 28 | card title |
| h4 | 22 | sub-heading |
| body-lg | 18 | lead paragraph |
| body | 16 | default text |
| small | 14 | captions, labels |

Defaults: heading weight 700, heading line-height 1.15; body weight 400, body
line-height 1.6. Scale down ~15–20% on mobile.

## Logo

Record the logo media id / URL in the intake record. Header recipes use the Site
Logo widget (Pro/UAE) or a Heading fallback.

## Intake template (fill one per client)

```json
{
  "client": "Acme",
  "colors": {
    "brand": "#1A56DB",
    "accent": "#F59E0B",
    "heading": "#0F172A",
    "text": "#334155",
    "bg": "#FFFFFF",
    "surface": "#F8FAFC",
    "muted": "#64748B",
    "border": "#E2E8F0"
  },
  "fonts": { "heading-font": "Rubik", "body-font": "Inter" },
  "logo": "https://acme.example/logo.svg"
}
```

## Applying it (MCP tool shapes)

`update-global-colors` — one entry per color token:

```json
{ "colors": [
  { "_id": "brand",   "title": "Brand",      "color": "#1A56DB" },
  { "_id": "accent",  "title": "Accent",     "color": "#F59E0B" },
  { "_id": "heading", "title": "Heading",    "color": "#0F172A" },
  { "_id": "text",    "title": "Text",       "color": "#334155" },
  { "_id": "bg",      "title": "Background",  "color": "#FFFFFF" },
  { "_id": "surface", "title": "Surface",    "color": "#F8FAFC" },
  { "_id": "muted",   "title": "Muted",      "color": "#64748B" },
  { "_id": "border",  "title": "Border",     "color": "#E2E8F0" }
] }
```

`update-global-typography` — one entry per font token:

```json
{ "typography": [
  { "_id": "heading-font", "title": "Heading Font",
    "typography_font_family": "Rubik",
    "typography_font_weight": "700",
    "typography_line_height": { "size": 1.15, "unit": "em" } },
  { "_id": "body-font", "title": "Body Font",
    "typography_font_family": "Inter",
    "typography_font_weight": "400",
    "typography_line_height": { "size": 1.6, "unit": "em" } }
] }
```

Then `get-global-settings` to confirm the 8 colors + 2 fonts are present by name.

## The discipline

After intake, bind widget colors to these globals (or use the recorded token value
when a recipe sets a value directly). Never introduce an ad-hoc hex/font mid-build —
that breaks brand consistency and the recipe library.
````

- [ ] **Step 2: Validate the JSON examples parse**

Run:
```bash
python3 - <<'PY'
import re, json, pathlib
md = pathlib.Path("files/references/brand-kit.md").read_text()
blocks = re.findall(r"```json\n(.*?)\n```", md, re.S)
assert blocks, "no json blocks found"
for i, b in enumerate(blocks):
    json.loads(b)
print(f"{len(blocks)} json blocks parse OK")
PY
```
Expected: `3 json blocks parse OK`.

- [ ] **Step 3: Commit**

```bash
git add files/references/brand-kit.md
git commit -m "feat(skill): add brand-kit token vocabulary + intake reference

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 2: SKILL.md section + build-order update

**Files:** Modify `files/SKILL.md`

- [ ] **Step 1: Add the brand-kit section**

Insert a new section immediately before `## When the user asks to BUILD — building order` (currently at line ~320):

```markdown
## Brand kit — intake & tokens

Triggers when the user is setting up a new client / brand, or says "set up the
brand". Establishes the design tokens every later build references **by name, never
raw hex/font**. Full schema + tool shapes: [`references/brand-kit.md`](references/brand-kit.md).

The 8 color tokens (`brand, accent, heading, text, bg, surface, muted, border`) and
2 font tokens (`heading-font, body-font`) map to **named Elementor custom globals**.

Flow:

1. **Gather** the brand — 8 colors (hex), 2 font families, logo — from the user's
   brief, a Figma file, or by asking. If fewer than 8 colors are given, derive the
   rest (`surface` = tint of `bg`; `muted` = lower-contrast `text`; `border` = light
   grey) and state the derivation.
2. **Apply** — `update-global-colors` with the 8 `{_id, title, color}` entries, then
   `update-global-typography` with the 2 font entries. (Exact payloads in the
   reference.)
3. **Record** the token→value map back to the user so recipes and later edits reuse it.
4. **Verify** — `get-global-settings` shows the 8 colors + 2 fonts by name.

After intake, **bind widget colors to these globals** (or use the recorded token
value when setting directly). Introducing an ad-hoc hex/font mid-build breaks brand
consistency — don't.
```

- [ ] **Step 2: Update build-order step 1**

Replace (line ~326):

```markdown
1. `update-global-colors` + `update-global-typography` — establish design tokens
```

with:

```markdown
1. **Brand kit** — if the brand tokens aren't set yet, run the brand-kit intake flow (see "Brand kit — intake & tokens" above) to establish the named global colors/typography. If already set, confirm via `get-global-settings`.
```

- [ ] **Step 3: Frontmatter lint still passes**

Run:
```bash
python3 - <<'PY'
import re, pathlib
p = pathlib.Path("files/SKILL.md").read_text()
m = re.match(r'^---\n(.*?)\n---\n', p, re.S); assert m, "no frontmatter"
fm = m.group(1)
for k in ("name","description"):
    mm = re.search(rf'^{k}:\s*(.+)$', fm, re.M); assert mm and mm.group(1).strip(), k
print("frontmatter OK")
PY
```
Expected: `frontmatter OK`.

- [ ] **Step 4: Commit**

```bash
git add files/SKILL.md
git commit -m "feat(skill): brand-kit intake section + build-order step 1

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 3: CI check

**Files:** Modify `.github/workflows/ci.yml`

- [ ] **Step 1: Add a brand-kit check to the `shell` job**

After the `SKILL.md frontmatter lint` step in `.github/workflows/ci.yml`, add:

```yaml
      - name: Brand-kit reference check
        run: |
          python3 - <<'PY'
          import re, json, pathlib
          md = pathlib.Path("files/references/brand-kit.md").read_text()
          blocks = re.findall(r"```json\n(.*?)\n```", md, re.S)
          assert blocks, "brand-kit.md has no json examples"
          for b in blocks:
              json.loads(b)
          skill = pathlib.Path("files/SKILL.md").read_text()
          assert "references/brand-kit.md" in skill, "SKILL.md must reference brand-kit.md"
          print(f"brand-kit ok ({len(blocks)} json blocks)")
          PY
```

- [ ] **Step 2: Commit**

```bash
git add .github/workflows/ci.yml
git commit -m "ci: validate brand-kit reference (json examples + SKILL link)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 4: Push + PR

- [ ] **Step 1**

```bash
git push -u origin feat/brand-kit-intake
gh pr create --repo Digitizers/claude-elementor-pro --base main --head feat/brand-kit-intake \
  --title "feat: brand-kit intake & token vocabulary (P1a)" \
  --body "$(cat <<'EOF'
## What
A studio brand-token vocabulary + intake flow — the foundation the recipe library (P1b) will consume.

- `files/references/brand-kit.md`: 8 color tokens + 2 font tokens mapped to **named Elementor custom globals**, a type scale, a fillable intake template, and exact `update-global-colors`/`update-global-typography` payloads.
- SKILL.md: new `## Brand kit — intake & tokens` section (gather → apply → record → verify) + the discipline (reference tokens by name, never raw hex); build-order step 1 now invokes the flow.
- CI validates the reference's JSON examples parse and SKILL links it.

## Why
Each client build previously re-decided colors/fonts ad hoc and hard-coded hex. Named global tokens make builds brand-driven and consistent, and unblock the recipe library.

## Grounding
Verified in elementor-mcp: `update-global-colors` / `update-global-typography` write named `custom_colors` / `custom_typography` merged by `_id` — so all tokens are MCP-settable named globals.

## Scope
Tokens + intake only. Recipe library = P1b (separate). Live-apply verification (SoftLab → get-global-settings) is a documented manual check.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

- [ ] **Step 2: Watch CI** — `gh pr checks --watch`; fix forward if red.

---

## Self-Review notes (author)

- **Spec coverage:** token vocabulary (Task 1 table) ✓; intake flow (Task 2 section) ✓; by-name discipline (Tasks 1 & 2) ✓; build-order update (Task 2) ✓; reference file w/ tool shapes + template + example (Task 1) ✓; CI check (Task 3) ✓; non-goals (no recipes, no CLI, no system-slot overwrite) honored ✓.
- **Placeholder scan:** full content in every step (the whole brand-kit.md + SKILL section are inline).
- **Type consistency:** token `_id`s (`brand/accent/heading/text/bg/surface/muted/border`, `heading-font/body-font`) identical across the reference, the SKILL section, and the JSON payloads; tool shapes match the verified elementor-mcp schemas.
