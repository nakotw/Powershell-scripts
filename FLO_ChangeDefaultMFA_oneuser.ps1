<#

Name:           Change default MFA method
Description:    Change the default MFA method for specific user

Authentication methods	Default MFA - abbreviations

Microsoft Authenticator notification on app - push
OATH TOTP (6-digit) one-time code on a third-party software app - oath
SMS (6-digit) code as a text message on primary mobile - sms
Voice call on the office phone - VoiceAlternateMobile
Voice call on primary mobile - VoiceMobile
Voice call on the office phone - VoiceOffice

{\__/}
( •.•)
/ > 🍪  u want this cookie ?

#>

# Connect to Microsoft Graph using the specified authentication scopes
Connect-MgGraph -Scopes "UserAuthenticationMethod.ReadWrite.All", "User.Read.All"

# Specify the user for whom you want to update the preferred method
$UserUPN = "flo@M365x19956391.onmicrosoft.com"

# Set the desired value for the preferred method
$PreferredMethod = "push"

# Get the user from Microsoft Graph
$User = Get-MgUser -UserId $UserUPN

# Create a JSON body template for the API request
$body = @{
    userPreferredMethodForSecondaryAuthentication = $PreferredMethod
}

# Construct the API endpoint URL for getting the user's authentication sign-in preferences
$uri = "https://graph.microsoft.com/beta/users/$($User.Id)/authentication/signInPreferences"

# Send a GET request to the API endpoint to check the user's preferred method
$Check = Invoke-MgGraphRequest -uri $uri -Method GET -OutputType PSObject

# Check if the user already has the preferred method set
if ($Check.userPreferredMethodForSecondaryAuthentication -eq $PreferredMethod) {
    Write-host "Default MFA method $PreferredMethod already set for $($User.UserPrincipalName)" -ForegroundColor Cyan
}
else {
    try {
        # Send a PATCH request to update the user's preferred method
        Invoke-MgGraphRequest -uri $uri -Body $body -Method PATCH -ErrorAction Stop
        Write-host "Default MFA method $PreferredMethod updated successfully for $($User.UserPrincipalName)" -ForegroundColor Green
    }
    catch {
        # The registered method is not found for the user
        Write-Host "Default MFA method $PreferredMethod is not registered by $($User.UserPrincipalName)" -ForegroundColor Yellow
    }
}