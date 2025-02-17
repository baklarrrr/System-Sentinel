################################################################################
# Name: Fix-SentinalToSentinel.ps1
# Description: GUI to select the "System Sentinal" folder, then rename 
#              "Sentinal" to "Sentinel" in folder names, file names, 
#              and file contents.
#
# IMPORTANT: This creates .bak backups when modifying file contents.
#            Verify the results, then remove .bak files if all is correct.
################################################################################

Add-Type -AssemblyName System.Windows.Forms

function Get-FolderSelection {
    [System.Windows.Forms.Application]::EnableVisualStyles()
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = "Select your 'System Sentinal' folder."
    $dialog.ShowNewFolderButton = $true

    $result = $dialog.ShowDialog()
    if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
        return $dialog.SelectedPath
    }
    else {
        Write-Host "No folder selected. Exiting..."
        exit
    }
}

function Rename-Path-Safely {
    param (
        [string]$OldPath
    )
    # If the name contains 'Sentinal' (any case), rename to 'Sentinel'
    $oldName = Split-Path $OldPath -Leaf
    $parent  = Split-Path $OldPath -Parent
    if ($oldName -match '(?i)Sentinal') {
        $newName = $oldName -replace '(?i)Sentinal','Sentinel'
        $newPath = Join-Path $parent $newName

        # Ensure we don't overwrite an existing file/folder
        if (Test-Path $newPath) {
            Write-Warning "Cannot rename. '$newPath' already exists."
        }
        else {
            try {
                Rename-Item -Path $OldPath -NewName $newName -ErrorAction Stop
                Write-Host "Renamed:`n$OldPath`n   -> $newPath`n"
                return $newPath
            }
            catch {
                Write-Warning "Failed to rename $OldPath: $($_.Exception.Message)"
            }
        }
    }
    return $OldPath  # if no rename happened
}

function Fix-Folder-And-Files {
    param (
        [string]$RootFolder
    )

    # Step 1: Rename the root folder itself if needed
    $rootAfterRename = Rename-Path-Safely $RootFolder

    # Step 2: Get all subfolders and files, rename them if needed
    #   Use -Depth to ensure we rename from the bottom up (safer).
    $allItems = Get-ChildItem -Path $rootAfterRename -Recurse -Force | Sort-Object FullName -Descending

    foreach ($item in $allItems) {
        # If we rename it, we get the new path for any subsequent operations
        $newPath = Rename-Path-Safely $item.FullName

        # If it's a file, also fix its contents
        if (Test-Path $newPath -PathType Leaf) {
            Fix-FileContents $newPath
        }
    }
}

function Fix-FileContents {
    param (
        [string]$FilePath
    )
    # We can skip binary files (e.g. .png, .ico, .exe) to avoid corruption.
    # Adjust as needed. For now, skip common binary extensions:
    $ext = [System.IO.Path]::GetExtension($FilePath).ToLower()
    $binaryExtensions = ".exe", ".dll", ".ico", ".png", ".jpg", ".jpeg", ".zip", ".pdf"

    if ($binaryExtensions -contains $ext) {
        return  # skip
    }

    # Read text and replace 'Sentinal' with 'Sentinel', ignoring case
    try {
        $content = Get-Content -LiteralPath $FilePath -Raw
        if ($content -match '(?i)Sentinal') {
            $backupPath = "$FilePath.bak"
            Copy-Item $FilePath $backupPath -Force  # Create a backup

            $newContent = $content -replace '(?i)Sentinal','Sentinel'
            Set-Content -LiteralPath $FilePath -Value $newContent

            Write-Host "Updated contents in:`n$FilePath`nBackup: $backupPath`n"
        }
    }
    catch {
        Write-Warning "Failed to process file '$FilePath': $($_.Exception.Message)"
    }
}

################################################################################
#                                MAIN                                          #
################################################################################

Write-Host "Select the folder containing 'System Sentinal'..."
$selected = Get-FolderSelection

if ($selected) {
    Write-Host "Starting rename & content fixes in: $selected"
    Fix-Folder-And-Files -RootFolder $selected
    Write-Host "All done. Review .bak backups and confirm results."
}
