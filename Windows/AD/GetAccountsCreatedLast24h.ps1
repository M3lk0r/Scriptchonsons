# Variáveis
$Report = [System.Collections.Generic.List[PSCustomObject]]::new()
$time = (Get-Date) - (New-TimeSpan -Hour 24)
$AllDCs = Get-ADDomainController -Filter *
$filename = Get-Date -Format yyyy.MM.dd
$exportcsv = "c:\ps\ad_users_creators_$($filename).csv"

# Cria o diretório se não existir
if (-not (Test-Path "c:\ps")) {
    New-Item -Path "c:\ps" -ItemType Directory
}

# Coleta de eventos de criação de usuários
ForEach ($DC in $AllDCs) {
    Try {
        Get-WinEvent -ComputerName $dc.Name -FilterHashtable @{LogName = "Security"; ID = 4720; StartTime = $Time } | Foreach {
            $event = [xml]$_.ToXml()
            if ($event) {
                $Time = $_.TimeCreated.ToString("yyyy-MM-dd HH:mm:ss")
                $CreatorUser = $event.Event.EventData.Data[4]."#text"
                $NewUser = $event.Event.EventData.Data[0]."#text"
                $objReport = [PSCustomObject]@{
                    User         = $NewUser
                    Creator      = $CreatorUser
                    DC           = $event.Event.System.Computer
                    CreationDate = $Time
                }
                $Report.Add($objReport)
            }
        }
    } Catch {
        Write-Warning "Failed to retrieve events from $($dc.Name): $_"
    }
}

# Exportação para CSV
$Report | Export-Csv $exportcsv -Append -NoTypeInformation -Delimiter ","
Write-Host "Report exported to $exportcsv"