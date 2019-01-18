########################################################################################################################################################
#
# New user creation script
#
# SCRIPT SUMMARY
#
# This script is to ensure the creation of a new user complies to business policies by completing all required fields with static information.
# Where the information is not static, such as the user's name, the script will attempt to format the input appropriatley.
# 
# DETAILS
# 
# 1.  Check if the script operator has appropriate permissions to manipulate Active Directory and Office 365 and for the existance of the 
#     static company information.
# 2.  Connect to the remote systems and import the sessions to ensure that remote commands are available to this script.
# 3.  Prompt operator for user's name, format it correctly, then check if this name already exists.
# 4.  Prompt operator for remaining information (name as it should be displayed, job title, qualifcations and mobile telephone number).
# 5.  Prompt operator for user's office location from a dynamically created list generated from Active Directory OUs.
# 6.  Prompt operator for a password.
# 7.  Create new user account in local Active Directory with all required fields populated.
# 8.  Add new user account to appropriate Active Directory groups.
# 9.  Force a delta sync with Office 365 (Azure Active Directory).
# 10. Wait until the new user account has synced and Office 365 creates a mailbox then set the user's usage location and license (Office 365 specific).
# 11. Disables OWA and ActiveSync if the user does not have a company issued mobile phone (as per company policy).
# 12. Displays reminders for other software that requires manual configuration based on the user's job title.
#
########################################################################################################################################################

$localADServer = "server"
$localADDomain = "domain.local"
$emailDomain = "domain.co.uk" ## Primary email domain in Office 365
$o365BusEssLicense = "xxx:O365_BUSINESS_ESSENTIALS"
$o365BusPremLicense = "xxx:O365_BUSINESS_PREMIUM"
$o365UsageLocation = "GB"
$o365Uri = "https://outlook.office365.com/powershell-liveid/"

## Tests ##

# Test for companydetails.csv in correct location
if (!(Test-Path .\companydetails.csv)) 
    {
        Write-Host "The companydetails.csv could not be found. It should be in the same directory as this script." -ForegroundColor Red
        Break
    }

# Test for local domain administrative rights
$testAdAdmin = Get-ADGroupMember -Identity "Administrators" -Recursive | Select -ExpandProperty SamAccountName

if (!$testAdAdmin.Contains($env:USERNAME))
    {
        Write-Host "Your account does not have the appropriate permissions for adding users to Active Directory." -ForegroundColor Red
        Break
    }

## Create sessions ##

# Create session to local AD server (with Azure AD Connect installed)
$localADSession = New-PSSession -ComputerName "$localADServer.$localADDomain" -ErrorAction Stop

# Get Office 365 administrator credentials
$o365Creds = Get-Credential -Message "Enter your Office 365 admin credentials"

# Connect to Office 365
Connect-MsolService -Credential $o365Creds -ErrorAction Stop

# Create Office 365 remote session
$o365Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri $o365Uri -Credential $o365Creds -Authentication Basic -AllowRedirection


# Function to remove all remote sessions
function Remove-AllSessions
{
    Remove-PSSession -Session $localADSession
    Remove-PSSession -Session $o365Session
}


# Import modules
Import-Module ActiveDirectory
Import-Module (Import-PSSession $o365Session -AllowClobber -DisableNameChecking) -Global -DisableNameChecking
Import-Module -PSSession $localADSession -Name ADSync

# Test for Office 365 administrative rights
$testO365Admin = Get-MsolUserRole -UserPrincipalName "$env:USERNAME@$emailDomain" | Select -ExpandProperty Name

if (!$testO365Admin -eq "Company Administrator")
{
    Write-Host "Your Office 365 account does not have admin permissions." -ForegroundColor Red
    Remove-AllSessions
    Break
}

## Data collection ##

# Collect the new user's first and last name
Write-Host "Enter the user's first name: " -ForegroundColor Magenta -NoNewline
$inputFirstName = Read-Host
Write-Host "Now enter the user's last name: " -ForegroundColor Magenta -NoNewline 
$inputLastName = Read-Host


