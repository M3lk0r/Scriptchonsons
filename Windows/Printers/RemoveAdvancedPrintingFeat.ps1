$printers = Get-Printer -Name *
foreach ($p in $printers) 
{
cscript c:\Windows\System32\Printing_Admin_Scripts\en-US\prncnfg.vbs -t -p $p.name +rawonly
}