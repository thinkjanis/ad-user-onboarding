# Ensure the Active Directory module is imported
Import-Module ActiveDirectory

# Retrieve current domain details dynamically
try {
    $currentDomain = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain()
    $domainName = $currentDomain.Name              
    $netbiosName = $env:USERDOMAIN                  

    # Convert the FQDN into distinguished name (DC=) components
    $dcComponents = $domainName.Split('.') | ForEach-Object { "DC=$_" }
    $dcSuffix = ($dcComponents -join ",")
    
    Write-Output "Domain: $domainName ($netbiosName)"
} catch {
    Write-Error "Could not retrieve the current domain information: $_"
    exit 1
}

# Load base_ou from config.json
$scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$configFilePath = Join-Path -Path $scriptDirectory -ChildPath "config.json"

try {
    # Read and parse the JSON config file
    $config = Get-Content -Path $configFilePath -Raw | ConvertFrom-Json
    $baseOU = $config.base_ou
    Write-Output "Base OU retrieved from config.json: $baseOU"
} catch {
    Write-Error "Failed to read or parse the config.json file: $_"
    exit 1
}

# Prompt for the new user details
$FirstName = Read-Host "Enter First Name"
$LastName  = Read-Host "Enter Last Name"
$Username  = ($FirstName.Substring(0,1) + $LastName).ToLower()

# Ensure username is unique
$count = 1
$originalUsername = $Username
while (Get-ADUser -Filter { SamAccountName -eq $Username }) {
    $Username = "$originalUsername$count"
    $count++
}

$Name = "$FirstName $LastName"
$UPN = "$Username@$domainName"

# Prompt for department (optional)
$Department = Read-Host "Enter Department (Engineering/Management or leave blank)"

# Validate department if provided
if ($Department -and $Department -ne "Engineering" -and $Department -ne "Management") {
    Write-Error "Invalid department. Allowed values: Engineering, Management, or leave blank."
    exit 1
}

# Set OU dynamically based on department
if ($Department) {
    $OUPath = "OU=$Department,OU=Users,OU=$baseOU,$dcSuffix"
} else {
    $OUPath = "OU=Users,OU=$baseOU,$dcSuffix"
}

# Generate a secure random password
$Password = [System.Web.Security.Membership]::GeneratePassword(12, 4)
$SecurePassword = ConvertTo-SecureString -AsPlainText $Password -Force

try {
    # Create AD User
    New-ADUser -SamAccountName $Username `
                -UserPrincipalName $UPN `
                -GivenName $FirstName `
                -Surname $LastName `
                -Name $Name `
                -AccountPassword $SecurePassword `
                -Enabled $true `
                -Path $OUPath `
                -PassThru

    Write-Output "User $Username created successfully."
    Write-Output "Generated Password: $Password"

    # Retrieve the newly created user details
    $createdUser = Get-ADUser -Identity $Username -Properties Name, GivenName, Surname, Enabled, DistinguishedName

    # Output the details
    Write-Output "Created User Details:"
    Write-Output "--------------------------------"
    Write-Output "Name              : $($createdUser.Name)"
    Write-Output "First Name        : $($createdUser.GivenName)"
    Write-Output "Last Name         : $($createdUser.Surname)"
    Write-Output "Enabled           : $($createdUser.Enabled)"
    Write-Output "Distinguished Name: $($createdUser.DistinguishedName)"
    Write-Output "--------------------------------"
} catch {
    Write-Error "Failed to create user $Username. Error: $_"
}