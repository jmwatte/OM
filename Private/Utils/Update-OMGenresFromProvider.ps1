function Update-OMGenresFromProvider {
    <#
    .SYNOPSIS
        Updates genre tags on audio files using genres from a provider album or artist.

    .DESCRIPTION
        Extracts genres from the provider album (genres, genre, styles fields) or falls back
        to artist genres. Then applies them to all audio files in the specified album path
        using either Replace or Merge mode.

    .PARAMETER SelectedAlbum
        The provider album object (must have genres/genre/styles properties, or $null).

    .PARAMETER ProviderArtist
        The provider artist object (fallback for genres if album has none).

    .PARAMETER AlbumPath
        The full path to the album folder containing audio files.

    .PARAMETER GenreMode
        'Replace' to overwrite existing genres, 'Merge' to add new genres to existing.

    .PARAMETER UseWhatIf
        If true, previews changes without writing.

    .OUTPUTS
        PSCustomObject with: Updated (int), Total (int), Genres (string[]), Success (bool)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $SelectedAlbum,

        [Parameter()]
        $ProviderArtist,

        [Parameter(Mandatory)]
        [string]$AlbumPath,

        [Parameter()]
        [ValidateSet('Replace', 'Merge')]
        [string]$GenreMode = 'Replace',

        [Parameter()]
        [switch]$UseWhatIf
    )

    # Get audio files
    $audioFiles = @(Get-ChildItem -LiteralPath $AlbumPath -File -Recurse |
        Where-Object { $_.Extension -match '\.(mp3|flac|wav|m4a|aac|ogg|ape)' })

    if ($audioFiles.Count -eq 0) {
        Write-Warning "No audio files found in: $AlbumPath"
        return [PSCustomObject]@{ Updated = 0; Total = 0; Genres = @(); Success = $false }
    }

    # Extract genres: album.genres → album.genre → album.styles → artist.genres
    $providerGenres = @()
    $albumGenres = Get-IfExists $SelectedAlbum 'genres'
    $albumGenre  = Get-IfExists $SelectedAlbum 'genre'
    $albumStyles = Get-IfExists $SelectedAlbum 'styles'
    $artistGenres = if ($ProviderArtist) { Get-IfExists $ProviderArtist 'genres' } else { $null }

    if ($albumGenres)       { $providerGenres = @($albumGenres) }
    elseif ($albumGenre)    { $providerGenres = @($albumGenre) }
    elseif ($albumStyles)   { $providerGenres = @($albumStyles) }
    elseif ($artistGenres)  { $providerGenres = @($artistGenres) }

    # Normalize: filter blanks, trim, decode HTML entities
    $providerGenres = @($providerGenres | Where-Object { $_ -and $_ -ne '' } | ForEach-Object {
        [System.Net.WebUtility]::HtmlDecode($_.ToString().Trim())
    })

    if ($providerGenres.Count -eq 0) {
        Write-Verbose "No genres found on provider album or artist."
        return [PSCustomObject]@{ Updated = 0; Total = $audioFiles.Count; Genres = @(); Success = $false }
    }

    Write-Host "Genres: $($providerGenres -join ', ')" -ForegroundColor Green

    # Update each file
    $updatedCount = 0
    foreach ($audioFile in $audioFiles) {
        try {
            $currentTags = Get-OMTags -Path $audioFile.FullName
            $currentGenres = if ($currentTags.Genres) { @($currentTags.Genres) } else { @() }

            $newGenres = if ($GenreMode -eq 'Merge') {
                @((@($currentGenres) + @($providerGenres)) | Select-Object -Unique)
            } else {
                @($providerGenres)
            }

            # Check if actually changed
            $changed = $false
            if ($newGenres.Count -ne $currentGenres.Count) {
                $changed = $true
            } else {
                $sortedNew     = @($newGenres | Sort-Object)
                $sortedCurrent = @($currentGenres | Sort-Object)
                for ($i = 0; $i -lt $sortedNew.Count; $i++) {
                    if ($sortedNew[$i] -cne $sortedCurrent[$i]) {
                        $changed = $true
                        break
                    }
                }
            }

            if ($changed) {
                Write-Verbose "  Updating: $($audioFile.Name) ($($currentGenres -join ', ') -> $($newGenres -join ', '))"
                Set-OMTags -Path $audioFile.FullName -Tags @{ Genres = $newGenres } -Force -WhatIf:$UseWhatIf | Out-Null
                $updatedCount++
            }
        }
        catch {
            Write-Warning "Failed to update '$($audioFile.Name)': $_"
        }
    }

    if ($UseWhatIf) {
        Write-Host "WhatIf: Would update $updatedCount/$($audioFiles.Count) file(s) with genres" -ForegroundColor Yellow
    } else {
        Write-Host "Updated $updatedCount/$($audioFiles.Count) file(s) with genres" -ForegroundColor Green
    }

    return [PSCustomObject]@{
        Updated = $updatedCount
        Total   = $audioFiles.Count
        Genres  = $providerGenres
        Success = $true
    }
}
