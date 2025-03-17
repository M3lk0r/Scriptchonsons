Start-Transcript -Path "c:\temp\PSlog.txt"
#Gets information for the spreadsheet
$username = $env:USERNAME
$computername = $env:COMPUTERNAME
$Ethernet = Get-NetIpAddress | Where-Object {($_.InterfaceAlias -eq "Ethernet") -and ($_.AddressFamily -eq "IPv4")} | foreach { $_.IPAddress }
$WiFi = Get-NetIpAddress | Where-Object {($_.InterfaceAlias -eq "Wi-Fi") -and ($_.AddressFamily -eq "IPv4")} | foreach { $_.IPAddress }
$computermodel = get-wmiobject win32_computersystem | foreach { $_.model } 
$serial = get-wmiobject win32_bios | foreach { $_.serialnumber } 
$timeformat='MM-dd-yyyy hh:mm:ss tt'
$time = (Get-Date).ToString($timeformat)
$action = 'Logon'
$boottime = Get-CimInstance -ClassName win32_operatingsystem | select lastbootuptime | foreach { $_.lastbootuptime } 
 
#Specifies filename, and directory
$directory = "\\ad02\User_logs\Events"
$filedate = 'dd-MM-yyyy'
$filename = 'Logon' + '-' + $(((get-date)).ToString("yyyyMMdd"))
$file = "$filename.csv"
 
#Creates custom table and sorts the information
$table=  New-Object –TypeName PSObject -Property @{
            'Date/Time' = $time
            'Username' = $username
            'ComputerName' = $computername
            'Ethernet' = $Ethernet
            'WiFi' = $WiFi
            'Model' = $computermodel
            'Serial' = $serial
            'Action' = $action
            'Boot Time' = $boottime
} | Select date/time, username, computername, Ethernet, WiFi, model, serial, action, 'Boot Time' 
 
#Checks if CSV has already been created for the day.
if (Test-path "$directory\$file") {
     
    import-csv -Path "$directory\$file" > null
    $table | Export-Csv -NoTypeInformation -Append -Path "$directory\$file"
 
}
 
else{ 
    $table | Export-Csv -NoTypeInformation -Path "$directory\$file"
} 
Stop-Transcript
