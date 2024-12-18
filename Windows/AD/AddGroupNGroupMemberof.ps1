# Caminho para o arquivo CSV
$csvPath = "C:\AddGroupNGroupMemberof.csv"

# Definir a OU onde os grupos serão criados
$ouPath = "OU=File Server,OU=Security Groups,DC=agripecas,DC=net"

# Importar o CSV
$grupos = Import-Csv -Path $csvPath -Encoding UTF8

# Verificar o conteúdo do CSV
$grupos | Format-Table -AutoSize
Write-Host "Pressione qualquer tecla para continuar..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

# Loop pelos grupos no CSV
foreach ($grupo in $grupos) {
    # Verificar se as propriedades existem
    if (-not ($grupo.PSObject.Properties.Name -contains 'GroupName') -or -not ($grupo.PSObject.Properties.Name -contains 'MemberOf')) {
        Write-Host "Erro: As colunas 'GroupName' ou 'MemberOf' não foram encontradas no CSV."
        continue
    }

    # Criar o grupo se ele não existir
    if (-not (Get-ADGroup -Filter "Name -eq '$($grupo.GroupName)'" -ErrorAction SilentlyContinue)) {
        New-ADGroup -Name $grupo.GroupName -GroupScope Global -Path $ouPath
        Write-Host "Grupo '$($grupo.GroupName)' criado em '$ouPath'."
    } else {
        Write-Host "Grupo '$($grupo.GroupName)' já existe."
    }

    # Adicionar o grupo como membro do grupo especificado na coluna 'MemberOf'
    if (Get-ADGroup -Filter "Name -eq '$($grupo.MemberOf)'" -ErrorAction SilentlyContinue) {
        Add-ADGroupMember -Identity $grupo.MemberOf -Members $grupo.GroupName
        Write-Host "Grupo '$($grupo.GroupName)' adicionado ao grupo '$($grupo.MemberOf)'."
    } else {
        Write-Host "Grupo '$($grupo.MemberOf)' não encontrado. Não foi possível adicionar '$($grupo.GroupName)'."
    }
}