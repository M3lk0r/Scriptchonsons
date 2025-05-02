<#
.SYNOPSIS
    Cria estrutura organizacional completa, usuários e grupos em domínio Active Directory.
.DESCRIPTION
    Este script cria:
    - Estrutura de OUs baseada em departamentos e serviços
    - Grupos de segurança organizacionais
    - Usuários de teste para laboratório
    - Configurações básicas de permissões
.NOTES
    File Name      : Create-ADLabStructure.ps1
    Prerequisite   : Windows Server 2025 Core com AD DS instalado
    Version        : 1.0
#>

# Verificar se o módulo do AD está disponível
if (-not (Get-Module -Name ActiveDirectory -ErrorAction SilentlyContinue)) {
    try {
        Import-Module ActiveDirectory
    }
    catch {
        Write-Error "Módulo ActiveDirectory não encontrado. Execute este script em um controlador de domínio."
        exit
    }
}

# Definir variáveis básicas
$DomainDN = (Get-ADDomain).DistinguishedName
$DefaultPassword = ConvertTo-SecureString "P@ssw0rd2025!" -AsPlainText -Force
$UserPrincipalNameSuffix = "@contoso.com.br"

# Função para criar OU com proteção contra exclusão acidental
function New-ProtectedOU {
    param(
        [string]$Name,
        [string]$Path,
        [string]$Description = ""
    )
    
    $ou = Get-ADOrganizationalUnit -Filter "Name -eq '$Name'" -SearchBase $Path -ErrorAction SilentlyContinue
    if (-not $ou) {
        New-ADOrganizationalUnit -Name $Name -Path $Path -Description $Description -ProtectedFromAccidentalDeletion $true
        Write-Host "OU criada: $Name em $Path" -ForegroundColor Green
    }
    else {
        Write-Host "OU já existe: $Name em $Path" -ForegroundColor Yellow
    }
}

# 1. Criar estrutura de OUs principal
Write-Host "`nCriando estrutura organizacional..." -ForegroundColor Cyan

# OUs de nível superior
New-ProtectedOU -Name "00-EMPRESA" -Path $DomainDN -Description "Estrutura organizacional principal"
New-ProtectedOU -Name "01-FILIAIS" -Path $DomainDN -Description "Filiais da empresa"
New-ProtectedOU -Name "02-SUCURSAIS" -Path $DomainDN -Description "Suursais regionais"
New-ProtectedOU -Name "03-Integracoes" -Path $DomainDN -Description "Integrações com sistemas externos"

# OUs dentro de 00-EMPRESA
$empresaPath = "OU=00-EMPRESA,$DomainDN"
New-ProtectedOU -Name "Aplicacoes" -Path $empresaPath -Description "Aplicações corporativas"
New-ProtectedOU -Name "Departamentos" -Path $empresaPath -Description "Departamentos organizacionais"
New-ProtectedOU -Name "Servidores" -Path $empresaPath -Description "Servidores da empresa"
New-ProtectedOU -Name "Terceiros" -Path $empresaPath -Description "Contas de terceiros"

# OUs aninhadas
$aplicacoesPath = "OU=Aplicacoes,$empresaPath"
New-ProtectedOU -Name "ERP" -Path $aplicacoesPath -Description "Sistema ERP"
New-ProtectedOU -Name "CRM" -Path $aplicacoesPath -Description "Sistema CRM"
New-ProtectedOU -Name "BI" -Path $aplicacoesPath -Description "Business Intelligence"

$departamentosPath = "OU=Departamentos,$empresaPath"
New-ProtectedOU -Name "TI" -Path $departamentosPath -Description "Tecnologia da Informação"
New-ProtectedOU -Name "Financeiro" -Path $departamentosPath -Description "Departamento Financeiro"
New-ProtectedOU -Name "RH" -Path $departamentosPath -Description "Recursos Humanos"
New-ProtectedOU -Name "Marketing" -Path $departamentosPath -Description "Departamento de Marketing"

