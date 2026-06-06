<#
.SYNOPSIS
    Windows Automated Reboot & Hardware Diagnostics Tool.
.DESCRIPTION
    Analyzes system event logs (Kernel-Power, WHEA-Logger, NTFS, MemoryDiagnostics) 
    using a weighted scoring algorithm to identify hardware failure risks.
.LICENSE
    MIT License
.VERSION
    1.0.0
#>

# 1. Privileges Verification
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "Critical: Please run this script as an Administrator to access low-level system event logs."
    Exit
}

# 2. Initialize Diagnosis Counters & Evidence Metrics
$Analysis = @{
    CpuScore     = 0
    MemoryScore  = 0
    DiskScore    = 0
    PowerScore   = 0
    GpuScore     = 0
    Evidence     = [System.Collections.Generic.List[string]]::new()
    Details      = [System.Collections.Generic.List[string]]::new()
}

# XML Property Extraction Helper
function Get-EventXmlProperty {
    param(
        [Parameter(Mandatory=$true)]$Event,
        [Parameter(Mandatory=$true)][string]$PropertyName
    )
    try {
        [xml]$Xml = $Event.ToXml()
        $Node = $Xml.Event.EventData.Data | Where-Object { $_.Name -eq $PropertyName }
        if ($Node) { return $Node.'#text' }
    } catch {
        # Suppress XML parsing errors silently
    }
    return $null
}

# 3. Data Collection & Deep Analysis
# 3.1 Inspect Kernel-Power Event ID 41 (Unexpected Shutdown / Power Interruption)
$KernelPowerEvents = try { Get-WinEvent -FilterHashtable @{LogName='System'; Id=41} -ErrorAction Stop } catch { $null }
if ($KernelPowerEvents) {
    $Analysis.Details.Add("Detected a total of $($KernelPowerEvents.Count) unexpected reboot/power-loss records (Event ID 41).")

    foreach ($Event in $KernelPowerEvents) {
        $BugcheckCodeDec = Get-EventXmlProperty -Event $Event -PropertyName "BugcheckCode"
        $PowerButtonTime = Get-EventXmlProperty -Event $Event -PropertyName "PowerButtonTimestamp"
        
        if ($BugcheckCodeDec -and $BugcheckCodeDec -ne "0" -and $BugcheckCodeDec -match '^\d+$') {
            # Convert decimal bugcheck code to standardized Hexadecimal
            $BugcheckHex = "0x" + [Convert]::ToString([int64]$BugcheckCodeDec, 16).ToUpper()
            $Analysis.Evidence.Add("Kernel-Power caught a BSOD crash. Bugcheck Code: $BugcheckHex (Timestamp: $($Event.TimeCreated))")
            
            # Weighted categorization of BSOD Bugcheck Codes
            switch ($BugcheckHex) {
                { $_ -in "0x1A", "0x2E", "0x4E", "0x50", "0x109" } {
                    $Analysis.MemoryScore += 3
                    $Analysis.Evidence.Add("  -> Bugcheck $BugcheckHex is highly correlated with RAM stability issues.")
                }
                { $_ -in "0x101", "0x124" } {
                    $Analysis.CpuScore += 4
                    $Analysis.Evidence.Add("  -> Bugcheck $BugcheckHex is associated with CPU core or core-voltage failure.")
                }
                { $_ -in "0x7A", "0x7B", "0xF4", "0xEF" } {
                    $Analysis.DiskScore += 3
                    $Analysis.Evidence.Add("  -> Bugcheck $BugcheckHex signals Storage (SSD/HDD) or interface communication failure.")
                }
                { $_ -in "0x116", "0x117", "0x119" } {
                    $Analysis.GpuScore += 3
                    $Analysis.Evidence.Add("  -> Bugcheck $BugcheckHex relates to Graphics Card (GPU) or PCIe slot anomalies.")
                }
            }
        } else {
            # Bugcheck is 0: Instant power loss or hard hardware lockup
            if ($PowerButtonTime -eq "0") {
                $Analysis.PowerScore += 2
                $Analysis.Evidence.Add("Instant power cut or hardware freeze detected (Bugcheck 0, No BSOD. Timestamp: $($Event.TimeCreated)). Commonly linked to motherboard VRMs, power adapters, failing batteries, or instant thermal shutdown protection.")
            } else {
                $Analysis.Evidence.Add("Detected a manual hard shutdown initiated by the user long-pressing the power button (Timestamp: $($Event.TimeCreated)).")
            }
        }
    }
}

