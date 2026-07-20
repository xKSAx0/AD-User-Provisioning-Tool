# Active Directory Security Audit Tool

A read-only PowerShell security audit tool for Active Directory and Windows Server environments.

The script collects security-relevant configuration and account information, highlights findings with colour-coded statuses, calculates a simple security score, and exports the results to CSV and HTML reports.

> This tool does not change user accounts, Group Policy, Active Directory settings, or server configuration.

## Security checks

- Domain password policy
- Password complexity and minimum password length
- Membership of privileged AD groups
- Enabled accounts with `PasswordNeverExpires`
- Inactive enabled user accounts
- Currently locked-out accounts
- Active Directory Recycle Bin status
- SMBv1 server protocol status
- Windows Firewall profile status
- Microsoft Defender status
- Failed logons — Event ID `4625`
- Account lockouts — Event ID `4740`

## Requirements

- Windows PowerShell 5.1 or later
- Active Directory PowerShell module
- Domain Controller or management computer with RSAT installed
- An account with permission to read Active Directory
- Administrator permissions to read the Security Event Log and local security configuration

## Usage

Run PowerShell as Administrator:

```powershell
.\AD_Security_Audit_Tool.ps1
```

Optional parameters:

```powershell
.\AD_Security_Audit_Tool.ps1 -InactiveDays 60 -EventLookbackHours 48
```

- `InactiveDays` defines when an enabled account is considered inactive. Default: `90`
- `EventLookbackHours` defines how far back the script checks authentication events. Default: `24`

## Output

The script creates a `Reports` folder beside the script and saves:

```text
AD_Security_Audit_YYYY-MM-DD_HH-mm-ss.csv
AD_Security_Audit_YYYY-MM-DD_HH-mm-ss.html
```

## Status meanings

| Status | Meaning |
|---|---|
| GREEN | No issue found by this check |
| YELLOW | Review required; may be a valid exception |
| RED | Higher-risk finding that needs attention |

A yellow or red status is not automatically an error. Security decisions should be based on context, documented exceptions, and organisational policy.

## Skills demonstrated

- Active Directory security auditing
- PowerShell functions and parameters
- Security event log analysis
- Privileged-access review
- Windows Firewall and SMB security checks
- CSV and HTML reporting
- Read-only auditing and change-control awareness

## Future improvements

- Add Group Policy security settings
- Check local Administrators group membership
- Add Microsoft LAPS status checks
- Add BitLocker checks for client devices
- Send scheduled email reports
- Compare audit results against a baseline
- Add approved exceptions from a configuration file

## Disclaimer

This is a learning and portfolio project built in a home-lab environment. Test all scripts in a non-production environment before using them in an enterprise environment.