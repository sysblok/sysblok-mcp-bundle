# sysblok-mcp-bundle

Local MCP (Model Context Protocol) servers for WordPress, Planka, and
Google Docs/Sheets/Drive, so anyone on the team can point Claude Code,
Claude Desktop, or another MCP-capable agent at sysblok's tools. Docker is
the only prerequisite -- no Node.js, Python, or git required.

**Don't read this as a manual setup guide.** Tell any AI agent:

> Fetch `https://raw.githubusercontent.com/sysblok/sysblok-mcp-bundle/v0.1.0/SETUP.md`
> and follow it.

and answer its questions as it walks through onboarding. See
[`SETUP.md`](./SETUP.md) for the full agent-executed flow.

> Maintainers: the URL above pins to a release tag, not `main`, so
> instructions can't change out from under someone between "told to run
> this" and "actually running it." Update it here after cutting each
> release.

## What's included

| Server | Upstream | Transport | Runs via |
|---|---|---|---|
| WordPress | [`docdyhr/mcp-wordpress`](https://github.com/docdyhr/mcp-wordpress) | stdio only | on-demand `docker run`, spawned by your MCP client |
| Planka | [`chmald/planka-mcp`](https://github.com/chmald/planka-mcp) | SSE | `docker compose` (persistent) |
| Google Docs/Sheets/Drive | [`taylorwilsdon/google_workspace_mcp`](https://github.com/taylorwilsdon/google_workspace_mcp) | streamable-HTTP + OAuth 2.1 | `docker compose` (persistent) |

## Prerequisites

| Tool | Notes |
|---|---|
| Docker | Desktop (macOS/Windows) or Engine + Compose plugin (Linux). Nothing else. |

## Repo layout

- `SETUP.md` -- the real onboarding path, meant to be executed by an agent
  on a human's behalf.
- `docker-compose.yml` / `.env.example` -- tracked, canonical source for
  the Planka + Google services. `SETUP.md` inlines byte-identical copies
  of these (enforced by CI, see `scripts/check-setup-sync.sh`) so an agent
  never needs a second fetch to materialize them.
- `client-config.example.json` -- the `mcpServers` block for all three
  servers, in the shape `SETUP.md` merges into your actual MCP client
  config.

## Secrets

No `.env` file is ever committed. `.gitignore` blocks `.env` and `data/`
(where per-user Google OAuth tokens land via bind mount). The one shared
Google OAuth Client ID/Secret lives in each teammate's local `.env`,
distributed by an admin out-of-band -- see `.env.example` for details on
what's per-user vs. admin-provided.

## License

MIT -- see [`LICENSE`](./LICENSE).

## For repo maintainers

If you edit `docker-compose.yml`, `.env.example`, or
`client-config.example.json`, update the matching fenced block in
`SETUP.md` in the same PR. CI (`scripts/check-setup-sync.sh`) fails the
build if they drift -- run it locally before pushing:

```bash
./scripts/check-setup-sync.sh
```
