# CPU Monitoring & Auto-Restart Service Script

## Overview
This PowerShell script monitors the CPU usage of a specific process and automatically restarts the associated service if CPU consumption exceeds a defined threshold. It also logs events and manages log rotation.

## Features
- Monitors CPU usage of a specified process
- Restarts the associated service if CPU usage exceeds a threshold
- Logs events including status changes, CPU usage, and errors
- Rotates log files to prevent excessive growth
- Runs continuously with configurable check intervals

## Requirements
- Windows OS
- PowerShell 5.1 or later
- Administrative privileges (required for service restart)

## Configuration
Modify the following parameters at the beginning of the script to fit your needs:

```powershell
$threshold         = 70                # CPU usage threshold (%)
$processName       = "Example_Process"      # Target process name (Example)
$serviceName       = "Example_Service"      # Service to restart (Example)
$logFile           = "C:\Example\Logs\ServiceRestart.log" # Log file path (Example)
$checkInterval     = 5                 # Check interval (seconds)
$doubleCheckDelay  = 10                # Delay before rechecking (seconds)
$maxLogSize        = 10MB              # Max log file size
```

## Installation
1. Save the script as `MonitorService.ps1`.
2. Ensure PowerShell execution policy allows script execution:
   ```powershell
   Set-ExecutionPolicy Unrestricted -Scope Process
   ```
3. Run the script with administrative privileges:
   ```powershell
   .\MonitorService.ps1
   ```

## Logging
- Logs are stored in the specified log file (`$logFile`).
- If the log file exceeds `$maxLogSize`, it will be renamed and a new log file will be created.

## How It Works
1. The script continuously checks if the target process is running.
2. If running, it retrieves the current CPU usage.
3. If CPU usage exceeds `$threshold`, it waits `$doubleCheckDelay` seconds and checks again.
4. If high CPU usage persists, it restarts the associated service (`$serviceName`).
5. All events are logged.

## Error Handling
- If the process is not found, an error is logged.
- If CPU usage cannot be retrieved, an error is logged.
- If an unexpected error occurs, the script logs the error and terminates.

## License
This script is provided "as is" without warranty. Use at your own risk.

## Author
[Your Name]

