function Import-OMGenres {
    <#
    .SYNOPSIS
        Import genre configuration from a JSON file exported by Export-OMGenres.
    
    .DESCRIPTION
        Imports and applies genre configuration from a JSON file to the current OM config.
        This updates:
        - AllowedGenreNames: The whitelist of accepted genres
        - GenreMappings: Source-to-target genre mappings
        - GarbageGenres: List of genres to ignore/remove
        
        The existing Genres configuration will be completely replaced.
        Consider backing up your current config before importing.
    
    .PARAMETER Path
        The path to the genres configuration JSON file to import.
    
    .PARAMETER Merge
        If specified, merges the imported genres with existing ones instead of replacing.
        - AllowedGenreNames: Adds new genres to the whitelist
        - GenreMappings: Adds new mappings, existing ones take precedence
        - GarbageGenres: Adds new garbage genres
    
    .PARAMETER Force
        Skip confirmation prompt when replacing existing configuration.
    
    .EXAMPLE
        Import-OMGenres -Path "E:\Music\genres-backup.json"
        Imports genres configuration from the specified file (prompts for confirmation).
    
    .EXAMPLE
        Import-OMGenres -Path "D:\Backup\genres.json" -Force
        Imports without confirmation, replacing existing configuration.
    
    .EXAMPLE
        Import-OMGenres -Path "E:\Music\genres.json" -Merge
        Merges imported genres with existing configuration.
    
    .NOTES
        Use Export-OMGenres to create the backup file.
        Config location: $env:USERPROFILE\.OM\config.json (Windows) or ~/.OM/config.json (Linux/Mac)
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        
        [Parameter()]
        [switch]$Merge,
        
        [Parameter()]
        [switch]$Force,

        [Parameter()]
        [object]$Context
    )
    
    try {
        # Validate file exists
        if (-not (Test-Path -Path $Path)) {
            Write-Error "File not found: $Path"
            return
        }
        
        # Load imported genres
        $importedGenres = Get-Content -Path $Path -Raw | ConvertFrom-Json
        
        if (-not $importedGenres) {
            Write-Error "Failed to parse genres from file: $Path"
            return
        }
        
        # Validate structure
        if (-not $importedGenres.PSObject.Properties['AllowedGenreNames']) {
            Write-Error "Invalid genres file format: Missing AllowedGenreNames"
            return
        }
        
        # Get current config
        $config = Get-OMConfig
        
        # Ensure Show-Message helper available when dot-sourced in tests
        if (-not (Get-Command -Name Show-Message -ErrorAction SilentlyContinue)) {
            $candidates = @()
            if ($PSScriptRoot) { $candidates += Join-Path $PSScriptRoot '..\Private\Utils\Show-Message.ps1' }
            if ($MyInvocation.MyCommand.Path) { $candidates += Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) '..\Private\Utils\Show-Message.ps1' }
            $candidates += Join-Path (Get-Location) 'Private\Utils\Show-Message.ps1'
            foreach ($path in $candidates) { if (Test-Path $path) { . $path; break } }
        }

        # Confirmation
        if (-not $Force -and -not $PSCmdlet.ShouldProcess(
            "OM Genres Configuration",
            "Replace existing genres configuration with imported data?")) {
            Show-Message -Message "Import cancelled." -ForegroundColor Yellow -Context $Context
            return
        }
        
        if ($Merge) {
            Write-Verbose "Merging imported genres with existing configuration..."
            
            # Merge AllowedGenreNames
            $existingAllowed = @($config.Genres.AllowedGenreNames)
            $newAllowed = @($importedGenres.AllowedGenreNames | Where-Object { $_ -notin $existingAllowed })
            $config.Genres.AllowedGenreNames = @($existingAllowed + $newAllowed)
            
            # Merge GenreMappings
            if ($importedGenres.GenreMappings) {
                foreach ($prop in $importedGenres.GenreMappings.PSObject.Properties) {
                    if (-not $config.Genres.GenreMappings.PSObject.Properties[$prop.Name]) {
                        $config.Genres.GenreMappings | Add-Member -NotePropertyName $prop.Name -NotePropertyValue $prop.Value -Force
                    }
                }
            }
            
            # Merge GarbageGenres
            if ($importedGenres.GarbageGenres) {
                $existingGarbage = @($config.Genres.GarbageGenres)
                $newGarbage = @($importedGenres.GarbageGenres | Where-Object { $_ -notin $existingGarbage })
                $config.Genres.GarbageGenres = @($existingGarbage + $newGarbage)
            }
            
            Show-Message -Message ("✓ Merged $($newAllowed.Count) new allowed genres, $(@($importedGenres.GenreMappings.PSObject.Properties).Count) mappings") -ForegroundColor Green -Context $Context
        }
        else {
            Write-Verbose "Replacing existing genres configuration..."
            
            # Replace entire Genres section
            $config.Genres.AllowedGenreNames = $importedGenres.AllowedGenreNames
            $config.Genres.GenreMappings = $importedGenres.GenreMappings
            $config.Genres.GarbageGenres = $importedGenres.GarbageGenres
            
            Show-Message -Message ("✓ Imported $($importedGenres.AllowedGenreNames.Count) allowed genres, $(@($importedGenres.GenreMappings.PSObject.Properties).Count) mappings") -ForegroundColor Green -Context $Context
        }
        
        # Save config
        $configPath = if ($IsLinux -or $IsMacOS) {
            Join-Path $HOME '.OM' 'config.json'
        } else {
            Join-Path $env:USERPROFILE '.OM' 'config.json'
        }
        
        $config | ConvertTo-Json -Depth 10 | Set-Content -Path $configPath -Encoding UTF8
        
        Show-Message -Message ("✓ Genres configuration saved to: $configPath") -ForegroundColor Green -Context $Context
    }
    catch {
        Write-Error "Failed to import genres configuration: $_"
    }
}