$servidoresPath = "OU=Servidores,$empresaPath"
New-ProtectedOU -Name "FileServers" -Path $servidoresPath -Description "Servidores de Arquivos"
New-ProtectedOU -Name "AppServers" -Path $servidoresPath -Description "Servidores de Aplicação"
New-ProtectedOU -Name "DBServers" -Path $servidoresPath -Description "Servidores de Banco de Dados"
New-ProtectedOU -Name "Infra" -Path $servidoresPath -Description "Infraestrutura de Rede"

# 2. Criar grupos de segurança
Write-Host "`nCriando grupos de segurança..." -ForegroundColor Cyan

$groups = @(
    @{Name="GRP-TI-Admins"; Description="Administradores de TI"; Path="OU=TI,$departamentosPath"; GroupCategory="Security"; GroupScope="Global"},
    @{Name="GRP-TI-Helpdesk"; Description="Equipe de Helpdesk"; Path="OU=TI,$departamentosPath"; GroupCategory="Security"; GroupScope="Global"},
    @{Name="GRP-Fin-Contabilidade"; Description="Equipe de Contabilidade"; Path="OU=Financeiro,$departamentosPath"; GroupCategory="Security"; GroupScope="Global"},
    @{Name="GRP-RH-Gestao"; Description="Gestão de RH"; Path="OU=RH,$departamentosPath"; GroupCategory="Security"; GroupScope="Global"},
    @{Name="GRP-FileServer-Read"; Description="Acesso leitura File Server"; Path="OU=FileServers,$servidoresPath"; GroupCategory="Security"; GroupScope="DomainLocal"},
    @{Name="GRP-FileServer-Write"; Description="Acesso escrita File Server"; Path="OU=FileServers,$servidoresPath"; GroupCategory="Security"; GroupScope="DomainLocal"},
    @{Name="GRP-ERP-Users"; Description="Usuários do ERP"; Path="OU=ERP,$aplicacoesPath"; GroupCategory="Security"; GroupScope="Global"},
    @{Name="GRP-CRM-Users"; Description="Usuários do CRM"; Path="OU=CRM,$aplicacoesPath"; GroupCategory="Security"; GroupScope="Global"}
)

foreach ($group in $groups) {
    if (-not (Get-ADGroup -Filter {Name -eq $group.Name} -ErrorAction SilentlyContinue)) {
        New-ADGroup @group
        Write-Host "Grupo criado: $($group.Name)" -ForegroundColor Green
    }
    else {
        Write-Host "Grupo já existe: $($group.Name)" -ForegroundColor Yellow
    }
}

# 3. Criar usuários de teste
Write-Host "`nCriando usuários de laboratório..." -ForegroundColor Cyan

$users = @(
    @{GivenName="Admin"; Surname="TI"; Name="ti.admin"; SamAccountName="ti.admin"; Path="OU=TI,$departamentosPath"; Description="Administrador de TI"; Groups=@("GRP-TI-Admins","Domain Admins")},
    @{GivenName="Helpdesk"; Surname="TI"; Name="ti.helpdesk"; SamAccountName="ti.helpdesk"; Path="OU=TI,$departamentosPath"; Description="Técnico de Helpdesk"; Groups=@("GRP-TI-Helpdesk")},
    @{GivenName="Gerente"; Surname="Financeiro"; Name="fin.gerente"; SamAccountName="fin.gerente"; Path="OU=Financeiro,$departamentosPath"; Description="Gerente Financeiro"; Groups=@("GRP-Fin-Contabilidade")},
    @{GivenName="Analista"; Surname="RH"; Name="rh.analista"; SamAccountName="rh.analista"; Path="OU=RH,$departamentosPath"; Description="Analista de RH"; Groups=@("GRP-RH-Gestao")},
    @{GivenName="Usuario"; Surname="ERP"; Name="erp.user"; SamAccountName="erp.user"; Path="OU=ERP,$aplicacoesPath"; Description="Usuário do ERP"; Groups=@("GRP-ERP-Users")},
    @{GivenName="Usuario"; Surname="CRM"; Name="crm.user"; SamAccountName="crm.user"; Path="OU=CRM,$aplicacoesPath"; Description="Usuário do CRM"; Groups=@("GRP-CRM-Users")},
    @{GivenName="Terceiro"; Surname="Consultor"; Name="terceiro.consultor"; SamAccountName="terceiro.consultor"; Path="OU=Terceiros,$empresaPath"; Description="Consultor Externo"; Groups=@()}
)

