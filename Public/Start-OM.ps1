<#
.SYNOPSIS
    Interactively organizes music albums by matching them with online databases.

.DESCRIPTION
    Start-OM is a comprehensive, interactive function that guides you through organizing your music library.
    It processes a directory of album folders, and for each album, it helps you find the correct artist and
    album information from providers like Spotify, Qobuz, Discogs, or MusicBrainz.

    Choose between two search approaches:
    - Quick Album Search: Enter artist and album directly for faster lookup and matching
    - Artist-First Search: Traditional workflow starting with artist selection, then album selection

    The workflow is divided into three main stages:
    A: Artist Selection - Searches for the artist and lets you choose the correct one (Artist-First mode only).
    B: Album Selection - Fetches albums for the selected artist and lets you choose the matching album.
    C: Track Matching & Tagging - Displays a side-by-side view of your local files and the provider's tracks,
       allowing you to match them, save tags, and rename the album folder.

    This function is designed to be used interactively, but it also provides parameters for automation.
    During interactive use, you can switch between search modes, change providers, and use various sorting
    and matching options in the track selection stage.

.PARAMETER Path
    The path to the base directory containing the album folders you want to organize.
    This parameter is mandatory and can be provided via the pipeline.

.PARAMETER Provider
    Specifies the online music database to use for fetching metadata.
    Valid values are 'Spotify', 'Qobuz', 'Discogs', and 'MusicBrainz'.
    Defaults to 'Spotify'.

.PARAMETER ArtistId
    Allows you to skip the interactive artist search by providing the artist's ID directly.

.PARAMETER AlbumId
    Allows you to skip the interactive album search by providing the album's ID directly.
    Requires ArtistId to be specified as well.

.PARAMETER AutoSelect
    If specified, the function will automatically select the first search result for artist and album,
    making the process faster but potentially less accurate.

.PARAMETER NonInteractive
    If specified, the function will run in a non-interactive mode. It will not prompt for user input
    and will skip the interactive track selection stage.

.PARAMETER goA
    A debugging switch that automatically selects the first artist candidate in Stage A.

.PARAMETER goB
    A debugging switch that automatically selects the first album candidate in Stage B.

.PARAMETER goC
    A debugging switch that automatically applies all changes (Save All) in Stage C.

.PARAMETER ReverseSource
    A switch to reverse the source and target columns in the track matching UI (Stage C).

.PARAMETER TargetFolder
    Specifies the target directory where organized album folders will be moved after processing.
    If provided, album folders will be moved to this directory after saving tags.
    If a folder with the same name already exists in the target, a numbered suffix (2), (3), etc. will be added.
    The target directory will be created if it doesn't exist.

.PARAMETER Auto
    Enables automatic mode for batch processing. When enabled, the function will:
    - Automatically select the best matching album from search results based on confidence scoring
    - Try different track sorting strategies and pick the one with the most high-confidence matches
    - Automatically save tags and optionally cover art if confidence threshold is met
    - Skip to the next album in the pipeline after successful processing
    Useful for processing large batches of well-organized albums.

.PARAMETER AutoConfidenceThreshold
    Sets the minimum confidence score (0.5 to 1.0) required for automatic selection and processing.
    Default is 0.80 (80%). Higher values require more exact matches.

.PARAMETER AutoFallback
    Enables automatic provider fallback when the primary provider doesn't have a high-confidence match.
    The fallback chain prioritizes Qobuz and Spotify as the most reliable providers:
    - Qobuz → Spotify → Discogs → MusicBrainz
    - Spotify → Qobuz → Discogs → MusicBrainz
    This helps ensure successful matches even when one provider has incomplete data.

.PARAMETER AutoSaveCover
    When used with -Auto, automatically saves cover art to the album folder after saving tags.
    Requires Auto mode to be enabled.

.PARAMETER UpdateGenresOnly
    When specified, the function will only update genre tags from the matched album/release.
    All other tags (Title, Artist, Album, Track numbers, etc.) remain unchanged.
    This mode:
    - Uses Quick Find to match albums directly (skips Artist stage)
    - Fetches genre information from the matched release
    - Updates only the genre tags on all files in the album
    - Works with -Auto for batch processing
    - Respects -GenreMode for Replace vs Merge behavior
    Useful for adding or updating genre metadata across your library without touching other tags.

.PARAMETER GenreMode
    Specifies how to handle existing genres when updating genre tags.
    Valid values:
    - 'Replace': Completely replace existing genres with provider genres (default)
    - 'Merge': Add provider genres to existing genres (keeps both, deduplicates)
    Only applies when -UpdateGenresOnly is used, or when saving tags in interactive mode.
    Default is 'Replace'.

.EXAMPLE
    Start-OM -Path "C:\Music\MyArtist"

    Starts the interactive organization process for all album folders inside "C:\Music\MyArtist".

.EXAMPLE
    "C:\Music\MyArtist" | Start-OM -Provider Discogs

    Starts the interactive process using Discogs as the provider, with the path provided via the pipeline.

.EXAMPLE
    Start-OM -Path "C:\Music\MyArtist\MyAlbum" -ArtistId "..." -AlbumId "..." -NonInteractive

    Runs the process non-interactively for a specific album, using the provided artist and album IDs.

.EXAMPLE
    Start-OM -Path "C:\Music\Unsorted" -TargetFolder "C:\Music\Organized"

    Processes albums from C:\Music\Unsorted and moves each organized album folder to C:\Music\Organized.
    Albums will be organized into the structure created by the rename pattern (typically Artist\Year - Album).

.EXAMPLE
    Start-OM -Path "C:\Music\Artist" -Auto -AutoFallback -AutoSaveCover

    Auto-processes all albums under C:\Music\Artist with automatic provider fallback and cover art saving.
    Automatically selects best matches, tries different sorting strategies, and skips to next album after saving.

.EXAMPLE
    Start-OM -Path "C:\Music\NewAlbums" -Auto -AutoConfidenceThreshold 0.90 -Provider Qobuz

    Auto-processes albums with Qobuz provider, requiring 90% confidence for automatic selection.
    If Qobuz doesn't have good matches, stays in interactive mode for manual selection.

.EXAMPLE
    Start-OM -Path "C:\Music\Collection" -Auto -AutoFallback -WhatIf

    Preview what Auto mode would do without making any changes. Shows which albums would be auto-selected
    and which would require manual intervention.

.EXAMPLE
    Start-OM -Path "C:\Music\Artist" -UpdateGenresOnly -Provider Discogs -Auto

    Automatically update only genre tags for all albums using Discogs. Replaces existing genres with
    Discogs genres. Processes all albums in batch mode.

.EXAMPLE
    Start-OM -Path "C:\Music\Artist" -UpdateGenresOnly -GenreMode Merge -Provider Qobuz

    Interactively update genre tags, adding Qobuz genres to existing genres (keeps both).
    Allows manual album selection for each folder.

.NOTES
    This function requires the TagLib-Sharp library for reading and writing audio file tags.
    It will attempt to install it automatically if it's missing.
    For Spotify integration, the 'Spotishell' module is required.
    The function supports -WhatIf to preview changes without applying them.
    Interactive mode supports switching between Quick Album Search and Artist-First Search modes,
    changing providers on the fly, and various track sorting and matching options.
    
    Auto mode is best for well-organized libraries where folder names accurately reflect artist and album.
    Use higher confidence thresholds (0.90+) for conservative matching, or lower (0.70-0.80) for more
    aggressive batch processing. AutoFallback ensures better match rates across providers.

.LINK
    https://github.com/jmwatte/OM
