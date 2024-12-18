# Importa o módulo Active Directory
Import-Module ActiveDirectory

# Função para coletar eventos de adição de usuários a grupos
function Get-ADGroupAdditions {
    param (
        [int]$HoursAgo,
        [array]$DCs
    )
    
    # Lista para armazenar os resultados
    $Results = [System.Collections.Generic.List[PSCustomObject]]::new()
    $StartTime = (Get-Date) - (New-TimeSpan -Hour $HoursAgo)

    # Coleta de eventos em cada controlador de domínio
    foreach ($DC in $DCs) {
        try {
            Get-WinEvent -ComputerName $DC.Name -FilterHashtable @{LogName = "Security"; ID = 4732; StartTime = $StartTime } | Foreach {
                $event = [xml]$_.ToXml()
                if ($event) {
                    $EventTime = $_.TimeCreated.ToString("yyyy-MM-dd HH:mm:ss")
                    $User = $event.Event.EventData.Data[0]."#text"
                    $Group = $event.Event.EventData.Data[2]."#text"
                    $Admin = $event.Event.EventData.Data[6]."#text"
                    $dcName = $event.Event.System.Computer

                    # Adiciona o resultado como um objeto customizado
                    $Results.Add([PSCustomObject]@{
                        Action      = "Added"
                        DC          = $dcName
                        EventTime   = $EventTime
                        Group       = $Group
                        User        = $User
                        Admin       = $Admin
                    })
                }
            }
        } catch {
            Write-Warning "Failed to retrieve addition events from $($DC.Name): $_"
        }
    }

    return $Results
}

# Função para coletar eventos de remoção de usuários de grupos
function Get-ADGroupRemovals {
    param (
        [int]$HoursAgo,
        [array]$DCs
    )
    
    # Lista para armazenar os resultados
    $Results = [System.Collections.Generic.List[PSCustomObject]]::new()
    $StartTime = (Get-Date) - (New-TimeSpan -Hour $HoursAgo)

    # Coleta de eventos em cada controlador de domínio
    foreach ($DC in $DCs) {
        try {
            Get-WinEvent -ComputerName $DC.Name -FilterHashtable @{LogName = "Security"; ID = 4733; StartTime = $StartTime } | Foreach {
                $event = [xml]$_.ToXml()
                if ($event) {
                    $EventTime = $_.TimeCreated.ToString("yyyy-MM-dd HH:mm:ss")
                    $User = $event.Event.EventData.Data[0]."#text"
                    $Group = $event.Event.EventData.Data[2]."#text"
                    $Admin = $event.Event.EventData.Data[6]."#text"
                    $dcName = $event.Event.System.Computer

                    # Adiciona o resultado como um objeto customizado
                    $Results.Add([PSCustomObject]@{
                        Action      = "Removed"
                        DC          = $dcName
                        EventTime   = $EventTime
                        Group       = $Group
                        User        = $User
                        Admin       = $Admin
                    })
                }
            }
        } catch {
            Write-Warning "Failed to retrieve removal events from $($DC.Name): $_"
        }
    }

    return $Results
}

# Define os controladores de domínio e o período de tempo
$DCs = Get-ADDomainController -Filter *
$HoursAgo = 24

# Coleta os relatórios de adições e remoções
$AdditionsReport = Get-ADGroupAdditions -HoursAgo $HoursAgo -DCs $DCs
$RemovalsReport = Get-ADGroupRemovals -HoursAgo $HoursAgo -DCs $DCs

# Combina os relatórios em um só
$CombinedReport = $AdditionsReport + $RemovalsReport

# Exporta o relatório combinado para CSV
$FileName = "c:\ps\ad_group_changes_" + (Get-Date -Format "yyyy.MM.dd") + ".csv"
$CombinedReport | Export-Csv -Path $FileName -NoTypeInformation -Delimiter ","
Write-Host "Report exported to $FileName"