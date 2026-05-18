# AxeOS Difficulty Tracker

A real-time share difficulty monitor and full dashboard for home Bitcoin miners running AxeOS firmware — Bitaxe, NerdQaxe++, Titan, and compatible devices.

No cloud. No accounts. No installs beyond the files in this zip. Runs entirely on your local network. Full companion mobile app for iPhone via Safari over WiFi or Tailscale.

---

## Quick Start

1. Download and unzip all files into the same folder
2. Right-click **`Launch Bitaxe Monitor.bat`** → **Run as administrator**
3. Edge opens automatically at `http://localhost:19248`
4. On iPhone: open Safari and go to the IP shown in yellow in the console window (e.g. `http://10.0.0.145:19248`)

> **Running as administrator is required** so the server can bind to your network interface and allow your phone to connect.

---

## Remote Access via Tailscale

To access your app from anywhere (not just home WiFi):

1. Install [Tailscale](https://tailscale.com) on your Windows PC and iPhone
2. Sign in with the same account on both devices
3. Note your PC's Tailscale IP (e.g. `100.x.x.x`) from the Tailscale app
4. On iPhone: open Safari and go to `http://100.x.x.x:19248`

Your PC must be on and the server must be running. Tailscale does **not** route all your iPhone traffic through your home — only traffic to your PC's Tailscale IP.

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
- Shares, Rejected (with %), Avg/share, HR, Error Rate, Last diff, Pool Target
- ASIC and VR temperatures with color coding:
  - ASIC: green <65°C, orange 65–69°C, red ≥70°C
  - VR: green ≤70°C, orange 71–80°C, red >80°C
- Top N best difficulties this session (10/25/50/100)

### 📊 Stats Visibility Dropdown
Show or hide individual elements per miner card:
Best Difficulty, Status/Uptime, Shares, Rejected, Hashrate, Error Rate, Avg/Share, Target, Last, Temperatures, Top Diffs List, Live Log

### 📋 Session Best (Fullscreen)
- Full-screen overlay of top session shares across all miners
- Selectable top 10/25/50/100

### ⭐ All-Time Hall of Fame
- Stores up to 500 best shares per miner — persists forever
- Integrates with AxeOS Scoreboard — imports entries automatically on connect and every 30 seconds
- Synced to server so iPhone reads the same list
- Selectable top 10/25/50/100 view

### ⚙ Settings Panel
Full-screen overlay per miner:
- Frequency (MHz), Core Voltage (mV)
- Auto Fan: Target Temp (35–66°C), Min Fan Speed (0–99%)
- Manual Fan: Fan Speed (0–100%)
- Save and Restart buttons

### ⛁ Pool Settings Panel
Full-screen overlay per miner:
- Primary Pool: Stratum Host, Port, User, Password
- Primary Advanced: Suggested Difficulty, Extranonce Subscribe, Decode Coinbase Tx, Connection Security
- Fallback Pool: same fields
- Fallback Advanced: same fields
- Save and Restart buttons

### Miner Names
- Name each miner — shows instead of IP everywhere in the app
- Names pushed to server so Safari loads them automatically on first open

### Auto-Restart
- Per-miner toggle — saves between sessions, controllable from Safari
- Fires after **5 minutes with no shares**
- Max 3 restarts per hour — shows ⚠ warning when limit reached

### Live Log
- Real-time stream of miner log output
- Show/hide via Stats dropdown — pauses writes when hidden to prevent freeze on re-show

### Other
- Block Found full-screen alert with audio beep
- Total Hashrate chip in header (combined all miners)
- Unlimited miners, custom colors, nameable, add/remove with ✕
- 💛 Donate button for BTC/BCH/ETH/LTC/BNB
- ⏻ Close App shuts down server cleanly

---

## iPhone Safari Companion App

Opening the server address in iPhone Safari automatically loads the mobile app.

### ⛏ Miners Tab
- Card per miner with live stats pushed from Windows every 2 seconds:
  All-Time Best, Session Best, Status/Uptime, Shares/Rej, Avg/share, Target, Last, Frequency, Voltage, Fan Speed
- Hashrate and error rate displayed in the card header
- 🌡 Temps-only toggle per miner — tap to collapse everything except temperature bars
- **A** button per miner — toggles auto-restart on/off, syncs to Windows
- Temperature bars with color coding, collapsible per miner
- Color picker per miner (tap the colored circle)
- Remove miner with ✕, rename by tapping the miner name
- Total bar — watts on the left, total hashrate on the right
- Difficulty chart (last 60 shares) and Hashrate/Temp chart per miner
- Block finding odds card at the bottom — per hour / day / month / year based on your total hashrate vs the Bitcoin network
- In-app notifications for miner restarts, auto-restart warnings, block found

### ➕ Add Tab
- Add miners by IP and name
- Lists current miners with rename and remove options

### 📋 Session Tab
- Top 10/25/50/100 best shares this session
- Pulled live from Windows — exact match

### ⭐ All-Time Tab
- Top 10/25/50/100 all-time best per miner
- Same data as Windows hall of fame

### ⛁ Pool Tab
- Primary + Fallback stratum settings with advanced options
- Save and Restart per miner
- Settings freeze until Save is tapped to prevent accidental overwrites

### ⚙ Settings Tab
- Frequency, Voltage, Fan control per miner
- Save and Restart per miner
- Settings freeze until Save is tapped to prevent accidental overwrites

### General
- Auto-refreshes every 5 seconds
- Pauses when any input is focused
- Manual Refresh button in header
- Miners and names sync from Windows on first load

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
- Fetches the AxeOS Scoreboard and merges entries into your all-time list
- Stores shared state in memory: miner list, all-time data, live session data, notifications
- All traffic stays on your local network — nothing leaves your home

---

## License

MIT — do whatever you want with it.
