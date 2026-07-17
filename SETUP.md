# SETUP.md -- sysblok-mcp-bundle agent setup script

> You are an AI agent executing this file on behalf of a human teammate.
> This document is written in second person imperative addressed to YOU.
> The human only answers questions and confirms actions as you work through
> this -- do not summarize this file back to them and ask them to do the
> steps manually yourself.
>
> If you have a Bash/shell tool available: you should have fetched this
> file itself with `curl -fsSL <raw-url>` rather than a web-summarizing
> fetch tool, since you're about to write its contents to disk verbatim and
> a summarizing fetch may paraphrase or truncate it. If you only have a
> web-fetch tool that summarizes pages, ask it to reproduce this document's
> content verbatim rather than describe it.
>
> Everything you need is inlined below as fenced code blocks. You do not
> need `git clone`, `git`, Node.js, Python, or `uv`. Docker is the only
> prerequisite, checked in Step 1.

---

## Step 1 -- Check prerequisites

Run:

```bash
docker --version
docker compose version
```

If either command fails or is not found: stop here. Tell the human to
install Docker Desktop (macOS/Windows) or Docker Engine + the Compose
plugin (Linux), and wait for confirmation it's installed before continuing.
Do not proceed on assumptions -- verify both commands actually succeed.

---

## Step 2 -- Pick a working directory and materialize files

Ask the human for a working directory, defaulting to `~/sysblok-mcp-bundle/`
if they have no preference. Create it, then write the three files below
into it verbatim, using the fenced blocks in this document as their exact
content (do not paraphrase, reformat, or "improve" them -- these blocks are
kept byte-identical to this repo's tracked files by CI, so what's below is
already correct and tested):

`docker-compose.yml`:

<!-- BEGIN-SYNC: docker-compose.yml -->
```yaml
name: sysblok-mcp

services:
  planka-mcp:
    image: chmald/planka-mcp:${PLANKA_MCP_VERSION:-latest}
    container_name: sysblok-mcp-planka
    restart: unless-stopped
    environment:
      - MCP_TRANSPORT=sse
      - MCP_PORT=3001
      - PLANKA_BASE_URL=${PLANKA_BASE_URL}
      - PLANKA_API_KEY=${PLANKA_API_KEY}
    ports:
      # loopback-only: PLANKA_API_KEY is baked in server-side and the SSE
      # endpoint has no additional per-request auth -- anything reaching
      # this port has full access as that user. Never bind 0.0.0.0.
      - "127.0.0.1:3001:3001"

  google-workspace-mcp:
    image: ghcr.io/taylorwilsdon/google_workspace_mcp:${GOOGLE_WORKSPACE_MCP_VERSION:-latest}
    container_name: sysblok-mcp-google
    restart: unless-stopped
    command: ["--transport", "streamable-http", "--tool-tier", "${GOOGLE_WORKSPACE_TOOL_TIER:-core}"]
    environment:
      - MCP_ENABLE_OAUTH21=true
      - WORKSPACE_MCP_TRANSPORT=streamable-http
      - WORKSPACE_MCP_HOST=0.0.0.0
      - WORKSPACE_MCP_PORT=8000
      - GOOGLE_OAUTH_CLIENT_ID=${GOOGLE_OAUTH_CLIENT_ID}
      - GOOGLE_OAUTH_CLIENT_SECRET=${GOOGLE_OAUTH_CLIENT_SECRET}
      - GOOGLE_OAUTH_REDIRECT_URI=http://localhost:8000/oauth2callback
      - OAUTHLIB_INSECURE_TRANSPORT=1
      - WORKSPACE_MCP_CREDENTIALS_DIR=/root/.google_workspace_mcp/credentials
    ports:
      # loopback-only, and required: the browser hits localhost:8000
      # directly for the OAuth redirect, so this must be a published host
      # port, not just an internal compose-network address.
      - "127.0.0.1:8000:8000"
    volumes:
      # bind mount, not a named volume, so SETUP.md/a human can verify
      # auth succeeded with a plain `ls ./data/google-credentials`.
      - ./data/google-credentials:/root/.google_workspace_mcp/credentials
```
<!-- END-SYNC: docker-compose.yml -->

`.env.example`:

