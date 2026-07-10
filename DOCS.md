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
| `api_key`         | Secret required to call the HTTP endpoint, either as a bearer token or embedded in the URL. **Strongly recommended**, see below.   |

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
one. Set `api_key` and configure your MCP client to send it as
`Authorization: Bearer <api_key>`. Only expose the port beyond your local
network if you know what you are doing (e.g. behind a VPN or reverse proxy
that also enforces authentication).

## Connecting an MCP client

There are two equivalent ways to authenticate, depending on what your client
supports:

**With a header** — point the client at the fixed path and send the key as a
bearer token:

```
http://<home-assistant-host>:3000/mcp
Authorization: Bearer <api_key>
```

**With a URL only** — no custom header required, the key is embedded in the
path instead (same idea as Home Assistant's own `/api/webhook/<id>` URLs).
Use this for clients/tools that only let you paste in a URL:

```
http://<home-assistant-host>:3000/private_<api_key>
```

Anyone who doesn't know the exact `<api_key>` gets a `404` from this path (it
doesn't reveal that `/private_` is meaningful), so keep the full URL as
secret as you would a password. Both paths require `api_key` to be set; if
you left it empty, `/mcp` is open to anyone who can reach the port and the
`/private_...` path is disabled.

For clients that only support the stdio transport (e.g. some Claude Desktop
setups), use [`mcp-remote`](https://www.npmjs.com/package/mcp-remote) as a
bridge — either form works:

```json
{
  "mcpServers": {
    "ssh-mcp": {
      "command": "npx",
      "args": ["mcp-remote", "http://<home-assistant-host>:3000/private_<api_key>"]
    }
  }
}
```

## Tools

See the main [README](./README.md#tools) for the full `exec` / `sudo-exec` tool
reference — behavior is identical to running `ssh-mcp` directly, the app just
wraps it as a managed, network-reachable service.
