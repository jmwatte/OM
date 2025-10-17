# OM Module
# Dot-source all functions from Private and Public folders

# Private functions
Get-ChildItem -Path $PSScriptRoot\Private -Filter *.ps1 -Recurse | ForEach-Object { . $_.FullName }

# Public functions
Get-ChildItem -Path $PSScriptRoot\Public -Filter *.ps1 | ForEach-Object { . $_.FullName }