function Show-CoverArt {
    <#
    .SYNOPSIS
        Displays cover art for selected albums using chafa terminal preview or browser fallback.

    .DESCRIPTION
        Handles the cv command with range selection support. Downloads cover art images
        and displays them in a terminal grid using chafa, or falls back to opening
        in browser if chafa is not available.

    .PARAMETER Album
        Single album object with cover_url property (for backward compatibility)

    .PARAMETER RangeText
        Range text like "1-4,6,7" or single number like "3"

    .PARAMETER AlbumList
        Array of album objects with cover_url property

    .PARAMETER LoopLabel
        Optional loop label for continue statements (for use in nested loops)

    .EXAMPLE
        Show-CoverArt -Album $singleAlbum
        Show-CoverArt -RangeText "1-3,5" -AlbumList $albums
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [object]$Album,

        [Parameter(Mandatory = $false)]
        [string]$RangeText,

        [Parameter(Mandatory = $false)]
        [array]$AlbumList,

        [Parameter(Mandatory = $false)]
        [string]$LoopLabel
    )

    # Handle backward compatibility: if Album is provided, treat it as a single album
    if ($Album -and -not $AlbumList) {
        $AlbumList = @($Album)
        if (-not $RangeText) {
            $RangeText = "1"  # Default to showing the single album
        }
    }

    # Validate parameters
    if (-not $AlbumList -or $AlbumList.Count -eq 0) {
        Write-Warning "No albums provided"
        if ($LoopLabel) { continue $LoopLabel } else { return }
    }

    if (-not $RangeText) {
        $RangeText = "1..$($AlbumList.Count)"  # Default to all albums if no range specified
    }

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

    # Always use browser/image viewer for real image display
    Write-Host "Opening $($selectedIndices.Count) cover image(s)..." -ForegroundColor Green

    foreach ($index in $selectedIndices) {
        $albumIndex = $index - 1  # Convert to 0-based
        $selectedAlbum = $AlbumList[$albumIndex]
        $coverUrl = Get-IfExists $selectedAlbum 'cover_url'

        if ($coverUrl) {
            # Get optimal URL for display (large size for better viewing)
            $provider = $null
            if ($coverUrl -match 'qobuz\.com') { $provider = 'Qobuz' }
            elseif ($coverUrl -match 'spotify\.com') { $provider = 'Spotify' }
            elseif ($coverUrl -match 'discogs\.com') { $provider = 'Discogs' }
            elseif ($coverUrl -match 'coverartarchive\.org') { $provider = 'MusicBrainz' }

            $displayUrl = if ($provider) {
                Get-CoverArtUrl -CoverUrl $coverUrl -Provider $provider -Size 'large'
            } else {
                $coverUrl
            }

            try {
                Write-Host "Opening cover for album $index ($($selectedAlbum.name))" -ForegroundColor Cyan
                Start-Process $displayUrl
            } catch {
                Write-Warning "Failed to open cover art URL for album $index`: $($_.Exception.Message)"
            }
        } else {
            Write-Warning "No cover art available for album $index ($($selectedAlbum.name))"
        }
    }

    if ($LoopLabel) { continue $LoopLabel } else { return }
}