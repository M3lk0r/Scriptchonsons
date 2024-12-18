[CmdletBinding()]
param ()
$file_data = Select-Xml -Path "C:\ERP COMPLEM\Update\esAccessCenterConfig.xml" -XPath '/Config/Geral/Portal' | ForEach-Object { $_.Node.Servidor }
if ( $file_data ) {
    [PSCustomObject]@{
        Servidores = $file_data
    }
}
else {
    Write-Verbose "Sem servidores configurados"
}


$file_vers = Select-Xml -Path "C:\ERP COMPLEM\Update\esAccessCenterUpdateClient.exe.config" -XPath '/configuration/appSettings/add'
ForEach ( $vers in $file_vers ) {
    [PSCustomObject]@{
        Key    = $vers | ForEach-Object { $_.Node.key }
        Versao = $vers | ForEach-Object { $_.Node.value }
    }
}

$file_vers = Select-Xml -Path "C:\ERP COMPLEM\Update\esAccessCenterUpdateClient.exe.config" -XPath '/configuration/appSettings/add'
ForEach ( $vers in $file_vers ) {
    $var = $vers | ForEach-Object { $_.Node.key }
    if ($var -eq 'Setor') { $setor = $vers | ForEach-Object { $_.Node.value } }
    if ($var -eq 'Versao') { $value = $vers | ForEach-Object { $_.Node.value } }
}
[PSCustomObject]@{
    Setor  = $setor 
    Versao = $value 
}