<!-- BEGIN-SYNC: .env.example -->
```bash
# ==============================================================================
# sysblok-mcp-bundle -- environment configuration
# Copy this file to .env and fill in the blanks. .env is gitignored and must
# never be committed -- see README.md "Secrets" section.
# ==============================================================================

# ---- Planka MCP (chmald/planka-mcp) -----------------------------------------

# ONE-TIME, org-wide constant: sysblok's Planka prod instance.
PLANKA_BASE_URL=https://board.sysblok.team

# PER-USER, self-generated: log into Planka -> avatar menu -> Settings ->
# API Keys -> Generate. Paste the token below. Do not share this with
# teammates -- generate your own.
PLANKA_API_KEY=

# Optional: pin a specific planka-mcp image tag instead of `latest`.
PLANKA_MCP_VERSION=latest


# ---- WordPress MCP (docdyhr/mcp-wordpress) ----------------------------------
# NOTE: WordPress MCP is NOT managed by docker-compose -- it's stdio-only and
# spawned on demand by your MCP client (see client-config.example.json).
# These values still live in .env so SETUP.md can read them once and write
# them straight into your MCP client config in the same pass.

# ONE-TIME, org-wide constant: sysblok's WordPress site URL.
WORDPRESS_SITE_URL=https://sysblok.ru

# PER-USER, self-generated: wp-admin -> your Profile -> Application Passwords
# -> "New Application Password Name" -> Add New. Requires Editor role or
# above. Copy the generated password (with spaces) exactly as shown.
WORDPRESS_USERNAME=
WORDPRESS_APP_PASSWORD=


# ---- Google Workspace MCP (taylorwilsdon/google_workspace_mcp) -------------

# ONE-TIME, ADMIN-PROVIDED: shared org-wide OAuth Client ID/Secret, "Desktop
# app" type, created once in Google Cloud Console with Docs+Sheets+Drive
# scopes enabled. Distributed by the admin via a side channel -- NOT this
# repo, NOT a public channel. Google does not treat Desktop-app client
# secrets as confidential (PKCE + localhost-only redirect protect the actual
# flow), but we still keep it out of git history as hygiene.
GOOGLE_OAUTH_CLIENT_ID=
GOOGLE_OAUTH_CLIENT_SECRET=

# Which Google Workspace tool set to expose. core = Docs+Sheets+Drive only,
# matching what this bundle is scoped for. Leave as-is unless you know you
# need `extended` or `complete`.
GOOGLE_WORKSPACE_TOOL_TIER=core

# Optional: pin a specific google_workspace_mcp image tag instead of `latest`.
GOOGLE_WORKSPACE_MCP_VERSION=latest
```
<!-- END-SYNC: .env.example -->

`client-config.example.json`:

<!-- BEGIN-SYNC: client-config.example.json -->
```json
{
  "mcpServers": {
    "wordpress": {
      "command": "docker",
      "args": [
        "run", "-i", "--rm",
        "-e", "WORDPRESS_SITE_URL",
        "-e", "WORDPRESS_USERNAME",
        "-e", "WORDPRESS_APP_PASSWORD",
        "docdyhr/mcp-wordpress:latest"
      ],
      "env": {
        "WORDPRESS_SITE_URL": "<filled in by SETUP.md from .env>",
        "WORDPRESS_USERNAME": "<filled in by SETUP.md from .env>",
        "WORDPRESS_APP_PASSWORD": "<filled in by SETUP.md from .env>"
      }
    },
    "planka": {
      "type": "sse",
      "url": "http://127.0.0.1:3001/sse"
    },
    "google-workspace": {
      "type": "http",
      "url": "http://127.0.0.1:8000/mcp"
    }
  }
}
```
<!-- END-SYNC: client-config.example.json -->

---

## Step 3 -- Create `.env` from `.env.example`

Copy the `.env.example` content you just wrote to `.env` in the same
directory. `PLANKA_BASE_URL` (`https://board.sysblok.team`) and
`WORDPRESS_SITE_URL` (`https://sysblok.ru`) are both already filled in as
fixed org-wide constants -- nothing to ask the human for here.

---

## Step 4 -- WordPress Application Password

Walk the human through:
1. Log into `$WORDPRESS_SITE_URL/wp-admin/`.
2. Go to your Profile (top-right avatar, or `/wp-admin/profile.php`).
3. Scroll to "Application Passwords".
4. Enter a name (e.g. "sysblok-mcp-bundle"), click "Add New Application Password".
5. Copy the generated password exactly as shown, including the spaces.

Requires the account to have Editor role or above. Write `WORDPRESS_USERNAME`
and `WORDPRESS_APP_PASSWORD` into `.env`. Verify it actually works before
moving on:

