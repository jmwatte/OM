# OM Module
# Dot-source all functions from Private and Public folders

# Private functions
Get-ChildItem -Path $PSScriptRoot\Private -Filter *.ps1 -Recurse | ForEach-Object { . $_.FullName }

# Public functions
Get-ChildItem -Path $PSScriptRoot\Public -Filter *.ps1 | ForEach-Object { . $_.FullName }

# Define aliases
New-Alias -Name SOM -Value Start-OM -Description "Alias for Start-OM"
New-Alias -Name SOT -Value Set-OMTags -Description "Alias for Set-OMTags"
New-Alias -Name GOT -Value Get-OMTags -Description "Alias for Get-OMTags"
New-Alias -Name AOD -Value Add-OMDiscNumbers -Description "Alias for Add-OMDiscNumbers"