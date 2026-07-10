# Home Assistant App: SSH MCP Server

This app runs [ssh-mcp](https://github.com/10bn/ssh-mcp-hass-addon) as a persistent
service inside Home Assistant, exposing it over the network as a
[Streamable HTTP](https://modelcontextprotocol.io/) MCP endpoint at `/mcp` on port
`3000`. Any MCP-compatible client (Claude Desktop/Code via `mcp-remote`, Home
Assistant's own MCP Client integration, Cursor, etc.) can connect to it to run
shell commands on a remote Linux/Windows host over SSH.

## Installation

1. In Home Assistant, go to **Settings → Add-ons → Add-on store** (a.k.a. **App store**).
2. Open the menu (⋮) → **Repositories**, and add:
   `https://github.com/10bn/ssh-mcp-hass-addon`
3. Find **SSH MCP Server** in the store and install it.

## Configuration

| Option          | Description                                                                            |
| ---------------- | --------------------------------------------------------------------------------------- |
| `host`           | Hostname or IP of the machine you want to control over SSH. **Required.**              |
| `port`            | SSH port of that machine. Default `22`.                                                |
| `user`            | SSH username. **Required.**                                                            |
| `password`        | SSH password. Leave empty if you use a key instead.                                    |
| `ssh_key_path`    | Path to a private key, **relative to `/config`**. See below.                            |
| `sudo_password`   | Password for the `sudo-exec` tool.                                                      |
| `su_password`     | Password used to open a persistent root shell via `su -`.                              |
| `disable_sudo`    | Disable the `sudo-exec` tool entirely.                                                  |
| `timeout`         | Command timeout in milliseconds. Default `60000`.                                       |
| `max_chars`       | Max characters per command. `none` disables the limit. Default `1000`.                  |
| `api_key`         | Optional: pin a fixed secret for the HTTP endpoint. Leave empty — a secret is auto-generated and persisted for you, see below.   |

### Auto-generated secret (recommended: leave `api_key` empty)

If you don't set `api_key`, the app generates a random 128-bit secret on
first start and persists it in the app's own data directory — it survives
restarts and updates. After starting the app, open its **Log** tab and look
for a line like:

```
🔐 No-header MCP URL: http://<host>:3000/private_eS2obRZUylNYYUWgfftrAw
```

Copy that URL (with `<host>` replaced by your Home Assistant host) straight
into your MCP client — no header configuration needed. Setting `api_key`
manually instead pins a fixed value of your choosing, e.g. if you want the
URL to stay predictable across a fresh install.

If you remapped the port on this app's **Network** tab (Settings → this app
→ Network), the log line already reflects that remapped port automatically —
always use the port shown in the log, not necessarily `3000`.

### Using an SSH key instead of a password

The Home Assistant `/config` directory is mounted read-write into the app. Copy
your private key there (e.g. via the File editor or Samba app) to
`/config/ssh-mcp/id_rsa`, then set:

```yaml
ssh_key_path: ssh-mcp/id_rsa
```

### Securing the endpoint

The app listens on TCP port `3000` for anyone who can reach the Home Assistant
host on your network — this is a shell-execution endpoint, so treat it like
one. By default a secret is always required (see above); only expose the port
beyond your local network if you know what you are doing (e.g. behind a VPN
or reverse proxy that also enforces authentication), and keep the full
`/private_...` URL — or the `api_key` value — as confidential as a password.

## Connecting an MCP client

`3000` below is the app's default port — if you remapped it on the app's
**Network** tab, use that port instead (also shown in the app's Log tab).

There are two equivalent ways to authenticate, depending on what your client
supports:

**With a header** — point the client at the fixed path and send the key as a
bearer token:

```
http://<home-assistant-host>:3000/mcp
Authorization: Bearer <secret>
```

**With a URL only** — no custom header required, the key is embedded in the
path instead (same idea as Home Assistant's own `/api/webhook/<id>` URLs).
Use this for clients/tools that only let you paste in a URL:

```
http://<home-assistant-host>:3000/private_<secret>
```

Anyone who doesn't know the exact secret gets a `404` from this path (it
doesn't reveal that `/private_` is meaningful), so keep the full URL as
secret as you would a password. This app always has a secret — either the
auto-generated one (default) or your pinned `api_key` value.

For clients that only support the stdio transport (e.g. some Claude Desktop
setups), use [`mcp-remote`](https://www.npmjs.com/package/mcp-remote) as a
bridge — either form works:

```json
{
  "mcpServers": {
    "ssh-mcp": {
      "command": "npx",
      "args": ["mcp-remote", "http://<home-assistant-host>:3000/private_<secret>"]
    }
  }
}
```

## Tools

See the main [README](./README.md#tools) for the full `exec` / `sudo-exec` tool
reference — behavior is identical to running `ssh-mcp` directly, the app just
wraps it as a managed, network-reachable service.
