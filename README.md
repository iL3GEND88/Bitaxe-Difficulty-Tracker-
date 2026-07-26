# Bitaxe Difficulty Tracker

A real-time share difficulty monitor and full dashboard for home Bitcoin miners running AxeOS firmware — Bitaxe, NerdQaxe++, NerdOCTAXE Gamma, Titan, and compatible devices.

No cloud. No accounts. No installs beyond the files in this zip. Runs entirely on your local network. Full companion mobile app for iPhone/Android via Safari or Chrome over WiFi or Tailscale.

---

## What's New (Recent Updates)

**Fleet card**
- A single aggregate card above the miners showing the whole rig as one unit: combined hashrate, total power, fleet efficiency, total shares/rejects, fleet-wide all-time and session bests, and 10m / 1h averages.
- Collapsible (tap the header), colour-settable, and it shows the session best even while collapsed.
- Present on both Windows and mobile.

**Luck**
- **1h / 4h / 12h / 24h luck** on the fleet card *and* every miner card, on both platforms. Colour-coded green ≥100%, white 90-100%, amber 75-90%, red below. Toggle from **Stats ▾ → Luck (per miner)** or **Visible Stats → Luck**.
- **Windows are a cap, not a gate** — a miner up only 6 hours shows its 6-hour luck under all four labels rather than a blank dash.
- **Log-at-target miners scored correctly.** Boards that only log shares meeting the pool target (Nexus-class) read far too low, because the app divided a partial numerator by a full denominator. They're now auto-detected and scored by a **count-based** method — expected shares above target vs actual — directly comparable to boards that log everything.
- **Vardiff-exact.** Share rate scales with 1/target, so expected count now uses a time-weighted mean of *1/target*, not 1/(mean target). With a target swinging 10-15K that alone was worth ~35 percentage points.
- **Downtime excluded.** Expected work is measured over *active* hashing time, so one reboot no longer drags a 24h window down for a full day.
- **Live pool difficulty.** The relay learns the pool target from `mining.set_difficulty`, persists it across restarts, and estimates it from the smallest observed share when it hasn't seen one — no more hardcoded fallback.

**Analysis charts — Charts ▾**
- **Luck Curve** — survival curve of your accepted shares on log-log axes; ideal is a straight descending line (P(beat x) = 1/x), gold dot marks your best as "best 1 in N". (Replaced the earlier Poisson bar chart.)
- **Efficiency Curve** — J/TH vs MHz from your own settled runs, best point ringed. Shows your personal knee.
- **Volt/Temp Map** — (temp, voltage) scatter coloured by frequency with a trend line printing your **mV/°C**.
- **Cold-Drop Watch** — hashrate and ASIC temp on a dual axis, red-shaded where hashrate sags *while* temp falls. Catches the cold-timing failure that throws no error.
- A background **run-logger** records each stable freq/voltage point so the curve charts have real data; it seeds on first sight and refines, so they populate in minutes.
- Mobile gets all four as scrollable sections.

**Per-miner chart timeframe**
- Each miner's Hashrate/Temp chart has its own **▾** picker — 1h / 2h / 4h / 6h / 8h / 12h / 24h / 36h — independent of the master timeframe and the Y-zoom, and remembered per miner. 36h spans a full night-day-night cycle.

**Apple Watch / external access**
- **`/fleet` JSON endpoint** on the relay exposes fleet hashrate, shares, best diff and luck for external consumers — used to drive an **Apple Watch complication** via Complicator over Tailscale.

**Economics & odds**
- **Per-miner cost** — running cost in the power square, from your electricity rate.
- **Network difficulty & Block %** — odds of a block shown beside the best-diff squares, read from each miner's own reported `networkDifficulty` so it reflects the chain that miner is actually on.

**Scripts — full fan control**
- **`setAsicTargetTemp`** sets the ASIC fan PID target, writing `fans[0].pid.targetTemp` *and* legacy `temptarget` so one action covers Nexus-class and AxeOS.
- **`setVrTargetTemp`** and **`setVrFanSpeed`** drive the second (VR) fan independently; they skip with a toast on single-fan miners.
- `setFanSpeed` now sets `fans[0].mode` / `manualSpeed` rather than top-level fields only.
- Every fan write **echoes the miner's `fans[]` back verbatim** and edits one field — reconstructing it is what caused the "connector 1 stuck at 90%" lock.

