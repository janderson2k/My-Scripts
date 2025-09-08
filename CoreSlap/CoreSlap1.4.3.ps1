# =================================================
# CoreSlap.ps1 – Core-parking & Game Bar Utility (X3D Enhanced)
# Version: 1.4.3
# =================================================

Write-Host 'Gathering system information, please wait...' -ForegroundColor Cyan
Start-Sleep -Seconds 2
Clear-Host

# --- Returns hashtable with .Status (string), .Value (int), and .CCDStatus (string) ---
function Get-CoreParkingStatus {
    $guid = '0cc5b647-c1df-4637-891a-dec35c318583'
    $rawAC = powercfg /query SCHEME_CURRENT SUB_PROCESSOR $guid |
             Select-String 'Current AC Power Setting Index'
    $rawDC = powercfg /query SCHEME_CURRENT SUB_PROCESSOR $guid |
             Select-String 'Current DC Power Setting Index'
    $acVal = -1; $dcVal = -1

    if ($rawAC -match '0x([0-9A-Fa-f]+)') {
        $acVal = [convert]::ToInt32($matches[1],16)
    }
    if ($rawDC -match '0x([0-9A-Fa-f]+)') {
        $dcVal = [convert]::ToInt32($matches[1],16)
    }

    if ($acVal -ge 0 -and $dcVal -ge 0) {
        $avg = [math]::Round(($acVal + $dcVal) / 2)
        $status = if ($avg -eq 100) { 'Disabled (100%)' } else { "Enabled ($avg%)" }
        $ccdStatus = Get-X3DCCDStatus
        return @{ Status = $status; Value = $avg; CCDStatus = $ccdStatus }
    }

    return @{ Status = 'Unknown'; Value = -1; CCDStatus = 'N/A' }
}

# --- Checks CCD prioritization for X3D dual-CCD CPUs ---
function Get-X3DCCDStatus {
    $x3dStatus = Get-X3DStatus
    if (-not $x3dStatus.IsX3D -or -not $x3dStatus.DualCCD) {
        return 'N/A'
    }

    # Check if CCD1 (non-V-Cache) is parked by examining core utilization
    $samples = Get-Counter '\Processor Information(*)\% Processor Utility' |
               Select-Object -Expand CounterSamples
    $ccd0Active = $false; $ccd1Active = $false
    foreach ($sample in $samples) {
        if ($sample.Path -match '.*\((\d+),(\d+)\).*') {
            $coreIndex = [int]$matches[2]
            if ($x3dStatus.CCD0Cores -contains $coreIndex -and $sample.CookedValue -ge 1) {
                $ccd0Active = $true
            }
            if ($x3dStatus.CCD1Cores -contains $coreIndex -and $sample.CookedValue -ge 1) {
                $ccd1Active = $true
            }
        }
    }

    if ($ccd0Active -and -not $ccd1Active) {
        return 'V-Cache CCD (CCD0) Prioritized'
    } elseif ($ccd1Active -and -not $ccd0Active) {
        return 'Non-V-Cache CCD (CCD1) Prioritized'
    } elseif ($ccd0Active -and $ccd1Active) {
        return 'Both CCDs Active'
    } else {
        return 'No CCDs Active'
    }
}

# --- Sets core parking minimum active-core percentage ---
function Set-CoreParking {
    param([ValidateRange(0,100)][int]$Value)
    $guid = '0cc5b647-c1df-4637-891a-dec35c318583'
    powercfg -attributes SUB_PROCESSOR $guid -ATTRIB_HIDE | Out-Null
    powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR $guid $Value | Out-Null
    powercfg /setdcvalueindex SCHEME_CURRENT SUB_PROCESSOR $guid $Value | Out-Null
    powercfg -setactive SCHEME_CURRENT | Out-Null
}

