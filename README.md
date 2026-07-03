# Claude + Elementor Pro — Claude Code & OpenClaw Skill

[![CI](https://github.com/Digitizers/claude-elementor-pro/actions/workflows/ci.yml/badge.svg)](https://github.com/Digitizers/claude-elementor-pro/actions/workflows/ci.yml)
![Claude Code Skill](https://img.shields.io/badge/Claude_Code-Skill-d97757)
![OpenClaw Skill](https://img.shields.io/badge/OpenClaw-Skill-purple)
![Elementor](https://img.shields.io/badge/Elementor-Pro-92003b)
![License: MIT](https://img.shields.io/badge/License-MIT-green)
![Version](https://img.shields.io/badge/version-1.0.1-blue)

Build **WordPress sites with AI** — design with Claude Code, then have Claude build it directly inside your [Elementor](https://digitizer.li/elementor) Free or Pro site. No more rebuilding mockups by hand.

A **Claude Code & OpenClaw skill** that teaches Claude to build directly inside Elementor. Not just a mockup tool — Claude places real sections, widgets, colors, and typography into your live Elementor site, with Pro/free auto-detection and a widget-vs-HTML discipline.

> **The short version:** This kit teaches Claude (Anthropic's AI) how to talk to your WordPress site through the Elementor MCP server. You design pages in Claude Code, then Claude places sections, widgets, colors, and typography directly into Elementor for you. Works on local sites (Local-by-Flywheel) and live hosts.

---

## What's inside

```
claude-elementor-pro/
├── INSTALL.sh          ← Installer for Mac & Linux
├── INSTALL.bat         ← Installer for Windows (double-click)
├── INSTALL.ps1         ← Windows installer (PowerShell)
├── files/
│   ├── SKILL.md                  ← The cheat sheet Claude reads
│   └── setup-elementor-mcp.sh    ← The robot that connects Claude to WordPress
├── docs/
│   ├── QUICKSTART.md       ← Short "how to use this" guide
│   ├── WHATS_INSTALLED.md  ← One-page map of every file/plugin the kit touches
│   └── LESSONS.md          ← Deep-dive on why it works the way it does
├── LICENSE             ← MIT — free for any use
└── README.md           ← You are here
```

---

## How it works (in 30 seconds)

There are two pieces:

1. **The skill** (`SKILL.md`) — a guide Claude reads every time you ask it to work on Elementor. It encodes every quirk and gotcha learned the hard way (correct widget parameter names, when to use HTML vs native widgets, the auth gotchas, etc.).

2. **The setup script** (`setup-elementor-mcp.sh`) — a wizard that connects Claude to one specific WordPress site. It installs the MCP plugins, wires up authentication, and writes a `.mcp.json` file in your project directory.

After running both, you can tell Claude *"build me a hero section with this design"* and watch it appear on your WordPress site in real time.

---

## Prerequisites

The kit touches **five layers** of stuff. Some you install yourself, some the wizard handles for you. Here's the full picture so nothing surprises you mid-setup.

### Layer 1 — On your computer *(install once, ever)*

- ☐ **[Claude Code](https://claude.ai/download)** — the AI assistant the kit plugs into
- ☐ **[Local by Flywheel](https://localwp.com/)** *(only if you want offline WordPress — skip if you have a live site)*
- ☐ **[Git Bash](https://git-scm.com/download/win)** *(Windows only — gives you `bash`, `curl`, `python`, `zip` that the setup script needs. Mac and Linux users already have these.)*

### Layer 2 — Inside Local *(or your hosting panel)*

- ☐ **A WordPress site.** Create a fresh one in Local, or have admin access to a live host.
- ☐ **An Application Password.** WP Admin → Users → Profile → scroll to *Application Passwords* → click Add. Copy the password — that's the credential the wizard uses. ([WordPress docs](https://wordpress.org/documentation/article/application-passwords/))

### Layer 3 — WordPress plugins + theme

You can install these yourself OR let the **setup wizard auto-install them for you** (it asks). All are free, on the WordPress.org plugin directory.

**Required:**

| Plugin / Theme | What it does |
|---|---|
| **Elementor (free)** | The page builder — Claude builds pages inside this |
| **Hello Elementor** *(theme)* | Blank canvas theme that doesn't fight Elementor's styling |
| **Ultimate Addons for Elementor (UAE)** | Lets you build site-wide headers and footers (Theme Builder is Pro-only) plus a free Nav Menu widget |

**Optional but useful:**

| Plugin | What it does |
|---|---|
| **Essential Addons for Elementor (lite)** | Free widgets like Post Grid that aren't in Elementor base |
| **Fluent Forms** | Real working contact forms (Elementor's Form widget is Pro) |

### Layer 4 — The MCP plugins *(automatic — wizard handles these)*

You **don't install these yourself.** The setup wizard downloads them from GitHub and installs them automatically.

| Plugin | What it does |
|---|---|
| **MCP Adapter** | The "phone line" that lets any AI talk to WordPress |
| **MCP Tools for Elementor** | The Elementor-specific MCP server — the magic |

### Layer 5 — This kit *(handled by `INSTALL.sh` / `INSTALL.bat`)*

The two files in this repo's `files/` folder get copied to:

- `~/.claude/skills/elementor-mcp/SKILL.md` — the cheat sheet Claude reads each session
- `~/.claude/scripts/setup-elementor-mcp.sh` — the wizard you run per WordPress site

> 📋 **Want a one-page reference of every file/plugin the kit touches?** See [`docs/WHATS_INSTALLED.md`](docs/WHATS_INSTALLED.md).

---

## Install

### Mac / Linux

```bash
# 1. Clone or download this repo
git clone https://github.com/Digitizers/claude-elementor-pro.git
cd claude-elementor-pro

# 2. Run the installer
bash INSTALL.sh
```

### Windows

```
1. Download this repo as a ZIP (green "Code" button → Download ZIP)
2. Unzip it anywhere
3. Double-click INSTALL.bat
```

The installer copies two files into your `~/.claude/` folder:
- `~/.claude/skills/elementor-mcp/SKILL.md`
- `~/.claude/scripts/setup-elementor-mcp.sh`

Safe to re-run — it'll ask before overwriting existing files.

---

## Use it

### One-time per WordPress site

```bash
# In your project folder (anywhere you want .mcp.json to live)
bash ~/.claude/scripts/setup-elementor-mcp.sh
```

The wizard walks you through 8 steps:
1. Local or live host?
2. Site URL or Local site name
3. Connectivity check
4. WordPress username + Application password
5. Reports which baseline plugins/theme are already active
6. **Offers to auto-install** missing ones (Elementor, UAE, Hello Elementor, optionally Essential Addons + Fluent Forms)
7. Installs the two MCP plugins from GitHub
8. Writes `.mcp.json` to the current folder

If you say "yes" at step 6, the wizard installs the required plugins from wordpress.org for you. If you say "no" — say if you're using an existing site you don't want auto-modified — install them manually via WP Admin → Plugins → Add New.

### Onboard a client fast (non-interactive)

For spinning up many client sites, `new-client.sh` is a flag-driven, headless version of the wizard — resolves the site, verifies auth, detects Pro, installs the MCP plugins, and writes `.mcp.json` in one command:

```bash
# Local-by-Flywheel site (resolved from Local's sites.json — works even when the
# site lives outside ~/Local Sites/):
bash new-client.sh --local "ClientName" --user wpuser --app-pass "xxxx xxxx xxxx xxxx xxxx xxxx" --with-api-pro

# Live host (prints the two MCP zips to upload, then re-run):
bash new-client.sh --live "https://client.com" --user wpuser --app-pass "..." --project-dir ~/projects/client
```

Useful flags: `--project-dir <path>` (where `.mcp.json` goes), `--with-api-pro [path]` (also install the [wordpress-api-pro](https://github.com/Digitizers/wordpress-api-pro) companion skill), `--name <id>` (MCP server name), `--dry-run` (report only). Idempotent — skips the plugin install if the MCP route is already registered.

### Every session

1. Restart Claude Code in the project folder so it picks up `.mcp.json`
2. Approve the new MCP server when prompted
3. Tell Claude what to build:
   - *"Use the Elementor MCP to build a homepage based on the design in this folder"*
   - *"Add a hero section with a video background"*
   - *"Set my global colors to navy and gold"*

The skill auto-loads, and Claude already knows how to drive Elementor correctly.

---

## What this can and can't do

**Can do:**
- Create pages, set them as the homepage
- Build sections — heroes, listings grids, neighborhoods, stats, journals, contact
- Set Elementor global colors and typography
- Add containers, headings, images, buttons, tabs, accordions, dividers
- Drop in custom HTML/CSS for things native widgets can't do
- Edit existing pages, find elements by ID, update settings, restructure layouts
- Work on local AND live WordPress sites

**With Elementor Pro (auto-detected):**
- The kit detects Elementor Pro and switches to native Pro tools automatically — no config needed.
- Native **Form** widget (real submitting forms, no Fluent Forms), **Theme Builder** headers/footers/single/archive (no UAE/HFE), **Loop Grid** for dynamic listings, **Popups**, **Dynamic Tags**, and **Sticky/Motion** effects.
- The kit can't *install* Pro for you (it's paid and not on wordpress.org) — install/activate it yourself, then run the setup wizard.

**With ACF or Crocoblock/JetEngine (auto-detected, Tier-0):**
- The kit detects **ACF** and **JetEngine** and switches the skill into dynamic-data mode — bind ACF fields via Pro Dynamic Tags, place JetEngine widgets via the generic `add-widget`.
- Exact widget/tag names are **verified at runtime** (and the first write is read back), so the skill never silently writes a wrong type. Building ACF field groups, JetEngine CPTs/listings, and the Query Builder stays in their own admin UIs — the kit wires Elementor up to them, it doesn't create them.

**Can't do:**
- Install plugins on live hosts (you upload the two MCP plugin zips manually — the script tells you when)
- Pixel-perfect translation from arbitrary HTML — Elementor's flexbox container model is the ceiling (Pro adds CSS Grid containers)
- On **free Elementor**, drive Pro-only features — it falls back to workarounds: Fluent Forms for forms, and **[Header Footer Elementor](https://wordpress.org/plugins/header-footer-elementor/)** (free) / UAE for custom headers/footers

---

## Troubleshooting

**"Auth failed"** — The Application Password's *name* (e.g. "ClaudeMCP") is just a label. The username is your actual WordPress login. The setup script will list public users on auth failure.

**"Could not find MySQL socket"** — Your Local site isn't running. Open Local, click Start Site, re-run the setup script.

**"MCP namespace doesn't appear after install"** — The elementor-mcp plugin requires Elementor v3.20+. Check the plugin row in WP Admin → Plugins for any error.

**"Live host returns 403 from /wp-json/"** — Some hosts block non-browser User-Agents on the REST API. Add WP-CLI or the `curl` IP to your security plugin's allowlist.

**Windows: "bash: command not found"** — Install [Git Bash](https://git-scm.com/download/win) first.

For more details, see [`docs/LESSONS.md`](docs/LESSONS.md).

---

## Credits

This is the **Elementor Pro edition** — a fork of and built on top of the original kit:

- **[claude-elementor-kit](https://github.com/emersimeon/claude-elementor-kit)** by [Emery Simeon (@emersimeon)](https://github.com/emersimeon) — the original kit that this repo extends with native Elementor Pro support and auto-detection (MIT)

It also wraps two existing open-source WordPress projects:

- **[elementor-mcp](https://github.com/msrbuilds/elementor-mcp)** by [@msrbuilds](https://github.com/msrbuilds) — the actual MCP server that exposes Elementor to AI agents (GPL-3.0)
- **[WordPress MCP Adapter](https://github.com/WordPress/mcp-adapter)** — the WP-side plumbing for any MCP server (GPL-2.0)

Both plugins are GPL-licensed and are downloaded from GitHub Releases by the setup script.

The skill, setup script, installers, and docs in this kit are MIT-licensed (see [LICENSE](LICENSE)).

---

## Questions?

Open an issue on this repo. Don't promise me you'll wait for an answer, but I read everything.

## Links

- **Repository:** https://github.com/Digitizers/claude-elementor-pro
- **OpenClaw:** https://openclaw.ai
- **Elementor MCP server:** https://github.com/msrbuilds/elementor-mcp
- **Digitizer:** https://www.digitizer.studio

---

Built with ❤️ for OpenClaw by [Digitizer](https://www.digitizer.studio)
