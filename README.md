# System Sentinel

A powerful system monitoring and maintenance tool with GUI interface, built using Python and PowerShell.

## Features
- Real-time system monitoring
- Performance tracking and logging
- Interactive GUI built with PyQt6
- Automated system maintenance
- Detailed reporting with graphs
- Modular PowerShell architecture

## Components
- SystemSentinelGUI.exe - Main executable interface
- SystemSentinel.ps1 - Core PowerShell monitoring script
- SystemSentinelModule.psm1 - PowerShell module containing core functions
- report_generator.py - Generates performance graphs and reports
- log_helper.py - Centralized logging system

## Requirements
- Windows 10/11
- PowerShell 5.1 or higher
- Python 3.8+ (for development)
- PyQt6 (for development)
- matplotlib (for development)

## Installation
1. Download the latest release
2. Extract all files to desired location
3. Run SystemSentinelGUI.exe
4. System Sentinel will automatically configure required permissions

## Building from Source
Use the included build_exe.bat script to compile:
```bash
.\build_exe.bat
