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

.EXAMPLE
    Start-OM -Path "C:\Music\MyArtist"

    Starts the interactive organization process for all album folders inside "C:\Music\MyArtist".

.EXAMPLE
    "C:\Music\MyArtist" | Start-OM -Provider Discogs

    Starts the interactive process using Discogs as the provider, with the path provided via the pipeline.

.EXAMPLE
    Start-OM -Path "C:\Music\MyArtist\MyAlbum" -ArtistId "..." -AlbumId "..." -NonInteractive

    Runs the process non-interactively for a specific album, using the provided artist and album IDs.

.NOTES
    This function requires the TagLib-Sharp library for reading and writing audio file tags.
    It will attempt to install it automatically if it's missing.
    For Spotify integration, the 'Spotishell' module is required.
    The function supports -WhatIf to preview changes without applying them.
    Interactive mode supports switching between Quick Album Search and Artist-First Search modes,
    changing providers on the fly, and various track sorting and matching options.

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
        [switch]$ReverseSource

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

        if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
            throw "Path not found or not a directory: $Path"
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
            Write-Host $Provider -ForegroundColor Cyan
            Write-Host "👤 Original Artist: " -NoNewline -ForegroundColor Yellow
            Write-Host $Artist -ForegroundColor White
            Write-Host "💿 Original Album: " -NoNewline -ForegroundColor Green
            Write-Host $AlbumName -NoNewline -ForegroundColor White
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
                    $audioFiles = Get-ChildItem -LiteralPath $script:album.FullName -File -Recurse | Where-Object { $_.Extension -match '\.(mp3|flac|wav|m4a|aac|ogg|ape)' }
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
                                Duration    = $tagFile.Properties.Duration.TotalMilliseconds
                            }
                        }
                        catch {
                            Write-Warning "Skipping corrupted or invalid audio file: $($f.FullName) - Error: $($_.Exception.Message)"
                            continue
                        }
                    }

                    # Update paired tracks with reloaded audio files to reflect updated tags
                    if ($pairedTracks -and $pairedTracks.Count -gt 0) {
                        for ($i = 0; $i -lt [Math]::Min($pairedTracks.Count, $audioFiles.Count); $i++) {
                            if ($pairedTracks[$i].AudioFile.TagFile) {
                                try { $pairedTracks[$i].AudioFile.TagFile.Dispose() } catch { }
                            }
                            $pairedTracks[$i].AudioFile = $audioFiles[$i]
                        }
                    }
                    $refreshTracks = $false


                    # $refreshTracks = $true
                    Write-Host "Album saved and folder moved. Choose 's' to skip to next album, or select another option." -ForegroundColor Yellow
                    #  continue doTracks
                }
            }
            else {
                Write-Warning "Move failed or was skipped. Move result: $moveResult"
            }
        }
        $script:album = $null
        $script:artist= Split-Path -Leaf $Path
        $artist = Split-Path -Leaf $Path
        $albums = Get-ChildItem -LiteralPath $Path -Directory
        
        # Initialize WhatIf mode early
        $useWhatIf = $isWhatIf
        $script:findMode = 'artist-first'  # Default to artist-first mode
        $currentAlbumPage = 1
        
        foreach ($albumOriginal in $albums) {
            $script:album = $albumOriginal
            $script:ManualAlbumArtist = $null
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
            $audioFilesCheck = Get-ChildItem -LiteralPath $script:album.FullName -File -Recurse | Where-Object { $_.Extension -match '\.(mp3|flac|wav|m4a|aac|ogg|ape)' }
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
            $currentArtist = $script:artist  # Persistent current artist for quick find mode
            $currentAlbum = $script:albumName  # Persistent current album for quick find mode
            $skipQuickPrompts = $false  # Flag to skip prompts when re-entering quick find after provider change

            :stageLoop while ($true) {
                # NEW: Handle quick find mode (only when not in track selection stage)
                if ($script:findMode -eq 'quick' -and $stage -ne 'C') {
                    Clear-Host
                    & $showHeader -Provider $Provider -Artist $script:artist -AlbumName $script:albumName -TrackCount $script:trackCount
                    Write-Host "🔍 Find Mode: Quick Album Search" -ForegroundColor Magenta
                    Write-Host ""

                    # Auto-detect artist and album from folder structure
                    if (-not $skipQuickPrompts) {
                        $folderName = $script:album.Name
                        $artistFolderName = $script:album.Parent.Name
                        
                        # Extract album name (strip year if present)
                        if ($folderName -match '^\d{4}\s*-\s*(.+)$') {
                            $detectedAlbum = $matches[1].Trim()
                        } else {
                            $detectedAlbum = $folderName
                        }
                        
                        # Use parent folder as artist
                        $detectedArtist = $artistFolderName
                        
                        Write-Host "📁 Auto-detected from folder structure: Artist='$detectedArtist', Album='$detectedAlbum'" -ForegroundColor Green
                        $currentArtist = $detectedArtist
                        $currentAlbum = $detectedAlbum
                        $skipQuickPrompts = $true  # Skip prompts since both detected from structure
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
                    } else {
                        # Use current values without prompting
                        $quickArtist = $currentArtist
                        $quickAlbum = $currentAlbum
                    }

                    Write-Host "Searching for '$quickAlbum' by '$quickArtist'..." -ForegroundColor Cyan
                    
                    :quickSearchLoop while ($true) {
                        try {
                            $quickResults = Invoke-ProviderSearch -Provider $Provider -Album $quickAlbum -Artist $quickArtist -Type album
                            $albumCandidates = @($quickResults.albums.items | Where-Object { $_ -ne $null })
                        } catch {
                            Write-Warning "Quick search failed: $_"
                            $albumCandidates = @()
                        }

                        if ($albumCandidates.Count -eq 0) {
                            Write-Host "No albums found for '$quickAlbum' by '$quickArtist' with $Provider." -ForegroundColor Red
                            $retryChoice = Read-Host "`nPress Enter to retry, '(p)rovider', '(a)' artist-first mode, '(na)' new artist, or enter new album name"
                            if ($retryChoice -eq 'p') {
                                $config = Get-OMConfig
                                $defaultProvider = $config.DefaultProvider
                                $newProvider = Read-Host "Current provider: $Provider`nAvailable providers: (p) default ($defaultProvider), (ps)potify, (pq)obuz, (pd)iscogs, (pm)usicbrainz`nEnter provider"
                                $providerMap = @{
                                    'p' = $defaultProvider
                                    'ps' = 'Spotify'; 's' = 'Spotify'; 'spotify' = 'Spotify'
                                    'pq' = 'Qobuz'; 'q' = 'Qobuz'; 'qobuz' = 'Qobuz'
                                    'pd' = 'Discogs'; 'd' = 'Discogs'; 'discogs' = 'Discogs'
                                    'pm' = 'MusicBrainz'; 'm' = 'MusicBrainz'; 'musicbrainz' = 'MusicBrainz'
                                }
                                $matched = $providerMap[$newProvider.ToLower()]
                                if ($matched) {
                                    $Provider = $matched
                                    Write-Host "Switched to provider: $Provider" -ForegroundColor Green
                                    continue quickSearchLoop
                                }
                            } elseif ($retryChoice -eq 'a') {
                                $script:findMode = 'artist-first'
                                $stage = 'A'
                                break quickSearchLoop
                            } elseif ($retryChoice -eq 'na') {
                                $userInput = Read-Host "Enter new artist name"
                                if (-not $userInput) {
                                    Write-Host "Artist cannot be empty. Retrying." -ForegroundColor Yellow
                                    continue quickSearchLoop
                                }
                                $currentArtist = $userInput
                            } elseif ($retryChoice) {
                                # Assume it's a new album name
                                $currentAlbum = $retryChoice
                            } else {
                                continue quickSearchLoop
                            }
                        } else {
                            break quickSearchLoop
                        }
                    }

                    if ($script:findMode -ne 'quick') {
                        continue stageLoop
                    }

                    # Store candidates for back navigation
                    $script:quickAlbumCandidates = $albumCandidates
                    $script:quickCurrentPage = 1

                    # Album selection loop
                    :albumSelectionLoop while ($true) {
                        # Display album candidates
                        Write-Host "$Provider Album candidates for '$quickAlbum' by '$quickArtist':" -ForegroundColor Green
                        for ($i = 0; $i -lt $albumCandidates.Count; $i++) {
                            $album = $albumCandidates[$i]
                            $artistDisplay = if ($album.artists -and $album.artists[0].name) { $album.artists[0].name } else { 'Unknown Artist' }
                            
                            # Get year and track count for consistent display with artist-first mode
                            $year = Get-IfExists $album 'release_date'
                            $trackCount = Get-IfExists $album 'total_tracks'
                            if (-not $trackCount) { $trackCount = Get-IfExists $album 'track_count' }
                            if (-not $trackCount) { $trackCount = Get-IfExists $album 'tracks_count' }
                            $trackInfo = if ($trackCount) { " ($trackCount tracks)" } else { "" }
                            
                            Write-Host "[$($i+1)] $($album.name) - $artistDisplay (id: $($album.id)) (year: $year)$trackInfo"
                        }

                        $originalColor = [Console]::ForegroundColor
                        [Console]::ForegroundColor = [ConsoleColor]::Yellow
                        $albumChoice = Read-Host "Select album [number] (Enter=first), (P)rovider, {F}indMode, (C)over {[V]iew,[S]ave,saveIn[T]ags}, or new search term"
                        [Console]::ForegroundColor = $originalColor
                        if ($albumChoice -eq '') { $albumChoice = '1' }
                        
                        if ($albumChoice -eq 'p') {
                            $config = Get-OMConfig
                            $defaultProvider = $config.DefaultProvider
                            $newProvider = Read-Host "Current provider: $Provider`nAvailable providers: (p) default ($defaultProvider), (ps)potify, (pq)obuz, (pd)iscogs, (pm)usicbrainz`nEnter provider"
                            $providerMap = @{
                                'p' = $defaultProvider
                                'ps' = 'Spotify'; 's' = 'Spotify'; 'spotify' = 'Spotify'
                                'pq' = 'Qobuz'; 'q' = 'Qobuz'; 'qobuz' = 'Qobuz'
                                'pd' = 'Discogs'; 'd' = 'Discogs'; 'discogs' = 'Discogs'
                                'pm' = 'MusicBrainz'; 'm' = 'MusicBrainz'; 'musicbrainz' = 'MusicBrainz'
                            }
                            $matched = $providerMap[$newProvider.ToLower()]
                            if ($matched) {
                                $Provider = $matched
                                Write-Host "Switched to provider: $Provider" -ForegroundColor Green
                                $skipQuickPrompts = $true  # Skip prompts when re-entering quick find
                                continue stageLoop
                            }
                            continue albumSelectionLoop
                        } elseif ($albumChoice -eq 'ps') {
                            $Provider = 'Spotify'
                            Write-Host "Switched to provider: $Provider" -ForegroundColor Green
                            $skipQuickPrompts = $true
                            continue stageLoop
                        } elseif ($albumChoice -eq 'pq') {
                            $Provider = 'Qobuz'
                            Write-Host "Switched to provider: $Provider" -ForegroundColor Green
                            $skipQuickPrompts = $true
                            continue stageLoop
                        } elseif ($albumChoice -eq 'pd') {
                            $Provider = 'Discogs'
                            Write-Host "Switched to provider: $Provider" -ForegroundColor Green
                            $skipQuickPrompts = $true
                            continue stageLoop
                        } elseif ($albumChoice -eq 'pm') {
                            $Provider = 'MusicBrainz'
                            Write-Host "Switched to provider: $Provider" -ForegroundColor Green
                            $skipQuickPrompts = $true
                            continue stageLoop
                        } elseif ($albumChoice.ToLower() -eq 'f') {
                            $script:findMode = 'artist-first'
                            $stage = 'A'
                            continue stageLoop
                        } elseif ($albumChoice -match '^cv(\d*)$') {
                            $albumIndex = if ($matches[1]) { [int]$matches[1] - 1 } else { 0 }
                            if ($albumIndex -ge 0 -and $albumIndex -lt $albumCandidates.Count) {
                                $selectedAlbum = $albumCandidates[$albumIndex]
                                Show-CoverArt -Album $selectedAlbum -RangeText $matches[1]
                            } else {
                                Write-Warning "Invalid album index for cv command"
                            }
                            continue albumSelectionLoop
                        } elseif ($albumChoice -match '^cs(\d*)$') {
                            $albumIndex = if ($matches[1]) { [int]$matches[1] - 1 } else { 0 }
                            if ($albumIndex -ge 0 -and $albumIndex -lt $albumCandidates.Count) {
                                $selectedAlbum = $albumCandidates[$albumIndex]
                                if ($selectedAlbum.cover_url) {
                                    $config = Get-OMConfig
                                    $maxSize = $config.CoverArt.FolderImageSize
                                    $result = Save-CoverArt -CoverUrl $selectedAlbum.cover_url -AlbumPath $script:album.FullName -Action SaveToFolder -MaxSize $maxSize -WhatIf:$useWhatIf
                                    if (-not $result.Success) {
                                        Write-Warning "Failed to save cover art: $($result.Error)"
                                    }
                                } else {
                                    Write-Warning "No cover art available for this album"
                                }
                            } else {
                                Write-Warning "Invalid album index for cs command"
                            }
                            continue albumSelectionLoop
                        } elseif ($albumChoice -match '^ct(\d*)$') {
                            $albumIndex = if ($matches[1]) { [int]$matches[1] - 1 } else { 0 }
                            if ($albumIndex -ge 0 -and $albumIndex -lt $albumCandidates.Count) {
                                $selectedAlbum = $albumCandidates[$albumIndex]
                                if ($selectedAlbum.cover_url) {
                                    $config = Get-OMConfig
                                    $maxSize = $config.CoverArt.TagImageSize
                                    # Get audio files for embedding
                                    $audioFiles = Get-ChildItem -LiteralPath $script:album.FullName -File -Recurse | Where-Object { $_.Extension -match '\.(mp3|flac|wav|m4a|aac|ogg|ape)' } | ForEach-Object {
                                        try {
                                            $tagFile = [TagLib.File]::Create($_.FullName)
                                            [PSCustomObject]@{
                                                FilePath = $_.FullName
                                                TagFile = $tagFile
                                            }
                                        } catch {
                                            Write-Warning "Skipping invalid audio file: $($_.FullName)"
                                            $null
                                        }
                                    } | Where-Object { $_ -ne $null }

                                    if ($audioFiles.Count -gt 0) {
                                        $result = Save-CoverArt -CoverUrl $selectedAlbum.cover_url -AudioFiles $audioFiles -Action EmbedInTags -MaxSize $maxSize -WhatIf:$useWhatIf
                                        if (-not $result.Success) {
                                            Write-Warning "Failed to embed cover art: $($result.Error)"
                                        }
                                        # Clean up tag files
                                        foreach ($af in $audioFiles) {
                                            if ($af.TagFile) {
                                                try { $af.TagFile.Dispose() } catch { }
                                            }
                                        }
                                    } else {
                                        Write-Warning "No audio files found to embed cover art in"
                                    }
                                } else {
                                    Write-Warning "No cover art available for this album"
                                }
                            } else {
                                Write-Warning "Invalid album index for ct command"
                            }
                            continue albumSelectionLoop
                        } elseif ($albumChoice -match '^\d+$') {
                            $idx = [int]$albumChoice
                            if ($idx -ge 1 -and $idx -le $albumCandidates.Count) {
                                $ProviderAlbum = $albumCandidates[$idx - 1]
                                $ProviderArtist = @{ name = $quickArtist; id = $quickArtist }  # Simplified artist object
                                $stage = 'C'
                                continue stageLoop
                            } else {
                                Write-Warning "Invalid selection"
                                continue albumSelectionLoop
                            }
                        } else {
                            # New search term - update album name and restart search
                            $currentAlbum = $albumChoice
                            continue stageLoop
                        }
                    }
                }
                switch ($stage) {
                    
                    "A" {
                        $loadStageBResults = $true
                        Clear-Host
                        & $showHeader -Provider $Provider -Artist $script:artist -AlbumName $script:albumName -TrackCount $script:trackCount
                        if ($script:findMode -eq 'quick') {
                            Write-Host "🔍 Find Mode: Quick Album Search" -ForegroundColor Magenta
                        } else {
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
                            $inputF = Read-Host "Enter new search, '(p)rovider', '(x)ip' to skip album, or 'id:<id>' to select by id"
                            switch -Regex ($inputF) {
                                '^x(ip)?$' { 
                                    $albumDone = $true
                                    break stageLoop
                                    #break 
                                }
                                '^p$' {
                                    $config = Get-OMConfig
                                    $defaultProvider = $config.DefaultProvider
                                    $newProvider = Read-Host "Current provider: $Provider`nAvailable providers: (p) default ($defaultProvider), (ps)potify, (pq)obuz, (pd)iscogs, (pm)usicbrainz`nEnter provider"
                                    $providerMap = @{
                                        'p' = $defaultProvider
                                        'ps' = 'Spotify'; 's' = 'Spotify'; 'spotify' = 'Spotify'
                                        'pq' = 'Qobuz'; 'q' = 'Qobuz'; 'qobuz' = 'Qobuz'
                                        'pd' = 'Discogs'; 'd' = 'Discogs'; 'discogs' = 'Discogs'
                                        'pm' = 'MusicBrainz'; 'm' = 'MusicBrainz'; 'musicbrainz' = 'MusicBrainz'
                                    }
                                    $matched = $providerMap[$newProvider.ToLower()]
                                    if ($matched) {
                                        $Provider = $matched
                                        Write-Host "Switched to provider: $Provider" -ForegroundColor Green
                                        continue stageLoop
                                    }
                                    else {
                                        Write-Warning "Invalid provider: $newProvider. Staying with $Provider."
                                        continue stageLoop
                                    }
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

                        Write-Host "Select artist [number] (Enter=first), number, '(x)ip' album, 'id:<id>', '(p)rovider','al:<albumName>', '(F)indmode or new search term:" -ForegroundColor Yellow -NoNewline
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
                        if ($inputF -eq 'p') {
                            $config = Get-OMConfig
                            $defaultProvider = $config.DefaultProvider
                            $newProvider = Read-Host "Current provider: $Provider`nAvailable providers: (p) default ($defaultProvider), (ps)potify, (pq)obuz, (pd)iscogs, (pm)usicbrainz`nEnter provider"
                            $providerMap = @{
                                'p' = $defaultProvider
                                'ps' = 'Spotify'; 's' = 'Spotify'; 'spotify' = 'Spotify'
                                'pq' = 'Qobuz'; 'q' = 'Qobuz'; 'qobuz' = 'Qobuz'
                                'pd' = 'Discogs'; 'd' = 'Discogs'; 'discogs' = 'Discogs'
                                'pm' = 'MusicBrainz'; 'm' = 'MusicBrainz'; 'musicbrainz' = 'MusicBrainz'
                            }
                            $matched = $providerMap[$newProvider.ToLower()]
                            if ($matched) {
                                $Provider = $matched
                                Write-Host "Switched to provider: $Provider" -ForegroundColor Green
                                continue stageLoop
                            }
                            else {
                                Write-Warning "Invalid provider: $newProvider. Staying with $Provider."
                                continue stageLoop
                            }
                        }
                        if ($inputF -eq 'fm') {
                            Write-Host "`nCurrent find mode: $($script:findMode)" -ForegroundColor Cyan
                            Write-Host "Available modes: (q)uick album search, (a)rtist-first search" -ForegroundColor Gray
                            $newMode = Read-Host "Select mode [q/a]"
                            if ($newMode -eq 'q' -or $newMode -eq 'quick') {
                                $script:findMode = 'quick'
                                $skipQuickPrompts = $false  # Show prompts when switching to quick mode
                                Write-Host "✓ Switched to Quick Album Search mode" -ForegroundColor Green
                            } elseif ($newMode -eq 'a' -or $newMode -eq 'artist-first') {
                                $script:findMode = 'artist-first'
                                Write-Host "✓ Switched to Artist-First Search mode" -ForegroundColor Green
                                # Reset search state when switching to artist-first mode
                                $cachedAlbums = $null
                                $cachedArtistId = $null
                                $artistQuery = $artist
                                $ProviderArtist = $null
                                $ProviderAlbum = $null
                            } else {
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
                            CachedAlbums       = $cachedAlbums
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
                        
                        # Handle skip action (break out of stage loop)
                        if ($stage -eq 'Skip') {
                            $albumDone = $true
                            break stageLoop
                            # break
                        }
                        
                        continue stageLoop
                    }
                    "C" {
                        Clear-Host
                        & $showHeader -Provider $Provider -Artist $script:artist -AlbumName $script:albumName -TrackCount $script:trackCount
                        
                        if ($script:findMode -eq 'quick') {
                            Write-Host "🔍 Find Mode: Quick Album Search" -ForegroundColor Magenta
                        } else {
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
                        # collect audio files and tags
                        $audioFiles = Get-ChildItem -LiteralPath $script:album.FullName -File -Recurse | Where-Object { $_.Extension -match '\.(mp3|flac|wav|m4a|aac|ogg|ape)' }
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
                                    Duration    = $tagFile.Properties.Duration.TotalMilliseconds
                                }
                            }
                            catch {
                                Write-Warning "Skipping corrupted or invalid audio file: $($f.FullName) - Error: $($_.Exception.Message)"
                                continue
                            }
                        }
    
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
                                $tracksForAlbum = Invoke-ProviderGetTracks -Provider $Provider -AlbumId $albumIdToFetch
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
                                            Clear-Host
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
                                        $config = Get-OMConfig
                                        $defaultProvider = $config.DefaultProvider
                                        $newProvider = Read-Host "Current provider: $Provider`nAvailable providers: (p) default ($defaultProvider), (ps)potify, (pq)obuz, (pd)iscogs, (pm)usicbrainz`nEnter provider"
                                        $providerMap = @{
                                            'p' = $defaultProvider
                                            'ps' = 'Spotify'; 's' = 'Spotify'; 'spotify' = 'Spotify'
                                            'pq' = 'Qobuz'; 'q' = 'Qobuz'; 'qobuz' = 'Qobuz'
                                            'pd' = 'Discogs'; 'd' = 'Discogs'; 'discogs' = 'Discogs'
                                            'pm' = 'MusicBrainz'; 'm' = 'MusicBrainz'; 'musicbrainz' = 'MusicBrainz'
                                        }
                                        $matched = $providerMap[$newProvider.ToLower()]
                                        if ($matched) {
                                            $Provider = $matched
                                            Write-Host "Switched to provider: $Provider" -ForegroundColor Green
                                            $stage = 'A'
                                        }
                                        else {
                                            Write-Warning "Invalid provider: $newProvider"
                                        }
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
                                
                                $skipChoice = Read-Host "Press Enter to skip, $backPrompt, 'p' to change provider"
                                if ($skipChoice -eq 'b') {
                                    if ($canRetryReleases) {
                                        # Show releases again (same code as above)
                                        Clear-Host
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
                                    $config = Get-OMConfig
                                    $defaultProvider = $config.DefaultProvider
                                    $newProvider = Read-Host "Current provider: $Provider`nAvailable providers: (p) default ($defaultProvider), (ps)potify, (pq)obuz, (pd)iscogs, (pm)usicbrainz`nEnter provider"
                                    $providerMap = @{
                                        'p' = $defaultProvider
                                        'ps' = 'Spotify'; 's' = 'Spotify'; 'spotify' = 'Spotify'
                                        'pq' = 'Qobuz'; 'q' = 'Qobuz'; 'qobuz' = 'Qobuz'
                                        'pd' = 'Discogs'; 'd' = 'Discogs'; 'discogs' = 'Discogs'
                                        'pm' = 'MusicBrainz'; 'm' = 'MusicBrainz'; 'musicbrainz' = 'MusicBrainz'
                                    }
                                    $matched = $providerMap[$newProvider.ToLower()]
                                    if ($matched) {
                                        $Provider = $matched
                                        Write-Host "Switched to provider: $Provider" -ForegroundColor Green
                                        $stage = 'A'
                                    }
                                    else {
                                        Write-Warning "Invalid provider: $newProvider"
                                    }
                                    continue stageLoop
                                }
                                else {
                                    break
                                }
                            }
                        }
                        
                        # Auto-prompt for ambiguous album artist (classical music with multiple artists)
                        if (-not $NonInteractive -and $tracksForAlbum -and $tracksForAlbum.Count -gt 0) {
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
                                $tracksForAlbum | Select-Object id, name, disc_number, track_number | Format-Table -AutoSize
                            }
                        }
                        catch {
                            Write-Verbose "Failed to print debug provider tracks: $($_.Exception.Message)"
                        }
                        $exitdo = $false
                        $pairedTracks = $null
                        $refreshTracks = $true
                        $goCDisplayShown = $false
                        :doTracks do {
                            if ($refreshTracks -or -not $pairedTracks) {
                                if ($useWhatIf) { $HostColor = 'Cyan' } else { $HostColor = 'Red' }
                                $param = @{
                                    SortMethod    = $sortMethod
                                    AudioFiles    = $audioFiles
                                    SpotifyTracks = $tracksForAlbum
                                }
                                if ($reverseSource) { $param.Reverse = $true }
                                $pairedTracks = Set-Tracks @param
                                $refreshTracks = $false
                                if ($sortMethod -eq 'Manual') {
                                    # Reset sort method to 'byOrder' after manual selection to prevent re-prompting on refreshes
                                    $sortMethod = 'byOrder'
                                }

                                if ($goC -and -not $goCDisplayShown) {
                                    Clear-Host
                                    $autoReader = { param($prompt) 'q' }
                                    $autoShowParams = @{
                                        PairedTracks  = $pairedTracks
                                        AlbumName     = $ProviderAlbum.name
                                        SpotifyArtist = $ProviderArtist
                                    }
                                    if ($reverseSource) { $autoShowParams.Reverse = $true }
                                    Show-Tracks @autoShowParams -InputReader $autoReader | Out-Null
                                    $goCDisplayShown = $true
                                }
                            }

                            if ($goC) {
                                Write-Host "goC: auto-applying Save-All for album '$($ProviderAlbum.name)'." -ForegroundColor Yellow
                                $inputF = 'sa'
                            }
                            else {
                                if ($useWhatIf) { $HostColor = 'Cyan' } else { $HostColor = 'Red' }
                                $whatIfStatus = if ($useWhatIf) { "ON" } else { "OFF" }
                                $optionsLine = "`nOptions: SortBy (o)rder, Tit(l)e, (d)uration, (t)rackNumber, (n)ame, (h)ybrid, (m)anual, (r)everse | (S)ave {[A]ll, [T]ags, [F]olderNames} | {C}over {[V]iew,[S]ave,saveIn[T]ags} | (aa)AlbumArtist, (b)ack/(pr)evious, (P)rovider, (F)indmode, (w)hatIf:$whatIfStatus, (X)ip"
                                $commandList = @('o', 'd', 't', 'n', 'l', 'h', 'm', 'r', 'sa', 'st', 'sf', 'cv', 'cs', 'ct', 'aa', 'b', 'pr', 'p', 'pq', 'ps', 'pd', 'pm', 'f', 'w', 'whatif', 'x')
                                $paramshow = @{
                                    PairedTracks  = $pairedTracks
                                    AlbumName     = $ProviderAlbum.name
                                    SpotifyArtist = $ProviderArtist
                                    OptionsText   = $optionsLine
                                    ValidCommands = $commandList
                                    PromptColor   = $HostColor
                                    ProviderName  = $Provider
                                }
                                if ($reverseSource) { $paramshow.Reverse = $true }
                                Clear-Host
                                $inputF = Show-Tracks @paramshow

                                if ($null -eq $inputF) { continue }
                                if ($inputF -eq 'q') {
                                    Write-Host $optionsLine -ForegroundColor $HostColor
                                    $inputF = Read-Host "Select tracks(or option):"
                                }
                            }

                            switch -Regex ($inputF) {
                                '^o$' { $sortMethod = 'byOrder'; $refreshTracks = $true; continue }
                                '^d$' { $sortMethod = 'byDuration'; $refreshTracks = $true; continue }
                                '^t$' { $sortMethod = 'byTrackNumber'; $refreshTracks = $true; continue }
                                '^n$' { $sortMethod = 'byName'; $refreshTracks = $true; continue }
                                '^l$' { $sortMethod = 'byTitle'; $refreshTracks = $true; continue }
                                '^h$' { $sortMethod = 'Hybrid'; $refreshTracks = $true; continue }
                                '^m$' { $sortMethod = 'Manual'; $refreshTracks = $true; continue }
                                '^r$' { $ReverseSource = -not $ReverseSource; $refreshTracks = $true; continue }
                                '^aa$' {
                                    # Manual album artist builder
                                    if ($tracksForAlbum -and $tracksForAlbum.Count -gt 0) {
                                        $script:ManualAlbumArtist = Invoke-AlbumArtistBuilder -AlbumName $ProviderAlbum.name -Tracks $tracksForAlbum -CurrentAlbumArtist $ProviderArtist.name
                                        if ($script:ManualAlbumArtist) {
                                            Write-Host "`n✓ Album artist set to: $script:ManualAlbumArtist" -ForegroundColor Green
                                            $refreshTracks = $true
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
                                    $loadStageBResults = $false    # Use cache and preserve page
                                    if ($script:findMode -eq 'quick') {
                                        $cachedAlbums = $script:quickAlbumCandidates
                                        $currentAlbumPage = $script:quickCurrentPage
                                    }
                                    $stage = 'B'
                                    $exitdo = $true
                                    break 
                                }
                                '^pr$' { 
                                    $script:ManualAlbumArtist = $null
                                    # $AlbumId = $ProviderAlbum.id
                                    $loadStageBResults = $false    # Use cache and preserve page
                                    if ($script:findMode -eq 'quick') {
                                        $cachedAlbums = $script:quickAlbumCandidates
                                        $currentAlbumPage = $script:quickCurrentPage
                                    }
                                    $stage = 'B'
                                    $exitdo = $true
                                    break 
                                }
                                '^p$' {
                                    $config = Get-OMConfig
                                    $defaultProvider = $config.DefaultProvider
                                    $newProvider = Read-Host "Current provider: $Provider`nAvailable providers: (p) default ($defaultProvider), (ps)potify, (pq)obuz, (pd)iscogs, (pm)usicbrainz`nEnter provider"
                                    $providerMap = @{
                                        'p' = $defaultProvider
                                        'ps' = 'Spotify'; 's' = 'Spotify'; 'spotify' = 'Spotify'
                                        'pq' = 'Qobuz'; 'q' = 'Qobuz'; 'qobuz' = 'Qobuz'
                                        'pd' = 'Discogs'; 'd' = 'Discogs'; 'discogs' = 'Discogs'
                                        'pm' = 'MusicBrainz'; 'm' = 'MusicBrainz'; 'musicbrainz' = 'MusicBrainz'
                                    }
                                    $matched = $providerMap[$newProvider.ToLower()]
                                    if ($matched) {
                                        $Provider = $matched
                                        Write-Host "Switched to provider: $Provider" -ForegroundColor Green
                                        $cachedAlbums = $null
                                        $cachedArtistId = $null
                                        $stage = 'A'
                                        $exitdo = $true
                                        break
                                    }
                                    else {
                                        Write-Warning "Invalid provider: $newProvider. Staying with $Provider."
                                        continue
                                    }
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
                                    } else {
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
                                    $refreshTracks = $true
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
                                    
                                    # Use ManualAlbumArtist if set, otherwise fall back to ProviderArtist
                                    $artistNameForFolder = if ($script:ManualAlbumArtist) {
                                        Write-Verbose "Using ManualAlbumArtist for folder name: $script:ManualAlbumArtist"
                                        $script:ManualAlbumArtist
                                    }
                                    else {
                                        Get-IfExists $ProviderArtist 'name'
                                    }
                                    $safeArtistName = Approve-PathSegment -Segment $artistNameForFolder -Replacement '_' -CollapseRepeating -Transliterate
    
                                    $mvArgs = @{
                                        AlbumPath    = $oldpath
                                        NewArtist    = $safeArtistName
                                        NewYear      = $year
                                        NewAlbumName = $safeAlbumName
                                    }
                                    # call Move-AlbumFolder and pass -WhatIf from the caller (if requested)
                                    $moveResult = Invoke-MoveAlbumWithRetry -mvArgs $mvArgs -useWhatIf $useWhatIf
                                    & $handleMoveSuccess -moveResult $moveResult -useWhatIf $useWhatIf -oldpath $oldpath
                                    #& $handleMoveSuccess -moveResult $moveResult -useWhatIf $useWhatIf -oldpath $oldpath -album $album -audioFiles $audioFiles -refreshTracks $refreshTracks
                                    continue doTracks                         
                                    
                                }
                                '^st\s+(?<range>.+)$' {
                                    if (-not $pairedTracks -or $pairedTracks.Count -eq 0) {
                                        Write-Warning "No track matches available to save."
                                        continue doTracks
                                    }

                                    $rangeText = $matches['range'].Trim()
                                    if (-not $rangeText) {
                                        Write-Warning "No track numbers provided for 'st' command."
                                        continue doTracks
                                    }

                                    try {
                                        $selectedIndices = Expand-SelectionRange -RangeText $rangeText -MaxIndex $pairedTracks.Count
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
                                        $saveResult = Save-OMTrackSelection -PairedTracks $pairedTracks -SelectedIndices $selectedIndices -ProviderArtist $ProviderArtist -ProviderAlbum $ProviderAlbum -UseWhatIf:$useWhatIf
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
                                        Write-Host ("✓ Processed {0} track(s). Remaining: {1}" -f $saveResult.SavedDetails.Count, $pairedTracks.Count) -ForegroundColor Green
                                    }
                                    else {
                                        Write-Host "No tracks were updated." -ForegroundColor Yellow
                                    }

                                    $refreshTracks = $false
                                    continue doTracks
                                }
                                '^st$' {
                                    try {


                                        foreach ($pair in $pairedTracks) {
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
                                                $res = Save-TagsForFile -FilePath $filePath -TagValues $tags -WhatIf:$useWhatIf
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
                                            $audioFiles = Get-ChildItem -LiteralPath $script:album.FullName -File -Recurse | Where-Object { $_.Extension -match '\.(mp3|flac|wav|m4a|aac|ogg|ape)' }
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
                                                        Duration    = $tagFile.Properties.Duration.TotalMilliseconds
                                                    }
                                                }
                                                catch {
                                                    Write-Warning "Skipping corrupted or invalid audio file: $($f.FullName) - Error: $($_.Exception.Message)"
                                                    continue
                                                }
                                            }
                                            $refreshTracks = $true
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




                                    foreach ($pair in $pairedTracks) {
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
                                            $res = Save-TagsForFile -FilePath $filePath -TagValues $tags -WhatIf:$useWhatIf
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
                                            if ($value =Get-IfExists $a 'TagFile') {
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
                                    
                                    # Use ManualAlbumArtist if set, otherwise fall back to ProviderArtist
                                    $artistNameForFolder = if ($script:ManualAlbumArtist) {
                                        Write-Verbose "Using ManualAlbumArtist for folder name: $script:ManualAlbumArtist"
                                        $script:ManualAlbumArtist
                                    }
                                    else {
                                        Get-IfExists $ProviderArtist 'name'
                                    }
                                    $safeArtistName = Approve-PathSegment -Segment $artistNameForFolder -Replacement '_' -CollapseRepeating -Transliterate
    
                                    $mvArgs = @{
                                        AlbumPath    = $oldpath
                                        NewArtist    = $safeArtistName
                                        NewYear      = $year
                                        NewAlbumName = $safeAlbumName
                                    }
    
                                    $moveResult = Invoke-MoveAlbumWithRetry -mvArgs $mvArgs -useWhatIf $useWhatIf
                                    #   & $handleMoveSuccess -moveResult $moveResult -useWhatIf $useWhatIf -oldpath $oldpath -album $album -audioFiles $audioFiles -refreshTracks $refreshTracks
                                    & $handleMoveSuccess -moveResult $moveResult -useWhatIf $useWhatIf -oldpath $oldpath
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
                                '^cv(\d*)$' {
                                    # View Cover art
                                    Show-CoverArt -Album $ProviderAlbum -RangeText $matches[1]
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
                                    } else {
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
                                        $audioFilesForCover = Get-ChildItem -LiteralPath $script:album.FullName -File -Recurse | Where-Object { $_.Extension -match '\.(mp3|flac|wav|m4a|aac|ogg|ape)' } | ForEach-Object {
                                            try {
                                                $tagFile = [TagLib.File]::Create($_.FullName)
                                                [PSCustomObject]@{
                                                    FilePath = $_.FullName
                                                    TagFile = $tagFile
                                                }
                                            } catch {
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
                                        } else {
                                            Write-Warning "No audio files found to embed cover art in"
                                        }
                                    } else {
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


