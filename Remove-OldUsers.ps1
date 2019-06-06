# Get all disabled accounts from the Historical User OU
$disabledUsers = Search-ADAccount -SearchBase 'OU=Historical Staff,DC=xxxxx,DC=LOCAL' -AccountDisabled | Select-Object Name, SamAccountName, LastLogonDate

# Get today's date
$today = Get-Date
# Substract 365 days from today's date
$yearAgo = $today.AddDays(-365)

# Loop through the list of disabled users
foreach ($user in $disabledUsers)
    {
        # Compare the last logon date of the account to the date a year ago from today
        if ($user.LastLogonDate -le $yearAgo)
            {
                try
                    {   
                        # Remove the user account                     
                        Remove-ADUser -Identity $user.SamAccountName -Confirm:$false

                        # Add success message to log variable
                        $logResult = "Successfully removed"
                    }

                catch
                    {
                        # Add failure message to log variable
                        $logResult = "Failed to remove"
                    }

                # Create array for logging and populate with results
                $log = [ordered]@{Date = $today; UserName = $user.Name; Result = $logResult}
                                
                # Output log to CSV file
                New-Object psobject -prop $log | Export-Csv -Path .\log.csv -Append

            }

    }
