Set-Service -StartupType Disabled -Name 'ERP - 1581'
Set-Service -StartupType Disabled -Name 'ERP - 1584'
Stop-Service 'ERP - 1581'
Stop-Service 'ERP - 1584'
Start-Sleep -s 90
Copy-Item -Path C:\Azure_Deploy_Release\esAccessCenterService\* -Destination C:\eSolution\esAccessCenterService\ -Recurse -Force
Copy-Item -Path C:\Azure_Deploy_Release\esAccessCenterService\* -Destination C:\eSolution\esAccessCenterServiceHomologacao\ -Recurse -Force
Copy-Item -Path C:\Azure_Deploy_Release\Relatorios -Destination C:\eSolution\esAccessCenterService\bin\ -Recurse -Force
Copy-Item -Path C:\Azure_Deploy_Release\Relatorios -Destination C:\eSolution\esAccessCenterServiceHomologacao\bin\ -Recurse -Force
Set-Service -StartupType Automatic -Name 'ERP - 1581'
Set-Service -StartupType Automatic -Name 'ERP - 1584'
Start-Service 'ERP - 1581'
Start-Service 'ERP - 1584'