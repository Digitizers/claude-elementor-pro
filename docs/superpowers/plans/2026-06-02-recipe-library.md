# Section Recipe Library — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Add a library of 10 brand-token-driven section recipes the skill consults before building a section.

**Architecture:** A new `files/references/recipes.md` (intro + 10 recipe sections, classic-first build trees bound to brand tokens, with Pro/atomic variant notes) and a lean `## Recipe library` section in SKILL.md pointing to it; build-order references it. CI asserts all 10 recipes present, SKILL links the file, and tokens are referenced. No runtime code.

**Tech Stack:** Markdown (skill docs), GitHub Actions (`ci.yml`).

**Repo / branch:** `/Users/digitizer/Documents/GitHub/siteagent-elementor-studio`, branch `feat/recipe-library` off `main`.

**Exact recipe titles (CI checks these — keep verbatim):**
`Hero`, `Services grid`, `Split (image + text)`, `Stats band`, `Testimonials`, `CTA band`, `Contact`, `FAQ`, `Pricing`, `Logos strip`.

**Tokens to reference (from P1a):** `brand, accent, heading, text, bg, surface, muted, border`; type-scale steps `h1/h2/h3/h4/body-lg/body/small`.

---

## File Structure

- Create `files/references/recipes.md` — intro + 10 recipe H2 sections.
- Modify `files/SKILL.md` — `## Recipe library` section + build-order step 4 pointer.
- Modify `.github/workflows/ci.yml` — recipe-library check.

---

## Task 0: Branch

```bash
cd /Users/digitizer/Documents/GitHub/siteagent-elementor-studio
git checkout main && git pull --ff-only
git checkout -b feat/recipe-library
```

---

## Task 1: `files/references/recipes.md`

**Files:** Create `files/references/recipes.md`

- [ ] **Step 1: Write the file**

Structure: an intro, then one `## <Title>` per recipe (titles exactly as listed
above). Each recipe section contains, in order:

- **When** — one line.
- **Structure** — an indented bullet tree: outer container (full-width; bg = a named
  token; vertical padding) → inner container (boxed, max-width ~1200–1360, centered)
  → content widgets, nesting explicit.
- **Tokens & scale** — token bindings (bg/text/heading/accent/border) + the
  type-scale step each text uses.
- **Key settings** — the few flat-param settings that matter.
- **Responsive** — what changes on mobile.
- **Variants** — short **Pro** and **Atomic/V4** notes only (not a second tree).

