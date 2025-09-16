# Define the device name
$deviceName = "AKiTiO 10Gbit Network Adapter"

# Get the device instance ID using WMI
$device = Get-PnpDevice | Where-Object { $_.FriendlyName -eq $deviceName }

if ($device) {
    $instanceId = $device.InstanceId
    Write-Host "Found device: $instanceId"

    # Disable the device
    Write-Host "Disabling device..."
    pnputil /disable-device "$instanceId"
    Start-Sleep -Seconds 3

    # Re-enable the device
    Write-Host "Re-enabling device..."
    pnputil /enable-device "$instanceId"
} else {
    Write-Host "Device not found: $deviceName"
}
