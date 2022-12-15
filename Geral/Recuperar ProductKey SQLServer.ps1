<#
Para o Sql Server 2012, você precisa substituir duas linhas de código. Nos detalhes, substitua a linha 5 pela seguinte linha:

$regPath = "SOFTWARE\Microsoft\Microsoft SQL Server\110\Tools\Setup"
E também substituir a linha 16 pela seguinte linha (graças aos gprkns por apontá-la):

$binArray = ($data.uValue)[0..16]
Você também pode dar uma olhada no código completo do script para Sql Server 2012 no link a seguir.

Para o Sql Server 2014, a Microsoft mudou o Produto Digital nó para o nome de ocorrência real no registro, então você precisará substituir a linha 5 por algo semelhante ao seguinte (dependendo da sua instalação):

$regPath = "SOFTWARE\Microsoft\Microsoft SQL Server\MSSQL12.[YOUR SQL INSTANCE NAME]\Setup"
Tudo o que você precisa fazer para executar este script é executar essas ações:

Inicie um prompt do PowerShell (Iniciar > Run, em seguida, digite powershell e pressione ENTER.
Copie o texto da função acima e passe diretamente dentro da área de prompt.
Pressione ENTER algumas vezes, só para ter certeza de que você está de volta ao prompt.
Digite GetSqlServerProductKey e pressione ENTER.
#>



function GetSqlServerProductKey {
    ## function to retrieve the license key of a SQL 2008 Server.
    param ($targets = ".")
    $hklm = 2147483650
    $regPath = "SOFTWARE\Microsoft\Microsoft SQL Server\100\Tools\Setup"
    $regValue1 = "DigitalProductId"
    $regValue2 = "PatchLevel"
    $regValue3 = "Edition"
    Foreach ($target in $targets) {
        $productKey = $null
        $win32os = $null
        $wmi = [WMIClass]"\\$target\root\default:stdRegProv"
        $data = $wmi.GetBinaryValue($hklm,$regPath,$regValue1)
        [string]$SQLver = $wmi.GetstringValue($hklm,$regPath,$regValue2).svalue
        [string]$SQLedition = $wmi.GetstringValue($hklm,$regPath,$regValue3).svalue
        $binArray = ($data.uValue)[52..66]
        $charsArray = "B","C","D","F","G","H","J","K","M","P","Q","R","T","V","W","X","Y","2","3","4","6","7","8","9"
        ## decrypt base24 encoded binary data
        For ($i = 24; $i -ge 0; $i--) {
            $k = 0
            For ($j = 14; $j -ge 0; $j--) {
                $k = $k * 256 -bxor $binArray[$j]
                $binArray[$j] = [math]::truncate($k / 24)
                $k = $k % 24
         }
            $productKey = $charsArray[$k] + $productKey
            If (($i % 5 -eq 0) -and ($i -ne 0)) {
                $productKey = "-" + $productKey
            }
        }
        $win32os = Get-WmiObject Win32_OperatingSystem -computer $target
        $obj = New-Object Object
        $obj | Add-Member Noteproperty Computer -value $target
        $obj | Add-Member Noteproperty OSCaption -value $win32os.Caption
        $obj | Add-Member Noteproperty OSArch -value $win32os.OSArchitecture
        $obj | Add-Member Noteproperty SQLver -value $SQLver
        $obj | Add-Member Noteproperty SQLedition -value $SQLedition
        $obj | Add-Member Noteproperty ProductKey -value $productkey
        $obj
    }
}

