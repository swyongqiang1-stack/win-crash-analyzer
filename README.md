# Windows Notebook Automated Reboot & Hardware Diagnostics Tool 🚀

A lightweight, native PowerShell utility designed to diagnose sudden reboots, freezes, and Blue Screens of Death (BSOD) on Windows laptops. 

Instead of relying on heavy third-party software, this tool directly extracts and parses low-level system logs (`Kernel-Power 41`, `WHEA-Logger`, `NTFS/Disk`, and `MemoryDiagnostics`). It applies a weighted scoring algorithm to evaluate and rank potential failure risks across core hardware components: RAM, CPU, Storage, Power/Thermal, and GPU.

---

## ✨ Features
* **Privilege Self-Check**: Automatically verifies and prompts for Administrator privileges required to access restricted kernel-level logs.
* **BSOD Code Auto-Parsing**: Automatically converts decimal Bugcheck codes to Hexadecimal and classifies them by their known hardware associations.
* **WHEA-Logger Evaluation**: Captures Machine Check Exceptions (MCE) and PCIExpress bus errors to identify failing silicon or faulty slots.
* **Instant Power-Loss Detection**: Differentiates between hard manual shutdowns (long-pressing the power button) and sudden hardware power drops (Bugcheck 0) caused by power rails, batteries, or thermal tripping.
* **Intelligent Action Items**: Generates a tailored troubleshooting checklist based on the highest-scoring component.
* **Fallback Storage Path**: Saves the diagnostic report to the Desktop by default, with an automatic fallback to the local `Temp` directory to prevent data loss.

---

## 📦 How to Use

### Method 1: Run the Script (Recommended)
1. Right-click the Windows Start menu and select **Terminal (Admin)** or **PowerShell (Admin)**.
2. If you haven't enabled script execution on your machine, run the following command to allow it for the current session:
   ```powershell
   Set-ExecutionPolicy RemoteSigned -Scope Process
