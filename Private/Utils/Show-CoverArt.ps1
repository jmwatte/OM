function Show-CoverArt {
    <#
    .SYNOPSIS
        Displays cover art for selected albums using chafa terminal preview or browser fallback.

    .DESCRIPTION
        Handles the cv command with range selection support. Downloads cover art images
        and displays them in a terminal grid using chafa, or falls back to opening
        in browser if chafa is not available.

    .PARAMETER RangeText
        Range text like "1-4,6,7" or single number like "3"

    .PARAMETER AlbumList
        Array of album objects with cover_url property

    .PARAMETER LoopLabel
        Optional loop label for continue statements (for use in nested loops)

    .EXAMPLE
        Show-CoverArt -RangeText "1-3,5" -AlbumList $albums
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RangeText,

        [Parameter(Mandatory = $true)]
        [array]$AlbumList,

        [Parameter(Mandatory = $false)]
        [string]$LoopLabel
    )

    try {
        $selectedIndices = Expand-SelectionRange -RangeText $RangeText -MaxIndex $AlbumList.Count
    } catch {
        Write-Warning "Invalid range syntax: $RangeText - $_"
        if ($LoopLabel) { continue $LoopLabel } else { return }
    }

    if ($selectedIndices.Count -eq 0) {
        Write-Warning "No valid albums selected"
        if ($LoopLabel) { continue $LoopLabel } else { return }
    }

    # Check if chafa is available
    $chafaAvailable = $null
    try {
        $chafaAvailable = Get-Command chafa -ErrorAction Stop
    } catch {
        $chafaAvailable = $null
    }

    if (-not $chafaAvailable) {
        # Fallback to browser for single album or first album in range
        $firstIndex = $selectedIndices[0] - 1  # Convert to 0-based
        if ($firstIndex -ge 0 -and $firstIndex -lt $AlbumList.Count) {
            $selectedAlbum = $AlbumList[$firstIndex]
            $coverUrl = Get-IfExists $selectedAlbum 'cover_url'

            if ($coverUrl) {
                Write-Host "Displaying cover art from $coverUrl (chafa not available, using browser)" -ForegroundColor Green
                try {
                    Start-Process $coverUrl
                } catch {
                    Write-Warning "Failed to open cover art URL: $_"
                }
            } else {
                Write-Warning "No cover art available for this album"
            }
        } else {
            Write-Warning "Invalid album number: $($selectedIndices[0])"
        }
        if ($LoopLabel) { continue $LoopLabel } else { return }
    }

    # Use chafa for terminal preview
    $tempFiles = @()
    $imageLabels = @()

    Write-Host "Preparing cover art preview..." -ForegroundColor Cyan

    foreach ($index in $selectedIndices) {
        $albumIndex = $index - 1  # Convert to 0-based
        $selectedAlbum = $AlbumList[$albumIndex]
        $coverUrl = Get-IfExists $selectedAlbum 'cover_url'

        if ($coverUrl) {
            # Get optimal URL for preview (medium size)
            $provider = $null
            if ($coverUrl -match 'qobuz\.com') { $provider = 'Qobuz' }
            elseif ($coverUrl -match 'spotify\.com') { $provider = 'Spotify' }
            elseif ($coverUrl -match 'discogs\.com') { $provider = 'Discogs' }
            elseif ($coverUrl -match 'coverartarchive\.org') { $provider = 'MusicBrainz' }

            $downloadUrl = if ($provider) {
                Get-CoverArtUrl -CoverUrl $coverUrl -Provider $provider -Size 'medium'
            } else {
                $coverUrl
            }

            # Download to temp file
            try {
                $tempFile = Join-Path $env:TEMP ("om_cover_$([guid]::NewGuid().ToString()).jpg")
                $response = Invoke-WebRequest -Uri $downloadUrl -Method Get -UseBasicParsing -ErrorAction Stop
                [System.IO.File]::WriteAllBytes($tempFile, $response.Content)
                $tempFiles += $tempFile
                $imageLabels += "$index. $($selectedAlbum.name)"
            } catch {
                Write-Warning "Failed to download cover for album $index ($($selectedAlbum.name)): $_"
            }
        } else {
            Write-Warning "No cover art available for album $index ($($selectedAlbum.name))"
        }
    }

    if ($tempFiles.Count -eq 0) {
        Write-Warning "No cover art could be downloaded"
        if ($LoopLabel) { continue $LoopLabel } else { return }
    }

    # Display with chafa
    try {
        Write-Host "Displaying $($tempFiles.Count) cover(s) in terminal grid:" -ForegroundColor Green

        # Create arguments for chafa
        $chafaArgs = @('--size', '20x20', '--colors', '256')

        # Add labels if multiple images
        if ($tempFiles.Count -gt 1) {
            for ($i = 0; $i -lt $tempFiles.Count; $i++) {
                $chafaArgs += @('--label', $imageLabels[$i])
            }
        }

        # Add all image files
        $chafaArgs += $tempFiles

        # Run chafa
        & chafa @chafaArgs

    } catch {
        Write-Warning "Failed to display images with chafa: $_"
    } finally {
        # Clean up temp files
        foreach ($tempFile in $tempFiles) {
            try {
                if (Test-Path $tempFile) {
                    Remove-Item $tempFile -Force
                }
            } catch {
                Write-Verbose "Failed to clean up temp file: $tempFile"
            }
        }
    }

    if ($LoopLabel) { continue $LoopLabel } else { return }
}