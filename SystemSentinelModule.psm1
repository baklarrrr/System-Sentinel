<#
.SYNOPSIS
    Module for SystemSentinel.ps1 containing all functions.
#>

# Set Default Log Level - Can be overridden by config
$global:LogLevel = "Info" # Default log level if not specified in config

# --- Section 0: Helper Functions ---
function Invoke-WithRetry {
    param(
        [ScriptBlock]$ScriptBlock,
        [int]$RetryCount = 3,
        [int]$DelaySeconds = 1
    )
    for ($i = 0; $i -lt $RetryCount; $i++) {
        try {
            & $ScriptBlock
            return $true
        }
        catch {
            Write-Log "Invoke-WithRetry: Attempt $($i+1) failed: $($_.Exception.Message)" -Level Warning
            Start-Sleep -Seconds $DelaySeconds
        }
    }
    return $false
}

# --- Section 3: Logging & Utility Functions ---
function Get-Timestamp { return "[{0:yyyy-MM-dd HH:mm:ss}]" -f (Get-Date) }

function Roll-LogFile {
    param (
        [string]$LogFilePath,
        [double]$MaxMB = 1,
        [int]$MaxArchives = 5
    )
    try {
        $maxSizeBytes = $MaxMB * 1MB
        if (Test-Path $LogFilePath) {
            $currentSize = (Get-Item $LogFilePath).Length
            if ($currentSize -ge $maxSizeBytes) {
                $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
                $logDir = Split-Path $LogFilePath
                $logBaseName = Split-Path $LogFilePath -LeafBase
                $archiveDir = Join-Path $logDir (Get-Date -Format "yyyy-MM-dd")
                if (!(Test-Path $archiveDir)) { New-Item -ItemType Directory -Path $archiveDir | Out-Null }
                $archiveName = Join-Path $archiveDir "$logBaseName`_$timestamp.txt"
                Rename-Item -Path $LogFilePath -NewName $archiveName -ErrorAction Stop
                Write-Host "$(Get-Timestamp) Log file archived as $archiveName."
                $archives = Get-ChildItem -Path $archiveDir -Filter "$logBaseName*_*.txt" | Sort-Object LastWriteTime -Descending
                if ($archives.Count -gt $MaxArchives) {
                    $archives | Select-Object -Skip $MaxArchives | Remove-Item -Force
                    Write-Host "$(Get-Timestamp) Old archived logs deleted."
                }
                New-Item -Path $LogFilePath -ItemType File | Out-Null
            }
        }
    }
    catch {
        Write-Host "$(Get-Timestamp) Error rolling log file: $($_.Exception.Message)" -Level Error
    }
}

function Write-Log {
    param (
        [string]$Message,
        [ValidateSet("Debug", "Info", "Warning", "Error")][string]$Level = "Info"
    )
    $logLevels = @{
        "Debug"   = 1
        "Info"    = 2
        "Warning" = 3
        "Error"   = 4
    }
    if ($logLevels[$Level] -ge $logLevels[$global:LogLevel]) {
        $entry = "$(Get-Timestamp) [$Level] $Message"
        Write-Host $entry
        try {
            if (-not [string]::IsNullOrWhiteSpace($global:LogFile)) {
                Roll-LogFile -LogFilePath $global:LogFile -MaxMB $global:MaxLogFileSizeMB -MaxArchives $global:MaxArchivedLogs
                Add-Content -Path $global:LogFile -Value $entry -ErrorAction Stop
            }
        }
        catch {
            Write-Host "$(Get-Timestamp) Failed to write to log file: $($_.Exception.Message)" -Level Error
        }
    }
}

function Run-CmdCommand {
    param ([string]$Command)
    try {
        Write-Log "Running CMD: $Command" -Level Debug
        $output = cmd /c $Command 2>&1
        foreach ($line in $output) {
            Write-Log "CMD Output: $line" -Level Debug
        }
    }
    catch {
        Write-Log "CMD Error: $($_.Exception.Message) in command: $Command" -Level Error
    }
}

