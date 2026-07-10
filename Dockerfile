ARG BUILD_FROM=ghcr.io/home-assistant/base:3.23
FROM ${BUILD_FROM}

# Node.js runtime for the MCP server
RUN apk add --no-cache nodejs npm

WORKDIR /app

# Install dependencies and build the TypeScript sources.
# `npm ci` runs the package's `prepare` script (`npm run build`), so src/ must
# already be present; devDependencies (typescript, etc.) are pruned afterwards.
COPY package.json package-lock.json tsconfig.json ./
COPY src ./src
RUN npm ci \
    && npm prune --omit=dev

# Home Assistant app service definition (s6-overlay) and metadata
COPY rootfs /

LABEL \
    org.opencontainers.image.title="SSH MCP Server" \
    org.opencontainers.image.description="MCP server exposing SSH command execution on a remote host to MCP-compatible AI clients." \
    org.opencontainers.image.source="https://github.com/10bn/ssh-mcp-hass-addon" \
    org.opencontainers.image.licenses="MIT"
