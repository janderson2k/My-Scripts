# NetworkStatus2.ps1 – Version 3.4

$configPath = Join-Path $PSScriptRoot 'NicStatusConfig.txt'

# ---------------------- First Run Setup ----------------------
if (-not (Test-Path $configPath)) {

    Write-Host ""
    Write-Host "[Setup] Config not found. Starting first-time setup."

    $initial = Get-NetAdapter | Where-Object Status -eq 'Up'
    if (-not $initial) { Write-Host "No active NICs. Exit."; exit }

    Write-Host ""
    Write-Host "Detected NICs:"
    $initial | ForEach-Object { Write-Host ("  {0,-20} {1}" -f $_.Name, $_.LinkSpeed) }

    Read-Host "`nVerify NICs are connected then press ENTER..."

    $active = Get-NetAdapter | Where-Object Status -eq 'Up'
    if (-not $active) { Write-Host "No NICs after re-check. Exit."; exit }

    Write-Host ""
    Write-Host "NICs to monitor:"
    $active | ForEach-Object { Write-Host ("  {0,-20} {1}" -f $_.Name, $_.LinkSpeed) }

    # --- Auto-detect Gateway ---
    $defaultGw = (Get-NetIPConfiguration | Where-Object { $_.IPv4DefaultGateway -ne $null } |
                  Select-Object -First 1).IPv4DefaultGateway.NextHop

    if ($defaultGw) {
        $choice = Read-Host "`nYour current default gateway is $defaultGw. Use this for local connectivity test? (Y/N)"
        if ($choice -match '^[Yy]') {
            $gatewayIP = $defaultGw
        } else {
            $gatewayIP = Read-Host "Enter the local IP address to use instead"
        }
    } else {
        $gatewayIP = Read-Host "`nNo default gateway detected. Please enter a local IP to use for testing"
    }

    # --- Optional custom IPs
    $ipList = @()
    while ($true) {
        $ans = Read-Host "`nAdd custom IP to monitor? (Y/N)"
        if ($ans -match '^[Nn]') { break }
        $ip    = Read-Host "  IP address"
        $label = Read-Host "  Label"
        $ipList += [pscustomobject]@{ Label=$label ; IP=$ip }
    }

    # --- Write Config
    $lines = @()
    $lines += "GW=$gatewayIP"
    foreach ($n in $active) { $lines += "NIC=$($n.Name)" }
    foreach ($ci in $ipList) { $lines += "IP=$($ci.Label)`|$($ci.IP)" }

    $lines | Set-Content -Path $configPath -Encoding UTF8

    Write-Host ""
    Write-Host "[Setup] Saved. Re-run script to begin monitoring."
    exit
}

# ---------------------- Load Config ----------------------
$cfg = Get-Content $configPath
$gatewayIP = ($cfg | Where-Object { $_ -like 'GW=*' }) -replace '^GW=', ''
$monNics   = ($cfg | Where-Object { $_ -like 'NIC=*' }) -replace '^NIC=', ''
$custom    = foreach ($l in $cfg | Where-Object { $_ -like 'IP=*' }) {
    $parts = ($l.Substring(3)).Split('|',2)
    [pscustomobject]@{ Label=$parts[0] ; IP=$parts[1] }
}
$wanIP = '8.8.8.8'

# ---------------------- Check Status ----------------------
$ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
Write-Host ""
Write-Host "[$ts] Status:"

$nicResults = @()
foreach ($n in $monNics) {
    $a = Get-NetAdapter -Name $n
    $speed = $a.LinkSpeed -replace '\s+',' '
    if ($speed -notmatch '\d') { $speed = 'n/a' }
    Write-Host ("  {0,-14} -> {1} @ {2}" -f $n, $a.Status, $speed)
    $nicResults += [pscustomobject]@{ Name=$n ; Status=$a.Status }
}

$gatewayStatus = if (Test-Connection -Quiet -Count 2 $gatewayIP) { 'Up' } else { 'Down' }
$wanStatus     = if (Test-Connection -Quiet -Count 2 $wanIP)     { 'Up' } else { 'Down' }
Write-Host ("  {0,-14} -> {1} ({2})" -f 'Gateway', $gatewayStatus, $gatewayIP)
Write-Host ("  {0,-14} -> {1} ({2})" -f 'WAN',     $wanStatus,     $wanIP)

