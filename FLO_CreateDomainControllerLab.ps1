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
