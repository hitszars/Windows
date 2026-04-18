<#
Reduce-FanNoise-AllInOne.ps1
Run as Administrator.
Creates a restore file (Restore-FanNoise-Settings.ps1) to undo changes.
#>

# Require admin
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "Please run this script as Administrator."
    exit 1
}

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$restoreFile = "$env:TEMP\Restore-FanNoise-Settings_$timestamp.ps1"
$logFile = "$env:TEMP\ReduceFanNoise_Log_$timestamp.txt"
Start-Transcript -Path $logFile -Force

Write-Output "Starting fan-noise reduction at $(Get-Date). Creating restore script: $restoreFile"

# 1) Save current active power scheme GUID and max processor state (AC)
$activeOutput = powercfg /getactivescheme 2>$null
if ($activeOutput -match 'GUID: ([0-9a-fA-F\-]+)') { $origGuid = $Matches[1] } else { $origGuid = $null }
# Read current AC max processor state (may require parsing registry/powercfg; attempt to read via powercfg)
function Get-ProcessorMaxState {
    param($guid)
    if (-not $guid) { return $null }
    $val = & powercfg /q $guid SUB_PROCESSOR PROCTHROTTLEMAX 2>$null | Out-String
    if ($val -match 'Current AC Power Setting Index: 0x([0-9a-fA-F]+)') { return [Convert]::ToInt32($Matches[1],16) }
    return $null
}
$origMaxProc = Get-ProcessorMaxState $origGuid

# 2) Create restore script header
$restoreLines = @()
$restoreLines += "if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { Write-Error 'Run as Administrator'; exit 1 }"
if ($origGuid) { $restoreLines += "powercfg /setactive $origGuid" }
if ($origMaxProc -ne $null) { $restoreLines += "powercfg /setacvalueindex $origGuid SUB_PROCESSOR PROCTHROTTLEMAX $origMaxProc`npowercfg /setactive $origGuid" }

# 3) Kill common heavy processes (configurable list)
$killList = @('chrome','msedge','firefox','HandBrake','Prime95','transcode','rtss64','msmpeng') # edit as needed
$restoreLines += "# No automatic restart of killed apps (user can reopen)"
foreach ($p in $killList) { $restoreLines += "# Killed (if running): $p" }

# 4) Reduce CPU max state to 50% (AC) to lower turbo
$targetMaxProc = 50
if ($origGuid) {
    try {
        powercfg /setacvalueindex $origGuid SUB_PROCESSOR PROCTHROTTLEMAX $targetMaxProc
        powercfg /setactive $origGuid
        Write-Output "Set Maximum Processor State (AC) to $targetMaxProc% on scheme $origGuid"
    } catch { Write-Warning "Failed to set processor max state: $_" }
} else {
    Write-Warning "Could not determine active power scheme GUID; skipping CPU max-state change."
}

# 5) Lower display brightness to 30% (if supported)
try {
    $monMethods = Get-WmiObject -Namespace root/WMI -Class WmiMonitorBrightnessMethods -ErrorAction SilentlyContinue
    if ($monMethods) {
        foreach ($m in $monMethods) { $m.WmiSetBrightness(1,30) }
        $restoreLines += "# Note: Display brightness restore not implemented (use system controls)."
        Write-Output "Set display brightness to 30% (if supported)."
    } else {
        Write-Output "No WMI brightness control detected; skipping display brightness."
    }
} catch { Write-Warning "Brightness change failed: $_" }

# 6) Kill heavy processes
foreach ($p in $killList) {
    try {
        $procs = Get-Process -Name $p -ErrorAction SilentlyContinue
        if ($procs) {
            $procs | Stop-Process -Force -ErrorAction SilentlyContinue
            Write-Output "Stopped process: $p"
        }
    } catch { Write-Warning "Failed to stop $p: $_" }
}

# 7) NVIDIA GPU: attempt to set conservative power limit if nvidia-smi available
$nvsi = Get-Command nvidia-smi -ErrorAction SilentlyContinue
if ($nvsi) {
    try {
        # Query current power limit(s)
        $gpuInfo = & nvidia-smi --query-gpu=index,power.limit --format=csv,noheader 2>$null
        if ($gpuInfo) {
            $lines = $gpuInfo -split "`n" | Where-Object { $_ -match '\S' }
            $origNv = @()
            foreach ($ln in $lines) {
                $parts = $ln -split ','
                $idx = $parts[0].Trim()
                $plStr = ($parts[1].Trim() -replace 'W','').Trim()
                $origNv += @{Index=$idx;Power=$plStr}
            }
            # Save restore lines for each GPU
            foreach ($g in $origNv) {
                $restoreLines += "nvidia-smi -i $($g.Index) -pl $($g.Power) 2>$null"
            }
            # Set a conservative absolute value: choose 80% of current or at most 120W as example
            foreach ($g in $origNv) {
                $newPL = [math]::Max(30, [math]::Floor($g.Power * 0.8)) # don't go below 30W
                try {
                    nvidia-smi -i $g.Index -pl $newPL 2>$null
                    Write-Output "Set NVIDIA GPU $($g.Index) power limit to ${newPL}W (was $($g.Power)W)"
                } catch { Write-Warning "Failed to set NVIDIA power limit for GPU $($g.Index): $_" }
            }
        } else {
            Write-Output "nvidia-smi present but could not read GPU power info."
        }
    } catch { Write-Warning "NVIDIA power-limit step failed: $_" }
} else {
    Write-Output "nvidia-smi not found; skipping NVIDIA GPU power limiting."
}

# 8) Vendor-specific quiet profiles (attempt common CLIs)
# Dell (Dell Command | PowerShell may provide 'dell' tools) - example placeholder
if (Get-Command DellBIOSProvider -ErrorAction SilentlyContinue) {
    Write-Output "Dell BIOS Provider detected — vendor quiet profile steps could be added here."
    $restoreLines += "# Vendor Dell changes not implemented automatically."
}
# Lenovo, ASUS, MSI detection placeholders: many vendors do not expose CLI; user installs vendor utility.

# 9) Recommend BIOS fan curve (log)
Write-Output "If noise continues, hardware/BIOS fan curve or cleaning may be required."

# 10) Create restore script file
$restoreHeader = @(
    "### Restore script generated on $([datetime]::Now)",
    "### Run as Administrator to restore saved settings"
)
$restoreHeader + $restoreLines | Out-File -FilePath $restoreFile -Encoding UTF8
Write-Output "Created restore script at: $restoreFile"

# 11) Final message
Write-Output "Completed automated actions. Check $logFile for details. If noise persists, consider hardware inspection or vendor utilities."

Stop-Transcript
