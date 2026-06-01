# AxeOS Difficulty Tracker

A real-time share difficulty monitor and full dashboard for home Bitcoin miners running AxeOS firmware — Bitaxe, NerdQaxe++, Titan, and compatible devices.

No cloud. No accounts. No installs beyond the files in this zip. Runs entirely on your local network. Full companion mobile app for iPhone/Android via Safari or Chrome over WiFi or Tailscale.

---

## Quick Start

1. Download and unzip all files into the same folder
2. Double-click **`Launch Bitaxe Difficulty Tracker.bat`** (runs as administrator automatically)
3. The app opens automatically in its own window (Edge, Chrome, Brave, or Opera in app mode)
4. On iPhone/Android: open Safari or Chrome and go to the IP shown in yellow in the console window (e.g. `http://10.0.0.145:19248`)

> **The launcher self-elevates to administrator** — no need to right-click Run as administrator.

---

## Remote Access via Tailscale

To access your app from anywhere (not just home WiFi):

1. Install [Tailscale](https://tailscale.com) on your Windows PC and iPhone
2. Sign in with the same account on both devices
3. Note your PC's Tailscale IP (e.g. `100.x.x.x`) from the Tailscale app
4. On iPhone: open Safari and go to `http://100.x.x.x:19248`

---

## Requirements

- Windows 10 or 11 PC
- Edge, Chrome, Brave, or Opera (falls back to default browser if none found)
- PowerShell (pre-installed on Windows)
- Miners running AxeOS firmware on the same local network
- iPhone/Android for mobile companion app

---

## Files

| File | Purpose |
|---|---|
| `BitaxeDifficultyTracker.html` | Main Windows dashboard |
| `mobile.html` | iPhone/Android companion app |
| `server.ps1` | PowerShell HTTP proxy server |
| `Launch Bitaxe Difficulty Tracker.bat` | Launcher — self-elevating, auto-opens browser |
| `README.md` | This file |

---

## Windows App Features

### Live Difficulty Chart
- Every share attempt plotted in real time from the miner's log stream
- Pool target shown as a dashed line — detects variable difficulty pools automatically
- Green dots on accepted shares, colored lines per miner with area fill
- Hover tooltip: exact difficulty, accepted/rejected, pool target, timestamp
- Log or Linear Y-axis scale toggle, Y-axis scale slider
- Time range dropdown: 10s / 30s / 1m / 5m / 30m / 1h / 6h / 24h / 1w / All
- X-axis scroll and zoom — scrub back through history
- **Chart history persists across session resets** — restarting a miner doesn't clear the difficulty chart

### Hashrate / Temperature Chart
- Hashrate over time per miner with Instant / 1m / 10m / 1h average modes
- Temperature lines per ASIC and VR sensor, color-coded green/orange/red
- Efficiency line (W/TH) overlay
- Toggle between Difficulty and Hashrate/Temp charts
- **▼ View dropdown** per panel — toggle Hashrate, Temps, Efficiency layers
- **▼ HR dropdown** per panel — select hashrate averaging mode

### Chart Layouts
- **Combined** — all miners on one chart
- **Split** — each miner gets its own panel
- **Both** — combined + individual panels
- Resize panels by dragging the handle

### Stats Column (per miner)
- Resizable — font scales with width, saves between sessions
- All-Time Best, Session Best, Status/Uptime
- Shares, Rejected (with %), Avg/share, HR, Error Rate, Last diff, Pool Target
- **Efficiency (W/TH)** displayed below Last diff
- ASIC and VR temperatures with color coding:
  - ASIC: green <65°C, orange 65–69°C, red ≥70°C
  - VR: green ≤70°C, orange 71–80°C, red >80°C
- Top N best difficulties this session (10/25/50/100)

### 📊 Stats Visibility Dropdown
Show or hide individual elements per miner card:
Best Difficulty, Status/Uptime, Shares, Rejected, Hashrate, Error Rate, Avg/Share, Target, Last, Efficiency, Temperatures, Top Diffs List, Live Log

### 📋 Session Best (Fullscreen)
- Full-screen overlay of top session shares across all miners
- Selectable top 10/25/50/100

### ⭐ All-Time Hall of Fame
- Stores up to 500 best shares per miner — persists forever
- Integrates with AxeOS Scoreboard — imports entries automatically on connect and every 30 seconds
- Synced to server so iPhone reads the same list
- Selectable top 10/25/50/100 view

### 📋 Crash/Restart Reports
- Automatically saves a session snapshot whenever a miner's hashrate drops to zero
- Triggered by actual hashrate loss — catches crashes, power cycles, manual restarts, and auto-restarts
- Up to 10 reports per miner stored in localStorage
- Each report shows: session number, date/time, uptime/duration, hashrate, efficiency, best diff, shares accepted/found, rejected count, avg share time, temperatures, and top 10 difficulties
- Collapsible cards — compact by default, expand to see full stats
- Reports synced to server so iPhone can read them
- Delete individual reports from Windows or mobile — deletions sync bidirectionally

### 📜 Scripts Engine
- Create automation scripts that fire every 10 seconds based on miner conditions
- Conditions: hashrate, temperature, uptime, efficiency, shares, and more
- Actions: set frequency, voltage, fan speed, restart
- Scripts grouped by miner with drag-and-drop reordering
- Bidirectional sync with mobile — changes on either side propagate within seconds

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
- Save and Restart buttons

### Miner Names
- Name each miner — shows instead of IP everywhere in the app
- Names pushed to server so mobile loads them automatically on first open

### Auto-Restart
- Per-miner toggle — saves between sessions, controllable from mobile
- Fires after **5 minutes with no shares AND hashrate near zero**
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
- **Launcher kills any existing server on port 19248 before starting** — prevents "server stopped" after reboots
- **Opens in dedicated app window** (no browser tabs, no throttling) on Edge, Chrome, Brave, Opera

---

## iPhone / Android Companion App

Opening the server address in iPhone Safari or Android Chrome automatically loads the mobile app.

### ⛏ Miners Tab
- Card per miner with live stats pushed from Windows every 2 seconds:
  All-Time Best, Session Best, Status/Uptime, Shares/Rej, Avg/share, Target, Last, Efficiency, Frequency, Voltage, Fan Speed
- Hashrate and error rate displayed in the card header
- 🌡 Temps-only toggle per miner — tap to collapse everything except temperature bars
- **A** button per miner — toggles auto-restart on/off, syncs to Windows
- Temperature bars with color coding, collapsible per miner
- Color picker per miner (tap the colored circle)
- Remove miner with ✕, rename by tapping the miner name
- Total bar — watts on the left, total hashrate on the right (excludes stalled miners)
- Difficulty chart (last 60 shares) and Hashrate/Temp chart per miner
- **Stall detection** — stalled miners show red border and ⚠ Stalled badge
- Block finding odds card at the bottom
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

### ⚙ App Settings Tab
- Frequency, Voltage, Fan control per miner (collapsible per miner)
- **Battery Saver** — choose refresh rate: 2s / 5s / 10s / 20s
- **📜 Scripts** — view, create, edit, reorder automation scripts
- **📋 Crash/Restart Reports** — view session snapshots saved on miner restarts, with collapsible cards per miner, delete support, bidirectional sync with Windows
- Hash Rain visual effect with brightness controls

### General
- Auto-refreshes (default 5 seconds, configurable)
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
- Redirects iPhone/iPad/Android to the mobile app automatically
- Proxies WebSocket connections and REST API calls to your miners
- Fetches the AxeOS Scoreboard and merges entries into your all-time list
- Stores shared state in memory: miner list, all-time data, live session data, scripts, notifications, crash reports
- All traffic stays on your local network — nothing leaves your home

---

## License

MIT — do whatever you want with it.
