# OM Module
# Dot-source all functions from Private and Public folders

# Private functions
# Dot-source private functions but skip test helpers that have filenames starting
# with 'test-' so they don't get executed when the module is imported.
Get-ChildItem -Path $PSScriptRoot\Private -Filter *.ps1 -Recurse |
	Where-Object { $_.Name -notmatch '^test-.*\.ps1$' } |
	ForEach-Object { . $_.FullName }

# Public functions
Get-ChildItem -Path $PSScriptRoot\Public -Filter *.ps1 | ForEach-Object { . $_.FullName }

# Define aliases
New-Alias -Name AOD -Value Add-OMDiscNumbers -Description "Alias for Add-OMDiscNumbers" -Force
New-Alias -Name FOG -Value Format-Genres -Description "Alias for Format-Genres" -Force
New-Alias -Name GOT -Value Get-OMTags -Description "Alias for Get-OMTags" -Force
New-Alias -Name MOT -Value Move-OMTags -Description "Alias for Move-OMTags" -Force
New-Alias -Name SOT -Value Set-OMTags -Description "Alias for Set-OMTags" -Force
New-Alias -Name SOM -Value Start-OM -Description "Alias for Start-OM" -Force