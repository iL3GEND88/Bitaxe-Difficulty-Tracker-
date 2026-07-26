# Bitaxe Monitor - Proxy Server
param()
$PORT = 19248
$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$HTML_FILE  = Join-Path $SCRIPT_DIR "BitaxeDifficultyTracker.html"

Write-Host ""
Write-Host "  ===========================================" -ForegroundColor Cyan
Write-Host "   AxeOS Difficulty Tracker - Server" -ForegroundColor Cyan
Write-Host "   http://localhost:$PORT" -ForegroundColor Green
Write-Host "   Close this window to stop the server." -ForegroundColor Yellow
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

# Browser launched by the .bat file
Write-Host "  [OK] Open your browser to: http://localhost:$PORT/" -ForegroundColor Green

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

# ── Nexus per-share difficulty library ───────────────────────────────────────
# Some firmwares (NexusOS / BM1373) never log "asic_result ... diff X of Y", so the
# chart has nothing to plot. They DO log the raw stratum exchange. This library
# reconstructs each share's difficulty from the stratum job + submit, using a byte
# order verified against real captured shares (all computed to >= pool difficulty),
# the device's own network difficulty, and the Bitcoin genesis block hash.
$nexusDiffLib = @'
function NX-Hex2Bytes([string]$h){
  if([string]::IsNullOrEmpty($h) -or ($h.Length % 2 -ne 0)){ return ,(New-Object byte[] 0) }
  $n=$h.Length/2; $b=New-Object byte[] $n
  for($i=0;$i -lt $n;$i++){ $b[$i]=[Convert]::ToByte($h.Substring($i*2,2),16) }
  return ,$b
}
function NX-Sha256([byte[]]$b){ $s=[System.Security.Cryptography.SHA256]::Create(); try{ return $s.ComputeHash($b) } finally { $s.Dispose() } }
function NX-Sha256d([byte[]]$b){ return (NX-Sha256 (NX-Sha256 $b)) }
function NX-Swap32([byte[]]$b){
  $o=New-Object byte[] $b.Length
  for($i=0;$i -lt $b.Length;$i+=4){ $o[$i]=$b[$i+3];$o[$i+1]=$b[$i+2];$o[$i+2]=$b[$i+1];$o[$i+3]=$b[$i] }
  return ,$o
}
function NX-U32LE($v){
  $u=[uint32]$v; $b=New-Object byte[] 4
  $b[0]=[byte]($u -band 0xFF); $b[1]=[byte](($u -shr 8) -band 0xFF)
  $b[2]=[byte](($u -shr 16) -band 0xFF); $b[3]=[byte](($u -shr 24) -band 0xFF)
  return ,$b
}
# Locked byte order: prevhash word-swapped; version-rolling applied; ver/ntime/nbits/nonce LE;
# merkle branches as-is; final double-SHA reversed; difficulty = DIFF1 / hash.
function NX-ShareDiff($en1,$job,$en2,$ntimeHex,$nonceHex,$vbitsHex,$mask){
  $cb = NX-Hex2Bytes ([string]$job.coinb1 + [string]$en1 + [string]$en2 + [string]$job.coinb2)
  $mr = NX-Sha256d $cb
  foreach($br in $job.merkle){ $mr = NX-Sha256d ([byte[]]($mr + (NX-Hex2Bytes ([string]$br)))) }
  $jv=[long][Convert]::ToUInt32([string]$job.version,16)
  $vb=[long][Convert]::ToUInt32([string]$vbitsHex,16)
  $nm=[long]4294967295 -bxor [long]$mask
  $hver=[uint32](($jv -band $nm) -bor ($vb -band [long]$mask))
  $ver = NX-U32LE $hver
  $ph  = NX-Swap32 (NX-Hex2Bytes ([string]$job.prevhash))
  $nt  = NX-U32LE ([Convert]::ToUInt32([string]$ntimeHex,16))
  $nb  = NX-U32LE ([Convert]::ToUInt32([string]$job.nbits,16))
  $nn  = NX-U32LE ([Convert]::ToUInt32([string]$nonceHex,16))
  $header = [byte[]]($ver + $ph + $mr + $nt + $nb + $nn)
  $h = NX-Sha256d $header
  [array]::Reverse($h)
  $hexBE = -join ($h | ForEach-Object { $_.ToString('x2') })
  $H = [System.Numerics.BigInteger]::Parse('0'+$hexBE,[System.Globalization.NumberStyles]::HexNumber)
  if($H -le 0){ return 0.0 }
  $DIFF1 = [System.Numerics.BigInteger]::Parse('00000000ffff0000000000000000000000000000000000000000000000000000',[System.Globalization.NumberStyles]::HexNumber)
  return [double](($DIFF1 * 1000000) / $H) / 1000000.0
}
function NX-LoadEnonce($store,$ip){
  try { if(Test-Path $store){ $o=Get-Content $store -Raw | ConvertFrom-Json; if($o.$ip){ return [string]$o.$ip } } } catch {}
  return $null
}
function NX-SaveEnonce($store,$ip,$en1){
  try {
    $m=@{}; if(Test-Path $store){ (Get-Content $store -Raw | ConvertFrom-Json).PSObject.Properties | ForEach-Object { $m[$_.Name]=$_.Value } }
    $m[$ip]=$en1; ($m | ConvertTo-Json -Compress) | Set-Content $store
  } catch {}
}
# Pool difficulty persistence. The pool only sends mining.set_difficulty when the
# value CHANGES, so a relay that attaches mid-session never sees one and would sit
# on a hardcoded default forever - making every synthesized share line read
# "of <default>" and skewing luck. Persist the last known value per IP so a relay
# restart resumes from the real difficulty instead of a guess.
function NX-LoadDiff($store,$ip){
  try { if(Test-Path $store){ $o=Get-Content $store -Raw | ConvertFrom-Json; if($o.$ip){ return [int]$o.$ip } } } catch {}
  return 0
}
function NX-SaveDiff($store,$ip,$d){
  try {
    $m=@{}; if(Test-Path $store){ (Get-Content $store -Raw | ConvertFrom-Json).PSObject.Properties | ForEach-Object { $m[$_.Name]=$_.Value } }
    $m[$ip]=$d; ($m | ConvertTo-Json -Compress) | Set-Content $store
  } catch {}
}
'@

# Startup self-test: a known captured share (job cfd1, extranonce 1530006e) must equal 36259.7.
& {
  . ([scriptblock]::Create($nexusDiffLib))
  $tj = @{
    prevhash='fe72308297be046a61f88df49f6d05aadb54c748000101b40000000000000000'
    coinb1='01000000010000000000000000000000000000000000000000000000000000000000000000ffffffff3503a2940e00040ee23e6a04c1c8e6010c'
    coinb2='0a636b706f6f6c112f736f6c6f2e636b706f6f6c2e6f72672ffffffffe035256511200000000160014f61ad5d9ffca353f06e1c9f2385d26a733ab41aa64b35f000000000016001451ed61d2f6aa260cc72cdf743e4e436a82c010270000000000000000266a24aa21a9ed62fbd4ad3fa26fb5e963580646202ea432d7276724615d187432ad366c81b199a1940e00'
    merkle=@('a011a0b5fcff49de052d20be0debbfe12867b146c0ae68b70b4c81f7ea71e953','4e86c8f5825a6eb34bfd86d9cc9cbceb5fc5181bde91bc80c2493565554aa9f4','fa24777ea979352bbe62b7607164bc6fe254bdf01f4f4a8f81c92722ad738e5a','3b397e363caa5495fc1905c8a199638c3b82e3c70dab4d128b3d3270c927a65e','8a8abd597908419024de9f79b88fd582bec523a915b61c5ad37e6c0300e60d6d','e19f724e57ad8dd256907db942ae8da7f8250f03a304ff0cad6ac50da87a5713','7d38664bd818d9f8ec62448140fb834bdf198cc26539dbd03dc8a5b35685cdef','538f8cadbbfd7e92fec92876ec3ce62e10e989b9eb73ebaecdca3efb6d01c176','3449942a915b51def656b661147677c06f32a3bd52ac860d26e5996511a2fdda','647e55757718b64f4544351c4dced9901ed7a57b0ba2d25c3fc00cc2003cd1fb','70beb6fdf6dddc5d9a12e8698d91effd50800ada97b3ece3025791f88625462e')
    version='20000000'; nbits='170240c3'
  }
  try {
    $td = NX-ShareDiff '1530006e' $tj '0000000000000006' '6a3ee20e' 'f686016e' '05310000' 0x1fffe000
    if([Math]::Abs($td - 36259.7) -lt 2.0){ Write-Host "  [Nexus] share-diff self-test PASSED (computed $([string]::Format('{0:0.0}',$td)))" -ForegroundColor Green }
    else { Write-Host "  [Nexus] share-diff self-test FAILED (got $td, expected 36259.7) - Nexus plotting may be wrong" -ForegroundColor Red }
  } catch { Write-Host "  [Nexus] share-diff self-test ERROR: $_" -ForegroundColor Red }
}