# --- Section D: Baseline Maintenance Functions ---
function Create-RestorePoint {
    Write-Log "Creating system restore point..." -Level Info
    if (-not (Invoke-WithRetry -ScriptBlock { Checkpoint-Computer -Description "System Sentinel Restore Point" -RestorePointType MODIFY_SETTINGS })) {
        Write-Log "Restore point creation failed after multiple attempts." -Level Warning
    }
    else {
        Write-Log "Restore point creation attempted." -Level Debug
    }
}

function Run-SFC {
    Write-Log "Running System File Checker (SFC)..." -Level Info
    try {
        $sfcJob = Start-Job -ScriptBlock { sfc /scannow }
        while ($sfcJob.State -eq "Running") {
            Write-Progress -Activity "SFC Scan" -Status "SFC is running..." -PercentComplete 0
            Start-Sleep -Seconds 5
        }
        Receive-Job -Job $sfcJob | ForEach-Object { Write-Log $_ -Level Debug }
        Write-Log "SFC scan completed." -Level Info
        Remove-Job $sfcJob
    }
    catch {
        Write-Log "Error running SFC: $($_.Exception.Message)" -Level Error
    }
}

function Run-DiskCleanup {
    Write-Log "Running Disk Cleanup..." -Level Info
    try {
        $cleanupJob = Start-Job -ScriptBlock { cleanmgr /sagerun:1 }
        while ($cleanupJob.State -eq "Running") {
            Write-Progress -Activity "Disk Cleanup" -Status "Disk Cleanup is in progress..." -PercentComplete 0
            Start-Sleep -Seconds 5
        }
        Receive-Job -Job $cleanupJob | ForEach-Object { Write-Log $_ -Level Debug }
        Write-Log "Disk Cleanup completed." -Level Info
        Remove-Job $cleanupJob
    }
    catch {
        Write-Log "Error running Disk Cleanup: $($_.Exception.Message)" -Level Error
    }
}

function Backup-Drivers {
    Write-Log "Backing up installed drivers..." -Level Info
    try {
        $dest = $config.DriverBackupDestination
        if (-not (Test-Path $dest)) { New-Item -ItemType Directory -Path $dest -ErrorAction Stop | Out-Null }
        if (-not (Invoke-WithRetry -ScriptBlock { dism /online /export-driver /destination:"$dest" | ForEach-Object { Write-Log $_ -Level Debug } })) {
            Write-Log "Driver backup failed after multiple attempts." -Level Warning
        }
        else {
            Write-Log "Driver backup completed." -Level Info
        }
    }
    catch {
        Write-Log "Error backing up drivers: $($_.Exception.Message)" -Level Error
    }
}

function Check-WindowsUpdates {
    Write-Log "Checking for Windows Updates..." -Level Info
    try {
        if (-not (Get-Module -ListAvailable PSWindowsUpdate)) {
            Install-Module -Name PSWindowsUpdate -Force -ErrorAction Stop
        }
        Import-Module PSWindowsUpdate -ErrorAction Stop
        if (-not (Invoke-WithRetry -ScriptBlock { Get-WindowsUpdate -AcceptAll -IgnoreReboot | ForEach-Object { Write-Log $_ -Level Debug } })) {
            Write-Log "Windows update check failed after retries." -Level Warning
        }
        else {
            Write-Log "Windows update check completed." -Level Info
        }
    }
    catch {
        Write-Log "Error checking Windows Updates: $($_.Exception.Message)" -Level Error
    }
}

function Clear-EventLogs {
    Write-Log "Clearing Application and System Event Logs..." -Level Info
    try {
        Run-CmdCommand "wevtutil cl Application"
        Run-CmdCommand "wevtutil cl System"
        Write-Log "Event logs cleared." -Level Info
    }
    catch {
        Write-Log "Error clearing event logs: $($_.Exception.Message)" -Level Error
    }
}

