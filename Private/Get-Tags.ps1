 
function Get-Tags {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [object]$Artist,

        [Parameter(Mandatory = $true)]
        [object]$Album,

        [Parameter(Mandatory = $true)]
        [object]$SpotifyTrack,
        
        [Parameter(Mandatory = $false)]
        [string]$ManualAlbumArtist
    )

    # Get genres - prefer track-level genres (e.g., from MusicBrainz) over artist-level
    $genreT = if ($trackGenres = Get-IfExists $SpotifyTrack 'genres') {
        # Track has genres - use them directly
        Write-Verbose "Using track-level genres: $($trackGenres -join ', ')"
        $trackGenres -join ', '
    } else {
        # Fall back to artist/album genres
        Write-Verbose "No track-level genres, using artist/album genres"
        Get-GenresTags -ProviderArtist $Artist -ProviderAlbum $Album
    }
    $year = Get-IfExists $Album 'release_date'
    if ($year -match '^(?<year>\d{4})') { $Year = $matches.year } else { $Year = 0000 }
    
    # Extract album artist value
    # Priority: Manual override > Classical performer detection > Default artist name
    $albumArtistValue = if ($ManualAlbumArtist) { 
        Write-Verbose "Using manual album artist override: $ManualAlbumArtist"
        $ManualAlbumArtist 
    } elseif ($value = Get-IfExists $Artist 'name') { 
        $value 
    } else { 
        $Artist 
    }
    
    # Check if this is classical music
    $isClassical = $false
    $albumGenre = Get-IfExists $Album 'genre'
    $albumGenres = Get-IfExists $Album 'genres'
    
    if ($albumGenre -and $albumGenre -match '(?i)classical') {
        $isClassical = $true
    } elseif ($albumGenres -and ($albumGenres -join ', ') -match '(?i)classical') {
        $isClassical = $true
    } elseif ($genreT -match '(?i)classical') {
        $isClassical = $true
    }
    
    # For classical music, use performers as album artist if available (unless manually overridden)
    if ($isClassical -and -not $ManualAlbumArtist) {
        Write-Verbose "Classical music detected, checking for performers as album artist"
        
        # Try to get conductor from track
        $conductor = Get-IfExists $SpotifyTrack 'Conductor'
        
        # Try to get ensemble/orchestra from artists
        # Collect all ensemble-type performers, not just the first one
        $ensembles = @()
        if ($value = Get-IfExists $SpotifyTrack 'artists') {
            Write-Verbose "  Checking artists array (count: $(if ($value -is [array]) { $value.Count } else { 1 }))"
            if ($value -is [array]) {
                foreach ($a in $value) {
                    $name = if ($a.name) { $a.name } else { $a.ToString() }
                    Write-Verbose "    Artist: $name"
                    # Skip composers (single person names without ensemble indicators)
                    # Include English, French, German, Italian ensemble names
                    if ($name -match '(?i)(orchestra|orchestre|orchester|philharmonic|philharmonique|philharmoniker|symphony|symphonie|sinfonie|sinfonieorchester|ensemble|choir|chorus|choeur|chor|quartet|quartett|quatuor|trio)') {
                        if ($name -notin $ensembles) {
                            $ensembles += $name
                            Write-Verbose "      -> Identified as ensemble"
                        }
                    }
                }
            }
        }
        
        # Build classical album artist from performers
        $performerParts = @()
        
        # Add conductor first if available
        if ($conductor) { 
            $performerParts += $conductor 
            Write-Verbose "  Found conductor: $conductor"
        }
        
        # Add all ensembles
        if ($ensembles.Count -gt 0) {
            $performerParts += $ensembles
            Write-Verbose "  Found ensemble(s): $($ensembles -join ', ')"
        }
        
        # Use performers if we found any
        if ($performerParts.Count -gt 0) {
            $albumArtistValue = $performerParts -join ', '
            Write-Verbose "Using performers as album artist: $albumArtistValue"
        } else {
            Write-Verbose "No performers found in track data, keeping original album artist: $albumArtistValue"
        }
    }

    # Extract track title (handle both Spotify 'name' and Qobuz 'title' properties)
    $trackTitle = if ($value = Get-IfExists $SpotifyTrack 'name') { $value } elseif ($value = Get-IfExists $SpotifyTrack 'title') { $value } else { 'Unknown Title' }
    
    # Extract track number (handle both formats)
    $trackNumber = if ($value = Get-IfExists $SpotifyTrack 'track_number') { $value } elseif ($value = Get-IfExists $SpotifyTrack 'TrackNumber') { $value } else { 0 }
    
    # Extract disc number (handle both formats)
    $discNumber = if ($value = Get-IfExists $SpotifyTrack 'disc_number') { $value } elseif ($value = Get-IfExists $SpotifyTrack 'DiscNumber') { $value } else { 1 }

    # Extract and format performers (artists) - handle multiple provider formats
    $artistT = 'Unknown Artist'
    if ($value = Get-IfExists $SpotifyTrack 'artists') {
        if ($value -is [array]) {
            $artistT = ($value | ForEach-Object { if ($_.name) { $_.name } else { $_.ToString() } }) -join '; '
        } elseif ($value.name) {
            $artistT = $value.name
        } else {
            $artistT = $value.ToString()
        }
    } elseif ($value = Get-IfExists $SpotifyTrack 'performer') {
        $artistT = if ($value -is [array]) { $value -join '; ' } else { $value }
    } elseif ($value = Get-IfExists $SpotifyTrack 'Artist') {
        $artistT = if ($value -is [array]) { $value -join '; ' } else { $value }
    }

    # Build the tags hashtable
    $tags = @{
        Title       = $trackTitle
        Track       = "{0:D2}" -f $trackNumber
        Disc        = "{0:D2}" -f $discNumber
        Performers  = $artistT
        Genres      = $genreT
        AlbumArtist = $albumArtistValue
        Date        = $Year
        Album       = Get-IfExists $Album 'name'
    }

    # Conditionally add composers if present in the Spotify track
    if ($value = Get-IfExists $SpotifyTrack  'composer') {
        $tags.Composers = $value -join '; '
    }

    # Add Conductor if present (Qobuz classical music)
    if ($value = Get-IfExists $SpotifyTrack 'Conductor') {
        $tags.Conductor = $value
    }

    # Add Comment field with full production credits (Qobuz)
    if ($value = Get-IfExists $SpotifyTrack 'Comment') {
        try {
            $decoded = [System.Net.WebUtility]::HtmlDecode([string]$value)
        } catch {
            $decoded = [string]$value
        }
        # Strip any trailing Production Credits block
        $decoded = ($decoded -split '(?m)---\s*Production Credits\s*---',2)[0].Trim()
        $tags.Comment = $decoded
    }

    # Return the tags hashtable
    return $tags
}
