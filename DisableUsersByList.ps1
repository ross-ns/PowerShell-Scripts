# Disables Active Directory accounts from a list of usernames (listOfAccounts.txt) and logs the results to DisableUsers-results.csv
$accounts = @()
$results = @() 
$accountsToDisable = Get-Content .\listOfAccounts.txt
$adResults = @()

$domain = Read-Host "Domain"

foreach ($account in $accountsToDisable) {
    $adResults += Get-AdUser -Identity $account -Server $domain -Properties AccountExpirationDate, Created, Description, DisplayName, EmailAddress, LastLogonDate, Office
}

Write-Host "Got" $adResults.Count "user accounts from Active Directory. Does this number seem reasonable?" 
pause

foreach ($adResult in $adResults) {
    $accounts += [pscustomobject]@{
        SamAccountName          = $adResult.SamAccountName
        FirstName               = $adResult.GivenName
        LastName                = $adResult.Surname
        DisplayName             = $adResult.DisplayName
        UserPrincipalName       = $adResult.UserPrincipalName
        DistinguishedName       = $adResult.DistinguishedName
        Description             = $adResult.Description
        Office                  = $adResult.Office
        EmailAddress            = $adResult.EmailAddress
        CreationDate            = $adResult.Created
        LastLogonDate           = if ($adResult.LastLogonDate) { $adResult.LastLogonDate } else { "Never" }
        PasswordLastChanged     = if ($adResult.PasswordLastSet) { $adResult.PasswordLastSet } else { "Never" }
        AccountExpirationDate   = if ($adResult.AccountExpirationDate) { $adResult.AccountExpirationDate } else { "Never" }
        Expires                 = if ($adResult.AccountExpirationDate) { $adResults.AccountExpirationDate } else { "Never" }
        NewStatus               = $null
    }
}

$counts = [PSCustomObject]@{
    Accounts = $accounts.Count
    Expired = $accounts | Where-Object { $_.AccountExpirationDate -ne "Never" -and $_.AccountExpirationDate -lt (Get-Date) } | Measure-Object | Select-Object -ExpandProperty Count
    WillExpire = $accounts | Where-Object { $_.AccountExpirationDate -ne "Never" -and $_.AccountExpirationDate -gt (Get-Date) } | Measure-Object | Select-Object -ExpandProperty Count
}

$counts | Format-List
Write-Host "Continuing will disable all accounts including those that have expired"
pause

foreach ($account in $accounts) {
        try {
            Disable-ADAccount -Server $domain -Identity $account.DistinguishedName -ErrorAction Stop -Verbose
            $account.NewStatus = "Disabled"
        }
        catch [Microsoft.ActiveDirectory.Management.ADException] {
            if ($_.Exception.Message -match 'Insufficient access rights') {
                Write-Host "You do not have permissions to disable" $account.SamAccountName

                $account.NewStatus = "Unchanged (insufficient permissions)"
            }
        }
        catch {
            $account.NewStatus = "Unchanged (error disabling)"
        }
     $results += $account
}

$results | Format-Table -Property SamAccountName, UserPrincipalName, FirstName, LastName, NewStatus
$results | Export-Csv DisableUsers-results.csv -NoTypeInformation -Append