# 3.2 Evaluate WHEA-Logger Hardware Errors (Limited to last 5 logs to avoid log bloating)
$WheaEvents = try { Get-WinEvent -FilterHashtable @{LogName='System'; ProviderName='Microsoft-Windows-WHEA-Logger'} -ErrorAction Stop } catch { $null }
if ($WheaEvents) {
    $Analysis.Details.Add("WHEA (Windows Hardware Error Architecture) captured a total of $($WheaEvents.Count) hardware error events.")

    $WheaEvents | Select-Object -First 5 | ForEach-Object {
        $Analysis.Evidence.Add("WHEA Hardware Log Entry (ID: $($_.Id), Timestamp: $($_.TimeCreated)).")

        if ($_.Id -eq 18 -or $_.Message -like "*Processor*") {
            $Analysis.CpuScore += 5
            $Analysis.Evidence.Add("  -> [Recent Event] Detected CPU Architecture or Cache Hierarchy Error (Machine Check Exception).")
        } elseif ($_.Id -eq 17 -or $_.Message -like "*PCIExpress*") {
            $Analysis.GpuScore += 2
            $Analysis.DiskScore += 1
            $Analysis.Evidence.Add("  -> [Recent Event] Detected PCIe Bus Interconnect Error. May impact Discrete GPU, NVMe SSD, or Wi-Fi card.")
        }
    }
}

# 3.3 Validate Memory Diagnostics Logs (Targeting IDs 1102 / 1202)
$MemoryEvents = try { Get-WinEvent -FilterHashtable @{LogName='System'; ProviderName='Microsoft-Windows-MemoryDiagnostics-Results'} -ErrorAction Stop } catch { $null }
if ($MemoryEvents) {
    foreach ($Event in $MemoryEvents) {
        if ($Event.Id -eq 1102 -or $Event.Id -eq 1202) {
            $Analysis.MemoryScore += 10
            $Analysis.Evidence.Add("Windows Memory Diagnostic Tool explicitly confirmed physical RAM degradation (Event ID: $($Event.Id), Timestamp: $($Event.TimeCreated)).")
        }
    }
}

# 3.4 Audit Storage and File System Integrity (NTFS / Disk Errors)
$DiskEvents = try { Get-WinEvent -FilterHashtable @{LogName='System'; ProviderName=@('disk', 'Ntfs')} -ErrorAction Stop | Where-Object { $_.Level -le 2 } } catch { $null }
if ($DiskEvents) {
    $RecentDiskErrors = $DiskEvents | Select-Object -First 5
    if ($RecentDiskErrors) {
        $Analysis.DiskScore += 2
        $Analysis.Evidence.Add("Storage subsystems reported critical driver or file-system level anomalies recently (NTFS/Disk Error).")
    }
}

# 3.5 Check for Critical Thermal Overheat Shutdowns (Event IDs 86 and 8624)
$ThermalEvents = try { Get-WinEvent -FilterHashtable @{LogName='System'; Id=@(8624, 86)} -ErrorAction Stop } catch { $null }
if ($ThermalEvents) {
    $Analysis.PowerScore += 3
    $Analysis.Evidence.Add("System triggered a kernel-level or hardware-enforced emergency thermal shutdown due to exceeding safe temperature thresholds (Event ID: $(($ThermalEvents | Select-Object -First 1).Id)).")
}

# 4. Compile Diagnostic Report
$TotalScore = $Analysis.CpuScore + $Analysis.MemoryScore + $Analysis.DiskScore + $Analysis.PowerScore + $Analysis.GpuScore
$SuspectHardware = "No definitive hardware failure markers found (Likely caused by unstable drivers, third-party software conflicts, or system corruption)."

if ($TotalScore -gt 0) {
    $HardwareMatrix = @(
        @{ Name = "Processor (CPU) Defect or Unstable VCore Voltage Supply"; Score = $Analysis.CpuScore },
        @{ Name = "Memory (RAM) Physical Degradation or Defective Contacts"; Score = $Analysis.MemoryScore },
        @{ Name = "Storage (SSD/HDD) Controller Failure or Interface Interruption"; Score = $Analysis.DiskScore },
        @{ Name = "Power Supply / Motherboard VRM Failure, or Thermal Trip Shutdown"; Score = $Analysis.PowerScore },
        @{ Name = "Discrete Graphics (GPU) Hardware Failure or Bad PCIe Connection"; Score = $Analysis.GpuScore }
    )

    $SortedMatrix = $HardwareMatrix | Sort-Object Score -Descending
    $TopMatch = $SortedMatrix[0]
    if ($TopMatch.Score -ge 2) {
        $SuspectHardware = $TopMatch.Name
    }
}

