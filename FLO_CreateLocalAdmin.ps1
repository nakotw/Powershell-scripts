#Password generation function with random password, for LAPS
Function GenerateStrongPassword ([Parameter(Mandatory=$true)][int]$PasswordLenght)
{
Add-Type -AssemblyName System.Web
$PassComplexCheck = $false
do {
$newPassword=[System.Web.Security.Membership]::GeneratePassword($PasswordLenght,1)
If ( ($newPassword -cmatch "[A-Z\p{Lu}\s]") `
-and ($newPassword -cmatch "[a-z\p{Ll}\s]") `
-and ($newPassword -match "[\d]") `
-and ($newPassword -match "[^\w]")
)
{
$PassComplexCheck=$True
}
} While ($PassComplexCheck -eq $false)
return $newPassword
}
#Generate a secure password and convert is to a secure string
$Password = GenerateStrongPassword (14)
$SecurePassword = ConvertTo-SecureString $Password -AsPlainText -Force

#Create the local account with the secure password and add it to the Administrators group by SID
$username = "supportti"

$user = Get-LocalUser | Where-Object { $_.Name -eq "$username" }
if ( -not $user)
 {
    New-LocalUser -Name "$username" -Description "TI support account" -AccountNeverExpires -Password $SecurePassword
 }

$localgroup = Get-LocalGroup | Where-Object {$_.Name -eq "administrateurs"}
if ( -not $localgroup)
 {
    Add-LocalGroupMember -Group "Administrators" -Member "$username"
 }else {
    Add-LocalGroupMember -Group "Administrateurs" -Member "$username"
 }

#Cleanup for security reasons
Clear-Variable -Name Password -ErrorAction SilentlyContinue
Clear-Variable -Name newPassword -ErrorAction SilentlyContinue
Clear-Variable -Name SecurePassword -ErrorAction SilentlyContinue
Remove-Variable -Name Password -ErrorAction SilentlyContinue
Remove-Variable -Name newPassword -ErrorAction SilentlyContinue
Remove-Variable -Name SecurePassword -ErrorAction SilentlyContinue
