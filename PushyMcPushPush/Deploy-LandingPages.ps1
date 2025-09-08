# Check for Posh-SSH module and prompt for installation if missing
function Test-RequiredModule {
    $moduleName = "Posh-SSH"
    if (-not (Get-Module -ListAvailable -Name $moduleName)) {
        Write-Warning "The required module '$moduleName' is not installed."
        $install = Read-Host "Would you like to install it now? (yes/no)"
        if ($install.ToLower() -eq "yes") {
            try {
                Write-Host "Installing $moduleName..."
                Install-Module -Name $moduleName -Force -Scope CurrentUser -ErrorAction Stop
                Write-Host "$moduleName installed successfully."
            }
            catch {
                Write-Error "Failed to install $moduleName`: $($_.Exception.Message)"
                Write-Host "Please install $moduleName manually using 'Install-Module -Name Posh-SSH' in an elevated PowerShell session."
                exit 1
            }
        }
        else {
            Write-Error "The $moduleName module is required to run this script. Exiting."
            exit 1
        }
    }
    Import-Module -Name $moduleName
}

function Get-ServerList {
    $numServers = Read-Host "How many servers would you like to push to?"
    $numServers = [int]$numServers
    Write-Host "`nWould you like to:`n1. Provide a text file with FQDNs (ENTER delimited)`n2. Type in the server names"
    $choice = Read-Host "Enter 1 or 2"

    $servers = @()
    if ($choice -eq "1") {
        $filePath = Read-Host "Enter the path to the text file with FQDNs"
        if (-not (Test-Path $filePath)) {
            Write-Error "File not found. Exiting."
            exit 1
        }
        $servers = Get-Content $filePath | Where-Object { $_ -ne "" }
        if ($servers.Count -ne $numServers) {
            Write-Warning "File contains $($servers.Count) servers, but you specified $numServers."
        }
    }
    else {
        Write-Host "Enter the FQDNs (one per line, press ENTER after each, finish with an empty line):"
        while ($servers.Count -lt $numServers) {
            $fqdn = Read-Host
            if ($fqdn -eq "" -and $servers.Count -gt 0) {
                break
            }
            elseif ($fqdn -ne "") {
                $servers += $fqdn
            }
            else {
                Write-Host "Empty input not allowed as first entry. Please enter a valid FQDN."
            }
        }
        if ($servers.Count -ne $numServers) {
            Write-Warning "You entered $($servers.Count) servers, but specified $numServers."
        }
    }
    return $servers
}

function Get-Credentials {
    param ($Servers)
    $sameUsername = (Read-Host "Is the username the same for each server? (yes/no)").ToLower() -eq "yes"
    
    $usernames = @{}
    if ($sameUsername) {
        $username = Read-Host "Enter the username"
        foreach ($server in $Servers) {
            $usernames[$server] = $username
        }
    }
    else {
        foreach ($server in $Servers) {
            $usernames[$server] = Read-Host "Enter username for $server"
        }
    }

    $passwords = @{}
    foreach ($server in $Servers) {
        $securePassword = Read-Host "Enter password for $server" -AsSecureString
        $passwords[$server] = $securePassword
    }

    return $usernames, $passwords
}

function Get-Paths {
    param ($Servers)
    $localPath = Read-Host "Enter the path to the local working folder"
    if (-not (Test-Path $localPath)) {
        Write-Error "Local path does not exist. Exiting."
        exit 1
    }

    # Check for matching FQDN folders
    $missingFolders = @()
    foreach ($server in $Servers) {
        $serverFolder = Join-Path $localPath $server
        if (-not (Test-Path $serverFolder)) {
            $missingFolders += $server
        }
    }
    if ($missingFolders.Count -gt 0) {
        Write-Warning "The following server folders are missing in $localPath`:"
        foreach ($folder in $missingFolders) {
            Write-Host "  $folder"
        }
        $continue = Read-Host "Do you want to continue despite missing folders? (yes/no)"
        if ($continue.ToLower() -ne "yes") {
            Write-Host "Exiting due to missing folders."
            exit 1
        }
    }

    $targetPath = Read-Host "Enter the target path on the appliances"
    return $localPath, $targetPath
}

function Test-Connectivity {
    param ($Servers, $Usernames, $Passwords)
    $results = @{}
    foreach ($server in $Servers) {
        try {
            $cred = New-Object System.Management.Automation.PSCredential ($Usernames[$server], $Passwords[$server])
            $session = New-SSHSession -ComputerName $server -Credential $cred -ConnectionTimeout 5 -ErrorAction Stop
            $results[$server] = "Success"
            Remove-SSHSession -SessionId $session.SessionId | Out-Null
        }
        catch {
            $results[$server] = "Failed: $($_.Exception.Message)"
        }
    }
    return $results
}

