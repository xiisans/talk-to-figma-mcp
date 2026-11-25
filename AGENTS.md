# AGENTS.md

This file provides guidance to AI coding agents (Claude Code, Codex, Cursor, Windsurf, Cline, or any MCP-capable client) when working with code in this repository. Hand this file to any such agent and ask it to set the project up or help with a change.

## Project Overview

MCP (Model Context Protocol) server that bridges AI agents (any MCP-compatible client, such as Claude Code, Cursor, Windsurf, or Cline) with Figma. Three components communicate in a pipeline:

```
AI agent (MCP client) ←(stdio)→ MCP Server ←(WebSocket)→ WebSocket Relay ←(WebSocket)→ Figma Plugin
```

## Build & Development Commands

```bash
bun install              # Install dependencies
bun run build            # Build MCP server (tsup → dist/)
bun run dev              # Build in watch mode
bun socket               # Start WebSocket relay server (port 3055)
bun run start            # Run built MCP server
bun setup                # Full setup (install + write .cursor/mcp.json + .mcp.json)
```

`.cursor/mcp.json` is the config path read by Cursor; other MCP clients use their own config file but the same server entry.

There is no test suite or linter configured.

## Architecture

### MCP Server (`src/talk_to_figma_mcp/server.ts`)
The main server implementing the MCP protocol via `@modelcontextprotocol/sdk`. Exposes 50+ tools (create shapes, modify text, manage layouts, export images, etc.) and several AI prompts (design strategies). Communicates with the AI agent over stdio and with the WebSocket relay via `ws`. Each request gets a UUID, is tracked in a `pendingRequests` Map with timeout/promise callbacks, and resolves when the plugin responds.

### WebSocket Relay (`src/socket.ts`)
Lightweight Bun WebSocket server on port 3055 (configurable via `PORT` env). Routes messages between MCP server and Figma plugin using channel-based isolation. Clients call `join` to enter a channel; messages broadcast only within the same channel.

### Figma Plugin (`src/mcp_plugin/`)
Runs inside Figma. `code.js` is the plugin main thread handling 30+ commands via a dispatcher. `ui.html` is the plugin UI for WebSocket connection management. `manifest.json` declares permissions (dynamic-page access, localhost network). The plugin is **not built/bundled** — `code.js` is written directly as the runtime artifact.

## Key Patterns

- **Colors**: Figma uses RGBA 0-1 range. The MCP tools accept 0-1 floats and the filter converts to hex for display.
- **Logging**: All logs go to stderr. Stdout is reserved for MCP protocol messages.
- **Timeouts**: 30s default per command. Progress updates from the plugin reset the inactivity timer.
- **Chunking**: Large operations (scanning 100+ nodes) are chunked with progress updates to prevent Figma UI freezing.
- **Reconnection**: WebSocket auto-reconnects after 2 seconds on disconnect.
- **Zod validation**: All tool parameters are validated with Zod schemas.

## Setup & Onboarding (for AI agents)

Prerequisites: **Bun** (required — runs the server and the relay) and **Git**. Node.js is optional. Install Bun with Homebrew (`brew install bun`) when admin access and Homebrew are available, otherwise run `curl -fsSL https://bun.sh/install | bash` (writes to the home dir, no admin needed). Verify with `bun --version`.

Quick setup, from the project root:

```bash
bun install      # install dependencies
bun run build    # build the MCP server
bun setup        # writes MCP config to .cursor/mcp.json and .mcp.json
```

`bun setup` writes `.cursor/mcp.json` (read by Cursor) and `.mcp.json` (read by Claude Code). For any other client, copy the same server entry into that client's MCP config file. The config uses the published package:

```json
{
  "mcpServers": {
    "TalkToFigma": {
      "command": "bunx",
      "args": ["talk-to-figma-mcp@latest"]
    }
  }
}
```

You can also add it manually for Claude Code via the CLI:

```bash
claude mcp add TalkToFigma -- bunx talk-to-figma-mcp@latest
```

### Run & verify

1. **Start the relay** in a dedicated terminal and keep it open: `bun socket > websocket.log 2>&1`. The log should begin with `WebSocket server running on port 3055`. Watch it live from a second terminal with `tail -f websocket.log`.
2. **Confirm the MCP server** is connected in your client (Cursor: Settings → MCP; Claude Code: `claude mcp list`). It should list `TalkToFigma`.
3. **Install the Figma plugin** — either from the [community page](https://www.figma.com/community/plugin/1485687494525374295/cursor-talk-to-figma-mcp-plugin) (URL slug fixed by Figma), or locally via Plugins → Development → Import plugin from manifest → `src/mcp_plugin/manifest.json`.
4. **Run the plugin**, join a channel (default `ws://localhost:3055`); `websocket.log` should log the new connection.
5. **End-to-end test** from your client: `join_channel` (expect success), then `get_document_info` (expect JSON from the document).

### Troubleshooting

- **MCP not connected** — confirm you're in the project root (`package.json` + `src/` present) and that `.mcp.json` or `.cursor/mcp.json` exists (re-run `bun setup`), then reload the client so it re-reads its MCP config.
- **Port 3055 busy** — macOS/Linux: `lsof -ti:3055 | xargs kill -9`; Windows: `netstat -ano | findstr 3055` then `taskkill /PID <pid> /F`.
- **Plugin won't connect** — the relay must be running, the plugin URL must be `ws://localhost:3055`, and nothing may block localhost:3055. Watch `websocket.log` and reconnect the plugin.

## Agent Notes

- Always call `join_channel` before issuing any Figma commands
- Call `get_document_info` first to understand the design structure
- Use `read_my_design` or `get_selection` before making modifications
- Batch operations (`set_multiple_text_contents`, `delete_multiple_nodes`, `set_multiple_annotations`) are preferred over repeated single-node calls for performance
- All MCP tool parameters are Zod-validated; invalid inputs return structured errors
- The plugin and relay must both be running before any tool calls succeed
