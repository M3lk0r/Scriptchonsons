function Add-XmlFromFile ([String]$Path,
    [String]$XPath,
    [System.Xml.XmlElement]$ParentElement) {

    [System.Xml.XmlElement]$ChildElement = `
    (Select-Xml -Path $Path -XPath $XPath).Node

    [System.Xml.XmlElement]$ImportedElement = `
        $ParentElement.OwnerDocument.ImportNode($ChildElement, $true)

    return $ParentElement.AppendChild($ImportedElement)
}

# Creating new XML object.
$Xml = New-Object Xml
$XmlDeclaration = $Xml.CreateXmlDeclaration("1.0", "UTF-8", $null)
$Xml.AppendChild($XmlDeclaration) | Out-Null

# Creating parent element.
$CreateResourceRequest = $Xml.CreateElement("CreateResourceRequest")

# Adding child elements to parent.
Add-XmlFromFile -Path "Versoes-1.xml" `
    -XPath "//ResourceResponse/Resource" `
    -ParentElement $CreateResourceRequest | Out-Null
Add-XmlFromFile -Path "Versoes-2.xml" `
    -XPath "//ResourcePrototypeResponse/ResourcePrototype" `
    -ParentElement $CreateResourceRequest | Out-Null
Add-XmlFromFile -Path "Versoes-3.xml" `
    -XPath "//Resource" `
    -ParentElement $CreateResourceRequest | Out-Null

# Appending parent to XML object.
$Xml.AppendChild($CreateResourceRequest) | Out-Null

# Saving XML object.
$Xml.OuterXml | Out-File -FilePath "Versoes.xml" -Encoding "UTF8"