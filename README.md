# SSH MCP Server — Home Assistant App

[![Add repository to my Home Assistant](https://my.home-assistant.io/badges/supervisor_add_addon_repository.svg)](https://my.home-assistant.io/redirect/supervisor_add_addon_repository/?repository_url=https%3A%2F%2Fgithub.com%2F10bn%2Fssh-mcp-hass-addon)

[![NPM Version](https://img.shields.io/npm/v/ssh-mcp)](https://www.npmjs.com/package/ssh-mcp)
[![Node Version](https://img.shields.io/node/v/ssh-mcp)](https://nodejs.org/)
[![License](https://img.shields.io/github/license/tufantunc/ssh-mcp)](./LICENSE)
[![Build Status](https://github.com/tufantunc/ssh-mcp/actions/workflows/publish.yml/badge.svg)](https://github.com/tufantunc/ssh-mcp/actions)

This is a fork of [**tufantunc/ssh-mcp**](https://github.com/tufantunc/ssh-mcp) — see
[Attribution](#attribution) below — packaged to run as a native
**[Home Assistant App](https://developers.home-assistant.io/docs/apps/)** (add-on).
It exposes SSH command execution on a remote Linux/Windows host as a
[Model Context Protocol](https://modelcontextprotocol.io/) server, so MCP clients
(Claude, Cursor, and others) can run shell commands on that host through natural
language. Running it as a Home Assistant App turns it into a persistent, always-on
service reachable over the network, instead of a process an MCP client has to spawn
itself.

## Contents

- [Install as a Home Assistant App](#install-as-a-home-assistant-app)
- [Configuration](#configuration)
- [Connecting an MCP client](#connecting-an-mcp-client)
- [Standalone / CLI usage](#standalone--cli-usage)
- [Tools](#tools)
- [Testing](#testing)
- [Attribution](#attribution)
- [Disclaimer](#disclaimer)
- [Support](#support)

## Install as a Home Assistant App

1. Click the badge above, or manually: in Home Assistant go to
   **Settings → Add-ons → Add-on store**, open the menu (⋮) → **Repositories**,
   and add:
   ```
   https://github.com/10bn/ssh-mcp-hass-addon
   ```
2. Find **SSH MCP Server** in the store and install it.
3. Open the **Configuration** tab and set at least `host`, `user`, and either
   `password` or `ssh_key_path` for the machine you want to control. Leave
   `api_key` empty — a secret is generated for you automatically.
4. Start the app, then check its **Log** tab for a `🔐 No-header MCP URL`
   line — that's your ready-to-use, pre-authenticated endpoint.

Full option-by-option reference: [DOCS.md](./DOCS.md).

## Configuration

| Option          | Description                                                                           |
| --------------- | -------------------------------------------------------------------------------------- |
| `host`          | Hostname or IP of the machine to control over SSH. **Required.**                       |
| `port`          | SSH port of *that machine* (not this app's own port — see below). Default `22`.        |
| `user`          | SSH username. **Required.**                                                            |
| `password`      | SSH password. Leave empty if you use a key instead.                                    |
| `ssh_key_path`  | Path to a private key, **relative to `/config`** (the app mounts it read-write).       |
| `sudo_password` | Password for the `sudo-exec` tool.                                                     |
| `su_password`   | Password used to open a persistent root shell via `su -`.                              |
| `disable_sudo`  | Disable the `sudo-exec` tool entirely.                                                  |
| `timeout`       | Command timeout in milliseconds. Default `60000`.                                       |
| `max_chars`     | Max characters per command. `none` disables the limit. Default `1000`.                  |
| `api_key`       | Optional: pin a fixed secret. Leave empty and one is auto-generated for you — see the app's log after first start. |

The endpoint is a shell-execution API. A secret is always required by default
(auto-generated if you don't set `api_key`) — only expose the port beyond
your LAN behind something that also enforces authentication (VPN, reverse
proxy). See [DOCS.md](./DOCS.md#using-an-ssh-key-instead-of-a-password) for
SSH-key setup.

This app's own MCP port defaults to `3000` and is remapped, if needed, via
the app's **Network** tab in Home Assistant — not via the `port` option
above, which is unrelated (that's the *target* machine's SSH port). The
app's Log tab always shows whichever port is actually reachable.

## Connecting an MCP client

Point any Streamable-HTTP-capable MCP client at:

```
http://<home-assistant-host>:3000/mcp
```

with header `Authorization: Bearer <secret>`. If your client can't set custom
headers, use the URL-only form instead — same secret, embedded in the path
(copy it straight from the app's log, look for `🔐 No-header MCP URL`):

```
http://<home-assistant-host>:3000/private_<secret>
```

For stdio-only clients (some Claude Desktop setups), bridge with
[`mcp-remote`](https://www.npmjs.com/package/mcp-remote) (either URL form works):

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

See [DOCS.md](./DOCS.md#connecting-an-mcp-client) for details on both forms.

## Standalone / CLI usage

The underlying server also works as a plain MCP stdio server outside of Home
Assistant — e.g. with Claude Desktop, Claude Code, or Cursor talking to it
directly over stdio (no HTTP, no `api_key`).

```bash
git clone https://github.com/10bn/ssh-mcp-hass-addon.git
cd ssh-mcp-hass-addon
npm install
```

```jsonc
{
  "mcpServers": {
    "ssh-mcp": {
      "command": "npx",
      "args": [
        "ssh-mcp", "-y", "--",
        "--host=1.2.3.4", "--port=22", "--user=root",
        "--password=pass", "--key=path/to/key",
        "--timeout=30000", "--maxChars=none"
      ]
    }
  }
}
```

**Claude Code:**

```bash
claude mcp add --transport stdio ssh-mcp -- npx -y ssh-mcp -- --host=YOUR_HOST --user=YOUR_USER --password=YOUR_PASSWORD
```

Both transports — stdio (default, used above) and the HTTP transport used by the
Home Assistant App — are built into the same server:

- `--transport`: `stdio` (default) or `http`
- `--httpPort`: port for the HTTP endpoint (default `3000`, only with `--transport=http`)
- `--apiKey=<value>`: pin a fixed secret (otherwise one is auto-generated — see below)
- `--secretPathFile=<path>`: persist the auto-generated secret here so it survives restarts (the Home Assistant App sets this to a file under its own `/data` directory automatically)
- `--disableAuth`: explicitly run the HTTP endpoint with no secret at all

In HTTP mode, requests must either send `Authorization: Bearer <secret>` on
`/mcp`, or hit `/private_<secret>` directly (no header needed). Unless
`--disableAuth` is passed, a secret always exists: your `--apiKey`, or
(without one) a freshly generated 128-bit secret printed to the log on
startup — it changes on every restart unless `--secretPathFile` is set.

## Tools

- `exec`: Execute a shell command on the remote server
  - `command` (required): shell command to run
  - `description` (optional): appended as a trailing comment
- `sudo-exec`: Execute a shell command with sudo elevation
  - Same parameters as `exec`
  - Uses `sudo_password`/`--sudoPassword` if set, otherwise assumes passwordless sudo
  - For a persistent root shell instead, set `su_password`/`--suPassword`
  - Disabled entirely via the `disable_sudo` option / `--disableSudo` flag

Both tools share the `timeout` and `max_chars` limits described in
[Configuration](#configuration).

## Testing

```sh
npm run inspect
```

Opens the [MCP Inspector](https://modelcontextprotocol.io/docs/tools/inspector)
for visual debugging against a locally running server.

## Attribution

This repository is a fork of [**tufantunc/ssh-mcp**](https://github.com/tufantunc/ssh-mcp)
by [Tufan Tunç](https://github.com/tufantunc), licensed under the [MIT License](./LICENSE).
All core SSH/MCP functionality (the `exec`/`sudo-exec` tools, connection handling,
sudo/su elevation) originates from the upstream project. This fork adds the
Streamable HTTP transport and the Home Assistant App packaging on top of it.
Please direct upstream bugs/features to the original repository, and
Home-Assistant-packaging-specific issues here.

The auto-generated, no-header `/private_<secret>` authentication scheme is
modeled on the same approach used by
[**homeassistant-ai/ha-mcp**](https://github.com/homeassistant-ai/ha-mcp)'s
Home Assistant App packaging.

## Disclaimer

SSH MCP Server is provided under the [MIT License](./LICENSE). Use at your own
risk. This project is not affiliated with or endorsed by Home Assistant, any SSH
provider, or any MCP provider.

## Contributing

See [Contributing Guidelines](./CONTRIBUTING.md) and the
[Code of Conduct](./CODE_OF_CONDUCT.md).

## Support

If you find this useful, consider starring the repository — and the
[original project](https://github.com/tufantunc/ssh-mcp) it's built on.