function Show-Summary {
    param ($Servers, $Usernames, $LocalPath, $TargetPath, $ConnectivityResults)
    Write-Host "`n=== Deployment Summary ==="
    Write-Host "Servers: $($Servers -join ', ')"
    Write-Host "Usernames:"
    foreach ($server in $Servers) {
        Write-Host "  $server`: $($Usernames[$server])"
    }
    Write-Host "Local working folder: $LocalPath"
    Write-Host "Target path on appliances: $TargetPath"
    Write-Host "Connectivity test results:"
    foreach ($server in $Servers) {
        Write-Host "  $server`: $($ConnectivityResults[$server])"
    }
    $proceed = Read-Host "`nDo you want to proceed with the deployment? (yes/no)"
    return $proceed.ToLower() -eq "yes"
}

function Push-Files {
    param ($Servers, $Usernames, $Passwords, $LocalPath, $TargetPath)
    $results = @{}
    foreach ($server in $Servers) {
        try {
            $cred = New-Object System.Management.Automation.PSCredential ($Usernames[$server], $Passwords[$server])
            $session = New-SSHSession -ComputerName $server -Credential $cred -ErrorAction Stop
            $sftp = New-SFTPSession -ComputerName $server -Credential $cred -ErrorAction Stop

            $serverFolder = Join-Path $LocalPath $server
            if (-not (Test-Path $serverFolder)) {
                $results[$server] = "Failed: Local folder $serverFolder does not exist"
                continue
            }

            # Ensure target directory exists
            try {
                Get-SFTPPath -SFTPSession $sftp -Path $TargetPath -ErrorAction Stop | Out-Null
            }
            catch {
                New-SFTPItem -SFTPSession $sftp -Path $TargetPath -ItemType Directory -ErrorAction Stop
            }

            # Push files
            $files = Get-ChildItem -Path $serverFolder -Recurse -File
            foreach ($file in $files) {
                $relPath = $file.FullName.Substring($serverFolder.Length).TrimStart('\', '/')
                $remotePath = ($TargetPath + '/' + $relPath).Replace('\', '/')
                $remoteDir = Split-Path $remotePath -Parent

                # Create remote directory if it doesn't exist
                try {
                    Get-SFTPPath -SFTPSession $sftp -Path $remoteDir -ErrorAction Stop | Out-Null
                }
                catch {
                    New-SFTPItem -SFTPSession $sftp -Path $remoteDir -ItemType Directory -ErrorAction Stop
                }

                Set-SFTPItem -SFTPSession $sftp -Path $remotePath -Source $file.FullName -ErrorAction Stop
            }

            $results[$server] = "Success"
            Remove-SFTPSession -SFTPSession $sftp | Out-Null
            Remove-SSHSession -SessionId $session.SessionId | Out-Null
        }
        catch {
            $results[$server] = "Failed: $($_.Exception.Message)"
        }
    }
    return $results
}

function Show-Results {
    param ($Results)
    Write-Host "`n=== Deployment Results ==="
    foreach ($server in $Results.Keys) {
        Write-Host "$server`: $($Results[$server])"
    }
}

function Main {
    # Check and install required module
    Test-RequiredModule

    $servers = $null
    $usernames = $null
    $passwords = $null
    $localPath = $null
    $targetPath = $null

    while ($true) {
        Write-Host "`n=== Landing Page Deployment Script ==="
        if ($servers) {
            Write-Host "1. Deploy with existing server list and credentials"
            Write-Host "2. Start new deployment"
            Write-Host "3. Exit"
            $choice = Read-Host "Enter your choice (1-3)"
        }
        else {
            $choice = "2"
        }

        if ($choice -eq "1" -and $servers) {
            if (-not (Show-Summary -Servers $servers -Usernames $usernames -LocalPath $localPath -TargetPath $targetPath -ConnectivityResults (Test-Connectivity -Servers $servers -Usernames $usernames -Passwords $passwords))) {
                continue
            }
            $results = Push-Files -Servers $servers -Usernames $usernames -Passwords $passwords -LocalPath $localPath -TargetPath $targetPath
            Show-Results -Results $results
        }
        elseif ($choice -eq "2") {
            $servers = Get-ServerList
            $usernames, $passwords = Get-Credentials -Servers $servers
            $localPath, $targetPath = Get-Paths -Servers $servers
            $connectivityResults = Test-Connectivity -Servers $servers -Usernames $usernames -Passwords $passwords
            if (-not (Show-Summary -Servers $servers -Usernames $usernames -LocalPath $localPath -TargetPath $targetPath -ConnectivityResults $connectivityResults)) {
                continue
            }
            $results = Push-Files -Servers $servers -Usernames $usernames -Passwords $passwords -LocalPath $localPath -TargetPath $targetPath
            Show-Results -Results $results
        }
        elseif ($choice -eq "3") {
            break
        }
        else {
            Write-Host "Invalid choice. Please try again."
        }
    }
}

Main