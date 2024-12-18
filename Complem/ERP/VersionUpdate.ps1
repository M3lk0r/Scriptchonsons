#Caminhos de arquivos relevantes
$path = 'C:\eSolution\eSolution-Update\Combine1\Versoes.xml'
$path2 = 'C:\eSolution\eSolution-Update\Combine2\Versoes.xml'
$pathTempVersao1 = 'C:\eSolution\eSolution-Update\Combine1\'
$pathTempVersao2 = 'C:\eSolution\eSolution-Update\Combine2\'
$pathVersaoAtual1 = 'c:\eSolution\eSolution-Update\Server\Versoes.xml'
$pathVersaoAtual2 = 'C:\Azure_Deploy_Release\Versao\Versoes.xml'
$pathDest = 'c:\eSolution\eSolution-Update\Server\Versoes.xml'

#Para Servico de atualizacao do ERP
Stop-Service 'eSolution - Update Service'

#Move arquivo de versao para pasta temporaria
Copy-Item -Path $pathVersaoAtual1 -Destination $pathTempVersao1 -PassThru
Copy-Item -Path $pathVersaoAtual2 -Destination $pathTempVersao2 -PassThru

#Unindo arquivos .xml de versoes do ERP
$xml = New-Object Xml
$xml.AppendChild($xml.CreateElement('Versoes')) | Out-Null

$arquivoLido = New-Object Xml
$arquivoLido.Load($path)
$listaElementos = $arquivoLido.DocumentElement.GetElementsByTagName("Versao");

$arquivoLido2 = New-Object Xml
$arquivoLido2.Load($path2)

$listaElementos2 = $arquivoLido2.DocumentElement.GetElementsByTagName("Versao");

if ($listaElementos.Count -gt 0 -and $listaElementos2.Count -gt 0 ) {

    $imported = $xml.ImportNode($listaElementos[0], $true)
    $imported2 = $xml.ImportNode($listaElementos2[0], $true)

    $xml.DocumentElement.AppendChild($imported) | Out-Null
    $xml.DocumentElement.AppendChild($imported2) | Out-Null
    
    $Xml.OuterXml | Out-File -FilePath $pathDest -Encoding "UTF8"
}

#Move arquivos referentes a versao autual do ERP
Copy-Item -Path C:\Azure_Deploy_Release\Versao\Clients\Clientes_Stage0.xml -Destination C:\eSolution\eSolution-Update\Server\Clients\ -Force
Copy-Item -Path C:\Azure_Deploy_Release\Versao\Versoes\* -Destination C:\eSolution\eSolution-Update\Server\Versoes\ -Recurse -Force

#Inicia servico de atualizacao do ERP
Start-Service 'eSolution - Update Service'