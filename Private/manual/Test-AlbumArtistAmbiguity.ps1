function Test-AlbumArtistAmbiguity {
    <#
    .SYNOPSIS
        Detects if an album has ambiguous album artist assignment (especially classical music).
    
    .DESCRIPTION
        For classical music, album artist is often ambiguous when multiple artists are listed
        without clear role information (composer vs. performer). This function detects such cases.
    
    .PARAMETER Artist
        Artist object with genre information (optional, used as fallback).
    
    .PARAMETER Album
        Album object with genre information.
    
    .PARAMETER Tracks
        Array of track objects with artist information.
    
    .EXAMPLE
        $isAmbiguous = Test-AlbumArtistAmbiguity -Artist $artist -Album $album -Tracks $tracks
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [object]$Artist,
        
        [Parameter(Mandatory = $true)]
        [object]$Album,
        
        [Parameter(Mandatory = $true)]
        [array]$Tracks
    )

    # Check if this is classical music - use Get-IfExists for safe property access
    # Try artist genres first (more reliable), then album
    $isClassical = $false
    
    if ($Artist) {
        $artistGenres = Get-IfExists $Artist 'genres'
        Write-Verbose "Artist genres: $($artistGenres -join ', ')"
        if ($artistGenres -and ($artistGenres -join ', ') -match '(?i)classical') {
            $isClassical = $true
            Write-Verbose "Classical music detected from artist genres"
        }
    }
    
    if (-not $isClassical) {
        $albumGenre = Get-IfExists $Album 'genre'
        $albumGenres = Get-IfExists $Album 'genres'
        Write-Verbose "Album genre (singular): $albumGenre"
        Write-Verbose "Album genres (plural): $($albumGenres -join ', ')"
        
        if ($albumGenre -and $albumGenre -match '(?i)classical') {
            $isClassical = $true
            Write-Verbose "Classical music detected from album genre"
        } elseif ($albumGenres -and ($albumGenres -join ', ') -match '(?i)classical') {
            $isClassical = $true
            Write-Verbose "Classical music detected from album genres"
        }
    }
    
    # Also check track genres (MusicBrainz stores genres at track level)
    if (-not $isClassical -and $Tracks -and $Tracks.Count -gt 0) {
        $firstTrack = $Tracks[0]
        $trackGenres = Get-IfExists $firstTrack 'genres'
        Write-Verbose "Track genres: $($trackGenres -join ', ')"
        if ($trackGenres -and ($trackGenres -join ', ') -match '(?i)classical') {
            $isClassical = $true
            Write-Verbose "Classical music detected from track genres"
        }
    }

    if (-not $isClassical) {
        Write-Verbose "Not classical music, no ambiguity"
        return $false
    }

    # Get unique artists from first track (representative sample)
    if (-not $Tracks -or $Tracks.Count -eq 0) {
        Write-Verbose "No tracks to analyze"
        return $false
    }

    $firstTrack = $Tracks[0]
    if (-not $firstTrack.artists -or $firstTrack.artists.Count -le 1) {
        Write-Verbose "Only one artist, no ambiguity"
        return $false
    }

    # Check if we have explicit role information
    $hasExplicitRoles = $false
    
    # Check for composer property (Discogs/Qobuz provide this)
    if ($firstTrack.PSObject.Properties['composer'] -and $firstTrack.composer) {
        $hasExplicitRoles = $true
        Write-Verbose "Track has explicit composer property"
    }
    
    # Check for conductor property
    if ($firstTrack.PSObject.Properties['Conductor'] -and $firstTrack.Conductor) {
        $hasExplicitRoles = $true
        Write-Verbose "Track has explicit conductor property"
    }

    # Check if artist objects have role information
    foreach ($artist in $firstTrack.artists) {
        if ($artist.PSObject.Properties['role'] -and $artist.role) {
            $hasExplicitRoles = $true
            Write-Verbose "Artist has explicit role: $($artist.name) - $($artist.role)"
            break
        }
        if ($artist.PSObject.Properties['type'] -and $artist.type) {
            $hasExplicitRoles = $true
            Write-Verbose "Artist has explicit type: $($artist.name) - $($artist.type)"
            break
        }
    }

    # If we have multiple artists but no clear ensemble (orchestra, etc.), it's ambiguous
    $artistNames = $firstTrack.artists | ForEach-Object { $_.name }
    $hasEnsemble = $false
    foreach ($name in $artistNames) {
        if ($name -match '(?i)(orchestra|orchestre|orchester|philharmonic|philharmonique|philharmoniker|symphony|symphonie|sinfonie|sinfonieorchester|ensemble|choir|chorus|choeur|chor|quartet|quartett|quatuor|trio)') {
            $hasEnsemble = $true
            Write-Verbose "Found ensemble: $name"
            break
        }
    }

    # Ambiguous if:
    # - Classical music
    # - Multiple artists (>1)
    # - No explicit role data OR no clear ensemble
    $isAmbiguous = $firstTrack.artists.Count -gt 1 -and (-not $hasExplicitRoles -or -not $hasEnsemble)
    
    if ($isAmbiguous) {
        Write-Verbose "Album artist is ambiguous: $($firstTrack.artists.Count) artists, hasExplicitRoles=$hasExplicitRoles, hasEnsemble=$hasEnsemble"
    } else {
        Write-Verbose "Album artist is clear: roles or ensemble found"
    }

    return $isAmbiguous
}
