# Importa o módulo do Active Directory
Import-Module ActiveDirectory

# Definições de variáveis
$csvPath = "C:\Users\adm.gomes\Desktop\passwordnerver.csv"
$delimiter = ";"
$encoding = "Default"
$csvData = Import-Csv -Path $csvPath -Delimiter $delimiter -Encoding $encoding

# Função para atualizar a configuração de senha dos usuários
function Update-PasswordPolicy {
    param (
        [array]$users
    )

    foreach ($user in $users) {
        try {
            # Obtém o usuário do AD
            $adUser = Get-ADUser -Identity $user.Username -Properties PasswordNeverExpires

            # Verifica se a configuração precisa ser atualizada
            if ($adUser.PasswordNeverExpires) {
                Set-ADUser -Identity $user.Username -PasswordNeverExpires $false
                Write-Host "Password policy updated for user: $($user.Username)"
            } else {
                Write-Host "No change needed for user: $($user.Username)"
            }
        } catch {
            Write-Warning "Failed to update password policy for user: $($user.Username) - $_"
        }
    }
}

# Executa a função de atualização
Update-PasswordPolicy -users $csvData