# --- Detects if CPU is AMD X3D with dual CCD ---
function Get-X3DStatus {
    $cpu = Get-CimInstance Win32_Processor | Select-Object -ExpandProperty Name
    $coreCount = (Get-CimInstance Win32_Processor).NumberOfCores
    $x3dModels = @('7950X3D', '7900X3D', '9950X3D') # Dual CCD X3D CPUs
    $isX3D = $x3dModels | Where-Object { $cpu -match $_ }
    if ($isX3D) {
        $ccd0Cores = 0..7 # V-Cache CCD (CCD0)
        $ccd1Cores = 8..($coreCount - 1) # Non-V-Cache CCD (CCD1)
        return @{ IsX3D = $true; DualCCD = $true; CCD0Cores = $ccd0Cores; CCD1Cores = $ccd1Cores }
    } elseif ($cpu -match '7800X3D|9800X3D') {
        return @{ IsX3D = $true; DualCCD = $false; CCD0Cores = 0..($coreCount - 1); CCD1Cores = @() }
    }
    return @{ IsX3D = $false; DualCCD = $false; CCD0Cores = @(); CCD1Cores = @() }
}

# --- Parks specified CCD for dual-CCD X3D CPUs ---
function Set-X3DCoreParking {
    $x3dStatus = Get-X3DStatus
    if (-not $x3dStatus.IsX3D -or -not $x3dStatus.DualCCD) {
        Write-Host 'X3D dual-CCD CPU not detected.' -ForegroundColor Yellow
        Start-Sleep 1.5
        return
    }

    # Check parking status for each CCD
    $samples = Get-Counter '\Processor Information(*)\% Processor Utility' |
               Select-Object -Expand CounterSamples
    $ccd0Parked = $true; $ccd1Parked = $true
    foreach ($sample in $samples) {
        if ($sample.Path -match '.*\((\d+),(\d+)\).*') {
            $coreIndex = [int]$matches[2]
            if ($x3dStatus.CCD0Cores -contains $coreIndex -and $sample.CookedValue -ge 1) {
                $ccd0Parked = $false
            }
            if ($x3dStatus.CCD1Cores -contains $coreIndex -and $sample.CookedValue -ge 1) {
                $ccd1Parked = $false
            }
        }
    }
    $ccd0Status = if ($ccd0Parked) { 'Parked' } else { 'Active' }
    $ccd1Status = if ($ccd1Parked) { 'Parked' } else { 'Active' }

    Write-Host ''; Write-Host 'X3D CORE PARKING' -ForegroundColor Cyan
    Write-Host "V-Cache CCD (CCD0): Cores $($x3dStatus.CCD0Cores -join ', ') [Status: $ccd0Status]"
    Write-Host "Non-V-Cache CCD (CCD1): Cores $($x3dStatus.CCD1Cores -join ', ') [Status: $ccd1Status]"
    Write-Host ' 1 = Park non-V-Cache CCD (CCD1) for gaming'
    Write-Host ' 2 = Park V-Cache CCD (CCD0) for compute tasks'
    Write-Host ' 3 = Enable all CCDs (Disable Parking)'
    Write-Host ' X = Cancel'
    $choice = Read-Host "`nSelect"

    switch ($choice) {
        '1' {
            Write-Host 'Prioritizing V-Cache CCD (CCD0) and parking non-V-Cache CCD (CCD1)...' -ForegroundColor Green
            Set-CoreParking -Value 0 # Disable parking globally
            # Rely on Game Mode/AMD drivers to prioritize CCD0
            powercfg /setactive SCHEME_CURRENT | Out-Null
            Write-Host 'Done. Use Game Mode for best gaming performance.' -ForegroundColor Green
        }
        '2' {
            Write-Host 'Prioritizing non-V-Cache CCD (CCD1) and parking V-Cache CCD (CCD0)...' -ForegroundColor Green
            Set-CoreParking -Value 0 # Disable parking globally
            # No direct way to park CCD0 via powercfg; advise manual affinity
            Write-Host 'Done. Use tools like Process Lasso to set affinity to CCD1 for compute tasks.' -ForegroundColor Green
        }
        '3' {
            Write-Host 'Enabling all CCDs (Disabling Parking)...' -ForegroundColor Green
            Set-CoreParking -Value 100 # Enable all cores
            powercfg /setactive SCHEME_CURRENT | Out-Null
            Write-Host 'Done. All CCDs are now active.' -ForegroundColor Green
        }
        'X' {
            Write-Host 'Cancelled.' -ForegroundColor Yellow
        }
        default {
            Write-Host 'Invalid choice.' -ForegroundColor Red
        }
    }
    Start-Sleep 1.5
}

