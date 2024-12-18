# Importa o módulo ActiveDirectory
Import-Module ActiveDirectory

# Variáveis de configuração
$csvPath = "\\ad02\c$\Users\adm.gomes\Desktop\smtp01.csv"
$csvDelimiter = ";"
$csvEncoding = "UTF8"
$domainSuffix = "@complem.com.br"

# Importa os dados do CSV
$arquivo = Import-Csv -Path $csvPath -Delimiter $csvDelimiter -Encoding $csvEncoding

# Define os prefixos de endereços SMTP
$SMTP1Prefix = "SMTP:"
$SMTP2Prefix = "smtp:"

# Função para adicionar endereços de proxy
function Add-ProxyAddresses {
    foreach ($user in $arquivo) {
        try {
            # Constrói os endereços SMTP e smtp
            $SMTP1 = $SMTP1Prefix + $user.smtp + $domainSuffix
            $SMTP2 = $SMTP2Prefix + $user.smtp1 + $domainSuffix

            # Recupera o usuário do AD
            $adUser = Get-ADUser -Identity $user.user -Properties ProxyAddresses

            if ($adUser) {
                # Adiciona os endereços de proxy ao usuário
                $proxyAddresses = $adUser.ProxyAddresses
                $proxyAddresses += $SMTP1
                $proxyAddresses += $SMTP2

                # Atualiza o usuário no AD com os novos endereços
                Set-ADUser -Identity $user.user -Add @{ProxyAddresses = $proxyAddresses}

                Write-Host "Proxy addresses added for user $($user.user): $SMTP1, $SMTP2"
            } else {
                Write-Warning "User $($user.user) not found in Active Directory. Skipping."
            }
        } catch {
            Write-Warning "Error adding proxy addresses for user $($user.user): $_"
        }
    }
}

# Chama a função para adicionar os endereços de proxy
Add-ProxyAddresses