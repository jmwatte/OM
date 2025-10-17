function Get-MBArtistLatinName {
    <#
    .SYNOPSIS
    Get the Latin/romanized name for a MusicBrainz artist.
    
    .DESCRIPTION
    Fetches artist details from MusicBrainz and returns the best Latin script name.
    Useful for getting "Yuri Simonov" instead of "Юрий Симонов".
    
    Priority order:
    1. English locale alias (locale=en)
    2. Latin script alias (script=Latn)
    3. Sort name if it's in Latin script
    4. Original name as fallback
    
    .PARAMETER ArtistId
    MusicBrainz Artist ID (MBID)
    
    .PARAMETER OriginalName
    The original artist name (for fallback if no Latin alias found)
    
    .EXAMPLE
    Get-MBArtistLatinName -ArtistId "abc123" -OriginalName "Юрий Симонов"
    Returns: "Yuri Simonov"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ArtistId,
        
        [Parameter(Mandatory = $false)]
        [string]$OriginalName = ""
    )

    try {
        # Request artist with aliases
        $artist = Invoke-MusicBrainzRequest -Endpoint 'artist' -Id $ArtistId -Inc 'aliases'
        
        if (-not $artist) {
            Write-Verbose "Could not fetch artist details for $ArtistId"
            return $OriginalName
        }
        
        # Check if we have aliases
        $aliases = @()
        if ($artist.PSObject.Properties['aliases'] -and $artist.aliases) {
            $aliases = @($artist.aliases)
        }
        
        if ($aliases.Count -eq 0) {
            Write-Verbose "No aliases found for artist $ArtistId"
            return $OriginalName
        }
        
        Write-Verbose "Found $($aliases.Count) aliases for artist"
        
        # Priority 1: English locale alias
        $enAlias = $aliases | Where-Object { 
            $_.PSObject.Properties['locale'] -and $_.locale -eq 'en' -and 
            $_.PSObject.Properties['name'] -and $_.name
        } | Select-Object -First 1
        
        if ($enAlias) {
            Write-Verbose "Using English locale alias: $($enAlias.name)"
            return $enAlias.name
        }
        
        # Priority 2: Latin script alias
        $latinAlias = $aliases | Where-Object { 
            $_.PSObject.Properties['type'] -and $_.type -ne 'Search hint' -and
            $_.PSObject.Properties['name'] -and $_.name -match '^[a-zA-Z\s\-\.]+$'
        } | Select-Object -First 1
        
        if ($latinAlias) {
            Write-Verbose "Using Latin script alias: $($latinAlias.name)"
            return $latinAlias.name
        }
        
        # Priority 3: Sort name if in Latin script
        if ($artist.PSObject.Properties['sort-name'] -and $artist.'sort-name' -match '^[a-zA-Z\s\-\,\.]+$') {
            Write-Verbose "Using sort-name: $($artist.'sort-name')"
            return $artist.'sort-name'
        }
        
        # Fallback: Original name
        Write-Verbose "No Latin alias found, using original name"
        return $OriginalName
    }
    catch {
        Write-Warning "Failed to get Latin name for artist $ArtistId : $_"
        return $OriginalName
    }
}
