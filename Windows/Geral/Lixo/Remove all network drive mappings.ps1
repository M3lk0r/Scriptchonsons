# Remove all network drive mappings
Get-PSDrive -PSProvider FileSystem | Where-Object { $_.DisplayRoot -like '\\*' } | Remove-PSDrive -Force

# Clear all cached network credentials
cmdkey /list | ForEach-Object {
    if ($_ -match "Target.*: (.+)") {
        cmdkey /delete:$matches[1]
    }
}
