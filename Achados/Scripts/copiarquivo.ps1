$Year = get-date -uformat "%Y"
$Monthly = get-date -uformat "%m"
 
$User = "servidorusuario"
$PWord = ConvertTo-SecureString -String "senha" -AsPlainText -Force
$Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $User, $PWord
New-PSDrive -Name Y -PSProvider FileSystem -Root caminho_de_rede -Credential $Credential -Persist
 
$check = Test-Path -PathType Container diretorio_de_backup$Year
if ($check -eq $false) {
    New-Item -Path diretorio_de_backup$Year -ItemType "directory"
}
 
$check = Test-Path -PathType Container diretorio_de_backup$Year$Monthly
if ($check -eq $false) {
    New-Item -Path diretorio_de_backup$Year$Monthly -ItemType "directory"
}
 
Move-Item -Path Y:*.TXT -Destination D:UNIVERSEEXTRATOS -Force
Move-Item -Path D:diretorio_de_origem*.TXT -Destination Y:diretorio_de_destino$Year$Monthly -Force
 
Remove-PSDrive Y