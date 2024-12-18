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
function Create-FolderStructure($groupName) {
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

# Função para configurar permissões de pastas intermediárias
function Set-IntermediateFolderPermissions($folderPath, $groupName) {
    $acl = Get-Acl $folderPath
    $acl.SetAccessRuleProtection($true, $false)
    
    # Adicionar permissões padrão
    $acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule("SYSTEM", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")))
    $acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule("Administrators", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")))
    $acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule("ggs_fs_controletotal", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")))
    
    # Adicionar permissão de leitura para o grupo intermediário
    $acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule($groupName, "ReadAndExecute", "ContainerInherit,ObjectInherit", "None", "Allow")))
    
    Set-Acl $folderPath $acl
    Write-Host "Permissões intermediárias configuradas para $groupName em $folderPath"
}

# Função para configurar permissões de pastas finais
function Set-FinalFolderPermissions($folderPath, $groupName) {
    $acl = Get-Acl $folderPath
    $acl.SetAccessRuleProtection($true, $false)
    
    # Adicionar permissões padrão
    $acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule("SYSTEM", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")))
    $acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule("Administrators", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")))
    $acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule("ggs_fs_controletotal", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")))
    
    # Adicionar permissões específicas do grupo
    $rGroup = $groupName + "_r"
    $rwGroup = $groupName + "_rw"
    $acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule($rGroup, "ReadAndExecute", "ContainerInherit,ObjectInherit", "None", "Allow")))
    $acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule($rwGroup, "Modify", "ContainerInherit,ObjectInherit", "None", "Allow")))
    
    Set-Acl $folderPath $acl
    Write-Host "Permissões finais configuradas para $groupName em $folderPath"
}

# Criar estrutura de pastas
foreach ($grupo in $grupos) {
    if ($grupo.GroupName -ne "ggs_fs_controletotal") {
        $groupName = $grupo.GroupName -replace "_r$|_rw$", ""
        Create-FolderStructure $groupName
    } else {
        Create-FolderStructure $grupo.GroupName
    }
}

# Configurar permissões
foreach ($grupo in $grupos) {
    $groupName = $grupo.GroupName -replace "_r$|_rw$", ""
    $folderPath = $basePath
    $parts = $groupName -replace "ggs_fs_", "" -split "_"
    for ($i = 0; $i -lt $parts.Count; $i++) {
        if ($parts[$i] -ne "r" -and $parts[$i] -ne "rw") {
            $formattedPart = Format-FolderName $parts[$i]
            $folderPath = Join-Path $folderPath $formattedPart
            if (!(Test-Path $folderPath)) {
                New-Item -Path $folderPath -ItemType Directory -Force
                Write-Host "Pasta criada: $folderPath"
            }
            if ($i -lt $parts.Count - 1) {
                Set-IntermediateFolderPermissions $folderPath $groupName
            } else {
                Set-FinalFolderPermissions $folderPath $groupName
            }
        }
    }
}