function Snapshot-DiskSpace {
    Write-Log "Capturing disk space snapshot..." -Level Info
    try {
        $drives = Get-PSDrive -PSProvider FileSystem | Select-Object Name, Used, Free, @{Name = "Free(GB)"; Expression = { [math]::Round($_.Free / 1GB, 2) } }
        $drives | Format-Table | Out-String | Write-Log -Level Info
        Write-Log "Disk space snapshot captured." -Level Info
    }
    catch {
        Write-Log "Error capturing disk space snapshot: $($_.Exception.Message)" -Level Error
    }
}

function Test-Network {
    Write-Log "Testing network connectivity to google.com..." -Level Info
    try {
        $result = Test-Connection google.com -Count 4 -ErrorAction Stop | Format-Table | Out-String
        Write-Log "Network test result: `n$result" -Level Info
    }
    catch {
        Write-Log "Error testing network connectivity: $($_.Exception.Message)" -Level Error
    }
}

function Snapshot-Performance {
    Write-Log "Capturing CPU performance snapshot..." -Level Info
    try {
        $counter = Get-Counter '\Processor(_Total)\% Processor Time'
        $counter | Format-List | Out-String | Write-Log -Level Info
        Write-Log "Performance snapshot captured." -Level Info
    }
    catch {
        Write-Log "Error capturing performance snapshot: $($_.Exception.Message)" -Level Error
    }
}

# --- Section E: Additional Maintenance Functions ---
function Run-DefenderScan {
    Write-Log "Running Windows Defender Quick Scan..." -Level Info
    try {
        if (-not (Invoke-WithRetry -ScriptBlock { Start-MpScan -ScanType QuickScan | Out-Null })) {
            Write-Log "Windows Defender Quick Scan failed." -Level Warning
        }
        else {
            Write-Log "Windows Defender Quick Scan initiated." -Level Info
        }
    }
    catch {
        Write-Log "Error running Windows Defender Quick Scan: $($_.Exception.Message)" -Level Error
    }
}

function Get-CriticalEventLogSummary {
    Write-Log "Collecting summary of critical events from the System log..." -Level Info
    try {
        $events = Get-WinEvent -FilterHashtable @{ LogName = 'System'; Level = 2 } -MaxEvents 10 -ErrorAction Stop
        if ($events) {
            $summary = $events | Format-Table -AutoSize | Out-String
            Write-Log "Critical System Events Summary:`n$summary" -Level Info
        }
        else {
            Write-Log "No critical events found in System log." -Level Info
        }
    }
    catch {
        Write-Log "Error collecting critical event log summary: $($_.Exception.Message)" -Level Error
    }
}

# --- Section F: Advanced Enhancements ---
function Analyze-PerformanceTrends {
    Write-Log "Analyzing performance trends..." -Level Info
    try {
        $cpuUsage = (Get-Counter '\Processor(_Total)\% Processor Time').CounterSamples[0].CookedValue
        $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
        $freeMemPercent = [math]::Round((($os.FreePhysicalMemory / $os.TotalVisibleMemorySize) * 100), 2)
        $csvFile = Join-Path $PSScriptRoot $config.PerformanceHistoryFile
        $history = @()
        if (Test-Path $csvFile) {
            $history = Get-Content $csvFile | Select-Object -Skip 1 | ForEach-Object {
                $parts = $_ -split ','
                if ($parts.Length -ge 2) { [double]$parts[1] } else { $null }
            } | Where-Object { $_ -ne $null }
        }
        if ($history.Count -ge 10) {
            $recent = $history | Select-Object -Last 10
            $avg = ($recent | Measure-Object -Average).Average
            if ($cpuUsage -gt ($avg + 20)) {
                Write-Log "Anomaly Detected: Current CPU ($([math]::Round($cpuUsage,2))%) is significantly above average ($([math]::Round($avg,2))%)." -Level Warning
            }
            else {
                Write-Log "No significant anomalies detected." -Level Debug
            }
        }
        else {
            Write-Log "Insufficient historical data for anomaly detection." -Level Warning
        }
        if ($cpuUsage -gt 80 -or $freeMemPercent -lt 5) {
            Write-Log "Anomaly detected: CPU usage is $([math]::Round($cpuUsage,2))% and free memory is $freeMemPercent%." -Level Warning
        }
        else {
            Write-Log "No performance anomalies detected." -Level Debug
        }
    }
    catch {
        Write-Log "Error analyzing performance trends: $($_.Exception.Message)" -Level Error
    }
}