Intro must state the rules (reuse, don't restate): consult the matching recipe before
building a section; bind to brand tokens by name (see `brand-kit.md`); native widgets
not HTML dumps; `duplicate-element` for fixed card sets, Loop Grid (Pro) for dynamic;
flat-param widget convention. Classic-first; apply the variant note for Pro/V4.

Write all 10 recipes per the spec's "The 10 recipes" section. Each must name at least
one brand token. Keep each recipe tight (~15–25 lines).

- [ ] **Step 2: Validate structure**

Run:
```bash
python3 - <<'PY'
import re, pathlib
md = pathlib.Path("files/references/recipes.md").read_text()
titles = ["Hero","Services grid","Split (image + text)","Stats band","Testimonials",
          "CTA band","Contact","FAQ","Pricing","Logos strip"]
heads = re.findall(r"^##\s+(.+)$", md, re.M)
missing = [t for t in titles if t not in heads]
assert not missing, f"missing recipes: {missing}"
for tok in ("brand","surface","heading","text"):
    assert tok in md, f"recipes.md should reference token '{tok}'"
print(f"recipes ok ({len(titles)} present)")
PY
```
Expected: `recipes ok (10 present)`.

- [ ] **Step 3: Commit**

```bash
git add files/references/recipes.md
git commit -m "feat(skill): add 10 brand-token section recipes

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 2: SKILL.md section + build-order pointer

**Files:** Modify `files/SKILL.md`

- [ ] **Step 1: Add `## Recipe library` section**

Insert immediately before `## When the user asks to BUILD — building order`:

```markdown
## Recipe library

Reusable, brand-token-driven build sequences for common sections. **Before building a
section, consult the matching recipe** and bind everything to the brand tokens (see
"Brand kit" above). Classic-first; apply the recipe's Pro/V4 variant note when those
engines are active. Full trees + token bindings: [`references/recipes.md`](references/recipes.md).

Available recipes: **Hero**, **Services grid**, **Split (image + text)**, **Stats
band**, **Testimonials**, **CTA band**, **Contact**, **FAQ**, **Pricing**, **Logos
strip**. (The library grows — add a recipe when a new section type recurs.)

Recipes reuse the rest of this skill's rules (native widgets not HTML dumps,
`duplicate-element`/Loop Grid for grids, flat-param convention) — they don't restate
them.
```

- [ ] **Step 2: Point build-order step 4 at the library**

Replace the build-order line:

```markdown
4. Build sections — outer container → inner content container (boxed, max-width 1360px-ish) → content
```

with:

```markdown
4. Build sections — **use the matching recipe from the Recipe library** (outer container → inner boxed container, max-width ~1360px → content), bound to brand tokens
```

- [ ] **Step 3: Frontmatter lint**

```bash
python3 - <<'PY'
import re, pathlib
p = pathlib.Path("files/SKILL.md").read_text()
m = re.match(r'^---\n(.*?)\n---\n', p, re.S); assert m
for k in ("name","description"):
    mm = re.search(rf'^{k}:\s*(.+)$', m.group(1), re.M); assert mm and mm.group(1).strip(), k
assert "references/recipes.md" in p, "SKILL must link recipes.md"
print("ok")
PY
```
Expected: `ok`.

- [ ] **Step 4: Commit**

```bash
git add files/SKILL.md
git commit -m "feat(skill): recipe-library section + build-order pointer

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 3: CI check

**Files:** Modify `.github/workflows/ci.yml`

- [ ] **Step 1: Add after the brand-kit check step**

```yaml
      - name: Recipe library check
        run: |
          python3 - <<'PY'
          import re, pathlib
          md = pathlib.Path("files/references/recipes.md").read_text()
          titles = ["Hero","Services grid","Split (image + text)","Stats band","Testimonials",
                    "CTA band","Contact","FAQ","Pricing","Logos strip"]
          heads = re.findall(r"^##\s+(.+)$", md, re.M)
          missing = [t for t in titles if t not in heads]
          assert not missing, f"missing recipes: {missing}"
          for tok in ("brand","surface","heading","text"):
              assert tok in md, f"recipes.md should reference token '{tok}'"
          skill = pathlib.Path("files/SKILL.md").read_text()
          assert "references/recipes.md" in skill, "SKILL must reference recipes.md"
          print(f"recipe library ok ({len(titles)} recipes)")
          PY
```

- [ ] **Step 2: Commit**

```bash
git add .github/workflows/ci.yml
git commit -m "ci: validate recipe library (10 recipes + token refs + SKILL link)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 4: Push + PR

```bash
git push -u origin feat/recipe-library
gh pr create --repo Digitizers/siteagent-elementor-studio --base main --head feat/recipe-library \
  --title "feat: section recipe library (P1b)" \
  --body "$(cat <<'EOF'
## What
10 reusable, brand-token-driven section recipes the skill consults before building a section — the studio's compounding build asset.

- `files/references/recipes.md`: Hero, Services grid, Split, Stats band, Testimonials, CTA band, Contact, FAQ, Pricing, Logos strip. Each is a classic-first container tree bound to the P1a brand tokens, with short Pro/V4 variant notes.
- SKILL.md: `## Recipe library` section + build-order step 4 points at it. Recipes reuse the existing discipline (tokens by name, native widgets, duplicate-element/Loop Grid).
- CI asserts all 10 recipes present, SKILL links the file, and tokens are referenced.

## Depends on
P1a brand tokens (#10) — recipes reference them by name.

## Scope
Classic-first + variant notes (not full dual atomic trees). Single markdown file (grows in place). Live build-one-recipe verification is a documented manual check.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

Watch CI: `gh pr checks --watch`.

---

## Self-Review notes (author)

- **Spec coverage:** recipe format (Task 1) ✓; all 10 recipes (Task 1) ✓; SKILL section + build-order pointer (Task 2) ✓; CI (Task 3) ✓; discipline ties / non-goals honored (Task 1 intro) ✓.
- **Placeholder scan:** the recipe prose is the deliverable; Task 1 fully specifies its required structure + content source (spec §"The 10 recipes"). SKILL/CI steps have full literal content.
- **Type consistency:** the 10 titles are byte-identical across Task 1 validation, the SKILL list, and the CI check; tokens match P1a.
