# Bitaxe Difficulty Tracker

A real-time share difficulty monitor and full dashboard for home Bitcoin miners running AxeOS firmware — Bitaxe, NerdQaxe++, NerdOCTAXE Gamma, Titan, and compatible devices.

No cloud. No accounts. No installs beyond the files in this zip. Runs entirely on your local network. Full companion mobile app for iPhone/Android via Safari or Chrome over WiFi or Tailscale.

---

## What's New (Recent Updates)

**Charts**
- **Per-chart 1m / 10m / 1h hashrate averages** shown in the header of each hashrate chart. Calculated by the app itself, so they work for miners that don't report firmware averages (e.g. Nexus-class) as well as AxeOS boards.
- **Working per-panel Y-axis zoom slider** — tighten the axis around the line so a big, rock-steady miner's variation fills the chart instead of looking flat; persists per panel.
- Hashrate-only controls (averages, HR, View, Y) appear on the Hashrate/Temp chart only, not on the Difficulty chart.

**Miner management & data integrity**
- **Remove a miner without losing its history.** The active-miner list is owned solely by your explicit miner list — removing a miner keeps its history, and re-adding the same IP later reconnects it. (Fixes "ghost miners" that used to reappear after removal.)
- **🧹 Purge Miner** — deliberately wipe a miner from every local and server store when you want it gone for good (global button on Windows, per-miner on mobile).
- **Per-miner all-time clear** — 🗑 on a miner's card clears its all-time Best Diffs or HR Scores, on Windows and mobile (durable; syncs to server and the other platform).

**Fan & temperature control**
- **VR fan control** for boards with a second (VR) fan — mode (Linked / Manual / Auto-PID), manual speed, and PID target temperature, set independently of the ASIC fan.
- **Correct target-temp & min-fan reading across firmwares** — boards reporting target temp via `pidTargetTemp` / per-fan PID (e.g. Nexus-class) no longer snap back to a default; the Min-Fan field only shows for boards that support it.

**Dynamic Governor**
- Auto-adjusts frequency/voltage/fan to hold miners inside temperature, VR-temp, and **current (amps)** bands, with dwell/settle timers, per-profile 24hr scheduling, and restart-after-adjust.

**Reliability fixes**
- **Crash reports fire once per outage** — a miner that stays down no longer spawns a new report every few minutes; it re-arms only after the miner recovers.
- **Notification deck** — toast notifications stack into a tidy, tappable deck.