#>
function Start-OM {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Path,
        [Parameter(Mandatory = $false)]
        [ValidateSet('Spotify', 'Qobuz', 'Discogs', 'MusicBrainz')]
        [string]$Provider = 'Spotify',  # Default to Spotify for compatibility
        [Parameter(Mandatory = $false)]
        [string]$ArtistId,
        [Parameter(Mandatory = $false)]
        [string]$AlbumId,
        [Parameter(Mandatory = $false)]
        [switch]$AutoSelect,
        [Parameter(Mandatory = $false)]
        [switch]$NonInteractive,
        [Parameter(Mandatory = $false)]
        [switch]$goA,
        [Parameter(Mandatory = $false)]
        [switch]$goB,
        [Parameter(Mandatory = $false)]
        [switch]$goC,
        [Parameter(Mandatory = $false)]
        [switch]$ReverseSource,
        [Parameter(Mandatory = $false)]
        [string]$TargetFolder,
        [Parameter(Mandatory = $false)]
        [switch]$Auto,
        [Parameter(Mandatory = $false)]
        [ValidateRange(0.5, 1.0)]
        [double]$AutoConfidenceThreshold = 0.70,
        [Parameter(Mandatory = $false)]
        [switch]$AutoFallback,
        [Parameter(Mandatory = $false)]
        [switch]$AutoSaveCover,
        [Parameter(Mandatory = $false)]
        [switch]$UpdateGenresOnly,
        [Parameter(Mandatory = $false)]
        [ValidateSet('Replace', 'Merge')]
        [string]$GenreMode = 'Replace'

    )

    begin {
        $taglibloaded = Assert-TagLibLoaded -ThrowOnError 
        if (-not $taglibloaded) {
            Install-TagLibSharp | Out-Null
        }
        # ensure TagLib is present for this function (Install-TagLibSharp should make TagLib available)
        Set-StrictMode -Version Latest
        $ErrorActionPreference = 'Stop'

        # detect whether the user passed -WhatIf to this function (comes from CmdletBinding)
        $isWhatIf = $PSBoundParameters.ContainsKey('WhatIf')

        # Initialize verbose display toggle if it doesn't exist
        if (-not (Get-Variable -Name showVerbose -Scope Script -ErrorAction SilentlyContinue)) {
            $script:showVerbose = $false
            $script:genreMode = 'Replace'  # 'Replace' or 'Merge'
        }
        
        # Set genre mode from parameter if provided
        if ($PSBoundParameters.ContainsKey('GenreMode')) {
            $script:genreMode = $GenreMode
        }

        if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
            throw "Path not found or not a directory: $Path"
        }

        # Detect path type: single album folder (has audio files) vs artist folder (has album subfolders)
        $audioFilesInPath = @(Get-ChildItem -LiteralPath $Path -File -Recurse -ErrorAction SilentlyContinue | 
            Where-Object { $_.Extension -match '\.(mp3|flac|wav|m4a|aac|ogg|ape)' } |
            Sort-Object { [regex]::Replace($_.Name, '(\d+)', { $args[0].Value.PadLeft(10, '0') }) })
        $subFoldersInPath = @(Get-ChildItem -LiteralPath $Path -Directory -ErrorAction SilentlyContinue)
        
        # Helper function to detect if a folder name is a disc folder
        $isDiscFolder = {
            param([string]$FolderName)
            # Match patterns: Disc1, Disc 1, Disc 01, CD1, CD 1, CD01, Disk1, Disk 1, Disk01, etc.
            return $FolderName -match '^\s*(Disc|CD|Disk)\s*\d+\s*$'
        }
        
        # Single album mode: Path has audio files and either no subfolders or all subfolders are disc folders
        $script:isSingleAlbumPath = $false
        $script:originalPath = $Path
        
        if ($audioFilesInPath.Count -gt 0) {
            # Check if subfolders contain audio files
            $subFoldersWithAudio = @($subFoldersInPath | Where-Object {
                $subAudioFiles = @(Get-ChildItem -LiteralPath $_.FullName -File -Recurse -ErrorAction SilentlyContinue | 
                    Where-Object { $_.Extension -match '\.(mp3|flac|wav|m4a|aac|ogg|ape)' } |
                    Sort-Object { [regex]::Replace($_.Name, '(\d+)', { $args[0].Value.PadLeft(10, '0') }) })
                $subAudioFiles.Count -gt 0
            })
            
            if ($subFoldersWithAudio.Count -eq 0) {
                # No subfolders with audio → single album (flat structure)
                $script:isSingleAlbumPath = $true
                Write-Verbose "Detected single album path: $Path (contains $($audioFilesInPath.Count) audio files)"
            }
            else {
                # Subfolders with audio exist - check if they're ALL disc folders
                $nonDiscFolders = @($subFoldersWithAudio | Where-Object { -not (& $isDiscFolder $_.Name) })
                
                if ($nonDiscFolders.Count -eq 0) {
                    # ALL subfolders with audio are disc folders → single multi-disc album
                    $script:isSingleAlbumPath = $true
                    Write-Verbose "Detected single album with disc subfolders: $Path (contains $($audioFilesInPath.Count) audio files across $($subFoldersWithAudio.Count) disc folders)"
                }
                else {
                    # Some subfolders are NOT disc folders → artist folder with multiple albums
                    Write-Verbose "Detected artist folder path: $Path (has $($subFoldersWithAudio.Count) album subfolders with audio files)"
                }
            }
        }
        elseif ($subFoldersInPath.Count -gt 0) {
            Write-Verbose "Detected artist folder path: $Path (has $($subFoldersInPath.Count) subfolders, checking for albums)"
        }
        else {
            Write-Warning "Path contains no audio files and no subfolders: $Path"
        }

        # Ensure required external module Spotishell is present in the session
        if (-not (Get-Module -Name Spotishell)) {
            try { Import-Module Spotishell -ErrorAction Stop } catch { Write-Warning "Spotishell module not loaded: $_"; throw }
        }

        # Convert the switch into the debug-friendly object used by the helpers (optional)
        #   $whatIfObj = New-Object PSObject -Property @{ IsPresent = $isWhatIf }
    }

    # ... (begin block unchanged)
    
    process {
        # If Provider was not explicitly specified, use DefaultProvider from config
        if (-not $PSBoundParameters.ContainsKey('Provider')) {
            $config = Get-OMConfig
            if ($config.DefaultProvider) {
                $Provider = $config.DefaultProvider
                Write-Verbose "Using DefaultProvider from config: $Provider"
            }
        }
        
        # Cache Qobuz locale early to avoid repeated config calls during header display
        $qobuzUrlLocale = $null
        if ($Provider -eq 'Qobuz' -or (Get-OMConfig).DefaultProvider -eq 'Qobuz') {
            $qobuzConfig = Get-OMConfig -Provider Qobuz
            $qobuzLocale = if ($qobuzConfig -and $qobuzConfig.Locale) { $qobuzConfig.Locale } else { $PSCulture }
            if (Get-Command -Name Get-QobuzUrlLocale -ErrorAction SilentlyContinue) {
                $qobuzUrlLocale = Get-QobuzUrlLocale -CultureCode $qobuzLocale
            } else {
                $qobuzUrlLocale = $qobuzLocale
            }
            Write-Verbose "Cached Qobuz URL locale: $qobuzUrlLocale"
        }
        
        # Helper function to normalize Discogs IDs (strip brackets, resolve masters)
        $normalizeDiscogsId = {
            param([string]$InputId)
            
            $id = $InputId.Trim()
            
            # Remove brackets if present: [r2388472] → r2388472, [m1764178] → m1764178
            $id = $id -replace '^\[|\]$', ''
            
            # Check if it's a master release (m prefix)
            # if ($id -match '^m(\d+)$') {
            #     Write-Host "Detected Discogs master release: $id" -ForegroundColor Yellow
            #     Write-Host "Fetching master to resolve main release..." -ForegroundColor Cyan
            #     try {
            #         $masterId = $matches[1]
            #         $master = Invoke-DiscogsRequest -Uri "/masters/$masterId"
            #         if ($master -and $master.main_release) {
            #             $id ="r"+[string]$master.main_release
            #             Write-Host "✓ Resolved to main release: $id" -ForegroundColor Green
            #         }
            #         else {
            #             Write-Warning "Could not resolve master $masterId to main release, using master ID"
            #             $id = $masterId
            #         }
            #     }
            #     catch {
            #         Write-Warning "Failed to fetch master release: $_"
            #         $id = $masterId
            #     }
            # }
            # # Strip 'r' prefix if present: r2388472 → 2388472
            # elseif ($id -match '^r(\d+)$') {

            #     #$id = $matches[1]
            # }
            
            return $id
        }
        
        # Helper function to show consistent header across all stages
        $showHeader = {
            param(
                [string]$Provider,
                [string]$Artist,
                [string]$AlbumName,
                [int]$TrackCount = 0
            )
            Write-Host ""
            Write-Host "🎵 ═══════════════════════════════════════════════════════════" -ForegroundColor DarkCyan
            Write-Host "🔍 Provider: " -NoNewline -ForegroundColor Magenta
            
            # Add locale for Qobuz provider (use cached value from parent scope)
            if ($Provider -eq 'Qobuz' -and $qobuzUrlLocale) {
                Write-Host "$Provider ($qobuzUrlLocale)" -ForegroundColor Cyan
            } else {
                Write-Host $Provider -ForegroundColor Cyan
            }
            
            Write-Host "👤 Original Artist: " -NoNewline -ForegroundColor Yellow
            Write-Host $Artist -ForegroundColor White
            Write-Host "💿 Original Album: " -NoNewline -ForegroundColor Green
            
            # Try to extract year from folder name (e.g., "2011 - Bach Cello Suites")
            $folderYear = ""
            if ($script:album -and $script:album.Name) {
                if ($script:album.Name -match '^(\d{4})\s*-\s*') {
                    $folderYear = "$($matches[1]) - "
                }
            }
            
            Write-Host "$folderYear$AlbumName" -NoNewline -ForegroundColor White
            if ($TrackCount -gt 0) {
                Write-Host " ($TrackCount tracks)" -ForegroundColor White
            }
            else {
                Write-Host ""  # Ensure newline
            }
            Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor DarkCyan
            Write-Host ""
        }
        # Helper function for album folder move with retry on access errors
        function Invoke-MoveAlbumWithRetry {
            param($mvArgs, $useWhatIf)
        
            $moveSucceeded = $false
            do {
                try {
                    $moveResult = Move-AlbumFolder @mvArgs -WhatIf:$useWhatIf
                    $moveSucceeded = $true
                }
                catch {
                    Write-Warning "Move-AlbumFolder failed: $($_.Exception.Message)"
                    $retry = Read-Host "Folder may be in use by another process. Free the folder (close files/apps) and press Enter to retry, or 's' to skip"
                    if ($retry -eq 's') {
                        Write-Host "Skipping folder move." -ForegroundColor Yellow
                        return $null
                    }
                }
            } while (-not $moveSucceeded)
        
            return $moveResult
        }
        # Helper scriptblock for handling move success (shared between sf and sa)
        $handleMoveSuccess = {
            param($moveResult, $useWhatIf, $oldpath)
    
            if ($moveResult -and $moveResult.Success) {
                if ($useWhatIf) {
                    Write-Host "WhatIf: album would be moved:" -ForegroundColor Yellow
                    Write-Host -NoNewline -ForegroundColor Green "Old: "
                    Write-Host $oldpath
                    Write-Host -NoNewline -ForegroundColor Green "New: "
                    Write-Host $moveResult.NewAlbumPath
                    if ($moveResult.NewAlbumPath -ne $oldpath -and -not ($NonInteractive -or $goC) -and -not $useWhatIf) {
                        Read-Host -Prompt "Press Enter to continue"
                    }
                    else {
                        Write-Verbose "NonInteractive/goC/WhatIf or no-path-change: skipping pause after move."
                    }
                    Write-Host "Album saved. Choose 's' to skip to next album, or select another option." -ForegroundColor Yellow
                    # continue doTracks
                }
                else {
                    if ($moveResult.NewAlbumPath -eq $oldpath) {
                        Write-Verbose "Move result indicates no change to album path; continuing."
                        Write-Host "Album saved. Choose 's' to skip to next album, or select another option." -ForegroundColor Yellow
                        #  continue doTracks
                    }
                    # Folder was moved - update $album and reload audio files from new location
                    $script:album = Get-Item -LiteralPath $moveResult.NewAlbumPath
            
                    # Reload audio files with fresh TagLib handles from the NEW album path
                    $script:audioFiles = Get-ChildItem -LiteralPath $script:album.FullName -File -Recurse | 
                        Where-Object { $_.Extension -match '\.(mp3|flac|wav|m4a|aac|ogg|ape)' } |
                        Sort-Object { [regex]::Replace($_.Name, '(\d+)', { $args[0].Value.PadLeft(10, '0') }) }
                    $script:audioFiles = foreach ($f in $script:audioFiles) {
                        try {
                            $tagFile = [TagLib.File]::Create($f.FullName)
                            [PSCustomObject]@{
                                FilePath    = $f.FullName
                                DiscNumber  = $tagFile.Tag.Disc
                                TrackNumber = $tagFile.Tag.Track
                                Title       = $tagFile.Tag.Title
                                TagFile     = $tagFile
                                Composer    = if ($tagFile.Tag.Composers) { $tagFile.Tag.Composers -join '; ' } else { 'Unknown Composer' }
                                Artist      = if ($tagFile.Tag.Performers) { $tagFile.Tag.Performers -join '; ' } else { 'Unknown Artist' }
                                Name        = if ($tagFile.Tag.Title) { $tagFile.Tag.Title } else { $f.BaseName }
                                Duration    = if ($f.Extension -eq '.ape') { Get-ApeDuration -FilePath $f.FullName } else { $tagFile.Properties.Duration.TotalMilliseconds }
                            }
                        }
                        catch {
                            Write-Warning "Skipping corrupted or invalid audio file: $($f.FullName) - Error: $($_.Exception.Message)"
                            continue
                        }
                    }

                    # Update paired tracks with reloaded audio files to reflect updated tags
                    if ($script:pairedTracks -and $script:pairedTracks.Count -gt 0) {
                        for ($i = 0; $i -lt [Math]::Min($script:pairedTracks.Count, $script:audioFiles.Count); $i++) {
                            if ($script:pairedTracks[$i].AudioFile.TagFile) {
                                try { $script:pairedTracks[$i].AudioFile.TagFile.Dispose() } catch { }
                            }
                            $script:pairedTracks[$i].AudioFile = $script:audioFiles[$i]
                        }
                    }
                    $script:refreshTracks = $true  # Trigger display refresh to show updated tags
                    
                    # Handle TargetFolder move if specified
                    if ($TargetFolder) {
                        Write-Verbose "TargetFolder specified: $TargetFolder"
                        $currentPath = $script:album.FullName
                        $folderName = Split-Path $currentPath -Leaf
                        $originalParentFolder = Split-Path $currentPath -Parent
                        Write-Verbose "Current album path: $currentPath"
                        Write-Verbose "Folder name: $folderName"
                        
                        # Get AlbumArtist from the first audio file's tags (they should all be the same)
                        $albumArtistName = 'Unknown Artist'
                        if ($audioFiles -and $audioFiles.Count -gt 0 -and $audioFiles[0].PSObject.Properties['FilePath']) {
                            Write-Verbose "Found $($audioFiles.Count) audio files for AlbumArtist extraction"
                            try {
                                $firstFilePath = $audioFiles[0].FilePath
                                Write-Verbose "Reading AlbumArtist from: $firstFilePath"
                                # Dispose old handle if exists
                                if ($audioFiles[0].PSObject.Properties['TagFile'] -and $audioFiles[0].TagFile) {
                                    try { $audioFiles[0].TagFile.Dispose() } catch { }
                                    Write-Verbose "Disposed existing TagFile handle"
                                }
                                # Reload file to read current saved tags
                                $tempTag = [TagLib.File]::Create($firstFilePath)
                                Write-Verbose "Reloaded TagFile for AlbumArtist check"
                                if ($tempTag.Tag.AlbumArtists -and $tempTag.Tag.AlbumArtists.Count -gt 0) {
                                    $albumArtistName = $tempTag.Tag.AlbumArtists[0]
                                    Write-Verbose "Read AlbumArtist from saved tags for TargetFolder: $albumArtistName"
                                }
                                elseif ($tempTag.Tag.FirstAlbumArtist) {
                                    $albumArtistName = $tempTag.Tag.FirstAlbumArtist
                                    Write-Verbose "Read FirstAlbumArtist from saved tags for TargetFolder: $albumArtistName"
                                }
                                else {
                                    Write-Verbose "No AlbumArtist found in tags, using default: $albumArtistName"
                                }
                                $tempTag.Dispose()
                            }
                            catch {
                                Write-Warning "Could not extract AlbumArtist from tags: $($_.Exception.Message)"
                            }
                        }
                        
                        # Sanitize album artist name for folder creation
                        $albumArtistName = Approve-PathSegment -Segment $albumArtistName
                        
                        # Ensure target directory exists
                        if (-not (Test-Path -LiteralPath $TargetFolder)) {
                            Write-Verbose "Creating target directory: $TargetFolder"
                            New-Item -Path $TargetFolder -ItemType Directory -Force | Out-Null
                        }
                        
                        # Create artist subdirectory in target folder
                        $artistFolder = Join-Path $TargetFolder $albumArtistName
                        if (-not (Test-Path -LiteralPath $artistFolder)) {
                            Write-Verbose "Creating artist directory: $artistFolder"
                            New-Item -Path $artistFolder -ItemType Directory -Force | Out-Null
                        }
                        
                        # Calculate target path with duplicate handling
                        $targetPath = Join-Path $artistFolder $folderName
                        if (Test-Path -LiteralPath $targetPath) {
                            $n = 2
                            while (Test-Path -LiteralPath (Join-Path $artistFolder "$folderName ($n)")) {
                                $n++
                            }
                            $targetPath = Join-Path $artistFolder "$folderName ($n)"
                            Write-Verbose "Duplicate folder detected. Using: $targetPath"
                        }
                        
                        # Move album to target folder
                        Write-Host "Moving album to target folder: $targetPath" -ForegroundColor Cyan
                        Move-Item -LiteralPath $currentPath -Destination $targetPath -Force
                        
                        # Clean up empty parent folder if it's now empty
                        # SAFEGUARD: Only remove parent if we were processing from an artist folder (not single album mode)
                        # This prevents removing user's music library folder when they point directly to Artist/Album6
                        $shouldCleanupParent = $originalParentFolder -and 
                                               (Test-Path -LiteralPath $originalParentFolder) -and
                                               (-not $script:isSingleAlbumPath)
                        
                        if ($shouldCleanupParent) {
                            $remainingItems = @(Get-ChildItem -LiteralPath $originalParentFolder -Force)
                            if ($remainingItems.Count -eq 0) {
                                Write-Verbose "Removing empty parent folder: $originalParentFolder"
                                Remove-Item -LiteralPath $originalParentFolder -Force
                                Write-Host "Cleaned up empty folder: $originalParentFolder" -ForegroundColor Gray
                            }
                            else {
                                Write-Verbose "Parent folder not empty ($(($remainingItems.Count)) items remaining), keeping it"
                            }
                        }
                        elseif ($script:isSingleAlbumPath) {
                            Write-Verbose "Single album mode: Skipping parent folder cleanup to preserve original folder structure"
                        }
                        
                        # Update $script:album and reload audio files from new location
                        $script:album = Get-Item -LiteralPath $targetPath
                        
                        # Reload audio files with fresh TagLib handles from the target path
                        $audioFiles = Get-ChildItem -LiteralPath $script:album.FullName -File -Recurse | 
                            Where-Object { $_.Extension -match '\.(mp3|flac|wav|m4a|aac|ogg|ape)' } |
                            Sort-Object { [regex]::Replace($_.Name, '(\d+)', { $args[0].Value.PadLeft(10, '0') }) }
                        $audioFiles = foreach ($f in $audioFiles) {
                            try {
                                $tagFile = [TagLib.File]::Create($f.FullName)
                                [PSCustomObject]@{
                                    FilePath    = $f.FullName
                                    DiscNumber  = $tagFile.Tag.Disc
                                    TrackNumber = $tagFile.Tag.Track
                                    Title       = $tagFile.Tag.Title
                                    TagFile     = $tagFile
                                    Composer    = if ($tagFile.Tag.Composers) { $tagFile.Tag.Composers -join '; ' } else { 'Unknown Composer' }
                                    Artist      = if ($tagFile.Tag.Performers) { $tagFile.Tag.Performers -join '; ' } else { 'Unknown Artist' }
                                    Name        = if ($tagFile.Tag.Title) { $tagFile.Tag.Title } else { $f.BaseName }
                                    Duration    = if ($f.Extension -eq '.ape') { Get-ApeDuration -FilePath $f.FullName } else { $tagFile.Properties.Duration.TotalMilliseconds }
                                }
                            }
                            catch {
                                Write-Warning "Skipping corrupted or invalid audio file: $($f.FullName) - Error: $($_.Exception.Message)"
                                continue
                            }
                        }

                        # Update paired tracks with reloaded audio files
                        if ($script:pairedTracks -and $script:pairedTracks.Count -gt 0) {
                            for ($i = 0; $i -lt [Math]::Min($script:pairedTracks.Count, $audioFiles.Count); $i++) {
                                if ($script:pairedTracks[$i].AudioFile.TagFile) {
                                    try { $script:pairedTracks[$i].AudioFile.TagFile.Dispose() } catch { }
                                }
                                $script:pairedTracks[$i].AudioFile = $audioFiles[$i]
                            }
                        }
                    }
                    
                    Write-Host "Album saved and folder moved. Choose 's' to skip to next album, or select another option." -ForegroundColor Yellow
                    #  continue doTracks
                }
            }
            else {
                Write-Warning "Move failed or was skipped. Move result: $moveResult"
            }
        }
        # Helper function: Calculate string similarity (Levenshtein-based)
        function Get-StringSimilarity {
            param(
                $String1,
                $String2
            )
            try {
                # Handle arrays first (before null checks)
                if ($String1 -is [array]) { $String1 = $String1[0] }
                if ($String2 -is [array]) { $String2 = $String2[0] }
                
                # Now check for null/empty
                if (-not $String1 -or -not $String2) { return 0.0 }
                
                # Force to string and normalize
                $s1 = [string]$String1
                $s2 = [string]$String2
                
                # Normalize: remove punctuation that gets replaced in file paths
                # Approve-PathSegment replaces : \ / with _ for Windows compatibility
                # So "TRON: Legacy" matches "TRON_ Legacy"
                $s1 = $s1.ToLower() -replace '[:\\/\-_]', '' -replace '\s+', ' '
                $s2 = $s2.ToLower() -replace '[:\\/\-_]', '' -replace '\s+', ' '
                $s1 = $s1.Trim()
                $s2 = $s2.Trim()
                
                if ($s1 -eq $s2) { return 1.0 }
                
                [int]$len1 = $s1.Length
                [int]$len2 = $s2.Length
                [int]$maxLen = [Math]::Max($len1, $len2)
                
                if ($maxLen -eq 0) { return 1.0 }
                
                # Use Levenshtein distance - create array differently
                $matrix = [int[,]]::new($len1 + 1, $len2 + 1)
                
                for ($i = 0; $i -le $len1; $i++) { $matrix[$i, 0] = $i }
                for ($j = 0; $j -le $len2; $j++) { $matrix[0, $j] = $j }
                
                for ($i = 1; $i -le $len1; $i++) {
                    for ($j = 1; $j -le $len2; $j++) {
                        [int]$cost = if ($s1[$i - 1] -eq $s2[$j - 1]) { 0 } else { 1 }
                        
                        # PowerShell multidimensional arrays can return arrays - use GetValue
                        [int]$deletion = [int]$matrix.GetValue(($i - 1), $j)
                        [int]$insertion = [int]$matrix.GetValue($i, ($j - 1))
                        [int]$substitution = [int]$matrix.GetValue(($i - 1), ($j - 1))
                        
                        [int]$minVal = [Math]::Min([Math]::Min(($deletion + 1), ($insertion + 1)), ($substitution + $cost))
                        $matrix.SetValue($minVal, $i, $j)
                    }
                }
                
                # Extract final distance
                [int]$distance = [int]$matrix.GetValue($len1, $len2)
                [double]$result = 1.0 - ([double]$distance / [double]$maxLen)
                return $result
            }
            catch {
                Write-Warning "Get-StringSimilarity error: $_ | String1 type: $($String1.GetType().Name), String2 type: $($String2.GetType().Name)"
                return 0.0
            }
        }
        
        # Helper function: Calculate match confidence for album
        function Get-AlbumMatchConfidence {
            param(
                $Candidate,
                [string]$LocalArtist,
                [string]$LocalAlbum,
                [int]$LocalTrackCount
            )
            
            $score = 0.0
            $weights = @{
                Artist = 0.30
                Album = 0.40
                TrackCount = 0.30
            }
            
            # Artist similarity
            $remoteArtist = ''
            if ($value = Get-IfExists $Candidate 'artists') {
                if ($value -is [array] -and $value.Count -gt 0) {
                    $remoteArtist = if ($value[0].name) { $value[0].name } else { $value[0].ToString() }
                }
            }
            if (-not $remoteArtist -and ($value = Get-IfExists $Candidate 'artist')) {
                $remoteArtist = $value
            }
            
            if ($remoteArtist) {
                $artistSim = Get-StringSimilarity -String1 $LocalArtist -String2 $remoteArtist
                if ($artistSim -is [array]) { $artistSim = [double]$artistSim[0] }
                $score += ([double]$artistSim * $weights.Artist)
            }
            
            # Album similarity
            $remoteAlbum = Get-IfExists $Candidate 'name'
            if ($remoteAlbum) {
                $albumSim = Get-StringSimilarity -String1 $LocalAlbum -String2 $remoteAlbum
                if ($albumSim -is [array]) { $albumSim = [double]$albumSim[0] }
                $score += ([double]$albumSim * $weights.Album)
            }
            
            # Track count match
            $remoteTrackCount = Get-IfExists $Candidate 'total_tracks'
            if (-not $remoteTrackCount) { $remoteTrackCount = Get-IfExists $Candidate 'track_count' }
            if (-not $remoteTrackCount) { $remoteTrackCount = Get-IfExists $Candidate 'tracks_count' }
            
            # Ensure track count is a scalar integer
            if ($remoteTrackCount -is [array]) { $remoteTrackCount = $remoteTrackCount[0] }
            if ($remoteTrackCount) { 
                try { $remoteTrackCount = [int]$remoteTrackCount } 
                catch { $remoteTrackCount = $null }
            }
            
            if ($remoteTrackCount -and $LocalTrackCount -gt 0) {
                $trackDiff = [Math]::Abs($remoteTrackCount - $LocalTrackCount)
                $trackScore = if ($trackDiff -eq 0) { 1.0 }
                             elseif ($trackDiff -le 2) { 0.8 }
                             elseif ($trackDiff -le 5) { 0.5 }
                             else { 0.0 }
                $score += $trackScore * $weights.TrackCount
            }
            
            return $score
        }
        
        # Helper function: Get best auto match from candidates
        function Get-BestAutoMatch {
            param(
                $Candidates,
                [string]$LocalArtist,
                [string]$LocalAlbum,
                [int]$LocalTrackCount,
                [double]$Threshold
            )
            
            $bestMatch = $null
            $bestScore = 0.0
            $bestIndex = -1
            
            for ($i = 0; $i -lt $Candidates.Count; $i++) {
                $score = Get-AlbumMatchConfidence -Candidate $Candidates[$i] `
                    -LocalArtist $LocalArtist -LocalAlbum $LocalAlbum `
                    -LocalTrackCount $LocalTrackCount
                
                if ($score -gt $bestScore) {
                    $bestScore = $score
                    $bestMatch = $Candidates[$i]
                    $bestIndex = $i
                }
            }
            
            if ($bestScore -ge $Threshold) {
                return @{
                    Album = $bestMatch
                    Index = $bestIndex + 1
                    Confidence = [Math]::Round($bestScore * 100, 0)
                }
            }
            
            return $null
        }
        
        # Helper function: Provider fallback with Qobuz → Spotify priority
        function Invoke-ProviderWithFallback {
            param(
                [string]$PrimaryProvider,
                [string]$Artist,
                [string]$Album,
                [int]$TrackCount,
                [double]$Threshold,
                [switch]$EnableFallback
            )
            
            # Try primary provider
            Write-Host "🔍 AUTO: Searching $PrimaryProvider for '$Album' by '$Artist'..." -ForegroundColor Cyan
            
            try {
                $results = Invoke-ProviderSearch -Provider $PrimaryProvider -Album $Album -Artist $Artist -Type album
                $candidates = if ($results -and $results.albums -and $results.albums.PSObject.Properties.Name -contains 'items' -and $results.albums.items) { @($results.albums.items | Where-Object { $_ -ne $null }) } else { @() }
            }
            catch {
                Write-Verbose "Primary provider search failed: $_"
                $candidates = @()
            }
            
            if ($candidates.Count -gt 0) {
                $bestMatch = Get-BestAutoMatch -Candidates $candidates -LocalArtist $Artist `
                    -LocalAlbum $Album -LocalTrackCount $TrackCount -Threshold $Threshold
                
                if ($bestMatch) {
                    Write-Host "✓ AUTO: Found high-confidence match on $PrimaryProvider ($($bestMatch.Confidence)%)" -ForegroundColor Green
                    return @{
                        Provider = $PrimaryProvider
                        Album = $bestMatch.Album
                        Confidence = $bestMatch.Confidence
                        IsFallback = $false
                    }
                }
            }
            
            # No good match - try fallback if enabled
            if (-not $EnableFallback) {
                Write-Verbose "No high-confidence match on $PrimaryProvider and fallback disabled"
                return $null
            }
            
            # Fallback chain: Qobuz → Spotify → Discogs → MusicBrainz
            # Always try Qobuz first (most reliable), then Spotify
            $fallbackChain = switch ($PrimaryProvider) {
                'Qobuz' { @('Spotify', 'Discogs', 'MusicBrainz') }
                'Spotify' { @('Qobuz', 'Discogs', 'MusicBrainz') }
                'Discogs' { @('Qobuz', 'Spotify', 'MusicBrainz') }
                'MusicBrainz' { @('Qobuz', 'Spotify', 'Discogs') }
            }
            
            foreach ($fallbackProvider in $fallbackChain) {
                Write-Host "⚠️  AUTO: No good match on $PrimaryProvider, trying $fallbackProvider..." -ForegroundColor Yellow
                
                try {
                    $fallbackResults = Invoke-ProviderSearch -Provider $fallbackProvider -Album $Album -Artist $Artist -Type album
                    $fallbackCandidates = if ($fallbackResults -and $fallbackResults.albums -and $fallbackResults.albums.PSObject.Properties.Name -contains 'items' -and $fallbackResults.albums.items) { @($fallbackResults.albums.items | Where-Object { $_ -ne $null }) } else { @() }
                }
                catch {
                    Write-Verbose "Fallback provider $fallbackProvider search failed: $_"
                    continue
                }
                
                if ($fallbackCandidates.Count -gt 0) {
                    $bestMatch = Get-BestAutoMatch -Candidates $fallbackCandidates -LocalArtist $Artist `
                        -LocalAlbum $Album -LocalTrackCount $TrackCount -Threshold $Threshold
                    
                    if ($bestMatch) {
                        Write-Host "✓ AUTO: Found high-confidence match on $fallbackProvider ($($bestMatch.Confidence)% confidence)" -ForegroundColor Green
                        return @{
                            Provider = $fallbackProvider
                            Album = $bestMatch.Album
                            Confidence = $bestMatch.Confidence
                            IsFallback = $true
                        }
                    }
                }
            }
            
            Write-Verbose "No high-confidence match found on any provider"
            return $null
        }
        
        $script:album = $null
        
        # Handle single album path: extract artist from parent folder
        if ($script:isSingleAlbumPath) {
            $parentPath = Split-Path -Parent $Path
            if ($parentPath -and $parentPath -notmatch '^[A-Z]:\\?$') {
                # Normal case: parent is a valid artist folder name
                $script:artist = Split-Path -Leaf $parentPath
                $artist = $script:artist
                Write-Verbose "Single album mode: Extracted artist '$artist' from parent folder"
            }
            else {
                # Root-level album folder - use album folder name as placeholder artist
                # This will be overridden by ProviderAlbum.album_artist during "sa" command
                $albumFolderName = Split-Path -Leaf $Path
                $script:artist = $albumFolderName
                $artist = $script:artist
                Write-Verbose "Single album mode: Root-level album detected at drive root, using album folder name '$artist' as temporary artist (will be updated from metadata)"
            }
            
            # Process only the target album folder
            $albums = @(Get-Item -LiteralPath $Path)
            Write-Verbose "Single album mode: Processing only album folder '$($albums[0].Name)'"
        }
        else {
            # Original behavior: Path is artist folder containing album subfolders
            $script:artist = Split-Path -Leaf $Path
            $artist = Split-Path -Leaf $Path
            $albums = @(Get-ChildItem -LiteralPath $Path -Directory)
            Write-Verbose "Artist folder mode: Processing $($albums.Count) album folders under artist '$artist'"
        }
        
        # Initialize WhatIf mode early
        $useWhatIf = $isWhatIf
        $script:findMode = 'artist-first'  # Default to artist-first mode
        $currentAlbumPage = 1
        
        foreach ($albumOriginal in $albums) {
            $script:album = $albumOriginal
            $script:ManualAlbumArtist = $null
            # Initialize script-scope variables used by handleMoveSuccess scriptblock
            $script:audioFiles = $null
            $script:pairedTracks = $null
            $script:refreshTracks = $false
            # derive album name and year
            # Try to extract year from the start of the folder name (e.g., "2023 - Album Name")
            if ($script:album.Name -match '^(\d{4})\s*[-]?\s*(.+)') {
                $year = $matches[1]
                $albumName = $matches[2].Trim()
                $script:albumName = $matches[2].Trim()
            }
            else {
                $year = $null
                $script:albumName = $script:album.Name.Trim()
                $albumName = $script:album.Name.Trim()

            }
            $audioFilesCheck = @(Get-ChildItem -LiteralPath $script:album.FullName -File -Recurse | 
                Where-Object { $_.Extension -match '\.(mp3|flac|wav|m4a|aac|ogg|ape)' } |
                Sort-Object { [regex]::Replace($_.Name, '(\d+)', { $args[0].Value.PadLeft(10, '0') }) })
            if (-not $audioFilesCheck -or $audioFilesCheck.Count -eq 0) {
                Write-Warning "No supported audio files found in album folder: $($script:album.FullName). Skipping album."
                continue
            }
            $script:trackCount = $audioFilesCheck.Count
            $artistQuery = $artist
            $stage = "A"
            $cachedAlbums = $null
            $cachedArtistId = $null
            $loadStageBResults = $true 
            $page = 1
            $pageSize = 25
            $albumDone = $false
            $mastersOnlyMode = $true  # Track Discogs filter state: true=masters only, false=all releases
            $script:findMode = 'quick'  # Always start in quick find mode
            $script:quickAlbumCandidates = $null
            $script:quickCurrentPage = 1
            $script:backNavigationMode = $false
            $currentArtist = $script:artist  # Persistent current artist for quick find mode
            $currentAlbum = $script:albumName  # Persistent current album for quick find mode
            $skipQuickPrompts = $false  # Flag to skip prompts when re-entering quick find after provider change

            :stageLoop while ($true) {
                # NEW: Handle quick find mode (only when not in track selection stage)
                if ($script:findMode -eq 'quick' -and $stage -ne 'C') {
                    if ($VerbosePreference -ne 'Continue') { Clear-Host }
                    & $showHeader -Provider $Provider -Artist $script:artist -AlbumName $script:albumName -TrackCount $script:trackCount
                    Write-Host "🔍 Find Mode: Quick Album Search" -ForegroundColor Magenta
                    Write-Host ""

                    # Auto-detect artist and album from folder structure
                    if (-not $skipQuickPrompts) {
                        Write-Verbose "DEBUG: Running auto-detection (skipQuickPrompts=$skipQuickPrompts)"
                        $folderName = $script:album.Name
                        $artistFolderName = $script:album.Parent.Name
                        
                        # Extract album name (strip year if present)
                        if ($folderName -match '^\d{4}\s*-\s*(.+)$') {
                            $detectedAlbum = $matches[1].Trim()
                        }
                        else {
                            $detectedAlbum = $folderName
                        }
                        
                        # Use parent folder as artist
                        $detectedArtist = $artistFolderName
                        
                        # Try to load AlbumArtist tag from first audio file for better detection
                        $tagArtist = $null
                        try {
                            $firstAudioFile = Get-ChildItem -LiteralPath $script:album.FullName -File -Recurse -ErrorAction Stop | 
                                Where-Object { $_.Extension -in '.flac', '.mp3', '.m4a', '.ogg', '.opus', '.wma', '.ape' } |
                                Select-Object -First 1
                            
                            if ($firstAudioFile -and $firstAudioFile.FullName) {
                                Write-Verbose "DEBUG: Loading tag from $($firstAudioFile.Name)"
                                
                                # Load TagLib if not already loaded
                                if (-not ([System.Management.Automation.PSTypeName]'TagLib.File').Type) {
                                    $tagLibPath = Join-Path $PSScriptRoot '..' 'lib' 'taglib-sharp.dll'
                                    if (Test-Path $tagLibPath) {
                                        Add-Type -Path $tagLibPath -ErrorAction Stop
                                    }
                                }
                                
                                $tagFile = [TagLib.File]::Create($firstAudioFile.FullName)
                                $tagArtist = if ($tagFile.Tag.FirstAlbumArtist) { $tagFile.Tag.FirstAlbumArtist } else { $null }
                                $tagFile.Dispose()
                                Write-Verbose "DEBUG: AlbumArtist tag='$tagArtist'"
                            }
                        }
                        catch {
                            Write-Verbose "Failed to load AlbumArtist tag for detection: $_"
                        }
                        
                        # If tag contains folder artist, use the more complete tag value
                        if ($tagArtist -and $tagArtist -match [regex]::Escape($detectedArtist)) {
                            Write-Host "📁 Auto-detected from folder: Artist='$detectedArtist', Album='$detectedAlbum'" -ForegroundColor Gray
                            Write-Host "🎵 Using AlbumArtist tag for better match: '$tagArtist'" -ForegroundColor Green
                            $detectedArtist = $tagArtist
                            
                            # Also check if album name has "Artist - Title" pattern and strip it
                            if ($detectedAlbum -match '^([^-]+?)\s*-\s*(.+)$') {
                                $possibleArtist = $matches[1].Trim()
                                $possibleAlbumOnly = $matches[2].Trim()
                                # If the album prefix looks like part of artist name, strip it
                                if ($possibleArtist -match [regex]::Escape($detectedArtist) -or $detectedArtist -match [regex]::Escape($possibleArtist)) {
                                    $detectedAlbum = $possibleAlbumOnly
                                    Write-Host "   Cleaned album name to: '$detectedAlbum'" -ForegroundColor Gray
                                }
                            }
                        }
                        # Otherwise check if album name has "Artist - Title" pattern
                        elseif ($detectedAlbum -match '^([^-]+?)\s*-\s*(.+)$') {
                            $possibleArtist = $matches[1].Trim()
                            $possibleAlbumOnly = $matches[2].Trim()
                            
                            if ($possibleArtist -match [regex]::Escape($detectedArtist)) {
                                Write-Host "📁 Auto-detected from folder: Artist='$detectedArtist', Album='$detectedAlbum'" -ForegroundColor Gray
                                Write-Host "🎵 Using artist from album name: '$possibleArtist'" -ForegroundColor Green
                                $detectedArtist = $possibleArtist
                                $detectedAlbum = $possibleAlbumOnly
                            }
                            else {
                                Write-Host "📁 Auto-detected from folder structure: Artist='$detectedArtist', Album='$detectedAlbum'" -ForegroundColor Green
                            }
                        }
                        else {
                            Write-Host "📁 Auto-detected from folder structure: Artist='$detectedArtist', Album='$detectedAlbum'" -ForegroundColor Green
                        }
                        
                        $currentArtist = $detectedArtist
                        $currentAlbum = $detectedAlbum
                        Write-Verbose "DEBUG: Set currentArtist='$currentArtist', currentAlbum='$currentAlbum'"
                        $skipQuickPrompts = $true  # Skip prompts since both detected from structure
                    }
                    else {
                        Write-Verbose "DEBUG: Skipping auto-detection (skipQuickPrompts=$skipQuickPrompts), using currentArtist='$currentArtist'"
                    }

                    if (-not $skipQuickPrompts) {
                        # Prompt for artist and album with pre-filled defaults
                        Write-Host "Artist [$currentArtist]: " -NoNewline
                        $userInput = Read-Host
                        if ($userInput) { $currentArtist = $userInput }
                        $quickArtist = $currentArtist
                        if (-not $quickArtist) {
                            Write-Host "Artist is required. Switching to artist-first mode." -ForegroundColor Yellow
                            $script:findMode = 'artist-first'
                            $stage = 'A'
                            continue stageLoop
                        }
                        
                        Write-Host "Album [$currentAlbum]: " -NoNewline
                        $userInput = Read-Host
                        if ($userInput) { $currentAlbum = $userInput }
                        $quickAlbum = $currentAlbum
                        if (-not $quickAlbum) {
                            Write-Host "Album is required. Switching to artist-first mode." -ForegroundColor Yellow
                            $script:findMode = 'artist-first'
                            $stage = 'A'
                            continue stageLoop
                        }

                        $skipQuickPrompts = $true  # Skip prompts on subsequent entries
                    }
                    else {
                        # Use current values without prompting
                        $quickArtist = $currentArtist
                        $quickAlbum = $currentAlbum
                    }

                    # Check if we have cached albums from back navigation
                    if ($script:backNavigationMode -and $script:quickAlbumCandidates) {
                        $albumCandidates = $script:quickAlbumCandidates
                        Write-Host "Using cached album results for back navigation..." -ForegroundColor Cyan
                    }
                    else {
                        Write-Host "Searching for '$quickAlbum' by '$quickArtist'..." -ForegroundColor Cyan
                        
                        :quickSearchLoop while ($true) {
                            $quickAlbum = $currentAlbum
                            $quickArtist = $currentArtist
                            try {
                                $quickResults = Invoke-ProviderSearch -Provider $Provider -Album $quickAlbum -Artist $quickArtist -Type album
                                $albumCandidates = if ($quickResults -and $quickResults.albums -and $quickResults.albums.PSObject.Properties.Name -contains 'items' -and $quickResults.albums.items) { @($quickResults.albums.items | Where-Object { $_ -ne $null }) } else { @() }
                            }
                            catch {
                                Write-Warning "Quick search failed: $_"
                                $albumCandidates = @()
                            }
                            
                            # Check if we have candidates (use the properly extracted $albumCandidates)
                            if ($null -eq $albumCandidates -or $albumCandidates.Count -eq 0) {
                                Write-Host "No albums found for '$quickAlbum' by '$quickArtist' with $Provider." -ForegroundColor Red
                                $retryChoice = Read-Host "`nPress Enter to retry, (ps)potify, (pq)obuz, (pd)iscogs, (pm)usicbrainz, '(a)' artist-first mode, (ni) New Item (enter new artist+album), (x) skip album, or enter new album name"
                                if ($retryChoice -eq 'ps') {
                                    $Provider = 'Spotify'
                                    Write-Host "Switched to provider: $Provider" -ForegroundColor Green
                                    continue quickSearchLoop
                                }
                                elseif ($retryChoice -eq 'pq') {
                                    $Provider = 'Qobuz'
                                    Write-Host "Switched to provider: $Provider" -ForegroundColor Green
                                    continue quickSearchLoop
                                }
                                elseif ($retryChoice -eq 'pd') {
                                    $Provider = 'Discogs'
                                    Write-Host "Switched to provider: $Provider" -ForegroundColor Green
                                    continue quickSearchLoop
                                }
                                elseif ($retryChoice -eq 'pm') {
                                    $Provider = 'MusicBrainz'
                                    Write-Host "Switched to provider: $Provider" -ForegroundColor Green
                                    continue quickSearchLoop
                                }
                                elseif ($retryChoice -eq 'a') {
                                    $script:findMode = 'artist-first'
                                    $stage = 'A'
                                    break quickSearchLoop
                                }
                                # 'na' (new artist) removed; use (ni) New Item instead
                                elseif ($retryChoice -eq 'ni') {
                                    # Prompt for new artist AND album together
                                    $res = Read-ArtistAlbum -DefaultArtist $currentArtist -DefaultAlbum $currentAlbum
                                    if ($res.ChangedArtist) { $currentArtist = $res.Artist }
                                    if ($res.ChangedAlbum) { $currentAlbum = $res.Album }
                                }
                                elseif ($retryChoice -eq 'x' -or $retryChoice -eq 'xip') {
                                    # Skip this album
                                    Write-Host "Skipping album: $quickAlbum" -ForegroundColor Yellow
                                    $albumDone = $true
                                    break quickSearchLoop
                                }
                                elseif ($retryChoice) {
                                    # Assume it's a new album name
                                    $currentAlbum = $retryChoice
                                }
                                else {
                                    continue quickSearchLoop
                                }
                            }
                            else {
                                break quickSearchLoop
                            }
                        }

                        if ($script:findMode -ne 'quick') {
                            continue stageLoop
                        }

                        # Store candidates for back navigation
                        $script:quickAlbumCandidates = $albumCandidates
                        $script:quickCurrentPage = 1
                        $script:backNavigationMode = $false  # Reset back navigation flag
                    }
                    
                    # AUTO MODE: Check existing candidates first, then try fallback if needed
                    if ($Auto) {
                        # First, try to find a good match in the candidates we already have
                        $bestMatch = $null
                        if ($albumCandidates.Count -gt 0) {
                            # Debug: Show confidence scores for all candidates
                            Write-Host "🤖 AUTO: Calculating confidence scores..." -ForegroundColor Cyan
                            $index = 1
                            foreach ($candidate in $albumCandidates) {
                                $scoreVal = Get-AlbumMatchConfidence -Candidate $candidate -LocalArtist $quickArtist -LocalAlbum $quickAlbum -LocalTrackCount $script:trackCount
                                $scorePercent = $scoreVal * 100
                                $displayName = if ($candidate.name) { $candidate.name } else { $candidate.title }
                                Write-Host "   [$index] $displayName : $([math]::Round($scorePercent, 1))%" -ForegroundColor $(if ($scorePercent -ge ($AutoConfidenceThreshold * 100)) { 'Green' } else { 'Yellow' })
                                $index++
                            }
                            
                            $bestMatch = Get-BestAutoMatch -Candidates $albumCandidates `
                                -LocalArtist $quickArtist -LocalAlbum $quickAlbum `
                                -LocalTrackCount $script:trackCount -Threshold $AutoConfidenceThreshold
                            
                            if ($bestMatch) {
                                Write-Host "✓ AUTO: Found high-confidence match on $Provider ($($bestMatch.Confidence)%)" -ForegroundColor Green
                            } else {
                                Write-Host "⚠️  AUTO: Best match below threshold (need $([math]::Round($AutoConfidenceThreshold * 100, 1))%)" -ForegroundColor Yellow
                            }
                        }
                        else {
                            Write-Host "⚠️  AUTO: No albums found on $Provider" -ForegroundColor Yellow
                        }
                        
                        # If no good match and fallback is enabled, try other providers
                        if (-not $bestMatch -and $AutoFallback) {
                            if ($albumCandidates.Count -gt 0) {
                                Write-Host "⚠️  AUTO: No high-confidence match on $Provider, trying fallback providers..." -ForegroundColor Yellow
                            }
                            else {
                                Write-Host "⚠️  AUTO: Trying fallback providers..." -ForegroundColor Yellow
                            }
                            
                            # Determine fallback chain
                            $fallbackChain = switch ($Provider) {
                                'Qobuz' { @('Spotify', 'Discogs', 'MusicBrainz') }
                                'Spotify' { @('Qobuz', 'Discogs', 'MusicBrainz') }
                                'Discogs' { @('Qobuz', 'Spotify', 'MusicBrainz') }
                                'MusicBrainz' { @('Qobuz', 'Spotify', 'Discogs') }
                            }
                            
                            foreach ($fallbackProvider in $fallbackChain) {
                                Write-Host "   Trying $fallbackProvider..." -ForegroundColor Cyan
                                
                                try {
                                    $fallbackResults = Invoke-ProviderSearch -Provider $fallbackProvider -Album $quickAlbum -Artist $quickArtist -Type album
                                    $fallbackCandidates = if ($fallbackResults -and $fallbackResults.albums -and $fallbackResults.albums.items) { @($fallbackResults.albums.items | Where-Object { $_ -ne $null }) } else { @() }
                                }
                                catch {
                                    Write-Verbose "Fallback provider $fallbackProvider search failed: $_"
                                    continue
                                }
                                
                                if ($fallbackCandidates.Count -gt 0) {
                                    $fallbackMatch = Get-BestAutoMatch -Candidates $fallbackCandidates `
                                        -LocalArtist $quickArtist -LocalAlbum $quickAlbum `
                                        -LocalTrackCount $script:trackCount -Threshold $AutoConfidenceThreshold
                                    
                                    if ($fallbackMatch) {
                                        Write-Host "   ✓ Found high-confidence match on $fallbackProvider ($($fallbackMatch.Confidence)%)" -ForegroundColor Green
                                        $bestMatch = $fallbackMatch
                                        $Provider = $fallbackProvider
                                        Write-Host "🔄 AUTO: Switched to provider $Provider for better match" -ForegroundColor Cyan
                                        break
                                    }
                                }
                            }
                        }
                        
                        # If we found a match (either primary or fallback), proceed
                        if ($bestMatch) {
                            $ProviderAlbum = $bestMatch.Album
                            
                            # Extract artist from album metadata
                            $artistNameFromAlbum = $null
                            if ($value = Get-IfExists $ProviderAlbum 'artists') {
                                if ($value -is [array] -and $value.Count -gt 0) {
                                    $artistNameFromAlbum = if ($value[0].name) { $value[0].name } else { $value[0].ToString() }
                                }
                            }
                            elseif ($value = Get-IfExists $ProviderAlbum 'artist') {
                                $artistNameFromAlbum = $value
                            }
                            
                            if (-not $artistNameFromAlbum) {
                                $artistNameFromAlbum = $quickArtist
                            }
                            
                            # For Spotify, fetch full artist details
                            if ($Provider -eq 'Spotify' -and $ProviderAlbum.artists -and $ProviderAlbum.artists.Count -gt 0) {
                                $artistId = $ProviderAlbum.artists[0].id
                                if ($artistId) {
                                    $ProviderArtist = Invoke-ProviderGetArtist -Provider $Provider -ArtistId $artistId
                                    if (-not $ProviderArtist) {
                                        $ProviderArtist = @{ name = $artistNameFromAlbum; id = $artistNameFromAlbum }
                                    }
                                }
                                else {
                                    $ProviderArtist = @{ name = $artistNameFromAlbum; id = $artistNameFromAlbum }
                                }
                            }
                            else {
                                $ProviderArtist = @{ name = $artistNameFromAlbum; id = $artistNameFromAlbum }
                            }
                            
                            Write-Host "✓ AUTO: Selected album: $($ProviderAlbum.name)" -ForegroundColor Green
                            
                            # UpdateGenresOnly mode in Auto: Skip Stage C and directly update genres
                            if ($UpdateGenresOnly) {
                                Write-Host "`n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
                                Write-Host "🎵 UPDATE GENRES ONLY MODE (AUTO)" -ForegroundColor Magenta
                                Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
                                Write-Host ""
                                Write-Host "Album: $($ProviderAlbum.name)" -ForegroundColor Green
                                Write-Host "Genre mode: $($script:genreMode)" -ForegroundColor Yellow
                                Write-Host ""
                                
                                # Get audio files
                                $genreUpdateFiles = @(Get-ChildItem -LiteralPath $script:album.FullName -File -Recurse | 
                                    Where-Object { $_.Extension -match '\.(mp3|flac|wav|m4a|aac|ogg|ape)' })
                                
                                if ($genreUpdateFiles.Count -eq 0) {
                                    Write-Warning "No audio files found. Skipping."
                                    $albumDone = $true
                                    continue stageLoop
                                }
                                
# Extract genres from $ProviderAlbum (already fetched from search) or $ProviderArtist
                                    Write-Verbose "Extracting genres from $Provider album/artist..."
                                    try {
                                        $providerGenres = @()
                                        
                                        # Try album-level genres first
                                        if ($ProviderAlbum.genres) {
                                            $providerGenres = @($ProviderAlbum.genres)
                                            Write-Verbose "Found genres from album: $($providerGenres -join ', ')"
                                        }
                                        # Try album genre field (Qobuz/Discogs/MusicBrainz)
                                        elseif ($ProviderAlbum.genre) {
                                            $providerGenres = @($ProviderAlbum.genre)
                                            Write-Verbose "Found genre from album: $($providerGenres -join ', ')"
                                        }
                                        # Try styles field (Discogs)
                                        elseif ($ProviderAlbum.styles) {
                                            $providerGenres = @($ProviderAlbum.styles)
                                            Write-Verbose "Found styles from album: $($providerGenres -join ', ')"
                                        }
                                        # Fallback to artist genres (Spotify)
                                        elseif ($ProviderArtist -and $ProviderArtist.genres) {
                                            $providerGenres = @($ProviderArtist.genres)
                                            Write-Verbose "Found genres from artist: $($providerGenres -join ', ')"
                                    }
                                    
                                    $providerGenres = @($providerGenres | Where-Object { $_ -and $_ -ne '' } | ForEach-Object { $_.ToString().Trim() })
                                    
                                    if ($providerGenres.Count -eq 0) {
                                        Write-Warning "No genres found for this album. Skipping."
                                        $albumDone = $true
                                        continue stageLoop
                                    }
                                    
                                    Write-Host "Genres: $($providerGenres -join ', ')" -ForegroundColor Green
                                    
                                    # Update files
                                    $updatedCount = 0
                                    foreach ($audioFile in $genreUpdateFiles) {
                                        try {
                                            $currentTags = Get-OMTags -Path $audioFile.FullName
                                            $currentGenres = if ($currentTags.Genres) { @($currentTags.Genres) } else { @() }
                                            
                                            $newGenres = if ($script:genreMode -eq 'Merge') {
                                                $combined = @($currentGenres) + @($providerGenres)
                                                @($combined | Select-Object -Unique)
                                            }
                                            else {
                                                $providerGenres
                                            }
                                            
                                            # Check if changed
                                            $changed = $false
                                            if ($newGenres.Count -ne $currentGenres.Count) {
                                                $changed = $true
                                            }
                                            else {
                                                $sortedNew = $newGenres | Sort-Object
                                                $sortedCurrent = $currentGenres | Sort-Object
                                                for ($i = 0; $i -lt $newGenres.Count; $i++) {
                                                    if ($sortedNew[$i] -cne $sortedCurrent[$i]) {
                                                        $changed = $true
                                                        break
                                                    }
                                                }
                                            }
                                            
                                            if ($changed) {
                                                Write-Verbose "  Updating: $($audioFile.Name) ($($currentGenres -join ', ') → $($newGenres -join ', '))"
                                                Set-OMTags -Path $audioFile.FullName -Tags @{ Genres = $newGenres } -Force -WhatIf:$useWhatIf | Out-Null
                                                $updatedCount++
                                            }
                                        }
                                        catch {
                                            Write-Warning "Failed to update '$($audioFile.Name)': $_"
                                        }
                                    }
                                    
                                    if ($useWhatIf) {
                                        Write-Host "✓ WhatIf: Would update $updatedCount/$($genreUpdateFiles.Count) file(s)" -ForegroundColor Yellow
                                    }
                                    else {
                                        Write-Host "✓ Updated $updatedCount/$($genreUpdateFiles.Count) file(s)" -ForegroundColor Green
                                    }
                                    Write-Host ""
                                    
                                    $albumDone = $true
                                    continue stageLoop
                                }
                                catch {
                                    Write-Error "Failed to update genres: $_"
                                    $albumDone = $true
                                    continue stageLoop
                                }
                            }
                            
                            $stage = 'C'
                            $script:autoModeActive = $true
                            continue stageLoop
                        }
                        else {
                            Write-Warning "AUTO: No high-confidence match found. Falling back to interactive selection."
                            $script:autoModeActive = $false
                        }
                    }

                    # Album selection for quick mode
                    $ProviderArtist = @{ name = $quickArtist; id = $quickArtist }  # Simplified artist object

                    # Album selection loop
                    :albumSelectionLoop while ($true) {
                        if ($VerbosePreference -ne 'Continue') { Clear-Host }
                        & $showHeader -Provider $Provider -Artist $script:artist -AlbumName $script:albumName -TrackCount $script:trackCount
                        Write-Host "🔍 Find Mode: Quick Album Search" -ForegroundColor Magenta
                        Write-Host ""
                        
                        Write-Host "$Provider Album candidates for '$quickAlbum' by '$quickArtist':" -ForegroundColor Green
                        for ($i = 0; $i -lt $albumCandidates.Count; $i++) {
                            $album = $albumCandidates[$i]
                            $artistDisplay = if ($album.artists -and $album.artists[0].name) { $album.artists[0].name } else { 'Unknown Artist' }
                            
                            $year = Get-IfExists $album 'release_date'
                            $trackCount = Get-IfExists $album 'total_tracks'
                            if (-not $trackCount) { $trackCount = Get-IfExists $album 'track_count' }
                            if (-not $trackCount) { $trackCount = Get-IfExists $album 'tracks_count' }
                            $trackInfo = if ($trackCount) { " ($trackCount tracks)" } else { "" }
                            
                            Write-Host "[$($i+1)] $($album.name) - $artistDisplay (id: $($album.id)) (year: $year)$trackInfo"
                        }

                        $originalColor = [Console]::ForegroundColor
                        [Console]::ForegroundColor = [ConsoleColor]::Yellow
                        $modeIndicator = if (
                        $script:backNavigationMode) { " (Back Navigation - use 'f' to search again)" } else { "" }
                        $albumChoice = Read-Host "Select album [number] (Enter=first), (P)rovider, {F}indMode, (ni) New Item (enter new artist+album), (x)ip, (C)over {[V]iew,[O]riginal,[S]ave,saveIn[T]ags}, or new search term$modeIndicator"
                        [Console]::ForegroundColor = $originalColor
                        if ($albumChoice -eq '') { $albumChoice = '1' }
                        
                        if ($albumChoice -eq 'p') {
                            # Show current provider and available shortcuts
                            $config = Get-OMConfig
                            $defaultProvider = $config.DefaultProvider
                            Write-Host "`nCurrent provider: $Provider (default: $defaultProvider)" -ForegroundColor Cyan
                            Write-Host "To switch providers, use: (ps)potify, (pq)obuz, (pd)iscogs, (pm)usicbrainz" -ForegroundColor Gray
                            continue albumSelectionLoop
                        }
                        elseif ($albumChoice -eq 'ps') {
                            $Provider = 'Spotify'
                            Write-Host "Switched to provider: $Provider" -ForegroundColor Green
                            $skipQuickPrompts = $true
                            $script:backNavigationMode = $false
                            continue stageLoop
                        }
                        elseif ($albumChoice -eq 'pq') {
                            $Provider = 'Qobuz'
                            Write-Host "Switched to provider: $Provider" -ForegroundColor Green
                            $skipQuickPrompts = $true
                            $script:backNavigationMode = $false
                            continue stageLoop
                        }
                        elseif ($albumChoice -eq 'pd') {
                            $Provider = 'Discogs'
                            Write-Host "Switched to provider: $Provider" -ForegroundColor Green
                            $skipQuickPrompts = $true
                            $script:backNavigationMode = $false
                            continue stageLoop
                        }
                        elseif ($albumChoice -eq 'pm') {
                            $Provider = 'MusicBrainz'
                            Write-Host "Switched to provider: $Provider" -ForegroundColor Green
                            $skipQuickPrompts = $true
                            $script:backNavigationMode = $false
                            continue stageLoop
                        }
                        elseif ($albumChoice.ToLower() -eq 'f') {
                            $script:findMode = 'artist-first'
                            $script:backNavigationMode = $false
                            $stage = 'A'
                            continue stageLoop
                        }
                        # 'na' (new artist) removed; use (ni) New Item instead
                        elseif ($albumChoice -eq 'ni') {
                            # Prompt for new artist and album in one step
                            $res = Read-ArtistAlbum -DefaultArtist $currentArtist -DefaultAlbum $currentAlbum
                            if ($res.ChangedArtist) { $currentArtist = $res.Artist }
                            if ($res.ChangedAlbum) { $currentAlbum = $res.Album }
                            $skipQuickPrompts = $true
                            $script:backNavigationMode = $false
                            continue stageLoop
                        }
                        elseif ($albumChoice -match '^cvo(.*)$') {
                            $rangeText = $matches[1]
                            if (-not $rangeText) { $rangeText = "1" }
                            Write-Verbose "Quickfind cv: Show-CoverArt called with Size='original' Grid='False' AlbumCount=$($albumCandidates.Count)"
                            Show-CoverArt -RangeText $rangeText -AlbumList $albumCandidates -Provider $Provider -Size 'original' -Grid $false
                            Read-Host "Press Enter to continue..."
                            continue albumSelectionLoop
                        }
                        elseif ($albumChoice -match '^cv(.*)$') {
                            $rangeText = $matches[1]
                            if (-not $rangeText) { $rangeText = "1" }
                            Write-Verbose "Quickfind cvo: Show-CoverArt called with Size='original' Grid='False' AlbumCount=$($albumCandidates.Count)"
                            Show-CoverArt -RangeText $rangeText -AlbumList $albumCandidates -Provider $Provider -Size 'original' -Grid $false
                            Read-Host "Press Enter to continue..."
                            continue albumSelectionLoop
                        }
                        elseif ($albumChoice -match '^cs(.*)$') {
                            $rangeText = $matches[1]
                            if (-not $rangeText) { $rangeText = "1" }
                            try {
                                $selectedIndices = Expand-SelectionRange -RangeText $rangeText -MaxIndex $albumCandidates.Count
                            }
                            catch {
                                Write-Warning "Invalid range syntax for cs command: $rangeText - $_"
                                continue albumSelectionLoop
                            }
                            if ($selectedIndices -isnot [array]) {
                                $selectedIndices = @($selectedIndices)
                            }
                            if ($selectedIndices.Count -eq 0) {
                                Write-Warning "No valid albums selected for cs command"
                                continue albumSelectionLoop
                            }
                            $config = Get-OMConfig
                            $maxSize = $config.CoverArt.FolderImageSize
                            foreach ($index in $selectedIndices) {
                                $albumIndex = $index - 1
                                $selectedAlbum = $albumCandidates[$albumIndex]
                                if ($selectedAlbum.cover_url) {
                                    $result = Save-CoverArt -CoverUrl $selectedAlbum.cover_url -AlbumPath $script:album.FullName -Action SaveToFolder -MaxSize $maxSize -WhatIf:$useWhatIf
                                    if (-not $result.Success) {
                                        Write-Warning "Failed to save cover art for album $index ($($selectedAlbum.name)): $($result.Error)"
                                    }
                                }
                                else {
                                    Write-Warning "No cover art available for album $index ($($selectedAlbum.name))"
                                }
                            }
                            continue albumSelectionLoop
                        }
                        elseif ($albumChoice -match '^ct(.*)$') {
                            $rangeText = $matches[1]
                            if (-not $rangeText) { $rangeText = "1" }
                            try {
                                $selectedIndices = Expand-SelectionRange -RangeText $rangeText -MaxIndex $albumCandidates.Count
                            }
                            catch {
                                Write-Warning "Invalid range syntax for ct command: $rangeText - $_"
                                continue albumSelectionLoop
                            }
                            if ($selectedIndices -isnot [array]) {
                                $selectedIndices = @($selectedIndices)
                            }
                            if ($selectedIndices.Count -eq 0) {
                                Write-Warning "No valid albums selected for ct command"
                                continue albumSelectionLoop
                            }
                            $config = Get-OMConfig
                            $maxSize = $config.CoverArt.TagImageSize
                            # Get audio files for embedding
                            $audioFiles = Get-ChildItem -LiteralPath $script:album.FullName -File -Recurse | 
                                Where-Object { $_.Extension -match '\.(mp3|flac|wav|m4a|aac|ogg|ape)' } |
                                Sort-Object { [regex]::Replace($_.Name, '(\d+)', { $args[0].Value.PadLeft(10, '0') }) } | ForEach-Object {
                                try {
                                    $tagFile = [TagLib.File]::Create($_.FullName)
                                    [PSCustomObject]@{
                                        FilePath = $_.FullName
                                        TagFile  = $tagFile
                                    }
                                }
                                catch {
                                    Write-Warning "Skipping invalid audio file: $($_.FullName)"
                                    $null
                                }
                            } | Where-Object { $_ -ne $null }

                            if ($audioFiles.Count -gt 0) {
                                foreach ($index in $selectedIndices) {
                                    $albumIndex = $index - 1
                                    $selectedAlbum = $albumCandidates[$albumIndex]
                                    if ($selectedAlbum.cover_url) {
                                        $result = Save-CoverArt -CoverUrl $selectedAlbum.cover_url -AudioFiles $audioFiles -Action EmbedInTags -MaxSize $maxSize -WhatIf:$useWhatIf
                                        if (-not $result.Success) {
                                            Write-Warning "Failed to embed cover art for album $index ($($selectedAlbum.name)): $($result.Error)"
                                        }
                                    }
                                    else {
                                        Write-Warning "No cover art available for album $index ($($selectedAlbum.name))"
                                    }
                                }
                                # Clean up tag files
                                foreach ($af in $audioFiles) {
                                    if ($af.TagFile) {
                                        try { $af.TagFile.Dispose() } catch { }
                                    }
                                }
                            }
                            else {
                                Write-Warning "No audio files found to embed cover art in"
                            }
                            continue albumSelectionLoop
                        }
                        elseif ($albumChoice -match '^\d+$') {
                            $idx = [int]$albumChoice
                            if ($idx -ge 1 -and $idx -le $albumCandidates.Count) {
                                $ProviderAlbum = $albumCandidates[$idx - 1]
                                
                                # Extract artist name from album metadata (not folder name)
                                $artistNameFromAlbum = $null
                                if ($value = Get-IfExists $ProviderAlbum 'artists') {
                                    # Spotify/MusicBrainz: artists array
                                    if ($value -is [array] -and $value.Count -gt 0) {
                                        $artistNameFromAlbum = if ($value[0].name) { $value[0].name } else { $value[0].ToString() }
                                    } elseif ($value.name) {
                                        $artistNameFromAlbum = $value.name
                                    } else {
                                        $artistNameFromAlbum = $value.ToString()
                                    }
                                } elseif ($value = Get-IfExists $ProviderAlbum 'artist') {
                                    # Qobuz/Discogs: artist string
                                    $artistNameFromAlbum = $value
                                }
                                
                                # Fallback to folder name only if album has no artist metadata
                                if (-not $artistNameFromAlbum) {
                                    $artistNameFromAlbum = $quickArtist
                                    Write-Verbose "No artist in album metadata, using folder name: $artistNameFromAlbum"
                                } else {
                                    Write-Verbose "Extracted artist from album metadata: $artistNameFromAlbum"
                                }
                                
                                # For Spotify, fetch full artist details with genres instead of using simplified object
                                if ($Provider -eq 'Spotify' -and $ProviderAlbum.artists -and $ProviderAlbum.artists.Count -gt 0) {
                                    $artistId = $ProviderAlbum.artists[0].id
                                    if ($artistId) {
                                        Write-Verbose "Fetching full artist details for ID: $artistId"
                                        $ProviderArtist = Invoke-ProviderGetArtist -Provider $Provider -ArtistId $artistId
                                        if (-not $ProviderArtist) {
                                            Write-Verbose "Failed to fetch artist details, using simplified object with album artist"
                                            $ProviderArtist = @{ name = $artistNameFromAlbum; id = $artistNameFromAlbum }
                                        }
                                    }
                                    else {
                                        $ProviderArtist = @{ name = $artistNameFromAlbum; id = $artistNameFromAlbum }
                                    }
                                }
                                else {
                                    # Non-Spotify providers: use artist name from album metadata
                                    $ProviderArtist = @{ name = $artistNameFromAlbum; id = $artistNameFromAlbum }
                                }
                                
                                $script:backNavigationMode = $false  # Reset back navigation flag
                                
                                # UpdateGenresOnly mode: Skip Stage C and directly update genres
                                if ($UpdateGenresOnly) {
                                    Write-Host "`n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
                                    Write-Host "🎵 UPDATE GENRES ONLY MODE" -ForegroundColor Magenta
                                    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
                                    Write-Host ""
                                    Write-Host "Selected album: $($ProviderAlbum.name)" -ForegroundColor Green
                                    Write-Host "Genre mode: $($script:genreMode)" -ForegroundColor Yellow
                                    Write-Host ""
                                    
                                    # Get audio files in album
                                    $genreUpdateFiles = @(Get-ChildItem -LiteralPath $script:album.FullName -File -Recurse | 
                                        Where-Object { $_.Extension -match '\.(mp3|flac|wav|m4a|aac|ogg|ape)' })
                                    
                                    if ($genreUpdateFiles.Count -eq 0) {
                                        Write-Warning "No audio files found in album folder. Skipping."
                                        $albumDone = $true
                                        break albumSelectionLoop
                                    }
                                    
                                    # Extract genres from $ProviderAlbum (already fetched from search) or $ProviderArtist
                                    Write-Host "Extracting genres from $Provider..." -ForegroundColor Cyan
                                    try {
                                        $providerGenres = @()
                                        
                                        # Try album-level genres first
                                        if ($ProviderAlbum.genres) {
                                            $providerGenres = @($ProviderAlbum.genres)
                                        }
                                        # Try album genre field (Qobuz/Discogs/MusicBrainz)
                                        elseif ($ProviderAlbum.genre) {
                                            $providerGenres = @($ProviderAlbum.genre)
                                        }
                                        # Try styles field (Discogs)
                                        elseif ($ProviderAlbum.styles) {
                                            $providerGenres = @($ProviderAlbum.styles)
                                        }
                                        # Fallback to artist genres (Spotify)
                                        elseif ($ProviderArtist -and $ProviderArtist.genres) {
                                            $providerGenres = @($ProviderArtist.genres)
                                        }
                                        
                                        # Normalize to array of strings
                                        $providerGenres = @($providerGenres | Where-Object { $_ -and $_ -ne '' } | ForEach-Object { $_.ToString().Trim() })
                                        
                                        if ($providerGenres.Count -eq 0) {
                                            Write-Warning "No genres found for this album on $Provider."
                                            Write-Host "Do you want to (s)kip or (e)nter genres manually? [s]: " -NoNewline -ForegroundColor Yellow
                                            $genreChoice = Read-Host
                                            if ($genreChoice -eq 'e') {
                                                Write-Host "Enter genres (comma-separated): " -NoNewline
                                                $manualGenres = Read-Host
                                                $providerGenres = @($manualGenres -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
                                            }
                                            else {
                                                Write-Host "Skipping album (no genres to apply)." -ForegroundColor Yellow
                                                $albumDone = $true
                                                break albumSelectionLoop
                                            }
                                        }
                                        
                                        Write-Host "Provider genres: $($providerGenres -join ', ')" -ForegroundColor Green
                                        Write-Host ""
                                        
                                        # Update each file
                                        $updatedCount = 0
                                        $skippedCount = 0
                                        
                                        foreach ($audioFile in $genreUpdateFiles) {
                                            try {
                                                # Read current tags
                                                $currentTags = Get-OMTags -Path $audioFile.FullName
                                                $currentGenres = if ($currentTags.Genres) { @($currentTags.Genres) } else { @() }
                                                
                                                # Determine new genres based on GenreMode
                                                $newGenres = if ($script:genreMode -eq 'Merge') {
                                                    # Merge: combine and deduplicate
                                                    $combined = @($currentGenres) + @($providerGenres)
                                                    @($combined | Select-Object -Unique)
                                                }
                                                else {
                                                    # Replace: use provider genres only
                                                    $providerGenres
                                                }
                                                
                                                # Check if genres actually changed
                                                $genresChanged = $false
                                                if ($newGenres.Count -ne $currentGenres.Count) {
                                                    $genresChanged = $true
                                                }
                                                else {
                                                    $sortedNew = $newGenres | Sort-Object
                                                    $sortedCurrent = $currentGenres | Sort-Object
                                                    for ($i = 0; $i -lt $newGenres.Count; $i++) {
                                                        if ($sortedNew[$i] -cne $sortedCurrent[$i]) {
                                                            $genresChanged = $true
                                                            break
                                                        }
                                                    }
                                                }
                                                
                                                if ($genresChanged) {
                                                    Write-Host "  Updating: $($audioFile.Name)" -ForegroundColor Cyan
                                                    Write-Host "    Old: $($currentGenres -join ', ')" -ForegroundColor Gray
                                                    Write-Host "    New: $($newGenres -join ', ')" -ForegroundColor Green
                                                    
                                                    # Apply the genre update
                                                    Set-OMTags -Path $audioFile.FullName -Tags @{ Genres = $newGenres } -Force -WhatIf:$useWhatIf | Out-Null
                                                    $updatedCount++
                                                }
                                                else {
                                                    Write-Verbose "  Skipped (no change): $($audioFile.Name)"
                                                    $skippedCount++
                                                }
                                            }
                                            catch {
                                                Write-Warning "Failed to update genres for '$($audioFile.Name)': $_"
                                            }
                                        }
                                        
                                        Write-Host ""
                                        Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
                                        if ($useWhatIf) {
                                            Write-Host "✓ WhatIf: Would update $updatedCount file(s), skip $skippedCount file(s)" -ForegroundColor Yellow
                                        }
                                        else {
                                            Write-Host "✓ Updated $updatedCount file(s), skipped $skippedCount file(s)" -ForegroundColor Green
                                        }
                                        Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
                                        Write-Host ""
                                        
                                        # In Auto mode, automatically move to next album
                                        if ($Auto) {
                                            Write-Host "Auto mode: Moving to next album..." -ForegroundColor Yellow
                                            $albumDone = $true
                                            break albumSelectionLoop
                                        }
                                        else {
                                            Write-Host "Press Enter to continue to next album..." -ForegroundColor Cyan
                                            Read-Host
                                            $albumDone = $true
                                            break albumSelectionLoop
                                        }
                                    }
                                    catch {
                                        Write-Error "Failed to fetch or apply genres: $_"
                                        Write-Host "Press Enter to skip this album..." -ForegroundColor Yellow
                                        Read-Host
                                        $albumDone = $true
                                        break albumSelectionLoop
                                    }
                                }
                                
                                $stage = 'C'
                                continue stageLoop
                            }
                            else {
                                Write-Warning "Invalid selection"
                                continue albumSelectionLoop
                            }
                        }
                        elseif ($albumChoice -eq 'x' -or $albumChoice -eq 'xip') {
                            $albumDone = $true
                            break albumSelectionLoop
                        }
                        else {
                            # New search term - update album name and restart search
                            if ($script:backNavigationMode) {
                                Write-Host "Back navigation mode: Enter album number to select, or use commands. To search again, use 'f' to change find mode first." -ForegroundColor Yellow
                                continue albumSelectionLoop
                            }
                            else {
                                $currentAlbum = $albumChoice
                                continue stageLoop
                            }
                        }
                    }

                }
                # Check if album was skipped in quick find mode before entering stage switch
                if ($albumDone) { break }
                
                switch ($stage) {
                    
                    "A" {
                        $loadStageBResults = $true
                        if ($VerbosePreference -ne 'Continue') { Clear-Host }
                        & $showHeader -Provider $Provider -Artist $script:artist -AlbumName $script:albumName -TrackCount $script:trackCount
                        if ($script:findMode -eq 'quick') {
                            Write-Host "🔍 Find Mode: Quick Album Search" -ForegroundColor Magenta
                        }
                        else {
                            Write-Host "🔍 Find Mode: Artist-First" -ForegroundColor Magenta
                        }
                        Write-Host ""
                        
                        # Always clear candidates and perform fresh search
                        $candidates = $null
                        
                        Write-Verbose "Searching for artist: '$artistQuery' with provider: $Provider"
                        try { $r = Invoke-ProviderSearch -Provider $Provider -query $artistQuery -Type artist } catch { Write-Warning "Search failed: $_"; $r = $null }
                        $candidates = @()
                        if ($value = Get-IfExists $r.artists "items") { $candidates = $value }
                        #if ($r -and $r.artists -and $r.artists.items) { $candidates = $r.artists.items }
                        # Normalize to array and filter out null/empty values
                        $candidates = @($candidates | Where-Object { $_ -ne $null })
                        Write-Verbose "Search returned $($candidates.Count) candidates"
    
                        if (-not $candidates -or $candidates.Count -eq 0) {
                            Write-Host "No artist candidates found for '$artistQuery'."
                            if ($NonInteractive) {
                                Write-Warning "NonInteractive: skipping album because no artist candidates were found for '$artistQuery'."
                                break
                            }
                            $inputF = Read-Host "Enter new search, (ps)potify, (pq)obuz, (pd)iscogs, (pm)usicbrainz, '(x)ip' to skip album, or 'id:<id>' to select by id"
                            switch -Regex ($inputF) {
                                '^x(ip)?$' { 
                                    $albumDone = $true
                                    break stageLoop
                                    #break 
                                }
                                '^ps$' {
                                    $Provider = 'Spotify'
                                    Write-Host "Switched to provider: $Provider" -ForegroundColor Green
                                    continue stageLoop
                                }
                                '^pq$' {
                                    $Provider = 'Qobuz'
                                    Write-Host "Switched to provider: $Provider" -ForegroundColor Green
                                    continue stageLoop
                                }
                                '^pd$' {
                                    $Provider = 'Discogs'
                                    Write-Host "Switched to provider: $Provider" -ForegroundColor Green
                                    continue stageLoop
                                }
                                '^pm$' {
                                    $Provider = 'MusicBrainz'
                                    Write-Host "Switched to provider: $Provider" -ForegroundColor Green
                                    continue stageLoop
                                }
                                '^id:(.+)$' { 
                                    $id = $matches[1].Trim()
                                    if ($Provider -eq 'Discogs') { $id = & $normalizeDiscogsId $id }
                                    $ProviderArtist = @{ id = $id; name = $id }
                                    $stage = 'B'
                                    continue 
                                }
                                default {
                                    if ($inputF) { 
                                        $artistQuery = $inputF
                                        Write-Verbose "Updated artistQuery to: '$artistQuery' (from no-candidates prompt)"
                                        continue stageLoop
                                    }
                                    else { 
                                        continue stageLoop
                                    }
                                }
                            }
                        }
    
                        Write-Host "$Provider Artist candidates for '$artistQuery':" -ForegroundColor Green
                        if ($candidates.Count -eq 0) {
                            Write-Warning "No candidates returned from search (this should not happen - should have been caught above)"
                        }
                        for ($i = 0; $i -lt $candidates.Count; $i++) {
                            $nameToDisplay = Get-IfExists $candidates[$i] 'displayName'
                            if ($null -eq $nameToDisplay) {
                                $nameToDisplay = $candidates[$i].name
                            }
                            Write-Host "[$($i+1)] $nameToDisplay - $($candidates[$i].genres -join ', ') (id: $($candidates[$i].id))"
                        }
    
                        # Non-interactive selection: prefer explicit ArtistId, then goA, then AutoSelect/NonInteractive
                        if ($ArtistId) {
                            $ProviderArtist = @{ id = $ArtistId; name = $ArtistId }
                            $stage = 'B'; continue
                        }
                        if ($goA) {
                            $ProviderArtist = $candidates[0]
                            $stage = 'B'; continue
                        }
                        if ($AutoSelect -or $NonInteractive) {
                            $ProviderArtist = $candidates[0]
                            $stage = 'B'; continue
                        }

                        Write-Host "Select artist [number] (Enter=first), number, '(x)ip' album, 'id:<id>', (ps)potify, (pq)obuz, (pd)iscogs, (pm)usicbrainz, 'al:<albumName>', '(F)indmode or new search term:" -ForegroundColor Yellow -NoNewline
                        $inputF = Read-Host
                        if ($inputF -eq '') { $ProviderArtist = $candidates[0]; $stage = 'B'; continue }
                        if ($inputF -like 'id:*') { 
                            $id = $inputF.Substring(3)
                            if ($Provider -eq 'Discogs') { $id = & $normalizeDiscogsId $id }
                            $ProviderArtist = @{ id = $id; name = $id }; $stage = 'B'; continue 
                        }
                        if ($inputF -like 'al:*') {
                            $newAlbumName = $inputF.Substring(3).Trim()
                            if ($newAlbumName) {
                                $albumName = $newAlbumName
                                #$script:albumName = $newAlbumName
                                Write-Verbose "Updated albumName to: '$albumName' (from al: prompt)"
                            }
                            continue stageLoop
                        }
                        if ($inputF -match '^\d+$') { $idx = [int]$inputF; if ($idx -ge 1 -and $idx -le $candidates.Count) { $ProviderArtist = $candidates[$idx - 1]; $stage = 'B'; continue } else { Write-Warning "Invalid"; continue stageLoop } }
                        if ($inputF -eq 'x' -or $inputF -eq 'xip') { 
                            # Skip this album folder entirely
                            $albumDone = $true
                            break stageLoop
                            #   break 
                        }
                        if ($inputF -eq 'ps') {
                            $Provider = 'Spotify'
                            Write-Host "Switched to provider: $Provider" -ForegroundColor Green
                            continue stageLoop
                        }
                        if ($inputF -eq 'pq') {
                            $Provider = 'Qobuz'
                            Write-Host "Switched to provider: $Provider" -ForegroundColor Green
                            continue stageLoop
                        }
                        if ($inputF -eq 'pd') {
                            $Provider = 'Discogs'
                            Write-Host "Switched to provider: $Provider" -ForegroundColor Green
                            continue stageLoop
                        }
                        if ($inputF -eq 'pm') {
                            $Provider = 'MusicBrainz'
                            Write-Host "Switched to provider: $Provider" -ForegroundColor Green
                            continue stageLoop
                        }
                        if ($inputF -eq 'f' -or $inputF -eq 'fm') {
                            Write-Host "`nCurrent find mode: $($script:findMode)" -ForegroundColor Cyan
                            Write-Host "Available modes: (q)uick album search, (a)rtist-first search" -ForegroundColor Gray
                            $newMode = Read-Host "Select mode [q/a]"
                            if ($newMode -eq 'q' -or $newMode -eq 'quick') {
                                $script:findMode = 'quick'
                                $skipQuickPrompts = $false  # Show prompts when switching to quick mode
                                Write-Host "✓ Switched to Quick Album Search mode" -ForegroundColor Green
                            }
                            elseif ($newMode -eq 'a' -or $newMode -eq 'artist-first') {
                                $script:findMode = 'artist-first'
                                Write-Host "✓ Switched to Artist-First Search mode" -ForegroundColor Green
                                # Reset search state when switching to artist-first mode
                                $cachedAlbums = $null
                                $cachedArtistId = $null
                                $artistQuery = $artist
                                $ProviderArtist = $null
                                $ProviderAlbum = $null
                            }
                            else {
                                Write-Warning "Invalid mode: $newMode. Staying with $($script:findMode)."
                            }
                            continue stageLoop
                        }
                        $artistQuery = $inputF
                        Write-Verbose "Updated artistQuery to: '$artistQuery' (from selection prompt)"
                        continue stageLoop
                    }
    
                    "B" {
                        # Stage B: Album selection
                        
                        $stageBParams = @{
                            Provider           = $Provider
                            ProviderArtist     = $ProviderArtist
                            AlbumName          = $albumName
                            Year               = $year
                            CachedAlbums       = if ($script:findMode -eq 'quick' -and $script:quickAlbumCandidates) { $script:quickAlbumCandidates } else { $cachedAlbums }
                            CachedArtistId     = $cachedArtistId
                            NormalizeDiscogsId = $normalizeDiscogsId
                            Artist             = $artist
                            ShowHeader         = $showHeader
                            TrackCount         = $TrackCount
                            NonInteractive     = $NonInteractive
                            AutoSelect         = $AutoSelect
                            AlbumId            = $albumId
                            GoB                = $goB
                            FetchAlbums        = $loadStageBResults
                            Page               = 1
                            PerPage            = 10
                            MaxResults         = 10
                            CurrentPage        = $currentAlbumPage
                        }
                        
                        $stageBResult = Invoke-StageB-AlbumSelection @stageBParams

                        # Validate result object before accessing properties
                        if (-not $stageBResult -or $stageBResult -isnot [hashtable]) {
                            Write-Error "Stage B did not return a valid result object. Result type: $($stageBResult.GetType().FullName)"
                            $stage = 'A'
                            continue stageLoop
                        }
                                
                            
                        # Handle results
                        $cachedAlbums = $stageBResult.UpdatedCache
                        $cachedArtistId = $stageBResult.UpdatedCachedArtistId
                        $stage = $stageBResult.NextStage
                        $ProviderAlbum = $stageBResult.SelectedAlbum
                        $currentAlbumPage = $stageBResult.CurrentPage
                        
                        # Handle provider changes
                        if ($stageBResult.UpdatedProvider -and $stageBResult.UpdatedProvider -ne $Provider) {
                            $Provider = $stageBResult.UpdatedProvider
                        }
                        
                        # Handle new artist query from Stage B (if provided)
                        if ($stageBResult.ContainsKey('NewArtistQuery') -and $stageBResult.NewArtistQuery) {
                            $artistQuery = $stageBResult.NewArtistQuery
                        }
                        
                        # Handle new album name from Stage B (if provided)
                        if ($stageBResult.ContainsKey('NewAlbumName') -and $stageBResult.NewAlbumName) {
                            $albumName = $stageBResult.NewAlbumName
                            $script:albumName = $stageBResult.NewAlbumName
                            Write-Verbose "Updated albumName to: '$albumName' (from Stage B ni command)"
                            # Force re-fetch of albums with new search term
                            $loadStageBResults = $true
                        }
                        
                        # Handle skip action (break out of stage loop)
                        if ($stage -eq 'Skip') {
                            $albumDone = $true
                            break stageLoop
                            # break
                        }
                        
                        continue stageLoop
                    }
                    "C" {
                        if ($VerbosePreference -ne 'Continue') { Clear-Host }
                        & $showHeader -Provider $Provider -Artist $script:artist -AlbumName $script:albumName -TrackCount $script:trackCount
                        
                        if ($script:findMode -eq 'quick') {
                            Write-Host "🔍 Find Mode: Quick Album Search" -ForegroundColor Magenta
                        }
                        else {
                            Write-Host "🔍 Find Mode: Artist-First" -ForegroundColor Magenta
                        }
                        Write-Host ""
                        
                        if ($useWhatIf) { $HostColor = 'Cyan' } else { $HostColor = 'Red' }
                        
                        # Display appropriate header for single or combined albums
                        if (Get-IfExists $ProviderAlbum '_isCombined') {
                            Write-Host "Processing COMBINED album set:" -ForegroundColor Yellow
                            Write-Host "  Albums: $($ProviderAlbum._albumCount)" -ForegroundColor Cyan
                            Write-Host "  Tracks: $($ProviderAlbum._tracks.Count)" -ForegroundColor Cyan
                            foreach ($albumName in $ProviderAlbum._albumNames) {
                                Write-Host "    - $albumName" -ForegroundColor Gray
                            }
                            Write-Host ""
                        }
                        else {
                            Write-Host "Searching tracks for album: $($ProviderAlbum.name) (id: $($ProviderAlbum.id))"
                        }
                        
                        # If the caller asked for non-interactive behavior, do not try to drive the
                        # interactive track-selection UI. This prevents Read-Host from blocking the
                        # process in unattended runs. The caller can run interactively to inspect and
                        # approve mappings, or add a future explicit flag to auto-apply changes.
                        if ($NonInteractive) {
                            Write-Warning "NonInteractive: skipping interactive track selection for album '$($ProviderAlbum.name)'."
                            # break out of the switch AND the enclosing stage while-loop to continue with next album
                            break 2
                        }
                        # Initialize sort method (can be changed later by user)
                        # Default to 'byFilesystem' to preserve disk order (as shown in Windows Explorer #)
                        # Users can press 'o' for alphabetical order, 't' for track numbers, etc.
                        if (-not (Get-Variable -Name sortMethod -ErrorAction SilentlyContinue) -or -not $sortMethod) {
                            $sortMethod = 'byFilesystem'
                        }
                        
                        # collect audio files and tags
                        $script:audioFiles = Get-ChildItem -LiteralPath $script:album.FullName -File -Recurse | 
                            Where-Object { $_.Extension -match '\.(mp3|flac|wav|m4a|aac|ogg|ape)' }
                        
                        Write-Verbose "sortMethod = '$sortMethod'"
                        Write-Verbose "First 3 files from Get-ChildItem: $($script:audioFiles | Select-Object -First 3 | ForEach-Object { $_.Name } | Join-String -Separator ', ')"
                        
                        # Only sort if NOT using byFilesystem (which preserves disk order)
                        if ($sortMethod -ne 'byFilesystem') {
                            Write-Verbose "Applying alphabetical sort (sortMethod != 'byFilesystem')"
                            $script:audioFiles = $script:audioFiles | Sort-Object { [regex]::Replace($_.Name, '(\d+)', { $args[0].Value.PadLeft(10, '0') }) }
                        }
                        else {
                            Write-Verbose "Preserving filesystem order (sortMethod == 'byFilesystem')"
                        }
                        
                        Write-Verbose "First 3 files after conditional sort: $($script:audioFiles | Select-Object -First 3 | ForEach-Object { $_.Name } | Join-String -Separator ', ')"
                        $script:audioFiles = foreach ($f in $script:audioFiles) {
                            try {
                                $tagFile = [TagLib.File]::Create($f.FullName)
                                
                                # Try to get track number from TagLib's numeric field
                                $trackNum = $tagFile.Tag.Track
                                $discNum = $tagFile.Tag.Disc
                                
                                # If track is 0 or missing, try to extract from raw track tag text
                                # (Some files have text like "01. Suite I in G" instead of numeric 1)
                                if (-not $trackNum -or $trackNum -eq 0) {
                                    try {
                                        # For FLAC files with Vorbis comments
                                        if ($tagFile -is [TagLib.Flac.File]) {
                                            $vorbisTag = $tagFile.GetTag([TagLib.TagTypes]::Xiph)
                                            if ($vorbisTag) {
                                                $trackText = $vorbisTag.GetFirstField("TRACKNUMBER")
                                                if ($trackText -and $trackText -match '^(\d+)') {
                                                    $trackNum = [int]$matches[1]
                                                    Write-Verbose "Extracted track $trackNum from text tag '$trackText'"
                                                }
                                            }
                                        }
                                    } catch {
                                        Write-Verbose "Could not extract text-based track number: $_"
                                    }
                                }
                                
                                [PSCustomObject]@{
                                    FilePath    = $f.FullName
                                    DiscNumber  = $discNum
                                    TrackNumber = $trackNum
                                    Title       = $tagFile.Tag.Title
                                    TagFile     = $tagFile
                                    Composer    = if ($tagFile.Tag.Composers) { $tagFile.Tag.Composers -join '; ' } else { 'Unknown Composer' }
                                    Artist      = if ($tagFile.Tag.Performers) { $tagFile.Tag.Performers -join '; ' } else { 'Unknown Artist' }
                                    Name        = if ($tagFile.Tag.Title) { $tagFile.Tag.Title } else { $f.BaseName }
                                    Duration    = if ($f.Extension -eq '.ape') { Get-ApeDuration -FilePath $f.FullName } else { $tagFile.Properties.Duration.TotalMilliseconds }
                                }
                            }
                            catch {
                                Write-Warning "Skipping corrupted or invalid audio file: $($f.FullName) - Error: $($_.Exception.Message)"
                                continue
                            }
                        }
                        
                        # Check if any valid audio files were loaded
                        $validAudioFiles = @($script:audioFiles | Where-Object { $_ -ne $null })
                        if ($validAudioFiles.Count -eq 0) {
                            Write-Host "`n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Red
                            Write-Host "⚠️  ERROR: No valid audio files found!" -ForegroundColor Red
                            Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Red
                            Write-Host "`nAlbum folder: $($script:album.FullName)" -ForegroundColor Yellow
                            Write-Host "All audio files were corrupted or invalid. Skipping this album." -ForegroundColor Yellow
                            Write-Host "`nPress Enter to continue to next album..." -ForegroundColor Cyan
                            Read-Host
                            break stageLoop  # Exit stage loop to continue to next album
                        }
                        
                        # Update script:audioFiles to only contain valid files
                        $script:audioFiles = $validAudioFiles
    
                        # Check if this is a combined album (tracks already fetched) or single album (need to fetch)
                        if (Get-IfExists $ProviderAlbum '_isCombined') {
                            Write-Verbose "Using pre-fetched tracks from combined album"
                            $tracksForAlbum = $ProviderAlbum._tracks
                        }
                        else {
                            # Use album ID directly - masters should have been resolved in Stage B
                            $albumIdToFetch = $ProviderAlbum.id
                            
                            # Verbose log if this was resolved from a master
                            if (Get-IfExists $ProviderAlbum '_resolvedFromMaster') {
                                Write-Verbose "Using release $albumIdToFetch (resolved from master $($ProviderAlbum._resolvedFromMaster) in Stage B)"
                            }
                            
                            try { 
                                Write-Verbose "Calling Invoke-ProviderGetTracks for provider $Provider with ID $albumIdToFetch"
                                $rawTracks = Invoke-ProviderGetTracks -Provider $Provider -AlbumId $albumIdToFetch
                                Write-Verbose "rawTracks type: $($rawTracks.GetType().FullName)"
                                Write-Verbose "rawTracks is array: $($rawTracks -is [Array])"
                                Write-Verbose "rawTracks count: $($rawTracks.Count)"
                                
                                # Force unroll if needed
                                if ($rawTracks -is [System.Management.Automation.PSObject] -and $rawTracks.PSObject.Properties['Count']) {
                                    Write-Verbose "Detected PSObject wrapper, accessing BaseObject"
                                    $tracksForAlbum = @($rawTracks.PSObject.BaseObject)
                                } else {
                                    $tracksForAlbum = @($rawTracks)
                                }
                                
                                Write-Verbose "Received $(@($tracksForAlbum).Count) tracks"
                                
                                # Extract album metadata from tracks (needed for Qobuz when using id: or URL)
                                if ($tracksForAlbum -and @($tracksForAlbum).Count -gt 0) {
                                    Write-Verbose "About to access first track..."
                                    try {
                                        # Direct property access to avoid PSObject wrapping issues
                                        $firstTrack = $tracksForAlbum | Select-Object -First 1
                                        Write-Verbose "firstTrack type: $($firstTrack.GetType().FullName)"
                                        $hasAlbumName = Get-IfExists $firstTrack 'album_name'
                                        Write-Verbose "firstTrack has album_name: $(if ($hasAlbumName) { 'Yes' } else { 'No' })"
                                    } catch {
                                        Write-Verbose "Error accessing first track: $_"
                                        Write-Verbose "Stack: $($_.ScriptStackTrace)"
                                        throw
                                    }
                                    
                                    # Update ProviderAlbum with metadata from tracks if missing
                                    if (-not (Get-IfExists $ProviderAlbum 'name') -or $ProviderAlbum.name -eq $ProviderAlbum.id) {
                                        $albumNameFromTrack = Get-IfExists $firstTrack 'album_name'
                                        if ($albumNameFromTrack) {
                                            $ProviderAlbum.name = $albumNameFromTrack
                                            Write-Verbose "Updated album name from track metadata: $albumNameFromTrack"
                                        }
                                    }
                                    
                    if (-not (Get-IfExists $ProviderAlbum 'release_date')) {
                        $releaseDateFromTrack = Get-IfExists $firstTrack 'release_date'
                        if ($releaseDateFromTrack) {
                            # Add property if it doesn't exist, otherwise update it
                            if ($null -eq (Get-IfExists $ProviderAlbum 'release_date')) {
                                $ProviderAlbum | Add-Member -NotePropertyName 'release_date' -NotePropertyValue $releaseDateFromTrack
                            } else {
                                $ProviderAlbum.release_date = $releaseDateFromTrack
                            }
                            Write-Verbose "Updated release date from track metadata: $releaseDateFromTrack"
                        }
                    }
                                    
                                    # Also update album artist if missing (for Qobuz classical albums)
                                    if (-not (Get-IfExists $ProviderAlbum 'artist') -and -not (Get-IfExists $ProviderAlbum 'album_artist')) {
                        $albumArtistFromTrack = Get-IfExists $firstTrack 'album_artist'
                        if ($albumArtistFromTrack) {
                            # Add property if it doesn't exist, otherwise update it
                            if ($null -eq (Get-IfExists $ProviderAlbum 'album_artist')) {
                                $ProviderAlbum | Add-Member -NotePropertyName 'album_artist' -NotePropertyValue $albumArtistFromTrack
                            } else {
                                $ProviderAlbum.album_artist = $albumArtistFromTrack
                            }
                            Write-Verbose "Updated album artist from track metadata: $albumArtistFromTrack"
                        }
                    }
                                }
                                
                                if (-not $tracksForAlbum -or $tracksForAlbum.Count -eq 0) {
                                    Write-Host "`n❌ No tracks returned from $Provider for album ID: $albumIdToFetch" -ForegroundColor Red
                                    Write-Host "   This can happen if:" -ForegroundColor Yellow
                                    Write-Host "   - The album/release has no track data in the provider's database" -ForegroundColor Gray
                                    Write-Host "   - The ID is for a master release (try selecting a specific release)" -ForegroundColor Gray
                                    Write-Host "   - The resource was deleted or moved" -ForegroundColor Gray
                                    
                                    # Check if this was a master release with stored releases list
                                    $canRetryReleases = (Get-IfExists $ProviderAlbum '_masterReleases') -and $ProviderAlbum._masterReleases.Count -gt 0
                                    $backPrompt = if ($canRetryReleases) { "'b' to try different release" } else { "'b' to go back to album selection" }
                                    
                                    $skipChoice = Read-Host "`nPress Enter to skip this album, $backPrompt, or 'p' to change provider"
                                    if ($skipChoice -eq 'b') {
                                        if ($canRetryReleases) {
                                            # Show releases again for this master
                                            if ($VerbosePreference -ne 'Continue') { Clear-Host }
                                            Write-Host "📀 Discogs MASTER: $($ProviderAlbum._masterName)" -ForegroundColor Yellow
                                            Write-Host "Found $($ProviderAlbum._masterReleases.Count) releases:`n" -ForegroundColor Cyan
                                            
                                            $releases = $ProviderAlbum._masterReleases
                                            for ($i = 0; $i -lt [Math]::Min(20, $releases.Count); $i++) {
                                                $rel = $releases[$i]
                                                $country = if (Get-IfExists $rel 'country') { " [$($rel.country)]" } else { "" }
                                                $format = if (Get-IfExists $rel 'format') { " - $($rel.format)" } else { "" }
                                                $label = if (Get-IfExists $rel 'label') { " ($($rel.label))" } else { "" }
                                                Write-Host "[$($i+1)] $($rel.title)$country$format$label" -ForegroundColor Gray
                                            }
                                            
                                            if ($releases.Count -gt 20) {
                                                Write-Host "... and $($releases.Count - 20) more" -ForegroundColor DarkGray
                                            }
                                            
                                            $relInput = Read-Host "`nSelect release [1-$($releases.Count)], [0] for main_release, 'b' for album list, or Enter for #1"
                                            
                                            if ($relInput -eq 'b') {
                                                $stage = 'B'
                                                continue stageLoop
                                            }
                                            
                                            $selectedRelease = $null
                                            if ($relInput -eq '') {
                                                $selectedRelease = $releases[0]
                                            }
                                            elseif ($relInput -eq '0' -or $relInput -eq 'main') {
                                                try {
                                                    $masterDetails = Invoke-DiscogsRequest -Uri "/masters/$($ProviderAlbum._resolvedFromMaster)"
                                                    if ($masterDetails -and (Get-IfExists $masterDetails 'main_release')) {
                                                        $mainReleaseId = [string]$masterDetails.main_release
                                                        Write-Host "Using main_release: $mainReleaseId" -ForegroundColor Green
                                                        $selectedRelease = @{ id = $mainReleaseId; title = $ProviderAlbum._masterName }
                                                    }
                                                    else {
                                                        Write-Warning "Master has no main_release, using first release"
                                                        $selectedRelease = $releases[0]
                                                    }
                                                }
                                                catch {
                                                    Write-Warning "Failed to fetch main_release: $_. Using first release."
                                                    $selectedRelease = $releases[0]
                                                }
                                            }
                                            elseif ($relInput -match '^\d+$') {
                                                $idx = [int]$relInput
                                                if ($idx -ge 1 -and $idx -le $releases.Count) {
                                                    $selectedRelease = $releases[$idx - 1]
                                                }
                                                else {
                                                    Write-Warning "Invalid selection, using first release"
                                                    $selectedRelease = $releases[0]
                                                }
                                            }
                                            else {
                                                Write-Warning "Invalid input, using first release"
                                                $selectedRelease = $releases[0]
                                            }
                                            
                                            # Update the album object with new release selection
                                            Write-Host "✓ Selected release: $($selectedRelease.id) - $($selectedRelease.title)" -ForegroundColor Green
                                            $ProviderAlbum = @{
                                                id                  = [string]$selectedRelease.id
                                                name                = $selectedRelease.title
                                                type                = 'release'
                                                _resolvedFromMaster = $ProviderAlbum._resolvedFromMaster
                                                _masterReleases     = $releases
                                                _masterName         = $ProviderAlbum._masterName
                                            }
                                            # Retry fetching tracks with new release
                                            continue stageLoop
                                        }
                                        else {
                                            # No releases stored, go back to album selection
                                            $stage = 'B'
                                            continue stageLoop
                                        }
                                    }
                                    elseif ($skipChoice -eq 'p') {
                                        # Show current provider and available shortcuts
                                        $config = Get-OMConfig
                                        $defaultProvider = $config.DefaultProvider
                                        Write-Host "`nCurrent provider: $Provider (default: $defaultProvider)" -ForegroundColor Cyan
                                        Write-Host "To switch providers, use: (ps)potify, (pq)obuz, (pd)iscogs, (pm)usicbrainz" -ForegroundColor Gray
                                        continue stageLoop
                                    }
                                    else {
                                        # Skip this album
                                        break
                                    }
                                }
                            }
                            catch { 
                                Write-Warning "Get-AlbumTracks failed: $_"
                                $tracksForAlbum = @()
                                
                                # Check if this was a master release with stored releases list
                                $canRetryReleases = (Get-IfExists $ProviderAlbum '_masterReleases') -and $ProviderAlbum._masterReleases.Count -gt 0
                                $backPrompt = if ($canRetryReleases) { "'b' to try different release" } else { "'b' for album selection" }
                                
                                if ($Auto -and $script:autoModeActive) {
                                    Write-Host "⚠️  AUTO: Track fetch failed, skipping album..." -ForegroundColor Yellow
                                    $albumDone = $true
                                    break stageLoop
                                }
                                
                                $skipChoice = Read-Host "Press Enter to skip, 'r' to retry, $backPrompt, 'p' to change provider"
                                if ($skipChoice -eq 'r') {
                                    Write-Host "Retrying..." -ForegroundColor Cyan
                                    continue stageLoop
                                }
                                elseif ($skipChoice -eq 'b') {
                                    if ($canRetryReleases) {
                                        # Show releases again (same code as above)
                                        if ($VerbosePreference -ne 'Continue') { Clear-Host }
                                        Write-Host "📀 Discogs MASTER: $($ProviderAlbum._masterName)" -ForegroundColor Yellow
                                        Write-Host "Found $($ProviderAlbum._masterReleases.Count) releases:`n" -ForegroundColor Cyan
                                        
                                        $releases = $ProviderAlbum._masterReleases
                                        for ($i = 0; $i -lt [Math]::Min(20, $releases.Count); $i++) {
                                            $rel = $releases[$i]
                                            $country = if (Get-IfExists $rel 'country') { " [$($rel.country)]" } else { "" }
                                            $format = if (Get-IfExists $rel 'format') { " - $($rel.format)" } else { "" }
                                            $label = if (Get-IfExists $rel 'label') { " ($($rel.label))" } else { "" }
                                            Write-Host "[$($i+1)] $($rel.title)$country$format$label" -ForegroundColor Gray
                                        }
                                        
                                        if ($releases.Count -gt 20) {
                                            Write-Host "... and $($releases.Count - 20) more" -ForegroundColor DarkGray
                                        }
                                        
                                        $relInput = Read-Host "`nSelect release [1-$($releases.Count)], [0] for main_release, 'b' for album list, or Enter for #1"
                                        
                                        if ($relInput -eq 'b') {
                                            $stage = 'B'
                                            continue stageLoop
                                        }
                                        
                                        $selectedRelease = $null
                                        if ($relInput -eq '') {
                                            $selectedRelease = $releases[0]
                                        }
                                        elseif ($relInput -eq '0' -or $relInput -eq 'main') {
                                            try {
                                                $masterDetails = Invoke-DiscogsRequest -Uri "/masters/$($ProviderAlbum._resolvedFromMaster)"
                                                if ($masterDetails -and (Get-IfExists $masterDetails 'main_release')) {
                                                    $mainReleaseId = [string]$masterDetails.main_release
                                                    Write-Host "Using main_release: $mainReleaseId" -ForegroundColor Green
                                                    $selectedRelease = @{ id = $mainReleaseId; title = $ProviderAlbum._masterName }
                                                }
                                                else {
                                                    Write-Warning "Master has no main_release, using first release"
                                                    $selectedRelease = $releases[0]
                                                }
                                            }
                                            catch {
                                                Write-Warning "Failed to fetch main_release: $_. Using first release."
                                                $selectedRelease = $releases[0]
                                            }
                                        }
                                        elseif ($relInput -match '^\d+$') {
                                            $idx = [int]$relInput
                                            if ($idx -ge 1 -and $idx -le $releases.Count) {
                                                $selectedRelease = $releases[$idx - 1]
                                            }
                                            else {
                                                Write-Warning "Invalid selection, using first release"
                                                $selectedRelease = $releases[0]
                                            }
                                        }
                                        else {
                                            Write-Warning "Invalid input, using first release"
                                            $selectedRelease = $releases[0]
                                        }
                                        
                                        # Update the album object with new release selection
                                        Write-Host "✓ Selected release: $($selectedRelease.id) - $($selectedRelease.title)" -ForegroundColor Green
                                        $ProviderAlbum = @{
                                            id                  = [string]$selectedRelease.id
                                            name                = $selectedRelease.title
                                            type                = 'release'
                                            _resolvedFromMaster = $ProviderAlbum._resolvedFromMaster
                                            _masterReleases     = $releases
                                            _masterName         = $ProviderAlbum._masterName
                                        }
                                        # Retry fetching tracks with new release
                                        continue stageLoop
                                    }
                                    else {
                                        $stage = 'B'
                                        continue stageLoop
                                    }
                                }
                                elseif ($skipChoice -eq 'p') {
                                    # Show current provider and available shortcuts
                                    $config = Get-OMConfig
                                    $defaultProvider = $config.DefaultProvider
                                    Write-Host "`nCurrent provider: $Provider (default: $defaultProvider)" -ForegroundColor Cyan
                                    Write-Host "To switch providers, use: (ps)potify, (pq)obuz, (pd)iscogs, (pm)usicbrainz" -ForegroundColor Gray
                                    continue stageLoop
                                }
                                else {
                                    break
                                }
                            }
                        }
                        
                        # Auto-prompt for ambiguous album artist (classical music with multiple artists)
                        if (-not $NonInteractive -and -not $Auto -and $tracksForAlbum -and $tracksForAlbum.Count -gt 0) {
                            $isAmbiguous = Assert-AlbumArtistAmbiguity -Artist $ProviderArtist -Album $ProviderAlbum -Tracks $tracksForAlbum
                            if ($isAmbiguous) {
                                Write-Host "`n⚠️  This classical album has ambiguous album artist assignment." -ForegroundColor Yellow
                                # Try different property names for album artist across providers
                                $currentAlbumArtist = Get-IfExists $ProviderAlbum 'album_artist'
                                if (-not $currentAlbumArtist) { $currentAlbumArtist = Get-IfExists $ProviderAlbum 'artist' }
                                if (-not $currentAlbumArtist -and $ProviderArtist) { 
                                    # Use simple name from raw MusicBrainz object instead of disambiguated name
                                    $currentAlbumArtist = Get-IfExists $ProviderArtist '_rawMusicBrainzObject' | Get-IfExists 'name'
                                    if (-not $currentAlbumArtist) { $currentAlbumArtist = Get-IfExists $ProviderArtist 'name' }  # Fallback
                                }     
                                if ($currentAlbumArtist) {
                                    Write-Host "   Album artist from API: $currentAlbumArtist" -ForegroundColor Gray
                                }
                                Write-Host "   Multiple artists found in tracks" -ForegroundColor Gray
                                Write-Host ""
                                $response = Read-Host "Press 'a' to build custom album artist, or Enter to use automatic detection"
                                if ($response -eq 'a') {
                                    $script:ManualAlbumArtist = Invoke-AlbumArtistBuilder -AlbumName $ProviderAlbum.name -Tracks $tracksForAlbum -CurrentAlbumArtist $ProviderArtist.name
                                    if ($script:ManualAlbumArtist) {
                                        Write-Host "✓ Album artist set to: $script:ManualAlbumArtist" -ForegroundColor Green
                                    }
                                    else {
                                        Write-Host "Skipped - will use automatic detection" -ForegroundColor Gray
                                    }
                                    Write-Host ""
                                }
                            }
                        }
                        
                      
    
                        # Prefer sorting by disc/track when provider supplied disc numbers, otherwise keep name-sorting
                        # $hasDiscNumbers = $false
                        # try {
                        #     if ($tracksForAlbum -and $tracksForAlbum.Count -gt 0) {
                        #         $hasDiscNumbers = ($tracksForAlbum | Where-Object { ($_.PSObject.Properties.Match('disc_Number') -and $_.disc_Number -gt 0) -or ($_.PSObject.Properties.Match('disc_number') -and $_.disc_number -gt 0) }).Count -gt 0
                        #     }
                        # }
                        # catch { $hasDiscNumbers = $false }
                        #$sortMethod = if ($hasDiscNumbers) { 'byTrackNumber' } else { 'byOrder' }
                        $sortMethod = 'byOrder'
                        # Debug: when verbose, print the raw provider track list so users can verify
                        # that disc numbers were parsed and normalized (helps compare with test output)
                        try {
                            if ($PSBoundParameters.ContainsKey('Verbose')) {
                                Write-Verbose "Provider tracks for album: $($ProviderAlbum.name) (count: $($tracksForAlbum.Count))"
                                Write-Verbose "DEBUG: About to call Format-Table on tracksForAlbum"
                                $tracksForAlbum | Select-Object id, name, disc_number, track_number | Format-Table -AutoSize
                                Write-Verbose "DEBUG: Format-Table completed successfully"
                            }
                        }
                        catch {
                            Write-Verbose "Failed to print debug provider tracks: $($_.Exception.Message)"
                            Write-Warning "Exception in Format-Table: $($_ | Out-String)"
                        }
                        $exitdo = $false
                        $script:pairedTracks = $null
                        $script:refreshTracks = $true
                        $goCDisplayShown = $false
                        Write-Verbose "DEBUG: Starting doTracks loop, script:pairedTracks is null: $($null -eq $script:pairedTracks)"
                        :doTracks do {
                            Write-Verbose "DEBUG: Inside doTracks, checking if we need to refresh..."
                            if ($script:refreshTracks -or -not $script:pairedTracks) {
                                Write-Verbose "DEBUG: Will call Set-Tracks"
                                if ($useWhatIf) { $HostColor = 'Cyan' } else { $HostColor = 'Red' }
                                $param = @{
                                    SortMethod    = $sortMethod
                                    AudioFiles    = $script:audioFiles
                                    SpotifyTracks = $tracksForAlbum
                                }
                                if ($reverseSource) { $param.Reverse = $true }
                                $script:pairedTracks = Set-Tracks @param
                                
                                # Sort paired tracks by confidence (High → Medium → Low)
                                # This makes it easy to spot problematic matches at the bottom
                                Write-Verbose "DEBUG: About to check confidence sorting... script:pairedTracks type: $($script:pairedTracks.GetType().Name), Count: $($script:pairedTracks.Count)"
                                if ($script:pairedTracks -and $script:pairedTracks.Count -gt 0 -and $script:pairedTracks[0].PSObject.Properties['Confidence']) {
                                    $script:pairedTracks = $script:pairedTracks | Sort-Object Confidence -Descending
                                    Write-Verbose "Sorted $($script:pairedTracks.Count) tracks by confidence"
                                }
                                
                                $script:refreshTracks = $false
                                if ($sortMethod -eq 'Manual') {
                                    # Reset sort method to 'byOrder' after manual selection to prevent re-prompting on refreshes
                                    $sortMethod = 'byOrder'
                                }

                                if ($goC -and -not $goCDisplayShown) {
                                    if ($VerbosePreference -ne 'Continue') { Clear-Host }
                                    $autoReader = { param($prompt) 'q' }
                                    $autoShowParams = @{
                                        PairedTracks  = $script:pairedTracks
                                        AlbumName     = $ProviderAlbum.name
                                        SpotifyArtist = $ProviderArtist
                                        ProviderAlbum = $ProviderAlbum
                                    }
                                    if ($reverseSource) { $autoShowParams.Reverse = $true }
                                    if ($script:showVerbose) { $autoShowParams.Verbose = $true }
                                    Show-Tracks @autoShowParams -InputReader $autoReader | Out-Null
                                    $goCDisplayShown = $true
                                }
                                
                                # AUTO MODE: Smart matching with best sort strategy
                                if ($Auto -and $script:autoModeActive -and -not $goC) {
                                    Write-Host "🤖 AUTO: Analyzing track matches..." -ForegroundColor Cyan
                                    
                                    # Try different sort strategies and pick the best
                                    $strategies = @('byOrder', 'byTitle', 'byDuration')
                                    $bestStrategy = $null
                                    $bestScore = 0
                                    $bestPairing = $null
                                    
                                    foreach ($strategy in $strategies) {
                                        # Create temporary pairing with this strategy
                                        $tempParam = @{
                                            SortMethod    = $strategy
                                            AudioFiles    = $script:audioFiles
                                            SpotifyTracks = $tracksForAlbum
                                        }
                                        if ($reverseSource) { $tempParam.Reverse = $true }
                                        $tempPairing = Set-Tracks @tempParam
                                        
                                        # Count high-confidence matches
                                        $highConfCount = @($tempPairing | Where-Object { 
                                            $_.PSObject.Properties['ConfidenceLevel'] -and $_.ConfidenceLevel -eq 'High'
                                        }).Count
                                        
                                        Write-Verbose "Strategy '$strategy': $highConfCount high-confidence matches"
                                        
                                        if ($highConfCount -gt $bestScore) {
                                            $bestScore = $highConfCount
                                            $bestStrategy = $strategy
                                            $bestPairing = $tempPairing
                                        }
                                    }
                                    
                                    # Use the best pairing
                                    if ($bestPairing) {
                                        $script:pairedTracks = $bestPairing
                                        $sortMethod = $bestStrategy
                                    }
                                    
                                    # Calculate confidence percentage
                                    $totalTracks = $script:pairedTracks.Count
                                    $confidencePercent = if ($totalTracks -gt 0) { 
                                        [Math]::Round(($bestScore / $totalTracks) * 100, 0) 
                                    } else { 0 }
                                    
                                    Write-Host "🤖 AUTO: Best strategy: '$bestStrategy' ($bestScore/$totalTracks matches, $confidencePercent% confidence)" -ForegroundColor Green
                                    
                                    # Auto-proceed if confidence is high enough
                                    if ($confidencePercent -ge ($AutoConfidenceThreshold * 100)) {
                                        Write-Host "✓ AUTO: Confidence threshold met, auto-saving tags and cover..." -ForegroundColor Green
                                        
                                        # Auto-execute save-all command
                                        $inputF = 'sa'
                                        $goC = $true  # Simulate goC to trigger save-all
                                        
                                        # If AutoSaveCover is enabled, also save cover art
                                        if ($AutoSaveCover) {
                                            $coverUrl = Get-IfExists $ProviderAlbum 'cover_url'
                                            if ($coverUrl) {
                                                Write-Host "🖼️  AUTO: Saving cover art..." -ForegroundColor Cyan
                                                $config = Get-OMConfig
                                                $maxSize = $config.CoverArt.FolderImageSize
                                                $result = Save-CoverArt -CoverUrl $coverUrl -AlbumPath $script:album.FullName `\n                                                    -Action SaveToFolder -MaxSize $maxSize -WhatIf:$useWhatIf
                                                if ($result.Success) {
                                                    Write-Host "✓ AUTO: Cover art saved" -ForegroundColor Green
                                                }
                                            }
                                        }
                                    }
                                    else {
                                        Write-Warning "AUTO: Confidence too low ($confidencePercent%), falling back to interactive mode"
                                        $script:autoModeActive = $false
                                    }
                                }
                            }

                            if ($goC) {
                                Write-Host "goC: auto-applying Save-All for album '$($ProviderAlbum.name)'." -ForegroundColor Yellow
                                $inputF = 'sa'
                            }
                            elseif ($Auto -and $script:autoModeActive -and $inputF -eq 'sa') {
                                # Auto mode already set inputF to 'sa' above, proceed
                            }
                            else {
                                if ($useWhatIf) { $HostColor = 'Cyan' } else { $HostColor = 'Red' }
                                $whatIfStatus = if ($useWhatIf) { "ON" } else { "OFF" }
                                $verboseStatus = if ($script:showVerbose) { "ON" } else { "OFF" }
                                
                                # Build sort method options with active one highlighted
                                $sortOptions = @{
                                    'byOrder' = '(o)rder'
                                    'byTitle' = 'Tit(l)e'
                                    'byDuration' = '(d)uration'
                                    'byTrackNumber' = '(t)rackNumber'
                                    'byName' = '(n)ame'
                                    'Hybrid' = '(h)ybrid'
                                    'Manual' = '(m)anual'
                                    'byFilesystem' = '(f)ilesystem'
                                }
                                $sortMethodDisplay = ($sortOptions.GetEnumerator() | ForEach-Object {
                                    if ($_.Key -eq $sortMethod) { "[*$($_.Value)*]" } else { $_.Value }
                                }) -join ', '
                                
                                $genreModeStatus = $script:genreMode
                                $optionsLine = "`nOptions: SortBy $sortMethodDisplay, (r)everse | (S)ave {[A]ll, [T]ags, [F]olderNames} | {C}over {[V]iew,[O]riginal,[S]ave,saveIn[T]ags} | (aa)AlbumArtist, (gm)GenreMode:$genreModeStatus, (rm)ReviewMarked, (b)ack/(pr)evious, (P)rovider, (F)indmode, (w)hatIf:$whatIfStatus, (v)erbose:$verboseStatus, (X)ip"
                                $commandList = @('o', 'd', 't', 'n', 'l', 'h', 'm', 'r', 'rm', 'sa', 'st', 'sf', 'cv', 'cvo', 'cs', 'ct', 'aa', 'gm', 'b', 'pr', 'p', 'pq', 'ps', 'pd', 'pm', 'f', 'w', 'whatif', 'v', 'x')
                                $paramshow = @{
                                    PairedTracks  = $script:pairedTracks
                                    AlbumName     = $ProviderAlbum.name
                                    SpotifyArtist = $ProviderArtist
                                    ProviderAlbum = $ProviderAlbum
                                    OptionsText   = $optionsLine
                                    ValidCommands = $commandList
                                    PromptColor   = $HostColor
                                    ProviderName  = $Provider
                                    SortMethod    = $sortMethod
                                }
                                if ($reverseSource) { $paramshow.Reverse = $true }
                                if ($script:showVerbose) { $paramshow.Verbose = $true }
                                if ($VerbosePreference -ne 'Continue') { Clear-Host }
                                $inputF = Show-Tracks @paramshow

                                if ($null -eq $inputF) { continue }
                                if ($inputF -eq 'q') {
                                    Write-Host $optionsLine -ForegroundColor $HostColor
                                    $inputF = Read-Host "Select tracks(or option):"
                                }
                            }

                            switch -Regex ($inputF) {
                                '^o$' { $sortMethod = 'byOrder'; $script:refreshTracks = $true; continue }
                                '^d$' { $sortMethod = 'byDuration'; $script:refreshTracks = $true; continue }
                                '^t$' { $sortMethod = 'byTrackNumber'; $script:refreshTracks = $true; continue }
                                '^n$' { $sortMethod = 'byName'; $script:refreshTracks = $true; continue }
                                '^l$' { $sortMethod = 'byTitle'; $script:refreshTracks = $true; continue }
                                '^h$' { $sortMethod = 'Hybrid'; $script:refreshTracks = $true; continue }
                                '^m$' { $sortMethod = 'Manual'; $script:refreshTracks = $true; continue }
                                '^f$' { $sortMethod = 'byFilesystem'; $script:refreshTracks = $true; continue }
                                '^r$' { $ReverseSource = -not $ReverseSource; $script:refreshTracks = $true; continue }
                                '^rm$' {
                                    # Review marked tracks in Manual mode, or all tracks if none marked
                                    $markedTracks = @($script:pairedTracks | Where-Object { $_.PSObject.Properties['Marked'] -and $_.Marked })
                                    
                                    # If no marks, use all tracks with audio files
                                    $reviewAll = $false
                                    if ($markedTracks.Count -eq 0) {
                                        $reviewAll = $true
                                        $markedTracks = @($script:pairedTracks | Where-Object { $_.AudioFile })
                                        if ($markedTracks.Count -eq 0) {
                                            Write-Host "`nNo audio files to review." -ForegroundColor Yellow
                                            Start-Sleep -Seconds 2
                                            continue
                                        }
                                        Write-Host "`n📋 No marks set - reviewing ALL $($markedTracks.Count) track(s)..." -ForegroundColor Cyan
                                    }
                                    else {
                                        Write-Host "`n🔖 Reviewing $($markedTracks.Count) marked track(s)..." -ForegroundColor Cyan
                                    }
                                    Start-Sleep -Seconds 1
                                    
                                    # Build pool of provider tracks - from marked pairs if marks exist, otherwise from all provider tracks
                                    if ($reviewAll) {
                                        # Use all provider tracks for the album
                                        $providerTrackPool = @($tracksForAlbum)
                                    }
                                    else {
                                        # Use provider tracks from marked pairs only
                                        $providerTrackPool = @($markedTracks | Where-Object { $_.SpotifyTrack } | ForEach-Object { $_.SpotifyTrack })
                                    }
                                    
                                    if ($providerTrackPool.Count -eq 0) {
                                        Write-Host "No provider tracks available to choose from." -ForegroundColor Yellow
                                        Start-Sleep -Seconds 2
                                        continue
                                    }
                                    
                                    # For each marked track, show audio file and let user pick from the pool
                                    foreach ($markedTrack in $markedTracks) {
                                        if (-not $markedTrack.AudioFile) { continue }
                                        if ($providerTrackPool.Count -eq 0) {
                                            Write-Host "No more provider tracks in pool." -ForegroundColor Yellow
                                            break
                                        }
                                        
                                        if ($VerbosePreference -ne 'Continue') { Clear-Host }
                                        Write-Host "🔖 Select correct match for:" -ForegroundColor Cyan
                                        
                                        # Format audio file duration
                                        $audioDurationStr = if ($markedTrack.AudioFile.Duration) {
                                            $audioDurationSpan = [TimeSpan]::FromMilliseconds($markedTrack.AudioFile.Duration)
                                            "{0:mm\:ss}" -f $audioDurationSpan
                                        } else {
                                            "00:00"
                                        }
                                        
                                        Write-Host "   $(Split-Path -Leaf $markedTrack.AudioFile.FilePath) ($audioDurationStr)" -ForegroundColor Yellow
                                        Write-Host ""
                                        
                                        # Sort pool by match confidence for current audio file (best match first)
                                        $scoredPool = @()
                                        foreach ($track in $providerTrackPool) {
                                            $confidence = Get-MatchConfidence -ProviderTrack $track -AudioFile $markedTrack.AudioFile
                                            $scoredPool += [PSCustomObject]@{
                                                Track = $track
                                                Score = $confidence.Score
                                                Level = $confidence.Level
                                            }
                                        }
                                        $scoredPool = $scoredPool | Sort-Object Score -Descending
                                        
                                        # Show provider tracks from pool with numbers (sorted by confidence)
                                        for ($i = 0; $i -lt $scoredPool.Count; $i++) {
                                            $scored = $scoredPool[$i]
                                            $track = $scored.Track
                                            $num = $i + 1
                                            
                                            $disc = if ($value = Get-IfExists $track 'disc_number') { $value } else { 1 }
                                            $trackNum = if ($value = Get-IfExists $track 'track_number') { $value } else { 0 }
                                            $durationMs = if ($value = Get-IfExists $track 'duration_ms') { $value } elseif ($value = Get-IfExists $track 'duration') { $value } else { 0 }
                                            $durationSpan = [TimeSpan]::FromMilliseconds($durationMs)
                                            $durationStr = "{0:mm\:ss}" -f $durationSpan
                                            
                                            # Color code by confidence
                                            $color = switch ($scored.Level) {
                                                'High' { 'Green' }
                                                'Medium' { 'Yellow' }
                                                'Low' { 'Red' }
                                                default { 'Gray' }
                                            }
                                            $confidenceIndicator = " ($($scored.Score)%)"
                                            
                                            Write-Host ("[$num] {0:D2}.{1:D2}: {2} ({3}){4}" -f $disc, $trackNum, $track.name, $durationStr, $confidenceIndicator) -ForegroundColor $color
                                        }
                                        
                                        Write-Host ""
                                        $selection = Read-Host "Enter track number or press Enter for [1] (or 's' to skip)"
                                        
                                        # Default to first option if Enter pressed
                                        if ([string]::IsNullOrWhiteSpace($selection)) {
                                            $selection = "1"
                                        }
                                        
                                        if ($selection -eq 's') {
                                            Write-Host "Skipped" -ForegroundColor Gray
                                            continue
                                        }
                                        
                                        if ($selection -match '^\d+$') {
                                            $selectedIndex = [int]$selection - 1
                                            if ($selectedIndex -ge 0 -and $selectedIndex -lt $scoredPool.Count) {
                                                $selectedTrack = $scoredPool[$selectedIndex].Track
                                                
                                                # Update the paired track in main array
                                                for ($i = 0; $i -lt $script:pairedTracks.Count; $i++) {
                                                    if ($script:pairedTracks[$i].AudioFile -and 
                                                        $script:pairedTracks[$i].AudioFile.FilePath -eq $markedTrack.AudioFile.FilePath) {
                                                        $script:pairedTracks[$i].SpotifyTrack = $selectedTrack
                                                        # Only clear Marked property if it exists
                                                        if ($script:pairedTracks[$i].PSObject.Properties['Marked']) {
                                                            $script:pairedTracks[$i].Marked = $false
                                                        }
                                                        Write-Host "✓ Updated" -ForegroundColor Green
                                                        
                                                        # Remove selected track from pool
                                                        $providerTrackPool = @($providerTrackPool | Where-Object { 
                                                            $trackId = if ($_.id) { $_.id } else { $_.name }
                                                            $selectedId = if ($selectedTrack.id) { $selectedTrack.id } else { $selectedTrack.name }
                                                            $trackId -ne $selectedId
                                                        })
                                                        
                                                        Start-Sleep -Milliseconds 500
                                                        break
                                                    }
                                                }
                                            }
                                            else {
                                                Write-Host "Invalid selection" -ForegroundColor Red
                                                Start-Sleep -Seconds 1
                                            }
                                        }
                                        else {
                                            Write-Host "Invalid input" -ForegroundColor Red
                                            Start-Sleep -Seconds 1
                                        }
                                    }
                                    
                                    $finishMsg = if ($reviewAll) { "Finished reviewing all tracks" } else { "Finished reviewing marked tracks" }
                                    Write-Host "`n✓ $finishMsg" -ForegroundColor Green
                                    Start-Sleep -Seconds 1
                                    $script:refreshTracks = $true
                                    continue
                                }
                                '^gm$' {
                                    # Toggle genre mode between Replace and Merge
                                    $script:genreMode = if ($script:genreMode -eq 'Replace') { 'Merge' } else { 'Replace' }
                                    $modeColor = if ($script:genreMode -eq 'Merge') { 'Cyan' } else { 'Green' }
                                    Write-Host "`n✓ Genre Mode: $($script:genreMode)" -ForegroundColor $modeColor
                                    if ($script:genreMode -eq 'Merge') {
                                        Write-Host "   Genres will be merged with existing tags (deduplicated)" -ForegroundColor Gray
                                    } else {
                                        Write-Host "   Genres will replace existing tags" -ForegroundColor Gray
                                    }
                                    Start-Sleep -Seconds 2
                                    $script:refreshTracks = $true
                                    continue
                                }
                                '^v$' { $script:showVerbose = -not $script:showVerbose; $script:refreshTracks = $true; continue }
                                '^aa$' {
                                    # Manual album artist builder
                                    if ($tracksForAlbum -and $tracksForAlbum.Count -gt 0) {
                                        $script:ManualAlbumArtist = Invoke-AlbumArtistBuilder -AlbumName $ProviderAlbum.name -Tracks $tracksForAlbum -CurrentAlbumArtist $ProviderArtist.name
                                        if ($script:ManualAlbumArtist) {
                                            Write-Host "`n✓ Album artist set to: $script:ManualAlbumArtist" -ForegroundColor Green
                                            $script:refreshTracks = $true
                                        }
                                        else {
                                            Write-Host "`nSkipped - album artist unchanged" -ForegroundColor Gray
                                        }
                                    }
                                    else {
                                        Write-Warning "No tracks available for album artist builder"
                                    }
                                    continue
                                }
                                '^b$' { 
                                    $script:ManualAlbumArtist = $null
                                    # $AlbumId = $ProviderAlbum.id
                                    if ($script:findMode -eq 'quick') {
                                        $loadStageBResults = $false    # Use cache
                                        $script:backNavigationMode = $true  # Enable back navigation mode
                                        $stage = 'B'
                                        $exitdo = $true
                                        break
                                    }
                                    else {
                                        $loadStageBResults = $false    # Use cache and preserve page
                                        $stage = 'B'
                                        $exitdo = $true
                                        break
                                    }
                                }
                                '^pr$' { 
                                    $script:ManualAlbumArtist = $null
                                    # $AlbumId = $ProviderAlbum.id
                                    if ($script:findMode -eq 'quick') {
                                        $loadStageBResults = $false    # Use cache
                                        $stage = 'B'
                                        $exitdo = $true
                                        break
                                    }
                                    else {
                                        $loadStageBResults = $false    # Use cache and preserve page
                                        $stage = 'B'
                                        $exitdo = $true
                                        break
                                    }
                                }
                                '^p$' {
                                    # Show current provider and available shortcuts
                                    $config = Get-OMConfig
                                    $defaultProvider = $config.DefaultProvider
                                    Write-Host "`nCurrent provider: $Provider (default: $defaultProvider)" -ForegroundColor Cyan
                                    Write-Host "To switch providers, use: (ps)potify, (pq)obuz, (pd)iscogs, (pm)usicbrainz" -ForegroundColor Gray
                                    continue
                                }
                                '^f$' {
                                    # Toggle find mode between quick and artist-first
                                    if ($script:findMode -eq 'quick') {
                                        $script:findMode = 'artist-first'
                                        Write-Host "✓ Switched to Artist-First Search mode" -ForegroundColor Green
                                        # Reset search state when switching to artist-first mode
                                        $cachedAlbums = $null
                                        $cachedArtistId = $null
                                        $artistQuery = $artist
                                        $ProviderArtist = $null
                                        $ProviderAlbum = $null
                                    }
                                    else {
                                        $script:findMode = 'quick'
                                        $skipQuickPrompts = $false  # Show prompts when switching to quick mode
                                        Write-Host "✓ Switched to Quick Album Search mode" -ForegroundColor Green
                                    }
                                    $stage = 'A'
                                    $exitdo = $true
                                    break
                                }
                                '^whatif$|^w$' {
                                    $useWhatIf = -not $useWhatIf
                                    $script:refreshTracks = $true
                                    continue
                                }
                                '^x(ip)?$' { 
                                    # Skip to next album in pipeline
                                    $albumDone = $true
                                    $exitDo = $true  # Need this to break out of doTracks loop
                                    break
                                }
                                '^sf$' {
                                    $year = Get-ReleaseYear -ReleaseDate (Get-IfExists $ProviderAlbum 'release_date')
                                    $oldpath = $script:album.FullName
                                    $safeAlbumName = Approve-PathSegment -Segment (Get-IfExists $ProviderAlbum 'name') -Replacement '_' -CollapseRepeating -Transliterate
                                    
                                    # Determine artist for folder name:
                                    # Priority: 1) ManualAlbumArtist if set
                                    #          2) Read AlbumArtist from first saved audio file (ensures consistency with saved tags)
                                    #          3) Fall back to ProviderArtist.name
                                    $artistNameForFolder = $null
                                    
                                    if ($script:ManualAlbumArtist) {
                                        Write-Verbose "Using ManualAlbumArtist for folder name: $script:ManualAlbumArtist"
                                        $artistNameForFolder = $script:ManualAlbumArtist
                                    }
                                    elseif ($audioFiles -and $audioFiles.Count -gt 0) {
                                        # Read AlbumArtist from first audio file's saved tags
                                        try {
                                            $firstFile = $audioFiles[0]
                                            if ($firstFile.TagFile) {
                                                # Dispose existing handle first
                                                try { $firstFile.TagFile.Dispose() } catch { }
                                            }
                                            # Reload file to read saved tags
                                            $tempTag = [TagLib.File]::Create($firstFile.FilePath)
                                            if ($tempTag.Tag.AlbumArtists -and $tempTag.Tag.AlbumArtists.Count -gt 0) {
                                                $artistNameForFolder = $tempTag.Tag.AlbumArtists[0]
                                                Write-Verbose "Read AlbumArtist from saved tags: $artistNameForFolder"
                                            }
                                            elseif ($tempTag.Tag.FirstAlbumArtist) {
                                                $artistNameForFolder = $tempTag.Tag.FirstAlbumArtist
                                                Write-Verbose "Read FirstAlbumArtist from saved tags: $artistNameForFolder"
                                            }
                                            $tempTag.Dispose()
                                        }
                                        catch {
                                            Write-Verbose "Failed to read AlbumArtist from saved tags: $($_.Exception.Message)"
                                        }
                                    }
                                    
                                    # Priority order for artist name (same as 'sa' command):
                                    # 1. ManualAlbumArtist (already checked above) - HIGHEST PRIORITY, never override
                                    # 2. AlbumArtist from saved tags (already attempted above)
                                    # 3. ProviderAlbum.album_artist (from track metadata - most reliable)
                                    # 4. ProviderArtist.name (only if not a drive letter or folder name)
                                    # 5. Album name as last resort
                                    
                                    # Only use ProviderAlbum.album_artist if ManualAlbumArtist is not set
                                    if (-not $script:ManualAlbumArtist) {
                                        $albumArtistFromMetadata = Get-IfExists $ProviderAlbum 'album_artist'
                                        if ($albumArtistFromMetadata) {
                                            $artistNameForFolder = $albumArtistFromMetadata
                                            Write-Verbose "Using ProviderAlbum.album_artist from track metadata: $artistNameForFolder"
                                        }
                                    }
                                    
                                    # If still no artist name, check if we have a valid artistNameForFolder
                                    if (-not $artistNameForFolder -or $artistNameForFolder -match '^[A-Z]:\\?$') {
                                        # artistNameForFolder is empty or a drive letter, try ProviderArtist.name
                                        $providerArtistName = Get-IfExists $ProviderArtist 'name'
                                        if ($providerArtistName -and $providerArtistName -notmatch '^[A-Z]:\\?$') {
                                            $artistNameForFolder = $providerArtistName
                                            Write-Verbose "Using ProviderArtist.name as fallback: $artistNameForFolder"
                                        }
                                        else {
                                            # Last resort: use album name as artist
                                            $artistNameForFolder = $script:albumName
                                            Write-Verbose "No valid artist found, using album name as fallback: $artistNameForFolder"
                                        }
                                    }
                                    # else: keep existing artistNameForFolder from saved tags
                                    
                                    $safeArtistName = Approve-PathSegment -Segment $artistNameForFolder -Replacement '_' -CollapseRepeating -Transliterate
    
                                    $mvArgs = @{
                                        AlbumPath    = $oldpath
                                        NewArtist    = $safeArtistName
                                        NewYear      = $year
                                        NewAlbumName = $safeAlbumName
                                    }
                                    
                                    # Force garbage collection to release any lingering file handles before folder rename
                                    Write-Verbose "Forcing garbage collection before folder move to release file handles"
                                    [System.GC]::Collect()
                                    [System.GC]::WaitForPendingFinalizers()
                                    [System.GC]::Collect()
                                    Start-Sleep -Milliseconds 100  # Brief pause to ensure OS releases locks
                                    
                                    # call Move-AlbumFolder and pass -WhatIf from the caller (if requested)
                                    $moveResult = Invoke-MoveAlbumWithRetry -mvArgs $mvArgs -useWhatIf $useWhatIf
                                    & $handleMoveSuccess -moveResult $moveResult -useWhatIf $useWhatIf -oldpath $oldpath
                                    #& $handleMoveSuccess -moveResult $moveResult -useWhatIf $useWhatIf -oldpath $oldpath -album $album -audioFiles $audioFiles -refreshTracks $refreshTracks
                                    continue doTracks                         
                                    
                                }
                                '^st\s+(?<range>.+)$' {
                                    if (-not $script:pairedTracks -or $script:pairedTracks.Count -eq 0) {
                                        Write-Warning "No track matches available to save."
                                        continue doTracks
                                    }

                                    $rangeText = $matches['range'].Trim()
                                    if (-not $rangeText) {
                                        Write-Warning "No track numbers provided for 'st' command."
                                        continue doTracks
                                    }

                                    try {
                                        $selectedIndices = Expand-SelectionRange -RangeText $rangeText -MaxIndex $script:pairedTracks.Count
                                    }
                                    catch {
                                        Write-Warning "Invalid track selection: $($_.Exception.Message)"
                                        continue doTracks
                                    }

                                    if (-not $selectedIndices -or $selectedIndices.Count -eq 0) {
                                        Write-Warning "No valid track numbers found in selection."
                                        continue doTracks
                                    }

                                    try {
                                        $saveResult = Save-OMTrackSelection -PairedTracks $script:pairedTracks -SelectedIndices $selectedIndices -ProviderArtist $ProviderArtist -ProviderAlbum $ProviderAlbum -UseWhatIf:$useWhatIf
                                    }
                                    catch {
                                        Write-Warning "Failed to save selected tracks: $($_.Exception.Message)"
                                        continue doTracks
                                    }

                                    foreach ($info in $saveResult.SavedDetails) {
                                        $tags = $info.Tags
                                        $filePath = $info.FilePath
                                        $fileName = Split-Path -Leaf $filePath
                                        Write-Host ("Saved tags: {0} -> {1:D2}.{2:D2}: {3}" -f $fileName, $tags.Disc, $tags.Track, $tags.Title) -ForegroundColor Green
                                    }

                                    foreach ($info in $saveResult.Skipped) {
                                        $reasonText = switch ($info.Reason) {
                                            'NoAudio' { 'no matching audio file' }
                                            default { $info.Reason }
                                        }
                                        Write-Warning ("Skipping track {0}: {1}" -f $info.Index, $reasonText)
                                    }

                                    foreach ($info in $saveResult.Failed) {
                                        $reasonText = if ($info.Reason) { $info.Reason } else { 'unknown error' }
                                        Write-Warning ("Failed to save track {0}: {1}" -f $info.Index, $reasonText)
                                    }

                                    $pairedTracks = $saveResult.UpdatedPairs
                                    $audioFiles = $saveResult.UpdatedAudioFiles
                                    $tracksForAlbum = $saveResult.UpdatedSpotifyTracks

                                    if ($saveResult.SavedDetails.Count -gt 0) {
                                        Write-Host ("✓ Processed {0} track(s). Remaining: {1}" -f $saveResult.SavedDetails.Count, $script:pairedTracks.Count) -ForegroundColor Green
                                    }
                                    else {
                                        Write-Host "No tracks were updated." -ForegroundColor Yellow
                                    }

                                    $script:refreshTracks = $false
                                    continue doTracks
                                }
                                '^st$' {
                                    try {


                                        foreach ($pair in $script:pairedTracks) {
                                            if ($null -ne $pair.AudioFile) {
                                                $filePath = $pair.AudioFile.FilePath
                                                $tagsParams = @{
                                                    Artist       = $ProviderArtist
                                                    Album        = $ProviderAlbum
                                                    SpotifyTrack = $pair.SpotifyTrack
                                                }
                                                if ($script:ManualAlbumArtist) {
                                                    # Debug: Show type and value
                                                    Write-Verbose "ManualAlbumArtist type: $($script:ManualAlbumArtist.GetType().FullName)"
                                                    Write-Verbose "ManualAlbumArtist value: $($script:ManualAlbumArtist | Out-String)"
                                                    
                                                    # Ensure it's a string
                                                    $albumArtistString = if ($script:ManualAlbumArtist -is [string]) {
                                                        $script:ManualAlbumArtist
                                                    }
                                                    elseif ($script:ManualAlbumArtist -is [array]) {
                                                        $script:ManualAlbumArtist -join '; '
                                                    }
                                                    else {
                                                        $script:ManualAlbumArtist.ToString()
                                                    }
                                                    $tagsParams['ManualAlbumArtist'] = $albumArtistString
                                                }
                                                $tags = Get-Tags @tagsParams
                                                Write-Verbose ("Saving tags to: {0}" -f $filePath)
                                                Write-Verbose ("Tag values:\n{0}" -f ($tags | Out-String))
                                                $genreMerge = ($script:genreMode -eq 'Merge')
                                                $res = Save-TagsForFile -FilePath $filePath -TagValues $tags -WhatIf:$useWhatIf -GenreMergeMode:$genreMerge
                                                if ($res.Success) { 
                                                    Write-Host ("Saved tags: {0} -> {1:D2}.{2:D2}: {3}" -f (Split-Path -Leaf $filePath), $tags.Disc, $tags.Track, $tags.Title) -ForegroundColor Green 
                                                }
                                                else { 
                                                    Write-Warning ("Skipped/Failed: {0} ({1})" -f $filePath, ($res.Reason -or 'unknown')) 
                                                }
                                            }
                                            else {
                                                Write-Verbose ("Skipping track '{0}' - no matching audio file" -f $pair.SpotifyTrack.name)
                                            }
                                        }
                                       
                                        
                                        
                                        # Dispose old TagFile handles and reload to show updated tags
                                        if (-not $useWhatIf) {
                                            foreach ($af in $audioFiles) {
                                                if ($af.TagFile) {
                                                    try { $af.TagFile.Dispose() } catch { Write-Verbose "Failed disposing TagFile: $_" }
                                                    $af.TagFile = $null
                                                }
                                            }
                                            # Reload audio files with fresh TagLib handles
                                            $audioFiles = Get-ChildItem -LiteralPath $script:album.FullName -File -Recurse | 
                                                Where-Object { $_.Extension -match '\.(mp3|flac|wav|m4a|aac|ogg|ape)' } |
                                                Sort-Object { [regex]::Replace($_.Name, '(\d+)', { $args[0].Value.PadLeft(10, '0') }) }
                                            $audioFiles = foreach ($f in $audioFiles) {
                                                try {
                                                    $tagFile = [TagLib.File]::Create($f.FullName)
                                                    [PSCustomObject]@{
                                                        FilePath    = $f.FullName
                                                        DiscNumber  = $tagFile.Tag.Disc
                                                        TrackNumber = $tagFile.Tag.Track
                                                        Title       = $tagFile.Tag.Title
                                                        TagFile     = $tagFile
                                                        Composer    = if ($tagFile.Tag.Composers) { $tagFile.Tag.Composers -join '; ' } else { 'Unknown Composer' }
                                                        Artist      = if ($tagFile.Tag.Performers) { $tagFile.Tag.Performers -join '; ' } else { 'Unknown Artist' }
                                                        Name        = if ($tagFile.Tag.Title) { $tagFile.Tag.Title } else { $f.BaseName }
                                                        Duration    = if ($f.Extension -eq '.ape') { Get-ApeDuration -FilePath $f.FullName } else { $tagFile.Properties.Duration.TotalMilliseconds }
                                                    }
                                                }
                                                catch {
                                                    Write-Warning "Skipping corrupted or invalid audio file: $($f.FullName) - Error: $($_.Exception.Message)"
                                                    continue
                                                }
                                            }
                                            $script:refreshTracks = $true
                                        }
                                        # Don't exit the doTracks loop - just refresh and continue
                                        # This avoids re-entering Stage C which would re-fetch tracks from provider
                                        continue doTracks
                                    }
                                    catch {
                                        Write-Host '---- ERROR in save-tags (st) handler ----' -ForegroundColor Red
                                        Write-Host "Message: $($_.Exception.Message)"
                                        Write-Host "Exception: $($_ | Out-String)"
                                        Write-Host "ScriptStackTrace: $($_.ScriptStackTrace)"
                                        # keep UI alive; set stage to C so outer loop continues
                                        $stage = 'C'
                                        $exitDo = $true
                                        break
                                    }
                                }
                                '^sa$' {




                                    foreach ($pair in $script:pairedTracks) {
                                        # check if pair has audio and spotify track with get-ifexists
                                        if ($null -ne (Get-IfExists $pair 'AudioFile') -and $null -ne (Get-IfExists $pair 'SpotifyTrack')) {
                                            $filePath = $pair.AudioFile.FilePath
                                            $tagsParams = @{
                                                Artist       = $ProviderArtist
                                                Album        = $ProviderAlbum
                                                SpotifyTrack = $pair.SpotifyTrack
                                            }
                                            if ($script:ManualAlbumArtist) {
                                                # Debug: Show type and value
                                                Write-Verbose "ManualAlbumArtist type: $($script:ManualAlbumArtist.GetType().FullName)"
                                                Write-Verbose "ManualAlbumArtist value: $($script:ManualAlbumArtist | Out-String)"
                                                
                                                # Ensure it's a string
                                                $albumArtistString = if ($script:ManualAlbumArtist -is [string]) {
                                                    $script:ManualAlbumArtist
                                                }
                                                elseif ($script:ManualAlbumArtist -is [array]) {
                                                    $script:ManualAlbumArtist -join '; '
                                                }
                                                else {
                                                    $script:ManualAlbumArtist.ToString()
                                                }
                                                $tagsParams['ManualAlbumArtist'] = $albumArtistString
                                            }
                                            $tags = Get-Tags @tagsParams
                                            Write-Verbose ("Saving tags to: {0}" -f $filePath)
                                            Write-Verbose ("Tag values:\n{0}" -f ($tags | Out-String))
                                            $genreMerge = ($script:genreMode -eq 'Merge')
                                            $res = Save-TagsForFile -FilePath $filePath -TagValues $tags -WhatIf:$useWhatIf -GenreMergeMode:$genreMerge
                                            if ($res.Success) { 
                                                Write-Host ("Saved tags: {0} -> {1:D2}.{2:D2}: {3}" -f (Split-Path -Leaf $filePath), $tags.Disc, $tags.Track, $tags.Title) -ForegroundColor Green 
                                            }
                                            else { 
                                                Write-Warning ("Skipped/Failed: {0} ({1})" -f $filePath, ($res.Reason -or 'unknown')) 
                                            }
                                        }
                                        else {
                                            #let the user know what is missing for this pair
                                            if ($null -eq $pair.AudioFile) {
                                                Write-Verbose ("Skipping track '{0}' - no matching audio file" -f $pair.SpotifyTrack.name)
                                            }
                                            if ($null -eq $pair.SpotifyTrack) {
                                                Write-Verbose ("Skipping track '{0}' - no matching Spotify track" -f $pair.AudioFile.name)
                                            }
                                        }
                                    }
                                    


                                    # dispose any lingering TagFile handles only when actually applying changes (not in -WhatIf)
                                    if (-not $useWhatIf) {
                                        foreach ($a in $audioFiles) {
                                            #rewrite with get-ifexists
                                            if ($value = Get-IfExists $a 'TagFile') {
                                                try { $value.Dispose() } catch { Write-Verbose "Failed disposing TagFile for $($a.FilePath): $_" }
                                                $a.TagFile = $null
                                            }
                                        }
                                        # NOTE: Audio files will be reloaded AFTER the folder move (if move happens)
                                    }
                                    else {
                                        # In preview mode keep TagFile open so UI can continue to inspect tags.
                                        Write-Verbose "Preview: keeping TagFile handles open so interactive UI can display tags."
                                    }
                                    $year = Get-ReleaseYear -ReleaseDate (Get-IfExists $ProviderAlbum 'release_date')
                                    $oldpath = $script:album.FullName
                                    $safeAlbumName = Approve-PathSegment -Segment (Get-IfExists $ProviderAlbum 'name') -Replacement '_' -CollapseRepeating -Transliterate
                                    
                                    # Determine artist for folder name:
                                    # Priority: 1) ManualAlbumArtist if set
                                    #          2) Read AlbumArtist from first saved audio file (ensures consistency with saved tags)
                                    #          3) Fall back to ProviderArtist.name
                                    $artistNameForFolder = $null
                                    
                                    if ($script:ManualAlbumArtist) {
                                        Write-Verbose "Using ManualAlbumArtist for folder name: $script:ManualAlbumArtist"
                                        $artistNameForFolder = $script:ManualAlbumArtist
                                    }
                                    elseif ($audioFiles -and $audioFiles.Count -gt 0 -and -not $useWhatIf) {
                                        # Read AlbumArtist from first audio file's saved tags (only in non-WhatIf mode)
                                        try {
                                            $firstFilePath = $audioFiles[0].FilePath
                                            # Reload file to read saved tags (handles were just disposed above)
                                            $tempTag = [TagLib.File]::Create($firstFilePath)
                                            if ($tempTag.Tag.AlbumArtists -and $tempTag.Tag.AlbumArtists.Count -gt 0) {
                                                $artistNameForFolder = $tempTag.Tag.AlbumArtists[0]
                                                Write-Verbose "Read AlbumArtist from saved tags: $artistNameForFolder"
                                            }
                                            elseif ($tempTag.Tag.FirstAlbumArtist) {
                                                $artistNameForFolder = $tempTag.Tag.FirstAlbumArtist
                                                Write-Verbose "Read FirstAlbumArtist from saved tags: $artistNameForFolder"
                                            }
                                            $tempTag.Dispose()
                                        }
                                        catch {
                                            Write-Verbose "Failed to read AlbumArtist from saved tags: $($_.Exception.Message)"
                                        }
                                    }
                                    
                                    # Priority order for artist name:
                                    # 1. ManualAlbumArtist (already checked above) - HIGHEST PRIORITY, never override
                                    # 2. AlbumArtist from saved tags (already attempted above)
                                    # 3. ProviderAlbum.album_artist (from track metadata - most reliable)
                                    # 4. ProviderArtist.name (only if not a drive letter or folder name)
                                    # 5. Album name as last resort
                                    
                                    # Only use ProviderAlbum.album_artist if ManualAlbumArtist is not set
                                    if (-not $script:ManualAlbumArtist) {
                                        $albumArtistFromMetadata = Get-IfExists $ProviderAlbum 'album_artist'
                                        if ($albumArtistFromMetadata) {
                                            $artistNameForFolder = $albumArtistFromMetadata
                                            Write-Verbose "Using ProviderAlbum.album_artist from track metadata: $artistNameForFolder"
                                        }
                                    }
                                    
                                    # If still no artist name, check if we have a valid artistNameForFolder
                                    if (-not $artistNameForFolder -or $artistNameForFolder -match '^[A-Z]:\\?$') {
                                        # artistNameForFolder is empty or a drive letter, try ProviderArtist.name
                                        $providerArtistName = Get-IfExists $ProviderArtist 'name'
                                        if ($providerArtistName -and $providerArtistName -notmatch '^[A-Z]:\\?$') {
                                            $artistNameForFolder = $providerArtistName
                                            Write-Verbose "Using ProviderArtist.name as fallback: $artistNameForFolder"
                                        }
                                        else {
                                            # Last resort: use album name as artist
                                            $artistNameForFolder = $script:albumName
                                            Write-Verbose "No valid artist found, using album name as fallback: $artistNameForFolder"
                                        }
                                    }
                                    # else: keep existing artistNameForFolder from saved tags
                                    
                                    # Debug logging to file
                                    $debugLog = "C:\temp\om_debug.log"
                                    "=== ARTIST NAME DEBUG ===" | Out-File $debugLog -Append
                                    "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | Out-File $debugLog -Append
                                    "Album Path: $($script:album.FullName)" | Out-File $debugLog -Append
                                    "artistNameForFolder: [$artistNameForFolder]" | Out-File $debugLog -Append
                                    "ManualAlbumArtist: [$script:ManualAlbumArtist]" | Out-File $debugLog -Append
                                    "ProviderAlbum.album_artist: [$(Get-IfExists $ProviderAlbum 'album_artist')]" | Out-File $debugLog -Append
                                    "ProviderArtist.name: [$(Get-IfExists $ProviderArtist 'name')]" | Out-File $debugLog -Append
                                    "" | Out-File $debugLog -Append
                                    
                                    $safeArtistName = Approve-PathSegment -Segment $artistNameForFolder -Replacement '_' -CollapseRepeating -Transliterate
                                    
                                    # More debug logging
                                    "safeArtistName after Approve-PathSegment: [$safeArtistName]" | Out-File $debugLog -Append
                                    "=========================" | Out-File $debugLog -Append
                                    "" | Out-File $debugLog -Append
    
                                    $mvArgs = @{
                                        AlbumPath    = $oldpath
                                        NewArtist    = $safeArtistName
                                        NewYear      = $year
                                        NewAlbumName = $safeAlbumName
                                    }
    
                                    # Force garbage collection to release any lingering file handles before folder rename
                                    if (-not $useWhatIf) {
                                        Write-Verbose "Forcing garbage collection before folder move to release file handles"
                                        [System.GC]::Collect()
                                        [System.GC]::WaitForPendingFinalizers()
                                        [System.GC]::Collect()
                                        Start-Sleep -Milliseconds 100  # Brief pause to ensure OS releases locks
                                    }
    
                                    $moveResult = Invoke-MoveAlbumWithRetry -mvArgs $mvArgs -useWhatIf $useWhatIf
                                    #   & $handleMoveSuccess -moveResult $moveResult -useWhatIf $useWhatIf -oldpath $oldpath -album $album -audioFiles $audioFiles -refreshTracks $refreshTracks
                                    & $handleMoveSuccess -moveResult $moveResult -useWhatIf $useWhatIf -oldpath $oldpath
                                    
                                    # Reload audio files with updated tags if not in WhatIf mode and folder wasn't moved
                                    # (handleMoveSuccess reloads if folder was moved, but we need to reload even if it wasn't)
                                    if (-not $useWhatIf -and $moveResult -and $moveResult.NewAlbumPath -eq $oldpath) {
                                        Write-Verbose "Reloading audio files to reflect saved tags (folder not moved)"
                                        # Reload audio files with fresh TagLib handles
                                        $script:audioFiles = Get-ChildItem -LiteralPath $script:album.FullName -File -Recurse | 
                                            Where-Object { $_.Extension -match '\.(mp3|flac|wav|m4a|aac|ogg|ape)' } |
                                            Sort-Object { [regex]::Replace($_.Name, '(\d+)', { $args[0].Value.PadLeft(10, '0') }) }
                                        $script:audioFiles = foreach ($f in $script:audioFiles) {
                                            try {
                                                $tagFile = [TagLib.File]::Create($f.FullName)
                                                [PSCustomObject]@{
                                                    FilePath    = $f.FullName
                                                    DiscNumber  = $tagFile.Tag.Disc
                                                    TrackNumber = $tagFile.Tag.Track
                                                    Title       = $tagFile.Tag.Title
                                                    TagFile     = $tagFile
                                                    Composer    = if ($tagFile.Tag.Composers) { $tagFile.Tag.Composers -join '; ' } else { 'Unknown Composer' }
                                                    Artist      = if ($tagFile.Tag.Performers) { $tagFile.Tag.Performers -join '; ' } else { 'Unknown Artist' }
                                                    Name        = if ($tagFile.Tag.Title) { $tagFile.Tag.Title } else { $f.BaseName }
                                                    Duration    = if ($f.Extension -eq '.ape') { Get-ApeDuration -FilePath $f.FullName } else { $tagFile.Properties.Duration.TotalMilliseconds }
                                                }
                                            }
                                            catch {
                                                Write-Warning "Skipping corrupted or invalid audio file: $($f.FullName) - Error: $($_.Exception.Message)"
                                                continue
                                            }
                                        }
                                        
                                        # Update paired tracks with reloaded audio files to preserve pairing
                                        if ($script:pairedTracks -and $script:pairedTracks.Count -gt 0) {
                                            for ($i = 0; $i -lt [Math]::Min($script:pairedTracks.Count, $script:audioFiles.Count); $i++) {
                                                $script:pairedTracks[$i].AudioFile = $script:audioFiles[$i]
                                            }
                                        }
                                        $script:refreshTracks = $true
                                    }
                                    
                                    # AUTO MODE: Skip to next album after successful save
                                    if ($Auto -and $script:autoModeActive) {
                                        Write-Host "✓ AUTO: Album completed successfully, moving to next album..." -ForegroundColor Green
                                        $albumDone = $true
                                        $exitDo = $true
                                        break
                                    }
                                    
                                    continue                                   
                                    
                                }
    
                                '^(\d+(?:\.\.\d+|\-\d+)) (\+?\w+) (.+)$' {
                                    # Parse range, tag, and value from input (e.g., "1..8 +composer J.S. Bach")
                                    if ($tracksForAlbum.Count -eq 0) {
                                        Write-Warning "No tracks available for tagging"
                                        continue
                                    }
                                    if ($audioFiles.Count -eq 0) {
                                        Write-Warning "No audio files available for tagging"
                                        continue
                                    }
                                    $maxIndex = [math]::Min($tracksForAlbum.Count, $audioFiles.Count)
                                    $rangeStr = $matches[1]
                                    $tagName = $matches[2]
                                    $tagValue = $matches[3]
    
                                    # Expand range to array of 1-based indices (e.g., "1..8" -> @(1,2,3,4,5,6,7,8))
                                    $indices = @()
                                    if ($rangeStr -match '^(\d+)\.\.(\d+)$') {
                                        $start = [int]$matches[1]
                                        $end = [int]$matches[2]
                                        $end = [math]::Min($end, $maxIndex)
                                        if ($start -le $end -and $start -ge 1) {
                                            $indices = $start..$end
                                        }
                                        else {
                                            Write-Warning "Invalid range: $rangeStr (must be 1 to $maxIndex)"
                                            continue
                                        }
                                    }
                                    elseif ($rangeStr -match '^(\d+)\-(\d+)$') {
                                        $start = [int]$matches[1]
                                        $end = [int]$matches[2]
                                        $end = [math]::Min($end, $maxIndex)
                                        if ($start -le $end -and $start -ge 1) {
                                            $indices = $start..$end
                                        }
                                        else {
                                            Write-Warning "Invalid range: $rangeStr (must be 1 to $maxIndex)"
                                            continue
                                        }
                                    }
                                    elseif ($rangeStr -match '^\d+$') {
                                        $idx = [int]$rangeStr
                                        if ($idx -ge 1 -and $idx -le $maxIndex) {
                                            $indices = @($idx)
                                        }
                                        else {
                                            Write-Warning "Invalid track number: $idx (must be 1 to $maxIndex)"
                                            continue
                                        }
                                    }
                                    else {
                                        Write-Warning "Unrecognized range format: $rangeStr"
                                        continue
                                    }
    
                                    # Determine if adding (+) or replacing
                                    $isAdd = $tagName.StartsWith('+')
                                    $actualTagName = if ($isAdd) { $tagName.Substring(1) } else { $tagName }
    
                                    # Validate tag name (add more as needed; map to TagLib properties)
                                    $validTags = @('composer', 'genre', 'artist', 'albumartist', 'title')  # Expand this list
                                    if ($actualTagName -notin $validTags) {
                                        Write-Warning "Unsupported tag: $actualTagName (supported: $($validTags -join ', '))"
                                        continue
                                    }
    
                                    # Apply to each track in range
                                    foreach ($idx in $indices) {
                                        $trackIdx = $idx - 1  # 0-based for arrays
                                        $spotifyTrack = $tracksForAlbum[$trackIdx]
                                        $audioFile = $audioFiles[$trackIdx]
                                        $filePath = $audioFile.FilePath
    
                                        # Build tag update (read existing value if adding)
                                        $existingValue = $null
                                        if ($isAdd) {
                                            # Try to read current tag value from the file (if available)
                                            try {
                                                $currentTagFile = [TagLib.File]::Create($filePath)
                                                $existingValue = switch ($actualTagName) {
                                                    'composer' { $currentTagFile.Tag.Composers -join '; ' }
                                                    'genre' { $currentTagFile.Tag.Genres -join '; ' }
                                                    'artist' { $currentTagFile.Tag.Performers -join '; ' }
                                                    'albumartist' { $currentTagFile.Tag.AlbumArtists -join '; ' }
                                                    'title' { $currentTagFile.Tag.Title }
                                                    default { $null }
                                                }
                                                $currentTagFile.Dispose()
                                            }
                                            catch {
                                                Write-Verbose "Could not read existing tag for $filePath`: $_"
                                            }
                                        }
    
                                        $newValue = if ($isAdd -and $existingValue) {
                                            "$existingValue; $tagValue"  # Append with separator
                                        }
                                        else {
                                            $tagValue  # Replace or set new
                                        }
    
                                        # Map to TagLib property names
                                        $tagKey = switch ($actualTagName) {
                                            'composer' { 'Composers' }
                                            'genre' { 'Genres' }
                                            'artist' { 'Performers' }
                                            'albumartist' { 'AlbumArtists' }
                                            'title' { 'Title' }
                                            default { $actualTagName }
                                        }
    
                                        $tags = @{
                                            $tagKey = $newValue
                                        }
    
                                        # Save the tag
                                        $res = Save-TagsForFile -FilePath $filePath -TagValues $tags -WhatIf:$useWhatIf
                                        if ($res.Success) {
                                            Write-Host ("Updated tag '$actualTagName' for track $idx ($($spotifyTrack.Title)): '$newValue'") -ForegroundColor Green
                                        }
                                        else {
                                            Write-Warning ("Failed to update tag for track $($idx): $($res.Reason)")
                                        }
                                    }
    
                                    $stage = 'C'
                                    $exitDo = $true
                                    $albumDone = $true
                                    break 
                                }
                                '^pq$' {
                                    $Provider = 'Qobuz'
                                    Write-Host "Switched to provider: Qobuz" -ForegroundColor Green
                                    $cachedAlbums = $null
                                    $cachedArtistId = $null
                                    $stage = 'A'
                                    $exitdo = $true
                                    break
                                }
                                '^ps$' {
                                    $Provider = 'Spotify'
                                    Write-Host "Switched to provider: Spotify" -ForegroundColor Green
                                    $cachedAlbums = $null
                                    $cachedArtistId = $null
                                    $stage = 'A'
                                    $exitdo = $true
                                    break
                                }
                                '^pd$' {
                                    $Provider = 'Discogs'
                                    Write-Host "Switched to provider: Discogs" -ForegroundColor Green
                                    $cachedAlbums = $null
                                    $cachedArtistId = $null
                                    $stage = 'A'
                                    $exitdo = $true
                                    break
                                }
                                '^pm$' {
                                    $Provider = 'MusicBrainz'
                                    Write-Host "Switched to provider: MusicBrainz" -ForegroundColor Green
                                    $cachedAlbums = $null
                                    $cachedArtistId = $null
                                    $stage = 'A'
                                    $exitdo = $true
                                    break
                                }
                                '^cvo(\d*)$' {
                                    # View Cover art original
                                    $rangeText = $matches[1]
                                    if (-not $rangeText) { $rangeText = "1" }
                                        Write-Verbose "Stage B cvo: Show-CoverArt called with Size='original' Grid='False' Album= $($ProviderAlbum.name)"
                                        Show-CoverArt -Album $ProviderAlbum -RangeText $rangeText -Provider $Provider -Size 'original' -Grid $false
                                    Read-Host "Press Enter to continue..."
                                    continue
                                }
                                '^cv(\d*)$' {
                                    # View Cover art
                                    $rangeText = $matches[1]
                                    if (-not $rangeText) { $rangeText = "1" }
                                    Write-Verbose "Stage B cv: Show-CoverArt called with Size='original' Grid='False' Album= $($ProviderAlbum.name)"
                                    Show-CoverArt -Album $ProviderAlbum -RangeText $rangeText -Provider $Provider -Size 'original' -Grid $false -LoopLabel 'stageLoop'
                                    Read-Host "Press Enter to continue..."
                                    continue
                                }
                                '^cs(\d*)$' {
                                    # Save Cover art to folder
                                    $coverUrl = Get-IfExists $ProviderAlbum 'cover_url'
                                    
                                    if ($coverUrl) {
                                        $config = Get-OMConfig
                                        $maxSize = $config.CoverArt.FolderImageSize
                                        $result = Save-CoverArt -CoverUrl $coverUrl -AlbumPath $script:album.FullName -Action SaveToFolder -MaxSize $maxSize -WhatIf:$useWhatIf
                                        if (-not $result.Success) {
                                            Write-Warning "Failed to save cover art: $($result.Error)"
                                        }
                                    }
                                    else {
                                        Write-Warning "No cover art available for this album"
                                    }
                                    continue
                                }
                                '^ct(\d*)$' {
                                    # Save Cover art to tags
                                    $coverUrl = Get-IfExists $ProviderAlbum 'cover_url'
                                    
                                    if ($coverUrl) {
                                        $config = Get-OMConfig
                                        $maxSize = $config.CoverArt.TagImageSize
                                        # Get audio files for embedding
                                        $audioFilesForCover = Get-ChildItem -LiteralPath $script:album.FullName -File -Recurse | 
                                            Where-Object { $_.Extension -match '\.(mp3|flac|wav|m4a|aac|ogg|ape)' } |
                                            Sort-Object { [regex]::Replace($_.Name, '(\d+)', { $args[0].Value.PadLeft(10, '0') }) } | ForEach-Object {
                                            try {
                                                $tagFile = [TagLib.File]::Create($_.FullName)
                                                [PSCustomObject]@{
                                                    FilePath = $_.FullName
                                                    TagFile  = $tagFile
                                                }
                                            }
                                            catch {
                                                Write-Warning "Skipping invalid audio file: $($_.FullName)"
                                                $null
                                            }
                                        } | Where-Object { $_ -ne $null }

                                        if ($audioFilesForCover.Count -gt 0) {
                                            $result = Save-CoverArt -CoverUrl $coverUrl -AudioFiles $audioFilesForCover -Action EmbedInTags -MaxSize $maxSize -WhatIf:$useWhatIf
                                            if (-not $result.Success) {
                                                Write-Warning "Failed to embed cover art: $($result.Error)"
                                            }
                                            # Clean up tag files
                                            foreach ($af in $audioFilesForCover) {
                                                if ($af.TagFile) {
                                                    try { $af.TagFile.Dispose() } catch { }
                                                }
                                            }
                                        }
                                        else {
                                            Write-Warning "No audio files found to embed cover art in"
                                        }
                                    }
                                    else {
                                        Write-Warning "No cover art available for this album"
                                    }
                                    continue
                                }

                                default { Write-Warning "Unknown option"; continue }
                            }
                            if ($exitDo) { break }
                        } while ($true)
                    }
                }
                if ($albumDone) { break } else { continue }
            } # end foreach albums
        }
    }
    end {
        return [PSCustomObject]@{
            Path      = $Path
            Completed = $true
            WhatIf    = $useWhatIf
        }
    }
}


