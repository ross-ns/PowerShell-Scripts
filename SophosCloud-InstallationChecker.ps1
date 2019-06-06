$credential = Get-Credential
$computers = Get-ADComputer -Filter 'Enabled -eq $true'

foreach ($computer in $computers)
{
    $testComputer = Test-Connection -ComputerName $computer.Name -Count 1 -ErrorAction SilentlyContinue

    if ($testComputer)
    {
        $installedApps = Invoke-Command -ComputerName $computer.Name -Credential $credential -ErrorAction SilentlyContinue -ScriptBlock { Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\Sophos* }
        if ($installedApps.DisplayName -contains "Sophos Endpoint Agent")
        {
            Write-Host $computer.Name has Sophos Cloud installed -ForegroundColor Green 
            $computer.Name+" has Sophos Cloud installed" | Out-File sophos.csv -Append
        }
        else
        {
            Write-Host $computer.Name does not have Sophos Cloud installed -ForegroundColor Red
            $computer.Name+" does NOT have Sophos Cloud installed" | Out-File sophos.csv -Append
        }
    }
    else
    {
        Write-Host $computer.Name is unreachable. -ForegroundColor Red
        $computer.Name+" is unreachable" | Out-File sophos.csv -Append
    }
}
