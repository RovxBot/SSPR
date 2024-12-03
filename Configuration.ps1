# Install required modules
Install-Module -Name MSAL.PS -Scope CurrentUser

# Import required modules
Import-Module MSAL.PS

# Prompt for user credentials
$Username = Read-Host -Prompt "Enter your username"
$Password = Read-Host -Prompt "Enter your password" -AsSecureString

# Prompt for Tenant ID and Client ID
$TenantId = Read-Host -Prompt "Enter your Tenant ID"
$ClientId = Read-Host -Prompt "Enter your Client ID"

# Provide information on SSPR settings
Write-Host "SSPR Settings:"
Write-Host "1. Notify on password reset: true/false"
Write-Host "2. Notify on password reset methods: comma-separated values (e.g., email,mobilePhone)"
Write-Host "   Available methods: email, mobilePhone, officePhone, securityQuestion, appNotification, appCode"
Write-Host "3. Authentication methods: comma-separated values (e.g., email,mobilePhone)"
Write-Host "   Available methods: email, mobilePhone, officePhone, securityQuestion, appNotification, appCode"
Write-Host "4. Enable password writeback: true/false"
Write-Host "5. Enable account unlock without password reset: true/false"

# Prompt for SSPR settings
$NotifyOnPasswordReset = Read-Host -Prompt "Notify on password reset (true/false)"
$NotifyOnPasswordResetMethods = Read-Host -Prompt "Notify on password reset methods (comma-separated, e.g., email,mobilePhone)"
$AuthenticationMethods = Read-Host -Prompt "Authentication methods (comma-separated, e.g., email,mobilePhone)"
$EnablePasswordWriteback = Read-Host -Prompt "Enable password writeback (true/false)"
$EnableAccountUnlock = Read-Host -Prompt "Enable account unlock without password reset (true/false)"

# Prompt for enabling SSPR for all users or a specific group
$EnableForAllUsers = Read-Host -Prompt "Enable SSPR for all users? (true/false)"
if (-not [bool]::Parse($EnableForAllUsers)) {
    $GroupId = Read-Host -Prompt "Enter the Group ID to enable SSPR for"
}

# Define the scope
$Scope = "https://graph.microsoft.com/.default"

# Get the access token using username and password
$TokenResponse = Get-MsalToken -ClientId $ClientId -TenantId $TenantId -Username $Username -Password $Password -Scopes $Scope

if ($TokenResponse.AccessToken) {
    $AccessToken = $TokenResponse.AccessToken

    # Use the access token to configure SSPR settings
    $Url = "https://graph.microsoft.com/v1.0/organization/{organization-id}/settings"
    $Headers = @{
        "Authorization" = "Bearer $AccessToken"
        "Content-Type"  = "application/json"
    }
    $Data = @{
        "selfServicePasswordResetPolicy" = @{
            "enabled" = $true
            "notificationSettings" = @{
                "notifyOnPasswordReset" = [bool]::Parse($NotifyOnPasswordReset)
                "notifyOnPasswordResetMethods" = $NotifyOnPasswordResetMethods -split ","
            }
            "authenticationMethods" = $AuthenticationMethods -split ","
            "allowUnlockWithoutPasswordReset" = [bool]::Parse($EnableAccountUnlock)
        }
        "passwordWritebackConfiguration" = @{
            "enabled" = [bool]::Parse($EnablePasswordWriteback)
        }
    }

    if (-not [bool]::Parse($EnableForAllUsers)) {
        $Data["selfServicePasswordResetPolicy"]["scope"] = @{
            "groupIds" = @($GroupId)
        }
    }

    $JsonData = $Data | ConvertTo-Json
    $Response = Invoke-RestMethod -Uri $Url -Method Patch -Headers $Headers -Body $JsonData
    Write-Output $Response

    # Configure authentication methods policy
    $AuthMethodsUrl = "https://graph.microsoft.com/v1.0/policies/authenticationMethodsPolicy"
    $AuthMethodsData = @{
        "authenticationMethodConfigurations" = @(
            @{
                "id" = "email"
                "state" = "enabled"
            },
            @{
                "id" = "mobilePhone"
                "state" = "enabled"
            }
        )
    }

    if (-not [bool]::Parse($EnableForAllUsers)) {
        $AuthMethodsData["includeTargets"] = @(
            @{
                "id" = $GroupId
                "targetType" = "group"
            }
        )
    } else {
        $AuthMethodsData["includeTargets"] = @(
            @{
                "id" = "allUsers"
                "targetType" = "group"
            }
        )
    }

    $AuthMethodsJsonData = $AuthMethodsData | ConvertTo-Json
    $AuthMethodsResponse = Invoke-RestMethod -Uri $AuthMethodsUrl -Method Patch -Headers $Headers -Body $AuthMethodsJsonData
    Write-Output $AuthMethodsResponse
} else {
    Write-Error "Failed to acquire token."
}