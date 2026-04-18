🔇 Reduce-FanNoise-AllInOne.ps1

A PowerShell utility designed to quickly reduce system fan noise by lowering CPU/GPU load, adjusting power settings, and stopping resource-heavy processes.

⚠️ Requires Administrator privileges

🚀 What This Script Does

This script applies several system-level optimizations to reduce heat and fan activity:

⚙️ Power & CPU Management
Detects current active power plan
Reduces Maximum Processor State (AC) to 50%
Limits turbo boost → lowers heat → quieter fans
Automatically restores original settings via generated script
💡 Display Adjustment
Attempts to set display brightness to 30% (if supported via WMI)
🧠 Process Optimization

Stops common high-CPU processes (configurable):

chrome, msedge, firefox, HandBrake, Prime95, transcode, rtss64, msmpeng

You can edit this list inside the script.

🎮 GPU Power Limiting (NVIDIA Only)
Uses nvidia-smi (if installed)
Reduces GPU power limit to ~80% of current value
Ensures it does not drop below 30W
Saves original values for restoration
🧾 Logging & Restore
Creates:
📄 Log file
♻️ Restore script

Stored in:

%TEMP%
📁 Output Files
File	Description
ReduceFanNoise_Log_*.txt	Full execution log
Restore-FanNoise-Settings_*.ps1	Script to revert all changes
▶️ Usage
1. Run Script
Right-click → Run as Administrator

Or via terminal:

powershell -ExecutionPolicy Bypass -File .\Reduce-FanNoise-AllInOne.ps1
2. Restore Original Settings

Run the generated restore script:

.\Restore-FanNoise-Settings_*.ps1

Must also be run as Administrator.

⚙️ Configuration
Modify Process Kill List
$killList = @('chrome','msedge','firefox','HandBrake','Prime95','transcode','rtss64','msmpeng')
Adjust CPU Limit
$targetMaxProc = 50
GPU Power Behavior
$newPL = [math]::Max(30, [math]::Floor($g.Power * 0.8))
🧩 Requirements
Windows (PowerShell 5+)
Administrator privileges
Optional:
nvidia-smi (for NVIDIA GPU control)
⚠️ Important Notes
This script prioritizes quiet operation over performance
Stopping processes may interrupt active work
GPU changes require compatible drivers/tools
Brightness control may not work on all systems
Vendor-specific fan controls (Dell, ASUS, Lenovo, etc.) are not fully implemented
🛠️ Troubleshooting
Script won't run
Ensure you're running as Administrator

Check execution policy:

Set-ExecutionPolicy Bypass -Scope Process
No GPU changes applied

Verify nvidia-smi is installed:

nvidia-smi
Fans still loud?
Possible causes:
Dust buildup
Thermal paste degradation
BIOS fan curve settings
Background workloads not covered in kill list
🔮 Possible Improvements
Add AMD GPU support
Integrate vendor APIs (Dell, ASUS, Lenovo)
GUI version
Fan curve control (if hardware allows)
Profile presets (Silent / Balanced / Performance)
📄 License

Free to use and modify.

🙌 Disclaimer

This script modifies system power and hardware behavior.
Use at your own risk. Always review scripts before running.
