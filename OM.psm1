# OM Module
# Dot-source all functions from Private and Public folders

# Private functions
# Dot-source only files that define functions/filters. Skip test files, standalone
# scripts (runNewCDS.ps1 etc.) and anything that doesn't start with a definition.
Get-ChildItem -Path $PSScriptRoot\Private -Filter *.ps1 -Recurse |
	Where-Object {
		$_.Name -notmatch '^test-.*\.ps1$' -and
		$_.Name -notmatch '\.Tests\.ps1$' -and
		(Get-Content $_.FullName -TotalCount 10) -match '^\s*function\s|^\s*filter\s'
	} |
	ForEach-Object { . $_.FullName }

# Public functions
Get-ChildItem -Path $PSScriptRoot\Public -Filter *.ps1 | ForEach-Object { . $_.FullName }

# Define and export aliases
New-Alias -Name AOD -Value Add-OMDiscNumbers -Description "Alias for Add-OMDiscNumbers" -Force
New-Alias -Name FOG -Value Format-Genres -Description "Alias for Format-Genres" -Force
New-Alias -Name GOT -Value Get-OMTags -Description "Alias for Get-OMTags" -Force
New-Alias -Name MOT -Value Move-OMTags -Description "Alias for Move-OMTags" -Force
New-Alias -Name SOT -Value Set-OMTags -Description "Alias for Set-OMTags" -Force
New-Alias -Name SOM -Value Start-OM -Description "Alias for Start-OM" -Force

# Export module members (functions and aliases are already specified in manifest)
Export-ModuleMember -Function * -Alias *