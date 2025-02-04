# Active Directory User Onboarding Example

A PowerShell automation example demonstrating automated user creation in Active Directory with department-based organization.

## Features

- Automated username generation (first initial + last name)
- Department-based OU placement
- Secure random password generation
- Configurable base OU through `config.json`
- Dynamic domain detection

## Usage

1. Ensure you have Active Directory PowerShell module installed
2. Set your base OU in `config.json`
3. Run:
```powershell
.\Onboarding.ps1
```

The script will interactively prompt for user details and create the AD account with appropriate settings.