#!/bin/bash

MCP_CONFIG='{
  "mcpServers": {
    "TalkToFigma": {
      "command": "bunx",
      "args": [
        "talk-to-figma-mcp@latest"
      ]
    }
  }
}'

bun install

# IDE that reads .cursor/mcp.json
mkdir -p .cursor
echo "$MCP_CONFIG" > .cursor/mcp.json
echo "✓ MCP config written to .cursor/mcp.json"

# Claude Code: write .mcp.json in project root
echo "$MCP_CONFIG" > .mcp.json
echo "✓ Claude Code MCP config written to .mcp.json"