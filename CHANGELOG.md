# Changelog

## 1.6.0

- Add a Home Assistant App (add-on) packaging: `config.yaml`, `Dockerfile`, and
  s6-overlay service scripts so this fork can be installed directly from a
  Home Assistant app/add-on repository.
- Add a Streamable HTTP transport (`--transport=http`, `--httpPort`,
  `--apiKey`) so the server can run as a persistent network service, secured
  with an optional bearer token. The default `stdio` transport used by the
  CLI/npm package is unchanged.
