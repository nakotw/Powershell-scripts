# Output tool banner after all ASCII art.
Write-Host ""
Write-Host "`tTool    :: Fix-MDM-aadj" -ForegroundColor Magenta
Write-Host "`tAuthor  :: Florian Daminato" -ForegroundColor Magenta
Write-Host "`tCompany  :: Micro Logic" -ForegroundColor Magenta
Write-Host ""
    
#Fix device AADJ but not MDM

$registryPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\MDM"
echo "$registryPath"
New-Item -Path $registryPath

$Name = "AutoEnrollMDM"
$Name2 = "UseAADCredentialType"
$value = "1"

new-ItemProperty -Path $registryPath -Name $name -Value $value -PropertyType DWORD -Force | Out-Null
new-ItemProperty -Path $registryPath -Name $name2 -Value $value -PropertyType DWORD -Force | Out-Null
gpupdate /force

$key = 'SYSTEM\CurrentControlSet\Control\CloudDomainJoin\TenantInfo\*'
$keyinfo = Get-Item "HKLM:\$key"
$url = $keyinfo.name
$url = $url.Split("\")[-1]
$path = "HKLM:\SYSTEM\CurrentControlSet\Control\CloudDomainJoin\TenantInfo\$url"

New-ItemProperty -LiteralPath $path -Name 'MdmEnrollmentUrl' -Value 'https://enrollment.manage.microsoft.com/enrollmentserver/discovery.svc' -PropertyType String -Force -ea SilentlyContinue;
New-ItemProperty -LiteralPath $path  -Name 'MdmTermsOfUseUrl' -Value 'https://portal.manage.microsoft.com/TermsofUse.aspx' -PropertyType String -Force -ea SilentlyContinue;
New-ItemProperty -LiteralPath $path -Name 'MdmComplianceUrl' -Value 'https://portal.manage.microsoft.com/?portalAction=Compliance' -PropertyType String -Force -ea SilentlyContinue;

#Call enrollment with psexec to use SYSTEM context

Write-Host "Downloading pstools" -ForegroundColor Yellow
Invoke-RestMethod -Uri 'https://download.sysinternals.com/files/PSTools.zip' -OutFile $env:TEMP\PSTools.zip
Write-Host "Extracting psexec.exe from archive" -ForegroundColor Yellow
Expand-Archive -Path $env:TEMP\PSTools.zip -DestinationPath $env:TEMP\PSTools -Force

##################################
# Force reenrollment with psexec #
##################################

Write-Host "Starting psexec.exe with DeviceEnroller and AutoEnrollMDM command" -ForegroundColor Yellow
$Process = Start-Process -FilePath $env:TEMP\PSTools\psexec.exe -ArgumentList "-i -s -accepteula cmd  /c `"deviceenroller.exe /c /AutoEnrollMDM`"" -Wait -NoNewWindow -PassThru
if ($process.ExitCode -eq 0) {
    Write-Host "Device enrollment and AutoEnrollMDM started" -ForegroundColor Green

}
else {
    Write-Host "Error! Please verify manually" -ForegroundColor Red
}
if ((Get-Service *intune*).Status -ne 'Running') {
    Get-Service *intune* | Start-Service
    Write-Host "Starting Intune Service"
}