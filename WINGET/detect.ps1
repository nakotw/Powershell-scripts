<#

Name:           detect.ps1
Description:    Detection script for Winget app

Change $PackageName on line 17 with package ID

Exemple : $PackageName = "VideoLAN.VLC"

{\__/}
( •.•)
/ > 🍪  u want this cookie ?

#>

#Fill this variable with the Winget package ID
$PackageName = "ShareX.ShareX"

#Start Logging
Start-Transcript -Path "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\$($PackageName)_detect.log" -Append 

try {
Write-host "Checking Winget Path"
$ResolveWingetPath = Resolve-Path "C:\Program Files\WindowsApps\Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe"
    if ($ResolveWingetPath){
           $WingetPath = $ResolveWingetPath[-1].Path
    }

$config
Write-host $ResolveWingetPath
Write-Host $WingetPath
cd $wingetpath


$CheckPSUpdate = Join-Path $env:ProgramData IntuneScripts\$PackageName.ps1
$CheckDir = Test-Path $CheckPSUpdate

Write-Host $CheckDir 


$InstalledApps = .\winget.exe list --id $PackageName --accept-source-agreements --accept-package-agreements
}
Catch { 
    Throw "Failed to detect $($PackageName)"
    }

if ($InstalledApps -eq "No installed package found matching input criteria.") {
    Write-Host "$($PackageName) is not installed"
    Stop-Transcript
    Exit 1
}


else {
If ($CheckDir -eq $False)
        {
        Write-Host "$($PackageName).ps1 not found"
        Stop-Transcript
        Exit 1
        }



    
}
