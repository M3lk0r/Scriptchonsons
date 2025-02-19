Import-Module CimCmdlets

$csv = "C:\ERP Client\services.csv"
$arquivo = Import-Csv -Path $csv -Encoding Default

foreach ($user in $arquivo) {
    $teste = $user.nome
    $teste2 = "C:\ERP Client\Servicos\$teste\esAccessCenterWindowsServiceHost.exe"
    Write-Host $teste2`n -ForegroundColor Blue
    New-Service -Name $teste -BinaryPathName $teste2
}