# Function to format name
function Name-Format ([string]$firstName, [string]$lastName)
{
    # Set input to title case and trim trailing whitespace
    $firstName = (Get-Culture).TextInfo.ToTitleCase($firstName.ToLower()).Trim()
    $lastName = (Get-Culture).TextInfo.ToTitleCase($lastName.ToLower()).Trim()

    # If Last Name is Mc
    if ($lastName -like "Mc*")
    {
       $mcUser = (Get-Culture).TextInfo.ToTitleCase($lastName.Split("Mc")).Trim()
       $lastName = "Mc"+$mcUser
    }

    # If Last Name is Mac
    if ($lastName -like "Mac*")
    {
        $macUser = (Get-Culture).TextInfo.ToTitleCase($lastName.Split("Mac")).Trim()
        $lastName = "Mac"+$macUser
    }

    # If First Name is double barrel
    if ($firstName -like "*-*")
    {
        $firstName = (Get-Culture).TextInfo.ToTitleCase($firstName)
    }

    # If Last Name is double barrel
    if ($lastName -like "*-*")
    {
        $lastName = (Get-Culture).TextInfo.ToTitleCase($lastName)
    }

    return $firstName, $lastName

}


# Create single variable with user's full name
$userName = Name-Format $inputFirstName $inputLastName

# Check if the user already exists
try
{
    $testAdUserExist = Get-ADUser "$($userName[0]).$($userName[1])"
}
catch
{ }

if ($testAdUserExist)
{
    Write-Host "`n$($userName[0]).$($userName[1]) already exists." -ForegroundColor Red
    Remove-AllSessions
    Break
}

# Collect the rest of the user's information
Write-Host "Enter the user's name as it should be displayed (middle names, initials etc. (case sensitive)): " -ForegroundColor Magenta -NoNewline
$inputDisplayName = Read-Host

Write-Host "What is the user's job title?: " -ForegroundColor Magenta -NoNewline
$inputTitle = Read-Host
$userTitle = $inputTitle.Trim()

Write-Host "And their qualifications?: " -ForegroundColor Magenta -NoNewline
$inputQuals = Read-Host
$userQuals = $inputQuals.Trim()

# Collect mobile phone number
do
{
    try
    {
        Write-Host "If the user has a mobile phone, please enter the number without spaces, otherwise press [enter] to continue: " -ForegroundColor Magenta -NoNewline
        [long]$testMobilePhone = Read-Host
        $testMobilePhoneInputOK = $true
                    
        if (($testMobilePhone).toString().Length -ne 10 -xor $testMobilePhone -eq 0)
        {
            Write-Host "`n You didn't enter 11 digits `n" -ForegroundColor Red
        }
        else
        {
            $testMobilePhoneLengthOK = $true 
        }
    }
    catch
    {
        Write-Host "`n Please enter numbers only and no spaces `n" -ForegroundColor Red 
    }

} 
until ($testMobilePhoneLengthOK -and $testMobilePhoneInputOK)

if ($testMobilePhone -eq 0)
{
    $userMobilePhone = $null
}
else
{ 
    $userMobilePhone = $testMobilePhone.toString().Insert(0,'0').Insert(5,' ').Insert(9,' ')
}

## Distribution lists ##

# Get user's office location (by Active Directory OU)
$officeOUs = Get-ADOrganizationalUnit -LDAPFilter '(name=*)' -SearchBase 'OU=Locations,DC=HARDIES,DC=LOCAL' -SearchScope OneLevel | Select-Object -ExpandProperty name

# Build menu for office location selection
$officeOUsTable = @{}

for ($i = 0; $i -lt $officeOUs.Count; $i++)
{
    $officeOUsTable.Add($i+1, $officeOUs[$i])
}

[int]$menuChoice = 0
while ($menuChoice -lt 1 -or $menuChoice -ge $officeOUsTable.Count)
{
    $officeOUsTable | Format-Table -AutoSize
    [int]$menuChoice = Read-Host Enter an option from 1 to $officeOUsTable.Count
}
$userOffice = $officeOUsTable[$menuChoice]