**Fixes**
- **Fan PATCH rewritten on both settings pages** to verbatim-echo. Fan target-temp changes that appeared to do nothing now apply.
- **Fleet session-best clears on restart** — a restarting miner used to keep contributing its stale API best until its next poll, so the record-holder never dropped out.
- **Min Fan Speed always shown in auto mode**, even on boards that don't report it, plus a mobile `0 → 35` fallback bug that blocked low floors.
- **Share stream recovers from a power cycle** — a dead socket on a healthy miner is reconnected instead of skipped, using the existing 60s debounce so it can't hammer the miner.
- **Miner card spacing tightened** — line-height 1.95 → 1.25, reclaiming ~85px per card.
- **Card collapse UX** — tap the header to collapse (replacing the old thermostat control).

**Best-share pace**
- New **PACE** row on every miner card and the fleet card, both platforms: `exp 174M  r 52M–1.1G  b 1.20G`. Expected best share for the work done, the range that's unremarkable, and your actual best.
- `b` is coloured against expected — green above, red below, compared at full precision, so two values that display identically can still colour differently.
- Built on order statistics: `P(best ≤ x) = (1 − D/x)^N`. The band is **always ~22× wide** regardless of how many shares you accumulate — that's the nature of a maximum, and it's why the range matters more than the point estimate.
- Scoped to the **device** session (`axeOSShares`), not the app's, so a long-running miner is no longer measured against a short app expectation.
- Fleet pace sums each miner's work rather than averaging targets, which would be meaningless across miners on different pool difficulties.

**Ambient temperature inference**
- Fifth Charts ▾ view. Derives room temperature from `T = ambient + P × R_th(fan)`, where cooling falls off as roughly `fan^-0.6`.
- Handles both regimes: with the fan pinned, a warmer room shows as a warmer chip; with the fan modulating to hold a target, temperature barely moves and the rise appears as **extra fan duty** instead. A PID miner that looks thermally steady is still reported as a warming room.
- **Calibrate by clicking the panel** and entering your thermometer reading. One reading pins each miner's coefficient directly — no waiting for a curve to fit. Enter it before any estimate exists and it's applied as soon as telemetry arrives.
- History is its own persisted series (a point every 5 minutes, 30 days), so the curve survives restarts rather than starting blank each launch.

**Degradation tracking**
- Collapsible **Degradation** section per miner on both platforms.
- Samples every 6 hours per operating point and compares the earliest half of readings against the latest, always at **identical freq/volt with ambient subtracted** — so retuning can't look like decay, and a warm room can't look like a failing heatsink.
- Reports efficiency drift, hashrate drift, and thermal rise above ambient. Under 1% is noise.
- The 6-hour clock is wall-clock, not runtime, so the app doesn't need to run continuously — roughly one sample per session, six sessions across a week is enough.

**Underperformance restart watchdog**
- Per-miner, in Miner Settings on both platforms, collapsed by default. Restarts a miner whose session best falls far below what its work predicts.
- Window of 4 / 8 / 12 / 24 / 48 / 72 hours or 7 days, gated on **device uptime** — a restart zeroes session best, so without that gate the rule would loop.
- Three triggers: **percentage below expected**, **below the range** (under `r`), or **below a session best you type**.
- Tap **"What's a healthy threshold?"** for the false-trigger table. The figures are exact, not estimated: `P = 2^(−1/c)`, with total work cancelling out, so they hold for every miner. Being below expected is not a symptom — half of all healthy sessions are. 90% below is ~1 in 1,024.

**One data file**
- `session-data.json`, `scripts-data.json` and `reports-data.json` are now a single **`bitaxe-data.json`**, so moving to a new folder means copying one file. Existing files are migrated automatically on first launch.
- Now also holds **degradation, run-log, governors, all-time bests and ambient history** — all previously localStorage-only and lost if browser data was cleared.
- Written by concatenation and read by structural scan, so nothing is ever serialised or parsed on write; a 600 KB log costs no CPU to persist.
- Writes are **change-gated, not timed**: the desktop sends a signature covering only what can't be regenerated, and if nothing meaningful moved, the disk isn't touched. Roughly 1,800 writes an hour became near-zero.
- Run `auditStore()` in the console for a per-section report read back off disk — useful after copying the file to a new folder.

**Chart changes**
- **Windows toolbar consolidated** — Difficulty, Hashrate/Temp and Charts ▾ are one dropdown showing the active view. Two toolbar slots recovered.
- **Difficulty timeframe moved into each panel header** and is now an **absolute window**: pick 1h and you see exactly one hour, with older shares reachable by scrolling. Previously it fed a zoom slider, so "24h" actually displayed about 38 minutes. Range 10s → 1w, per panel, remembered.
- **Efficiency Curve redrawn** as a single trajectory through every point in frequency order — no orphaned dots. A frequency held at several voltages gets a bracket showing the spread.
- **Volt/Temp Map redrawn** with a scatter band around the trend and a path through the settings, so the mV/°C figure carries visible confidence.
- **Mobile renders one chart, not six.** A pill selector picks the view (including **None**); the others aren't drawn or even built — 18 canvases down to 3 on a three-miner fleet.

