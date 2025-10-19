function Get-DAlbumTracks {
    <#
    .SYNOPSIS
    Get tracks from a Discogs release.
    
    .DESCRIPTION
    Retrieves the track listing from a specific Discogs release ID.
    Transforms the data to match Spotify-like structure for compatibility.
    
    .PARAMETER Id
    The Discogs release ID (numeric).
    
    .EXAMPLE
    Get-DAlbumTracks -Id 249504
    Gets tracks for release ID 249504.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Id
    )

    try {
        Write-Verbose "Fetching Discogs release $Id..."
        
        # Check if this is a master ID that needs resolution
        # Masters cannot be fetched directly for tracks - need to resolve to main_release first
        $releaseId = $Id
        if ($Id -match '^m?(\d+)$') {
            $numericId = $matches[1]
            
            # Try to fetch as master first to check if it exists
            try {
                $master = Invoke-DiscogsRequest -Uri "/masters/$numericId"
                if ($master -and $master.main_release) {
                    Write-Verbose "Master $numericId detected, resolving to main_release: $($master.main_release)"
                    $releaseId = [string]$master.main_release
                }
            } catch {
                # Not a master, treat as release ID
                Write-Verbose "Not a master or failed to fetch master $numericId, treating as release ID"
                $releaseId = $numericId
            }
        }
        
        # Get release details using resolved release ID
        #remove the r prefix if present
        if ($releaseId -match '^r?(\d+)$') {
            $releaseId = $matches[1]
        }
        
        $release = Invoke-DiscogsRequest -Uri "/releases/$releaseId"
        
        if (-not $release) {
            Write-Warning "No release found for ID: $releaseId (original: $Id)"
            return @()
        }
        
        $parsePosition = {
            param([string]$Position)

            if ([string]::IsNullOrWhiteSpace($Position)) {
                return $null
            }

            if ($Position -match '^([A-Z])(\d+)$') {
                return [ordered]@{
                    Disc  = [char]::ToUpper($matches[1]) - 64
                    Track = [int]$matches[2]
                }
            }

            if ($Position -match '^(\d+)-(\d+)$') {
                return [ordered]@{
                    Disc  = [int]$matches[1]
                    Track = [int]$matches[2]
                }
            }

            if ($Position -match '^\d+$') {
                return [ordered]@{
                    Disc  = 1
                    Track = [int]$Position
                }
            }

            if ($Position -match '(\d+)') {
                return [ordered]@{
                    Disc  = 1
                    Track = [int]$matches[1]
                }
            }

            return $null
        }

        $getDurationMs = {
            param(
                [string]$PrimaryDuration,
                [string]$FallbackDuration
            )

            foreach ($candidate in @($PrimaryDuration, $FallbackDuration)) {
                if ([string]::IsNullOrWhiteSpace($candidate)) {
                    continue
                }

                if ($candidate -match '^(\d+):(\d+)$') {
                    $minutes = [int]$matches[1]
                    $seconds = [int]$matches[2]
                    return ($minutes * 60 + $seconds) * 1000
                }
            }

            return 0
        }

        $extractContributors = {
            param(
                [object]$Track,
                [object]$ParentTrack
            )

            $entries = @()

            $trackArtistsProp = if ($Track) { $Track.PSObject.Properties['artists'] } else { $null }
            if ($trackArtistsProp -and $trackArtistsProp.Value) {
                $entries += @($trackArtistsProp.Value)
            }

            $trackExtrasProp = if ($Track) { $Track.PSObject.Properties['extraartists'] } else { $null }
            if ($trackExtrasProp -and $trackExtrasProp.Value) {
                $entries += @($trackExtrasProp.Value)
            }

            $parentExtrasProp = if ($ParentTrack) { $ParentTrack.PSObject.Properties['extraartists'] } else { $null }
            if ($parentExtrasProp -and $parentExtrasProp.Value) {
                $entries += @($parentExtrasProp.Value)
            }

            $performers = [System.Collections.Generic.List[string]]::new()
            $composers  = [System.Collections.Generic.List[string]]::new()
            $conductors = [System.Collections.Generic.List[string]]::new()

            foreach ($entry in $entries) {
                if (-not $entry) { continue }
                $name = $entry.name
                if (-not $name) { continue }
                $role = [string]$entry.role

                if ($role -match '(?i)composer|composed by') {
                    if (-not $composers.Contains($name)) { [void]$composers.Add($name) }
                    continue
                }

                if ($role -match '(?i)conductor') {
                    if (-not $conductors.Contains($name)) { [void]$conductors.Add($name) }
                }

                if ([string]::IsNullOrWhiteSpace($role)) {
                    if (-not $performers.Contains($name)) { [void]$performers.Add($name) }
                }
                else {
                    $decorated = "$name ($role)"
                    if (-not $performers.Contains($decorated)) { [void]$performers.Add($decorated) }
                }
            }

            $releaseArtistsProp = $release.PSObject.Properties['artists']
            if ($performers.Count -eq 0 -and $releaseArtistsProp -and $releaseArtistsProp.Value) {
                foreach ($artist in @($releaseArtistsProp.Value)) {
                    if ($artist.name -and -not $performers.Contains($artist.name)) {
                        [void]$performers.Add($artist.name)
                    }
                }
            }

            [PSCustomObject]@{
                Performers = $performers.ToArray()
                Composers  = $composers.ToArray()
                Conductors = $conductors.ToArray()
            }
        }

        $buildTrackObject = {
            param(
                [string]$Title,
                [string]$PositionValue,
                [hashtable]$PositionInfo,
                [int]$DurationMs,
                [pscustomobject]$Contributors
            )

            $artistList = @()
            if ($Contributors.Performers -and $Contributors.Performers.Count -gt 0) {
                $artistList = $Contributors.Performers |
                    Where-Object { $_ } |
                    Select-Object -Unique |
                    ForEach-Object { [PSCustomObject]@{ name = $_ } }
            }

            if ($artistList.Count -eq 0 -and $Contributors.Composers -and $Contributors.Composers.Count -gt 0) {
                $artistList = $Contributors.Composers |
                    Where-Object { $_ } |
                    Select-Object -Unique |
                    ForEach-Object { [PSCustomObject]@{ name = $_ } }
            }

            if ($artistList.Count -eq 0) {
                $artistList = @([PSCustomObject]@{ name = 'Unknown Artist' })
            }

            $trackObj = [PSCustomObject]@{
                id           = "$Id-$PositionValue"
                name         = $Title
                title        = $Title
                disc_number  = $PositionInfo.Disc
                track_number = $PositionInfo.Track
                duration_ms  = $DurationMs
                position     = $PositionValue
                artists      = $artistList
            }

            if ($Contributors.Composers -and $Contributors.Composers.Count -gt 0) {
                $trackObj | Add-Member -NotePropertyName composer -NotePropertyValue ($Contributors.Composers | Where-Object { $_ } | Select-Object -Unique)
            }

            if ($Contributors.Conductors -and $Contributors.Conductors.Count -gt 0) {
                $trackObj | Add-Member -NotePropertyName Conductor -NotePropertyValue (($Contributors.Conductors | Where-Object { $_ }) -join '; ')
            }

            return $trackObj
        }

        $processTrack = $null
        $sequentialTrackNumber = 0

        $processTrack = {
            param(
                [object]$Track,
                [object]$ParentTrack,
                [hashtable]$ParentPosition
            )

            if (-not $Track) {
                return @()
            }

            $results = @()

            $subTracks = @()
            $subTracksProp = $Track.PSObject.Properties['sub_tracks']
            if ($subTracksProp -and $subTracksProp.Value) {
                $subTracks = @($subTracksProp.Value)
            }

            if ($subTracks.Count -gt 0) {
                $basePosition = & $parsePosition $Track.position
                if (-not $basePosition) {
                    $basePosition = if ($ParentPosition) { $ParentPosition } else { [ordered]@{ Disc = 1; Track = 0 } }
                }

                foreach ($subTrack in $subTracks) {
                    if (-not $subTrack) { continue }
                    $results += & $processTrack $subTrack $Track $basePosition
                }

                return $results
            }

            if (($Track.type_ -in @('heading','index')) -and -not $Track.title) {
                return $results
            }

            $positionValue = $Track.position
            $positionInfo = & $parsePosition $positionValue

            if (-not $positionInfo) {
                $sequentialTrackNumber++
                $positionInfo = [ordered]@{
                    Disc  = if ($ParentPosition) { $ParentPosition.Disc } else { 1 }
                    Track = $sequentialTrackNumber
                }

                if ([string]::IsNullOrWhiteSpace($positionValue)) {
                    $positionValue = "{0}-{1}" -f $positionInfo.Disc, $positionInfo.Track
                }
            }

            $parentDuration = if ($ParentTrack) { $ParentTrack.duration } else { $null }
            $durationMs = & $getDurationMs $Track.duration $parentDuration
            $contributors = & $extractContributors $Track $ParentTrack

            $title = if ($Track.title) { $Track.title } elseif ($ParentTrack) { $ParentTrack.title } else { $null }
            if (-not $title) {
                return $results
            }

            $results += & $buildTrackObject $title $positionValue $positionInfo $durationMs $contributors
            return $results
        }

        # Extract tracks from tracklist (including nested sub-tracks)
        $tracks = @()

        if ($release.tracklist) {
            foreach ($track in $release.tracklist) {
                $tracks += & $processTrack $track $null $null
            }
        }
        
        Write-Verbose "Found $($tracks.Count) tracks for release $Id"
        return $tracks
    }
    catch {
        Write-Warning "Failed to get Discogs release tracks: $_"
        return @()
    }
}
