function Export-OMPlaylists {
    <#
    .SYNOPSIS
        Export Spotify playlists to CSV files (one file per playlist).

    .DESCRIPTION
        Retrieves the current user's Spotify playlists and exports each one to a CSV file.
        Each track includes artist, album, duration, release date, and Spotify URL.
        Optionally includes audio features like musical key, tempo, danceability, etc.

        Requires Spotishell module and a configured Spotify application
        (New-SpotifyApplication or existing OM Spotify config).

    .PARAMETER OutputPath
        Directory where CSV files will be saved. Defaults to ~/.OM/playlists/.

    .PARAMETER Name
        Filter to specific playlist(s) by name. Supports wildcards.
        If omitted, an interactive grid view picker is shown.

    .PARAMETER All
        Export all playlists without prompting for selection.

    .PARAMETER IncludeAudioFeatures
        Include audio feature columns: Key, Mode, Tempo, TimeSignature,
        Danceability, Energy, Acousticness, Instrumentalness, Speechiness,
        Liveness, Valence, Loudness.

    .EXAMPLE
        Export-OMPlaylists
        Exports all playlists to ~/.OM/playlists/.

    .EXAMPLE
        Export-OMPlaylists -Name "Chill*" -IncludeAudioFeatures
        Exports playlists matching "Chill*" with audio feature columns.

    .EXAMPLE
        Export-OMPlaylists -OutputPath "C:\Music\Playlists" -Name "Favorites"
        Exports the "Favorites" playlist to the specified directory.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$OutputPath,

        [Parameter()]
        [string[]]$Name,

        [Parameter()]
        [switch]$All,

        [Parameter()]
        [switch]$IncludeAudioFeatures
    )

    # Key number to note name mapping (Spotify pitch class notation)
    $KeyNames = @('C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B')
    $ModeNames = @{ 0 = 'Minor'; 1 = 'Major' }

    # Resolve output directory
    if (-not $OutputPath) {
        $OutputPath = Join-Path ([Environment]::GetFolderPath('UserProfile')) '.OM' 'playlists'
    }
    if (-not (Test-Path $OutputPath)) {
        New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
    }

    # Ensure Spotishell is available
    if (-not (Get-Module -Name Spotishell)) {
        try {
            Import-Module Spotishell -ErrorAction Stop
        }
        catch {
            Write-Error "Spotishell module is required. Install with: Install-Module Spotishell"
            return
        }
    }

    # Fetch playlists
    Write-Host "Fetching playlists..." -ForegroundColor Cyan
    $playlists = Get-CurrentUserPlaylists
    if (-not $playlists) {
        Write-Warning "No playlists found."
        return
    }

    # Filter by name if specified
    if ($Name) {
        $filtered = @()
        foreach ($pattern in $Name) {
            $filtered += @($playlists | Where-Object { $_.name -like $pattern })
        }
        $playlists = $filtered | Sort-Object -Property id -Unique
        if (-not $playlists) {
            Write-Warning "No playlists matched the filter: $($Name -join ', ')"
            return
        }
    }
    elseif (-not $All) {
        # Interactive selection via Out-GridView
        $selection = $playlists |
            Select-Object @{N='Name';E={$_.name}}, @{N='Tracks';E={$_.tracks.total}}, @{N='Owner';E={$_.owner.display_name}}, @{N='Id';E={$_.id}} |
            Out-GridView -Title 'Select playlist(s) to export' -PassThru
        if (-not $selection) {
            Write-Host "No playlists selected." -ForegroundColor Yellow
            return
        }
        $selectedIds = @($selection | ForEach-Object { $_.Id })
        $playlists = @($playlists | Where-Object { $selectedIds -contains $_.id })
    }

    Write-Host "Found $($playlists.Count) playlist(s) to export." -ForegroundColor Cyan
    $exportedFiles = @()

    foreach ($playlist in $playlists) {
        $playlistName = $playlist.name
        Write-Host "`nExporting: $playlistName ($($playlist.tracks.total) tracks)" -ForegroundColor Green

        # Get playlist items
        try {
            $items = Get-PlaylistItems -Id $playlist.id
        }
        catch {
            Write-Warning "  Failed to fetch playlist '$playlistName': $($_.Exception.Message). Skipping."
            continue
        }
        if (-not $items) {
            Write-Warning "  No items in playlist '$playlistName'. Skipping."
            continue
        }

        # Build track rows
        $rows = @()
        $trackIds = @()

        foreach ($item in $items) {
            $track = $item.track
            if (-not $track -or $track.type -eq 'episode') {
                # Skip episodes or null entries (deleted tracks)
                continue
            }

            $artists = ($track.artists | ForEach-Object { $_.name }) -join '; '
            $durationMin = [math]::Round($track.duration_ms / 60000, 2)

            $row = [ordered]@{
                PlaylistName = $playlistName
                TrackName    = $track.name
                Artists      = $artists
                AlbumName    = $track.album.name
                TrackNumber  = $track.track_number
                DiscNumber   = $track.disc_number
                DurationMin  = $durationMin
                ReleaseDate  = $track.album.release_date
                Explicit     = $track.explicit
                Popularity   = $track.popularity
                ISRC         = if ($track.external_ids) { $track.external_ids.isrc } else { '' }
                SpotifyUrl   = $track.external_urls.spotify
                SpotifyId    = $track.id
                AddedAt      = $item.added_at
                AddedBy      = if ($item.added_by) { $item.added_by.id } else { '' }
            }

            $rows += [PSCustomObject]$row
            if ($track.id) { $trackIds += $track.id }
        }

        # Merge audio features if requested
        if ($IncludeAudioFeatures -and $trackIds.Count -gt 0) {
            Write-Host "  Fetching audio features..." -ForegroundColor DarkCyan

            # Batch in groups of 100 (Spotify API limit)
            $features = @{}
            for ($i = 0; $i -lt $trackIds.Count; $i += 100) {
                $batch = $trackIds[$i..[math]::Min($i + 99, $trackIds.Count - 1)]
                $batchResult = Get-TrackAudioFeature -Id $batch
                foreach ($f in $batchResult) {
                    if ($f -and $f.id) { $features[$f.id] = $f }
                }
            }

            # Add feature columns to each row
            $enrichedRows = @()
            foreach ($row in $rows) {
                $f = $features[$row.SpotifyId]
                $row | Add-Member -NotePropertyName 'Key' -NotePropertyValue $(
                    if ($f -and $f.key -ge 0 -and $f.key -le 11) { $KeyNames[$f.key] } else { '' }
                ) -Force
                $row | Add-Member -NotePropertyName 'Mode' -NotePropertyValue $(
                    if ($f -and $null -ne $f.mode) { $ModeNames[[int]$f.mode] } else { '' }
                ) -Force
                $row | Add-Member -NotePropertyName 'Tempo' -NotePropertyValue $(
                    if ($f) { [math]::Round($f.tempo, 1) } else { '' }
                ) -Force
                $row | Add-Member -NotePropertyName 'TimeSignature' -NotePropertyValue $(
                    if ($f) { $f.time_signature } else { '' }
                ) -Force
                $row | Add-Member -NotePropertyName 'Danceability' -NotePropertyValue $(
                    if ($f) { $f.danceability } else { '' }
                ) -Force
                $row | Add-Member -NotePropertyName 'Energy' -NotePropertyValue $(
                    if ($f) { $f.energy } else { '' }
                ) -Force
                $row | Add-Member -NotePropertyName 'Acousticness' -NotePropertyValue $(
                    if ($f) { $f.acousticness } else { '' }
                ) -Force
                $row | Add-Member -NotePropertyName 'Instrumentalness' -NotePropertyValue $(
                    if ($f) { $f.instrumentalness } else { '' }
                ) -Force
                $row | Add-Member -NotePropertyName 'Speechiness' -NotePropertyValue $(
                    if ($f) { $f.speechiness } else { '' }
                ) -Force
                $row | Add-Member -NotePropertyName 'Liveness' -NotePropertyValue $(
                    if ($f) { $f.liveness } else { '' }
                ) -Force
                $row | Add-Member -NotePropertyName 'Valence' -NotePropertyValue $(
                    if ($f) { $f.valence } else { '' }
                ) -Force
                $row | Add-Member -NotePropertyName 'Loudness' -NotePropertyValue $(
                    if ($f) { $f.loudness } else { '' }
                ) -Force
                $enrichedRows += $row
            }
            $rows = $enrichedRows
        }

        if ($rows.Count -eq 0) {
            Write-Warning "  No tracks to export for '$playlistName'."
            continue
        }

        # Sanitize playlist name for filename
        $safeName = $playlistName -replace '[\\/:*?"<>|\[\]]', '_'
        $safeName = $safeName.Trim()
        $csvPath = Join-Path $OutputPath "$safeName.csv"

        $rows | Export-Csv -LiteralPath $csvPath -NoTypeInformation -Encoding UTF8
        $exportedFiles += $csvPath
        Write-Host "  Saved $($rows.Count) tracks -> $csvPath" -ForegroundColor DarkGreen
    }

    Write-Host "`nExport complete. $($exportedFiles.Count) file(s) written to: $OutputPath" -ForegroundColor Cyan
    return $exportedFiles
}
