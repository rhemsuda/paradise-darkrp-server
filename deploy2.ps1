param (
    [string]$RepoUrl = "https://github.com/rhemsuda/paradise-darkrp-server.git",
    [string]$LocalPath = "C:\code\garrysmod\paradise-darkrp-server",
    [string]$SftpHost = "64.74.161.162",
    [int]$SftpPort = 8822,
    [string]$SftpUser = "nicholas36",
    [string]$SftpPass = $env:PDRP_SFTP_PASS,
    [string]$RemotePath = "/64.74.161.162_27055/garrysmod",
    [string]$Branch = "main"
)

$foldersToUpdate = @("addons", "backgrounds", "cfg", "gamemodes", "html", "lua", "maps", "particles", "materials", "models", "sound", "materials", "scenes", "settings")


if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Error "Git is not installed. Please install it from git-scm.com."
    exit 1
}


function Get-CurrentBranch {
    try {
        return (git rev-parse --abbrev-ref HEAD)
    } catch {
        Write-Warning "Could not detect current branch. Using default: $Branch"
        return $Branch
    }
}


if (Test-Path $LocalPath) {
    Write-Host "Updating local repository..."
    Set-Location $LocalPath
    if (-not $Branch) {
        $currentBranch = Get-CurrentBranch
        $Branch = $currentBranch
    }
    git fetch origin
    git checkout $Branch
    git pull origin $Branch
} else {
    Write-Host "Cloning repository..."
    git clone $RepoUrl $LocalPath
    Set-Location $LocalPath
    if (-not $Branch) {
        $Branch = "main"
    }
    git checkout $Branch
}

Add-Type -Path "C:\Program Files (x86)\WinSCP\WinSCPnet.dll"

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

    # Delete all files/folders in /garrysmod/ except data files
    Write-Host "Deleting existing /garrysmod/ contents (excluding data files)..."
    foreach ($folder in $foldersToUpdate) {
        Write-Host "Attempt Removing $RemotePath/$folder..."
        Write-Host $session.FileExists("$RemotePath/$folder")
        if ($session.FileExists("$RemotePath/$folder")) {
            Write-Host "Removing /$folder..."
            $session.RemoveFiles("$RemotePath/$folder/*").Check()
            $session.RemoveFiles("$RemotePath/$folder").Check()
        }
    }

    Write-Host "Uploading /garrysmod/ contents from branch '$Branch'..."
    $transferOptions = New-Object WinSCP.TransferOptions
    $transferOptions.FileMask = "|.git/sv.db;data/"
    $transferResult = $session.PutFiles("$LocalPath\*", $RemotePath, $true, $transferOptions)
    $transferResult.Check()

    Write-Host "Deployment complete! Files uploaded from branch '$Branch':"
    foreach ($transfer in $transferResult.Transfers) {
        Write-Host $transfer.FileName
    } 
} catch {
    Write-Error "Error during deployment: $_"
} finally {
    $session.Dispose()
}
