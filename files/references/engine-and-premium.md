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
