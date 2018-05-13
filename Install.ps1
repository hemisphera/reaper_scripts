if (-not (([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)))
{
    $arguments = "& '" + $myinvocation.mycommand.definition + "'"
    Start-Process powershell -Verb runAs -ArgumentList $arguments
    Break
}

try
{
    $ErrorActionPreference = "Stop"

    $ReaperResBaseFolder = "$env:APPDATA\REAPER"
    if (-not (Test-Path $ReaperResBaseFolder)) {
        throw "REAPER default resource folder ($ReaperResBaseFolder) not found."
    }

    $Subfolders = Get-ChildItem $PSScriptRoot -Directory
    foreach ($Subfolder in $Subfolders) {
        $ReaperFolder = "$ReaperResBaseFolder\$($Subfolder.Name)\Hemisphera"
        if (Test-Path $ReaperFolder) {
            Write-Host "Deleting existing folder '$ReaperFolder'"

            # Resorting to System.IO because Remove-Item apparently is bugged
            [IO.Directory]::Delete($ReaperFolder)
        }
        Write-Host "Creating link from '$ReaperFolder' to '$($Subfolder.FullName)'"
        New-Item -ItemType SymbolicLink -Path $ReaperFolder -Value $Subfolder.FullName | out-null
    }

    Write-Host -ForegroundColor Green "Successfully completed."
}
catch
{
    Write-Host -ForegroundColor Red $_
}
Write-Host "Press ENTER to exit"
Read-Host
