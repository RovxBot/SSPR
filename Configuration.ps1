# Install required modules
Install-Module -Name MSAL.PS -Scope CurrentUser

# Import required modules
Import-Module MSAL.PS

# Function to prompt for a boolean value and validate input
function Prompt-ForBoolean {
    param (
        [string]$PromptMessage
    )
    while ($true) {
        $input = Read-Host -Prompt $PromptMessage
        if ($input -match "^(true|false)$") {
            return [bool]::Parse($input)
        } else {
            Write-Host "Invalid input. Please enter 'true' or 'false'."
        }
    }
}

# Prompt for Tenant ID
$TenantId = Read-Host -Prompt "Enter your Tenant ID"

# Provide information on SSPR settings
Write-Host "SSPR Settings:"
Write-Host "1. Notify on user password reset: true/false"
Write-Host "2. Notify on admin password reset: true/false"
Write-Host "3. Authentication methods: comma-separated values (e.g., email,mobilePhone)"
Write-Host "   Available methods: email, mobilePhone, officePhone, securityQuestion, appNotification, appCode"
Write-Host "4. Enable password writeback: true/false"
Write-Host "5. Enable account unlock without password reset: true/false"

# Prompt for SSPR settings
$NotifyOnUserPasswordReset = Prompt-ForBoolean -PromptMessage "Notify on user password reset (true/false)"
$NotifyOnAdminPasswordReset = Prompt-ForBoolean -PromptMessage "Notify on admin password reset (true/false)"
$AuthenticationMethods = Read-Host -Prompt "Authentication methods (comma-separated, e.g., email,mobilePhone)"
$EnablePasswordWriteback = Prompt-ForBoolean -PromptMessage "Enable password writeback (true/false)"
$EnableAccountUnlock = Prompt-ForBoolean -PromptMessage "Enable account unlock without password reset (true/false)"

# Prompt for enabling SSPR for all users or a specific group
$EnableForAllUsers = Prompt-ForBoolean -PromptMessage "Enable SSPR for all users? (true/false)"
if (-not $EnableForAllUsers) {
    $GroupId = Read-Host -Prompt "Enter the Group ID to enable SSPR for"
}

# Define the scope
$Scope = "https://graph.microsoft.com/.default"

try {
    # Get the access token using device code flow
    $TokenResponse = Get-MsalToken -TenantId $TenantId -ClientId "04b07795-8ddb-461a-bbee-02f9e1bf7b46" -Scopes $Scope -DeviceCode

    if ($TokenResponse.AccessToken) {
        $AccessToken = $TokenResponse.AccessToken

        # Use the access token to configure SSPR settings
        $Url = "https://graph.microsoft.com/beta/organization/{organization-id}/settings"
        $Headers = @{
            "Authorization" = "Bearer $AccessToken"
            "Content-Type"  = "application/json"
        }
        $Data = @{
            "selfServicePasswordResetPolicy" = @{
                "isEnabled" = $true
                "notificationSettings" = @{
                    "notifyOnUserPasswordReset" = $NotifyOnUserPasswordReset
                    "notifyOnAdminPasswordResetViaEmail" = $NotifyOnAdminPasswordReset
                }
                "authenticationMethods" = $AuthenticationMethods -split ","
                "allowUnlockWithoutPasswordReset" = $EnableAccountUnlock
            }
            "passwordWritebackConfiguration" = @{
                "isEnabled" = $EnablePasswordWriteback
            }
        }

        if (-not $EnableForAllUsers) {
            $Data["selfServicePasswordResetPolicy"]["scope"] = @{
                "groupIds" = @($GroupId)
            }
        }

        $JsonData = $Data | ConvertTo-Json
        $Response = Invoke-RestMethod -Uri $Url -Method Patch -Headers $Headers -Body $JsonData
        Write-Output $Response

        # Configure authentication methods policy
        $AuthMethodsUrl = "https://graph.microsoft.com/beta/policies/authenticationmethodspolicy"
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

        if (-not $EnableForAllUsers) {
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
        throw "Failed to acquire token."
    }
} catch {
    Write-Error $_.Exception.Message
    Read-Host -Prompt "Press Enter to exit"
}