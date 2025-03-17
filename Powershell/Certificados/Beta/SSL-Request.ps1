# Definir parâmetros básicos
$templateName = "Web Server"      # Nome do template de certificado
$certStore = "Cert:\LocalMachine\My" # Local para armazenar o certificado gerado
$cn = $env:COMPUTERNAME           # Common Name (CN) - Nome do computador
$dnsNames = @("$cn.domain.local", "$cn")  # DNS Names - Substituir pelo domínio correto

# Criar objeto de solicitação
$certRequest = New-Object -ComObject X509Enrollment.CX509CertificateRequestPkcs10

# Configurar informações básicas do requerente
$certRequest.InitializeFromTemplateName(0x1, $templateName) # 0x1 = Contexto LocalMachine
$certRequest.Subject = "CN=$cn"  # Definir o CN

# Adicionar os DNS Names como SANs (Subject Alternative Names)
$sanExtension = New-Object -ComObject X509Enrollment.CX509ExtensionAlternativeNames
$sanNames = New-Object -ComObject X509Enrollment.CX509AlternativeNames

foreach ($dns in $dnsNames) {
    $altName = New-Object -ComObject X509Enrollment.CX509AlternativeName
    $altName.InitializeFromString(2, $dns)  # 2 = DNS Name
    $sanNames.Add($altName)
}

$sanExtension.InitializeEncode($sanNames)
$certRequest.X509Extensions.Add($sanExtension)

# Submeter a solicitação para a CA
$certEnrollment = New-Object -ComObject X509Enrollment.CX509Enrollment
$certEnrollment.InitializeFromRequest($certRequest)
$certPem = $certEnrollment.CreateRequest(0)

$certResponse = certreq -submit -attrib "CertificateTemplate:$templateName" $certPem

# Salvar o certificado no local especificado
$certEnrollment.InstallResponse(2, $certResponse, 0, $null) # 2 = AllowUntrustedRoot

# Confirmar instalação
Write-Output "Certificado solicitado e instalado com sucesso no armazenamento $certStore!"