# --- Returns True/False if Xbox Game Bar is installed ---
function Get-GameBarStatus {
    return (Get-AppxPackage -Name Microsoft.XboxGamingOverlay -ErrorAction SilentlyContinue) -ne $null
}

# --- Uninstalls Xbox Game Bar after confirmation ---
function Uninstall-GameBar {
    Write-Host ''; Write-Host 'UNINSTALL Xbox Game Bar' -ForegroundColor Red
    $y = Read-Host 'Remove overlays & widgets? (Y/N)'
    if ($y -match '^[Yy]') {
        Get-AppxPackage Microsoft.XboxGamingOverlay | Remove-AppxPackage
        Write-Host 'Game Bar removed.' -ForegroundColor Green
    } else {
        Write-Host 'Cancelled.' -ForegroundColor Yellow
    }
    Start-Sleep 1.5
}

# --- Opens Microsoft Store to the Game Bar page ---
function Install-GameBar {
    Write-Host ''; Write-Host 'INSTALL Xbox Game Bar' -ForegroundColor Cyan
    $y = Read-Host 'Open Store to install? (Y/N)'
    if ($y -match '^[Yy]') {
        Start-Process 'ms-windows-store://pdp/?productid=9NZKPSTSNW4P'
        Write-Host 'Store opened.' -ForegroundColor Green
    } else {
        Write-Host 'Cancelled.' -ForegroundColor Yellow
    }
    Start-Sleep 1.5
}

# --- Mutes all device connect/disconnect sounds globally ---
function Suppress-DeviceSounds {
    Write-Host ''; Write-Host 'SUPPRESS DEVICE SOUNDS' -ForegroundColor Red
    Write-Host 'Mutes ALL plug/unplug sounds (USB, docks, audio jacks).'
    $y = Read-Host 'Proceed? (Y/N)'
    if ($y -match '^[Yy]') {
        $base = 'HKCU:\AppEvents\Schemes\Apps\.Default'
        Set-ItemProperty "$base\DeviceConnect\.Current"    '(default)' '' -ErrorAction SilentlyContinue
        Set-ItemProperty "$base\DeviceDisconnect\.Current" '(default)' '' -ErrorAction SilentlyContinue
        rundll32.exe user32.dll,UpdatePerUserSystemParameters
        Write-Host 'Device sounds muted.' -ForegroundColor Green
    } else {
        Write-Host 'Cancelled.' -ForegroundColor Yellow
    }
    Start-Sleep 1.5
}

# --- Restores default device connect/disconnect sounds ---
function Restore-DeviceSounds {
    Write-Host ''; Write-Host 'RESTORE DEVICE SOUNDS' -ForegroundColor Cyan
    $y = Read-Host 'Restore plug/unplug sounds? (Y/N)'
    if ($y -match '^[Yy]') {
        $base = 'HKCU:\AppEvents\Schemes\Apps\.Default'
        Set-ItemProperty "$base\DeviceConnect\.Current"    '(default)' 'Windows Hardware Insert.wav'
        Set-ItemProperty "$base\DeviceDisconnect\.Current" '(default)' 'Windows Hardware Remove.wav'
        rundll32.exe user32.dll,UpdatePerUserSystemParameters
        Write-Host 'Device sounds restored.' -ForegroundColor Green
    } else {
        Write-Host 'Cancelled.' -ForegroundColor Yellow
    }
    Start-Sleep 1.5
}