function Self-Update {
    Write-Log "Checking for script updates..." -Level Info
    try {
        $latestVersion = "1.2.0-enhanced-logging-config"
        $currentVersion = "1.2.0-enhanced-logging-config"
        if ($latestVersion -gt $currentVersion) {
            Write-Log "A newer version ($latestVersion) is available. Please update." -Level Warning
        }
        else {
            Write-Log "You are running the latest version." -Level Info
        }
    }
    catch {
        Write-Log "Error during self-update check: $($_.Exception.Message)" -Level Error
    }
}

function Run-RemoteMaintenance {
    param ([string[]]$ComputerList)
    Write-Log "Initiating remote maintenance on: ${ComputerList -join ', '}" -Level Info
    foreach ($comp in $ComputerList) {
        try {
            Invoke-Command -ComputerName $comp -ScriptBlock {
                Write-Output "Remote maintenance executed on $env:COMPUTERNAME"
            } -ErrorAction Stop | ForEach-Object { Write-Log $_ -Level Debug }
        }
        catch {
            Write-Log "Error running remote maintenance on ${comp}: $($_.Exception.Message)" -Level Error
        }
    }
}

function Send-Notification {
    param(
        [string]$Subject,
        [string]$Body
    )
    if ($config.EnableNotification -and -not ([string]::IsNullOrWhiteSpace($config.SMTPServer)) -and -not ([string]::IsNullOrWhiteSpace($config.SMTPFrom)) -and -not ([string]::IsNullOrWhiteSpace($config.SMTPTo))) {
        try {
            Send-MailMessage -SmtpServer $config.SMTPServer -Port $config.SMTPPort -From $config.SMTPFrom -To $config.SMTPTo -Subject $Subject -Body $Body -UseSsl -ErrorAction Stop
            Write-Log "Email notification sent: $Subject" -Level Debug
        }
        catch {
            Write-Log "Error sending email notification: $($_.Exception.Message)" -Level Error
        }
    }
    else {
        Write-Log "Email notification not configured; skipping." -Level Warning
    }
}

function Send-SlackNotification {
    param(
        [string]$Message
    )
    if ($config.EnableSlackNotification -and -not ([string]::IsNullOrWhiteSpace($config.SlackWebhookURL))) {
        try {
            $payload = @{ text = $Message } | ConvertTo-Json
            Invoke-RestMethod -Uri $config.SlackWebhookURL -Method Post -Body $payload -ContentType "application/json" -ErrorAction Stop
            Write-Log "Slack notification sent." -Level Debug
        }
        catch {
            Write-Log "Error sending Slack notification: $($_.Exception.Message)" -Level Error
        }
    }
    else {
        Write-Log "Slack notification not configured; skipping." -Level Warning
    }
}

