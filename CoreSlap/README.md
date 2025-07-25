# CoreSlap PowerShell Utility

The CoreSlap.ps1 PowerShell script is a utility for managing **CPU core parking**, **Xbox Game Bar**, and **device connect/disconnect sounds** on Windows. Here's a concise breakdown:

1. **Core Parking Management**:

  - Checks CPU core parking status (enabled/disabled, percentage of active cores).

  - Toggles core parking between 10% (aggressive parking) and 100% (disabled) or sets custom percentages (0-100%) via an advanced menu.

  - Displays live core parking stats (active vs. parked cores) every 5 seconds.

2. **Xbox Game Bar**:

  - Checks if Xbox Game Bar is installed.

  - Allows uninstalling Game Bar or opening the Microsoft Store to reinstall it.

3. **Device Sounds**:

  - Mutes all device connect/disconnect sounds (e.g., USB, audio jacks).

  - Restores default device sounds.

4. **Features**:

  - Interactive menu with options to toggle settings, view live stats, or access advanced controls.

  - Uses powercfg for core parking, Windows registry for sounds, and Get-AppxPackage for Game Bar.

**Usage**: Run in PowerShell. Choose options (1, 2, A, X) to manage settings. Requires admin privileges for some actions (e.g., powercfg, registry changes).

## Changelog

### Version 1.4.4 (July 25, 2025)
- **Bug Fix**:
  - Fixed issue where selecting 'X' in the main menu did not exit the script. Replaced `break` with `Exit` in the main loop to ensure the PowerShell session terminates.
- **File Rename**:
  - Renamed script to `CoreSlap1.4.4.ps1` to reflect version number.
- **Updated Documentation**:
  - Updated script header to reflect version 1.4.4.

### Version 1.4.3 (July 25, 2025)
- **Enhanced X3D Core Parking Menu**:
  - Added display of parking status for each CCD (V-Cache CCD0 and non-V-Cache CCD1) in the X3D core parking menu, showing whether each is "Parked" or "Active".
  - Added option '3' to "Enable all CCDs (Disable Parking)," which sets core parking to 100% to ensure all cores are active.
- **File Rename**:
  - Renamed script to `CoreSlap1.4.3.ps1` to reflect version number.
- **Updated Documentation**:
  - Updated script header to reflect version 1.4.3.

### Version 1.4.1 (July 25, 2025)
- **Added Startup Message**:
  - Displays "Gathering system information, please wait..." at script launch to inform users during initial system checks.
- **File Rename**:
  - Renamed script to `CoreSlap1.4.1.ps1` to reflect version number.
- **Updated Documentation**:
  - Updated script header to reflect version 1.4.1.

### Version 1.4.1a (July 25, 2025)
- **Bug Fix**:
  - Fixed error in `Get-X3DCCDStatus` function where core index parsing failed due to incorrect regex for performance counter paths (e.g., `processor information(0,0)`). Updated to correctly handle `(processor,core)` format and skip invalid entries like `_total`.
- **Updated Documentation**:
  - Updated script header to reflect version 1.5.

### Version 1.4 (July 25, 2025)
- **Enhanced Core Parking Status Display**:
  - Added display of current CCD prioritization status for AMD X3D dual-CCD CPUs (e.g., V-Cache CCD0 or non-V-Cache CCD1 prioritized, or both active).
  - Main menu now shows detailed core parking status, including percentage and CCD prioritization (if applicable).
- **Improved Status Reporting**:
  - New function to detect and report which CCD is active based on core utilization for X3D CPUs.
- **Updated Documentation**:
  - Updated script header to reflect version 1.4.
  - Improved clarity in status reporting for core parking and CCD prioritization.

### Version 1.3 (July 25, 2025)
- **Added AMD X3D CPU Support**:
  - Detects AMD X3D CPUs (e.g., 7950X3D, 7900X3D, 7800X3D, 9800X3D, 9950X3D).
  - Identifies dual-CCD X3D CPUs and their core configurations (V-Cache CCD0 and non-V-Cache CCD1).
  - New advanced menu option ('P') to prioritize either V-Cache CCD (for gaming) or non-V-Cache CCD (for compute tasks) by adjusting core parking.
  - Displays X3D CPU status and core assignments in the main menu.
- **Enhanced Documentation**:
  - Updated script header to reflect version 1.3 and X3D enhancements.
  - Improved clarity in X3D-related prompts and messages.