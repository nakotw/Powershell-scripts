# Export path for CSV file
$csvPath = "C:\Temp\AuthenticationReport.csv"

# Connect to Microsoft Graph
Connect-MgGraph -Scopes "User.Read.All", "UserAuthenticationMethod.Read.All", "AuditLog.Read.All"

try {
    # Fetch user registration detail report from Microsoft Graph
    $Users = Get-MgBetaReportAuthenticationMethodUserRegistrationDetail -All

    # Create custom PowerShell object and populate it with the desired properties
    $Report = foreach ($User in $Users) {
        [pscustomobject]@{
            Id                                           = $User.Id
            UserPrincipalName                            = $User.UserPrincipalName
            UserDisplayName                              = $User.UserDisplayName
            IsAdmin                                      = $User.IsAdmin
            DefaultMfaMethod                             = $User.DefaultMfaMethod
            MethodsRegistered                            = $User.MethodsRegistered -join ','
            IsMfaCapable                                 = $User.IsMfaCapable
            IsMfaRegistered                              = $User.IsMfaRegistered
            IsPasswordlessCapable                        = $User.IsPasswordlessCapable
            IsSsprCapable                                = $User.IsSsprCapable
            IsSsprEnabled                                = $User.IsSsprEnabled
            IsSsprRegistered                             = $User.IsSsprRegistered
            IsSystemPreferredAuthenticationMethodEnabled = $User.IsSystemPreferredAuthenticationMethodEnabled
            LastUpdatedDateTime                          = $User.LastUpdatedDateTime
        }
    }
    # Output custom object to GridView
    $Report | Out-GridView -Title "Authentication Methods Report"

    # Export custom object to CSV file
    $Report | Export-Csv -Path $csvPath -NoTypeInformation -Encoding utf8

    Write-Host "Script completed. Report exported successfully to $csvPath" -ForegroundColor Green
}
catch {
    # Catch errors
    Write-Host "An error occurred: $_" -ForegroundColor Red
}
