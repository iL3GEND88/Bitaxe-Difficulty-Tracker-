# Bitaxe Monitor - Proxy Server with auto-shutdown when Edge closes
param()
$PORT = 19248
$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$HTML_FILE  = Join-Path $SCRIPT_DIR "BitaxeMonitor.html"

Write-Host ""
Write-Host "  ===========================================" -ForegroundColor Cyan
Write-Host "   AxeOS Difficulty Tracker - Server" -ForegroundColor Cyan
Write-Host "   http://localhost:$PORT" -ForegroundColor Green
Write-Host "   Close this window OR close Edge to stop." -ForegroundColor Yellow
Write-Host "  ===========================================" -ForegroundColor Cyan
Write-Host ""

$listener = New-Object System.Net.HttpListener
# Get local IP
$localIP = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object {
    $_.IPAddress -notlike "127.*" -and
    $_.IPAddress -notlike "169.*" -and
    $_.PrefixOrigin -ne "WellKnown"
} | Select-Object -First 1).IPAddress

# Register URL so non-admin can bind to all interfaces
netsh http add urlacl url="http://+:$PORT/" user=Everyone 2>&1 | Out-Null

$listener.Prefixes.Add("http://+:$PORT/")
try {
    $listener.Start()
    Write-Host "  [OK] Listening on port $PORT (all interfaces)" -ForegroundColor Green
    if($localIP){
        Write-Host "  [iPhone] Open Safari: http://${localIP}:$PORT/" -ForegroundColor Yellow
    }
} catch {
    # Fall back to localhost only
    $listener = New-Object System.Net.HttpListener
    $listener.Prefixes.Add("http://localhost:$PORT/")
    $listener.Start()
    Write-Host "  [OK] Listening on localhost:$PORT" -ForegroundColor Green
    Write-Host "  [NOTE] Run as Administrator for iPhone access" -ForegroundColor Yellow
}

# Launch Edge and capture its process
Start-Sleep -Milliseconds 700
$edgeProc = $null
foreach ($ep in @("C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe","C:\Program Files\Microsoft\Edge\Application\msedge.exe")) {
    if (Test-Path $ep) {
        $edgeProc = Start-Process $ep "http://localhost:$PORT/" -PassThru
        Write-Host "  [OK] Launched Edge (PID $($edgeProc.Id))" -ForegroundColor Green
        break
    }
}
if (-not $edgeProc) { Write-Host "  Open Edge to: http://localhost:$PORT/" -ForegroundColor Yellow }

Write-Host "  [OK] Ready" -ForegroundColor Green
Write-Host ""

# Monitor Edge in background - shut down server when all Edge windows close
$listenerRef = $listener
$monitorScript = {
    param($edgePid, $port, $listenerObj)
    # Wait for the specific Edge window to close
    # Then check if ANY msedge process has our localhost tab
    # Simplest: just watch for our URL to become unreachable from Edge side
    # by monitoring if the Edge process tree is gone
    Start-Sleep -Seconds 3
    while ($true) {
        Start-Sleep -Seconds 2
        # Check if any msedge processes still running
        $edgeProcs = Get-Process -Name "msedge" -ErrorAction SilentlyContinue
        if (-not $edgeProcs) {
            Write-Host "  [Monitor] Edge closed - shutting down server..." -ForegroundColor Yellow
            try { $listenerObj.Stop() } catch {}
            exit 0
        }
    }
}

# Run monitor on background runspace
$rs = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace()
$rs.Open()
$ps2 = [System.Management.Automation.PowerShell]::Create()
$ps2.Runspace = $rs
[void]$ps2.AddScript($monitorScript)
[void]$ps2.AddArgument($edgeProc.Id)
[void]$ps2.AddArgument($PORT)
[void]$ps2.AddArgument($listener)
[void]$ps2.BeginInvoke()

