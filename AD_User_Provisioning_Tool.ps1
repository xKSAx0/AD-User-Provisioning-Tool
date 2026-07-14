<#
    AD USER PROVISIONING TOOL
    Purpose: Provide a safe, menu-driven interface for common AD user tasks.
    Requirements: ActiveDirectory PowerShell module and delegated AD permissions.
#>

[CmdletBinding()]
param(
    [string]$DefaultUserPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Initialize-Tool {
    try {
        Import-Module ActiveDirectory -ErrorAction Stop

        $script:Domain = Get-ADDomain -ErrorAction Stop
        $script:DomainDnsRoot = $script:Domain.DNSRoot

        if ([string]::IsNullOrWhiteSpace($DefaultUserPath)) {
            $script:DefaultUserPath = "CN=Users,$($script:Domain.DistinguishedName)"
        }
        else {
            $script:DefaultUserPath = $DefaultUserPath
        }

        $script:OutputDirectory = Join-Path -Path $PSScriptRoot -ChildPath 'Reports'
        $script:LogDirectory = Join-Path -Path $PSScriptRoot -ChildPath 'Logs'
        New-Item -ItemType Directory -Path $script:OutputDirectory, $script:LogDirectory -Force | Out-Null

        $script:LogFile = Join-Path -Path $script:LogDirectory -ChildPath "AD_User_Provisioning_$(Get-Date -Format 'yyyy-MM-dd').log"
    }
    catch {
        Write-Host "Unable to initialise the tool: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

function Write-ToolLog {
    param(
        [Parameter(Mandatory)]
        [string]$Message,

        [ValidateSet('INFO', 'WARNING', 'ERROR', 'SUCCESS')]
        [string]$Level = 'INFO'
    )

    $entry = '[{0}] [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
    Add-Content -LiteralPath $script:LogFile -Value $entry
}

function Write-Status {
    param(
        [Parameter(Mandatory)]
        [string]$Message,

        [ValidateSet('Green', 'Yellow', 'Red', 'Cyan', 'White')]
        [string]$Color = 'White'
    )

    Write-Host $Message -ForegroundColor $Color
}

function Read-RequiredValue {
    param(
        [Parameter(Mandatory)]
        [string]$Prompt
    )

    do {
        $value = Read-Host $Prompt
        if ([string]::IsNullOrWhiteSpace($value)) {
            Write-Status 'A value is required. Please try again.' -Color Yellow
        }
    } while ([string]::IsNullOrWhiteSpace($value))

    return $value.Trim()
}

function Get-UserFromInput {
    param(
        [string]$Prompt = 'Enter the user logon name (sAMAccountName)'
    )

    $samAccountName = Read-RequiredValue -Prompt $Prompt

    try {
        return Get-ADUser -Identity $samAccountName -Properties DisplayName, Enabled, LockedOut, UserPrincipalName -ErrorAction Stop
    }
    catch {
        Write-Status "User '$samAccountName' was not found." -Color Red
        Write-ToolLog -Message "User lookup failed for '$samAccountName'." -Level WARNING
        return $null
    }
}

function Confirm-Action {
    param(
        [Parameter(Mandatory)]
        [string]$Message,

        [string]$ExpectedAnswer = 'YES'
    )

    $answer = Read-Host "$Message Type $ExpectedAnswer to continue"
    return $answer -ceq $ExpectedAnswer
}

function New-DirectoryUser {
    Write-Status "`n--- Create User ---" -Color Cyan

    $firstName = Read-RequiredValue -Prompt 'First name'
    $lastName = Read-RequiredValue -Prompt 'Last name'
    $samAccountName = Read-RequiredValue -Prompt 'User logon name (for example, j.smith)'
    $department = Read-Host 'Department (optional)'
    $title = Read-Host 'Job title (optional)'
    $emailAddress = Read-Host 'Email address (optional)'

    try {
        if (Get-ADUser -Filter "SamAccountName -eq '$samAccountName'" -ErrorAction Stop) {
            Write-Status "A user with logon name '$samAccountName' already exists." -Color Red
            return
        }

        $password = Read-Host 'Initial password' -AsSecureString
        $displayName = "$firstName $lastName"
        $userPrincipalName = "$samAccountName@$script:DomainDnsRoot"

        $newUserParameters = @{
            Name                  = $displayName
            GivenName             = $firstName
            Surname               = $lastName
            DisplayName           = $displayName
            SamAccountName        = $samAccountName
            UserPrincipalName     = $userPrincipalName
            AccountPassword       = $password
            Enabled               = $true
            ChangePasswordAtLogon = $true
            Path                  = $script:DefaultUserPath
            ErrorAction           = 'Stop'
        }

        if (-not [string]::IsNullOrWhiteSpace($department)) { $newUserParameters.Department = $department }
        if (-not [string]::IsNullOrWhiteSpace($title)) { $newUserParameters.Title = $title }
        if (-not [string]::IsNullOrWhiteSpace($emailAddress)) { $newUserParameters.EmailAddress = $emailAddress }

        New-ADUser @newUserParameters
        Write-Status "User '$displayName' was created and must change password at next logon." -Color Green
        Write-ToolLog -Message "Created user '$samAccountName' in '$script:DefaultUserPath'." -Level SUCCESS
    }
    catch {
        Write-Status "User creation failed: $($_.Exception.Message)" -Color Red
        Write-ToolLog -Message "User creation failed for '$samAccountName': $($_.Exception.Message)" -Level ERROR
    }
}

function Disable-DirectoryUser {
    Write-Status "`n--- Disable User ---" -Color Cyan
    $user = Get-UserFromInput
    if ($null -eq $user) { return }

    if (-not $user.Enabled) {
        Write-Status "'$($user.SamAccountName)' is already disabled." -Color Yellow
        return
    }

    if (-not (Confirm-Action -Message "Disable '$($user.DisplayName)' ($($user.SamAccountName))?")) {
        Write-Status 'Action cancelled.' -Color Yellow
        return
    }

    try {
        Disable-ADAccount -Identity $user -ErrorAction Stop
        Write-Status "User '$($user.SamAccountName)' was disabled." -Color Green
        Write-ToolLog -Message "Disabled user '$($user.SamAccountName)'." -Level SUCCESS
    }
    catch {
        Write-Status "Unable to disable user: $($_.Exception.Message)" -Color Red
        Write-ToolLog -Message "Failed to disable '$($user.SamAccountName)': $($_.Exception.Message)" -Level ERROR
    }
}

function Unlock-DirectoryUser {
    Write-Status "`n--- Unlock User ---" -Color Cyan
    $user = Get-UserFromInput
    if ($null -eq $user) { return }

    if (-not $user.LockedOut) {
        Write-Status "'$($user.SamAccountName)' is not locked out." -Color Yellow
        return
    }

    try {
        Unlock-ADAccount -Identity $user -ErrorAction Stop
        Write-Status "User '$($user.SamAccountName)' was unlocked." -Color Green
        Write-ToolLog -Message "Unlocked user '$($user.SamAccountName)'." -Level SUCCESS
    }
    catch {
        Write-Status "Unable to unlock user: $($_.Exception.Message)" -Color Red
        Write-ToolLog -Message "Failed to unlock '$($user.SamAccountName)': $($_.Exception.Message)" -Level ERROR
    }
}

function Reset-DirectoryUserPassword {
    Write-Status "`n--- Reset Password ---" -Color Cyan
    $user = Get-UserFromInput
    if ($null -eq $user) { return }

    $password = Read-Host "Enter a new temporary password for '$($user.SamAccountName)'" -AsSecureString

    try {
        Set-ADAccountPassword -Identity $user -Reset -NewPassword $password -ErrorAction Stop
        Set-ADUser -Identity $user -ChangePasswordAtLogon $true -ErrorAction Stop
        Write-Status "Password reset for '$($user.SamAccountName)'. Password change is required at next logon." -Color Green
        Write-ToolLog -Message "Reset password for '$($user.SamAccountName)'." -Level SUCCESS
    }
    catch {
        Write-Status "Password reset failed: $($_.Exception.Message)" -Color Red
        Write-ToolLog -Message "Password reset failed for '$($user.SamAccountName)': $($_.Exception.Message)" -Level ERROR
    }
}

function Remove-DirectoryUser {
    Write-Status "`n--- Delete User ---" -Color Red
    Write-Status 'Best practice: disable a leaver first. Deletion is permanent.' -Color Yellow
    $user = Get-UserFromInput
    if ($null -eq $user) { return }

    if (-not (Confirm-Action -Message "PERMANENTLY delete '$($user.DisplayName)' ($($user.SamAccountName))?" -ExpectedAnswer 'DELETE')) {
        Write-Status 'Action cancelled.' -Color Yellow
        return
    }

    try {
        Remove-ADUser -Identity $user -Confirm:$false -ErrorAction Stop
        Write-Status "User '$($user.SamAccountName)' was deleted." -Color Green
        Write-ToolLog -Message "Deleted user '$($user.SamAccountName)'." -Level WARNING
    }
    catch {
        Write-Status "User deletion failed: $($_.Exception.Message)" -Color Red
        Write-ToolLog -Message "User deletion failed for '$($user.SamAccountName)': $($_.Exception.Message)" -Level ERROR
    }
}

function Export-DirectoryUsers {
    Write-Status "`n--- Export Users ---" -Color Cyan

    try {
        $fileName = 'AD_Users_{0}.csv' -f (Get-Date -Format 'yyyy-MM-dd_HH-mm-ss')
        $filePath = Join-Path -Path $script:OutputDirectory -ChildPath $fileName

        Get-ADUser -Filter * -Properties DisplayName, Enabled, Department, Title, EmailAddress, LastLogonDate, UserPrincipalName |
            Select-Object Name, SamAccountName, UserPrincipalName, Enabled, Department, Title, EmailAddress, LastLogonDate, DistinguishedName |
            Export-Csv -LiteralPath $filePath -NoTypeInformation -Encoding UTF8

        Write-Status "Users were exported to: $filePath" -Color Green
        Write-ToolLog -Message "Exported AD users to '$filePath'." -Level SUCCESS
    }
    catch {
        Write-Status "User export failed: $($_.Exception.Message)" -Color Red
        Write-ToolLog -Message "User export failed: $($_.Exception.Message)" -Level ERROR
    }
}

function Show-Menu {
    Clear-Host
    Write-Status '+======================================+' -Color Cyan
    Write-Status '|      ACTIVE DIRECTORY USER TOOL      |' -Color Cyan
    Write-Status '+======================================+' -Color Cyan
    Write-Host '1. Create User'
    Write-Host '2. Disable User'
    Write-Host '3. Unlock User'
    Write-Host '4. Reset Password'
    Write-Host '5. Delete User'
    Write-Host '6. Export Users'
    Write-Host '0. Exit'
    Write-Host ''
}

Initialize-Tool

do {
    Show-Menu
    $selection = Read-Host 'Choose an option'

    switch ($selection) {
        '1' { New-DirectoryUser }
        '2' { Disable-DirectoryUser }
        '3' { Unlock-DirectoryUser }
        '4' { Reset-DirectoryUserPassword }
        '5' { Remove-DirectoryUser }
        '6' { Export-DirectoryUsers }
        '0' { Write-Status 'Goodbye.' -Color Cyan; break }
        default { Write-Status 'Invalid option. Choose a number from 0 to 6.' -Color Yellow }
    }

    if ($selection -ne '0') {
        Write-Host ''
        [void](Read-Host 'Press Enter to return to the menu')
    }
} while ($true)
