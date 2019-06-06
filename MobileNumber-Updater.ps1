$allUsers = Get-ADUser -Filter * -Properties name, mobilephone

foreach ($user in $allUsers)
    {
        Write-Host `n
        Write-Host $user.Name -ForegroundColor Yellow

        if ($user.MobilePhone -eq $null)
            {
                Write-Host Current number: None `n
            }
        else 
            {
                Write-Host Current number: $user.MobilePhone `n
            }

        do 
            {
                $getChoice = Read-Host "Update mobile number? (y/n) "
            }

        until ($getChoice -eq "y" -or $getChoice -eq "n")


        if ($getChoice -eq "y")
            {
                [long]$newMobile = Read-Host "Enter new mobile number (no spaces) "                
                Set-ADUser $user -MobilePhone $newMobile.toString().Insert(0,'0').Insert(5,' ').Insert(9,' ')
            }

    }
