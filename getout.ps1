    <#
    .SYNOPSIS
    getout.ps1

    .DESCRIPTION
    Reset user(s) password, disable devices, sign-out all sessions, block sign-in.

    .NOTES
    FLORIAN DAMINATO
#>

param (
    [switch]$All,
    [switch]$ResetPassword,
    [switch]$DisableDevices,
    [switch]$SignOut,
    [switch]$BlockSignIn,
    [string[]]$Exclude,
    [string[]]$UserPrincipalNames
)

# Check if no switches or parameters are provided
if (-not $All -and -not $ResetPassword -and -not $DisableDevices -and -not $SignOut -and -not $BlockSignIn -and -not $Exclude -and -not $UserPrincipalNames) {
    Write-Host "No switches or parameters provided. Please specify the desired action using switches such as -All, -ResetPassword, -DisableDevices, -SignOut, -BlockSignIn, or provide user principal names using -UserPrincipalNames." -ForegroundColor Yellow
    Exit
}

# Connect to Microsoft Graph API
Connect-MgGraph -Scopes Directory.AccessAsUser.All
Select-MgProfile Beta

# Retrieve all users if -All parameter is specified
if ($All) {
    $Users = Get-MgUser -All
}
else {
    # Filter users based on provided user principal names
    if ($UserPrincipalNames) {
        $Users = $UserPrincipalNames | Foreach-Object { Get-MgUser -Filter "UserPrincipalName eq '$($_)'" }
    }
    else {
        $Users = @()
        Write-Host "No -UserPrincipalNames or -All parameter provided." -ForegroundColor Yellow
    }
}

# Prompt for the new password if -ResetPassword parameter is specified and there are users to process
$NewPassword = ""
if ($ResetPassword -and $Users.Count -gt 0) {
    $NewPassword = Read-Host "Enter the new password"
}

# Check if any excluded users were not found
$ExcludedNotFound = $Exclude | Where-Object { $Users.UserPrincipalName -notcontains $_ }
foreach ($excludedUser in $ExcludedNotFound) {
    Write-Host "Can't find Azure AD account for user $excludedUser" -ForegroundColor Red
}

# Check if any provided users were not found
$UsersNotFound = $UserPrincipalNames | Where-Object { $Users.UserPrincipalName -notcontains $_ }
foreach ($userNotFound in $UsersNotFound) {
    Write-Host "Can't find Azure AD account for user $userNotFound" -ForegroundColor Red
}

foreach ($User in $Users) {
    # Check if the user should be excluded
    if ($Exclude -contains $User.UserPrincipalName) {
        Write-Host "Skipping user $($User.UserPrincipalName)" -ForegroundColor Cyan
        continue
    }
    
    # Flag to indicate if any actions were performed for the user
    $processed = $false  

    # Revoke access if -SignOut parameter is specified
    if ($SignOut) {
        Write-Host "Sign-out completed for account $($User.DisplayName)" -ForegroundColor Green

        # Revoke all signed in sessions and refresh tokens for the account
        $SignOutStatus = Revoke-MgUserSignInSession -UserId $User.Id

        $processed = $true
    }

    # Block sign-in if -BlockSignIn parameter is specified
    if ($BlockSignIn) {
        Write-Host "Block sign-in completed for account $($User.DisplayName)" -ForegroundColor Green

        # Block sign-in
        Update-MgUser -UserId $User.Id -AccountEnabled:$False

        $processed = $true
    }

    # Reset the password if -ResetPassword parameter is specified
    if ($ResetPassword -and $NewPassword) {
        $NewPasswordProfile = @{
            "Password"                      = $NewPassword
            "ForceChangePasswordNextSignIn" = $true
        }
        Update-MgUser -UserId $User.Id -PasswordProfile $NewPasswordProfile
        Write-Host "Password reset completed for $($User.DisplayName)" -ForegroundColor Green

        $processed = $true
    }

    # Disable registered devices if -DisableDevices parameter is specified
    if ($DisableDevices) {
        Write-Host "Disable registered devices completed for $($User.DisplayName)" -ForegroundColor Green
        
        # Retrieve registered devices
        $UserDevices = Get-MgUserRegisteredDevice -UserId $User.Id

        # Disable registered devices
        if ($UserDevices) {
            foreach ($Device in $UserDevices) {
                Update-MgDevice -DeviceId $Device.Id -AccountEnabled $false
            }
        }

        $processed = $true
    }

    if (-not $processed) {
        Write-Host "No actions selected for account $($User.DisplayName)" -ForegroundColor Yellow
    }
}