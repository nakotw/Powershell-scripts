#step 1

#Setting up the NIC, Renaming the Computer, and Rebooting
# Define the Computer Name
$computerName = "dc1"

# Define the IPv4 Addressing
$IPv4Address = "10.10.100.25"
$IPv4Prefix = "24"
$IPv4GW = "10.10.100.1"
$IPv4DNS = "8.8.8.8"

# Get the Network Adapter's Prefix
$ipIF = (Get-NetAdapter).ifIndex

# Turn off IPv6 Random & Temporary IP Assignments
Set-NetIPv6Protocol -RandomizeIdentifiers Disabled
Set-NetIPv6Protocol -UseTemporaryAddresses Disabled

# Turn off IPv6 Transition Technologies
Set-Net6to4Configuration -State Disabled
Set-NetIsatapConfiguration -State Disabled
Set-NetTeredoConfiguration -Type Disabled

# Add IPv4 Address, Gateway, and DNS
New-NetIPAddress -InterfaceIndex $ipIF -IPAddress $IPv4Address -PrefixLength $IPv4Prefix -DefaultGateway $IPv4GW
Set-DNSClientServerAddress –interfaceIndex $ipIF –ServerAddresses $IPv4DNS

# Rename the Computer, and Restart
Rename-Computer -NewName $computerName -force
Restart-Computer


#step 2

#Install the ADDS Bits and Promote
$domainName  = "labflo.com"
$netBIOSname = "LABFLO"
$mode  = "Win2012R2"

Install-WindowsFeature AD-Domain-Services -IncludeAllSubFeature -IncludeManagementTools

Import-Module ADDSDeployment

$forestProperties = @{

    DomainName           = $domainName
    DomainNetbiosName    = $netBIOSname
    ForestMode           = $mode
    DomainMode           = $mode
    CreateDnsDelegation  = $false
    InstallDns           = $true
    DatabasePath         = "C:\Windows\NTDS"
    LogPath              = "C:\Windows\NTDS"
    SysvolPath           = "C:\Windows\SYSVOL"
    NoRebootOnCompletion = $false
    Force                = $true

}

Install-ADDSForest @forestProperties


#step 3

#DNS, Sites & Services, and Time Keeping
# Define DNS and Sites & Services Settings
$IPv4netID = "10.10.100.0/24"
$siteName = "LAB"
$location = "Lab City"

# Define Authoritative Internet Time Servers
$timePeerList = "0.us.pool.ntp.org 1.us.pool.ntp.org"

# Add DNS Reverse Lookup Zones
Add-DNSServerPrimaryZone -NetworkID $IPv4netID -ReplicationScope 'Forest' -DynamicUpdate 'Secure'

# Make Changes to Sites & Services
$defaultSite = Get-ADReplicationSite | Select DistinguishedName
Rename-ADObject $defaultSite.DistinguishedName -NewName $siteName
New-ADReplicationSubnet -Name $IPv4netID -site $siteName -Location $location

# Re-Register DC's DNS Records
Register-DnsClient

# Enable Default Aging/Scavenging Settings for All Zones and this DNS Server
Set-DnsServerScavenging –ScavengingState $True –ScavengingInterval 7:00:00:00 –ApplyOnAllZones
$Zones = Get-DnsServerZone | Where-Object {$_.IsAutoCreated -eq $False -and $_.ZoneName -ne 'TrustAnchors'}
$Zones | Set-DnsServerZoneAging -Aging $True

# Set Time Configuration
w32tm /config /manualpeerlist:$timePeerList /syncfromflags:manual /reliable:yes /update


#step 4

#Build an OU Structure
$baseDN = "DC=LABFLO,DC=com"
$resourcesDN = "OU=Resources," + $baseDN

New-ADOrganizationalUnit "Resources" -path $baseDN
New-ADOrganizationalUnit "Admin Users" -path $resourcesDN
New-ADOrganizationalUnit "Groups Security" -path $resourcesDN
New-ADOrganizationalUnit "Service Accounts" -path $resourcesDN
New-ADOrganizationalUnit "Workstations" -path $resourcesDN
New-ADOrganizationalUnit "Servers" -path $resourcesDN
New-ADOrganizationalUnit "Users" -path $resourcesDN


#step 5

#Enable the Recycle Bin
$ForestFQDN = "labflo.com"
$SchemaDC   = "dc1.labflo.com"

Enable-ADOptionalFeature –Identity 'Recycle Bin Feature' –Scope ForestOrConfigurationSet –Target $ForestFQDN -Server $SchemaDC -confirm:$false


#step 6

#Create User Accounts
# Prompt for a Password
$Password = Read-Host -assecurestring "User Password"

# Create a Privileged Account
$userProperties = @{

    Name                 = "John Dougherty EA"
    GivenName            = "John"
    Surname              = "Dougherty EA"
    DisplayName          = "John Dougherty EA"
    Path                 = "OU=Admin Users,OU=Resources,DC=labflo,DC=com"
    SamAccountName       = "dougherty-ea"
    UserPrincipalName    = "dougherty-ea@labflo.com"
    AccountPassword      = $Password
    PasswordNeverExpires = $True
    Enabled              = $True
    Description          = "Labflo Enterprise Admin"

}

New-ADUser @userProperties

# Add Privileged Account to EA, DA, & SA Groups
Add-ADGroupMember "Admins du domaine" $userProperties.SamAccountName
Add-ADGroupMember "Administrateurs de l’entreprise" $userProperties.SamAccountName
Add-ADGroupMember "Administrateurs du schéma" $userProperties.SamAccountName
# Create a Non-Privileged User Account
$userProperties = @{

    Name                 = "John Dougherty"
    GivenName            = "John"
    Surname              = "Dougherty"
    DisplayName          = "John Dougherty"
    Path                 = "OU=Users,OU=Resources,DC=labflo,DC=com"
    SamAccountName       = "john.dougherty"
    UserPrincipalName    = "john.dougherty@labflo.com"
    AccountPassword      = $Password
    PasswordNeverExpires = $True
    Enabled              = $True
    Description          = "Labflo User"

}

New-ADUser @userProperties


#step 7

#Secure & Disable the Administrator Account (optional in lab)
#Set-ADUser Administrator -AccountNotDelegated:$true -SmartcardLogonRequired:$true -Enabled:$false


#step 8

#Create an Active Directory Snapshot
C:\Windows\system32\ntdsutil.exe snapshot "activate instance ntds" create quit quit
