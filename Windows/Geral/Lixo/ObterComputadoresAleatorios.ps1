# Carregar o módulo do Active Directory
Import-Module ActiveDirectory

# Definir o número de computadores aleatórios a serem selecionados
$numberOfComputers = 20

# Buscar todos os computadores no Active Directory
$allComputers = Get-ADComputer -Filter * -Property Name

# Filtrar computadores que não são servidores
# Aqui assumimos que servidores têm um padrão específico no nome. Ajuste conforme necessário.
$nonServers = $allComputers | Where-Object { $_.Name -notlike "*SRV*" }

# Verificar se há computadores suficientes
if ($nonServers.Count -lt $numberOfComputers) {
    Write-Host "Não há computadores suficientes que atendam aos critérios."
    exit
}

# Selecionar aleatoriamente 20 computadores
$randomComputers = $nonServers | Get-Random -Count $numberOfComputers

# Exibir a lista dos computadores selecionados
$randomComputers | Select-Object Name

# Opcional: Exportar para um arquivo CSV
# $randomComputers | Select-Object Name | Export-Csv -Path "computadores_aleatorios.csv" -NoTypeInformation
