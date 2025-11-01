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

    .PARAMETER Provider
        The music provider (Spotify, Qobuz, Discogs, MusicBrainz) to optimize cover art URLs

    .PARAMETER Size
        Size of the cover art to display ('large' or 'original')

    .PARAMETER Grid
        Whether to display in grid layout (default true)

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
        [string]$LoopLabel,

        [Parameter(Mandatory = $false)]
        [string]$Provider,

        [Parameter(Mandatory = $false)]
        [string]$Size = 'large',

        [Parameter(Mandatory = $false)]
        [bool]$Grid = $true
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

    # Ensure $selectedIndices is an array
    if ($selectedIndices -isnot [array]) {
        $selectedIndices = @($selectedIndices)
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
        # Fallback to browser for all selected albums
        Write-Host "Opening $($selectedIndices.Count) cover image(s) in browser (chafa not available)..." -ForegroundColor Green

        foreach ($index in $selectedIndices) {
            $albumIndex = $index - 1  # Convert to 0-based
            $selectedAlbum = $AlbumList[$albumIndex]
            $coverUrl = Get-IfExists $selectedAlbum 'cover_url'

            if ($coverUrl) {
                try {
                    Write-Host "Opening cover for album $index ($($selectedAlbum.name))" -ForegroundColor Cyan
                    Start-Process $coverUrl
                } catch {
                    Write-Warning "Failed to open cover art URL for album $index`: $($_.Exception.Message)"
                }
            } else {
                Write-Warning "No cover art available for album $index ($($selectedAlbum.name))"
            }
        }
        if ($LoopLabel) { continue $LoopLabel } else { return }
    }

    # Use chafa for terminal image display with grid layout
    $tempFiles = @()

    Write-Host "Preparing cover art display..." -ForegroundColor Cyan

    foreach ($index in $selectedIndices) {
        $albumIndex = $index - 1  # Convert to 0-based
        $selectedAlbum = $AlbumList[$albumIndex]
        $coverUrl = Get-IfExists $selectedAlbum 'cover_url'

        if ($coverUrl) {
            # Get optimal URL for display (large size for better quality)
            $providerName = $Provider
            # if (-not $providerName) {
            #     # Fallback to parsing URL if provider not provided
            #     if ($coverUrl -match 'qobuz\.com') { $providerName = 'Qobuz' }
            #     elseif ($coverUrl -match 'spotify\.com') { $providerName = 'Spotify' }
            #     elseif ($coverUrl -match 'discogs\.com') { $providerName = 'Discogs' }
            #     elseif ($coverUrl -match 'coverartarchive\.org') { $providerName = 'MusicBrainz' }
            # }

            $downloadUrl = if ($providerName) {
                Get-CoverArtUrl -CoverUrl $coverUrl -Provider $providerName -Size $Size
            } else {
                $coverUrl
            }

            # Download to temp file
            try {
                $tempFile = Join-Path $env:TEMP ("cover$index.jpg")
                $response = Invoke-WebRequest -Uri $downloadUrl -Method Get -UseBasicParsing -ErrorAction Stop
                [System.IO.File]::WriteAllBytes($tempFile, $response.Content)
                $tempFiles += $tempFile
            } catch {
                Write-Warning "Failed to download cover for album $index ($($selectedAlbum.name)): $($_.Exception.Message)"
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
        if ($Grid) {
            Write-Host "Displaying $($tempFiles.Count) cover(s) in terminal grid:" -ForegroundColor Green
        } else {
            Write-Host "Displaying $($tempFiles.Count) cover(s) in terminal list:" -ForegroundColor Green
        }

        # Create arguments for chafa
        $chafaArgs = @()

        if ($Grid) {
            $chafaArgs += @('--grid=auto')  # Grid layout
        } else {
            $chafaArgs += @('-l')  # List mode
        }

        $chafaArgs += @('--label=on')  # Enable labeling with filenames

        # Try to use sixels format for better image quality if supported
        try {
            $null = & chafa --help 2>&1 | Select-String 'sixels'
            $chafaArgs += @('--format=sixels')
        } catch {
            # sixels not supported, use default format
        }

        # Add all image files
        $chafaArgs += $tempFiles

        # Run chafa
        & chafa @chafaArgs

    } catch {
        Write-Warning "Failed to display images with chafa: $($_.Exception.Message)"
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