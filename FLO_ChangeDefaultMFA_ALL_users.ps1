<#

Name:           Change default MFA method
Description:    Change the default MFA method for all users

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

# Set the desired value for the preferred method and the CSV file path
$PreferredMethod = "push"
$CsvPath = "C:\temp\MFAMethodReport_welch.csv"

# Get all users from Microsoft Graph
$AllUsers = Get-MgUser -All

# Create a JSON body template for the API request
$body = @{
    userPreferredMethodForSecondaryAuthentication = $PreferredMethod
}

# Create an empty array to store the results
$results = @()

# Loop through each user
foreach ($User in $AllUsers) {
    # Construct the API endpoint URL for getting the user's authentication sign-in preferences
    $uri = "https://graph.microsoft.com/beta/users/$($User.Id)/authentication/signInPreferences"

    # Send a GET request to the API endpoint to check the user's preferred method
    $Check = Invoke-MgGraphRequest -uri $uri -Method GET -OutputType PSObject

    # Check if the user already has the preferred method set
    if ($Check.userPreferredMethodForSecondaryAuthentication -eq $PreferredMethod) {
        # Skip the user and add the result to the array
        Write-host "Default MFA method $PreferredMethod already set for $($User.UserPrincipalName)" -ForegroundColor Cyan
        $result = [PSCustomObject]@{
            DisplayName       = $User.DisplayName
            UserPrincipalName = $User.UserPrincipalName
            Status            = "Already set"
        }
        $results += $result
        continue
    }

    try {
        # Send a PATCH request to update the user's preferred method
        Invoke-MgGraphRequest -uri $uri -Body $body -Method PATCH -ErrorAction Stop
        $result = [PSCustomObject]@{
            DisplayName       = $User.DisplayName
            UserPrincipalName = $User.UserPrincipalName
            Status            = "Updated"
        }
        $results += $result
        Write-host "Default MFA method $PreferredMethod updated successfully for $($User.UserPrincipalName)" -ForegroundColor Green
    }
    catch {
        # The registered method is not found for the user
        Write-Host "Default MFA method $PreferredMethod is not registered by $($User.UserPrincipalName)" -ForegroundColor Yellow
        $result = [PSCustomObject]@{
            DisplayName       = $User.DisplayName
            UserPrincipalName = $User.UserPrincipalName
            Status            = "Method not registered"
        }
        $results += $result
    }
}

# Export the results to a CSV file
$results | Export-Csv -Path $csvPath -Encoding utf8 -NoTypeInformation
Write-Host "Results saved to $($CsvPath)" -ForegroundColor Cyan

Disconnect-MgGraph