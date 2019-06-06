$credential = Get-Credential
$costxComputers = New-Object System.Collections.ArrayList
$installFail = New-Object System.Collections.ArrayList

Write-Host Retrieving computers from Active Directory...

$computers = Get-ADComputer -Filter * | Select-Object -Expand name

$server = "servername"

Write-Host $computers.count computers found. Determining which have CostX installed...

foreach ($computer in $computers)
{
    if ($computer.operatingSystem -notlike "*server*") # Not necessary using the office selection menu
    {
        $costxReg = Invoke-Command -ComputerName $computer -Credential $credential -ScriptBlock { Get-ItemProperty HKLM:\Software\Exactal\CostX\ } -ErrorAction SilentlyContinue
    }

        if ($costxReg)
        {
            $costxComputers.Add($computer) | Out-Null
        }
}

Write-Host CostX will be deployed to $costxComputers.count computers.

foreach ($costxComputer in $costxComputers)
{
    # Enable CredSSP locally, delegating to the computer in the current loop
    Enable-WSManCredSSP -Role Client -DelegateComputer $costxComputer -Force | Out-Null

    # Create a PS session, enable CredSSP on the remote computer, then exit the session
    $session = New-PSSession -ComputerName $costxComputer -Credential $credential

    if ($session)
    {
        Enter-PSSession -Session $session
        Enable-WSManCredSSP –Role Server -Force | Out-Null
        Exit-PSSession
        
        # Create a PS session with CredSSP
        $session = New-PSSession -ComputerName $costxComputer -Credential $credential -Authentication Credssp

        if ($session)
        {
            # Start the installation
            Write-Host Starting installation on $costxComputer...
            Invoke-Command -Session $session -ScriptBlock { New-Item -Path c:\temp -ItemType Directory -Force } | Out-Null
            Invoke-Command -Session $session -ScriptBlock { Copy-Item -Path \\$using:server\ClientApps\CostX\CostX_6.8_en_install.exe -Destination c:\temp }
            Invoke-Command -Session $session -ScriptBlock { Copy-Item -Path \\$using:server\ClientApps\CostX\vc_redist.x64.exe -Destination c:\temp }
            Invoke-Command -Session $session -ScriptBlock { & cmd.exe /c "c:\temp\vc_redist.x64.exe /install /passive /norestart" }
            Invoke-Command -Session $session -ScriptBlock { & cmd.exe /c "c:\temp\CostX_6.8_en_install.exe /S" }
            Invoke-Command -Session $session -ScriptBlock { Remove-Item c:\temp\CostX_6.8_en_install.exe -Force } | Out-Null

            # Disable CredSSP on the remote computer, then exit and remove the PS session
            Disable-WSManCredSSP -Role Server
            # Exit-PSSession
            Remove-PSSession -Session $session
            Write-Host Installation on $costxComputer complete.
        }
        else
        {
            Write-Host "`nCould not establish a PS Session to $costxComputer with CredSSP." -ForegroundColor Red
            $installFail.Add($costxComputer) | Out-Null
        }
    }
}
