# Make sure you have GitHub CLI (gh) and Git installed.
# This script will create a GitHub repo named "System Sentinel"
# and push your local code to it.

param(
    [string]$RepoName = "System Sentinel",
    [string]$LocalPath = "C:\Users\Bakar\Documents\Powershell Scripts\System Sentinal",
    [switch]$Private  # Use -Private switch if you want the repo to be private
)

# Go to your project folder
Set-Location $LocalPath

# Initialize a local git repository if not already initialized
if (-not (Test-Path "$LocalPath\.git")) {
    git init
}

# Add all files to staging
git add .

# Commit changes
git commit -m "Initial commit"

# Create repository on GitHub
if ($Private) {
    gh repo create "$RepoName" --private --confirm
}
else {
    gh repo create "$RepoName" --public --confirm
}

# Set the remote to the newly created GitHub repo
# By default, gh sets up the remote, but let's ensure it:
$currentRemote = git remote get-url origin 2>$null
if (-not $currentRemote) {
    # The default naming by gh is <github_username>/<RepoName>.git
    # Let’s retrieve it from gh to be safe
    $remoteUrl = gh repo view "$RepoName" --json sshUrl | ConvertFrom-Json | Select-Object -ExpandProperty sshUrl
    git remote add origin $remoteUrl
}

# Push changes
git push -u origin main