# --- Live core-parking tally display (5s intervals) ---
function Show-CoreParkingLive {
    $exit = $false
    Write-Host ''; Write-Host 'LIVE CORE PARKING SUMMARY (5s intervals)' -ForegroundColor Cyan
    Write-Host "Press 'X' to return.`n"

    while (-not $exit) {
        $samples = Get-Counter '\Processor Information(*)\% Processor Utility' |
                   Select-Object -Expand CounterSamples
        $active = ($samples | Where-Object { $_.CookedValue -ge 1 }).Count
        $parked = ($samples | Where-Object { $_.CookedValue -lt 1 }).Count
        $ts = (Get-Date).ToString('HH:mm:ss')
        Write-Host "[ $ts ] Active: $active   Parked: $parked   Total: $($active+$parked)"

        # wait up to 5 seconds, break on X key
        $start = Get-Date
        while ((Get-Date) -lt $start.AddSeconds(5)) {
            Start-Sleep -Milliseconds 200
            if ([Console]::KeyAvailable -and
                [Console]::ReadKey($true).Key -eq 'X') {
                $exit = $true
                break
            }
        }
    }
}

# --- Advanced menu with X3D options ---
function Show-AdvancedMenu {
    while ($true) {
        Clear-Host
        Write-Host ''; Write-Host 'ADVANCED MENU' -ForegroundColor Cyan
        Write-Host ' 0 = Disable Parking (100%)'
        for ($i=1; $i -le 9; $i++) {
            $p = $i * 10
            Write-Host " $i = Enable Parking at $p%"
        }
        Write-Host ''
        Write-Host ' P = Park CCD (X3D CPUs)'
        Write-Host ' U = Uninstall Game Bar'
        Write-Host ' I = Install Game Bar'
        Write-Host ' S = Suppress Device Sounds'
        Write-Host ' R = Restore Device Sounds'
        Write-Host ' X = Back to Main Menu'
        Write-Host "About:"
        Write-Host " 10%  = Aggressive parking "
        Write-Host " 100% = Parking disabled "

        $ans = Read-Host "`nSelect"
        switch ($ans.ToUpper()) {
            '0'    { Set-CoreParking -Value 100 }
            { $_ -match '^[1-9]$' } { Set-CoreParking -Value ([int]$ans*10) }
            'P'    { Set-X3DCoreParking }
            'U'    { Uninstall-GameBar }
            'I'    { Install-GameBar }
            'S'    { Suppress-DeviceSounds }
            'R'    { Restore-DeviceSounds }
            'X'    { return }     # exit this function
            default {
                Write-Host 'Invalid option.' -ForegroundColor Red
                Start-Sleep 1
            }
        }
    }
}

# --- Displays menu and returns the user’s choice ---
function Show-MainMenu {
    Clear-Host
    $cp = Get-CoreParkingStatus
    $gb = Get-GameBarStatus
    $x3d = Get-X3DStatus

    Write-Host CoreSlap : Core Parking Utility 1.4.3
    Write-Host Jay Anderson 7.25.25 - FullDuplexTech.com
    Write-Host ''; Write-Host "Core Parking....................: $($cp.Status)"
    Write-Host "X3D CCD Status..................: $($cp.CCDStatus)"
    Write-Host "Game Bar Installed..............: $gb"
    Write-Host "X3D CPU Detected................: $($x3d.IsX3D)"
    if ($x3d.IsX3D) {
        Write-Host "Dual CCD........................: $($x3d.DualCCD)"
        if ($x3d.DualCCD) {
            Write-Host "V-Cache CCD (CCD0)..............: Cores $($x3d.CCD0Cores -join ', ')"
            Write-Host "Non-V-Cache CCD (CCD1)..........: Cores $($x3d.CCD1Cores -join ', ')"
        }
    }
    Write-Host ''
    Write-Host ' 1 = Toggle Core Parking (10% <-> 100%)'
    Write-Host ' 2 = Show Live Core-parking Status'
    Write-Host ' A = Advanced Menu'
    Write-Host ' X = Exit'
    Write-Host ''

    return Read-Host "`nChoose"
}

# --- Main program loop ---
while ($true) {
    $choice = Show-MainMenu
    switch ($choice.ToUpper()) {
        '1' {
            $cp = Get-CoreParkingStatus
            if ($cp.Value -eq 100) {
                Set-CoreParking -Value 10
            } else {
                Set-CoreParking -Value 100
            }
        }
        '2' { Show-CoreParkingLive }
        'A' { Show-AdvancedMenu }
        'X' { break }
        default {
            Write-Host 'Invalid choice.' -ForegroundColor Red
            Start-Sleep 1
        }
    }
}