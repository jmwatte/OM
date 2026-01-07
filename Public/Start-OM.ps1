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

        [Parameter(Mandatory = $false)][object]$Context

    )

    begin {
        $taglibloaded = Assert-TagLibLoaded -ThrowOnError 
        if (-not $taglibloaded) {
            Install-TagLibSharp | Out-Null
        }
        # ensure TagLib is present for this function (Install-TagLibSharp should make TagLib available)
        Set-StrictMode -Version Latest
        $ErrorActionPreference = 'Stop'

        Write-Verbose "Start-OM: begin (diagnostics)"
        Write-Verbose ("PSBoundParameters: {0}" -f ($PSBoundParameters.Keys -join ','))
        Write-Verbose ("Path value: '{0}' (Length: {1})" -f $Path, ($Path -ne $null ? $Path.Length : '<null>'))

        # detect whether the user passed -WhatIf to this function (comes from CmdletBinding)
        $isWhatIf = $PSBoundParameters.ContainsKey('WhatIf')

        # Debug trap: capture ParameterBindingExceptions and dump call stack + bound params
        trap [System.Management.Automation.ParameterBindingException] {
            Write-Error "Start-OM: ParameterBindingException caught: $($_.Exception.Message)"
            Dump-ExceptionDiagnostics -ErrorRecord $_ -ContextMsg "ParameterBindingException trap"
            Write-Output "Path: $Path"
            throw
        }

        # Debug trap: capture InvalidOperationException (e.g., collection modified during enumeration)
        trap [System.InvalidOperationException] {
            Write-Error "Start-OM: InvalidOperationException caught: $($_.Exception.Message)"
            Dump-ExceptionDiagnostics -ErrorRecord $_ -ContextMsg "InvalidOperationException trap"
            Write-Output "Path: $Path"
            throw
        }

        # Send-Message: robust wrapper around Show-Message to avoid missing-function errors in nested scopes
        function Send-Message {
            param(
                [Parameter(Mandatory=$true)][string]$Message,
                [string]$Color = 'Cyan'
            )
            if (Get-Command -Name Show-Message -ErrorAction SilentlyContinue) {
                Show-Message -Message $Message -ForegroundColor $Color -Context $Context
            } else {
                Write-Verbose "Send-Message fallback: $Message"
                Write-Output $Message
            }
        }

        # Initialize verbose display toggle if it doesn't exist
        # Note: These are synced to $State after creation via Sync-OMScriptToState
        if (-not (Get-Variable -Name showVerbose -Scope Script -ErrorAction SilentlyContinue)) {
            $showVerbose = $false
            $genreMode = 'Replace'  # 'Replace' or 'Merge'
        }

        if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
            throw "Path not found or not a directory: $Path"
        }

        # Initialize central state object (Phase 3.1 - complete)
        # Replaced all $script: scoped variables with explicit $State properties
        $State = New-OMState -Path $Path -Provider $Provider -Context $Context

        # Detect path type: single album folder (has audio files) vs artist folder (has album subfolders)
        Write-Verbose "Start-OM: enumerating files in $Path"
        $audioFilesInPath = @(Get-OMAudioFile -Path $Path -ReturnPathsOnly -SortMethod alphabetical -ErrorAction SilentlyContinue)
        $subFoldersInPath = @(Get-ChildItem -LiteralPath $Path -Directory -ErrorAction SilentlyContinue)
        Write-Verbose "Start-OM: enumerated $($audioFilesInPath.Count) audio files and $($subFoldersInPath.Count) subfolders"
        
        # Single album mode: Path has audio files and either no subfolders or all subfolders are disc folders
        $State.IsSingleAlbumPath = $false
        # Note: State.OriginalPath is already set by New-OMState
        
        if ($audioFilesInPath.Count -gt 0) {
            # Check if subfolders contain audio files
            $subFoldersWithAudio = @($subFoldersInPath | Where-Object {
                $subAudioFiles = @(Get-OMAudioFile -Path $_.FullName -ReturnPathsOnly -SortMethod alphabetical -ErrorAction SilentlyContinue)
                $subAudioFiles.Count -gt 0
            })
            
            if ($subFoldersWithAudio.Count -eq 0) {
                # No subfolders with audio → single album (flat structure)
                $State.IsSingleAlbumPath = $true
                Write-Verbose "Detected single album path: $Path (contains $($audioFilesInPath.Count) audio files)"
            }
            else {
                # Subfolders with audio exist - check if they're ALL disc folders
                Write-Verbose ("TRACE: Building nonDiscFolders: subFoldersWithAudio.Count=$($subFoldersWithAudio.Count)")
                $nonDiscFolders = @($subFoldersWithAudio | Where-Object { -not (Assert-DiscFolder -FolderName $_.Name) })
                
                if ($nonDiscFolders.Count -eq 0) {
                    # ALL subfolders with audio are disc folders → single multi-disc album
                    $State.IsSingleAlbumPath = $true
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

        # Sync path detection results to State object
        Sync-OMScriptToState -State $State

        # Ensure required external module Spotishell is present in the session
        if (-not (Get-Module -Name Spotishell)) {
            try { Import-Module Spotishell -ErrorAction Stop } catch { Write-Warning "Spotishell module not loaded: $_"; throw }
        }

        # Convert the switch into the debug-friendly object used by the helpers (optional)
        #   $whatIfObj = New-Object PSObject -Property @{ IsPresent = $isWhatIf }
    }

    # ... (begin block unchanged)
    
    process { try {
        # Diagnostic: record Start-OM invocation top-level parameters
        try { "$(Get-Date -Format o) | Start-OM invoked Path=$Path Auto=$Auto AutoFallback=$AutoFallback NonInteractive=$NonInteractive Provider=$Provider" | Out-File -FilePath (Join-Path $env:TEMP 'start_om_invocation_log.txt') -Append -Encoding utf8 -Force } catch { }

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
        
        # Helper function to show consistent header across all stages
        $showHeader = {
            param(
                [string]$Provider,
                [string]$Artist,
                [string]$AlbumName,
                [int]$TrackCount = 0
            )

                # Delegate to the centralized Show-OMHeader helper (one canonical header)
                try {
                    Show-OMHeader -Provider $Provider -Artist $Artist -AlbumName $AlbumName -TrackCount $TrackCount -QobuzUrlLocale $qobuzUrlLocale -ScriptAlbum $State.Album -Context $Context
                } catch {
                    Write-Verbose "showHeader: Show-OMHeader invocation failed: $($_.Exception.Message)"
                }
        }
        # handleMoveSuccess is now Invoke-OMHandleMoveSuccess function in Private/Utils
        
        $State.Album = $null
        
        # Handle single album path: extract artist from parent folder
        if ($State.IsSingleAlbumPath) {
            $parentPath = Split-Path -Parent $Path
            if ($parentPath -and $parentPath -notmatch '^[A-Z]:\\?$') {
                # Normal case: parent is a valid artist folder name
                $State.Artist = Split-Path -Leaf $parentPath
                $artist = $State.Artist
                Write-Verbose "Single album mode: Extracted artist '$artist' from parent folder"
            }
            else {
                # Root-level album folder - use album folder name as placeholder artist
                # This will be overridden by ProviderAlbum.album_artist during "sa" command
                $albumFolderName = Split-Path -Leaf $Path
                $State.Artist = $albumFolderName
                $artist = $State.Artist
                Write-Verbose "Single album mode: Root-level album detected at drive root, using album folder name '$artist' as temporary artist (will be updated from metadata)"
            }
            
            # Process only the target album folder
            $albums = @(Get-Item -LiteralPath $Path)
            Write-Verbose "Single album mode: Processing only album folder '$($albums[0].Name)'"
        }
        else {
            # Original behavior: Path is artist folder containing album subfolders
            $State.Artist = Split-Path -Leaf $Path
            $artist = Split-Path -Leaf $Path
            $albums = @(Get-ChildItem -LiteralPath $Path -Directory)
            Write-Verbose "Artist folder mode: Processing $($albums.Count) album folders under artist '$artist'"
        }
        
        # Initialize WhatIf mode early
        $useWhatIf = $isWhatIf
        $State.FindMode = 'artist-first'  # Default to artist-first mode
        $State.AutoModeActive = $false    # Will be set to $true if Auto mode finds a match
        $currentAlbumPage = 1
        
        foreach ($albumOriginal in @($albums)) {
            $State.Album = $albumOriginal
            Write-Verbose "TRACE: Start processing album: $($State.Album.FullName)"
            $State.ManualAlbumArtist = $null
            # Initialize State properties
            $State.AudioFiles = $null
            $State.PairedTracks = $null
            $State.RefreshTracks = $false
            
            # derive album name and year
            # Try to extract year from the start of the folder name (e.g., "2023 - Album Name")
            if ($State.Album.Name -match '^(\d{4})\s*[-]?\s*(.+)') {
                $year = $matches[1]
                $albumName = $matches[2].Trim()
                $State.AlbumName = $matches[2].Trim()
            }
            else {
                $year = $null
                $State.AlbumName = $State.Album.Name.Trim()
                $albumName = $State.Album.Name.Trim()

            }
            $audioFilesCheck = @(Get-OMAudioFile -Path $State.Album.FullName -ReturnPathsOnly -SortMethod alphabetical)
            if (-not $audioFilesCheck -or $audioFilesCheck.Count -eq 0) {
                Write-Warning "No supported audio files found in album folder: $($State.Album.FullName). Skipping album."
                continue
            }
            $State.TrackCount = $audioFilesCheck.Count
            $artistQuery = $artist
            $stage = "A"
            $cachedAlbums = $null
            $cachedArtistId = $null
            $loadStageBResults = $true 
            # Pagination fields (unused right now) removed to avoid analyzer warnings
            $albumDone = $false
            # For single album mode, always start in quick mode (faster, higher accuracy)
            # User can toggle to artist-first with 'F' command, and it will persist for this album
            # But we reset to quick for each new album because that's the most efficient default
            $State.FindMode = 'quick'
            $State.QuickAlbumCandidates = $null
            $State.QuickCurrentPage = 1
            $State.BackNavigationMode = $false
            $currentArtist = $State.Artist  # Persistent current artist for quick find mode
            $currentAlbum = $State.AlbumName  # Persistent current album for quick find mode
            $skipQuickPrompts = $false  # Flag to skip prompts when re-entering quick find after provider change

            # Sync State to script scope for legacy code
            Sync-OMStateToScript -State $State

            :stageLoop while ($true) {
                # Sync State at start of each stage loop iteration
                Sync-OMScriptToState -State $State
                
                # NEW: Handle quick find mode (only when not in track selection stage)
                if ($State.FindMode -eq 'quick' -and $stage -ne 'C') {
                    $quickFindParams = @{
                        State                    = $State
                        Provider                 = $Provider
                        ShowHeader               = $showHeader
                        SkipQuickPrompts         = $skipQuickPrompts
                        CurrentArtist            = $currentArtist
                        CurrentAlbum             = $currentAlbum
                        Auto                     = $Auto
                        AutoFallback             = $AutoFallback
                        AutoConfidenceThreshold  = $AutoConfidenceThreshold
                        NonInteractive           = $NonInteractive
                        UseWhatIf                = $useWhatIf
                        Context                  = $Context
                    }
                    
                    $quickFindResult = Invoke-OMQuickFind @quickFindParams
                    
                    # Handle result
                    switch ($quickFindResult.Action) {
                        'Selected' {
                            $ProviderArtist = $quickFindResult.ProviderArtist
                            $ProviderAlbum = $quickFindResult.ProviderAlbum
                            $Provider = $quickFindResult.Provider
                            $State.AutoModeActive = $quickFindResult.AutoModeActive
                            $State.QuickAlbumCandidates = $quickFindResult.AlbumCandidates
                            $State.BackNavigationMode = $quickFindResult.BackNavigationMode
                            $stage = $quickFindResult.NextStage
                            continue stageLoop
                        }
                        'SwitchMode' {
                            $State.FindMode = $quickFindResult.FindMode
                            $State.BackNavigationMode = $quickFindResult.BackNavigationMode
                            $stage = $quickFindResult.NextStage
                            continue stageLoop
                        }
                        'Skip' {
                            $albumDone = $true
                            break
                        }
                        'ProviderSwitch' {
                            $Provider = $quickFindResult.Provider
                            $skipQuickPrompts = $quickFindResult.SkipQuickPrompts
                            $State.BackNavigationMode = $quickFindResult.BackNavigationMode
                            continue stageLoop
                        }
                        'Continue' {
                            $currentArtist = $quickFindResult.CurrentArtist
                            $currentAlbum = $quickFindResult.CurrentAlbum
                            $skipQuickPrompts = $quickFindResult.SkipQuickPrompts
                            $State.BackNavigationMode = $quickFindResult.BackNavigationMode
                            continue stageLoop
                        }
                    }
                }
                # Check if album was skipped in quick find mode before entering stage switch
                if ($albumDone) { break }
                
                switch ($stage) {
                    
                    "A" {
                        # Stage A: Artist selection
                        $loadStageBResults = $true
                        
                        $stageAParams = @{
                            Provider       = $Provider
                            ArtistQuery    = $artistQuery
                            ArtistId       = $ArtistId
                            FindMode       = $State.FindMode
                            ShowHeader     = $showHeader
                            Artist         = $State.Artist
                            AlbumName      = $State.AlbumName
                            TrackCount     = $State.TrackCount
                            NonInteractive = $NonInteractive
                            AutoSelect     = $AutoSelect
                            GoA            = $goA
                            Context        = $Context
                        }
                        
                        $stageAResult = Invoke-StageA-ArtistSelection @stageAParams
                        
                        # Validate result object
                        if (-not $stageAResult -or $stageAResult -isnot [hashtable]) {
                            Write-Error "Stage A did not return a valid result object. Result type: $($stageAResult.GetType().FullName)"
                            continue stageLoop
                        }
                        
                        # Handle results
                        $stage = $stageAResult.NextStage
                        $ProviderArtist = $stageAResult.SelectedArtist
                        
                        # Handle provider changes
                        if ($stageAResult.UpdatedProvider -and $stageAResult.UpdatedProvider -ne $Provider) {
                            $Provider = $stageAResult.UpdatedProvider
                        }
                        
                        # Handle artist query changes
                        if ($stageAResult.UpdatedArtistQuery) {
                            $artistQuery = $stageAResult.UpdatedArtistQuery
                            Write-Verbose "Updated artistQuery to: '$artistQuery' (from Stage A)"
                        }
                        
                        # Handle album name changes (al: command)
                        if ($stageAResult.UpdatedAlbumName) {
                            $albumName = $stageAResult.UpdatedAlbumName
                            Write-Verbose "Updated albumName to: '$albumName' (from Stage A al: command)"
                        }
                        
                        # Handle find mode changes
                        if ($stageAResult.UpdatedFindMode) {
                            $State.FindMode = $stageAResult.UpdatedFindMode
                            if ($stageAResult.ContainsKey('SkipQuickPrompts')) {
                                $skipQuickPrompts = $stageAResult.SkipQuickPrompts
                            }
                            # Reset search state when switching to artist-first mode
                            if ($stageAResult.UpdatedFindMode -eq 'artist-first') {
                                $cachedAlbums = $null
                                $cachedArtistId = $null
                                $artistQuery = $artist
                                $ProviderArtist = $null
                                $ProviderAlbum = $null
                            }
                        }
                        
                        # Handle skip action (break out of stage loop)
                        if ($stage -eq 'Skip') {
                            $albumDone = $true
                            break stageLoop
                        }
                        
                        continue stageLoop
                    }
    
                    "B" {
                        # Stage B: Album selection
                        
                        $stageBParams = @{
                            Provider           = $Provider
                            ProviderArtist     = $ProviderArtist
                            AlbumName          = $albumName
                            Year               = $year
                            CachedAlbums       = if ($State.FindMode -eq 'quick' -and $State.QuickAlbumCandidates) { $State.QuickAlbumCandidates } else { $cachedAlbums }
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
                            $State.AlbumName = $stageBResult.NewAlbumName
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
                        if (-not ($showHeader -is [scriptblock])) { Dump-ExceptionDiagnostics -ErrorRecord (New-Object System.Management.Automation.ErrorRecord (New-Object System.Exception("showHeader is not a scriptblock (value: '$showHeader')")), 'InvalidTarget', 'InvalidOperation', $showHeader) ; throw "showHeader invalid" }
                        Write-Verbose ("TRACE: showHeader args: Provider=$Provider; Artist=$($State.Artist); AlbumName=$($State.AlbumName); TrackCount=$($State.TrackCount)")
                        Invoke-SafeScriptBlock -Block { & $showHeader -Provider $Provider -Artist $State.Artist -AlbumName $State.AlbumName -TrackCount $State.TrackCount } -ContextMsg 'showHeader invocation'
                        
                        if ($State.FindMode -eq 'quick') {
                            Show-Message -Message "🔍 Find Mode: Quick Album Search" -ForegroundColor Magenta -Context $Context
                        }
                        else {
                            Show-Message -Message "🔍 Find Mode: Artist-First" -ForegroundColor Magenta -Context $Context
                        }
                        Show-Message -Message "" -Context $Context
                        
                        if ($useWhatIf) { $HostColor = 'Cyan' } else { $HostColor = 'Red' }
                        
                        # Display appropriate header for single or combined albums
                        if (Get-IfExists $ProviderAlbum '_isCombined') {
                            Show-Message -Message "Processing COMBINED album set:" -ForegroundColor Yellow -Context $Context
                            Show-Message -Message "  Albums: $($ProviderAlbum._albumCount)" -ForegroundColor Cyan -Context $Context
                            Show-Message -Message "  Tracks: $($ProviderAlbum._tracks.Count)" -ForegroundColor Cyan -Context $Context
                            foreach ($albumName in @($ProviderAlbum._albumNames)) {
                                Show-Message -Message "    - $albumName" -ForegroundColor Gray -Context $Context
                            }
                            Show-Message -Message "" -Context $Context
                        }
                        else {
                            Show-Message -Message "Searching tracks for album: $($ProviderAlbum.name) (id: $($ProviderAlbum.id))" -Context $Context
                        }
                        
                        # If the caller asked for non-interactive behavior, do not try to drive the
                        # interactive track-selection UI. This prevents Read-Host from blocking the
                        # process in unattended runs. The caller can run interactively to inspect and
                        # approve mappings, or add a future explicit flag to auto-apply changes.
                        if ($NonInteractive) {
                            Write-Warning "NonInteractive: skipping interactive track selection for album '$($ProviderAlbum.name)'."
                            # break out of the switch AND the enclosing stage while-loop to continue with next album
                            break stageLoop
                        }
                        # Initialize sort method (can be changed later by user)
                        # Default to 'byFilesystem' to preserve disk order (as shown in Windows Explorer #)
                        # Users can press 'o' for alphabetical order, 't' for track numbers, etc.
                        if (-not (Get-Variable -Name sortMethod -ErrorAction SilentlyContinue) -or -not $sortMethod) {
                            $sortMethod = 'byFilesystem'
                        }
                        
                        # collect audio files and tags
                        Write-Verbose "sortMethod = '$sortMethod'"
                        $skipSort = $sortMethod -eq 'byFilesystem'
                        $State.AudioFiles = Reload-OMAudioFiles -AlbumPath $State.Album.FullName -SkipSort:$skipSort
                        $afCount = if ($null -eq $State.AudioFiles) { 0 } elseif ($State.AudioFiles -is [array]) { $State.AudioFiles.Count } else { 1 }
                        Write-Verbose "Loaded $afCount audio files (SkipSort: $skipSort)"
                        
                        # Check if any valid audio files were loaded
                        $validAudioFiles = @($State.AudioFiles | Where-Object { $_ -ne $null })
                        if ($validAudioFiles.Count -eq 0) {
                            Show-Message -Message "`n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Red -Context $Context
                            Show-Message -Message "⚠️  ERROR: No valid audio files found!" -ForegroundColor Red -Context $Context
                            Show-Message -Message "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Red -Context $Context
                            Show-Message -Message "`nAlbum folder: $($State.Album.FullName)" -ForegroundColor Yellow -Context $Context
                            Show-Message -Message "All audio files were corrupted or invalid. Skipping this album." -ForegroundColor Yellow -Context $Context
                            if (-not $NonInteractive) {
                                Prompt-PressEnter -Context $Context
                            }
                            break stageLoop  # Exit stage loop to continue to next album
                        }
                        
                        # Update State.AudioFiles to only contain valid files
                        $State.AudioFiles = $validAudioFiles
    
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
                                Write-Verbose "TRACE: Before Invoke-ProviderGetTracks (Provider=$Provider, AlbumId=$albumIdToFetch)"
                                Write-Verbose "Calling Invoke-ProviderGetTracks for provider $Provider with ID $albumIdToFetch"
                                $rawTracks = Invoke-ProviderGetTracks -Provider $Provider -AlbumId $albumIdToFetch
                                $rawType = if ($null -eq $rawTracks) { 'null' } else { $rawTracks.GetType().FullName }
                                $rawIsArray = $rawTracks -is [Array]
                                $rawCount = if ($null -eq $rawTracks) { 0 } elseif ($rawTracks -is [array]) { $rawTracks.Count } else { 1 }
                                Write-Verbose "rawTracks type: $rawType"
                                Write-Verbose "rawTracks is array: $rawIsArray"
                                Write-Verbose "rawTracks count: $rawCount"
                                
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
                                    Show-Message -Message "`n❌ No tracks returned from $Provider for album ID: $albumIdToFetch" -ForegroundColor Red -Context $Context
                                    Show-Message -Message "   This can happen if:" -ForegroundColor Yellow -Context $Context
                                    Show-Message -Message "   - The album/release has no track data in the provider's database" -ForegroundColor Gray -Context $Context
                                    Show-Message -Message "   - The ID is for a master release (try selecting a specific release)" -ForegroundColor Gray -Context $Context
                                    Show-Message -Message "   - The resource was deleted or moved" -ForegroundColor Gray -Context $Context
                                    
                                    # Check if this was a master release with stored releases list
                                    $canRetryReleases = (Get-IfExists $ProviderAlbum '_masterReleases') -and $ProviderAlbum._masterReleases.Count -gt 0
                                    $backPrompt = if ($canRetryReleases) { "'b' to try different release" } else { "'b' to go back to album selection" }
                                    
                                    $skipChoice = Show-OMPrompt -Prompt "Press Enter to skip this album, $backPrompt, or 'p' to change provider" -Context $Context
                                    if ($skipChoice -eq 'b') {
                                        if ($canRetryReleases) {
                                            # Use helper function to select release
                                            $releaseResult = Select-DiscogsMasterRelease `
                                                -MasterName $ProviderAlbum._masterName `
                                                -MasterId $ProviderAlbum._resolvedFromMaster `
                                                -Releases $ProviderAlbum._masterReleases `
                                                -Context $Context
                                            
                                            if ($releaseResult.Action -eq 'Back') {
                                                $stage = 'B'
                                                continue stageLoop
                                            }
                                            elseif ($releaseResult.Action -eq 'Selected') {
                                                $ProviderAlbum = $releaseResult.ProviderAlbum
                                                continue stageLoop
                                            }
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
                                        Show-Message -Message "`nCurrent provider: $Provider (default: $defaultProvider)" -ForegroundColor Cyan -Context $Context
                                        Show-Message -Message "To switch providers, use: (ps)potify, (pq)obuz, (pd)iscogs, (pm)usicbrainz" -ForegroundColor Gray -Context $Context
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
                                
                                if ($Auto -and $State.AutoModeActive) {
                                    Show-Message -Message "⚠️  AUTO: Track fetch failed, skipping album..." -ForegroundColor Yellow -Context $Context
                                    $albumDone = $true
                                    break stageLoop
                                }
                                
                                $skipChoice = Show-OMPrompt -Prompt "Press Enter to skip, 'r' to retry, $backPrompt, 'p' to change provider" -Context $Context
                                if ($skipChoice -eq 'r') {
                                    Show-Message -Message "Retrying..." -ForegroundColor Cyan -Context $Context
                                    continue stageLoop
                                }
                                elseif ($skipChoice -eq 'b') {
                                    if ($canRetryReleases) {
                                        # Use helper function to select release
                                        $releaseResult = Select-DiscogsMasterRelease `
                                            -MasterName $ProviderAlbum._masterName `
                                            -MasterId $ProviderAlbum._resolvedFromMaster `
                                            -Releases $ProviderAlbum._masterReleases `
                                            -Context $Context
                                        
                                        if ($releaseResult.Action -eq 'Back') {
                                            $stage = 'B'
                                            continue stageLoop
                                        }
                                        elseif ($releaseResult.Action -eq 'Selected') {
                                            $ProviderAlbum = $releaseResult.ProviderAlbum
                                            continue stageLoop
                                        }
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
                                    Show-Message -Message "`nCurrent provider: $Provider (default: $defaultProvider)" -ForegroundColor Cyan -Context $Context
                                    Show-Message -Message "To switch providers, use: (ps)potify, (pq)obuz, (pd)iscogs, (pm)usicbrainz" -ForegroundColor Gray -Context $Context
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
                                Show-Message -Message "`n⚠️  This classical album has ambiguous album artist assignment." -ForegroundColor Yellow -Context $Context
                                # Try different property names for album artist across providers
                                $currentAlbumArtist = Get-IfExists $ProviderAlbum 'album_artist'
                                if (-not $currentAlbumArtist) { $currentAlbumArtist = Get-IfExists $ProviderAlbum 'artist' }
                                if (-not $currentAlbumArtist -and $ProviderArtist) { 
                                    # Use simple name from raw MusicBrainz object instead of disambiguated name
                                    $currentAlbumArtist = Get-IfExists $ProviderArtist '_rawMusicBrainzObject' | Get-IfExists 'name'
                                    if (-not $currentAlbumArtist) { $currentAlbumArtist = Get-IfExists $ProviderArtist 'name' }  # Fallback
                                }     
                                if ($currentAlbumArtist) {
                                    Show-Message -Message "   Album artist from API: $currentAlbumArtist" -ForegroundColor Gray -Context $Context
                                }
                                Show-Message -Message "   Multiple artists found in tracks" -ForegroundColor Gray -Context $Context
                                Show-Message -Message "" -Context $Context
                                $response = Show-OMPrompt -Prompt "Press 'a' to build custom album artist, or Enter to use automatic detection" -Context $Context
                                if ($response -eq 'a') {
                                    $State.ManualAlbumArtist = Invoke-AlbumArtistBuilder -AlbumName $ProviderAlbum.name -Tracks $tracksForAlbum -CurrentAlbumArtist $ProviderArtist.name
                                    if ($State.ManualAlbumArtist) {
                                        Show-Message -Message "✓ Album artist set to: $($State.ManualAlbumArtist)" -ForegroundColor Green -Context $Context
                                    }
                                    else {
                                        Show-Message -Message "Skipped - will use automatic detection" -ForegroundColor Gray -Context $Context
                                    }
                                    Show-Message -Message "" -Context $Context
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
                        $State.PairedTracks = $null
                        $State.RefreshTracks = $true
                        $goCDisplayShown = $false
                        Write-Verbose "DEBUG: Starting doTracks loop, State.PairedTracks is null: $($null -eq $State.PairedTracks)"
                        :doTracks do {
                            Sync-OMScriptToState -State $State  # Sync at start of track matching loop
                            Write-Verbose "DEBUG: Inside doTracks, checking if we need to refresh..."
                            if ($State.RefreshTracks -or -not $State.PairedTracks) {
                                Write-Verbose "DEBUG: Will call Set-Tracks"
                                Write-Verbose "DEBUG: State.AudioFiles type: $(if ($State.AudioFiles) { $State.AudioFiles.GetType().Name } else { 'NULL' }), count: $(if ($State.AudioFiles) { $State.AudioFiles.Count } else { 0 })"
                                if ($useWhatIf) { $HostColor = 'Cyan' } else { $HostColor = 'Red' }
                                $param = @{
                                    SortMethod    = $sortMethod
                                    AudioFiles    = @($State.AudioFiles)
                                    SpotifyTracks = @($tracksForAlbum)
                                }
                                if ($reverseSource) { $param.Reverse = $true }
                                $State.PairedTracks = Set-Tracks @param
                                
                                # Sort paired tracks by confidence (High → Medium → Low)
                                # Use stable sort to preserve original order when confidence is equal
                                # This ensures matched tracks stay in position even when all have same confidence
                                $ptType = if ($null -eq $State.PairedTracks) { 'null' } else { $State.PairedTracks.GetType().Name }
                                $ptCount = if ($null -eq $State.PairedTracks) { 0 } elseif ($State.PairedTracks -is [array]) { $State.PairedTracks.Count } else { 1 }
                                Write-Verbose "DEBUG: About to check confidence sorting... State.PairedTracks type: $ptType, Count: $ptCount"
                                if ($State.PairedTracks -and $ptCount -gt 0 -and $State.PairedTracks[0].PSObject.Properties['Confidence']) {
                                    # Add index for stable sort, then sort by confidence (desc) and original index
                                    $indexedTracks = for ($i = 0; $i -lt $State.PairedTracks.Count; $i++) {
                                        $State.PairedTracks[$i] | Add-Member -NotePropertyName '_OriginalIndex' -NotePropertyValue $i -PassThru
                                    }
                                    $State.PairedTracks = @($indexedTracks | Sort-Object @{Expression='Confidence'; Descending=$true}, @{Expression='_OriginalIndex'; Descending=$false})
                                    # Remove the temporary index property
                                    foreach ($track in $State.PairedTracks) {
                                        $track.PSObject.Properties.Remove('_OriginalIndex')
                                    }
                                    Write-Verbose "Sorted $($State.PairedTracks.Count) tracks by confidence (stable)"
                                }
                                
                                $State.RefreshTracks = $false
                                if ($sortMethod -eq 'Manual') {
                                    # Reset sort method to 'byOrder' after manual selection to prevent re-prompting on refreshes
                                    $sortMethod = 'byOrder'
                                }

                                if ($goC -and -not $goCDisplayShown) {
                                    if ($VerbosePreference -ne 'Continue') { Clear-Host }
                                    $autoReader = { param($prompt) 'q' }
                                    $autoShowParams = @{
                                        PairedTracks  = $State.PairedTracks
                                        AlbumName     = $ProviderAlbum.name
                                        SpotifyArtist = $ProviderArtist
                                        ProviderAlbum = $ProviderAlbum
                                    }
                                    if ($reverseSource) { $autoShowParams.Reverse = $true }
                                    if ($State.ShowVerbose) { $autoShowParams.Verbose = $true }
                                    Write-Verbose "TRACE: Before Show-Tracks (auto path) - InputReader present: $([bool]$autoReader)"
                                    Show-Tracks @autoShowParams -InputReader $autoReader | Out-Null
                                    $goCDisplayShown = $true
                                }
                                
                                # AUTO MODE: Smart matching with best sort strategy
                                if ($Auto -and $State.AutoModeActive -and -not $goC) {
                                    Show-Message -Message "🤖 AUTO: Analyzing track matches..." -ForegroundColor Cyan -Context $Context
                                    
                                    # Try different sort strategies and pick the best
                                    $strategies = @('byOrder', 'byTitle', 'byDuration')
                                    $bestStrategy = $null
                                    $bestScore = 0
                                    $bestPairing = $null
                                    
                                    foreach ($strategy in @($strategies)) {
                                        # Create temporary pairing with this strategy
                                        $tempParam = @{
                                            SortMethod    = $strategy
                                            AudioFiles    = $State.AudioFiles
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
                                        $State.PairedTracks = $bestPairing
                                        $sortMethod = $bestStrategy
                                    }
                                    
                                    # Calculate confidence percentage
                                    $totalTracks = $State.PairedTracks.Count
                                    $confidencePercent = if ($totalTracks -gt 0) { 
                                        [Math]::Round(($bestScore / $totalTracks) * 100, 0) 
                                    } else { 0 }
                                    
                                    Show-Message -Message "🤖 AUTO: Best strategy: '$bestStrategy' ($bestScore/$totalTracks matches, $confidencePercent% confidence)" -ForegroundColor Green -Context $Context
                                    
                                    # Auto-proceed if confidence is high enough
                                    if ($confidencePercent -ge ($AutoConfidenceThreshold * 100)) {
                                        Show-Message -Message "✓ AUTO: Confidence threshold met, auto-saving tags and cover..." -ForegroundColor Green -Context $Context
                                        
                                        # Auto-execute save-all command
                                        $inputF = 'sa'
                                        $goC = $true  # Simulate goC to trigger save-all
                                        
                                        # If AutoSaveCover is enabled, also save cover art
                                        if ($AutoSaveCover) {
                                            $coverUrl = Get-IfExists $ProviderAlbum 'cover_url'
                                            if ($coverUrl) {
                                                Show-Message -Message "🖼️  AUTO: Saving cover art..." -ForegroundColor Cyan -Context $Context
                                                $config = Get-OMConfig
                                                $maxSize = $config.CoverArt.FolderImageSize
                                                $result = Save-CoverArt -CoverUrl $coverUrl -AlbumPath $State.Album.FullName `\n                                                    -Action SaveToFolder -MaxSize $maxSize -WhatIf:$useWhatIf
                                                if ($result.Success) {
                                                    Show-Message -Message "✓ AUTO: Cover art saved" -ForegroundColor Green -Context $Context
                                                }
                                            }
                                        }
                                    }
                                    else {
                                        Write-Warning "AUTO: Confidence too low ($confidencePercent%), falling back to interactive mode"
                                        $State.AutoModeActive = $false
                                    }
                                }
                            }

                            if ($goC) {
                                Show-Message -Message "goC: auto-applying Save-All for album '$($ProviderAlbum.name)'." -ForegroundColor Yellow -Context $Context
                                $inputF = 'sa'
                            }
                            elseif ($Auto -and $State.AutoModeActive -and $inputF -eq 'sa') {
                                # Auto mode already set inputF to 'sa' above, proceed
                            }
                            else {
                                if ($useWhatIf) { $HostColor = 'Cyan' } else { $HostColor = 'Red' }
                                $whatIfStatus = if ($useWhatIf) { "ON" } else { "OFF" }
                                $verboseStatus = if ($State.ShowVerbose) { "ON" } else { "OFF" }
                                
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
                                
                                $genreModeStatus = $State.GenreMode
                                $optionsLine = "`nOptions: SortBy $sortMethodDisplay, (r)everse | (S)ave {[A]ll, [T]ags, [F]olderNames} | {C}over {[V]iew,[O]riginal,[S]ave,saveIn[T]ags} | (aa)AlbumArtist, (gm)GenreMode:$genreModeStatus, (rm)ReviewMarked, (b)ack/(pr)evious, (P)rovider, (F)indmode, (w)hatIf:$whatIfStatus, (v)erbose:$verboseStatus, (X)ip"
                                $commandList = @('o', 'd', 't', 'n', 'l', 'h', 'm', 'f', 'r', 'rm', 'sa', 'st', 'sf', 'cv', 'cvo', 'cs', 'ct', 'aa', 'gm', 'b', 'pr', 'p', 'pq', 'ps', 'pd', 'pm', 'F', 'w', 'whatif', 'v', 'x')
                                $paramshow = @{
                                    PairedTracks  = $State.PairedTracks
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
                                if ($State.ShowVerbose) { $paramshow.Verbose = $true }
                                if ($VerbosePreference -ne 'Continue') { Clear-Host }
                                $inputF = Show-Tracks @paramshow

                                if ($null -eq $inputF) { continue }
                                if ($inputF -eq 'q') {
                                    Show-Message -Message $optionsLine -ForegroundColor $HostColor -Context $Context
                                    $inputF = Show-OMPrompt -Prompt "Select tracks(or option):" -Context $Context
                                }
                            }

                            switch -Regex ($inputF) {
                                '^o$' { $sortMethod = 'byOrder'; $State.RefreshTracks = $true; continue }
                                '^d$' { $sortMethod = 'byDuration'; $State.RefreshTracks = $true; continue }
                                '^t$' { $sortMethod = 'byTrackNumber'; $State.RefreshTracks = $true; continue }
                                '^n$' { $sortMethod = 'byName'; $State.RefreshTracks = $true; continue }
                                '^l$' { $sortMethod = 'byTitle'; $State.RefreshTracks = $true; continue }
                                '^h$' { $sortMethod = 'Hybrid'; $State.RefreshTracks = $true; continue }
                                '^m$' { $sortMethod = 'Manual'; $State.RefreshTracks = $true; continue }
                                '^f$' { $sortMethod = 'byFilesystem'; $State.RefreshTracks = $true; continue }
                                '^r$' { $ReverseSource = -not $ReverseSource; $State.RefreshTracks = $true; continue }
                                '^rm$' {
                                    # Review marked tracks using helper function
                                    $reviewResult = Invoke-StageB-ReviewMarkedTracks `
                                        -PairedTracks $State.PairedTracks `
                                        -TracksForAlbum $tracksForAlbum `
                                        -Context $Context
                                    
                                    # Handle exit request
                                    if ($reviewResult.ExitRequested) {
                                        $exitDo = $true
                                        $albumDone = $true
                                        break
                                    }
                                    
                                    # Handle back request
                                    if ($reviewResult.BackRequested) {
                                        $stage = 'B'
                                        $exitDo = $true
                                        break
                                    }
                                    
                                    # Handle provider switch
                                    if ($reviewResult.ProviderSwitch) {
                                        $Provider = $reviewResult.ProviderSwitch
                                    }
                                    
                                    # Show completion message
                                    if (-not $reviewResult.NoProviderTracks) {
                                        $finishMsg = "Finished reviewing tracks (Updated: $($reviewResult.Updated), Skipped: $($reviewResult.Skipped))"
                                        Show-Message -Message "`n✓ $finishMsg" -ForegroundColor Green -Context $Context
                                        Start-Sleep -Seconds 1
                                    }
                                    
                                    # DO NOT set RefreshTracks = true here!
                                    # Invoke-StageB-ReviewMarkedTracks modifies $State.PairedTracks in-place
                                    # Setting RefreshTracks would call Set-Tracks again and overwrite manual matches
                                    continue
                                }
                                '^gm$' {
                                    # Toggle genre mode between Replace and Merge
                                    $State.GenreMode = if ($State.GenreMode -eq 'Replace') { 'Merge' } else { 'Replace' }
                                    $modeColor = if ($State.GenreMode -eq 'Merge') { 'Cyan' } else { 'Green' }
                                    Show-Message -Message "`n✓ Genre Mode: $($State.GenreMode)" -ForegroundColor $modeColor -Context $Context
                                    if ($State.GenreMode -eq 'Merge') {
                                        Show-Message -Message "   Genres will be merged with existing tags (deduplicated)" -ForegroundColor Gray -Context $Context
                                    } else {
                                        Show-Message -Message "   Genres will replace existing tags" -ForegroundColor Gray -Context $Context
                                    }
                                    Start-Sleep -Seconds 2
                                    $State.RefreshTracks = $true
                                    continue
                                }
                                '^v$' { $State.ShowVerbose = -not $State.ShowVerbose; $State.RefreshTracks = $true; continue }
                                '^aa$' {
                                    # Manual album artist builder
                                    if ($tracksForAlbum -and $tracksForAlbum.Count -gt 0) {
                                        $State.ManualAlbumArtist = Invoke-AlbumArtistBuilder -AlbumName $ProviderAlbum.name -Tracks $tracksForAlbum -CurrentAlbumArtist $ProviderArtist.name
                                        if ($State.ManualAlbumArtist) {
                                            Show-Message -Message "`n✓ Album artist set to: $($State.ManualAlbumArtist)" -ForegroundColor Green -Context $Context
                                            $State.RefreshTracks = $true
                                        }
                                        else {
                                            Show-Message -Message "`nSkipped - album artist unchanged" -ForegroundColor Gray -Context $Context
                                        }
                                    }
                                    else {
                                        Write-Warning "No tracks available for album artist builder"
                                    }
                                    continue
                                }
                                '^b$' { 
                                    $State.ManualAlbumArtist = $null
                                    # $AlbumId = $ProviderAlbum.id
                                    if ($State.FindMode -eq 'quick') {
                                        $loadStageBResults = $false    # Use cache
                                        $State.BackNavigationMode = $true  # Enable back navigation mode
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
                                    $State.ManualAlbumArtist = $null
                                    # $AlbumId = $ProviderAlbum.id
                                    if ($State.FindMode -eq 'quick') {
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
                                    Show-Message -Message "`nCurrent provider: $Provider (default: $defaultProvider)" -ForegroundColor Cyan -Context $Context
                                    Show-Message -Message "To switch providers, use: (ps)potify, (pq)obuz, (pd)iscogs, (pm)usicbrainz" -ForegroundColor Gray -Context $Context
                                    continue
                                }
                                '^F$' {
                                    # Toggle find mode between quick and artist-first
                                    if ($State.FindMode -eq 'quick') {
                                        $State.FindMode = 'artist-first'
                                        Show-Message -Message "✓ Switched to Artist-First Search mode" -ForegroundColor Green -Context $Context
                                        # Reset search state when switching to artist-first mode
                                        $cachedAlbums = $null
                                        $cachedArtistId = $null
                                        $artistQuery = $artist
                                        $ProviderArtist = $null
                                        $ProviderAlbum = $null
                                    }
                                    else {
                                        $State.FindMode = 'quick'
                                        $skipQuickPrompts = $false  # Show prompts when switching to quick mode
                                        Show-Message -Message "✓ Switched to Quick Album Search mode" -ForegroundColor Green -Context $Context
                                    }
                                    $stage = 'A'
                                    $exitdo = $true
                                    break
                                }
                                '^whatif$|^w$' {
                                    $useWhatIf = -not $useWhatIf
                                    $State.RefreshTracks = $true
                                    continue
                                }
                                '^x(ip)?$' { 
                                    # Skip to next album in pipeline
                                    $albumDone = $true
                                    $exitDo = $true  # Need this to break out of doTracks loop
                                    break
                                }
                                '^sf$' {
                                    # Save folder only - use helper for folder move
                                    $folderMoveResult = Invoke-OMFolderMove `
                                        -ProviderAlbum $ProviderAlbum `
                                        -ProviderArtist $ProviderArtist `
                                        -AlbumPath $State.Album.FullName `
                                        -AudioFiles $audioFiles `
                                        -ManualAlbumArtist $State.ManualAlbumArtist `
                                        -AlbumName $State.AlbumName `
                                        -UseWhatIf:$useWhatIf `
                                        -ForceGC  # sf always runs GC
                                    
                                    # Handle move success using new function
                                    Write-Verbose ("TRACE: Invoke-OMHandleMoveSuccess args: moveResult=($($folderMoveResult.MoveResult -as [string])); useWhatIf=$useWhatIf; oldpath=$($folderMoveResult.OldPath)")
                                    Invoke-OMHandleMoveSuccess -MoveResult $folderMoveResult.MoveResult -UseWhatIf $useWhatIf -OldPath $folderMoveResult.OldPath `
                                        -State $State -TargetFolder $TargetFolder -Context $Context -NonInteractive:$NonInteractive -GoC:$goC -AudioFiles $State.AudioFiles
                                    Sync-OMStateToScript -State $State  # Sync State back to script variables
                                    continue doTracks
                                }
                                '^st\s+(?<range>.+)$' {
                                    if (-not $State.PairedTracks -or $State.PairedTracks.Count -eq 0) {
                                        Write-Warning "No track matches available to save."
                                        continue doTracks
                                    }

                                    $rangeText = $matches['range'].Trim()
                                    if (-not $rangeText) {
                                        Write-Warning "No track numbers provided for 'st' command."
                                        continue doTracks
                                    }

                                    try {
                                        $selectedIndices = Expand-SelectionRange -RangeText $rangeText -MaxIndex $State.PairedTracks.Count
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
                                        $saveResult = Save-OMTrackSelection -PairedTracks $State.PairedTracks -SelectedIndices $selectedIndices -ProviderArtist $ProviderArtist -ProviderAlbum $ProviderAlbum -UseWhatIf:$useWhatIf
                                    }
                                    catch {
                                        Write-Warning "Failed to save selected tracks: $($_.Exception.Message)"
                                        continue doTracks
                                    }

                                    foreach ($info in $saveResult.SavedDetails) {
                                        $tags = $info.Tags
                                        $filePath = $info.FilePath
                                        $fileName = Split-Path -Leaf $filePath
                                        Show-Message -Message (("Saved tags: {0} -> {1:D2}.{2:D2}: {3}" -f $fileName, $tags.Disc, $tags.Track, $tags.Title)) -ForegroundColor Green -Context $Context
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
                                        Show-Message -Message (("✓ Processed {0} track(s). Remaining: {1}" -f $saveResult.SavedDetails.Count, $State.PairedTracks.Count)) -ForegroundColor Green -Context $Context
                                    }
                                    else {
                                        Show-Message -Message "No tracks were updated." -ForegroundColor Yellow -Context $Context
                                    }

                                    $State.RefreshTracks = $false
                                    continue doTracks
                                }
                                '^st$' {
                                    try {


                                        foreach ($pair in $State.PairedTracks) {
                                            if ($null -ne $pair.AudioFile) {
                                                $filePath = $pair.AudioFile.FilePath
                                                $tagsParams = @{
                                                    Artist       = $ProviderArtist
                                                    Album        = $ProviderAlbum
                                                    SpotifyTrack = $pair.SpotifyTrack
                                                }
                                                if ($State.ManualAlbumArtist) {
                                                    $tagsParams['ManualAlbumArtist'] = ConvertTo-AlbumArtistString -Value $State.ManualAlbumArtist
                                                }
                                                $tags = Get-Tags @tagsParams
                                                Write-Verbose ("Saving tags to: {0}" -f $filePath)
                                                Write-Verbose ("Tag values:\n{0}" -f ($tags | Out-String))
                                                $genreMerge = ($State.GenreMode -eq 'Merge')
                                                $res = Save-TagsForFile -FilePath $filePath -TagValues $tags -WhatIf:$useWhatIf -GenreMergeMode:$genreMerge
                                                if ($res.Success) { 
                                                    Show-Message -Message (("Saved tags: {0} -> {1:D2}.{2:D2}: {3}" -f (Split-Path -Leaf $filePath), $tags.Disc, $tags.Track, $tags.Title)) -ForegroundColor Green -Context $Context 
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
                                            foreach ($af in @($audioFiles)) {
                                                if ($af.TagFile) {
                                                    try { $af.TagFile.Dispose() } catch { Write-Verbose "Failed disposing TagFile: $_" }
                                                    $af.TagFile = $null
                                                }
                                            }
                                            # Reload audio files with fresh TagLib handles
                                            $audioFiles = Reload-OMAudioFiles -AlbumPath $State.Album.FullName
                                            $State.RefreshTracks = $true
                                        }
                                        # Don't exit the doTracks loop - just refresh and continue
                                        # This avoids re-entering Stage C which would re-fetch tracks from provider
                                        continue doTracks
                                    }
                                    catch {
                                        Show-Message -Message '---- ERROR in save-tags (st) handler ----' -ForegroundColor Red -Context $Context
                                        Show-Message -Message "Message: $($_.Exception.Message)" -Context $Context
                                        Show-Message -Message "Exception: $($_ | Out-String)" -Context $Context
                                        Show-Message -Message "ScriptStackTrace: $($_.ScriptStackTrace)" -Context $Context
                                        # keep UI alive; set stage to C so outer loop continues
                                        $stage = 'C'
                                        $exitDo = $true
                                        break
                                    }
                                }
                                '^sa$' {




                                    foreach ($pair in $State.PairedTracks) {
                                        # check if pair has audio and spotify track with get-ifexists
                                        if ($null -ne (Get-IfExists $pair 'AudioFile') -and $null -ne (Get-IfExists $pair 'SpotifyTrack')) {
                                            $filePath = $pair.AudioFile.FilePath
                                            $tagsParams = @{
                                                Artist       = $ProviderArtist
                                                Album        = $ProviderAlbum
                                                SpotifyTrack = $pair.SpotifyTrack
                                            }
                                            if ($State.ManualAlbumArtist) {
                                                $tagsParams['ManualAlbumArtist'] = ConvertTo-AlbumArtistString -Value $State.ManualAlbumArtist
                                            }
                                            $tags = Get-Tags @tagsParams
                                            Write-Verbose ("Saving tags to: {0}" -f $filePath)
                                            Write-Verbose ("Tag values:\n{0}" -f ($tags | Out-String))
                                            $genreMerge = ($State.GenreMode -eq 'Merge')
                                            $res = Save-TagsForFile -FilePath $filePath -TagValues $tags -WhatIf:$useWhatIf -GenreMergeMode:$genreMerge
                                            if ($res.Success) { 
                                                Show-Message -Message (("Saved tags: {0} -> {1:D2}.{2:D2}: {3}" -f (Split-Path -Leaf $filePath), $tags.Disc, $tags.Track, $tags.Title)) -ForegroundColor Green -Context $Context 
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
                                    
                                    # Use helper for folder move - use ReloadTags since we just saved tags
                                    $folderMoveResult = Invoke-OMFolderMove `
                                        -ProviderAlbum $ProviderAlbum `
                                        -ProviderArtist $ProviderArtist `
                                        -AlbumPath $State.Album.FullName `
                                        -AudioFiles $audioFiles `
                                        -ManualAlbumArtist $State.ManualAlbumArtist `
                                        -AlbumName $State.AlbumName `
                                        -UseWhatIf:$useWhatIf `
                                        -ReloadTags:(-not $useWhatIf)
                                    
                                    Write-Verbose ("TRACE: Invoke-OMHandleMoveSuccess args: moveResult=($($folderMoveResult.MoveResult -as [string])); useWhatIf=$useWhatIf; oldpath=$($folderMoveResult.OldPath)")
                                    Invoke-OMHandleMoveSuccess -MoveResult $folderMoveResult.MoveResult -UseWhatIf $useWhatIf -OldPath $folderMoveResult.OldPath `
                                        -State $State -TargetFolder $TargetFolder -Context $Context -NonInteractive:$NonInteractive -GoC:$goC -AudioFiles $audioFiles
                                    Sync-OMStateToScript -State $State  # Sync State back to script variables
                                    
                                    # Reload audio files with updated tags if not in WhatIf mode and folder wasn't moved
                                    # (Invoke-OMHandleMoveSuccess reloads if folder was moved, but we need to reload even if it wasn't)
                                    if (-not $useWhatIf -and $moveResult -and $moveResult.NewAlbumPath -eq $oldpath) {
                                        Write-Verbose "Reloading audio files to reflect saved tags (folder not moved)"
                                        # Reload audio files with fresh TagLib handles
                                        $State.AudioFiles = Reload-OMAudioFiles -AlbumPath $State.Album.FullName
                                        
                                        # Update paired tracks with reloaded audio files to preserve pairing
                                        if ($State.PairedTracks -and $State.PairedTracks.Count -gt 0) {
                                            for ($i = 0; $i -lt [Math]::Min($State.PairedTracks.Count, $State.AudioFiles.Count); $i++) {
                                                $State.PairedTracks[$i].AudioFile = $State.AudioFiles[$i]
                                            }
                                        }
                                        $State.RefreshTracks = $true
                                    }
                                    
                                    # AUTO MODE: Skip to next album after successful save
                                    if ($Auto -and $State.AutoModeActive) {
                                        Show-Message -Message "✓ AUTO: Album completed successfully, moving to next album..." -ForegroundColor Green -Context $Context
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
                                            Show-Message -Message (("Updated tag '$actualTagName' for track $idx ($($spotifyTrack.Title)): '$newValue'")) -ForegroundColor Green -Context $Context
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
                                '^p([qsdm])$' {
                                    # Provider switch: pq=Qobuz, ps=Spotify, pd=Discogs, pm=MusicBrainz
                                    $newProvider = Switch-OMProvider -Input $matches[0] -Context $Context
                                    if ($newProvider) {
                                        $Provider = $newProvider
                                        $cachedAlbums = $null
                                        $cachedArtistId = $null
                                        $stage = 'A'
                                        $exitdo = $true
                                        break
                                    }
                                    continue
                                }
                                '^cvo(\d*)$' {
                                    # View Cover art original
                                    $rangeText = $matches[1]
                                    if (-not $rangeText) { $rangeText = "1" }
                                        Write-Verbose "Stage B cvo: Show-CoverArt called with Size='original' Grid='False' Album= $($ProviderAlbum.name)"
                                        Show-CoverArt -Album $ProviderAlbum -RangeText $rangeText -Provider $Provider -Size 'original' -Grid $false
                                    Prompt-PressEnter -Context $Context
                                    continue
                                }
                                '^cv(\d*)$' {
                                    # View Cover art
                                    $rangeText = $matches[1]
                                    if (-not $rangeText) { $rangeText = "1" }
                                    Write-Verbose "Stage B cv: Show-CoverArt called with Size='original' Grid='False' Album= $($ProviderAlbum.name)"
                                    Show-CoverArt -Album $ProviderAlbum -RangeText $rangeText -Provider $Provider -Size 'original' -Grid $false -LoopLabel 'stageLoop'
                                    Prompt-PressEnter -Context $Context
                                    continue
                                }
                                '^cs(\d*)$' {
                                    # Save Cover art to folder
                                    $coverUrl = Get-IfExists $ProviderAlbum 'cover_url'
                                    
                                    if ($coverUrl) {
                                        $config = Get-OMConfig
                                        $maxSize = $config.CoverArt.FolderImageSize
                                        $result = Save-CoverArt -CoverUrl $coverUrl -AlbumPath $State.Album.FullName -Action SaveToFolder -MaxSize $maxSize -WhatIf:$useWhatIf
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
                                        # Get audio files for embedding using helper
                                        $audioFilesForCover = Get-OMAudioFile -Path $State.Album.FullName

                                        if ($audioFilesForCover.Count -gt 0) {
                                            $result = Save-CoverArt -CoverUrl $coverUrl -AudioFiles $audioFilesForCover -Action EmbedInTags -MaxSize $maxSize -WhatIf:$useWhatIf
                                            if (-not $result.Success) {
                                                Write-Warning "Failed to embed cover art: $($result.Error)"
                                            }
                                            # Clean up tag files
                                            foreach ($af in $audioFilesForCover) {
                                                if ($af.TagFile) {
                                                    try { $af.TagFile.Dispose() } catch { Write-Verbose "Dispose failed: $($_.Exception.Message)" }
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
    } catch [System.Management.Automation.ParameterBindingException] {
        Dump-ExceptionDiagnostics -ErrorRecord $_ -ContextMsg "Top-level process ParameterBindingException"
        Write-Verbose "Top-level ParameterBindingException recovered"

        try {
            $snapFile = Join-Path $env:TEMP 'start_om_state_snapshot.txt'
            $snap = @()
            $snap += "Timestamp: $(Get-Date -Format o)"
            $snap += "Context: Top-level process ParameterBindingException"
            $snap += "Provider: $Provider"
            $snap += "Auto: $Auto, AutoFallback: $AutoFallback, NonInteractive: $NonInteractive"
            $snap += "State.AlbumName: $($State.AlbumName)"
            $snap += "State.Artist: $($State.Artist)"
            $snap += "albumCandidates.Count: $($albumCandidates -as [array] | Measure-Object | Select-Object -ExpandProperty Count)"
            $snap += "albumChoice: $albumChoice"
            $snap += "Recent PSCallStack: $((Get-PSCallStack) | Out-String)"
            $snap += "Loaded functions: $((Get-Command -CommandType Function | Select-Object -First 50 | ForEach-Object { $_.Name }) -join ', ')"
            $snap | Out-File -FilePath $snapFile -Append -Encoding utf8 -Force
        } catch {
            Write-Verbose "Failed to write state snapshot: $($_.Exception.Message)"
        }
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

