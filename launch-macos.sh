#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if ! command -v pwsh >/dev/null 2>&1; then
  echo "PowerShell 7 (pwsh) is required to run Bitaxe Difficulty Tracker on macOS."
  echo "Install it with: brew install --cask powershell"
  exit 1
fi

MACOS_BIN="$SCRIPT_DIR/.macos-bin"
mkdir -p "$MACOS_BIN"

cat > "$MACOS_BIN/netsh" <<'EOF'
#!/usr/bin/env bash
# Compatibility shim for Windows-only startup calls.
# The original app calls this during Windows setup; on macOS it is harmless.
exit 0
EOF
chmod +x "$MACOS_BIN/netsh"

cat > "$MACOS_BIN/powershell.exe" <<'EOF'
#!/usr/bin/env bash
args=()
for arg in "$@"; do
  if [[ "$arg" == "-Verb" || "$arg" == "RunAs" ]]; then
    continue
  fi
  args+=("$arg")
done
exec pwsh "${args[@]}"
EOF
chmod +x "$MACOS_BIN/powershell.exe"

export PATH="$MACOS_BIN:$PATH"

echo ""
echo "  =========================================="
echo "   Bitaxe Difficulty Tracker - macOS"
echo "   Starting relay on port 19248"
echo "  =========================================="
echo ""

pwsh -NoProfile -ExecutionPolicy Bypass -Command '
$scriptDir = (Get-Location).Path

function Get-NetIPAddress {
  param([string]$AddressFamily = "IPv4")
  $family = switch ($AddressFamily) {
    "IPv4" { [System.Net.Sockets.AddressFamily]::InterNetwork }
    "IPv6" { [System.Net.Sockets.AddressFamily]::InterNetworkV6 }
    default { [System.Net.Sockets.AddressFamily]::InterNetwork }
  }

  $hits = @()
  foreach ($nic in [System.Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces()) {
    foreach ($addr in $nic.GetIPProperties().UnicastAddresses) {
      if ($addr.Address.AddressFamily -eq $family) {
        $ip = $addr.Address.ToString()
        if ($ip -notmatch "^127\.") {
          $hits += [pscustomobject]@{ IPAddress = $ip }
        }
      }
    }
  }

  if (-not $hits) { $hits += [pscustomobject]@{ IPAddress = "127.0.0.1" } }
  return $hits
}

Write-Host ""
Write-Host "  ==========================================" -ForegroundColor Cyan
Write-Host "   AxeOS Difficulty Tracker - Server" -ForegroundColor Cyan
Write-Host "   http://localhost:19248" -ForegroundColor Green
Write-Host "   Close this window to stop the server." -ForegroundColor Yellow
Write-Host "  ==========================================" -ForegroundColor Cyan
Write-Host ""

& (Join-Path $scriptDir "server.ps1")
'