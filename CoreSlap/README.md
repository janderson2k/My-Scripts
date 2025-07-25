The `CoreSlap.ps1` PowerShell script is a utility for managing \*\*CPU core parking\*\*, \*\*Xbox Game Bar\*\*, and \*\*device connect/disconnect sounds\*\* on Windows. Here's a concise breakdown:



1\. \*\*Core Parking Management\*\*:

&nbsp;  - Checks CPU core parking status (enabled/disabled, percentage of active cores).

&nbsp;  - Toggles core parking between 10% (aggressive parking) and 100% (disabled) or sets custom percentages (0-100%) via an advanced menu.

&nbsp;  - Displays live core parking stats (active vs. parked cores) every 5 seconds.



2\. \*\*Xbox Game Bar\*\*:

&nbsp;  - Checks if Xbox Game Bar is installed.

&nbsp;  - Allows uninstalling Game Bar or opening the Microsoft Store to reinstall it.



3\. \*\*Device Sounds\*\*:

&nbsp;  - Mutes all device connect/disconnect sounds (e.g., USB, audio jacks).

&nbsp;  - Restores default device sounds.



4\. \*\*Features\*\*:

&nbsp;  - Interactive menu with options to toggle settings, view live stats, or access advanced controls.

&nbsp;  - Uses `powercfg` for core parking, Windows registry for sounds, and `Get-AppxPackage` for Game Bar.



\*\*Usage\*\*: Run in PowerShell. Choose options (1, 2, A, X) to manage settings. Requires admin privileges for some actions (e.g., `powercfg`, registry changes).



Let me know if you need help running it or adding it to your Git repo!