$sseScript = {
    param($resp, $minerIP, $nexusLib)
    $tok = [System.Threading.CancellationToken]::None
    $enc = [System.Text.Encoding]::UTF8
    # Nexus per-share difficulty: load the proven library + per-connection stratum state.
    # State is local to this runspace, which is correct: extranonce1 is per pool connection.
    try { . ([scriptblock]::Create($nexusLib)) } catch {}
    $nxMask=0x1fffe000; $nxSub=0
    $nxJobs=@{}; $nxOrder=New-Object System.Collections.ArrayList
    $nxStore = Join-Path $env:TEMP 'bitaxe_nexus_enonce.json'
    $nxDiffStore = Join-Path $env:TEMP 'bitaxe_nexus_pooldiff.json'
    $nxEn1 = NX-LoadEnonce $nxStore $minerIP
    if ($nxEn1) { Write-Host "  [Nexus] using saved extranonce1 $nxEn1 for $minerIP" -ForegroundColor DarkCyan }
    # Resume from the last known pool difficulty; 10000 only as a first-run seed.
    $nxPoolDiff = NX-LoadDiff $nxDiffStore $minerIP
    $nxDiffKnown = ($nxPoolDiff -gt 0)
    if (-not $nxDiffKnown) { $nxPoolDiff = 10000 }
    else { Write-Host "  [Nexus] using saved pool difficulty $nxPoolDiff for $minerIP" -ForegroundColor DarkCyan }
    # Self-correcting estimate: the miner only submits shares at/above the pool
    # target, so the MINIMUM observed share difficulty converges on the true target
    # from above. Used only until a real set_difficulty is seen this session.
    $nxMinSeen = [double]0; $nxMinCount = 0
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

                    # ── Nexus per-share difficulty ──────────────────────────
                    # NexusOS never logs "diff X of Y", so compute it from the stratum
                    # exchange and inject a line the chart parser already understands.
                    if ($line -match 'mining\.|extranonce_str|version mask') {
                        try {
                            if ($line -match 'extranonce_str:\s*([0-9a-fA-F]+)') {
                                if ($nxEn1 -ne $matches[1]) { $nxEn1=$matches[1]; NX-SaveEnonce $nxStore $minerIP $nxEn1; Write-Host "  [Nexus] extranonce1 captured $nxEn1 for $minerIP (saved)" -ForegroundColor Green }
                            }
                            elseif ($line -match 'version mask:\s*([0-9a-fA-F]+)') { $nxMask=[Convert]::ToInt64($matches[1],16) }
                            elseif ($line -match '"method":\s*"mining\.(notify|submit|set_difficulty)"' -or $line -match '"result":\[\[\["mining\.notify"') {
                                $js=$line.Substring($line.IndexOf('{')); $j=$js | ConvertFrom-Json
                                if ($j.result -and $j.result.Count -ge 2) {
                                    if ($nxEn1 -ne [string]$j.result[1]) { $nxEn1=[string]$j.result[1]; NX-SaveEnonce $nxStore $minerIP $nxEn1; Write-Host "  [Nexus] extranonce1 captured $nxEn1 for $minerIP (saved)" -ForegroundColor Green }
                                }
                                elseif ($j.method -eq 'mining.set_difficulty') {
                                    $nd=[int]$j.params[0]
                                    if ($nd -gt 0) {
                                        if ($nd -ne $nxPoolDiff) { Write-Host "  [Nexus] pool difficulty $nxPoolDiff -> $nd for $minerIP (saved)" -ForegroundColor Green }
                                        $nxPoolDiff=$nd; NX-SaveDiff $nxDiffStore $minerIP $nd
                                    }
                                    $nxDiffKnown=$true; $nxMinSeen=[double]0; $nxMinCount=0
                                }
                                elseif ($j.method -eq 'mining.notify') {
                                    $job=@{ prevhash=[string]$j.params[1]; coinb1=[string]$j.params[2]; coinb2=[string]$j.params[3]; merkle=$j.params[4]; version=[string]$j.params[5]; nbits=[string]$j.params[6] }
                                    $jid=[string]$j.params[0]; $nxJobs[$jid]=$job; [void]$nxOrder.Add($jid)
                                    while($nxOrder.Count -gt 12){ $old=[string]$nxOrder[0]; $nxOrder.RemoveAt(0); $nxJobs.Remove($old) }
                                }
                                elseif ($j.method -eq 'mining.submit') {
                                    $nxSub++
                                    $jid=[string]$j.params[1]; $job=$nxJobs[$jid]
                                    if ($job -and $nxEn1) {
                                        $d = NX-ShareDiff $nxEn1 $job ([string]$j.params[2]) ([string]$j.params[3]) ([string]$j.params[4]) ([string]$j.params[5]) $nxMask
                                        if ($d -gt 0) {
                                            # No set_difficulty seen yet this session: infer the target from the
                                            # smallest share the miner has submitted (it never submits below target).
                                            if (-not $nxDiffKnown) {
                                                if ($nxMinSeen -le 0 -or $d -lt $nxMinSeen) { $nxMinSeen=$d }
                                                $nxMinCount++
                                                if ($nxMinCount -ge 20 -and $nxMinSeen -gt 0) {
                                                    $est=[int][math]::Round($nxMinSeen)
                                                    if ($est -gt 0 -and ([math]::Abs($est-$nxPoolDiff)/[double]$nxPoolDiff) -gt 0.15) {
                                                        Write-Host "  [Nexus] no set_difficulty yet; estimated pool difficulty $est from $nxMinCount shares (was $nxPoolDiff)" -ForegroundColor Yellow
                                                        $nxPoolDiff=$est; NX-SaveDiff $nxDiffStore $minerIP $est
                                                    }
                                                    $nxMinCount=0; $nxMinSeen=[double]0
                                                }
                                            }
                                            $ds=[string]::Format([System.Globalization.CultureInfo]::InvariantCulture,'{0:0.0}',$d)
                                            $dl=$enc.GetBytes("data: Nexus share  diff $ds of $nxPoolDiff`n`n")
                                            $stream.Write($dl,0,$dl.Length); $stream.Flush()
                                            Write-Host "  [Nexus] share diff $ds of $nxPoolDiff (plotted)" -ForegroundColor DarkGreen
                                        }
                                    } elseif ($nxSub -le 3 -or ($nxSub % 25 -eq 0)) {
                                        Write-Host "  [Nexus] submit seen, cannot compute yet (en1=$([bool]$nxEn1) jobCached=$([bool]$job)) - if en1 is False, reboot the Nexus once while the tracker is running" -ForegroundColor DarkYellow
                                    }
                                }
                            }
                        } catch { if ($nxSub -le 5) { Write-Host "  [Nexus] parse note: $_" -ForegroundColor DarkYellow } }
                    }
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

# -- Unified data store -------------------------------------------------------
# One file instead of three, so moving to a new folder only has to carry
# bitaxe-data.json. Every section is held as a RAW JSON string and the file is
# built by concatenation, so nothing is ever serialized or parsed on write --
# a 600KB degradation log costs essentially no CPU to persist. Reads pull each
# section back out by brace matching, again without parsing.
$script:dataFile     = Join-Path $PSScriptRoot 'bitaxe-data.json'
$script:storeDirty   = $false
$script:lastFlush    = 0
$script:STORE_MIN_MS = 5000

function Now-Ms { return [int64]([datetime]::UtcNow - [datetime]'1970-01-01').TotalMilliseconds }

# Pull one section's raw JSON out of the combined file without ConvertFrom-Json.
# Walks TOP-LEVEL pairs only. A plain IndexOf is not safe here: section names
# also occur as nested keys -- per-miner session objects each carry their own
# "runlog", so a naive search finds one of those and the fragment then gets
# written back over the real section on the next save.
function Skip-JsonValue($raw, $i) {
    while ($i -lt $raw.Length -and [char]::IsWhiteSpace($raw[$i])) { $i++ }
    if ($i -ge $raw.Length) { return $i }
    $c = $raw[$i]
    if ($c -eq '"') {
        $i++
        while ($i -lt $raw.Length) {
            if ($raw[$i] -eq '\') { $i += 2; continue }
            if ($raw[$i] -eq '"') { return $i + 1 }
            $i++
        }
        return $i
    }
    if ($c -eq '{' -or $c -eq '[') {
        $open = $c
        $close = if ($open -eq '{') { '}' } else { ']' }
        $depth = 0; $inStr = $false; $esc = $false
        while ($i -lt $raw.Length) {
            $ch = $raw[$i]
            if ($inStr) {
                if ($esc) { $esc = $false }
                elseif ($ch -eq '\') { $esc = $true }
                elseif ($ch -eq '"') { $inStr = $false }
            } else {
                if ($ch -eq '"') { $inStr = $true }
                elseif ($ch -eq $open) { $depth++ }
                elseif ($ch -eq $close) { $depth--; if ($depth -eq 0) { return $i + 1 } }
            }
            $i++
        }
        return $i
    }
    while ($i -lt $raw.Length -and $raw[$i] -ne ',' -and $raw[$i] -ne '}') { $i++ }
    return $i
}

# Count TOP-LEVEL entries only. The previous version counted every brace or
# quoted key anywhere inside the section, so 10 scripts reported as 54 and a
# 3-miner session as 15806.
function Count-JsonTop($val) {
    if (-not $val) { return 0 }
    $val = $val.Trim()
    if ($val.Length -lt 2) { return 0 }
    $isArr = ($val[0] -eq '[')
    if ((-not $isArr) -and ($val[0] -ne '{')) { return 0 }
    $i = 1
    $n = 0
    while ($i -lt $val.Length) {
        while ($i -lt $val.Length -and ($val[$i] -eq ',' -or [char]::IsWhiteSpace($val[$i]))) { $i++ }
        if ($i -ge $val.Length) { break }
        if ($val[$i] -eq ']' -or $val[$i] -eq '}') { break }
        if (-not $isArr) {
            $i = Skip-JsonValue $val $i
            while ($i -lt $val.Length -and [char]::IsWhiteSpace($val[$i])) { $i++ }
            if ($i -lt $val.Length -and $val[$i] -eq ':') { $i++ }
        }
        $i = Skip-JsonValue $val $i
        $n++
    }
    return $n
}

function Get-StoreSection($raw, $name) {
    if (-not $raw) { return $null }
    $i = 0
    while ($i -lt $raw.Length -and $raw[$i] -ne '{') { $i++ }
    $i++
    while ($i -lt $raw.Length) {
        while ($i -lt $raw.Length -and ($raw[$i] -eq ',' -or [char]::IsWhiteSpace($raw[$i]))) { $i++ }
        if ($i -ge $raw.Length -or $raw[$i] -eq '}') { return $null }
        if ($raw[$i] -ne '"') { return $null }
        $ks = $i + 1; $i++
        while ($i -lt $raw.Length) {
            if ($raw[$i] -eq '\') { $i += 2; continue }
            if ($raw[$i] -eq '"') { break }
            $i++
        }
        $key = $raw.Substring($ks, $i - $ks)
        $i++
        while ($i -lt $raw.Length -and [char]::IsWhiteSpace($raw[$i])) { $i++ }
        if ($i -ge $raw.Length -or $raw[$i] -ne ':') { return $null }
        $i++
        while ($i -lt $raw.Length -and [char]::IsWhiteSpace($raw[$i])) { $i++ }
        $vs = $i
        $ve = Skip-JsonValue $raw $i
        if ($key -eq $name) {
            $val = $raw.Substring($vs, $ve - $vs).Trim()
            if ($val -eq 'null') { return $null }
            return $val
        }
        $i = $ve
    }
    return $null
}

function Save-Store {
    param([switch]$Force)
    $now = Now-Ms
    if (-not $Force) {
        if (-not $script:storeDirty) { return }
        if (($now - $script:lastFlush) -lt $script:STORE_MIN_MS) { return }
    }
    try {
        $sb = New-Object System.Text.StringBuilder
        [void]$sb.Append('{"v":1')
        $sections = @(
            @('session',     $script:sessionCache),
            @('scripts',     $script:scriptsCache),
            @('reports',     $script:reportsCache),
            @('degradation', $script:degCache),
            @('runlog',      $script:runlogCache),
            @('governors',   $script:govCache),
            @('alltime',     $script:allTimeCache),
            @('ambientlog',  $script:ambLogCache)
        )
        foreach ($sec in $sections) {
            [void]$sb.Append(',"'); [void]$sb.Append($sec[0]); [void]$sb.Append('":')
            if ($sec[1]) { [void]$sb.Append($sec[1]) } else { [void]$sb.Append('null') }
        }
        [void]$sb.Append('}')
        # UTF8Encoding($false) = no BOM. [System.Text.Encoding]::UTF8 emits one,
        # which makes the file fail any strict JSON parser that opens it.
        [System.IO.File]::WriteAllText($script:dataFile, $sb.ToString(), (New-Object System.Text.UTF8Encoding($false)))
        $script:storeDirty = $false
        $script:lastFlush  = $now
    } catch {}
}

# ── Shared state initialization ──────────────────────────────────────────────
if (-not $script:netHashCache)   { $script:netHashCache   = @{btc='{}';bch='{}';dgb='{}';xec='{}';fb='{}'} }
if (-not $script:netHashLastFetch){ $script:netHashLastFetch = @{btc=0;bch=0;dgb=0;xec=0;fb=0} }
if (-not $script:storeLoaded) {
    $script:storeLoaded = $true
    $script:degCache    = $null
    $script:runlogCache = $null
    $script:govCache    = $null
    $script:ambLogCache = $null
    if (Test-Path $script:dataFile) {
        try {
            $raw = [System.IO.File]::ReadAllText($script:dataFile, [System.Text.Encoding]::UTF8)
            $script:sessionCache = Get-StoreSection $raw 'session'
            $script:scriptsCache = Get-StoreSection $raw 'scripts'
            $script:reportsCache = Get-StoreSection $raw 'reports'
            $script:degCache     = Get-StoreSection $raw 'degradation'
            $script:runlogCache  = Get-StoreSection $raw 'runlog'
            $script:govCache     = Get-StoreSection $raw 'governors'
            $script:allTimeCache = Get-StoreSection $raw 'alltime'
            $script:ambLogCache  = Get-StoreSection $raw 'ambientlog'
        } catch {}
    } else {
        # First run on the new format: fold the three legacy files in, then write
        # the combined one. The originals are left alone as a fallback.
        try {
            $lp = Join-Path $PSScriptRoot "session-data.json"
            if (Test-Path $lp) { $script:sessionCache = [System.IO.File]::ReadAllText($lp, [System.Text.Encoding]::UTF8) }
        } catch {}
        try {
            $lp = Join-Path $PSScriptRoot "scripts-data.json"
            if (Test-Path $lp) { $script:scriptsCache = [System.IO.File]::ReadAllText($lp, [System.Text.Encoding]::UTF8) }
        } catch {}
        try {
            $lp = Join-Path $PSScriptRoot "reports-data.json"
            if (Test-Path $lp) { $script:reportsCache = [System.IO.File]::ReadAllText($lp, [System.Text.Encoding]::UTF8) }
        } catch {}
        Save-Store -Force
    }
}
# Left alone when the unified store already supplied it -- this is the one
# dataset that can never be regenerated from the miners.
if (-not $script:allTimeCache)   { $script:allTimeCache   = $null }
# In-memory only: the desktop republishes this every couple of seconds, so
# there's nothing worth persisting across restarts.
if (-not $script:fleetCache)     { $script:fleetCache     = $null }
if (-not $script:pendingNotifs)  { $script:pendingNotifs  = $null }
# (loaded from bitaxe-data.json above)
if (-not $script:pendingScripts) { $script:pendingScripts = $null }
if (-not $script:arStateCache)   { $script:arStateCache   = $null }
if (-not $script:minersCache)    { $script:minersCache    = $null }
if (-not $script:pendingReports)  { $script:pendingReports  = $null }
# (loaded from bitaxe-data.json above)
if (-not $script:minerIPs)       { $script:minerIPs       = @() }
if (-not $script:setAutoRestart) { $script:setAutoRestart = $null }

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
            [void]$ps3.AddScript($sseScript).AddArgument($respCopy).AddArgument($ipCopy).AddArgument($nexusDiffLib)
            [void]$ps3.BeginInvoke()
            continue
        }

        if ($path -eq "/notifications") {
            try {
                if ($req.HttpMethod -eq "POST") {
                    try {
                        $sr2 = New-Object System.IO.StreamReader($req.InputStream)
                        $nj = $sr2.ReadToEnd(); $sr2.Dispose()
                        if ($nj -and $nj.Length -gt 2) {
                        try {
                            $newNotifs = ConvertFrom-Json $nj
                            if ($script:pendingNotifs) {
                                $existing = ConvertFrom-Json $script:pendingNotifs
                                $combined = @($existing) + @($newNotifs)
                                if ($combined -and $combined.Count -gt 50) { $combined = $combined[-50..-1] }
                                if ($combined) { $script:pendingNotifs = ConvertTo-Json $combined -Compress }
                            } else {
                                $script:pendingNotifs = $nj
                            }
                        } catch { $script:pendingNotifs = $nj }
                    }
                    } catch {}
                    $nb = [System.Text.Encoding]::UTF8.GetBytes('{"ok":true}')
                    $resp.ContentType = "application/json"
                    $resp.ContentLength64 = $nb.Length
                    $resp.OutputStream.Write($nb, 0, $nb.Length)
                } else {
                    $nout = if ($script:pendingNotifs) { $script:pendingNotifs } else { '[]' }
                    $script:pendingNotifs = $null
                    $nb2 = [System.Text.Encoding]::UTF8.GetBytes($nout)
                    $resp.ContentType = "application/json"
                    $resp.ContentLength64 = $nb2.Length
                    $resp.OutputStream.Write($nb2, 0, $nb2.Length)
                }
            } catch { Write-Host "  [Notif] Error: $_" -ForegroundColor Yellow }
            $resp.Close(); continue
        }

        if ($path -eq "/setreports") {
            try {
                $srr = New-Object System.IO.StreamReader($req.InputStream)
                $srj = $srr.ReadToEnd(); $srr.Dispose()
                if ($srj -and $srj.Length -gt 2) { $script:pendingReports = $srj }
            } catch {}
            $resp.StatusCode = 200; $resp.Headers.Add("Access-Control-Allow-Origin","*")
            $b=[System.Text.Encoding]::UTF8.GetBytes("ok"); $resp.ContentLength64=$b.Length; $resp.OutputStream.Write($b,0,$b.Length)
            $resp.Close(); continue
        }

        if ($path -eq "/getreports") {
            $sout5 = if ($script:pendingReports) { $script:pendingReports } else { 'null' }
            $sb5=[System.Text.Encoding]::UTF8.GetBytes($sout5)
            $resp.ContentType="application/json"; $resp.Headers.Add("Access-Control-Allow-Origin","*")
            $resp.ContentLength64=$sb5.Length; $resp.OutputStream.Write($sb5,0,$sb5.Length)
            $resp.Close(); continue
        }

        if ($path -eq "/setscripts") {
            try {
                $sr4 = New-Object System.IO.StreamReader($req.InputStream)
                $sj4 = $sr4.ReadToEnd(); $sr4.Dispose()
                if ($sj4 -and $sj4.Length -gt 2) {
                    $script:scriptsCache = $sj4
                    $script:pendingScripts = $sj4
                    $script:storeDirty = $true; Save-Store -Force
                }
            } catch {}
            $rb4=[System.Text.Encoding]::UTF8.GetBytes('{"ok":true}')
            $resp.ContentType="application/json"; $resp.ContentLength64=$rb4.Length
            $resp.OutputStream.Write($rb4,0,$rb4.Length)
            $resp.Close(); continue
        }

        if ($path -eq "/getscripts") {
            # Return full scripts cache so Safari always has latest
            $sout4 = if ($script:scriptsCache) { $script:scriptsCache } else { 'null' }
            $sb4=[System.Text.Encoding]::UTF8.GetBytes($sout4)
            $resp.ContentType="application/json"; $resp.ContentLength64=$sb4.Length
            $resp.OutputStream.Write($sb4,0,$sb4.Length)
            $resp.Close(); continue
        }

        if ($path -eq "/governors") {
            # Windows pushes canonical governor config here; mobile polls it (read channel)
            if ($req.HttpMethod -eq "POST") {
                try {
                    $grd = New-Object System.IO.StreamReader($req.InputStream)
                    $gjd = $grd.ReadToEnd(); $grd.Dispose()
                    if ($gjd -and $gjd.Length -gt 1) { $script:governorsCache = $gjd }
                } catch {}
                $gb=[System.Text.Encoding]::UTF8.GetBytes('{"ok":true}')
                $resp.ContentType="application/json"; $resp.ContentLength64=$gb.Length
                $resp.OutputStream.Write($gb,0,$gb.Length)
            } else {
                $gout = if ($script:governorsCache) { $script:governorsCache } else { 'null' }
                $gb=[System.Text.Encoding]::UTF8.GetBytes($gout)
                $resp.ContentType="application/json"; $resp.ContentLength64=$gb.Length
                $resp.OutputStream.Write($gb,0,$gb.Length)
            }
            $resp.Close(); continue
        }

        if ($path -eq "/setgovernors") {
            # Mobile writes governor changes here; Windows polls /getgovernors (write channel)
            try {
                $grs = New-Object System.IO.StreamReader($req.InputStream)
                $gjs = $grs.ReadToEnd(); $grs.Dispose()
                if ($gjs -and $gjs.Length -gt 1) {
                    $script:governorsCache = $gjs
                    $script:pendingGovernors = $gjs
                }
            } catch {}
            $gb=[System.Text.Encoding]::UTF8.GetBytes('{"ok":true}')
            $resp.ContentType="application/json"; $resp.ContentLength64=$gb.Length
            $resp.OutputStream.Write($gb,0,$gb.Length)
            $resp.Close(); continue
        }

        if ($path -eq "/getgovernors") {
            # Windows polls for mobile-originated changes; returns pending once then clears
            $gout = if ($script:pendingGovernors) { $script:pendingGovernors } else { 'null' }
            $script:pendingGovernors = $null
            $gb=[System.Text.Encoding]::UTF8.GetBytes($gout)
            $resp.ContentType="application/json"; $resp.ContentLength64=$gb.Length
            $resp.OutputStream.Write($gb,0,$gb.Length)
            $resp.Close(); continue
        }

        # Degradation log and run-log. These are the only long-horizon datasets
        # (120 days), so they get a disk home rather than living only in the
        # browser's localStorage where clearing site data would wipe them.
        # Governor profiles. /setgovernors is the mobile change channel and is
        # consumed on read; this is the durable copy.
        # Storage audit: what is actually on disk, section by section. Reports
        # the real file, not the in-memory caches, so it can confirm a section
        # genuinely persisted rather than merely existing in the browser.
        if ($path -eq "/storeinfo") {
            $fileBytes = 0; $fileTime = ''
            try {
                if (Test-Path $script:dataFile) {
                    $fi = Get-Item $script:dataFile
                    $fileBytes = $fi.Length
                    $fileTime  = $fi.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss')
                }
            } catch {}
            $onDisk = ''
            try { if (Test-Path $script:dataFile) { $onDisk = [System.IO.File]::ReadAllText($script:dataFile, [System.Text.Encoding]::UTF8) } } catch {}
            $secs = @()
            foreach ($nm in @('session','scripts','reports','degradation','runlog','governors','alltime','ambientlog')) {
                $raw = if ($onDisk) { Get-StoreSection $onDisk $nm } else { $null }
                $len = if ($raw) { $raw.Length } else { 0 }
                $cnt = Count-JsonTop $raw
                $secs += ('"' + $nm + '":{"bytes":' + $len + ',"items":' + $cnt + '}')
            }
            $js = '{"file":' + (ConvertTo-Json $script:dataFile) + ',"bytes":' + $fileBytes +
                  ',"modified":"' + $fileTime + '","sections":{' + ($secs -join ',') + '}}'
            $b=[System.Text.Encoding]::UTF8.GetBytes($js)
            $resp.ContentType="application/json"; $resp.Headers.Add("Access-Control-Allow-Origin","*")
            $resp.ContentLength64=$b.Length; $resp.OutputStream.Write($b,0,$b.Length)
            $resp.Close(); continue
        }

        if ($path -eq "/governorstore" -and $req.HttpMethod -eq "GET") {
            $d = if ($script:govCache) { $script:govCache } else { 'null' }
            $b=[System.Text.Encoding]::UTF8.GetBytes($d)
            $resp.ContentType="application/json"; $resp.Headers.Add("Access-Control-Allow-Origin","*")
            $resp.ContentLength64=$b.Length; $resp.OutputStream.Write($b,0,$b.Length)
            $resp.Close(); continue
        }
        if ($path -eq "/governorstore" -and $req.HttpMethod -eq "POST") {
            try {
                $rd = New-Object System.IO.StreamReader($req.InputStream)
                $gj2 = $rd.ReadToEnd(); $rd.Dispose()
                if ($gj2 -and $gj2.Length -gt 1) { $script:govCache = $gj2; $script:storeDirty = $true; Save-Store -Force }
            } catch {}
            $b=[System.Text.Encoding]::UTF8.GetBytes('{"ok":true}')
            $resp.ContentType="application/json"; $resp.Headers.Add("Access-Control-Allow-Origin","*")
            $resp.ContentLength64=$b.Length; $resp.OutputStream.Write($b,0,$b.Length)
            $resp.Close(); continue
        }

        # Ambient history. Its own series rather than a replay of live telemetry,
        # so the curve survives restarts the way the readings that built it do.
        if ($path -eq "/ambientlog" -and $req.HttpMethod -eq "GET") {
            $d = if ($script:ambLogCache) { $script:ambLogCache } else { 'null' }
            $b=[System.Text.Encoding]::UTF8.GetBytes($d)
            $resp.ContentType="application/json"; $resp.Headers.Add("Access-Control-Allow-Origin","*")
            $resp.ContentLength64=$b.Length; $resp.OutputStream.Write($b,0,$b.Length)
            $resp.Close(); continue
        }
        if ($path -eq "/ambientlog" -and $req.HttpMethod -eq "POST") {
            try {
                $rd = New-Object System.IO.StreamReader($req.InputStream)
                $aj = $rd.ReadToEnd(); $rd.Dispose()
                if ($aj -and $aj.Length -gt 1) { $script:ambLogCache = $aj; $script:storeDirty = $true; Save-Store }
            } catch {}
            $b=[System.Text.Encoding]::UTF8.GetBytes('{"ok":true}')
            $resp.ContentType="application/json"; $resp.Headers.Add("Access-Control-Allow-Origin","*")
            $resp.ContentLength64=$b.Length; $resp.OutputStream.Write($b,0,$b.Length)
            $resp.Close(); continue
        }

        if ($path -eq "/degradation" -and $req.HttpMethod -eq "GET") {
            $d = if ($script:degCache) { $script:degCache } else { 'null' }
            $b=[System.Text.Encoding]::UTF8.GetBytes($d)
            $resp.ContentType="application/json"; $resp.Headers.Add("Access-Control-Allow-Origin","*")
            $resp.ContentLength64=$b.Length; $resp.OutputStream.Write($b,0,$b.Length)
            $resp.Close(); continue
        }
        if ($path -eq "/degradation" -and $req.HttpMethod -eq "POST") {
            try {
                $rd = New-Object System.IO.StreamReader($req.InputStream)
                $dj = $rd.ReadToEnd(); $rd.Dispose()
                if ($dj -and $dj.Length -gt 1) { $script:degCache = $dj; $script:storeDirty = $true; Save-Store }
            } catch {}
            $b=[System.Text.Encoding]::UTF8.GetBytes('{"ok":true}')
            $resp.ContentType="application/json"; $resp.Headers.Add("Access-Control-Allow-Origin","*")
            $resp.ContentLength64=$b.Length; $resp.OutputStream.Write($b,0,$b.Length)
            $resp.Close(); continue
        }
        if ($path -eq "/runlog" -and $req.HttpMethod -eq "GET") {
            $d = if ($script:runlogCache) { $script:runlogCache } else { 'null' }
            $b=[System.Text.Encoding]::UTF8.GetBytes($d)
            $resp.ContentType="application/json"; $resp.Headers.Add("Access-Control-Allow-Origin","*")
            $resp.ContentLength64=$b.Length; $resp.OutputStream.Write($b,0,$b.Length)
            $resp.Close(); continue
        }
        if ($path -eq "/runlog" -and $req.HttpMethod -eq "POST") {
            try {
                $rd = New-Object System.IO.StreamReader($req.InputStream)
                $rj2 = $rd.ReadToEnd(); $rd.Dispose()
                if ($rj2 -and $rj2.Length -gt 1) { $script:runlogCache = $rj2; $script:storeDirty = $true; Save-Store }
            } catch {}
            $b=[System.Text.Encoding]::UTF8.GetBytes('{"ok":true}')
            $resp.ContentType="application/json"; $resp.Headers.Add("Access-Control-Allow-Origin","*")
            $resp.ContentLength64=$b.Length; $resp.OutputStream.Write($b,0,$b.Length)
            $resp.Close(); continue
        }

        if ($path -eq "/setuwcfg") {
            # Mobile writes underperformance-watchdog changes here; Windows polls
            # /getuwcfg. Its own channel, not the auto-restart slot -- that one is
            # single-value and consumed on read, so the two would clobber each other.
            try {
                $urs = New-Object System.IO.StreamReader($req.InputStream)
                $ujs = $urs.ReadToEnd(); $urs.Dispose()
                if ($ujs -and $ujs.Length -gt 1) { $script:pendingUwCfg = $ujs }
            } catch {}
            $ub=[System.Text.Encoding]::UTF8.GetBytes('{"ok":true}')
            $resp.ContentType="application/json"; $resp.ContentLength64=$ub.Length
            $resp.OutputStream.Write($ub,0,$ub.Length)
            $resp.Close(); continue
        }

        if ($path -eq "/getuwcfg") {
            $uout = if ($script:pendingUwCfg) { $script:pendingUwCfg } else { 'null' }
            $script:pendingUwCfg = $null
            $ub=[System.Text.Encoding]::UTF8.GetBytes($uout)
            $resp.ContentType="application/json"; $resp.ContentLength64=$ub.Length
            $resp.OutputStream.Write($ub,0,$ub.Length)
            $resp.Close(); continue
        }

        if ($path -eq "/reports") {
            try {
                if ($req.HttpMethod -eq "POST") {
                    try {
                        $rr = New-Object System.IO.StreamReader($req.InputStream)
                        $rj = $rr.ReadToEnd(); $rr.Dispose()
                        if ($rj -and $rj.Length -gt 2) {
                            $script:reportsCache = $rj
                            $script:storeDirty = $true; Save-Store -Force
                        }
                    } catch {}
                    $resp.StatusCode = 200; $resp.Headers.Add("Access-Control-Allow-Origin","*")
                    $b=[System.Text.Encoding]::UTF8.GetBytes("ok"); $resp.ContentLength64=$b.Length; $resp.OutputStream.Write($b,0,$b.Length)
                } else {
                    $data = if ($script:reportsCache) { $script:reportsCache } else { '{}' }
                    $resp.StatusCode = 200; $resp.ContentType = "application/json"
                    $resp.Headers.Add("Access-Control-Allow-Origin","*")
                    $b=[System.Text.Encoding]::UTF8.GetBytes($data); $resp.ContentLength64=$b.Length; $resp.OutputStream.Write($b,0,$b.Length)
                }
            } catch { $resp.StatusCode=500 }
            $resp.Close(); continue
        }

        if ($path -eq "/startup") {
            if ($req.HttpMethod -eq "GET") {
                $taskExists = $false
                try {
                    $task = Get-ScheduledTask -TaskName "BitaxeDifficultyTracker" -ErrorAction SilentlyContinue
                    $taskExists = ($null -ne $task)
                } catch {}
                $data = if ($taskExists) { '{"enabled":true}' } else { '{"enabled":false}' }
                $resp.StatusCode = 200; $resp.ContentType = "application/json"
                $resp.Headers.Add("Access-Control-Allow-Origin","*")
                $b=[System.Text.Encoding]::UTF8.GetBytes($data); $resp.ContentLength64=$b.Length; $resp.OutputStream.Write($b,0,$b.Length)
            } else {
                try {
                    $sr6 = New-Object System.IO.StreamReader($req.InputStream)
                    $sj6 = $sr6.ReadToEnd(); $sr6.Dispose()
                    $req6 = ConvertFrom-Json $sj6
                    $helperPath = Join-Path $PSScriptRoot "startup-helper.ps1"
                    $batPath = Join-Path $PSScriptRoot "Launch Bitaxe Difficulty Tracker.bat"
                    if ($req6.enable) {
                        $args6 = "-NoProfile -ExecutionPolicy Bypass -File `"$helperPath`" -Action add -BatPath `"$batPath`" -Username `"$env:USERNAME`""
                        Start-Process "powershell.exe" -ArgumentList $args6 -Verb RunAs -Wait
                        Write-Host "  [Startup] Task created (elevated)" -ForegroundColor Green
                    } else {
                        $args6 = "-NoProfile -ExecutionPolicy Bypass -File `"$helperPath`" -Action remove -Username `"$env:USERNAME`""
                        Start-Process "powershell.exe" -ArgumentList $args6 -Verb RunAs -Wait
                        Write-Host "  [Startup] Task removed (elevated)" -ForegroundColor Yellow
                    }
                    $resp.StatusCode = 200
                } catch {
                    Write-Host "  [Startup] Error: $_" -ForegroundColor Red
                    $resp.StatusCode = 500
                }
                $resp.Headers.Add("Access-Control-Allow-Origin","*")
                $b=[System.Text.Encoding]::UTF8.GetBytes("ok"); $resp.ContentLength64=$b.Length; $resp.OutputStream.Write($b,0,$b.Length)
            }
            $resp.Close(); continue
        }
        if ($path -eq "/scripts") {
            try {
                if ($req.HttpMethod -eq "POST") {
                    try {
                        $sr3 = New-Object System.IO.StreamReader($req.InputStream)
                        $sj = $sr3.ReadToEnd(); $sr3.Dispose()
                        if ($sj -and $sj.Length -gt 2) {
                            $script:scriptsCache = $sj
                            $script:storeDirty = $true; Save-Store -Force
                        }
                    } catch {}
                    $rb=[System.Text.Encoding]::UTF8.GetBytes('{"ok":true}')
                    $resp.ContentType="application/json"; $resp.ContentLength64=$rb.Length
                    $resp.OutputStream.Write($rb,0,$rb.Length)
                } else {
                    $sout = if ($script:scriptsCache) { $script:scriptsCache } else { '[]' }
                    $sb=[System.Text.Encoding]::UTF8.GetBytes($sout)
                    $resp.ContentType="application/json"; $resp.ContentLength64=$sb.Length
                    $resp.OutputStream.Write($sb,0,$sb.Length)
                }
            } catch {}
            $resp.Close(); continue
        }

        if ($path -eq "/scoreboard" -and $ip) {
            try {
                $wc2 = New-Object System.Net.WebClient
                $wc2.Headers.Add("Accept","application/json")
                $sbReq = [System.Net.HttpWebRequest]::Create("http://$ip/api/system/scoreboard")
                $sbReq.Method = "GET"; $sbReq.Timeout = 4000; $sbReq.ReadWriteTimeout = 4000
                $sbResp2 = $sbReq.GetResponse()
                $sbReader = New-Object System.IO.StreamReader($sbResp2.GetResponseStream())
                $sb = [System.Text.Encoding]::UTF8.GetBytes($sbReader.ReadToEnd())
                $sbReader.Close(); $sbResp2.Close()
                $resp.ContentType="application/json"
                $resp.Headers.Add("Access-Control-Allow-Origin","*")
                $resp.ContentLength64=$sb.Length
                $resp.OutputStream.Write($sb,0,$sb.Length)
            } catch {
                $b=[System.Text.Encoding]::UTF8.GetBytes("[]")
                $resp.ContentType="application/json"
                $resp.ContentLength64=$b.Length
                $resp.OutputStream.Write($b,0,$b.Length)
            }
            $resp.Close(); continue
        }

        if ($path -eq "/api" -and $ip) {
            try {
                $apiReq = [System.Net.HttpWebRequest]::Create("http://$ip/api/system/info")
                $apiReq.Method = "GET"; $apiReq.Accept = "application/json"
                $apiReq.Timeout = 4000; $apiReq.ReadWriteTimeout = 4000
                $apiResp = $apiReq.GetResponse()
                $apiReader = New-Object System.IO.StreamReader($apiResp.GetResponseStream())
                $apiData = [System.Text.Encoding]::UTF8.GetBytes($apiReader.ReadToEnd())
                $apiReader.Close(); $apiResp.Close()
                $resp.ContentType = "application/json"
                $resp.Headers.Add("Access-Control-Allow-Origin","*")
                $resp.ContentLength64 = $apiData.Length
                $resp.OutputStream.Write($apiData,0,$apiData.Length)
                Write-Host "  [API] $ip OK" -ForegroundColor Green
            } catch {
                $msg = [System.Text.Encoding]::UTF8.GetBytes("{`"error`":`"$_`"}")
                $resp.StatusCode = 502; $resp.ContentType = "application/json"
                $resp.Headers.Add("Access-Control-Allow-Origin","*")
                $resp.ContentLength64 = $msg.Length
                $resp.OutputStream.Write($msg,0,$msg.Length)
                Write-Host "  [API] $ip FAILED" -ForegroundColor Red
            }
            $resp.Close(); continue


        if ($path -eq "/scoreboard" -and $ip) {
            try {
                $wc2 = New-Object System.Net.WebClient
                $wc2.Headers.Add("Accept","application/json")
                $sbReq = [System.Net.HttpWebRequest]::Create("http://$ip/api/system/scoreboard")
                $sbReq.Method = "GET"; $sbReq.Timeout = 4000; $sbReq.ReadWriteTimeout = 4000
                $sbResp2 = $sbReq.GetResponse()
                $sbReader = New-Object System.IO.StreamReader($sbResp2.GetResponseStream())
                $sb = [System.Text.Encoding]::UTF8.GetBytes($sbReader.ReadToEnd())
                $sbReader.Close(); $sbResp2.Close()
                $resp.ContentType="application/json"
                $resp.Headers.Add("Access-Control-Allow-Origin","*")
                $resp.ContentLength64=$sb.Length
                $resp.OutputStream.Write($sb,0,$sb.Length)
            } catch {
                $b=[System.Text.Encoding]::UTF8.GetBytes("[]")
                $resp.ContentType="application/json"
                $resp.ContentLength64=$b.Length
                $resp.OutputStream.Write($b,0,$b.Length)
            }
            $resp.Close(); continue
        }        }

        # /setminers POST - desktop posts current miner IPs
        if ($path -eq "/setautorestart" -and $req.HttpMethod -eq "POST") {
            try {
                $body = New-Object System.IO.StreamReader($req.InputStream)
                $json = $body.ReadToEnd()
                $obj = $json | ConvertFrom-Json
                $script:pendingAutoRestart = $obj
                $b=[System.Text.Encoding]::UTF8.GetBytes('{"ok":true}')
                $resp.ContentType="application/json"
                $resp.ContentLength64=$b.Length
                $resp.OutputStream.Write($b,0,$b.Length)
            } catch {
                $b=[System.Text.Encoding]::UTF8.GetBytes('{"ok":false}')
                $resp.ContentType="application/json"
                $resp.ContentLength64=$b.Length
                $resp.OutputStream.Write($b,0,$b.Length)
            }
            $resp.Close(); continue
        }

        if ($path -eq "/setminers" -and $req.HttpMethod -eq "POST") {
            $reader = New-Object System.IO.StreamReader($req.InputStream)
            $body2 = $reader.ReadToEnd(); $reader.Close()
            try {
                $obj2 = $body2 | ConvertFrom-Json
                $script:minerIPs = @($obj2.ips)
                if ($obj2.names) { $script:minerNames = $obj2.names }
                Write-Host "  [Sync] Miner IPs: $($script:minerIPs -join ', ')" -ForegroundColor Cyan
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

        # /fleet GET - flat combined rollup, for watch complications / widgets.
        # Deliberately flat: JSON-path tools (Complicator, Scriptable, etc) use
        # dot notation, and /session is keyed by miner IP - the dots in an IP are
        # indistinguishable from path separators, so nothing can address it.
        # Contains rollup numbers only: no pool, wallet or credential strings.
        if ($path -eq "/fleet" -and $req.HttpMethod -eq "GET") {
            $data = if ($script:fleetCache) { $script:fleetCache } else { '{}' }
            $resp.StatusCode = 200; $resp.ContentType = "application/json"
            $resp.Headers.Add("Access-Control-Allow-Origin","*")
            $b = [System.Text.Encoding]::UTF8.GetBytes($data)
            $resp.ContentLength64 = $b.Length; $resp.OutputStream.Write($b,0,$b.Length)
            $resp.Close(); continue
        }

        # /fleet POST - desktop pushes the computed rollup. The server stays a
        # dumb cache; fleetStats() on the desktop remains the single source of
        # truth, so this can't drift from what the cards show.
        if ($path -eq "/fleet" -and $req.HttpMethod -eq "POST") {
            $reader = New-Object System.IO.StreamReader($req.InputStream)
            $script:fleetCache = $reader.ReadToEnd(); $reader.Close()
            $resp.StatusCode = 200; $resp.Headers.Add("Access-Control-Allow-Origin","*")
            $b = [System.Text.Encoding]::UTF8.GetBytes("ok")
            $resp.ContentLength64 = $b.Length; $resp.OutputStream.Write($b,0,$b.Length)
            $resp.Close(); continue
        }

        # /session POST - desktop pushes live session stats
        if ($path -eq "/session" -and $req.HttpMethod -eq "POST") {
            $reader = New-Object System.IO.StreamReader($req.InputStream)
            $script:sessionCache = $reader.ReadToEnd(); $reader.Close()
            # Persist to disk - but only if snapshot has data or is intentionally cleared
            try {
                # Was a full ConvertFrom-Json of the entire session blob on every
                # POST -- roughly every 2 seconds. A substring test answers the
                # same question (is there anything worth keeping?) for a tiny
                # fraction of the cost, and the write itself is now throttled.
                # The desktop sends a signature covering only the unrecoverable
                # parts (session bests, top-share lists, cleared flag). If it is
                # unchanged there is nothing worth writing, so skip the disk
                # entirely -- which is most posts, since a new top share lands
                # minutes or hours apart, not every 2 seconds.
                $psig = $req.Headers['X-Persist-Sig']
                if ($psig -and $psig -eq $script:lastPsig) {
                    # nothing persistable changed
                } else {
                    if ($psig) { $script:lastPsig = $psig }
                    $hasData   = $script:sessionCache.Contains('"topSeriesSnapshot":[{')
                    $isCleared = $script:sessionCache.Contains('"sessionCleared":true')
                    if ($hasData -or $isCleared) {
                        $script:storeDirty = $true
                        Save-Store
                    }
                }
            } catch {}
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
        # /setclearsession POST - mobile requests session clear
        if ($path -eq "/setclearsession" -and $req.HttpMethod -eq "POST") {
            $reader = New-Object System.IO.StreamReader($req.InputStream)
            $script:pendingClearSession = $reader.ReadToEnd(); $reader.Close()
            $resp.StatusCode = 200; $resp.Headers.Add("Access-Control-Allow-Origin","*")
            $resp.ContentLength64 = 0; $resp.OutputStream.Close(); continue
        }

        # /getclearsession GET - Windows polls for pending clear
        if ($path -eq "/getclearsession") {
            if ($script:pendingClearSession) {
                $json = $script:pendingClearSession
                $script:pendingClearSession = $null
                $resp.StatusCode = 200; $resp.ContentType = "application/json"
                $buf = [System.Text.Encoding]::UTF8.GetBytes($json)
                $resp.ContentLength64 = $buf.Length; $resp.OutputStream.Write($buf,0,$buf.Length)
                $resp.OutputStream.Close(); continue
            }
            $resp.StatusCode = 200; $resp.ContentType = "application/json"
            $buf = [System.Text.Encoding]::UTF8.GetBytes("{}")
            $resp.ContentLength64 = $buf.Length; $resp.OutputStream.Write($buf,0,$buf.Length)
            $resp.OutputStream.Close(); continue
        }

        if ($path -eq "/getautorestart") {
            if ($script:pendingAutoRestart) {
                $json = $script:pendingAutoRestart | ConvertTo-Json -Compress
                # Consume ONLY the auto-restart flag. This used to also null
                # scriptsCache, pendingNotifs and pendingScripts, which wiped
                # every saved script the first time an auto-restart was polled.
                $script:pendingAutoRestart = $null
            } else {
                $json = 'null'
            }
            $b=[System.Text.Encoding]::UTF8.GetBytes($json)
            $resp.ContentType="application/json"
            $resp.ContentLength64=$b.Length
            $resp.OutputStream.Write($b,0,$b.Length)
            $resp.Close(); continue
        }

        if ($path -eq "/alltime" -and $req.HttpMethod -eq "GET") {
            $data = if ($script:allTimeCache) { $script:allTimeCache } else { '{}' }
            $resp.StatusCode = 200; $resp.ContentType = "application/json"
            $resp.Headers.Add("Access-Control-Allow-Origin", "*")
            $b = [System.Text.Encoding]::UTF8.GetBytes($data)
            $resp.ContentLength64 = $b.Length; $resp.OutputStream.Write($b, 0, $b.Length)
            $resp.Close(); continue
        }

        # /hralltime GET
        if ($path -eq "/hralltime" -and $req.HttpMethod -eq "GET") {
            $data = if ($script:hrAllTimeCache) { $script:hrAllTimeCache } else { '{}' }
            $resp.StatusCode = 200; $resp.ContentType = "application/json"
            $buf = [System.Text.Encoding]::UTF8.GetBytes($data)
            $resp.ContentLength64 = $buf.Length; $resp.OutputStream.Write($buf,0,$buf.Length)
            $resp.OutputStream.Close(); continue
        }

        # /hralltime POST
        if ($path -eq "/hralltime" -and $req.HttpMethod -eq "POST") {
            $reader = New-Object System.IO.StreamReader($req.InputStream)
            $script:hrAllTimeCache = $reader.ReadToEnd(); $reader.Close()
            $resp.StatusCode = 200; $resp.Headers.Add("Access-Control-Allow-Origin","*")
            $resp.ContentLength64 = 0; $resp.OutputStream.Close(); continue
        }

        # /deletehrentry POST - delete a specific HR entry by ip+ts
        if ($path -eq "/deletehrentry" -and $req.HttpMethod -eq "POST") {
            $reader = New-Object System.IO.StreamReader($req.InputStream)
            $json = $reader.ReadToEnd(); $reader.Close()
            if ($script:hrAllTimeCache) {
                try {
                    $d = ConvertFrom-Json $script:hrAllTimeCache
                    $del = ConvertFrom-Json $json
                    if ($del.ts -eq "all") {
                        if ($d.PSObject.Properties.Name -contains $del.ip) {
                            $d.PSObject.Properties.Remove($del.ip)
                            $script:hrAllTimeCache = ConvertTo-Json $d -Compress -Depth 5
                            $script:pendingHrDelete = $json
                        }
                    }
                    elseif ($d.($del.ip)) {
                        $d.($del.ip) = @($d.($del.ip) | Where-Object { $_.ts -ne $del.ts })
                        $script:hrAllTimeCache = ConvertTo-Json $d -Compress -Depth 5
                        $script:pendingHrDelete = $json
                    }
                } catch {}
            }
            $resp.StatusCode = 200; $resp.Headers.Add("Access-Control-Allow-Origin","*")
            $resp.ContentLength64 = 0; $resp.OutputStream.Close(); continue
        }

        # /gethrdelete GET - Windows polls for pending HR deletes
        if ($path -eq "/gethrdelete") {
            if ($script:pendingHrDelete) {
                $json2 = $script:pendingHrDelete
                $script:pendingHrDelete = $null
                $resp.StatusCode = 200; $resp.ContentType = "application/json"
                $buf = [System.Text.Encoding]::UTF8.GetBytes($json2)
                $resp.ContentLength64 = $buf.Length; $resp.OutputStream.Write($buf,0,$buf.Length)
                $resp.OutputStream.Close(); continue
            }
            $resp.StatusCode = 200; $resp.ContentType = "application/json"
            $buf = [System.Text.Encoding]::UTF8.GetBytes("{}")
            $resp.ContentLength64 = $buf.Length; $resp.OutputStream.Write($buf,0,$buf.Length)
            $resp.OutputStream.Close(); continue
        }

        # /setdiffclear POST - mobile requests clearing one miner's all-time diffs
        if ($path -eq "/setdiffclear" -and $req.HttpMethod -eq "POST") {
            $reader = New-Object System.IO.StreamReader($req.InputStream)
            $json = $reader.ReadToEnd(); $reader.Close()
            try {
                $del = ConvertFrom-Json $json
                if ($script:allTimeCache) {
                    $d = ConvertFrom-Json $script:allTimeCache
                    # all-time may be flat {ip:[...]} (atSave) or wrapped {alltime:{ip:[...]}}
                    $target = if ($d.PSObject.Properties.Name -contains "alltime") { $d.alltime } else { $d }
                    if ($target -and ($target.PSObject.Properties.Name -contains $del.ip)) {
                        $target.PSObject.Properties.Remove($del.ip)
                        $script:allTimeCache = ConvertTo-Json $d -Compress -Depth 6
                        $script:storeDirty = $true; Save-Store -Force
                    }
                }
                $script:pendingDiffClear = $json
            } catch {}
            $resp.StatusCode = 200; $resp.Headers.Add("Access-Control-Allow-Origin","*")
            $resp.ContentLength64 = 0; $resp.OutputStream.Close(); continue
        }

        # /getdiffclear GET - Windows polls for pending all-time diff clears
        if ($path -eq "/getdiffclear") {
            if ($script:pendingDiffClear) {
                $json3 = $script:pendingDiffClear
                $script:pendingDiffClear = $null
                $resp.StatusCode = 200; $resp.ContentType = "application/json"
                $buf = [System.Text.Encoding]::UTF8.GetBytes($json3)
                $resp.ContentLength64 = $buf.Length; $resp.OutputStream.Write($buf,0,$buf.Length)
                $resp.OutputStream.Close(); continue
            }
            $resp.StatusCode = 200; $resp.ContentType = "application/json"
            $buf = [System.Text.Encoding]::UTF8.GetBytes("{}")
            $resp.ContentLength64 = $buf.Length; $resp.OutputStream.Write($buf,0,$buf.Length)
            $resp.OutputStream.Close(); continue
        }

        # /alltime POST - desktop posts localStorage data for mobile to read
        if ($path -eq "/alltime" -and $req.HttpMethod -eq "POST") {
            $reader = New-Object System.IO.StreamReader($req.InputStream)
            $script:allTimeCache = $reader.ReadToEnd(); $reader.Close()
            $script:storeDirty = $true; Save-Store -Force
            # NOTE: intentionally do NOT rebuild $script:minerIPs from all-time keys.
            # The active-miner list comes ONLY from /setminers (explicitly added miners).
            # This keeps a removed miner's history intact without resurrecting it into
            # the poll/connect list. Re-adding the miner later reattaches its history.
            $resp.StatusCode = 200; $resp.Headers.Add("Access-Control-Allow-Origin", "*")
            $b = [System.Text.Encoding]::UTF8.GetBytes("ok")
            $resp.ContentLength64 = $b.Length; $resp.OutputStream.Write($b, 0, $b.Length)
            $resp.Close(); continue
        }

        if ($path -eq "/" -or $path -eq "/index.html" -or $path -eq "/BitaxeDifficultyTracker.html") {
            if (Test-Path $HTML_FILE) {
                $b=[System.IO.File]::ReadAllBytes($HTML_FILE)
                $resp.ContentType="text/html; charset=utf-8"; $resp.ContentLength64=$b.Length
                $resp.OutputStream.Write($b,0,$b.Length)
            } else {
                $b=[System.Text.Encoding]::UTF8.GetBytes("BitaxeDifficultyTracker.html not found")
                $resp.StatusCode=404; $resp.ContentLength64=$b.Length; $resp.OutputStream.Write($b,0,$b.Length)
            }
            $resp.Close(); continue
        }

        # Simple test page to confirm iPhone can reach server
        if ($path -eq "/nethash") {
            $coin = $req.QueryString["coin"]
            if (-not $coin) { $coin = "btc" }
            # Return cached value immediately (non-blocking)
            $nhCached = if ($script:netHashCache -and $script:netHashCache.ContainsKey($coin)) { $script:netHashCache[$coin] } else { $null }
            if (-not $nhCached -or $nhCached -eq "{}") { $nhCached = "{`"hashrate`":`"0`",`"coin`":`"$coin`"}" }
            $nhBytes = [System.Text.Encoding]::UTF8.GetBytes($nhCached)
            $resp.ContentType = "application/json"
            $resp.Headers.Add("Access-Control-Allow-Origin","*")
            $resp.ContentLength64 = $nhBytes.Length
            $resp.OutputStream.Write($nhBytes, 0, $nhBytes.Length)
            $resp.Close()
            # Fetch fresh data in background if stale (>5 min)
            $nhNow = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
            if ($script:netHashLastFetch -and $script:netHashLastFetch.ContainsKey($coin) -and ($nhNow - $script:netHashLastFetch[$coin]) -gt 300) {
                $script:netHashLastFetch[$coin] = $nhNow
                $nhCoin = $coin
                $rsNH = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace()
                $rsNH.Open()
                $psNH = [System.Management.Automation.PowerShell]::Create()
                $psNH.Runspace = $rsNH
                [void]$psNH.AddScript({
                    param($nhCoinArg, $cacheRef)
                    try {
                        $nhUrl = if ($nhCoinArg -eq "btc") { "https://blockchain.info/q/hashrate" }
                                 elseif ($nhCoinArg -eq "bch") { "https://blockchain.info/bch/q/hashrate" }
                                 elseif ($nhCoinArg -eq "xec") { "https://chainz.cryptoid.info/xec/api.dws?q=hashrate" }
                                 elseif ($nhCoinArg -eq "fb") { $null }
                                 else { "https://chainz.cryptoid.info/dgb/api.dws?q=hashrate" }
                        if (-not $nhUrl) { return }
                        $nhReq2 = [System.Net.HttpWebRequest]::Create($nhUrl)
                        $nhReq2.Timeout = 10000; $nhReq2.ReadWriteTimeout = 10000
                        $nhResp2 = $nhReq2.GetResponse()
                        $nhReader2 = New-Object System.IO.StreamReader($nhResp2.GetResponseStream())
                        $nhVal2 = $nhReader2.ReadToEnd().Trim()
                        $nhReader2.Close(); $nhResp2.Close()
                        $script:netHashCache[$nhCoinArg] = "{`"hashrate`":`"$nhVal2`",`"coin`":`"$nhCoinArg`"}"
                    } catch {}
                    finally { try { $rsNH.Close() } catch {} }
                }).AddArgument($nhCoin).AddArgument($script:netHashCache)
                [void]$psNH.BeginInvoke()
            }
            continue       }

        if ($path -eq "/test") {
            $b = [System.Text.Encoding]::UTF8.GetBytes("<html><body style='background:#000;color:#0f0;font-family:monospace;font-size:24px;padding:40px'><h1>✅ Server is reachable!</h1><p>Your iPhone can talk to the server.</p><p>Now try: <a style='color:#38bdf8' href='/'>http://$($req.Url.Host)/</a></p></body></html>")
            $resp.ContentType = "text/html; charset=utf-8"
            $resp.ContentLength64 = $b.Length
            $resp.OutputStream.Write($b, 0, $b.Length)
            $resp.Close(); continue
        }

        if ($path -eq "/patch" -and $ip) {
            $bodyJson = $req.Headers["X-Body"]
            if (-not $bodyJson) {
                $freq=$req.Headers["X-Freq"]; $voltage=$req.Headers["X-Voltage"]
                $bodyJson='{"frequency":'+$freq+',"coreVoltage":'+$voltage+',"overclockEnabled":1}'
            }
            $ipCopyP = $ip; $bodyJsonCopy = $bodyJson; $respCopyP = $resp
            $rsPatch = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace()
            $rsPatch.Open()
            $psPatch = [System.Management.Automation.PowerShell]::Create()
            $psPatch.Runspace = $rsPatch
            [void]$psPatch.AddScript({
                param($respP, $ipP, $bodyP)
                try {
                    $pReq=[System.Net.HttpWebRequest]::Create("http://$ipP/api/system")
                    $pReq.Method="PATCH"; $pReq.ContentType="application/json"
                    $pReq.Timeout=5000; $pReq.ReadWriteTimeout=5000
                    $pBytes=[System.Text.Encoding]::UTF8.GetBytes($bodyP)
                    $pReq.ContentLength=$pBytes.Length
                    $pStream=$pReq.GetRequestStream()
                    $pStream.Write($pBytes,0,$pBytes.Length); $pStream.Close()
                    $pResp=$pReq.GetResponse(); $pResp.Close()
                    $b=[System.Text.Encoding]::UTF8.GetBytes("ok")
                    $respP.StatusCode=200
                    $respP.Headers.Add("Access-Control-Allow-Origin","*")
                    $respP.ContentLength64=$b.Length
                    $respP.OutputStream.Write($b,0,$b.Length)
                    Write-Host "  [PATCH] $ipP OK" -ForegroundColor Cyan
                } catch {
                    try {
                        $b2=[System.Text.Encoding]::UTF8.GetBytes("error: $_")
                        $respP.StatusCode=502
                        $respP.Headers.Add("Access-Control-Allow-Origin","*")
                        $respP.ContentLength64=$b2.Length
                        $respP.OutputStream.Write($b2,0,$b2.Length)
                    } catch {}
                    Write-Host "  [PATCH] $ipP FAILED: $_" -ForegroundColor Red
                } finally {
                    try { $respP.Close() } catch {}
                    try { $rsPatch.Close() } catch {}
                }
            }).AddArgument($respCopyP).AddArgument($ipCopyP).AddArgument($bodyJsonCopy)
            [void]$psPatch.BeginInvoke()
            continue
        }

        # /restart?ip=... - proxy POST to AxeOS restart endpoint
        if ($path -eq "/restart" -and $ip) {
            # Fire restart in background runspace so main loop doesn't block
            $ipCopy = $ip
            $rsRestart = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace()
            $rsRestart.Open()
            $psRestart = [System.Management.Automation.PowerShell]::Create()
            $psRestart.Runspace = $rsRestart
            [void]$psRestart.AddScript({
                param($minerIp)
                try {
                    $req = [System.Net.HttpWebRequest]::Create("http://$minerIp/api/system/restart")
                    $req.Method = "POST"; $req.ContentType = "application/json"
                    $req.ContentLength = 0; $req.Timeout = 5000
                    try { $r=$req.GetResponse(); $r.Close() } catch { }
                    Write-Host "  [RESTART] Sent restart to $minerIp" -ForegroundColor Yellow
                } catch {
                    Write-Host "  [RESTART] Failed for ${minerIp}: $_" -ForegroundColor Red
                } finally {
                    try { $rsRestart.Close() } catch {}
                }
            }).AddArgument($ipCopy)
            [void]$psRestart.BeginInvoke()
            # Respond immediately
            $resp.StatusCode = 200
            $resp.Headers.Add("Access-Control-Allow-Origin","*")
            $b = [System.Text.Encoding]::UTF8.GetBytes("ok")
            $resp.ContentLength64 = $b.Length
            $resp.OutputStream.Write($b, 0, $b.Length)
            $resp.Close(); continue
        }

        $resp.StatusCode=404; $resp.Close()

    } catch [System.Net.HttpListenerException] { if (!$listener.IsListening) { break }; continue }
    catch { Write-Host "  [ERR] $_" -ForegroundColor Red; try{$resp.Close()}catch{} }
}

$listener.Stop()
Write-Host "  [Server] Stopped." -ForegroundColor Red
