WinCrashAnalyzer

A PowerShell-based diagnostic tool for investigating unexpected reboots, Blue Screens of Death (BSODs), hardware errors, and power-related failures on Windows systems.

WinCrashAnalyzer analyzes Windows Event Logs and correlates evidence from Kernel-Power, WHEA, Memory Diagnostics, Storage, and Thermal events to provide hardware suspicion analysis and troubleshooting recommendations.

The goal is not to replace professional hardware diagnostics, but to help users quickly identify the most likely source of system instability.

⸻

Features

Event Log Analysis

Collects and analyzes information from:

* Kernel-Power (Event ID 41)
* WHEA-Logger
* Windows Memory Diagnostics
* NTFS and Disk errors
* Thermal shutdown events

BSOD Analysis

* Extracts Bugcheck codes from system events
* Converts decimal Bugcheck values to hexadecimal
* Maps common BSOD codes to potential hardware categories

Hardware Risk Scoring

Evaluates and ranks the likelihood of issues related to:

* Memory (RAM)
* CPU
* Storage (SSD/HDD)
* Power and Thermal Systems
* GPU

Evidence-Based Reporting

Generates a detailed report including:

* Detected system events
* Diagnostic evidence
* Hardware suspicion ranking
* Troubleshooting recommendations

Automatic Report Export

Reports are automatically saved to:

1. Desktop (preferred)
2. Temp directory (fallback)

to ensure diagnostic results are preserved.

⸻

Example Output

==================================================
Windows Hardware Diagnostic Report
==================================================
Likely Cause:
Memory (RAM) Hardware Failure
Hardware Risk Ranking
RAM:       12
CPU:        4
Storage:    2
Power:      1
GPU:        0
Evidence
- Kernel-Power Event ID 41 detected
- Bugcheck Code 0x1A detected
- Memory Diagnostic failure detected
Recommendation
- Run Windows Memory Diagnostic
- Run MemTest86
- Reseat memory modules

⸻

Requirements

* Windows 10 / Windows 11
* PowerShell 5.1 or later
* Administrator privileges

⸻

Usage

Open PowerShell as Administrator.

Allow script execution for the current session:

Set-ExecutionPolicy RemoteSigned -Scope Process

Run the script:

.\WinCrashAnalyzer.ps1

After execution, a diagnostic report will be displayed and automatically saved.

⸻

Disclaimer

This tool performs log-based analysis only.

The generated results should be treated as diagnostic guidance rather than definitive proof of hardware failure.

Final conclusions should be verified using:

* Hardware stress testing
* Manufacturer diagnostic tools
* Physical hardware inspection

⸻

Contributing

Issues, bug reports, feature requests, and pull requests are welcome.

If you find incorrect event mappings, unsupported Bugcheck codes, or hardware detection improvements, please open an issue.

⸻

License

Released under the MIT License.