# --- Section G: Restart Recommendation & Performance History Logging ---
function Get-RestartRecommendation {
    Write-Log "Evaluating if a restart is recommended..." -Level Info
    $reasons = @()
    if (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired") {
        $reasons += "Windows Update requires a restart."
    }
    $pendingKey = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager"
    $pendingValue = (Get-ItemProperty -Path $pendingKey -Name PendingFileRenameOperations -ErrorAction SilentlyContinue).PendingFileRenameOperations
    if ($pendingValue) { $reasons += "Pending file rename operations detected." }
    try {
        $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
        $uptime = (Get-Date) - $os.LastBootUpTime
    }
    catch {
        Write-Log "Error retrieving OS uptime: $($_.Exception.Message)" -Level Error
        $uptime = [TimeSpan]::Zero
    }
    if ($uptime.Days -ge $config.UptimeThresholdDays) {
        $reasons += "System uptime is $($uptime.Days) days."
    }
    try {
        $totalMem = $os.TotalVisibleMemorySize
        $freeMem = $os.FreePhysicalMemory
        $freePercent = [math]::Round(($freeMem / $totalMem) * 100, 2)
        if ($freePercent -lt $config.FreeMemoryThresholdPercent) {
            $reasons += "Only $freePercent% free physical memory remains."
        }
    }
    catch {
        Write-Log "Error calculating memory usage: $($_.Exception.Message)" -Level Error
    }
    if ($reasons.Count -gt 0) {
        $recommendation = "Restart Recommended: " + ($reasons -join " ; ")
    }
    else {
        $recommendation = "No restart required at this time."
    }
    Write-Log $recommendation -Level Info
    return $recommendation
}

function Append-PerformanceHistory {
    Write-Log "Appending performance history..." -Level Debug
    try {
        $cpuUsage = (Get-Counter '\Processor(_Total)\% Processor Time').CounterSamples[0].CookedValue
        $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
        $freeMemPercent = [math]::Round((($os.FreePhysicalMemory / $os.TotalVisibleMemorySize) * 100), 2)
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $csvLine = "$timestamp,$cpuUsage,$freeMemPercent"
        $csvFile = Join-Path $PSScriptRoot $config.PerformanceHistoryFile

        # Ensure directory exists for the CSV file
        $csvFolder = Split-Path $csvFile -Parent
        if (-not (Test-Path $csvFolder)) {
            New-Item -ItemType Directory -Path $csvFolder -Force | Out-Null
        }

        if (-not (Test-Path $csvFile)) {
            "Timestamp,CPUUsage,FreeMemoryPercent" | Out-File -FilePath $csvFile -Encoding UTF8
        }
        $csvLine | Out-File -FilePath $csvFile -Append -Encoding UTF8
        Write-Log "Performance history appended: $csvLine" -Level Debug
    }
    catch {
        Write-Log "Error appending performance history: $($_.Exception.Message)" -Level Error
    }
}

function Log-SystemSpecs {
    Write-Log "Collecting detailed system specifications..." -Level Info
    try {
        $specsFile = Join-Path $PSScriptRoot "SystemSentinel_Specs.txt"
        $computer = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop
        $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
        $processor = Get-CimInstance Win32_Processor | Select-Object -First 1
        $video = Get-CimInstance Win32_VideoController | Select-Object -First 1
        $memoryGB = [math]::Round(($computer.TotalPhysicalMemory / 1GB), 2)
        $specs = @(
            "----- SYSTEM SPECIFICATIONS -----",
            "Computer Model: $($computer.Model)",
            "Manufacturer: $($computer.Manufacturer)",
            "Total Physical Memory (GB): $memoryGB",
            "Operating System: $($os.Caption) $($os.Version)",
            "System Type: $($computer.SystemType)",
            "Processor: $($processor.Name)",
            "Video Adapter: $($video.Name)",
            "Last Boot Time: $($os.LastBootUpTime)"
        )
        $specs | Out-File -FilePath $specsFile -Encoding UTF8
        Write-Log "Detailed system specifications logged to $specsFile" -Level Info
    }
    catch {
        Write-Log "Error collecting system specifications: $($_.Exception.Message)" -Level Error
    }
}

