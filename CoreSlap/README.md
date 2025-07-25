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

### Version 1.3 (July 25, 2025)
- **Added AMD X3D CPU Support**:
  - Detects AMD X3D CPUs (e.g., 7950X3D, 7900X3D, 7800X3D, 9800X3D, 9950X3D).
  - Identifies dual-CCD X3D CPUs and their core configurations (V-Cache CCD0 and non-V-Cache CCD1).
  - New advanced menu option ('P') to prioritize either V-Cache CCD (for gaming) or non-V-Cache CCD (for compute tasks) by adjusting core parking.
  - Displays X3D CPU status and core assignments in the main menu.
- **Enhanced Documentation**:
  - Updated script header to reflect version 1.3 and X3D enhancements.
  - Improved clarity in X3D-related prompts and messages.