# Get all distribution lists from Active Directory
$distLists = Get-ADGroup -Filter * -SearchBase "OU=Distribution lists,DC=hardies,DC=local" | Select-Object -ExpandProperty name

# Build a menu for workgroup distribution lists
$distListsTable = @{}
$i = 0

# Build menu. Ignore all lists that end with "Staff"
foreach ($list in $distLists)
{
    if ($list -notlike "*Staff")
    {
        $i++
        $distListsTable.Add($i, $list.Replace("All ", ""))
    }
}

$distListsTable.Add(0, "Finished")

[int]$menuChoice = 0
$menuChoices = @()

# Display menu and accept input until 0 is entered
do
{
    $distListsTable | Format-Table -AutoSize
    [int]$menuChoice = Read-Host Enter options from 1 to $distListsTable.Count or 0 to exit

    if ($menuChoice -in 0..$distListsTable.Count)
    {
        if ($menuChoice -ne 0)
        {
            $menuChoices += $distListsTable[$menuChoice]
        }
    }
    else
    {
        Write-Host "Please enter a number between 0 and" $distListsTable.Count -ForegroundColor Red
    }
}
# Exit the menu when operator has entered 0
until ($menuChoice -eq 0)

# Office 365 license type

Write-Host "`n Select which Office 365 license the user requires `n"
Write-Host "1. Business Essentials (Exchange online only)"
Write-Host "2. Business Premium (Exchange online and Office apps) `n"

$o365LicenseChoice = 0
do
{
    $o365LicenseChoice = Read-Host "Enter choice (1 or 2)"
}
until ($o365LicenseChoice -gt 0 -and $o365LicenseChoice -le 2)

if ($o365LicenseChoice -eq 1)
{
    $o365Licence = $o365BusEssLicense
}
elseif ($o365LicenseChoice -eq 2)
{
    $o365Licence = $o365BusPremLicense
}

# Prompt for a password
$userPassword = Read-Host "Enter a password that complies to the proper complexity policy" -AsSecureString 

## Static data ##

# Read static office info from .csv according to office selection
$officeDetails = Import-Csv companydetails.csv | Where-Object {$_.City -eq "$userOffice"}

## Create the new user ##

