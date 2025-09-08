This PowerShell script, `NetworkStatus2.ps1` (version 3.4), monitors network interface cards (NICs) and network connectivity, logging status and sending notifications when issues are detected. Here's a breakdown of what it does:

---

 ::::1. Purpose::::
The script monitors:
- The status of specified network adapters (NICs).
- Connectivity to a local gateway IP.
- Connectivity to an external IP (Google's DNS, `8.8.8.8`).
- Optional user-specified IPs (e.g., servers or devices).
It generates alerts (system tray notifications) and logs events to the Windows Event Log when issues (e.g., NICs or IPs being down) are detected.

---

 ::::2. Key Components::::

 ::::A. First-Time Setup::::
If no configuration file (`NicStatusConfig.txt`) exists:
- ::::Detects active NICs::::: Lists NICs with "Up" status using `Get-NetAdapter`.
- ::::Prompts for verification::::: Asks the user to confirm NICs are connected.
- ::::Auto-detects gateway::::: Retrieves the default gateway IP using `Get-NetIPConfiguration`. The user can accept it or specify a custom IP.
- ::::Custom IPs::::: Allows the user to add optional IPs to monitor (e.g., internal servers) with labels.
- ::::Saves config::::: Writes the gateway IP, NIC names, and custom IPs to `NicStatusConfig.txt`.

Example config file content:
```
GW=192.168.1.1
NIC=Ethernet
NIC=Wi-Fi
IP=Server1|10.0.0.5
IP=Server2|10.0.0.6
```

 ::::B. Load Configuration::::
- Reads `NicStatusConfig.txt` to load:
  - Gateway IP (`GW=`).
  - NIC names to monitor (`NIC=`).
  - Custom IPs and labels (`IP=`).
- Sets a hardcoded WAN IP (`8.8.8.8`) for external connectivity testing.

 ::::C. Check Status::::
- ::::NIC Status::::: Checks the status and link speed of each monitored NIC using `Get-NetAdapter`.
- ::::Gateway Connectivity::::: Pings the gateway IP to check local network connectivity.
- ::::WAN Connectivity::::: Pings `8.8.8.8` to check internet connectivity.
- ::::Custom IPs::::: Pings each user-specified IP to check its status.
- Outputs the status of all components to the console with a timestamp.

Example output:
```
[2025-07-25 06:52:00] Status:
  Ethernet       -> Up @ 1 Gbps
  Wi-Fi          -> Up @ 300 Mbps
  Gateway        -> Up (192.168.1.1)
  WAN            -> Up (8.8.8.8)
  Server1        -> Up (10.0.0.5)
  Server2        -> Down (10.0.0.6)
```

 ::::D. Notifications::::
- ::::System Tray Alerts::::: Uses `System.Windows.Forms.NotifyIcon` to display balloon tip notifications in the system tray.
- ::::Event Logging::::: Logs events to the Windows Event Log under the source `NICStatusMonitor` (creates the source if it doesn’t exist).

 ::::E. Alert Logic::::
- ::::Critical Alert::::: Triggered if:
  - All monitored NICs are down, ::::or::::
  - Both the gateway and WAN pings fail.
  - Displays a system tray alert with "CRITICAL: All NICs or both external pings are down" and logs an `Error` event.
- ::::Warning Alert::::: Triggered if:
  - Any NIC is not "Up," ::::or::::
  - Any custom IP, gateway, or WAN ping fails.
  - Displays a system tray alert listing the failed components (e.g., "Warning: Ethernet, Server2") and logs a `Warning` event.
- ::::Normal Operation::::: If all checks pass, logs an `Information` event with the status summary.

---

 ::::3. Key Functions::::
- ::::Show-Alert::::: Displays a system tray notification with a specified title and message.
- ::::Log-Event::::: Writes an event to the Windows Event Log with the specified type (`Error`, `Warning`, or `Information`).

---

 ::::4. Usage::::
- ::::First Run::::: The script prompts for setup and creates the config file. It exits after saving.
- ::::Subsequent Runs::::: Loads the config, checks NICs and IPs, displays status, and sends alerts/logs as needed.
- ::::Requirements::::: Must run on a Windows system with PowerShell and network access. Requires administrative privileges to create the Event Log source.
