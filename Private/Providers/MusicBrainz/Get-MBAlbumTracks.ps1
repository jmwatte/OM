function Get-MBAlbumTracks {
    <#
    .SYNOPSIS
    Get tracks (recordings) from a MusicBrainz release.
    
    .DESCRIPTION
    Retrieves the track listing from a specific MusicBrainz release ID (MBID).
    Includes detailed artist credits and relationships (conductor, performer, etc.).
    Returns normalized track objects compatible with MuFo workflow.
    
    .PARAMETER Id
    MusicBrainz Release ID (MBID)
    
    .EXAMPLE
    Get-MBAlbumTracks -Id "f5e5f36f-4779-4c0b-9c6e-4b1b0c8c3c3c"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Id
    )

    try {
        Write-Host "🔍 Fetching MusicBrainz release: $Id..." -ForegroundColor Cyan
        
        # Request release with media (tracks), artist credits, and genres/tags
        # Include release-groups to get album-level genre information
        # Include artist-rels to get detailed artist info with aliases (for Latin script names)
        # Include work-rels to get recording→work relationships (the work IDs are in the recording relations)
        # Note: We'll fetch each work separately to get composer relationships
        $inc = 'recordings+artist-credits+media+release-groups+genres+tags+artist-rels+work-rels'
        
        Write-Verbose "Requesting release with inc parameters: $inc"
        $release = Invoke-MusicBrainzRequest -Endpoint 'release' -Id $Id -Inc $inc
        
        if (-not $release) {
            Write-Warning "No release found for ID: $Id"
            return @()
        }
        
        Write-Host "✓ Found release: $($release.title)" -ForegroundColor Green
        
        # Extract genres from release-group (album-level genres)
        $albumGenres = @()
        
        # First try 'genres' property (newer MusicBrainz API)
        if ($release.PSObject.Properties['genres'] -and $release.genres) {
            $albumGenres = @($release.genres | 
                Where-Object { $_ -and $_.PSObject.Properties['name'] } | 
                Select-Object -First 5 -ExpandProperty name)
            if ($albumGenres.Count -gt 0) {
                Write-Verbose "Found $($albumGenres.Count) genres from release.genres"
            }
        }
        
        # Fallback to 'tags' property (older API or when genres not available)
        if ($albumGenres.Count -eq 0 -and $release.PSObject.Properties['tags'] -and $release.tags) {
            $albumGenres = @($release.tags | 
                Where-Object { $_ -and $_.PSObject.Properties['name'] -and $_.PSObject.Properties['count'] -and $_.count -gt 0 } | 
                Sort-Object -Property count -Descending |
                Select-Object -First 5 -ExpandProperty name)
            if ($albumGenres.Count -gt 0) {
                Write-Verbose "Found $($albumGenres.Count) tags from release.tags"
            }
        }
        
        # Also try release-groups if present
        if ($albumGenres.Count -eq 0 -and $release.PSObject.Properties['release-group'] -and $release.'release-group') {
            $rg = $release.'release-group'
            if ($rg.PSObject.Properties['genres'] -and $rg.genres) {
                $albumGenres = @($rg.genres | 
                    Where-Object { $_ -and $_.PSObject.Properties['name'] } | 
                    Select-Object -First 5 -ExpandProperty name)
                if ($albumGenres.Count -gt 0) {
                    Write-Verbose "Found $($albumGenres.Count) genres from release-group.genres"
                }
            } elseif ($rg.PSObject.Properties['tags'] -and $rg.tags) {
                $albumGenres = @($rg.tags | 
                    Where-Object { $_ -and $_.PSObject.Properties['name'] -and $_.PSObject.Properties['count'] -and $_.count -gt 0 } | 
                    Sort-Object -Property count -Descending |
                    Select-Object -First 5 -ExpandProperty name)
                if ($albumGenres.Count -gt 0) {
                    Write-Verbose "Found $($albumGenres.Count) tags from release-group.tags"
                }
            }
        }
        
        if ($albumGenres.Count -eq 0) {
            Write-Verbose "No genres/tags found for release $Id"
            $albumGenres = @('Unknown')
        } else {
            Write-Verbose "Using album genres: $($albumGenres -join ', ')"
        }
        
        # Extract tracks from media (ensure it's an array)
        $media = @()
        if (Get-IfExists $release 'media') {
            $media = @($release.media)
        }
        
        if ($media.Count -eq 0) {
            Write-Warning "Release $Id has no media/tracks"
            return @()
        }
        
        $allTracks = @()
        $totalTracks = 0
        foreach ($medium in $media) {
            $tracks = if (Get-IfExists $medium 'tracks') { $medium.tracks } else { @() }
            $totalTracks += $tracks.Count
        }
        
        Write-Host "📀 Processing $totalTracks tracks..." -ForegroundColor Cyan
        
        # Cache for work details to avoid redundant API calls
        # Classical albums often have multiple tracks linking to the same work (movements)
        $workCache = @{}
        $processedTracks = 0
        
        foreach ($medium in $media) {
            $discNumber = if (Get-IfExists $medium 'position') { $medium.position } else { 1 }
            $tracks = if (Get-IfExists $medium 'tracks') { $medium.tracks } else { @() }
            
            foreach ($track in $tracks) {
                $recording = if (Get-IfExists $track 'recording') { $track.recording } else { $null }
                
                if (-not $recording) {
                    Write-Verbose "Track missing recording data, skipping"
                    continue
                }
                
                $processedTracks++
                
                # Show progress for every 10 tracks or first/last
                if ($processedTracks % 10 -eq 0 -or $processedTracks -eq 1 -or $processedTracks -eq $totalTracks) {
                    Write-Host "  Processing track $processedTracks/$totalTracks..." -ForegroundColor Gray
                }
                
                # Extract artist credits
                $artists = @()
                if (Get-IfExists $recording 'artist-credit') {
                    foreach ($credit in $recording.'artist-credit') {
                        if (Get-IfExists $credit 'artist' -and (Get-IfExists $credit.artist 'name')) {
                            $artistName = $credit.artist.name
                            $artistId = if (Get-IfExists $credit.artist 'id') { $credit.artist.id } else { $null }
                            
                            # If name contains non-Latin characters (Cyrillic, etc.), try to get Latin alias
                            if ($artistId -and $artistName -match '[^\x00-\x7F]') {
                                Write-Verbose "Artist name '$artistName' contains non-Latin characters, fetching Latin alias..."
                                $latinName = Get-MBArtistLatinName -ArtistId $artistId -OriginalName $artistName
                                if ($latinName -and $latinName -ne $artistName) {
                                    Write-Verbose "Using Latin name: $latinName (original: $artistName)"
                                    $artistName = $latinName
                                }
                            }
                            
                            $artists += [PSCustomObject]@{
                                name = $artistName
                                id = $artistId
                            }
                        }
                    }
                }
                
                # If no artists on recording, use release artist
                if ($artists.Count -eq 0 -and (Get-IfExists $release 'artist-credit')) {
                    foreach ($credit in $release.'artist-credit') {
                        if (Get-IfExists $credit 'artist' -and (Get-IfExists $credit.artist 'name')) {
                            $artistName = $credit.artist.name
                            $artistId = if (Get-IfExists $credit.artist 'id') { $credit.artist.id } else { $null }
                            
                            # If name contains non-Latin characters, try to get Latin alias
                            if ($artistId -and $artistName -match '[^\x00-\x7F]') {
                                Write-Verbose "Artist name '$artistName' contains non-Latin characters, fetching Latin alias..."
                                $latinName = Get-MBArtistLatinName -ArtistId $artistId -OriginalName $artistName
                                if ($latinName -and $latinName -ne $artistName) {
                                    Write-Verbose "Using Latin name: $latinName (original: $artistName)"
                                    $artistName = $latinName
                                }
                            }
                            
                            $artists += [PSCustomObject]@{
                                name = $artistName
                                id = $artistId
                            }
                        }
                    }
                }
                
                # Fallback to unknown artist
                if ($artists.Count -eq 0) {
                    $artists = @([PSCustomObject]@{ name = 'Unknown Artist'; id = $null })
                }
                
                # Extract composer from work relationships
                # Note: The /release endpoint doesn't include recording relationships
                # We must fetch each recording individually to get work relationships
                $composer = $null
                
                if ($recording.PSObject.Properties['id'] -and $recording.id) {
                    try {
                        Write-Verbose "Fetching recording details for work/composer information..."
                        $recordingDetails = Invoke-MusicBrainzRequest -Endpoint 'recording' -Id $recording.id -Inc 'work-rels+artist-rels'
                        
                        if ($recordingDetails.PSObject.Properties['relations'] -and $recordingDetails.relations) {
                            Write-Verbose "Recording has $($recordingDetails.relations.Count) relations"
                            
                            # Look for work relationships (type='performance' links recording to work)
                            $workRels = @($recordingDetails.relations | Where-Object { 
                                $_.PSObject.Properties['work'] -and $_.work
                            })
                            
                            Write-Verbose "Found $($workRels.Count) work relationships"
                            
                            if ($workRels.Count -gt 0) {
                                $workStub = $workRels[0].work
                                $workId = if ($workStub.PSObject.Properties['id']) { $workStub.id } else { $null }
                                $workTitle = if ($workStub.PSObject.Properties['title']) { $workStub.title } else { 'Unknown' }
                                
                                Write-Verbose "Found work stub: $workTitle (id: $workId)"
                                
                                # The work stub doesn't include relationships, fetch full work details
                                if ($workId) {
                                    # Check cache first (multiple movements often share the same work)
                                    if ($workCache.ContainsKey($workId)) {
                                        Write-Verbose "Using cached work details for: $workTitle"
                                        $fullWork = $workCache[$workId]
                                    } else {
                                        Write-Verbose "Fetching full work details with composer relationships..."
                                        try {
                                            $fullWork = Invoke-MusicBrainzRequest -Endpoint 'work' -Id $workId -Inc 'artist-rels'
                                            # Cache the work for future tracks
                                            $workCache[$workId] = $fullWork
                                        } catch {
                                            Write-Warning "Failed to fetch work details: $_"
                                            $fullWork = $null
                                        }
                                    }
                                    
                                    if ($fullWork) {
                                        
                                        if ($fullWork.PSObject.Properties['relations'] -and $fullWork.relations) {
                                            Write-Verbose "Work has $($fullWork.relations.Count) relations"
                                            
                                            $composerRels = @($fullWork.relations | Where-Object {
                                                $_.PSObject.Properties['type'] -and $_.type -eq 'composer' -and
                                                $_.PSObject.Properties['artist'] -and $_.artist -and
                                                $_.artist.PSObject.Properties['name']
                                            })
                                            
                                            Write-Verbose "Found $($composerRels.Count) composer relationships"
                                            
                                            if ($composerRels.Count -gt 0) {
                                                $composerName = $composerRels[0].artist.name
                                                $composerId = if ($composerRels[0].artist.PSObject.Properties['id']) { 
                                                    $composerRels[0].artist.id 
                                                } else { 
                                                    $null 
                                                }
                                                
                                                # Check for non-Latin composer name and get Latin alias
                                                if ($composerId -and $composerName -match '[^\x00-\x7F]') {
                                                    Write-Verbose "Composer name '$composerName' contains non-Latin characters, fetching Latin alias..."
                                                    $latinComposer = Get-MBArtistLatinName -ArtistId $composerId -OriginalName $composerName
                                                    if ($latinComposer -and $latinComposer -ne $composerName) {
                                                        Write-Verbose "Using Latin composer name: $latinComposer (original: $composerName)"
                                                        $composerName = $latinComposer
                                                    }
                                                }
                                                
                                                $composer = $composerName
                                                Write-Verbose "Found composer: $composer"
                                            }
                                        } else {
                                            Write-Verbose "Work has no relations property"
                                        }
                                    }
                                }
                            }
                        } else {
                            Write-Verbose "Recording details have no relations property"
                        }
                    } catch {
                        Write-Warning "Failed to fetch recording details for composer: $_"
                        if ($_.Exception.InnerException) {
                            Write-Verbose "Inner exception details: $($_.Exception.InnerException.Message)"
                        }
                    }
                }
                
                # Extract duration (in milliseconds)
                $durationMs = 0
                if (Get-IfExists $recording 'length') {
                    $durationMs = [int]$recording.length
                } elseif (Get-IfExists $track 'length') {
                    $durationMs = [int]$track.length
                }
                
                # Track position/number
                $trackNumber = if (Get-IfExists $track 'position') { 
                    [int]$track.position 
                } else { 
                    $allTracks.Count + 1 
                }
                
                # Build track object
                $trackObj = [PSCustomObject]@{
                    id = $recording.id  # Recording MBID
                    name = $recording.title
                    title = $recording.title
                    disc_number = $discNumber
                    track_number = $trackNumber
                    duration_ms = $durationMs
                    artists = $artists
                    genres = $albumGenres  # Add album-level genres to track
                    composer = $composer  # Add composer from work relationships
                    _rawMusicBrainzObject = $recording
                }
                
                $allTracks += $trackObj
            }
        }
        
        Write-Host "✓ Completed processing $($allTracks.Count) tracks" -ForegroundColor Green
        if ($workCache.Count -gt 0) {
            Write-Host "  (Fetched $($workCache.Count) unique works for composer information)" -ForegroundColor Gray
        }
        return $allTracks
    }
    catch {
        Write-Warning "Failed to get MusicBrainz release tracks: $_"
        return @()
    }
}