> Launch-on-startup is available via the included `startup-helper.ps1` if you want the app to start with Windows; the in-app toggle is not shown in this build.

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
- Difficulty values are parsed with their unit suffix — `K`/`M`/`G`/`T` in the log (e.g. `diff 2.0M of 4.0M`) are correctly read as 2,000,000 / 4,000,000 rather than 2.0 / 4.0
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
- Resizable — font scales with width, saves between sessions (now starts wider by default so it's clear the panel is draggable)
- All-Time Best, Session Best, Status/Uptime
- Shares, Rejected (with %), Avg/share, HR, Error Rate, Last diff, Pool Target
- Efficiency (W/TH) displayed below Last diff
- **Power (W), Amps (A), Voltage (mV), Frequency (MHz)** — each individually toggleable
- **Multi-sensor temperatures** — shows every ASIC and VR temp the board reports. One sensor shows a plain label (`ASIC`, `VR`); multiple are numbered (`ASIC 1`, `ASIC 2`, `VR 1`…), with color coding:
  - ASIC: green <65°C, orange 65–69°C, red ≥70°C
  - VR: green ≤70°C, orange 71–80°C, red >80°C
- **Per-ASIC HR/Err** — per-chip hashrate and error count pulled from the miner's hashrate monitor, shown compactly (alternating left/right). Surfaces per-chip data that AxeOS doesn't break out — spot a weak or erroring chip on dual/quad-ASIC boards
- Difficulty values display with `K`/`M`/`G`/`T` units (e.g. a 4,100 target shows `4.1K`, a 2-million share shows `2.0M`)

### 📊 Stats Visibility Dropdown
Show or hide individual elements per miner card — including the per-stat toggles for Power, Amps, Voltage, Frequency, and Per-ASIC HR/Err — plus **🪩 Disco Mode** which hides miner cards and expands the live log to full height for a colorful full-log view.

### 📊 Difficulty Scores (Fullscreen)
- Session Best and All-Time Best side by side
- Collapsible per miner — state preserved when changing Top N
- Live updates every 2 seconds while open
- Per-miner trash icon to clear session diffs individually
- Selectable Top 10 / 25 / 50 / 100 / 250 / 500

### ⚡ HR High Scores (Fullscreen)
- Session and all-time hashrate peak records with error rate
- Collapsible per miner with live updates
- Per-miner trash icon to clear session HR scores individually
- Shows hashrate in GH/s or TH/s with timestamp and error rate (color-coded)
- Selectable Top 10 / 25 / 50 / 100

### ⭐ All-Time Hall of Fame
- Stores up to 500 best shares per miner — persists forever
- Integrates with AxeOS Scoreboard — imports entries automatically on connect and every 30 seconds
- Synced to server so iPhone reads the same list

### 📋 Crash/Restart Reports
- Automatically saves a session snapshot whenever a miner's hashrate drops to zero
- Captures pre-crash hashrate and temps (60-second lookback for accurate data)
- Detects: crashes, power faults, overheat, pool switches, manual restarts, auto-restarts
- Collapsible cards — compact by default, expand to see full stats
- Reports synced to server so iPhone can read them
- Delete individual reports from Windows or mobile — deletions sync bidirectionally

### 📜 Scripts Engine
- Create automation scripts that fire every 10 seconds based on miner conditions
- Conditions: hashrate, temperature, uptime, efficiency, frequency, time of day, **autoRestarts** (restarts in last hour), and more
- Actions: set frequency, voltage, fan speed, restart
- Scripts grouped by miner with drag-and-drop reordering
- Bidirectional sync with mobile — changes on either side propagate within seconds

### ⚙ Dynamic Governor
Automatic per-miner thermal tuning — holds a temperature band by nudging frequency and/or voltage in small steps.
- **Multiple named profiles per miner**, each active in its own non-overlapping time window — or flip the **24hr** toggle to run a profile around the clock (no time window needed)
- **Per-sensor temperature bands** — set an independent max/min for every ASIC and VR the board reports. Leave any sensor blank to ignore it (e.g. on a board reporting two ASIC temps, leave ASIC 1 blank and govern only on ASIC 2). Any single sensor out of its band triggers an adjustment, independent of the others; a too-hot reading always wins for safety
- **MHz and/or mV steps** with hard floor/ceiling — it rides right up to your ceiling/floor and never overshoots
- **Fan gates** — only steps down when the fan is at/above your set %, only steps up when it's at/below your set %
- **Uptime gate** (wait after a (re)start), **dwell** (temps must stay out of band this long before acting), and **settle** (pause after each change so it can take effect) timing
- **Both-directions** toggle (tune up and down, or down-only/protective) and optional **restart-after-adjust** per profile
- Master on/off, collapsible profiles, per-field help arrows, pill-slider toggles throughout
- Bidirectional sync with mobile — edit from either side
- Toast notification on every adjustment showing direction and the new value

### ⏱ Last Hour Report
- Rolling 60-minute per-miner summary, computed on open
- Per miner: ASIC hi/lo, VR hi/lo, average hashrate, best diff, amps hi/lo, average efficiency, voltage, frequency, fan hi/lo, average error rate, shares/rejects, average share time
- Collapsible report cards with state saved
- Synced to mobile

### Clear Sessions
- **✕ Clear Data** dropdown — clears chart and session data per miner or all at once
- **🗑 Clear Sessions** button — clears session best lists for all miners

### ⚙ Settings Panel
Full-screen overlay per miner — frequency, voltage, fan control with save and restart.

### ⛁ Pool Settings Panel
Full-screen overlay per miner — primary and fallback stratum with advanced options.

### Auto-Restart
- Per-miner toggle — saves between sessions, controllable from mobile
- Fires after **5 minutes with no shares AND hashrate near zero**
- Max 3 restarts per hour — shows ⚠ warning when limit reached
- Uses `autoRestarts` script condition to trigger frequency/voltage reduction after repeated crashes

### Other
- Block Found full-screen alert — fires immediately via API polling (not on dismiss)
- NerdQaxe++ and NerdOCTAXE Gamma compatibility
- Total Hashrate chip in header (combined all miners)
- Unlimited miners, custom colors, nameable, add/remove with ✕
- 💛 Donate button for BTC/BCH/ETH/LTC/BNB
- ⏻ Close App shuts down server cleanly
- Opens in dedicated app window (no browser tabs, no throttling)
- Launcher kills any existing server on port 19248 before starting

---

## iPhone / Android Companion App

Opening the server address in iPhone Safari or Android Chrome automatically loads the mobile app.

### ⛏ Miners Tab
- Card per miner with live stats pushed from Windows every 2 seconds
- Hashrate and error rate displayed in the card header
- 🌡 Temps-only toggle per miner
- Auto-restart toggle per miner, syncs to Windows
- Temperature bars with color coding, collapsible per miner
- Color picker per miner, rename by tapping the miner name
- Total bar — watts on the left, total hashrate on the right
- Difficulty and Hashrate/Temp charts per miner
- Per-miner stat rows including Power (W), Amps (A), Voltage (mV), Frequency (MHz), multi-sensor ASIC/VR temps, and Per-ASIC HR/Err
- Stall detection — stalled miners show red border and ⚠ badge
- Block finding odds card
- In-app notifications for restarts, warnings, block found

### 📋 Session Tab
- Top N best difficulty shares this session per miner, collapsible
- ⚡ HR Scores per miner, collapsible
- Per-list trash icon to clear diffs or HR scores for each miner individually
- Selectable Top 10 / 25 / 50 / 100 / 250 / 500

### ⭐ All-Time Tab
- Top N all-time best difficulties per miner, collapsible
- ⚡ All-time HR scores per miner, collapsible
- Same data as Windows hall of fame

### ⛁ Pool Tab
- Primary + Fallback stratum settings with advanced options
- Save and Restart per miner

### ⚙ App Settings Tab
- Frequency, Voltage, Fan control per miner
- **Battery Saver** — choose refresh rate: 2s / 5s / 10s / 20s
- **⚙ Dynamic Governor** — full editor at the top: create/edit per-miner profiles, per-sensor ASIC/VR bands, 24hr toggle, all step and timing settings, master on/off (pill-slider toggles, mirrors the Windows panel). Edits sync to the lead node that runs the engine
- **📜 Scripts** — view, create, edit, reorder automation scripts
- **📋 Crash/Restart Reports** — collapsible per miner, delete support, bidirectional sync
- **⏱ Last Hour Report** — rolling 60-minute per-miner summary, collapsible
- Settings page refreshes when you return from any sub-page (governor, scripts, reports, last hour)
- Hash Rain visual effect with brightness controls

### General
- Auto-refreshes (default 5 seconds, configurable)
- Manual Refresh button in header
- Miners and names sync from Windows on first load

---

## Supported Devices

| Device | Notes |
|---|---|
| Bitaxe (all models) | Full support |
| Bitaxe Duo 650 | Dual BM1370 chips |
| NerdQaxe++ | Full support — uses lastResetReason field |
| NerdOCTAXE Gamma | Full support — same firmware base as NerdQaxe |
| Titan | AxeOS compatible |
| NerdMiner v2 | No API — shows ⚠ warning |

---

## How It Works

The `.bat` launches a PowerShell HTTP server on port 19248 that:
- Serves the dashboard and mobile app to browsers on your local network
- Redirects iPhone/iPad/Android to the mobile app automatically
- Proxies WebSocket connections and REST API calls to your miners
- Fetches the AxeOS Scoreboard and merges entries into your all-time list
- Stores shared state in memory: miner list, all-time data, live session data, HR scores, scripts, notifications, crash reports
- All traffic stays on your local network — nothing leaves your home

---

## License

MIT — do whatever you want with it.
