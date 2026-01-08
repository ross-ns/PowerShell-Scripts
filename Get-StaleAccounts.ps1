# Creates a csv report of Active Directory accounts that are considered stale
$domain = Read-Host "Domain"
[int]$ageIn = Read-Host "Age in years to consider stale"

$age = $ageIn - ($ageIn * $ageIn)
$staleAccounts = Get-ADUser -Filter * -Properties Created, PasswordLastSet, LastLogonDate, LastLogonTimestamp -Server $domain | Where-Object { 
    $_.Enabled -eq $true -and $_.LastLogonDate -lt (Get-Date).AddYears($age) -and $_.Created -lt (Get-Date).AddYears($age) } | 
    Select-Object Name, SamAccountName, Created, LastLogonDate, PasswordLastSet, LastLogonTimestamp, DistinguishedName

$results = @()
foreach ($account in $staleAccounts) {
    $results += [PSCustomObject]@{
        Name = $account.Name
        SamAccountName = $account.SamAccountName
        LastLogonDate = $account.LastLogonDate
        PasswordLastSet = $account.PasswordLastSet
        LastLogonTimestamp = $account.LastLogonTimestamp
        DistinguishedName = $account.DistinguishedName
        OU = ($account.DistinguishedName -split ',',2)[-1]
    }
}

$results | Export-Csv .\staleAccounts.csv -NoTypeInformation