# Construct Report Output String
$Report = [System.Text.StringBuilder]::new()
[void]$Report.AppendLine("=========================================================================")
[void]$Report.AppendLine("             Windows Notebook Unexpected Reboot Diagnostic Report         ")
[void]$Report.AppendLine("=========================================================================")
[void]$Report.AppendLine("Generated On      : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
[void]$Report.AppendLine("Scan Range        : BSOD Kernels, WHEA Hardware Architecture, Power Logs, Storage Integrity")
[void]$Report.AppendLine("-------------------------------------------------------------------------")
[void]$Report.AppendLine("[System Health Execution Metrics]")

if ($Analysis.Details.Count -gt 0) {
    foreach ($Detail in $Analysis.Details) {
        [void]$Report.AppendLine("   $Detail")
    }
} else {
    [void]$Report.AppendLine("   No major kernel-level anomalies calculated in the database.")
}

[void]$Report.AppendLine("-------------------------------------------------------------------------")
[void]$Report.AppendLine("[Preliminary Strategic Conclusion]")
[void]$Report.AppendLine("Suspected Component At Fault: $SuspectHardware")
[void]$Report.AppendLine("-------------------------------------------------------------------------")
[void]$Report.AppendLine("[Hardware Instability Metrics Matrix (Higher Scores = Higher Probability)]")
[void]$Report.AppendLine("   Memory Subsystem (RAM) : $($Analysis.MemoryScore) Points")
[void]$Report.AppendLine("   Processor Core   (CPU) : $($Analysis.CpuScore) Points")
[void]$Report.AppendLine("   Storage Media (SSD/HDD): $($Analysis.DiskScore) Points")
[void]$Report.AppendLine("   Power & Thermal Rails  : $($Analysis.PowerScore) Points")
[void]$Report.AppendLine("   Graphics Adapter (GPU) : $($Analysis.GpuScore) Points")
[void]$Report.AppendLine("-------------------------------------------------------------------------")
[void]$Report.AppendLine("[Low-Level Forensic Evidence Logs]")

if ($Analysis.Evidence.Count -eq 0) {
    [void]$Report.AppendLine("   No clear low-level telemetry available. Persistent random reboots without logs typically imply zero-latency power rail dropouts.")
} else {
    foreach ($Evidence in $Analysis.Evidence) {
        [void]$Report.AppendLine("   $Evidence")
    }
}
[void]$Report.AppendLine("-------------------------------------------------------------------------")
[void]$Report.AppendLine("[Actionable Remediation Checklist]")

switch -Wildcard ($SuspectHardware) {
    "*Memory*" {
        [void]$Report.AppendLine("  1. Execute a deep-scan loop via MemTest86 (Bootable USB) or run the native Windows Memory Diagnostic tool.")
        [void]$Report.AppendLine("  2. If running a dual-channel configuration, pull one module out and alternate sockets to test absolute stability.")
        [void]$Report.AppendLine("  3. Clean the gold contacts on the RAM module using a non-static eraser and ensure it re-seats firmly.")
        break
    }
    "*Processor*" {
        [void]$Report.AppendLine("  1. Audit thermal charts immediately under load to detect structural thermal throttling or dry thermal paste.")
        [void]$Report.AppendLine("  2. If any undervolting (Offset) or Overclocking profiles are deployed in BIOS, clear CMOS to restore hardware factory defaults.")
        [void]$Report.AppendLine("  3. Check the OEM support page for urgent BIOS/UEFI microcode patches addressing CPU voltage rail fluctuations.")
        break
    }
    "*Storage*" {
        [void]$Report.AppendLine("  1. Download CrystalDiskInfo or manufacturer software to evaluate NVMe health parameters, checking specifically for 0E (Media Errors) indicators.")
        [void]$Report.AppendLine("  2. Reseat the M.2 SSD in its slot and verify if the thermal pad is intact to counter high controller heat-death cycles.")
        break
    }
    "*Power*" {
        [void]$Report.AppendLine("  1. Verify if reboots only materialize under battery operation. Failing lithium battery cells often fail to deliver immediate burst currents.")
        [void]$Report.AppendLine("  2. Perform heavy stress testing via AIDA64 / Prime95. Sudden power cutouts under high synthetic power draws isolate VRM/Adapter load limits.")
        [void]$Report.AppendLine("  3. Clear fan blockages and re-apply premium thermal paste to rule out sudden safety-induced hardware shutdowns.")
        break
    }
    "*Graphics*" {
        [void]$Report.AppendLine("  1. Perform a clean GPU driver swap via Display Driver Uninstaller (DDU) in Safe Mode, then deploy the latest enterprise WHQL stable driver.")
        [void]$Report.AppendLine("  2. Benchmark 3D heavy workflows via FurMark. Immediate display drops or freezes separate stable runtime kernels from GPU core logic drops.")
        break
    }
    Default {
        [void]$Report.AppendLine("  1. If this issue is highly prevalent across an identical batch of enterprise machines with Bugcheck 0, scrutinize systemic motherboard structural bugs.")
        [void]$Report.AppendLine("  2. Investigate low-level driver stack interceptors such as kernel filters added by outdated anti-virus configurations.")
        break
    }
}
[void]$Report.AppendLine("=========================================================================")

# 5. Output Management & Fail-Safe Persistence
$ReportText = $Report.ToString()
Write-Output $ReportText

$DesktopPath = [System.IO.Path]::Combine([Environment]::GetFolderPath("Desktop"), "Reboot_Hardware_Diagnosis_Report.txt")
$TempPath    = [System.IO.Path]::Combine($env:TEMP, "Reboot_Hardware_Diagnosis_Report.txt")
$SavedPath   = $null

try {
    $ReportText | Out-File -FilePath $DesktopPath -Encoding utf8 -Force
    $SavedPath = $DesktopPath
} catch {
    try {
        $ReportText | Out-File -FilePath $TempPath -Encoding utf8 -Force
        $SavedPath = $TempPath
    } catch {
        # Silent exception catch
    }
}

if ($SavedPath) {
    Write-Host "`n[Success] Diagnostic report successfully preserved at: $SavedPath" -ForegroundColor Green
} else {
    Write-Warning "[Warning] Storage persistence failed. Please copy the console data manually."
}
