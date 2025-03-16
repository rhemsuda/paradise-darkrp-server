# deploy.ps1
param (
    [string]$RepoUrl = "https://github.com/rhemsuda/paradise-darkrp-server.git",
    [string]$LocalPath = (Split-Path -Parent $MyInvocation.MyCommand.Path),
    [string]$SftpHost = "64.74.161.162",
    [int]$SftpPort = 8822,
    [string]$SftpUser = "nicholas36",
    [string]$SftpPass = $env:PDRP_SFTP_PASS,
    [string]$RemotePath = "/64.74.161.162_27055/garrysmod",
    [string]$Branch = "master"
)

# Ensure Git is installed
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Error "Git is not installed. Please install it from git-scm.com."
    exit 1
}

# Function to get current local branch
function Get-CurrentBranch {
    try {
        return (git rev-parse --abbrev-ref HEAD)
    } catch {
        Write-Warning "Could not detect current branch. Using default: $Branch"
        return $Branch
    }
}

# Clone or update the repository
if (Test-Path $LocalPath) {
    Write-Host "Updating local repository at $LocalPath..."
    Set-Location $LocalPath
    if (-not $Branch -or $Branch -eq "main") {
        $currentBranch = Get-CurrentBranch
        $Branch = $currentBranch
    }
    git fetch origin
    git checkout $Branch
    git pull origin $Branch
} else {
    Write-Host "Cloning repository to $LocalPath..."
    git clone $RepoUrl $LocalPath
    Set-Location $LocalPath
    if ($Branch -ne "main") {
        git checkout $Branch
    }
}

# Verify local path
if (-not (Test-Path $LocalPath)) {
    Write-Error "Local folder not found at $LocalPath. Check your repo structure."
    exit 1
}

# Load WinSCP .NET assembly
$winscpPath = "C:\Program Files (x86)\WinSCP\WinSCPnet.dll"
if (-not (Test-Path $winscpPath)) {
    Write-Error "WinSCP .NET assembly not found at $winscpPath. Verify WinSCP installation."
    exit 1
}
Add-Type -Path $winscpPath
Write-Host "WinSCP assembly loaded: $($([WinSCP.Session]).Assembly.FullName)"

# Set up session options
$sessionOptions = New-Object WinSCP.SessionOptions -Property @{
    Protocol = [WinSCP.Protocol]::Sftp
    HostName = $SftpHost
    PortNumber = $SftpPort
    UserName = $SftpUser
    Password = $SftpPass
    SshHostKeyFingerprint = $env:PDRP_SFTP_FINGERPRINT
}

$session = New-Object WinSCP.Session

try {
    # Connect to the server
    Write-Host "Connecting to Host Havoc via SFTP..."
    $session.Open($sessionOptions)

    Write-Host "Synchronizing files from $LocalPath to $RemotePath (only modified files)..."

    $transferOptions = New-Object WinSCP.TransferOptions
    $transferOptions.FileMask = "|.git/;sv.db;data/" # Exclude .git locally, sv.db and data/ remotely
    $transferOptions.TransferMode = [WinSCP.TransferMode]::Binary

    $syncCriteria = [WinSCP.SynchronizationCriteria]::Time

    # Sync only changed/updated files
    $syncResult = $session.SynchronizeDirectories(
        [WinSCP.SynchronizationMode]::Remote, 
        $LocalPath,
        $RemotePath,
        $False, 
        $True,
        $syncCriteria,
        $transferOptions
    )

    $syncResult.Check()

    Write-Host "Synchronization complete! Only changed files were uploaded."
} catch {
    Write-Error "Error during deployment: $_"
} finally {
    $session.Dispose()
}