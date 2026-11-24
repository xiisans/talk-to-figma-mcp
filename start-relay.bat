@echo off
chcp 65001 >nul
title Figma MCP WebSocket Relay (port 3055)
REM ===== 只需改这一行：指向你解压后的仓库根目录 =====
set "ROOT=F:\figma-mcp\talk-to-figma-mcp"
set "BUN=%USERPROFILE%\.bun\bin\bun.exe"
if not exist "%BUN%" (
  echo [ERROR] bun.exe not found: %BUN%
  echo Install Bun first:  powershell -c "irm bun.sh/install.ps1 ^| iex"
  pause
  exit /b 1
)
if not exist "%ROOT%\src\socket.ts" (
  echo [ERROR] socket.ts not found under: %ROOT%
  echo Edit ROOT in this .bat to your repo path.
  pause
  exit /b 1
)
cd /d "%ROOT%"
echo Starting relay on ws://localhost:3055  (keep this window open)
"%BUN%" run src\socket.ts
echo.
echo Relay stopped. Press any key to close.
pause >nul