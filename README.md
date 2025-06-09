# 🛡️ System Sentinel

> 🔍 Monitor, maintain, and optimize your Windows system with style!

## ✨ What is System Sentinel?
A powerful desktop application that combines the best of Python and PowerShell to keep your system running smoothly. Perfect for both tech enthusiasts and casual users!

## 🚀 Key Features
- 📊 Real-time system monitoring dashboard
- 🔄 Automated maintenance routines
- 📈 Performance tracking with visual graphs
- 🎨 Modern, user-friendly GUI
- 📝 Detailed system health reports
- ⚡ Lightweight and efficient

## 🛠️ Components
SystemSentinel/
├── 🖥️ SystemSentinelGUI.exe    # Main application
├── 📜 SystemSentinel.ps1       # PowerShell engine
├── 🔧 SystemSentinelModule.psm1 # Core functions
├── 📊 report_generator.py      # Analytics & graphs
└── 📝 log_helper.py           # Logging system

## 💻 System Requirements
- Windows 10/11
- PowerShell 5.1+
- 50MB disk space
- No additional software needed for end users!

## 🏃‍♂️ Quick Start
1. Download latest release
2. Run SystemSentinelGUI.exe
3. That's it! 🎉

## 🔧 For Developers
Building from source:
# Clone repository
git clone https://github.com/baklarrrr/System-Sentinel.git

# Build executable
.\build_exe.bat

Required for development:
- Python 3.8+
- PyQt6
- matplotlib
- pyinstaller

## ⚙️ Configuration
Customize via SystemSentinelConfig.json:
{
  "LogFileName": "build_scan_log.txt",
  "MaxLogFileSizeMB": 10,
  "MaxArchivedLogs": 5,
  "GPULoadThresholdPercent": 90,
  "CacheSizeLimitGB": 5
}

- `GPULoadThresholdPercent` sets the GPU usage warning threshold.
- `CacheSizeLimitGB` defines the maximum allowed size for Unreal and Blender caches.

## 📈 Performance Impact
- CPU: <2% average usage
- Memory: ~50MB RAM
- Disk: Minimal I/O

## 🤝 Contributing
Contributions welcome! Check our issues page or submit your own improvements.

## 📜 License
MIT License © 2025 Bakar

## 👨‍💻 Creator
Crafted with ❤️ by [Bakar](https://github.com/baklarrrr)
A passionate hobbyist developer who believes in creating useful tools for everyone. 
Built this project to combine my interests in system optimization and coding!

## 📝 Version History
- v1.0.0 - First stable release 🎉
  - Complete monitoring suite
  - GUI interface
  - Automated reporting

## 🌟 Star History
[![Star History Chart](https://api.star-history.com/svg?repos=baklarrrr/System-Sentinel&type=Date)](https://star-history.com/#baklarrrr/System-Sentinel&Date)

---
💡 **Pro Tip**: Run System Sentinel at startup for continuous system optimization!