**Notifications**
- The coloured edge on each notification now matches the miner it concerns, fleet green for app-wide messages. Both platforms.

**Fixes**
- **Render loop hardened** — `requestAnimationFrame` sat after the drawing, so any exception ended the loop permanently and froze every chart until relaunch. It reschedules first now, with per-panel isolation.
- **Mobile freeze on chart switch** — a `<select>` opens a native picker on iOS, and the auto-refresh rebuilt the page out from under it. Replaced with inline pills; the same lesson as the `prompt()` rename freeze. The refresh also runs in `try/finally` so a throw can't leave it wedged.
- **Rename row on mobile** — the editor was inserted as a flex child of the row, pushing Save off screen. It takes its own line now. Three more `flex:1` headers holding miner names got the same `min-width:0` guard.
- **Min chart difficulty and min dot filters persist** — they reset to 0 on every launch.
- **Run-log sanity gate** — impossible readings (`temp:-1`, 2.4 J/TH) were being stored as operating points and flattening the Efficiency Curve's Y-axis. Existing bad rows are swept once on load.
- **Ordinal suffixes** — `61th` is now `61st`.
- `--orange` was used twice in the Windows file but never declared.

---

## Previously

**Charts**
- **Per-chart 1m / 10m / 1h hashrate averages** in each hashrate chart header. Calculated by the app, so they work for miners that don't report firmware averages (e.g. Nexus-class) as well as AxeOS boards.
- **Per-panel Y-axis zoom slider** — tighten the axis so a big, rock-steady miner's variation fills the chart instead of looking flat; persists per panel.
- Hashrate-only controls appear on the Hashrate/Temp chart only, not on the Difficulty chart.

**Miner management & data integrity**
- **Remove a miner without losing its history.** The active-miner list is owned solely by your explicit miner list; re-adding the same IP reconnects it. (Fixes "ghost miners".)
- **🧹 Purge Miner** — deliberately wipe a miner from every local and server store (global button on Windows, per-miner on mobile).
- **Per-miner all-time clear** — 🗑 on a card clears its all-time Best Diffs or HR Scores, on both platforms, syncing to server and across.

**Fan & temperature control**
- **VR fan control** for boards with a second fan — mode (Linked / Manual / Auto-PID), manual speed, and PID target, independent of the ASIC fan.
- **Correct target-temp & min-fan reading across firmwares** — boards reporting via `pidTargetTemp` / per-fan PID no longer snap back to a default.

**Dynamic Governor**
- Auto-adjusts frequency/voltage/fan to hold miners inside temperature, VR-temp and **current (amps)** bands, with dwell/settle timers, per-profile 24hr scheduling, and restart-after-adjust.

**Reliability**
- **Crash reports fire once per outage** — a miner that stays down no longer spawns a report every few minutes; it re-arms after recovery.
- **Notification deck** — toasts stack into a tidy, tappable deck.

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
- Time range picker in each panel header: 10s / 30s / 1m / 5m / 30m / 45m / 1h / 6h / 24h / 1w — an absolute visible window, per panel
- X-axis scroll and zoom — scrub back through history
- **Chart history persists across session resets** — restarting a miner doesn't clear the difficulty chart

### Hashrate / Temperature Chart
- Hashrate over time per miner with Instant / 1m / 10m / 1h average modes
- Temperature lines per ASIC and VR sensor, color-coded green/orange/red
- Efficiency line (W/TH) overlay
- Toggle between Difficulty and Hashrate/Temp charts
- **▼ View dropdown** per panel — toggle Hashrate, Temps, Efficiency layers
- **▼ HR dropdown** per panel — select hashrate averaging mode

