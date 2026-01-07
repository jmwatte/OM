# OM Module
# Dot-source all functions from Private and Public folders

# Private functions
# Dot-source private functions but skip:
# - test helpers with filenames starting with 'test-'
# - Pester test files ending with '.Tests.ps1'
# - temporary test files starting with 'temp_'
# - anything in a 'Tests' folder
Get-ChildItem -Path $PSScriptRoot\Private -Filter *.ps1 -Recurse |
	Where-Object { $_.Name -notmatch '^test-.*\.ps1$' -and $_.Name -notmatch '\.Tests\.ps1$' -and $_.Name -notmatch '^temp_.*\.ps1$' -and $_.DirectoryName -notmatch '\\Tests($|\\)' } |
	ForEach-Object { . $_.FullName }

# Public functions
Get-ChildItem -Path $PSScriptRoot\Public -Filter *.ps1 | ForEach-Object { . $_.FullName }

# Define and export aliases
New-Alias -Name AOD -Value Add-OMDiscNumbers -Description "Alias for Add-OMDiscNumbers" -Force

# Temporary global trap for debugging uncaught ParameterBindingException inside module
# Enabled by setting environment variable OM_GLOBAL_TRAP=1
if ($env:OM_GLOBAL_TRAP -eq '1') {
    trap [System.Management.Automation.ParameterBindingException] {
        try { Dump-ExceptionDiagnostics -ErrorRecord $_ -ContextMsg "Global module trap: ParameterBindingException" } catch { Write-Verbose "Global trap: failed to dump diagnostics: $($_.Exception.Message)" }
        continue
    }
}
New-Alias -Name FOG -Value Format-Genres -Description "Alias for Format-Genres" -Force
New-Alias -Name GOT -Value Get-OMTags -Description "Alias for Get-OMTags" -Force
New-Alias -Name MOT -Value Move-OMTags -Description "Alias for Move-OMTags" -Force
New-Alias -Name SOT -Value Set-OMTags -Description "Alias for Set-OMTags" -Force
New-Alias -Name SOM -Value Start-OM -Description "Alias for Start-OM" -Force

# Export module members (functions and aliases are already specified in manifest)
Export-ModuleMember -Function * -Alias *