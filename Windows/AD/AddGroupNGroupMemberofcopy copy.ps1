<#
.SYNOPSIS
    Cria estrutura de pastas e configura permissões baseadas nos grupos do Active Directory a partir de um arquivo CSV.

.DESCRIPTION
    Este script PowerShell importa um arquivo CSV contendo os nomes dos grupos do Active Directory e cria uma estrutura de pastas no servidor de arquivos. 
    Ele também configura permissões específicas para cada grupo nas pastas criadas, garantindo o acesso adequado de leitura e escrita.

.PARAMETER csvPath
    Caminho para o arquivo CSV contendo os nomes dos grupos.

.PARAMETER basePath
    Caminho base onde as pastas serão criadas.

.EXAMPLE
    .\CreateFolderStructureAndSetPermissions.ps1

.NOTES
    Autor: Eduardo Augusto Gomes
    Data: 18/12/2024
    Versão: 1.0
        Versão inicial do script.

.LINK
    https://github.com/M3lk0r/Powershellson
#>

# Caminho para o arquivo CSV
$csvPath = "C:\AddGroupNGroupMemberof.csv"

# Caminho base para criação das pastas
$basePath = "\\172.16.1.15\s$"

# Importar o CSV
$grupos = Import-Csv -Path $csvPath -Encoding UTF8

# Função para formatar o nome da pasta
function Format-FolderName($name) {
    if ($name.Length -eq 2) {
        return $name.ToUpper()
    } else {
        return $name.Substring(0,1).ToUpper() + $name.Substring(1).ToLower()
    }
}

# Função para criar a estrutura de pastas
function CreateFolderStructure($groupName) {
    $parts = $groupName -replace "ggs_fs_", "" -split "_"
    $currentPath = $basePath
    
    for ($i = 0; $i -lt $parts.Count; $i++) {
        if ($parts[$i] -ne "r" -and $parts[$i] -ne "rw") {
            $formattedPart = Format-FolderName $parts[$i]
            $currentPath = Join-Path $currentPath $formattedPart
            if (!(Test-Path $currentPath)) {
                New-Item -Path $currentPath -ItemType Directory -Force
                Write-Host "Pasta criada: $currentPath"
            }
        }
    }
}

# Função para configurar permissões
function Set-FolderPermissions($folderPath, $groupName) {
    $acl = Get-Acl $folderPath
    $acl.SetAccessRuleProtection($true, $false)
    
    # Adicionar permissões padrão
    $rule = New-Object System.Security.AccessControl.FileSystemAccessRule("SYSTEM", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
    $acl.AddAccessRule($rule)
    
    $rule = New-Object System.Security.AccessControl.FileSystemAccessRule("Administrators", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
    $acl.AddAccessRule($rule)
    
    $rule = New-Object System.Security.AccessControl.FileSystemAccessRule("ggs_fs_controletotal", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
    $acl.AddAccessRule($rule)
    
    # Adicionar permissões específicas do grupo
    $rGroup = $groupName + "_r"
    $rwGroup = $groupName + "_rw"
    $rule = New-Object System.Security.AccessControl.FileSystemAccessRule($rGroup, "ReadAndExecute", "ContainerInherit,ObjectInherit", "None", "Allow")
    $acl.AddAccessRule($rule)
    $rule = New-Object System.Security.AccessControl.FileSystemAccessRule($rwGroup, "Modify", "ContainerInherit,ObjectInherit", "None", "Allow")
    $acl.AddAccessRule($rule)
    
    Set-Acl $folderPath $acl
    Write-Host "Permissões configuradas para $groupName em $folderPath"
}

# Lista para armazenar grupos já processados
$processedGroups = New-Object System.Collections.ArrayList

# Criar estrutura de pastas
foreach ($grupo in $grupos) {
    if ($grupo.GroupName -ne "ggs_fs_controletotal") {
        $groupName = $grupo.GroupName -replace "_r$|_rw$", ""
        if (!$processedGroups.Contains($groupName)) {
            CreateFolderStructure $groupName
            $processedGroups.Add($groupName) | Out-Null
        }
    } else {
        CreateFolderStructure $grupo.GroupName
    }
}

# Configurar permissões
foreach ($grupo in $grupos) {
    $groupName = $grupo.GroupName -replace "_r$|_rw$", ""
    $folderPath = $basePath
    $parts = $groupName -replace "ggs_fs_", "" -split "_"
    foreach ($part in $parts) {
        if ($part -ne "r" -and $part -ne "rw") {
            $formattedPart = Format-FolderName $part
            $folderPath = Join-Path $folderPath $formattedPart
            if (!(Test-Path $folderPath)) {
                New-Item -Path $folderPath -ItemType Directory -Force
                Write-Host "Pasta criada: $folderPath"
            }
            Set-FolderPermissions $folderPath $groupName
        }
    }
}