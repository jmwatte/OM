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

.PARAMETER AutoWait
    When used with -Auto, falls back to interactive selection instead of skipping albums
    that couldn't be matched automatically. This lets you manually fix the search query
    (e.g. use 'ni' to correct the album name) and retry.
    Without this switch, Auto mode silently skips unmatched albums.

.PARAMETER AutoSaveCover
    When used with -Auto, automatically saves cover art to the album folder after saving tags.
    Requires Auto mode to be enabled.

.PARAMETER UpdateOnly
    Specifies which metadata fields to update from the provider. By default, all fields are updated.
    Use this to selectively update only specific metadata while preserving other existing tags.

    Valid values:
    - 'All' (default): Update all metadata fields
    - 'Genres': Only update genre tags
    - 'Year': Only update the release year
    - 'AlbumArtist': Only update the album artist field
    - 'Artists': Only update track-level performer/artist fields
    - 'TrackInfo': Only update track title, track number, and disc number
    - 'Album': Only update album name
    - 'CoverArt': Only download/update cover art (no tag changes)
    - 'Composers': Only update composer fields
    - 'MissingTracks': Only generate a JSON report of missing/extra tracks (no tags are modified)

    Multiple values can be combined: -UpdateOnly Genres,Year,CoverArt

    Note: CoverArt is handled separately from tags. When 'CoverArt' is included,
    cover art will be saved regardless of other UpdateOnly values.

.PARAMETER GenreMode
    Specifies how to handle existing genres when updating genre tags.
    Valid values:
    - 'Replace': Completely replace existing genres with provider genres (default)
    - 'Merge': Add provider genres to existing genres (keeps both, deduplicates)
    Only applies when -UpdateOnly includes 'Genres', or when saving tags in interactive mode.
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
    Start-OM -Path "C:\Music\Artist" -Auto -AutoFallback -AutoWait

    Auto-processes albums but drops into interactive mode for any album that can't be matched.
    This lets you manually fix folder-derived names (e.g. strip " (2)" suffixes) and retry.

.EXAMPLE
    Start-OM -Path "C:\Music\Artist" -UpdateOnly Genres -Provider Discogs -Auto

    Automatically update only genre tags for all albums using Discogs. Replaces existing genres with
    Discogs genres. Processes all albums in batch mode.

.EXAMPLE
    Start-OM -Path "C:\Music\Artist" -UpdateOnly Genres -GenreMode Merge -Provider Qobuz

    Interactively update genre tags, adding Qobuz genres to existing genres (keeps both).
    Allows manual album selection for each folder.

.EXAMPLE
    Start-OM -Path "C:\Music\Artist" -Auto -AutoFallback -UpdateOnly CoverArt

    Only downloads and saves cover art (cover.jpg) without modifying any audio file tags.
    Perfect for albums that already have correct tags but are missing artwork.

.EXAMPLE
    Start-OM -Path "C:\Music\Artist" -Auto -AutoFallback -UpdateOnly Genres,Year,CoverArt

    Combines multiple update targets: fetches genres and year from the provider and downloads cover art,
    while preserving existing track titles, artists, album names, and other metadata.

.EXAMPLE
    Start-OM -Path "C:\Music\Classical" -Auto -UpdateOnly Artists,Composers -Provider Qobuz

    Updates only the track-level performers and composer fields from Qobuz.
    Useful for classical music where performer credits are important but you want to keep existing metadata.