foreach ($user in $users) {
    if (-not (Get-ADUser -Filter {SamAccountName -eq $user.SamAccountName} -ErrorAction SilentlyContinue)) {
        $newUserParams = @{
            GivenName       = $user.GivenName
            Surname         = $user.Surname
            Name            = $user.Name
            SamAccountName  = $user.SamAccountName
            UserPrincipalName = "$($user.SamAccountName)$UserPrincipalNameSuffix"
            Path            = $user.Path
            AccountPassword = $DefaultPassword
            Enabled         = $true
            Description     = $user.Description
            ChangePasswordAtLogon = $true
        }
        
        New-ADUser @newUserParams
        Write-Host "Usuário criado: $($user.SamAccountName)" -ForegroundColor Green
        
        # Adicionar aos grupos especificados
        foreach ($group in $user.Groups) {
            try {
                Add-ADGroupMember -Identity $group -Members $user.SamAccountName
                Write-Host "  - Adicionado ao grupo: $group" -ForegroundColor DarkGreen
            }
            catch {
                Write-Host "  - ERRO ao adicionar ao grupo $($group): $_" -ForegroundColor Red
            }
        }
    }
    else {
        Write-Host "Usuário já existe: $($user.SamAccountName)" -ForegroundColor Yellow
    }
}

# 4. Configurar permissões básicas
Write-Host "`nConfigurando permissões básicas..." -ForegroundColor Cyan

# Delegar controle da OU de TI para o grupo GRP-TI-Admins
$tiOU = "OU=TI,$departamentosPath"
$tiAdmins = "GRP-TI-Admins"

try {
    $guidMap = @{
        "ResetPass" = "00299570-246d-11d0-a768-00aa006e0529"
        "CreateDeleteUsers" = "ab721a53-1e2f-11d0-9819-00aa0040529b"
        "ManageGroups" = "ab721a54-1e2f-11d0-9819-00aa0040529b"
    }

    # Permissão para resetar senhas
    Add-ADPermission -Identity $tiOU -User (Get-ADGroup $tiAdmins).SID -AccessRights ExtendedRight -ExtendedRights $guidMap.ResetPass
    
    # Permissão para criar/remover usuários
    Add-ADPermission -Identity $tiOU -User (Get-ADGroup $tiAdmins).SID -AccessRights CreateChild, DeleteChild -ChildType "user"
    
    # Permissão para gerenciar grupos
    Add-ADPermission -Identity $tiOU -User (Get-ADGroup $tiAdmins).SID -AccessRights WriteProperty -PropertyType "Member"
    
    Write-Host "Permissões delegadas para GRP-TI-Admins na OU de TI" -ForegroundColor Green
}
catch {
    Write-Host "Erro ao configurar permissões: $_" -ForegroundColor Red
}

# 5. Configuração final
Write-Host "`nConfiguração completa!" -ForegroundColor Green
Write-Host "Estrutura criada:" -ForegroundColor Cyan
Get-ADOrganizationalUnit -Filter * -SearchScope Subtree | Sort-Object DistinguishedName | Format-Table Name, DistinguishedName -AutoSize

Write-Host "`nResumo de usuários criados:" -ForegroundColor Cyan
Get-ADUser -Filter * -SearchBase $empresaPath -Properties MemberOf | Select-Object Name, SamAccountName, DistinguishedName | Format-Table -AutoSize

Write-Host "`nDicas para gerenciamento:" -ForegroundColor Yellow
Write-Host "- Conecte-se usando o Centro Administrativo do Active Directory de uma estação com RSAT"
Write-Host "- Ou use PowerShell Remoting: Enter-PSSession -ComputerName SRV-AD -Credential contoso\administrador"
Write-Host "- Todos os usuários têm senha inicial: P@ssw0rd2025! (devem alterar no primeiro logon)"