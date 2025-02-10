# Importa o módulo Posh-SSH
Import-Module Posh-SSH

# Função para executar o comando SSH em um servidor remoto
function ExecuteSSHCommand {
    param (
        [string]$server,
        [string]$username,
        [string]$password,
        [string]$command,
        [string]$logpath
    )
    try {
        # Estabelece a conexão SSH
        $session = New-SSHSession -ComputerName $server -Credential (New-Object PSCredential ($username, (ConvertTo-SecureString $password -AsPlainText -Force)))
        
        # Executa o comando no servidor remoto
        $output = Invoke-SSHCommand -SessionId $session.SessionId -Command $command
        
        # Grava a saída no arquivo de log
        Add-Content -Path $logFilePath -Value "### Output do servidor: $server ###"
        Add-Content -Path $logFilePath -Value $output.Output
        Add-Content -Path $logFilePath -Value "`n"  # Adiciona uma linha em branco após o output
        
        # Fecha a sessão SSH
        Remove-SSHSession -SessionId $session.SessionId
    }
    catch {
        # Em caso de erro, grava o erro no arquivo de log
        Add-Content -Path $logFilePath -Value "Erro ao conectar ao servidor $server : $_"
        }
}

# Caminho para o arquivo CSV com a lista de servidores
$csvFilePath = "C:\teste\linux_servers.csv"

# Caminho para o arquivo de log
$logFilePath = "C:\teste\log_output.txt"

# Importa a lista de servidores do arquivo CSV
$servers = Import-Csv -Path $csvFilePath

# Comandos de update e upgrade
$updateCommand = "sudo apt update && sudo apt upgrade -y"

# Loop para executar os comandos em todos os servidores
foreach ($server in $servers) {
    ExecuteSSHCommand -server $server.IP -username "agripop" -password "MAL@ace2024" -command $updateCommand -logpath $logFilePath
}
