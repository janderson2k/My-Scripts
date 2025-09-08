# SLock 3.1.2

SLock is a Windows batch script designed to keep your computer awake for a specified number of hours. It simulates user activity at regular intervals to prevent the system from sleeping or locking. This is useful for long-running tasks, downloads, or presentations.

## Features

- Keeps the system awake for a user-defined duration
- Displays progress and estimated exit time
- Logs start and end times to a log file
- Simulates keyboard activity every 10 minutes
- Provides a tray notification upon completion

## Usage

1. Run the batch script.
2. Enter the number of hours to keep the system awake.
3. The script will simulate activity every 10 minutes.
4. A notification will appear when the duration is complete.

## Script Breakdown

- **Initialization**: Sets up environment variables, deletes old counters, and captures login time.
- **User Input**: Prompts for the number of hours to run.
- **Duration Calculation**: Converts hours to cycles and minutes.
- **Exit Time Calculation**: Computes the estimated time the script will finish.
- **Logging**: Logs the start time to `SLock_Log.txt`.
- **Main Loop**:
  - Updates progress and remaining time.
  - Displays a progress bar.
  - Waits for 10 minutes using `TIMEOUT`.
  - Simulates a key press using VBScript.
- **Completion**:
  - Logs the end time.
  - Displays a Windows tray notification using PowerShell.

## Requirements

- Windows OS
- Administrator privileges may be required for some features

## License

This script is provided by TheLatencyLounge.com. Use at your own discretion.

## Author

Jason - TheLatencyLounge.com
