<#

Name:           IntuneWinget.ps1
Description:    Use Winget to deploy app on devices

Example:

powershell -executionpolicy bypass -file IntuneWinget.ps1 -Install VideoLAN.VLC
powershell -executionpolicy bypass -file IntuneWinget.ps1 -Uninstall VideoLAN.VLC

{\__/}
( •.•)
/ > 🍪  u want this cookie ?

#>


Param(
    [switch]$Install,
    [switch]$Uninstall,
    $PackageName
)

if ($Install) {
$AppInstaller = Get-AppxProvisionedPackage -Online | Where-Object DisplayName -eq Microsoft.DesktopAppInstaller

#Start Logging
Start-Transcript -Path "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\$($PackageName)_Install.log" -Append

If($AppInstaller.Version -lt "2022.506.16.0") {

    Write-Host "Winget is not installed, trying to install latest version from Github" -ForegroundColor Yellow

    Try {
    Write-Host "Creating Winget Packages Folder" -ForegroundColor Yellow

        if (!(Test-Path -Path C:\ProgramData\WinGetPackages)) {
            New-Item -Path C:\ProgramData\WinGetPackages -Force -ItemType Directory
        }

        Set-Location C:\ProgramData\WinGetPackages

#Downloading Packagefiles
        #Microsoft.UI.Xaml.2.7.0
        Invoke-WebRequest -Uri "https://www.nuget.org/api/v2/package/Microsoft.UI.Xaml/2.7.0" -OutFile "C:\ProgramData\WinGetPackages\microsoft.ui.xaml.2.7.0.zip"
        Expand-Archive C:\ProgramData\WinGetPackages\microsoft.ui.xaml.2.7.0.zip -Force
        #Microsoft.VCLibs.140.00.UWPDesktop
        Invoke-WebRequest -Uri "https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx" -OutFile "C:\ProgramData\WinGetPackages\Microsoft.VCLibs.x64.14.00.Desktop.appx"
        #Winget
        Invoke-WebRequest -Uri "https://github.com/microsoft/winget-cli/releases/latest/download/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle" -OutFile "C:\ProgramData\WinGetPackages\Winget.msixbundle"
        #Installing dependencies + Winget
        Add-ProvisionedAppxPackage -online -PackagePath:.\Winget.msixbundle -DependencyPackagePath .\Microsoft.VCLibs.x64.14.00.Desktop.appx,.\microsoft.ui.xaml.2.7.0\tools\AppX\x64\Release\Microsoft.UI.Xaml.2.7.Appx -SkipLicense

        Write-Host "Starting sleep for Winget to initiate" -Foregroundcolor Yellow
        Start-Sleep 2
    }
    Catch {
        Throw "Failed to install Winget"
        Break
    }

    }
Else {
    Write-Host "Winget already installed, moving on" -ForegroundColor Green
}


#Trying to install Package with Winget
IF ($PackageName){
    try {
        Write-Host "Installing $($PackageName) via Winget" -ForegroundColor Green

        $ResolveWingetPath = Resolve-Path "C:\Program Files\WindowsApps\Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe"
        if ($ResolveWingetPath){
               $WingetPath = $ResolveWingetPath[-1].Path
        }
    
        $config
        cd $wingetpath
        $InstalledApps = .\winget.exe list --id $PackageName --accept-source-agreements --accept-package-agreements

        if ($InstalledApps -eq "No installed package found matching input criteria.") {
             Write-Host "$($PackageName) is not installed"
               .\winget.exe install $PackageName --silent --accept-source-agreements --accept-package-agreements }
        else {}
       
        
        


$content = @"
# Goto Winget install dir
cd "C:\Program Files\WindowsApps\Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe"
.\winget.exe upgrade $PackageName --silent --force --accept-package-agreements --accept-source-agreements 
#### Remove shortcut on public desktop.
    Get-childitem -Path "C:\Users\Public\Desktop\*.lnk" -recurse | where-object {$_.lastwritetime -gt (get-date).addDays(-1) -and -not $_.PSIsContainer} | Remove-Item -Force
    
"@

# create custom folder and write PS script
$path = $(Join-Path $env:ProgramData IntuneScripts)
if (!(Test-Path $path))
{
New-Item -Path $path -ItemType Directory -Force -Confirm:$false
}
Out-File -FilePath $(Join-Path $env:ProgramData IntuneScripts\$PackageName.ps1) -Encoding unicode -Force -InputObject $content -Confirm:$false
 
# register script as scheduled task
$Time = New-ScheduledTaskTrigger -AtLogOn
$User = "SYSTEM"
$Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ex bypass -file `"C:\ProgramData\IntuneScripts\$PackageName.ps1`""
Register-ScheduledTask -TaskPath "INTUNE" -TaskName "Upgrade$PackageName" -Trigger $Time -User $User -Action $Action -Force
Start-ScheduledTask -TaskPath "INTUNE" -TaskName "Upgrade$PackageName"

    }
    Catch {
        Throw "Failed to install package $($_)"
    }
#### Remove shortcut on public desktop.
Get-childitem -Path "C:\Users\Public\Desktop\*.lnk" -recurse | where-object {$_.lastwritetime -gt (get-date).addDays(-1) -and -not $_.PSIsContainer} | Remove-Item -Force


}
Else {
    Write-Host "Package $($PackageName) not available" -ForegroundColor Yellow
}
Stop-Transcript
}






















if ($Uninstall) {

#Start Logging
Start-Transcript -Path "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\$($PackageName)_Uninstall.log" -Append

#Detect Apps
$InstalledApps = winget list --id $PackageName

if ($InstalledApps) {
    
    Write-Host "Trying to uninstall $($PackageName)"
    
    try {        
        $ResolveWingetPath = Resolve-Path "C:\Program Files\WindowsApps\Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe"
        if ($ResolveWingetPath){
               $WingetPath = $ResolveWingetPath[-1].Path
        }
    
        $config
        cd $wingetpath

        .\winget.exe uninstall $PackageName --silent --accept-source-agreements --accept-package-agreements

        
    ## Remove scheduled Task
    Write-Host "Trying to remove Upgrade$($PackageName) Scheduled Task"
    Unregister-ScheduledTask -TaskName "Upgrade$PackageName" -Confirm:$false

    ## Remove PS 
    Write-Host "Trying to remove Powershell Script"
    $todelete = Join-Path $env:ProgramData IntuneScripts\$PackageName.ps1 
    Remove-Item -Path $todelete -Recurse -Force

    }
    catch {
        Throw "Failed to uninstall $($PackageName)"
    }
}
else {
    Write-Host "$($PackageName) is not installed or detected"
}

Stop-Transcript



}
Remove-Variable * -ErrorAction SilentlyContinue