$sseScript = {
    param($resp, $minerIP)
    $tok = [System.Threading.CancellationToken]::None
    $enc = [System.Text.Encoding]::UTF8
    try {
        $resp.ContentType = "text/event-stream"
        $resp.Headers.Add("Cache-Control","no-cache")
        $resp.Headers.Add("Access-Control-Allow-Origin","*")
        $resp.Headers.Add("X-Accel-Buffering","no")
        $stream = $resp.OutputStream

        $mws = New-Object System.Net.WebSockets.ClientWebSocket
        $mws.Options.SetRequestHeader("Origin","http://$minerIP")
        $mws.Options.KeepAliveInterval = [TimeSpan]::FromSeconds(20)
        $t = $mws.ConnectAsync([Uri]"ws://$minerIP/api/ws", $tok)
        if (-not $t.Wait(6000)) { throw "Timeout connecting to ws://$minerIP/api/ws" }
        if ($mws.State -ne 'Open') { throw "WebSocket did not open" }

        Write-Host "  [SSE] Connected to $minerIP" -ForegroundColor Green
        $hello = $enc.GetBytes("data: CONNECTED`n`n")
        $stream.Write($hello, 0, $hello.Length); $stream.Flush()

        $buf = New-Object byte[] 8192
        $seg = [System.ArraySegment[byte]]::new($buf)
        $sb  = New-Object System.Text.StringBuilder

        while ($mws.State -eq 'Open') {
            $r = $mws.ReceiveAsync($seg, $tok).GetAwaiter().GetResult()
            if ($r.MessageType -eq 'Close') { break }
            if ($r.Count -eq 0) { continue }
            $chunk = $enc.GetString($buf, 0, $r.Count)
            [void]$sb.Append($chunk)
            if ($r.EndOfMessage) {
                $line = $sb.ToString().Trim()
                [void]$sb.Clear()
                if ($line) {
                    $safe = $line -replace "`e\[[0-9;]*[mGKHFJA-Za-z]","" -replace "`n"," " -replace "`r","" -replace "[\x00-\x08\x0E-\x1F]",""
                    $msg  = $enc.GetBytes("data: $safe`n`n")
                    $stream.Write($msg, 0, $msg.Length); $stream.Flush()
                }
            }
        }
    } catch {
        Write-Host "  [SSE] $minerIP error: $_" -ForegroundColor Red
        try { $errMsg = $enc.GetBytes("data: ERROR: $_`n`n"); $resp.OutputStream.Write($errMsg,0,$errMsg.Length); $resp.OutputStream.Flush() } catch {}
    } finally {
        try { $mws.Dispose() } catch {}
        try { $resp.OutputStream.Close() } catch {}
        try { $resp.Close() } catch {}
        Write-Host "  [SSE] Session ended: $minerIP" -ForegroundColor Gray
    }
}