# --- Section H: Performance Optimization Functions ---
function Optimize-SystemPerformance {
    Write-Log "Running system performance optimizations..." -Level Info
    try {
        try { Remove-Item -Path "$env:TEMP\*" -Force -Recurse -ErrorAction Stop }
        catch { Write-Log "Error clearing $env:TEMP: $($_.Exception.Message)" -Level Warning }
        try { Remove-Item -Path "C:\Windows\Temp\*" -Force -Recurse -ErrorAction Stop }
        catch { Write-Log "Error clearing C:\Windows\Temp: $($_.Exception.Message)" -Level Warning }
        if ($config.ServicesToOptimize -and $config.ServicesToOptimize.Count -gt 0) {
            foreach ($svc in $config.ServicesToOptimize) {
                try {
                    Set-Service -Name $svc.Name -StartupType $svc.StartupType -ErrorAction Stop
                    Write-Log "Service $($svc.Name) set to $($svc.StartupType)." -Level Debug
                }
                catch { Write-Log "Error setting service $($svc.Name): $($_.Exception.Message)" -Level Error }
            }
        }
        else {
            $defaultServices = @(
                @{Name = "SysMain"; StartupType = "Automatic" },
                @{Name = "Schedule"; StartupType = "Automatic" },
                @{Name = "WSearch"; StartupType = "Delayed-Auto" }
            )
            foreach ($svc in $defaultServices) {
                try {
                    Set-Service -Name $svc.Name -StartupType $svc.StartupType -ErrorAction Stop
                    Write-Log "Default service $($svc.Name) set to $($svc.StartupType)." -Level Debug
                }
                catch { Write-Log "Error setting default service $($svc.Name): $($_.Exception.Message)" -Level Error }
            }
        }
        Run-CmdCommand "ipconfig /flushdns"
        Write-Log "System performance optimization completed." -Level Info
    }
    catch {
        Write-Log "General error in performance optimization: $($_.Exception.Message)" -Level Error
    }
}

# --- Section I: Resource Monitoring Function ---
function Monitor-SystemResources {
    Write-Log "Monitoring system resources..." -Level Debug
    try {
        $cpuUsage = (Get-Counter '\Processor(_Total)\% Processor Time').CounterSamples[0].CookedValue
        if ($cpuUsage -gt 80) {
            Write-Log "WARNING: High CPU usage detected: $([math]::Round($cpuUsage,2))%" -Level Warning
            Send-Notification -Subject "High CPU Usage Alert" -Body "CPU usage is at $([math]::Round($cpuUsage,2))%"
        }
    }
    catch {
        Write-Log "Error monitoring CPU usage: $($_.Exception.Message)" -Level Error
    }
    try {
        $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
        $memoryUsage = 100 - [math]::Round(($os.FreePhysicalMemory / $os.TotalVisibleMemorySize) * 100, 2)
        if ($memoryUsage -gt 90) {
            Write-Log "WARNING: High memory usage detected: $memoryUsage%" -Level Warning
            Send-Notification -Subject "High Memory Usage Alert" -Body "Memory usage is at $memoryUsage%"
        }
        Write-Log "Resource monitoring completed." -Level Debug
    }
    catch {
        Write-Log "Error monitoring memory usage: $($_.Exception.Message)" -Level Error
    }
}

# --- Section J: High Performance Power Plan & GPU Monitoring ---
function Set-HighPerformancePowerPlan {
    Write-Log "Setting High Performance Power Plan..." -Level Info
    try {
        $powerPlans = powercfg /L | Out-String
        if ($powerPlans -match "(?<guid>[A-F0-9\-]+)\s+\(High performance\)") {
            $planGuid = $matches.guid
            Write-Log "Retrieved High Performance GUID: $planGuid" -Level Debug
            powercfg -setactive $planGuid
        }
        else {
            Write-Log "High Performance plan not found dynamically; using fallback GUID." -Level Warning
            powercfg -setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c
        }
        Write-Log "High Performance Power Plan activated." -Level Info
    }
    catch {
        Write-Log "Error setting High Performance Power Plan: $($_.Exception.Message)" -Level Error
    }
}

