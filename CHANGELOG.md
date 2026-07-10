# Changelog

## 1.6.1

- Add a URL-only way to authenticate against the HTTP transport:
  `GET/POST/DELETE /private_<apiKey>` accepts the same `apiKey` embedded in
  the path instead of an `Authorization` header, for MCP clients/tools that
  can only be configured with a bare URL. Requires `apiKey` to be set; the
  existing header-based `/mcp` path is unchanged. Unknown tokens on the
  `/private_...` path get a generic `404` rather than a `401`, so the route
  doesn't confirm its own existence to guessers.

## 1.6.0

- Add a Home Assistant App (add-on) packaging: `config.yaml`, `Dockerfile`, and
  s6-overlay service scripts so this fork can be installed directly from a
  Home Assistant app/add-on repository.
- Add a Streamable HTTP transport (`--transport=http`, `--httpPort`,
  `--apiKey`) so the server can run as a persistent network service, secured
  with an optional bearer token. The default `stdio` transport used by the
  CLI/npm package is unchanged.
