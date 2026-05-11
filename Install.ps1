# Check if running on Windows or Linux/Mac
$IsWindows = $PSVersionTable.Platform -eq "Win32NT" -or -not $PSVersionTable.Platform
$IsLinux = $PSVersionTable.Platform -eq "Linux"
$IsMac = $PSVersionTable.Platform -eq "Darwin"

# Check for elevated privileges (required on Windows only)
if ($IsWindows) {
    if (-not (([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))) {
        throw "This script requires administrator privileges on Windows. Please run as Administrator."
    }
}

try {
    $ErrorActionPreference = "Stop"

    # Determine REAPER resource folder based on OS
    if ($IsWindows) {
        $ReaperResBaseFolder = "$env:APPDATA\REAPER"
    } elseif ($IsLinux) {
        $ReaperResBaseFolder = "$env:HOME/.config/REAPER"
    } elseif ($IsMac) {
        $ReaperResBaseFolder = "$env:HOME/Library/Application Support/REAPER"
    }

    if (-not (Test-Path $ReaperResBaseFolder)) {
        throw "REAPER default resource folder ($ReaperResBaseFolder) not found."
    }

    $Subfolders = Get-ChildItem $PSScriptRoot -Directory
    foreach ($Subfolder in $Subfolders) {
        $ReaperFolder = Join-Path $ReaperResBaseFolder $Subfolder.Name "Hemisphera"
        if (Test-Path $ReaperFolder) {
            Write-Host "Deleting existing folder '$ReaperFolder'"
            [IO.Directory]::Delete($ReaperFolder, $true)
        }
        Write-Host "Creating link from '$ReaperFolder' to '$($Subfolder.FullName)'"
        New-Item -ItemType SymbolicLink -Path $ReaperFolder -Value $Subfolder.FullName | out-null
    }

    Write-Host -ForegroundColor Green "Successfully completed."
}
catch {
    Write-Host -ForegroundColor Red $_
}
Write-Host "Press ENTER to exit"
Read-Host