.EXAMPLE
    Start-OM -Path "C:\Music\Artist" -Auto -AutoFallback -UpdateOnly MissingTracks

    Scans all albums and writes a _errorreport.json for any album where local files don't match
    the provider's track list. No tags are modified. The JSON report contains track names, durations,
    disc/track numbers, and ISRCs to help search for the missing tracks online.

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
        [switch]$AutoWait,
        [Parameter(Mandatory = $false)]
        [switch]$AutoSaveCover,
        [Parameter(Mandatory = $false)]
        [ValidateSet('All', 'Genres', 'Year', 'AlbumArtist', 'Artists', 'TrackInfo', 'Album', 'CoverArt', 'Composers', 'MissingTracks')]
        [string[]]$UpdateOnly = @('All'),
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

        # Derive backward-compatible UpdateGenresOnly flag from UpdateOnly.
        # Skip Stage C when UpdateOnly contains only Genres and/or CoverArt (no track-level fields).
        $UpdateGenresOnly = ($UpdateOnly -notcontains 'All') -and
            ($UpdateOnly -contains 'Genres') -and
            -not ($UpdateOnly | Where-Object { $_ -notin @('Genres', 'CoverArt') })

        # Derive MissingTracks-only flag: skip all tagging, only produce mismatch JSON report.
        $UpdateMissingTracksOnly = ($UpdateOnly -contains 'MissingTracks') -and
            -not ($UpdateOnly | Where-Object { $_ -notin @('MissingTracks') })

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
        # Cache config once — no Set-OMConfig calls exist in Start-OM, so it never changes during execution
        $config = Get-OMConfig

        # If Provider was not explicitly specified, use DefaultProvider from config
        if (-not $PSBoundParameters.ContainsKey('Provider')) {
            if ($config.DefaultProvider) {
                $Provider = $config.DefaultProvider
                Write-Verbose "Using DefaultProvider from config: $Provider"
            }
        }
        
        # Remember the resolved provider so we can reset it at the start of each album
        $originalProvider = $Provider

        # Cache Qobuz locale early to avoid repeated config calls during header display
        $qobuzUrlLocale = $null
        if ($Provider -eq 'Qobuz' -or $config.DefaultProvider -eq 'Qobuz') {
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
            
            return $id
        }
        
        # Helper: delegates header rendering to Private Show-OMHeader
        $showHeader = {
            param(
                [string]$Provider,
                [string]$Artist,
                [string]$AlbumName,
                [int]$TrackCount = 0
            )
            Show-OMHeader -Provider $Provider -Artist $Artist -AlbumName $AlbumName -TrackCount $TrackCount -QobuzUrlLocale $qobuzUrlLocale -ScriptAlbum $script:album
        }
        # Replaced inline Get-StringSimilarity with centralized helper in Private/Utils/Get-StringSimilarity.ps1
        # See: Private/Utils/Get-StringSimilarity.ps1
        
        
        # Replaced inline Get-AlbumMatchConfidence with centralized helper in Private/Utils/Get-AlbumMatchConfidence.ps1
        # See: Private/Utils/Get-AlbumMatchConfidence.ps1
        
        
        # Replaced inline Get-BestAutoMatch with centralized helper in Private/Utils/Get-BestAutoMatch.ps1
        # See: Private/Utils/Get-BestAutoMatch.ps1
        
        
        # Delegate provider fallback behavior to centralized helper in Private/Utils
        # Implementation moved to: Private/Utils/Invoke-ProviderWithFallback.ps1
        # The function is expected to be available via module import (no inline implementation here).
        
        $script:album = $null
        
        # Handle single album path: extract artist from parent folder
        if ($script:isSingleAlbumPath) {
            $parentPath = Split-Path -Parent $Path
            if ($parentPath -and $parentPath -notmatch '^[A-Z]:\\?$') {
                # Normal case: parent is a valid artist folder name
                $script:artist = Undo-PathSanitization -Name (Split-Path -Leaf $parentPath)
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
            $script:artist = Undo-PathSanitization -Name (Split-Path -Leaf $Path)
            $artist = $script:artist
            $albums = @(Get-ChildItem -LiteralPath $Path -Directory)
            Write-Verbose "Artist folder mode: Processing $($albums.Count) album folders under artist '$artist'"
        }
        
        # Initialize WhatIf mode early
        $useWhatIf = $isWhatIf
        $script:findMode = 'artist-first'  # Default to artist-first mode
        $currentAlbumPage = 1
        
        foreach ($albumOriginal in $albums) {
            # Reset provider to the original value so mid-album switches don't carry over
            $Provider = $originalProvider

            $script:album = $albumOriginal
            $script:ManualAlbumArtist = $null
            # Initialize script-scope variables used by handleMoveSuccess scriptblock
            $script:audioFiles = $null
            $script:pairedTracks = $null
            $script:refreshTracks = $false

            # Context object: explicit shared state passed to workflow functions
            # Replaces implicit $script: variable access for testability
            $script:ctx = @{
                Album              = $albumOriginal
                AudioFiles         = $null
                PairedTracks       = $null
                RefreshTracks      = $false
                TargetFolderMoved  = $false
                IsSingleAlbumPath  = $script:isSingleAlbumPath
                FindMode           = $script:findMode
                ShowVerbose        = $script:showVerbose
                GenreMode          = $script:genreMode
                ManualAlbumArtist  = $null
                AutoModeActive     = $false
                BackNavigationMode = $false
            }
            # derive album name and year
            # Try to extract year from the start of the folder name (e.g., "2023 - Album Name")
            if ($script:album.Name -match '^(\d{4})\s*[-]?\s*(.+)') {
                $year = $matches[1]
                $albumName = Undo-PathSanitization -Name $matches[2].Trim()
                $script:albumName = $albumName
            }
            else {
                $year = $null
                $script:albumName = Undo-PathSanitization -Name $script:album.Name.Trim()
                $albumName = $script:albumName
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
            $script:ctx.FindMode = 'quick'
            $script:quickAlbumCandidates = $null
            $script:quickCurrentPage = 1
            $script:backNavigationMode = $false
            $script:ctx.BackNavigationMode = $false
            $currentArtist = $script:artist  # Persistent current artist for quick find mode
            $currentAlbum = $script:albumName  # Persistent current album for quick find mode
            $skipQuickPrompts = $false  # Flag to skip prompts when re-entering quick find after provider change
            $sortMethod = $null  # Track sort method for Stage C (initialized on first entry)

            :stageLoop while ($true) {
                # Check if album is done FIRST before any other processing
                if ($albumDone) {
                    Write-Verbose "DEBUG: albumDone=true, breaking out of stageLoop"
                    break
                }
                
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
                        
                        # Extract album name (strip year if present) — unified regex with main loop
                        if ($folderName -match '^(\d{4})\s*[-]?\s*(.+)') {
                            $detectedAlbum = Undo-PathSanitization -Name $matches[2].Trim()
                        }
                        else {
                            $detectedAlbum = Undo-PathSanitization -Name $folderName
                        }
                        
                        # Use parent folder as artist (clean sanitization artifacts for search)
                        $detectedArtist = Undo-PathSanitization -Name $artistFolderName
                        
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
                                try {
                                    $tagArtist = if ($tagFile.Tag.FirstAlbumArtist) { $tagFile.Tag.FirstAlbumArtist } else { $null }
                                }
                                finally {
                                    $tagFile.Dispose()
                                }
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
                                $retryChoice = Read-Host "`nPress Enter to retry, (ps)potify, (pq)obuz, (pd)iscogs, (pm)usicbrainz, '(a)' artist-first mode, (ni) New Item (enter new artist+album), (x) skip album, (?) help, or enter new album name"
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
                                elseif ($retryChoice -eq '?') {
                                    Show-OMHelp -Context 'QuickFind-Retry'
                                    continue quickSearchLoop
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
                        if (-not $albumCandidates) { $albumCandidates = @() }
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
                                $fallbackCandidates = @()
                                
                                try {
                                    $fallbackResults = Invoke-ProviderSearch -Provider $fallbackProvider -Album $quickAlbum -Artist $quickArtist -Type album
                                    if ($fallbackResults) {
                                        $fbAlbums = Get-IfExists $fallbackResults 'albums'
                                        if ($fbAlbums) {
                                            $fbItems = Get-IfExists $fbAlbums 'items'
                                            if ($fbItems) {
                                                $fallbackCandidates = @($fbItems | Where-Object { $_ -ne $null })
                                            }
                                        }
                                    }
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

                                $genreResult = Update-OMGenresFromProvider -SelectedAlbum $ProviderAlbum -ProviderArtist $ProviderArtist `
                                    -AlbumPath $script:album.FullName -GenreMode $script:genreMode -UseWhatIf:$useWhatIf
                                
                                if (-not $genreResult.Success -and $genreResult.Total -eq 0) {
                                    Write-Warning "No audio files found. Skipping."
                                }

                                # Save cover art if requested via UpdateOnly
                                if ($UpdateOnly -contains 'CoverArt') {
                                    $coverUrl = Get-IfExists $ProviderAlbum 'cover_url'
                                    Write-Host "🖼️  Saving cover art..." -ForegroundColor Cyan
                                    $config = Get-OMConfig
                                    $maxSize = $config.CoverArt.FolderImageSize
                                    Save-CoverArtWithFallback -CoverUrl $coverUrl -AlbumPath $script:album.FullName `
                                        -MaxSize $maxSize -Provider $Provider `
                                        -AlbumName $quickAlbum -ArtistName $quickArtist `
                                        -AutoFallback:$AutoFallback -UseWhatIf:$useWhatIf
                                }

                                $albumDone = $true
                                continue stageLoop
                            }
                            
                            $stage = 'C'
                            $script:autoModeActive = $true
                            continue stageLoop
                        }
                        else {
                            if ($AutoWait) {
                                Write-Warning "AUTO: No high-confidence match found. Falling back to interactive selection."
                                $script:autoModeActive = $false
                                # Fall through to albumSelectionLoop so user can fix search and retry
                            }
                            else {
                                Write-Warning "AUTO: No high-confidence match found across all providers. Skipping album."
                                $script:autoModeActive = $false
                                $albumDone = $true
                                continue stageLoop
                            }
                        }
                    }

                    # Album selection for quick mode
                    $ProviderArtist = @{ name = $quickArtist; id = $quickArtist }  # Simplified artist object
                    if (-not $albumCandidates) { $albumCandidates = @() }

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
                        $albumChoice = Read-Host "Select album [number] (Enter=first), (b)ack, (p)rovider, (f)indMode, (ni) New Item, (x)ip, cover: cv/cvo/cs/ct, (?) help, or new search term$modeIndicator"
                        [Console]::ForegroundColor = $originalColor
                        if ($albumChoice -eq '') { $albumChoice = '1' }
                        
                        if ($albumChoice -eq '?') {
                            Show-OMHelp -Context 'QuickFind-Select'
                            continue albumSelectionLoop
                        }
                        elseif ($albumChoice -eq 'p') {
                            # Show current provider and available shortcuts
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
                        elseif ($albumChoice -eq 'b') {
                            # Go back to re-enter artist/album search terms
                            $skipQuickPrompts = $false
                            $script:backNavigationMode = $false
                            $script:quickAlbumCandidates = $null
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
                        elseif ($albumChoice -eq 'c') {
                            # User typed just 'c' — show cover art subcommand help
                            Write-Host "Cover art commands: cv[N] = view, cvo[N] = view original, cs[N] = save to folder, ct[N] = save to tags (N = album number, default 1)" -ForegroundColor Cyan
                            continue albumSelectionLoop
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
                            $maxSize = $config.CoverArt.TagImageSize
                            foreach ($index in $selectedIndices) {
                                $albumIndex = $index - 1
                                $selectedAlbum = $albumCandidates[$albumIndex]
                                if ($selectedAlbum.cover_url) {
                                    $result = Invoke-OMCoverArtEmbed -AlbumPath $script:album.FullName -CoverUrl $selectedAlbum.cover_url -MaxSize $maxSize -UseWhatIf:$useWhatIf
                                    if ($null -ne $result -and -not $result.Success) {
                                        Write-Warning "Failed to embed cover art for album $index ($($selectedAlbum.name)): $($result.Error)"
                                    }
                                }
                                else {
                                    Write-Warning "No cover art available for album $index ($($selectedAlbum.name))"
                                }
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
                                    
                                    $genreResult = Update-OMGenresFromProvider -SelectedAlbum $ProviderAlbum -ProviderArtist $ProviderArtist `
                                        -AlbumPath $script:album.FullName -GenreMode $script:genreMode -UseWhatIf:$useWhatIf
                                    
                                    if (-not $genreResult.Success -and $genreResult.Genres.Count -eq 0 -and $genreResult.Total -gt 0) {
                                        # No genres found - offer manual entry (interactive only)
                                        Write-Host "Do you want to (s)kip or (e)nter genres manually? [s]: " -NoNewline -ForegroundColor Yellow
                                        $genreChoice = Read-Host
                                        if ($genreChoice -eq 'e') {
                                            Write-Host "Enter genres (comma-separated): " -NoNewline
                                            $manualGenres = Read-Host
                                            $manualGenreArray = @($manualGenres -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
                                            if ($manualGenreArray.Count -gt 0) {
                                                # Create a temporary album object with the manual genres
                                                $manualAlbum = @{ genres = $manualGenreArray }
                                                $genreResult = Update-OMGenresFromProvider -SelectedAlbum $manualAlbum `
                                                    -AlbumPath $script:album.FullName -GenreMode $script:genreMode -UseWhatIf:$useWhatIf
                                            }
                                        } else {
                                            Write-Host "Skipping album (no genres to apply)." -ForegroundColor Yellow
                                            $albumDone = $true
                                            break albumSelectionLoop
                                        }
                                    }

                                    # Save cover art if requested via UpdateOnly
                                    if ($UpdateOnly -contains 'CoverArt') {
                                        $coverUrl = Get-IfExists $ProviderAlbum 'cover_url'
                                        Write-Host "🖼️  Saving cover art..." -ForegroundColor Cyan
                                        $config = Get-OMConfig
                                        $maxSize = $config.CoverArt.FolderImageSize
                                        Save-CoverArtWithFallback -CoverUrl $coverUrl -AlbumPath $script:album.FullName `
                                            -MaxSize $maxSize -Provider $Provider `
                                            -AlbumName $quickAlbum -ArtistName $quickArtist `
                                            -AutoFallback:$AutoFallback -UseWhatIf:$useWhatIf
                                    }

                                    if ($Auto) {
                                        Write-Host "Auto mode: Moving to next album..." -ForegroundColor Yellow
                                    } else {
                                        Write-Host "Press Enter to continue to next album..." -ForegroundColor Cyan
                                        Read-Host
                                    }
                                    $albumDone = $true
                                    break albumSelectionLoop
                                }
                                
                                # Only proceed to Stage C if not in UpdateGenresOnly mode
                                # (UpdateGenresOnly sets $albumDone and breaks albumSelectionLoop above)
                                if (-not $UpdateGenresOnly) {
                                    $stage = 'C'
                                    continue stageLoop
                                }
                                # else: let $albumDone check handle it
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
                            $currentAlbum = $albumChoice
                            $skipQuickPrompts = $true
                            $script:backNavigationMode = $false
                            $script:quickAlbumCandidates = $null
                            continue stageLoop
                        }
                    }

                }
                # Check if album was skipped in quick find mode before entering stage switch
                if ($albumDone) { break }
                
                switch ($stage) {
                    
                    "A" {
                        # --- Stage A: Artist Selection (extracted to Invoke-StageA-ArtistSelection) ---
                        $stageAParams = @{
                            Provider           = $Provider
                            ArtistQuery        = $artistQuery
                            Artist             = $artist
                            AlbumName          = $albumName
                            ArtistId           = $albumId  # reused for explicit artist ID
                            NonInteractive     = $NonInteractive
                            AutoSelect         = $AutoSelect
                            GoA                = $goA
                            ShowHeader         = $showHeader
                            NormalizeDiscogsId = $normalizeDiscogsId
                            Context            = $script:ctx
                        }

                        $stageAResult = Invoke-StageA-ArtistSelection @stageAParams

                        if (-not $stageAResult -or $stageAResult -isnot [hashtable]) {
                            Write-Error "Stage A did not return a valid result."
                            continue stageLoop
                        }

                        # Unpack results
                        $Provider = $stageAResult.Provider
                        $loadStageBResults = $true

                        if ($stageAResult.ProviderArtist) {
                            $ProviderArtist = $stageAResult.ProviderArtist
                        }
                        if ($stageAResult.ArtistQuery -ne $artistQuery) {
                            $artistQuery = $stageAResult.ArtistQuery
                            Write-Verbose "Updated artistQuery to: '$artistQuery' (from Stage A)"
                        }
                        if ($stageAResult.AlbumName -ne $albumName) {
                            $albumName = $stageAResult.AlbumName
                            Write-Verbose "Updated albumName to: '$albumName' (from Stage A al: command)"
                        }
                        # Handle cache clears (sentinel: $null means cleared, $false means unchanged)
                        if ($stageAResult.CachedAlbums -eq $null -and $stageAResult.CachedAlbums -isnot [bool]) {
                            $cachedAlbums = $null
                        }
                        if ($stageAResult.CachedArtistId -eq $null -and $stageAResult.CachedArtistId -isnot [bool]) {
                            $cachedArtistId = $null
                        }
                        if ($stageAResult.SkipQuickPrompts -ne $false -or $stageAResult.ContainsKey('SkipQuickPrompts')) {
                            $skipQuickPrompts = $stageAResult.SkipQuickPrompts
                        }

                        $nextStage = $stageAResult.NextStage
                        switch ($nextStage) {
                            'AlbumDone' {
                                $albumDone = $true
                                break stageLoop
                            }
                            'B' {
                                $stage = 'B'
                                continue stageLoop
                            }
                            default {
                                # Stay in A (re-search)
                                $stage = 'A'
                                continue stageLoop
                            }
                        }
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
                            UpdateGenresOnly   = $UpdateGenresOnly
                            UpdateOnly         = $UpdateOnly
                            GenreMode          = $script:genreMode
                            UseWhatIf          = $useWhatIf
                            Context            = $script:ctx
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
                        
                        # Handle AlbumDone status (UpdateGenresOnly/UpdateOnly completed in Stage B)
                        if ($stage -eq 'AlbumDone') {
                            # Save cover art if requested via UpdateOnly
                            if ($UpdateOnly -contains 'CoverArt' -and $ProviderAlbum) {
                                $coverUrl = Get-IfExists $ProviderAlbum 'cover_url'
                                Write-Host "🖼️  Saving cover art..." -ForegroundColor Cyan
                                $config = Get-OMConfig
                                $maxSize = $config.CoverArt.FolderImageSize
                                Save-CoverArtWithFallback -CoverUrl $coverUrl -AlbumPath $script:album.FullName `
                                    -MaxSize $maxSize -Provider $Provider `
                                    -AlbumName $quickAlbum -ArtistName $quickArtist `
                                    -AutoFallback:$AutoFallback -UseWhatIf:$useWhatIf
                            }
                            $albumDone = $true
                            break stageLoop
                        }
                        
                        continue stageLoop
                    }
                    "C" {
                        # --- Stage C: Track Selection (extracted to Invoke-StageC-TrackSelection) ---
                        $stageCParams = @{
                            Provider                = $Provider
                            ProviderAlbum           = $ProviderAlbum
                            ProviderArtist          = $ProviderArtist
                            NonInteractive          = $NonInteractive
                            Auto                    = $Auto
                            AutoConfidenceThreshold = $AutoConfidenceThreshold
                            AutoSaveCover           = $AutoSaveCover
                            AutoFallback            = $AutoFallback
                            ReverseSource           = $ReverseSource
                            TargetFolder            = $TargetFolder
                            UpdateOnly              = $UpdateOnly
                            UpdateMissingTracksOnly = $UpdateMissingTracksOnly
                            GoC                     = $goC
                            UseWhatIf               = $useWhatIf
                            ShowHeader              = $showHeader
                            Config                  = $config
                            QuickArtist             = $quickArtist
                            QuickAlbum              = $quickAlbum
                            Artist                  = $artist
                            SortMethod              = $sortMethod
                            Context                 = $script:ctx
                        }

                        $stageCResult = Invoke-StageC-TrackSelection @stageCParams

                        # Validate result
                        if (-not $stageCResult -or $stageCResult -isnot [hashtable]) {
                            Write-Error "Stage C did not return a valid result. Type: $(if ($stageCResult) { $stageCResult.GetType().FullName } else { 'null' })"
                            $stage = 'B'
                            continue stageLoop
                        }

                        # Unpack results
                        $Provider = $stageCResult.Provider
                        $ProviderAlbum = $stageCResult.ProviderAlbum
                        $useWhatIf = $stageCResult.UseWhatIf
                        $ReverseSource = $stageCResult.ReverseSource
                        $sortMethod = $stageCResult.SortMethod

                        # Handle cache updates
                        if ($stageCResult.ContainsKey('CachedAlbums') -and $null -eq $stageCResult.CachedAlbums) {
                            $cachedAlbums = $null
                        }
                        if ($stageCResult.ContainsKey('CachedArtistId') -and $null -eq $stageCResult.CachedArtistId) {
                            $cachedArtistId = $null
                        }

                        # Handle stage navigation
                        if ($stageCResult.ContainsKey('SkipQuickPrompts')) {
                            $skipQuickPrompts = $stageCResult.SkipQuickPrompts
                        }
                        if ($stageCResult.ContainsKey('LoadStageBResults')) {
                            $loadStageBResults = $stageCResult.LoadStageBResults
                        }

                        $nextStage = $stageCResult.NextStage
                        switch ($nextStage) {
                            'AlbumDone' {
                                $albumDone = $true
                                break stageLoop
                            }
                            'A' {
                                $stage = 'A'
                                continue stageLoop
                            }
                            'B' {
                                $stage = 'B'
                                continue stageLoop
                            }
                            'C' {
                                $stage = 'C'
                                continue stageLoop
                            }
                            default {
                                Write-Warning "Unexpected NextStage from Stage C: $nextStage"
                                $stage = 'B'
                                continue stageLoop
                            }
                        }
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