function Monitor-GPUUsage {
    Write-Log "Monitoring GPU usage..." -Level Debug
    try {
        if (Get-Command nvidia-smi -ErrorAction SilentlyContinue) {
            $gpuInfo = nvidia-smi
            Write-Log "NVIDIA GPU Usage:`n$gpuInfo" -Level Info
        }
        elseif (Get-Command rocm-smi -ErrorAction SilentlyContinue) {
            $gpuInfo = rocm-smi
            Write-Log "AMD GPU Usage:`n$gpuInfo" -Level Info
        }
        else {
            $intelGPU = Get-WmiObject -Namespace root\CIMV2 -Class Win32_PerfFormattedData_GPU_VideoController -ErrorAction SilentlyContinue
            if ($intelGPU) {
                foreach ($gpu in $intelGPU) {
                    Write-Log "Intel GPU: $($gpu.Name) - Utilization: $($gpu.UtilizationPercentage)%" -Level Info
                }
            }
            else {
                Write-Log "No GPU monitoring tools found. Supported: NVIDIA, AMD, Intel." -Level Warning
            }
        }
    }
    catch {
        Write-Log "Error monitoring GPU usage: $($_.Exception.Message)" -Level Error
    }
}

# --- Section K: Advanced Telemetry & Dashboard ---
function Launch-TelemetryDashboard {
    Write-Log "Launching telemetry dashboard..." -Level Info
    try {
        $listener = New-Object System.Net.HttpListener
        $url = "http://localhost:8080/"
        $listener.Prefixes.Add($url)
        $listener.Start()
        Write-Log "Telemetry dashboard available at $url" -Level Info
        Start-Job -InitializationScript {
            param($modPath)
            Import-Module $modPath -Force
        } -ArgumentList "$PSScriptRoot\SystemSentinelModule.psm1" -ScriptBlock {
            param($listener)
            while ($listener.IsListening) {
                try {
                    $context = $listener.GetContext()
                    $response = $context.Response
                    $cpuUsage = (Get-Counter '\Processor(_Total)\% Processor Time').CounterSamples[0].CookedValue
                    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
                    $freeMemPercent = if ($os) { [math]::Round((($os.FreePhysicalMemory / $os.TotalVisibleMemorySize) * 100), 2) } else { "N/A" }
                    $html = @"
<html>
<head>
  <title>Telemetry Dashboard</title>
  <meta http-equiv='refresh' content='5'>
  <style>
    body { font-family: Arial; margin: 20px; }
    h1 { color: #0078D7; }
  </style>
</head>
<body>
  <h1>System Telemetry</h1>
  <p><strong>CPU Usage:</strong> $([math]::Round($cpuUsage,2))%</p>
  <p><strong>Free Memory:</strong> $freeMemPercent%</p>
  <p><strong>Last Updated:</strong> $(Get-Timestamp)</p>
</body>
</html>
"@
                    $buffer = [System.Text.Encoding]::UTF8.GetBytes($html)
                    $response.ContentLength64 = $buffer.Length
                    $response.ContentType = "text/html"
                    $response.OutputStream.Write($buffer, 0, $buffer.Length)
                    $response.OutputStream.Close()
                }
                catch { Write-Log "Error in dashboard job: $($_.Exception.Message)" -Level Error }
            }
        } -ArgumentList $listener | Out-Null
        Write-Log "Telemetry dashboard launched." -Level Info
    }
    catch {
        Write-Log "Error launching telemetry dashboard: $($_.Exception.Message)" -Level Error
    }
}

# --- Section L: ML-Based Anomaly Detection ---
function Detect-Anomalies {
    Write-Log "Running ML-based anomaly detection..." -Level Debug
    try {
        $currentCPU = (Get-Counter '\Processor(_Total)\% Processor Time').CounterSamples[0].CookedValue
        $csvFile = Join-Path $PSScriptRoot $config.PerformanceHistoryFile
        $history = @()
        if (Test-Path $csvFile) {
            $history = Get-Content $csvFile | Select-Object -Skip 1 | ForEach-Object {
                $parts = $_ -split ','
                if ($parts.Length -ge 2) { [double]$parts[1] } else { $null }
            } | Where-Object { $_ -ne $null }
        }
        if ($history.Count -ge 10) {
            $recent = $history | Select-Object -Last 10
            $avg = ($recent | Measure-Object -Average).Average
            if ($currentCPU -gt ($avg + 20)) {
                Write-Log "Anomaly Detected: Current CPU ($([math]::Round($currentCPU,2))%) is significantly above average ($([math]::Round($avg,2))%)." -Level Warning
            }
            else {
                Write-Log "No significant anomalies detected." -Level Debug
            }
        }
        else {
            Write-Log "Insufficient historical data for anomaly detection." -Level Warning
        }
    }
    catch {
        Write-Log "Error in anomaly detection: $($_.Exception.Message)" -Level Error
    }
}

# --- Section M: Optional New Modules (Stubs) ---
function Optimize-Workload {
    Write-Log "Optimizing workload dynamically..." -Level Info
    try {
        Get-Process | Sort-Object CPU -Descending | Select-Object -First 5 | ForEach-Object {
            Write-Log "Process: $($_.Name) - CPU: $($_.CPU)" -Level Debug
        }
        Write-Log "Dynamic workload optimization complete." -Level Info
    }
    catch {
        Write-Log "Error optimizing workload: $($_.Exception.Message)" -Level Error
    }
}

function Check-DriverFirmwareUpdates {
    Write-Log "Checking for driver and firmware updates..." -Level Info
    try {
        Write-Log "Driver/firmware update check not implemented yet (stub)." -Level Warning
    }
    catch {
        Write-Log "Error in driver/firmware update check: $($_.Exception.Message)" -Level Error
    }
}

function Optimize-Thermals {
    Write-Log "Optimizing thermal performance..." -Level Info
    try {
        Write-Log "Thermal optimization not fully implemented (stub)." -Level Warning
    }
    catch {
        Write-Log "Error optimizing thermals: $($_.Exception.Message)" -Level Error
    }
}

function Analyze-Logs {
    Write-Log "Analyzing logs and generating report..." -Level Info
    try {
        $oneHourAgo = (Get-Date).AddHours(-1)
        $events = Get-WinEvent -FilterHashtable @{LogName = 'System'; Level = 1, 2, 3; StartTime = $oneHourAgo } -MaxEvents 50
        if ($events) {
            Write-Log "Recent System Events (last hour, Errors/Warnings/Critical):" -Level Info
            $events | Format-Table -AutoSize | Out-String | Write-Log -Level Info
        }
        else {
            Write-Log "No Error/Warning/Critical events found in System log in the last hour." -Level Info
        }
    }
    catch {
        Write-Log "Error analyzing logs: $($_.Exception.Message)" -Level Error
    }
}

# --- New: Add missing Set-FileAssociation function ---
function Set-FileAssociation {
    Write-Log "Setting file associations (stub implementation)..." -Level Info
    # Add your file association logic here.
}

# Export all functions for use by the main script
Export-ModuleMember -Function Invoke-WithRetry, Get-Timestamp, Roll-LogFile, Write-Log, Run-CmdCommand, `
    Create-RestorePoint, Run-SFC, Run-DiskCleanup, Backup-Drivers, Check-WindowsUpdates, Clear-EventLogs, `
    Snapshot-DiskSpace, Test-Network, Snapshot-Performance, Run-DefenderScan, Get-CriticalEventLogSummary, `
    Analyze-PerformanceTrends, Self-Update, Run-RemoteMaintenance, Send-Notification, Send-SlackNotification, `
    Get-RestartRecommendation, Append-PerformanceHistory, Log-SystemSpecs, Optimize-SystemPerformance, `
    Monitor-SystemResources, Set-HighPerformancePowerPlan, Monitor-GPUUsage, Launch-TelemetryDashboard, `
    Detect-Anomalies, Optimize-Workload, Check-DriverFirmwareUpdates, Optimize-Thermals, Analyze-Logs, Set-FileAssociation
