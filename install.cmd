@echo off
rem claude-code-bootstrap: double-click launcher for Windows (or run from CMD).
rem Uses install.ps1 next to this file if present, otherwise downloads it.
setlocal
if exist "%~dp0install.ps1" (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1"
) else (
  powershell -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol=[Net.ServicePointManager]::SecurityProtocol -bor 3072; irm https://raw.githubusercontent.com/gacabartosz/claude-code-bootstrap/main/install.ps1 | iex"
)
echo.
pause