```bash
curl -u "$WORDPRESS_USERNAME:$WORDPRESS_APP_PASSWORD" \
  "$WORDPRESS_SITE_URL/wp-json/wp/v2/users/me"
```

This must return HTTP 200 with the expected user's JSON, not a 401. If it
fails, don't guess why -- show the human the actual error and ask them to
double check the password was copied correctly (a missing/extra space is
the most common mistake).

---

## Step 5 -- Planka API key

Walk the human through:
1. Log into `https://board.sysblok.team`.
2. Avatar menu (top-right) -> Settings -> API Keys -> Generate.
3. Copy the generated key.

Write `PLANKA_API_KEY` into `.env`. Verify:

```bash
curl -H "X-Api-Key: $PLANKA_API_KEY" "$PLANKA_BASE_URL/api/users/me"
```

Must return HTTP 200 with the expected user's JSON.

---

## Step 6 -- Bring up the persistent services

Ask the human for `GOOGLE_OAUTH_CLIENT_ID` and `GOOGLE_OAUTH_CLIENT_SECRET`
(admin-provided, shared org-wide values -- never invent or guess these,
ask the human or tell them to ask an admin). Write them into `.env`.

From the working directory, run:

```bash
docker compose up -d
```

Confirm both services are actually reachable -- don't just trust
`docker compose ps` status, probe the ports directly:

```bash
curl -sf -o /dev/null -w "planka-mcp: %{http_code}\n" http://127.0.0.1:3001/sse || echo "planka-mcp: not reachable"
curl -sf -o /dev/null -w "google-workspace-mcp: %{http_code}\n" http://127.0.0.1:8000/mcp || echo "google-workspace-mcp: not reachable"
```

A non-connection-refused response (even a 4xx) means the service is up and
listening. Do not proceed to Step 7 until both respond.

---

## Step 7 -- Google OAuth consent

Tell the human the Google Workspace MCP container is running and needs a
one-time browser consent to link their own Google account. Check the
container's startup logs for the exact consent-flow URL it prints:

```bash
docker compose logs google-workspace-mcp | grep -i -E "auth|oauth|consent" 
```

Have the human open that URL in their own browser (not yours) and complete
the Google consent screen. Confirm success by polling for the credentials
file landing on the host, rather than asking "did it work?":

```bash
ls ./data/google-credentials/
```

A file appearing there is the concrete signal that auth succeeded. If
nothing appears after a minute, check the container logs again for errors.

---

## Step 8 -- Wire up the MCP client config

Ask the human which MCP client they're using (Claude Code, Claude Desktop,
or another). Locate their real config file for their OS:

| Client | macOS | Windows | Linux |
|---|---|---|---|
| Claude Desktop | `~/Library/Application Support/Claude/claude_desktop_config.json` | `%APPDATA%\Claude\claude_desktop_config.json` | `~/.config/Claude/claude_desktop_config.json` |
| Claude Code | project `.mcp.json` in the current directory, or use `claude mcp add` | same | same |

**Before writing anything**: read the file if it already exists. Show the
human the exact change you intend to make -- merging the three
`mcpServers` entries from `client-config.example.json` (filling in the
`env` block's WordPress values from `.env`) into their existing config
*without* deleting or overwriting any other entries already there. Require
explicit confirmation before writing -- this is a real edit to the human's
own files.

For Claude Code, prefer `claude mcp add-json` (if the CLI is available)
over hand-editing `.mcp.json`, since it avoids manual JSON-merge mistakes.

**Older-client fallback**: if the client rejects `"type": "sse"` or
`"type": "http"` entries (some older Claude Desktop builds only understand
local `command`/`args` stdio servers), tell the human they'll need Node.js
installed and the `mcp-remote` npx bridge instead -- e.g.
`"command": "npx", "args": ["-y", "mcp-remote", "http://127.0.0.1:3001/sse"]`.
This is a fallback for outdated clients only, not the default path.

---

## Step 9 -- Recap

Print a checklist of what's done and what's still pending:

- [ ] Docker installed and working
- [ ] WordPress Application Password verified
- [ ] Planka API key verified
- [ ] `docker compose up -d` services reachable
- [ ] Google OAuth credentials present at `./data/google-credentials/`
- [ ] MCP client config written (confirmed by the human)

Remind the human of the two commands they'll want later:

```bash
docker compose up -d    # start planka-mcp + google-workspace-mcp again
docker compose down     # stop them
```

The WordPress server needs no start/stop -- it only runs for the duration
of each MCP session, spawned directly by the client.
