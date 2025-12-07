function Export-OMGenres {
    <#
    .SYNOPSIS
        Export genre configuration (allowed genres, mappings, and garbage list) to a JSON file.
    
    .DESCRIPTION
        Exports the complete Genres configuration section from the OM config to a JSON file.
        This includes:
        - AllowedGenreNames: The whitelist of accepted genres
        - GenreMappings: Source-to-target genre mappings
        - GarbageGenres: List of genres to ignore/remove
        
        Use this to backup your genre configuration or sync it between multiple computers.
    
    .PARAMETER Path
        The path where the genres configuration JSON file will be saved.
        If the file exists, it will be overwritten.
    
    .PARAMETER PassThru
        If specified, returns the exported genres object to the pipeline.
    
    .EXAMPLE
        Export-OMGenres -Path "E:\Music\genres-backup.json"
        Exports genres configuration to the specified file.
    
    .EXAMPLE
        Export-OMGenres -Path "D:\Backup\genres.json" -PassThru
        Exports and also returns the genres object.
    
    .NOTES
        Use Import-OMGenres to restore or sync the configuration on another machine.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        
        [Parameter()]
        [switch]$PassThru
    )
    
    try {
        # Get current configuration
        $config = Get-OMConfig
        
        if (-not $config.Genres) {
            Write-Warning "No Genres configuration found in config."
            return
        }
        
        # Export Genres section to JSON
        $config.Genres | ConvertTo-Json -Depth 10 | Set-Content -Path $Path -Encoding UTF8
        
        Write-Host "✓ Genres configuration exported to: $Path" -ForegroundColor Green
        Write-Verbose "Exported $($config.Genres.AllowedGenreNames.Count) allowed genres, $($config.Genres.GenreMappings.PSObject.Properties.Count) mappings"
        
        if ($PassThru) {
            return $config.Genres
        }
    }
    catch {
        Write-Error "Failed to export genres configuration: $_"
    }
}
