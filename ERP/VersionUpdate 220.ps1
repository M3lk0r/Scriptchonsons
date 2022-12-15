#Caminhos de arquivos relevantes
$path = 'C:\Azure_Deploy_Release\Versao\Versoes.xml'
$path2 = 'C:\ERP Update\Versoes.xml'
$pathTempVersao1 = 'C:\ERP Update\Geral\Combine1\'
$pathTempVersao2 = 'C:\ERP Update\Geral\Combine2\'
$pathXMLVersaoAtual1 = 'C:\Azure_Deploy_Release\Versao\Versoes.xml'
$pathXMLVersaoAtual2 = 'C:\ERP Update\Versoes.xml'
$pathDest = 'C:\ERP Update\Versoes.xml'

#Para Servico de atualizacao do ERP
Stop-Service 'ERP Update Service'

#Move arquivo de versao para pasta temporaria
Copy-Item -Path $pathXMLVersaoAtual1 -Destination $pathTempVersao1 -PassThru
Copy-Item -Path $pathXMLVersaoAtual2 -Destination $pathTempVersao2 -PassThru

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
    foreach ($elemento in $listaElementos) {
        $imported = $xml.ImportNode($elemento, $true)
        $xml.DocumentElement.AppendChild($imported) | Out-Null
    }

    foreach ($elemento in $listaElementos2) {
        $imported = $xml.ImportNode($elemento, $true)
        $xml.DocumentElement.AppendChild($imported) | Out-Null
    }

    $Xml.OuterXml | Out-File -FilePath $pathDest -Encoding "UTF8"
}

#Move arquivos referentes a versao autual do ERP
Copy-Item -Path C:\Azure_Deploy_Release\Versao\Clients\Clientes_Stage0.xml -Destination "C:\ERP Update\Clients\" -Force
Copy-Item -Path C:\Azure_Deploy_Release\Versao\Versoes\* -Destination "C:\ERP Update\Versoes\" -Recurse -Force

#Inicia servico de atualizacao do ERPC:\ERP Update
Start-Service 'ERP Update Service'