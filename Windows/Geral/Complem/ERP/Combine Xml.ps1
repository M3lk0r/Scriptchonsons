$path = 'C:\XMLS\Versoes-1.xml'
$path2 = 'C:\XMLS\Versoes-2.xml'
$pathDest = 'c:\'

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
