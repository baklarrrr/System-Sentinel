# SystemSentinel.ps1

# ADD THIS LINE AT THE VERY TOP, RIGHT AFTER THE INITIAL COMMENTS:
Start-Sleep -Seconds 5

# -- Add this at the top --
# Detect PyInstaller bundle environment
if ($env:_MEIPASS) {
    $global:BundleMode = $true
    $global:RootPath = $env:_MEIPASS
}
else {
    $global:BundleMode = $false
    $global:RootPath = $PSScriptRoot
}

  # Get the correct path regardless of PyInstaller context
  $scriptPath = $PSScriptRoot
  if (-not $scriptPath) {
      $scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
  }

  # Use Join-Path for reliable path construction
  $modulePath = Join-Path -Path $scriptPath -ChildPath "SystemSentinelModule.psm1"

  # Add verbose logging for troubleshooting
  Write-Host "Loading from: $modulePath"

  # Import module with error handling
  if (Test-Path $modulePath) {
      Import-Module $modulePath -Force -Verbose
  } else {
      throw "Module not found at: $modulePath"
  }
# Ensure $PSScriptRoot is defined (for older PowerShell versions)
if (-not $PSScriptRoot) {
    # Fallback for PS < 3.0
    $PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
}

# Load configuration from JSON file
$configFile = Join-Path $PSScriptRoot "SystemSentinelConfig.json"
if (Test-Path $configFile) {
    $config = Get-Content $configFile | ConvertFrom-Json
}
else {
    Throw "Configuration file not found: $configFile"
}

# Set global logging variables from configuration
$global:LogFile           = Join-Path $PSScriptRoot $config.LogFileName
$global:MaxLogFileSizeMB  = $config.MaxLogFileSizeMB
$global:MaxArchivedLogs   = $config.MaxArchivedLogs
    # Determine the folder where this script is located.
    $currentDir = Split-Path -Parent $MyInvocation.MyCommand.Path

    # Form the full path of the module file.
    $moduleFile = Join-Path $currentDir 'SystemSentinelModule.psm1'

    # Check if the module file exists.
    if (-not (Test-Path $moduleFile)) {
        throw "Module file not found: $moduleFile"
    }

    # Import the module.
    Import-Module -Name $moduleFile -Force -Verbose
# Call functions that are defined in SystemSentinelModule.psm1
Set-FileAssociation

# Log the start of tasks
Write-Log "Initiating System Sentinel tasks concurrently..." -Level Info

# Example try/catch block for starting jobs
try {
    # Placeholder for your background jobs or tasks
    # $job = Start-Job -ScriptBlock { "Performing work..." }
    # Write-Log "Started job: $($job.Name)" -Level Info
}
catch {
    Write-Log "Error starting job: $($_.Exception.Message)" -Level Error
}

Write-Log "System Sentinel tasks completed successfully." -Level Info

# Check for a restart recommendation
$restartAdvice = Get-RestartRecommendation
if ($restartAdvice -match "Restart Recommended") {
    Write-Log "A system restart is recommended." -Level Warning
}
else {
    Write-Log "No restart required at this time." -Level Info
}

# Append performance history and log system specifications
Append-PerformanceHistory
Log-SystemSpecs

# Wait for user input before exiting
Read-Host "Press Enter to exit the System Sentinel script"