$customResults = @()
foreach ($ci in $custom) {
    $alive = Test-Connection -Quiet -Count 2 $ci.IP
    $st = if ($alive) { 'Up' } else { 'Down' }
    Write-Host ("  {0,-14} -> {1} ({2})" -f $ci.Label, $st, $ci.IP)
    $customResults += [pscustomobject]@{ Label=$ci.Label ; Status=$st }
}

# ---------------------- Notifications ----------------------
function Show-Alert ($title,$msg) {
    Add-Type -AssemblyName System.Windows.Forms
    $ni = New-Object Windows.Forms.NotifyIcon
    $ni.Icon = [System.Drawing.SystemIcons]::Information
    $ni.BalloonTipTitle = $title
    $ni.BalloonTipText  = $msg
    $ni.Visible = $true
    $ni.ShowBalloonTip(5000)
    Start-Sleep 5
    $ni.Dispose()
}
function Log-Event ($type,$msg) {
    $src = 'NICStatusMonitor'
    if (-not [Diagnostics.EventLog]::SourceExists($src)) {
        New-EventLog -LogName Application -Source $src
    }
    Write-EventLog -LogName Application -Source $src -EntryType $type -EventId 1000 -Message $msg
}

# ---------------------- Alerts ----------------------
$downNics = $nicResults    | Where-Object Status -ne 'Up'
$downIPs  = $customResults | Where-Object Status -eq 'Down'
$allNicsDown = ($nicResults.Count -gt 0) -and ($downNics.Count -eq $nicResults.Count)

$summary = @(
    ($nicResults    | ForEach-Object { "$($_.Name)=$($_.Status)" })
    "Gateway=$gatewayStatus"
    "WAN=$wanStatus"
    ($customResults | ForEach-Object { "$($_.Label)=$($_.Status)" })
) -join ', '

if ($allNicsDown -or ($gatewayStatus -eq 'Down' -and $wanStatus -eq 'Down')) {
    Start-Process powershell -ArgumentList '-WindowStyle Hidden -ExecutionPolicy Bypass -Command "& {Add-Type -AssemblyName System.Windows.Forms; $ni = New-Object Windows.Forms.NotifyIcon; $ni.Icon = [System.Drawing.SystemIcons]::Information; $ni.BalloonTipTitle = ''NIC Alert''; $ni.BalloonTipText = ''CRITICAL: All NICs or both external pings are down''; $ni.Visible = $true; $ni.ShowBalloonTip(5000); Start-Sleep 5; $ni.Dispose()}"'
    Log-Event 'Error'  "CRITICAL - $summary"
}
elseif ($downNics -or $downIPs -or $gatewayStatus -eq 'Down' -or $wanStatus -eq 'Down') {
    $items = @()
    $items += $downNics.Name
    if ($gatewayStatus -eq 'Down') { $items += 'Gateway' }
    if ($wanStatus     -eq 'Down') { $items += 'WAN'     }
    $items += $downIPs.Label
    $msg = 'Warning: ' + ($items -join ', ')
    
    Start-Process powershell -ArgumentList (
        '-WindowStyle Hidden -ExecutionPolicy Bypass -Command "& {' +
        'Add-Type -AssemblyName System.Windows.Forms; ' +
        '$ni = New-Object Windows.Forms.NotifyIcon; ' +
        '$ni.Icon = [System.Drawing.SystemIcons]::Warning; ' +
        '$ni.BalloonTipTitle = ''NIC Alert''; ' +
        '$ni.BalloonTipText = ''' + $msg + '''; ' +
        '$ni.Visible = $true; ' +
        '$ni.ShowBalloonTip(5000); ' +
        'Start-Sleep 5; ' +
        '$ni.Dispose(); }"'
    )

    Log-Event 'Warning' "$msg - $summary"
}
else {
    Log-Event 'Information' "OK - $summary"
}
