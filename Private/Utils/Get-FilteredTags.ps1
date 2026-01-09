function Get-FilteredTags {
    <#
    .SYNOPSIS
        Filters a tags hashtable based on the UpdateOnly parameter.
    
    .DESCRIPTION
        Takes a full tags hashtable from Get-Tags and returns a filtered version
        containing only the fields specified in UpdateOnly. If UpdateOnly contains
        'All', returns the original hashtable unchanged.
    
    .PARAMETER Tags
        The original tags hashtable from Get-Tags.
    
    .PARAMETER UpdateOnly
        Array of field categories to include. Valid values:
        - 'All': Return all fields (no filtering)
        - 'Genres': Include Genres field
        - 'Year': Include Date field
        - 'AlbumArtist': Include AlbumArtist field
        - 'Artists': Include Performers field
        - 'TrackInfo': Include Title, Track, Disc fields
        - 'Album': Include Album field
        - 'Composers': Include Composers and Conductor fields
        - 'CoverArt': Not handled here (cover art is saved separately)
    
    .OUTPUTS
        Hashtable with only the requested fields.
    
    .EXAMPLE
        $filtered = Get-FilteredTags -Tags $tags -UpdateOnly @('Genres', 'Year')
        # Returns hashtable with only Genres and Date fields
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Tags,
        
        [Parameter()]
        [string[]]$UpdateOnly = @('All')
    )
    
    # If 'All' is specified, return original tags
    if ($UpdateOnly -contains 'All') {
        return $Tags
    }
    
    $filteredTags = @{}
    
    if ('Genres' -in $UpdateOnly) { 
        if ($Tags.ContainsKey('Genres')) { $filteredTags.Genres = $Tags.Genres }
    }
    
    if ('Year' -in $UpdateOnly) { 
        if ($Tags.ContainsKey('Date')) { $filteredTags.Date = $Tags.Date }
    }
    
    if ('AlbumArtist' -in $UpdateOnly) { 
        if ($Tags.ContainsKey('AlbumArtist')) { $filteredTags.AlbumArtist = $Tags.AlbumArtist }
    }
    
    if ('Artists' -in $UpdateOnly) { 
        if ($Tags.ContainsKey('Performers')) { $filteredTags.Performers = $Tags.Performers }
    }
    
    if ('TrackInfo' -in $UpdateOnly) { 
        if ($Tags.ContainsKey('Title')) { $filteredTags.Title = $Tags.Title }
        if ($Tags.ContainsKey('Track')) { $filteredTags.Track = $Tags.Track }
        if ($Tags.ContainsKey('Disc')) { $filteredTags.Disc = $Tags.Disc }
    }
    
    if ('Album' -in $UpdateOnly) { 
        if ($Tags.ContainsKey('Album')) { $filteredTags.Album = $Tags.Album }
    }
    
    if ('Composers' -in $UpdateOnly) { 
        if ($Tags.ContainsKey('Composers')) { $filteredTags.Composers = $Tags.Composers }
        if ($Tags.ContainsKey('Conductor')) { $filteredTags.Conductor = $Tags.Conductor }
    }
    
    Write-Verbose "Filtered tags to: $($filteredTags.Keys -join ', ')"
    
    return $filteredTags
}