### 🧮 Fleet Card
An aggregate card above the individual miners that treats the whole rig as one unit:
- Combined hashrate, total power draw, and fleet efficiency (W/TH)
- Total shares and rejects with percentage
- Fleet-wide **all-time best** and **session best** (with the holding miner's colour)
- 10m and 1h fleet averages, and average time per share
- **Luck** over 1h / 4h / 12h / 24h, rolled up as sum(actual) ÷ sum(expected) across miners — so a 14 TH/s miner counts more than a 2 TH/s one, rather than averaging percentages
- Estimated running cost per day
- Collapsible by tapping the header (still shows session best while collapsed), and its accent colour is settable
- Present on Windows and mobile

### 📈 Charts ▾ (analysis views)
Four extra chart modes behind the **Charts ▾** toolbar dropdown:
- **Luck Curve** — survival curve of your accepted shares on log-log axes. Ideal is a straight descending line (P(beat x) = 1/x); a gold dot marks your best share as "best 1 in N".
- **Efficiency Curve** — J/TH vs frequency from your own logged runs, best point ringed. Shows where more MHz stops paying.
- **Volt/Temp Map** — (ASIC temp, core voltage) scatter coloured by frequency, with a trend line printing your **mV/°C**.
- **Cold-Drop Watch** — hashrate and ASIC temp on a dual axis; stretches where hashrate sags *while* temp falls are shaded red. This is the cold-timing failure that produces no error message.

A background **run-logger** records each stable freq/voltage operating point (frequency, voltage, hashrate, watts, J/TH, temps) so the Efficiency and Volt/Temp charts have real data. Stored locally, capped at 400 points.

- **Ambient Temp** — inferred room temperature, calibrated from one thermometer reading. See What's New.

### ⏱ Per-miner chart timeframe
Each miner's Hashrate/Temp chart carries its own **▾** timeframe picker — 1h, 2h, 4h, 6h, 8h, 12h, 24h, 36h — set independently per miner and independent of the master chart timeframe and the Y-zoom. Choices persist. The 36h option spans a full night-day-night cycle, useful for comparing a scheduled night setting against the day.

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

### 🍀 Luck
Each miner card and the fleet card show luck over **1h / 4h / 12h / 24h**.

Luck = work you actually proved ÷ work expected from your hashrate, so 100% is fair, under is unlucky, over is lucky. Colour-coded green / white / amber / red.

Three things make it accurate that most tools get wrong:
- Miners that only log shares at or above the pool target are detected and scored by counting shares above a known threshold, rather than summing targets they never reported.
- Under vardiff the expected count uses a time-weighted mean of 1/target, not 1/(mean target).
- Downtime is excluded — expected work is measured over hashing time only, so a reboot doesn't drag the number down for the rest of the window.

Short windows are noisy by nature (it's a Poisson process); the 24h figure is the trustworthy one. Toggle visibility from **Stats ▾ → Luck (per miner)**.

### ⚡ Cost & block odds
- **Per-miner running cost** shown in the power square, calculated from the electricity rate you set.
- **Network difficulty and Block %** beside the best-diff squares — the odds of that miner finding a block. Read from each miner's own reported `networkDifficulty`, so it reflects the chain that miner is actually pointed at rather than a global assumption.

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
- Actions: `restart`, `setFrequency`, `setCoreVoltage`, `setFanSpeed`, `setAutoFan`,
  **`setAsicTargetTemp`**, **`setVrTargetTemp`**, **`setVrFanSpeed`**,
  `setOverclock`, `setPrimaryPool`, `switchFallbackPool`, `setWorkerName`, `setPassword`, `notification`
- Fan actions are multi-fan aware: they echo the miner's `fans[]` back verbatim and edit only the field you asked for, so they work on two-fan (Nexus-class) boards without disturbing the other fan
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

### 🍀 Luck & analysis charts (mobile)
- Luck (1h / 4h / 12h / 24h) on every miner card and the fleet card, refreshed each poll. Hide it from **Visible Stats → Luck**.
- **Share Odds**, **Efficiency Curve**, **Volt / Temp Map** and **Cold-Drop Watch** appear as scrollable sections, one card per miner — the same four analysis views as the Windows **Charts ▾** dropdown.
- All of it is computed on the Windows engine and pushed, so mobile stays a light reader.

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

**`/fleet` endpoint**

The relay exposes `GET /fleet` returning fleet hashrate, share counts, best difficulty and luck as JSON. It's there so external displays can read the rig without loading the dashboard — it drives an **Apple Watch complication** via Complicator, reachable over Tailscale from outside the house.

**Share difficulty on boards that don't log it**

Some firmwares (Nexus-class / BM1373) never print an `asic_result ... diff X of Y` line — they emit only the raw stratum JSON. For those the relay reconstructs each share's difficulty itself from the job and the submitted nonce, and synthesises the log line the dashboard expects.

That needs two things from the stratum stream: the connection's `extranonce1`, and the pool's current difficulty. Both are captured live and **persisted to disk**, so a relay restart resumes from the real values instead of a default. If the relay attaches mid-session and hasn't seen a `mining.set_difficulty` yet, it estimates the target from the smallest share the miner has submitted — since it never submits below target, that converges from above within about 20 shares.

---

## License

MIT — do whatever you want with it.
