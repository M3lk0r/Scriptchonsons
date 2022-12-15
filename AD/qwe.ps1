$CurrTime = (get-date) - (new-timespan -hour 24)
Get-WinEvent -FilterHashtable @{LogName = "Security"; ID = 4732; StartTime = $CurrTime } | Foreach {
    $event = [xml]$_.ToXml()
    if ($event) {
        $CurrTime = Get-Date $_.TimeCreated -UFormat "%Y-%d-%m %H:%M:%S"
        $New_GrpUser = $event.Event.EventData.Data[0]."#text"
        $AD_Group = $event.Event.EventData.Data[2]."#text"
        $AdminWhoAdded = $event.Event.EventData.Data[6]."#text"
        $dc = $event.Event.System.computer
        $dc + “|” + $CurrTime + “|” + “|” + $AD_Group + “|” + $New_GrpUser + “|” + $AdminWhoAdded
    }
}


$time = (get-date) - (new-timespan -hour 124)
$DCs = Get-ADDomainController -Filter *
foreach ($DC in $DCs) {
    Get-WinEvent -ComputerName $DC -FilterHashtable @{LogName = "Security"; ID = 4732; StartTime = $Time } | Foreach {
        $event = [xml]$_.ToXml()
        if ($event) {
            CurrTime = Get-Date $_.TimeCreated -UFormat "%Y-%d-%m %H:%M:%S"
            $New_GrpUser = $event.Event.EventData.Data[0]."#text"
            $AD_Group = $event.Event.EventData.Data[2]."#text"
            $AdminWhoAdded = $event.Event.EventData.Data[6]."#text"
            $dc = $event.Event.System.computer
            $dc + “|” + $CurrTime + “|” + “|” + $AD_Group + “|” + $New_GrpUser + “|” + $AdminWhoAdded
        }
    }
}