try
{
    Write-Host "Adding $($userName[1].ToLower())@$($officeDetails.Domain) to Active Directory..." -NoNewline -ForegroundColor Cyan

    New-ADUser -UserPrincipalName "$($userName[0].ToLower()).$($userName[1].ToLower())@$($officeDetails.Domain)" `
                -SamAccountName "$($userName[0].ToLower()).$($userName[1].ToLower())" `
                -Name "$($userName[0]) $($userName[1])" `
                -DisplayName "$userDisplayName" `
                -GivenName "$($userName[0])" `
                -Surname "$($userName[1])" `
                -EmailAddress "$($userName[0].ToLower()).$($userName[1].ToLower())@$($officeDetails.Domain)" `
                -MobilePhone "$userMobilePhone" `
                -Department "$userQuals" `
                -Title "$userTitle" `
                -HomePage "www.$($officeDetails.Domain)" `
                -StreetAddress $officeDetails.Street `
                -City $officeDetails.City `
                -PostalCode $officeDetails.PostalCode `
                -OfficePhone $officeDetails.TelephoneNumber `
                -Company $officeDetails.Company `
                -ScriptPath "$($userOffice.ToLower())_logon.bat" `
                -Path "OU=Users,OU=$userOffice,OU=Locations,DC=hardies,DC=local" `
                -AccountPassword $userPassword `
                -PassThru | Enable-ADAccount

                Write-Host " Done" -ForegroundColor Green
}
catch
{
    Write-Host "There was a problem adding the new user account." -ForegroundColor Red
    Remove-AllSessions
    Break
}

## Distribution lists ##

# Add user to office location distribution list
try
{
    Write-Host "Adding $userName to All $userOffice Staff distribution list..." -NoNewline -ForegroundColor Cyan
    Add-ADGroupMember -Identity "All $userOffice Staff" -Members "$($userName[0]).$($userName[1])"
    Write-Host " Done" -ForegroundColor Green
}
catch
{
    Write-Host "Failed to add to All $userOffice Staff distribution list." -ForegroundColor Red
}

# Add user to workgroup distribution list

foreach ($choice in $menuChoices)
{
    try
    {
        Write-Host "Adding user to All $choice distribution list..." -NoNewline -ForegroundColor Cyan
        Add-ADGroupMember -Identity "All $choice" -Members "$($userName[0]).$($userName[1])"
        Write-Host " Done" -ForegroundColor Green
    }
    catch
    {
        Write-Host "Failed to add user to All $choice distribution list." -ForegroundColor Red
    }
}

# Add user to 'Users with mobile phones' group if mobile number was entered
if ($userMobilePhone)
{
    try
    {
        Write-Host "Adding $userName to Users with mobile phones distribution list..." -NoNewline -ForegroundColor Cyan
        Add-ADGroupMember -Identity "Users with mobile phones" -Members "$($userName[0]).$($userName[1])"
        Write-Host " Done" -ForegroundColor Green
    }
    catch
    {
        Write-Host "Failed to add user to Users with mobile phones distribution list." -ForegroundColor Red
    }
}

## Office 365 ##

# Force AD to Office 365 Syncronisation
Write-Host "Syncing local Active Directory to Office 365" -ForegroundColor Cyan
Start-ADSyncSyncCycle -PolicyType Delta | Out-Null

Write-Host "Waiting for new user account to syncronise" -ForegroundColor Cyan
while (!$testO365UserExist)
{
    try
    {
        $testO365UserExist = Get-MsolUser -UserPrincipalName "$($userName[0].ToLower()).$($userName[1].ToLower())@$($officeDetails.Domain)" -ErrorAction Stop
    }
    catch
    {
        Start-Sleep -Seconds 5
        Write-Host "." -NoNewline
    }
}

# Set new user's usage location and license
Write-Host "Setting user's usage location to $o365UsageLocation..."
Set-MsolUser -UserPrincipalName "$($userName[0].ToLower()).$($userName[1].ToLower())@$($officeDetails.Domain)" -UsageLocation $o365UsageLocation

try
{
    Write-Host "Assigning Office 365 license to user..." -NoNewline -ForegroundColor Cyan
    Set-MsolUserLicense -UserPrincipalName "$($userName[0].ToLower()).$($userName[1].ToLower())@$($officeDetails.Domain)" -AddLicenses $o365License
    Write-Host " Done" -ForegroundColor Green
}
catch
{
    Write-Host "Failed to assing license to user. Check that there are licenses available." -ForegroundColor Red
    Get-MsolAccountSku | where {$_.AccountSkuId -eq $o365License}
}

# Disable OWA and ActiveSync if the user does not have a mobile phone
if (!$userMobilePhone)
{
    Set-CASMailbox -Identity "$($userName[0].ToLower()).$($userName[1].ToLower())@$($officeDetails.Domain)" -ActiveSyncEnabled $false -ErrorAction Stop
    Set-CASMailbox -Identity "$($userName[0].ToLower()).$($userName[1].ToLower())@$($officeDetails.Domain)" -OWAEnabled $false -ErrorAction Stop
}

# Show some reminders
if ($userTitle -contains "Building")
{
    Write-Host "$($userName[0]) $($userLastName[1]) is a $userTitle and will need the following manually configured:"
    Write-Host "Union Square"
    Write-Host "NBS"
}

if ($userTitle -contains "Quantity")
{
    Write-Host "$($userName[0]) $($userLastName[1]) is a $userTitle and will need the following manually configured:"
    Write-Host "Union Square"
    Write-Host "CostX"
}

Remove-AllSessions
