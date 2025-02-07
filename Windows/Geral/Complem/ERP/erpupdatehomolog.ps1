Stop-Service 'ERP - 15554'
Start-Sleep -s 30
Copy-Item -Path C:\Azure_Deploy_Release\esAccessCenterService\* -Destination C:\eSolution\esAccessCenterServiceDebug\ -Recurse -Force
Copy-Item -Path C:\Azure_Deploy_Release\Relatorios -Destination C:\eSolution\esAccessCenterServiceDebug\bin\ -Recurse -Force
Start-Service 'ERP - 15554'