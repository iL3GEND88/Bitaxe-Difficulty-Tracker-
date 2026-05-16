# AxeOS Difficulty Tracker

A real-time share difficulty monitor and full dashboard for home Bitcoin miners running AxeOS firmware — Bitaxe, NerdQaxe++, Titan, and compatible devices.

No cloud. No accounts. No installs beyond the files in this zip. Runs entirely on your local network. Full companion mobile app for iPhone via Safari over WiFi.

---

## Quick Start

1. Download and unzip all files into the same folder
2. Right-click **`Launch Bitaxe Monitor.bat`** → **Run as administrator**
3. Edge opens automatically at `http://localhost:19248`
4. On iPhone: open Safari and go to the IP shown in yellow in the console window (e.g. `http://10.0.0.145:19248`)

> **Running as administrator is required** so the server can bind to your network interface and allow your phone to connect.

---

## Windows Firewall Setup (iPhone Access)

If Safari on your iPhone cannot reach the app, Windows Firewall may be blocking port 19248.

**Option 1 — PowerShell (run as Administrator):**
```
netsh advfirewall firewall add rule name="Bitaxe Monitor" dir=in action=allow protocol=TCP localport=19248
```

**Option 2 — Manual:**
1. Open **Windows Defender Firewall with Advanced Security**
2. Click **Inbound Rules** → **New Rule…**
3. Select **Port** → Next
4. Select **TCP**, enter `19248` → Next
5. Select **Allow the connection** → Next
6. Check **Private** (uncheck Public) → Next
7. Name it `Bitaxe Monitor` → Finish

---

## Requirements

- Windows 10 or 11 PC
- Microsoft Edge (pre-installed)
- PowerShell (pre-installed)
- Miners running AxeOS firmware on the same local network
- iPhone with Safari (for mobile companion app)

---

## Files

| File | Purpose |
|---|---|
| `BitaxeMonitor.html` | Main Windows dashboard |
| `mobile.html` | iPhone Safari companion app |
| `server.ps1` | PowerShell HTTP proxy server |
| `Launch Bitaxe Monitor.bat` | Launcher — run as administrator |
| `README.md` | This file |

---

## Windows App Features

### Live Difficulty Chart
- Every share attempt plotted in real time from the miner's log stream
- Pool target shown as a dashed line — detects variable difficulty pools automatically
- Green dots on accepted shares, colored lines per miner with area fill
- Hover tooltip: exact difficulty, accepted/rejected, pool target, timestamp
- Log or Linear Y-axis scale toggle, Y-axis scale slider
- Time range: 10s / 30s / 1m / 5m / 30m / 1h / 6h / 24h / 1w / All
- X-axis scroll and zoom — scrub back through history

### Hashrate / Temperature Chart
- Hashrate over time per miner
- Temperature lines per ASIC and VR sensor, color-coded green/orange/red
- Toggle between Difficulty and Hashrate/Temp charts

### Chart Layouts
- **Combined** — all miners on one chart
- **Split** — each miner gets its own panel
- **Both** — combined + individual panels
- Resize panels by dragging the handle

### Stats Column (per miner)
- Resizable — font scales with width, saves between sessions
- All-Time Best, Session Best, Status/Uptime
- Shares, Rejected (with %), Avg/share, HR, Last diff, Pool Target
- ASIC and VR temperatures with color coding:
  - ASIC: green <65°C, orange 65–69°C, red ≥70°C
  - VR: green ≤70°C, orange 71–80°C, red >80°C
- Top N best difficulties this session (10/25/50/100)

### 📊 Stats Visibility Dropdown
Show or hide individual stat sections per miner card:
Best Difficulty banner, Status/Uptime, Shares/Rejected/Last, Temperatures, Top Diffs List

### ⭐ All-Time Hall of Fame
- Stores up to 500 best shares per miner — persists forever
- Synced to server so iPhone reads the same list
- Selectable top 10/25/50/100 view, reset button

### ⚙ Settings Panel
Full-screen overlay per miner:
- Frequency (MHz), Core Voltage (mV)
- Auto Fan: Target Temp (35–66°C), Min Fan Speed (0–99%)
- Manual Fan: Fan Speed (0–100%)
- Save and Restart buttons

### ⛁ Pool Settings Panel
Full-screen overlay per miner:
- Primary + Fallback: Stratum Host, Port, User, Password
- Advanced: Suggested Difficulty, Extranonce Subscribe, Decode Coinbase Tx
- Connection Security: No TLS / TLS System cert / TLS Custom CA
- Save and Restart buttons

### Auto-Restart
- Per-miner toggle — saves between sessions
- Requires **both**: no shares for 5 min **and** hashrate near zero
- Max 3 restarts per hour — red warning when limit reached

### Other
- Block Found full-screen alert with audio beep
- Total Hashrate chip in header (combined all miners)
- Unlimited miners, custom colors, add/remove with ✕
- ⏻ Close App shuts down server cleanly

---

## iPhone Safari Companion App

Opening the server address in iPhone Safari automatically loads the mobile app.

### ⛏ Miners Tab
- Card per miner with all live stats from Windows:
  All-Time Best, Session Best, Status/Uptime, Shares, Rejected %, Avg/share, HR, Last, Frequency, Voltage, Fan Speed
- Temperature bars (color coded)
- Color picker per miner (tap the colored circle)
- Remove miner with ✕ button, Add Miner input at top
- Total Hashrate card (2+ miners)
- Difficulty chart (last 60 shares) and Hashrate/Temp chart (last 200 samples) per miner

### 📋 Session Tab
- Top 10/25/50/100 best shares this session
- Pulled live from Windows — exact match

### ⭐ All-Time Tab
- Top 10/25/50/100 all-time best per miner
- Same data as Windows hall of fame

### ⛁ Pool Tab
- Primary + Fallback stratum settings
- Advanced options, Connection Security
- Save and Restart per miner

### ⚙ Settings Tab
- Frequency, Voltage, Fan control per miner
- Save and Restart per miner

### General
- Auto-refreshes every 5 seconds
- Pauses when any input is focused
- Color picker auto-refreshes on color selection
- Manual Refresh button in header

---

## Supported Devices

| Device | Notes |
|---|---|
| Bitaxe (all models) | Full support |
| Bitaxe Duo 650 | Single ASIC temp sensor |
| NerdQaxe++ | ANSI stripping + slash log format |
| Titan | AxeOS compatible |
| NerdMiner v2 | No API — shows ⚠ warning |

---

## How It Works

The `.bat` launches a PowerShell HTTP server on port 19248 that:
- Serves the dashboard and mobile app to browsers on your local network
- Redirects iPhone/iPad to the mobile app automatically
- Proxies WebSocket connections and REST API calls to your miners
- Stores shared state in memory: miner list, all-time data, live session data
- All traffic stays on your local network — nothing leaves your home

---

## License

MIT — do whatever you want with it.
