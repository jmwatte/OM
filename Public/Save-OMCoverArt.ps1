function Save-OMCoverArt {
    <#
    .SYNOPSIS
        Fetches and saves cover art for album folders without artwork.

    .DESCRIPTION
        Searches for album metadata using the specified provider and downloads cover art
        to the folder. Handles both regular album folders and disc subfolders (cd1, Disc 1, etc.).
        
        For disc subfolders, extracts artist/album information from the parent folder but
        saves the artwork to the disc subfolder itself.

    .PARAMETER Path
        Path to folder containing audio files. Can be album folder or disc subfolder.
        Accepts pipeline input.

    .PARAMETER Provider
        Provider to fetch artwork from. Default is Qobuz.

    .PARAMETER Force
        Overwrite existing artwork files.

    .PARAMETER MaxSize
        Maximum dimension (width/height) for the image in pixels. Default is original size (no resizing).

    .EXAMPLE
        Save-OMCoverArt -Path "D:\Artist\2020 - Album\cd1" -Provider Qobuz
        Fetches cover art for "Artist - Album" and saves to the cd1 subfolder.

    .EXAMPLE
        Get-ChildItem -Directory | Save-OMCoverArt
        Processes multiple folders from pipeline.

    .EXAMPLE
        Get-ChildItem -Path "D:" -Recurse -Directory | 
            Where-Object { 
                $files = Get-ChildItem $_.FullName -File
                ($files.Extension -match '\.(mp3|flac|wav|m4a)$') -and 
                -not ($files.Extension -match '\.(jpg|jpeg|png|gif)$') 
            } | 
            Save-OMCoverArt -Provider Qobuz
        
        Finds all folders with audio files but no artwork and downloads cover art.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias('FullName')]
        [string]$Path,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet('Spotify', 'Qobuz', 'Discogs', 'MusicBrainz')]
        [string]$Provider = 'Qobuz',
        
        [Parameter(Mandatory = $false)]
        [switch]$Force,

        [Parameter(Mandatory = $false)]
        [int]$MaxSize = 0  # 0 means original size (no resizing)
    )
    
    begin {
        # Load configuration
        $config = Get-OMConfig
        if (-not $config) {
            throw "OM configuration not found. Run Set-OMConfig first."
        }

        # Ensure TagLib is loaded
        Assert-TagLibLoaded
    }

    process {
        try {
            # Resolve full path
            $Path = Resolve-Path $Path -ErrorAction Stop | Select-Object -ExpandProperty Path

            # Check if folder exists
            if (-not (Test-Path $Path -PathType Container)) {
                Write-Warning "Path is not a directory: $Path"
                return
            }

            # Check if cover art already exists
            $existingCover = Get-ChildItem -Path $Path -File -Filter "*.jpg" | 
                Where-Object { $_.Name -match '^(cover|folder|albumart)\.jpg$' } |
                Select-Object -First 1

            if ($existingCover -and -not $Force) {
                Write-Host "⊘ Skipping (artwork exists): $Path" -ForegroundColor Gray
                return
            }

            # Check if folder is a disc subfolder (cd1, Disc 1, disc2, etc.)
            $folderName = Split-Path $Path -Leaf
            $isDiscFolder = $folderName -match '^\s*(cd|disc|disk)\s*\d+\s*$'
            
            # Determine metadata folder (parent if disc subfolder)
            $metadataFolder = if ($isDiscFolder) {
                Split-Path $Path -Parent
            } else {
                $Path
            }

            # Extract artist/album from metadata folder structure
            $albumFolderItem = Get-Item $metadataFolder
            $artistName = $albumFolderItem.Parent.Name
            
            # Strip year prefix from album name (e.g., "2020 - Album Name" -> "Album Name")
            $albumName = $albumFolderItem.Name -replace '^\d{4}\s*-\s*', ''

            Write-Host "`n╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
            Write-Host "  Fetching artwork: $artistName - $albumName" -ForegroundColor Yellow
            if ($isDiscFolder) {
                Write-Host "  (Disc subfolder detected: saving to $folderName)" -ForegroundColor Gray
            }
            Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan

            # Search for album using the provider
            Write-Host "Searching $Provider..." -ForegroundColor Cyan
            
            $searchResults = Invoke-ProviderSearchAlbums -Provider $Provider `
                -ArtistName $artistName `
                -AlbumName $albumName

            if (-not $searchResults -or $searchResults.Count -eq 0) {
                Write-Warning "No albums found matching: $artistName - $albumName"
                return
            }

            # Use the first (best) match
            $bestMatch = $searchResults[0]
            
            Write-Host "Found: $($bestMatch.artist) - $($bestMatch.name)" -ForegroundColor Green
            Write-Host "  Provider ID: $($bestMatch.id)" -ForegroundColor Gray

            # Check if cover URL exists
            if (-not $bestMatch.cover_url) {
                Write-Warning "No cover art URL available for this album"
                return
            }

            # Determine action and max size
            $action = 'SaveToFolder'
            $actualMaxSize = if ($MaxSize -gt 0) { $MaxSize } else { 2000 }  # Use 2000 for "original"

            # Download and save cover art
            Write-Host "Downloading cover art..." -ForegroundColor Cyan
            
            $result = Save-CoverArt -CoverUrl $bestMatch.cover_url `
                -AlbumPath $Path `
                -Action $action `
                -MaxSize $actualMaxSize

            if ($result.Success) {
                Write-Host "✓ Cover art saved successfully" -ForegroundColor Green
            } else {
                Write-Warning "Failed to save cover art: $($result.Error)"
            }
        }
        catch {
            Write-Warning "Error processing $Path : $_"
            Write-Verbose $_.ScriptStackTrace
        }
    }
}
