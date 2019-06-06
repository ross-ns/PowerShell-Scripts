# AutoCAD LT serial numbers are stored in a registry value under HKEY_LOCAL_MACHINE\SOFTWARE\Autodesk\AutoCAD LT\RXX\ACADLT-EXXX:XXX\SerialNumber
# Where RXX is the release number and ACADLT-EXXX:XXX something I'm not quite sure about :)
# A ProductName value also resides here which contains the full name and language, e.g. AutoCAD LT 2017 - English
# Combining the computer's name with the AutoCAD Product Name and serial we can determine which versions(s) a computer has installed along with
# the corresponding serial number(s)

$credential = Get-Credential
$computers = Get-ADComputer -Filter * | Select-Object -ExpandProperty Name

$result = $null
$result = @()

foreach ($computer in $computers)
{
    # Get all subkeys of the AutoCAD LT key from the remote computer
    # If the computer does not have AutoCAD LT installed this key will not exist (duh), however the parent Autodesk key may exist for other products
    $autoCadReg = Invoke-Command -ComputerName $computer -Credential $credential -ScriptBlock {
    Get-ChildItem -Path "HKLM:\SOFTWARE\Autodesk\AutoCAD LT" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name }

    # If the key does not exist, move onto the next computer
    if ($autoCadReg)
    {
        # Add the computer name to the Result var
        $result += "Computer name: " + $computer.ToUpper()

        # Iterate through the subkeys, grabbing the Product Name (version by year e.g. AutoCAD LT 2017) and corresponding Serial number
        foreach ($autoCadProducts in $autoCadReg)
        {
            # Get each release version for computers with multiple versions of AutoCAD LT installed.
            $autoCadReleases = Invoke-Command -ComputerName $computer -Credential $credential -ScriptBlock {
            Get-ChildItem -Path "HKLM:\$using:autoCadProducts" | Where-Object {$_.Name -Like "HKEY_LOCAL_MACHINE\SOFTWARE\Autodesk\AutoCAD LT\R*\ACADLT-*:*"} | Select-Object -ExpandProperty Name }
            
            # Get the Product Name and Serial Number values and add them to the Result var, nicely formatted
            $result += Invoke-Command -ComputerName $computer -Credential $credential -ScriptBlock {
            Get-ItemProperty -Path "HKLM:\$using:autoCadReleases" | Select-Object -Property ProductName, SerialNumber | Format-Table -Wrap }
        }
    }
}

# Export the result to a Csv file
$result | Out-File AutoCADLT-serials.csv -Append
