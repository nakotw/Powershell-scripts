
# Fix intune enrollment - Florian Daminato - IT Architect - Micro Logic
# Execute as admin in powershell


$Global:ErrorActionPreference = 'Stop'

#######################
# Stop Intune service #
#######################

Write-Host "Stopping Intune Service" -ForegroundColor Yellow
Get-Service *intune* | Stop-Service

#####################
# Check AADJ status #
#####################

Write-Host "Check if device is AAD Joined" -ForegroundColor Yellow
$DSREGCMD = dsregcmd /status
$AADJoinCheck = $null
$AADJoinCheck = $DSREGCMD | Select-String -Pattern 'AzureAdJoined : YES'
if ($null -eq $AADJoinCheck) {
	Write-Host "Device is not AAD Joined!!! Stopping!" -ForegroundColor Red
	Break
} else {
	Write-Host "Device is AAD joined - OK" -ForegroundColor Green
}

###########################
# Searching enrollment ID #
###########################

Write-Host "Searching for enrollment ID"
$Tasks = Get-ScheduledTask | Where-Object { $psitem.TaskPath -like "\Microsoft\Windows\EnterpriseMgmt\*" }


# Option 1

#$EnrollId = $Tasks[0].TaskPath.Split('\\')[-2]

# Option 2 à prendre si l'option 1 fail et retourne du texte au lieu d'un ID au format XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX

$IDintune = Get-ChildItem "c:\programdata\microsoft\dmclient"
$EnrollId = $IDintune.name

##########################
# Checking enrollment ID #
##########################

if ($EnrollID -match '\w{8}-\w{4}-\w{4}-\w{4}-\w{12}') {
	Write-Host "Found EnrollID - $EnrollID" -ForegroundColor Green
} else {
	Write-Host "Error! No EnrollmentID found" -ForegroundColor Red
	Add-Type -AssemblyName Microsoft.VisualBasic
	$EnrollID = [Microsoft.VisualBasic.Interaction]::InputBox("Enter schedulted task \Microsoft\Windows\EnterpriseMgmt\ ID value. Value is formated as XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX", "")
	Break
}

######################################
# Removing enrollment scheduledTasks #
######################################

Write-Host "Removing scheduledTasks" -ForegroundColor Yellow
Try {
	$Tasks | ForEach-Object { Unregister-ScheduledTask -InputObject $psitem -Verbose -Confirm:$false }
} catch {
	Throw $_.Exception.Message
}
Write-Host "Scheduled tasks removed" -ForegroundColor Green

#############################################
# Removing enrollment scheduledTasks folder #
#############################################

Write-Host "Trying to remove task folder" -ForegroundColor Yellow
$TaskFolder = Test-Path "C:\windows\System32\Tasks\Microsoft\Windows\EnterpriseMgmt\$EnrollID"
try {
	if ($TaskFolder) {
		Remove-Item -Path "C:\windows\System32\Tasks\Microsoft\Windows\EnterpriseMgmt\$EnrollID" -Force -Verbose
		Write-Host "Tasks folder removed" 
	}
} catch {
	Throw $_.Exception.Message
}

#####################
# Cleaning registry #
#####################

Write-Host "Removing enrollment registry keys" -ForegroundColor Yellow
$EnrollmentReg = Test-Path -Path HKLM:\SOFTWARE\Microsoft\Enrollments\$EnrollID
if ($EnrollmentReg) {
	Remove-Item -Path HKLM:\SOFTWARE\Microsoft\Enrollments\$EnrollID -Recurse -Force -Verbose 
}
$EnrollmentReg = Test-Path -Path HKLM:\SOFTWARE\Microsoft\Enrollments\Status\$EnrollID
if ($EnrollmentReg) {
	Remove-Item -Path HKLM:\SOFTWARE\Microsoft\Enrollments\Status\$EnrollID -Recurse -Force -Verbose 
}
$EnrollmentReg = Test-Path -Path HKLM:\SOFTWARE\Microsoft\EnterpriseResourceManager\Tracked\$EnrollID
if ($EnrollmentReg) {
	Remove-Item -Path HKLM:\SOFTWARE\Microsoft\EnterpriseResourceManager\Tracked\$EnrollID -Recurse -Force -Verbose 
}
$EnrollmentReg = Test-Path -Path HKLM:\SOFTWARE\Microsoft\PolicyManager\AdmxInstalled\$EnrollID
if ($EnrollmentReg) {
	Remove-Item -Path HKLM:\SOFTWARE\Microsoft\PolicyManager\AdmxInstalled\$EnrollID -Recurse -Force -Verbose 
}
$EnrollmentReg = Test-Path -Path HKLM:\SOFTWARE\Microsoft\PolicyManager\Providers\$EnrollID
if ($EnrollmentReg) {
	Remove-Item -Path HKLM:\SOFTWARE\Microsoft\PolicyManager\Providers\$EnrollID -Recurse -Force -Verbose 
}
$EnrollmentReg = Test-Path -Path HKLM:\SOFTWARE\Microsoft\Provisioning\OMADM\Accounts\$EnrollID
if ($EnrollmentReg) {
	Remove-Item -Path HKLM:\SOFTWARE\Microsoft\Provisioning\OMADM\Accounts\$EnrollID -Recurse -Force -Verbose 
}
$EnrollmentReg = Test-Path -Path HKLM:\SOFTWARE\Microsoft\Provisioning\OMADM\Logger\$EnrollID
if ($EnrollmentReg) {
	Remove-Item -Path HKLM:\SOFTWARE\Microsoft\Provisioning\OMADM\Logger\$EnrollID -Recurse -Force -Verbose 
}
$EnrollmentReg = Test-Path -Path HKLM:\SOFTWARE\Microsoft\Provisioning\OMADM\Sessions\$EnrollID
if ($EnrollmentReg) {
	Remove-Item -Path HKLM:\SOFTWARE\Microsoft\Provisioning\OMADM\Sessions\$EnrollID -Recurse -Force -Verbose 
}
##### Run this if Remove-Item -Path "C:\windows\System32\Tasks\Microsoft\Windows\EnterpriseMgmt\$EnrollID" -Force -Verbose FAILED
<#
$EnrollmentReg = Test-Path -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tree\Microsoft\Windows\EnterpriseMgmt\$EnrollID"
if ($EnrollmentReg) {
	Remove-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tree\Microsoft\Windows\EnterpriseMgmt\$EnrollID" -Recurse -Force -Verbose 
}
#>

#########################################
# Cleaning local enrollment certificate #
#########################################

Write-Host "Checking for local Intune MDM certificate" -ForegroundColor Yellow
$Certs = $null
$Certs = Get-ChildItem -Path cert:\LocalMachine\My | Where-Object { $psitem.issuer -like '*Intune*' }
if ($null -ne $Certs) {
	$(Get-Item ($Certs).PSPath) | Remove-Item -Force -Verbose 
	Write-Host "Removed" -ForegroundColor Green
} else {
	Write-Host "Not found" -ForegroundColor Yellow
}

###################################################################
# Downloading psexec to simulate system account program execution #
###################################################################

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

} else {
	Write-Host "Error! Please verify manually" -ForegroundColor Red
}
if ((Get-Service *intune*).Status -ne 'Running') {
	Get-Service *intune* | Start-Service
    Write-Host "Starting Intune Service"
}