$running = $true
while ($running -and $listener.IsListening) {
    try {
        $ctx  = $listener.GetContext()
        $req  = $ctx.Request
        $resp = $ctx.Response
        $path = $req.Url.AbsolutePath
        $ip   = $req.QueryString["ip"]

        $resp.Headers.Add("Access-Control-Allow-Origin","*")
        $resp.Headers.Add("Access-Control-Allow-Methods","GET,OPTIONS")
        $resp.Headers.Add("Access-Control-Allow-Headers","*")

        if ($req.HttpMethod -eq "OPTIONS") { $resp.StatusCode=204; $resp.Close(); continue }

        # Shutdown endpoint (from Close App button)
        if ($path -eq "/shutdown") {
            Write-Host "  [Shutdown] Close App clicked - stopping..." -ForegroundColor Yellow
            $resp.StatusCode = 200
            $b = [System.Text.Encoding]::UTF8.GetBytes("ok")
            $resp.ContentLength64 = $b.Length
            $resp.OutputStream.Write($b, 0, $b.Length)
            $resp.Close()
            Start-Sleep -Milliseconds 300
            $listener.Stop()
            Write-Host "  [Server] Stopped." -ForegroundColor Red
            Start-Sleep -Milliseconds 200
            # Kill this PowerShell process so the window closes immediately
            Stop-Process -Id $PID -Force
        }

        if ($path -eq "/stream" -and $ip) {
            Write-Host "  [SSE] Browser subscribing to $ip" -ForegroundColor Cyan
            $respCopy=$resp; $ipCopy=$ip
            $rs2 = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace()
            $rs2.Open()
            $ps3 = [System.Management.Automation.PowerShell]::Create()
            $ps3.Runspace = $rs2
            [void]$ps3.AddScript($sseScript).AddArgument($respCopy).AddArgument($ipCopy)
            [void]$ps3.BeginInvoke()
            continue
        }

        if ($path -eq "/api" -and $ip) {
            try {
                $wc = New-Object System.Net.WebClient
                $wc.Headers.Add("Accept","application/json")
                $data = $wc.DownloadData("http://$ip/api/system/info")
                $resp.ContentType="application/json"; $resp.ContentLength64=$data.Length
                $resp.OutputStream.Write($data,0,$data.Length)
                Write-Host "  [API] $ip OK" -ForegroundColor Green
            } catch {
                $msg=[System.Text.Encoding]::UTF8.GetBytes("{`"error`":`"$_`"}")
                $resp.StatusCode=502; $resp.ContentType="application/json"
                $resp.ContentLength64=$msg.Length; $resp.OutputStream.Write($msg,0,$msg.Length)
                Write-Host "  [API] $ip FAILED: $_" -ForegroundColor Red
            }
            $resp.Close(); continue
        }

        # /setminers POST - desktop posts current miner IPs
        if ($path -eq "/setminers" -and $req.HttpMethod -eq "POST") {
            $reader = New-Object System.IO.StreamReader($req.InputStream)
            $body2 = $reader.ReadToEnd(); $reader.Close()
            try {
                $obj2 = $body2 | ConvertFrom-Json
                $script:minerIPs = @($obj2.ips)
                Write-Host "  [Mobile] Miner IPs updated: $($script:minerIPs -join ', ')" -ForegroundColor Cyan
            } catch {}
            $resp.StatusCode = 200; $resp.Headers.Add("Access-Control-Allow-Origin","*")
            $b = [System.Text.Encoding]::UTF8.GetBytes("ok")
            $resp.ContentLength64 = $b.Length; $resp.OutputStream.Write($b,0,$b.Length)
            $resp.Close(); continue
        }

        # /session GET - return live session data pushed by desktop
        if ($path -eq "/session" -and $req.HttpMethod -eq "GET") {
            $data = if ($script:sessionCache) { $script:sessionCache } else { '{}' }
            $resp.StatusCode = 200; $resp.ContentType = "application/json"
            $resp.Headers.Add("Access-Control-Allow-Origin","*")
            $b = [System.Text.Encoding]::UTF8.GetBytes($data)
            $resp.ContentLength64 = $b.Length; $resp.OutputStream.Write($b,0,$b.Length)
            $resp.Close(); continue
        }

        # /session POST - desktop pushes live session stats
        if ($path -eq "/session" -and $req.HttpMethod -eq "POST") {
            $reader = New-Object System.IO.StreamReader($req.InputStream)
            $script:sessionCache = $reader.ReadToEnd(); $reader.Close()
            $resp.StatusCode = 200; $resp.Headers.Add("Access-Control-Allow-Origin","*")
            $b = [System.Text.Encoding]::UTF8.GetBytes("ok")
            $resp.ContentLength64 = $b.Length; $resp.OutputStream.Write($b,0,$b.Length)
            $resp.Close(); continue
        }

        # Mobile redirect - iPhone/iPad/Android goes to /mobile
        if (($path -eq "/" -or $path -eq "/index.html") -and $req.Headers["User-Agent"] -match "iPhone|iPad|Android|Mobile") {
            $resp.StatusCode = 302
            $resp.Headers.Add("Location", "/mobile")
            $resp.Headers.Add("Access-Control-Allow-Origin", "*")
            $resp.ContentLength64 = 0
            $resp.Close(); continue
        }

        # /mobile - serve mobile UI
        if ($path -eq "/mobile") {
            $mobilePath = Join-Path $PSScriptRoot "mobile.html"
            if (Test-Path $mobilePath) {
                $mobileHtml = Get-Content -Path $mobilePath -Raw -Encoding UTF8
                $resp.StatusCode = 200; $resp.ContentType = "text/html; charset=utf-8"
                $resp.Headers.Add("Access-Control-Allow-Origin", "*")
                $b = [System.Text.Encoding]::UTF8.GetBytes($mobileHtml)
                $resp.ContentLength64 = $b.Length; $resp.OutputStream.Write($b, 0, $b.Length)
            } else {
                $resp.StatusCode = 404
                $b = [System.Text.Encoding]::UTF8.GetBytes("mobile.html not found")
                $resp.ContentLength64 = $b.Length; $resp.OutputStream.Write($b, 0, $b.Length)
            }
            $resp.Close(); continue
        }

        # /miners - return miner IPs known from all-time data
        if ($path -eq "/miners") {
            $ips = if ($script:minerIPs -and $script:minerIPs.Count -gt 0) { $script:minerIPs } else { @() }
            $ipJson = ($ips | ForEach-Object { '"' + $_ + '"' }) -join ','
            $payload = '{"ips":[' + $ipJson + ']}'
            $resp.StatusCode = 200; $resp.ContentType = "application/json"
            $resp.Headers.Add("Access-Control-Allow-Origin", "*")
            $b = [System.Text.Encoding]::UTF8.GetBytes($payload)
            $resp.ContentLength64 = $b.Length; $resp.OutputStream.Write($b, 0, $b.Length)
            $resp.Close(); continue
        }

        # /alltime GET - return cached all-time data
        if ($path -eq "/alltime" -and $req.HttpMethod -eq "GET") {
            $data = if ($script:allTimeCache) { $script:allTimeCache } else { '{}' }
            $resp.StatusCode = 200; $resp.ContentType = "application/json"
            $resp.Headers.Add("Access-Control-Allow-Origin", "*")
            $b = [System.Text.Encoding]::UTF8.GetBytes($data)
            $resp.ContentLength64 = $b.Length; $resp.OutputStream.Write($b, 0, $b.Length)
            $resp.Close(); continue
        }

        # /alltime POST - desktop posts localStorage data for mobile to read
        if ($path -eq "/alltime" -and $req.HttpMethod -eq "POST") {
            $reader = New-Object System.IO.StreamReader($req.InputStream)
            $script:allTimeCache = $reader.ReadToEnd(); $reader.Close()
            try {
                $obj = $script:allTimeCache | ConvertFrom-Json
                $script:minerIPs = @($obj.PSObject.Properties.Name)
            } catch {}
            $resp.StatusCode = 200; $resp.Headers.Add("Access-Control-Allow-Origin", "*")
            $b = [System.Text.Encoding]::UTF8.GetBytes("ok")
            $resp.ContentLength64 = $b.Length; $resp.OutputStream.Write($b, 0, $b.Length)
            $resp.Close(); continue
        }

        if ($path -eq "/" -or $path -eq "/index.html" -or $path -eq "/BitaxeMonitor.html") {
            if (Test-Path $HTML_FILE) {
                $b=[System.IO.File]::ReadAllBytes($HTML_FILE)
                $resp.ContentType="text/html; charset=utf-8"; $resp.ContentLength64=$b.Length
                $resp.OutputStream.Write($b,0,$b.Length)
            } else {
                $b=[System.Text.Encoding]::UTF8.GetBytes("BitaxeMonitor.html not found")
                $resp.StatusCode=404; $resp.ContentLength64=$b.Length; $resp.OutputStream.Write($b,0,$b.Length)
            }
            $resp.Close(); continue
        }

        # Simple test page to confirm iPhone can reach server
        if ($path -eq "/test") {
            $b = [System.Text.Encoding]::UTF8.GetBytes("<html><body style='background:#000;color:#0f0;font-family:monospace;font-size:24px;padding:40px'><h1>✅ Server is reachable!</h1><p>Your iPhone can talk to the server.</p><p>Now try: <a style='color:#38bdf8' href='/'>http://$($req.Url.Host)/</a></p></body></html>")
            $resp.ContentType = "text/html; charset=utf-8"
            $resp.ContentLength64 = $b.Length
            $resp.OutputStream.Write($b, 0, $b.Length)
            $resp.Close(); continue
        }

        if ($path -eq "/patch" -and $ip) {
            try {
                $bodyJson = $req.Headers["X-Body"]
                if (-not $bodyJson) {
                    $freq=$req.Headers["X-Freq"]; $voltage=$req.Headers["X-Voltage"]
                    $bodyJson='{"frequency":'+$freq+',"coreVoltage":'+$voltage+',"overclockEnabled":1}'
                }
                $wcp=New-Object System.Net.WebClient; $wcp.Headers.Add("Content-Type","application/json")
                [void]$wcp.UploadString("http://$ip/api/system","PATCH",$bodyJson)
                $resp.StatusCode=200; $resp.Headers.Add("Access-Control-Allow-Origin","*")
                $b=[System.Text.Encoding]::UTF8.GetBytes("ok"); $resp.ContentLength64=$b.Length; $resp.OutputStream.Write($b,0,$b.Length)
                Write-Host "  [PATCH] $ip OK" -ForegroundColor Cyan
            } catch {
                $b2=[System.Text.Encoding]::UTF8.GetBytes("error: $_"); $resp.StatusCode=502
                $resp.ContentLength64=$b2.Length; $resp.OutputStream.Write($b2,0,$b2.Length)
                Write-Host "  [PATCH] Failed: $_" -ForegroundColor Red
            }
            $resp.Close(); continue
        }

        # /restart?ip=... - proxy POST to AxeOS restart endpoint
        if ($path -eq "/restart" -and $ip) {
            try {
                $wc2 = New-Object System.Net.WebClient
                $wc2.Headers.Add("Content-Type","application/json")
                [void]$wc2.UploadString("http://$ip/api/system/restart","POST","")
                $resp.StatusCode = 200
                $resp.Headers.Add("Access-Control-Allow-Origin","*")
                $b = [System.Text.Encoding]::UTF8.GetBytes("ok")
                $resp.ContentLength64 = $b.Length
                $resp.OutputStream.Write($b, 0, $b.Length)
                Write-Host "  [RESTART] Sent restart to $ip" -ForegroundColor Yellow
            } catch {
                $b2 = [System.Text.Encoding]::UTF8.GetBytes("error: $_")
                $resp.StatusCode = 502
                $resp.ContentLength64 = $b2.Length
                $resp.OutputStream.Write($b2, 0, $b2.Length)
                Write-Host "  [RESTART] Failed for ${ip}: $_" -ForegroundColor Red
            }
            $resp.Close(); continue
        }

        $resp.StatusCode=404; $resp.Close()

    } catch [System.Net.HttpListenerException] { break }
    catch { Write-Host "  [ERR] $_" -ForegroundColor Red }
}

$listener.Stop()
Write-Host "  [Server] Stopped." -ForegroundColor Red
