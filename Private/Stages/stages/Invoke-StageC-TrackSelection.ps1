function Invoke-StageC-TrackSelection {
    <#
    .SYNOPSIS
        Stage C: Track selection and matching for Start-OM workflow.
    
    .DESCRIPTION
        Handles track fetching, pairing, display, and user interaction for saving
        tags, cover art, and folder renames. Supports auto mode, manual review,
        and various sort strategies.
    
    .OUTPUTS
        Hashtable with:
        - NextStage: 'A', 'B', 'C', or 'AlbumDone'
        - Provider: Updated provider name
        - ProviderAlbum: Updated album object
        - LoadStageBResults: Whether Stage B should re-fetch
        - SkipQuickPrompts: Whether to show quick-mode prompts
        - CachedAlbums: Album cache (may be cleared)
        - CachedArtistId: Artist ID cache (may be cleared)
        - UseWhatIf: Updated WhatIf state
        - ReverseSource: Updated reverse state
        - SortMethod: Updated sort method
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Provider,
        
        [Parameter(Mandatory)]
        [object]$ProviderAlbum,
        
        [Parameter()]
        [object]$ProviderArtist,
        
        [Parameter()]
        [switch]$NonInteractive,
        
        [Parameter()]
        [switch]$Auto,
        
        [Parameter()]
        [double]$AutoConfidenceThreshold = 0.7,
        
        [Parameter()]
        [switch]$AutoSaveCover,
        
        [Parameter()]
        [switch]$AutoFallback,
        
        [Parameter()]
        [switch]$ReverseSource,
        
        [Parameter()]
        [string]$TargetFolder,
        
        [Parameter()]
        [string[]]$UpdateOnly = @('All'),
        
        [Parameter()]
        [switch]$UpdateMissingTracksOnly,
        
        [Parameter()]
        [switch]$GoC,
        
        [Parameter()]
        [bool]$UseWhatIf,
        
        [Parameter()]
        [scriptblock]$ShowHeader,
        
        [Parameter()]
        [object]$Config,
        
        [Parameter()]
        [string]$QuickArtist,
        
        [Parameter()]
        [string]$QuickAlbum,
        
        [Parameter()]
        [string]$Artist,
        
        [Parameter()]
        [string]$SortMethod = 'byFilesystem',

        [Parameter()]
        [hashtable]$Context
    )

    # --- Resolve context ---
    $ctx = $Context

    # Build default result hashtable (used as base for all returns)
    $defaultResult = @{
        NextStage          = 'AlbumDone'
        Provider           = $Provider
        ProviderAlbum      = $ProviderAlbum
        LoadStageBResults  = $true
        SkipQuickPrompts   = $true
        CachedAlbums       = $null
        CachedArtistId     = $null
        UseWhatIf          = $UseWhatIf
        ReverseSource      = [bool]$ReverseSource
        SortMethod         = $SortMethod
    }
    # Helper to build a return hashtable by merging overrides into default.
    $buildResult = {
        param([hashtable]$Overrides)
        $result = $defaultResult.Clone()
        foreach ($key in $Overrides.Keys) {
            $result[$key] = $Overrides[$key]
        }
        return $result
    }

    # --- Stage C Header ---
    if ($VerbosePreference -ne 'Continue') { Clear-Host }
    if ($ShowHeader) {
        & $ShowHeader -Provider $Provider -Artist $script:artist -AlbumName $script:albumName -TrackCount $script:trackCount
    }

    if ($ctx.FindMode -eq 'quick') {
        Write-Host "🔍 Find Mode: Quick Album Search" -ForegroundColor Magenta
    }
    else {
        Write-Host "🔍 Find Mode: Artist-First" -ForegroundColor Magenta
    }
    Write-Host ""

    if ($UseWhatIf) { $HostColor = 'Cyan' } else { $HostColor = 'Red' }

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

    # NonInteractive: skip interactive track-selection UI
    if ($NonInteractive) {
        Write-Warning "NonInteractive: skipping interactive track selection for album '$($ProviderAlbum.name)'."
        return (& $buildResult @{ NextStage = 'AlbumDone' })
    }

    # Initialize sort method
    if (-not $SortMethod) {
        $SortMethod = 'byFilesystem'
    }

    # Collect audio files and tags via shared helper
    $preserveOrder = ($SortMethod -eq 'byFilesystem')
    Write-Verbose "sortMethod = '$SortMethod' (preserveOrder = $preserveOrder)"
    $ctx.AudioFiles = Reload-OMAudioFiles -AlbumPath $ctx.Album.FullName -PreserveOrder:$preserveOrder
    Write-Verbose "Loaded $($ctx.AudioFiles.Count) audio files"

    # Check if any valid audio files were loaded
    $validAudioFiles = @($ctx.AudioFiles | Where-Object { $_ -ne $null })
    if ($validAudioFiles.Count -eq 0) {
        Write-Host "`n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Red
        Write-Host "⚠️  ERROR: No valid audio files found!" -ForegroundColor Red
        Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Red
        Write-Host "`nAlbum folder: $($ctx.Album.FullName)" -ForegroundColor Yellow
        Write-Host "All audio files were corrupted or invalid. Skipping this album." -ForegroundColor Yellow
        Write-Host "`nPress Enter to continue to next album..." -ForegroundColor Cyan
        Read-Host
        return (& $buildResult @{ NextStage = 'AlbumDone' })
    }

    # Update script:audioFiles to only contain valid files
    $ctx.AudioFiles = $validAudioFiles

    # --- Track fetching ---
    $tracksForAlbum = $null
    if (Get-IfExists $ProviderAlbum '_isCombined') {
        Write-Verbose "Using pre-fetched tracks from combined album"
        $tracksForAlbum = $ProviderAlbum._tracks
    }
    else {
        $albumIdToFetch = $ProviderAlbum.id

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

            # Extract album metadata from tracks
            if ($tracksForAlbum -and @($tracksForAlbum).Count -gt 0) {
                Write-Verbose "About to access first track..."
                try {
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
                        if ($null -eq (Get-IfExists $ProviderAlbum 'release_date')) {
                            $ProviderAlbum | Add-Member -NotePropertyName 'release_date' -NotePropertyValue $releaseDateFromTrack
                        } else {
                            $ProviderAlbum.release_date = $releaseDateFromTrack
                        }
                        Write-Verbose "Updated release date from track metadata: $releaseDateFromTrack"
                    }
                }

                if (-not (Get-IfExists $ProviderAlbum 'artist') -and -not (Get-IfExists $ProviderAlbum 'artists') -and -not (Get-IfExists $ProviderAlbum 'album_artist')) {
                    $albumArtistFromTrack = Get-IfExists $firstTrack 'album_artist'
                    if ($albumArtistFromTrack) {
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

                $canRetryReleases = (Get-IfExists $ProviderAlbum '_masterReleases') -and $ProviderAlbum._masterReleases.Count -gt 0
                $backPrompt = if ($canRetryReleases) { "'b' to try different release" } else { "'b' to go back to album selection" }

                $skipChoice = Read-Host "`nPress Enter to skip this album, $backPrompt, 'p' to change provider, or (?) help"
                if ($skipChoice -eq '?') {
                    Show-OMHelp -Context 'StageC-NoTracks'
                    return (& $buildResult @{ NextStage = 'C'; ProviderAlbum = $ProviderAlbum })
                }
                elseif ($skipChoice -eq 'b') {
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
                            return (& $buildResult @{ NextStage = 'B' })
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
                        return (& $buildResult @{ NextStage = 'C'; ProviderAlbum = $ProviderAlbum })
                    }
                    else {
                        return (& $buildResult @{ NextStage = 'B' })
                    }
                }
                elseif ($skipChoice -eq 'p') {
                    $defaultProvider = $Config.DefaultProvider
                    Write-Host "`nCurrent provider: $Provider (default: $defaultProvider)" -ForegroundColor Cyan
                    Write-Host "To switch providers, use: (ps)potify, (pq)obuz, (pd)iscogs, (pm)usicbrainz" -ForegroundColor Gray
                    return (& $buildResult @{ NextStage = 'C'; ProviderAlbum = $ProviderAlbum })
                }
                else {
                    # Skip this album
                    return (& $buildResult @{ NextStage = 'AlbumDone' })
                }
            }
        }
        catch {
            Write-Warning "Get-AlbumTracks failed: $_"
            $tracksForAlbum = @()

            $canRetryReleases = (Get-IfExists $ProviderAlbum '_masterReleases') -and $ProviderAlbum._masterReleases.Count -gt 0
            $backPrompt = if ($canRetryReleases) { "'b' to try different release" } else { "'b' for album selection" }

            if ($Auto -and $ctx.AutoModeActive) {
                Write-Host "⚠️  AUTO: Track fetch failed, skipping album..." -ForegroundColor Yellow
                return (& $buildResult @{ NextStage = 'AlbumDone' })
            }

            $skipChoice = Read-Host "Press Enter to skip, 'r' to retry, $backPrompt, 'p' to change provider, or (?) help"
            if ($skipChoice -eq '?') {
                Show-OMHelp -Context 'StageC-FetchFail'
                return (& $buildResult @{ NextStage = 'C'; ProviderAlbum = $ProviderAlbum })
            }
            elseif ($skipChoice -eq 'r') {
                Write-Host "Retrying..." -ForegroundColor Cyan
                return (& $buildResult @{ NextStage = 'C'; ProviderAlbum = $ProviderAlbum })
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
                        return (& $buildResult @{ NextStage = 'B' })
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

                    Write-Host "✓ Selected release: $($selectedRelease.id) - $($selectedRelease.title)" -ForegroundColor Green
                    $ProviderAlbum = @{
                        id                  = [string]$selectedRelease.id
                        name                = $selectedRelease.title
                        type                = 'release'
                        _resolvedFromMaster = $ProviderAlbum._resolvedFromMaster
                        _masterReleases     = $releases
                        _masterName         = $ProviderAlbum._masterName
                    }
                    return (& $buildResult @{ NextStage = 'C'; ProviderAlbum = $ProviderAlbum })
                }
                else {
                    return (& $buildResult @{ NextStage = 'B' })
                }
            }
            elseif ($skipChoice -eq 'p') {
                $defaultProvider = $Config.DefaultProvider
                Write-Host "`nCurrent provider: $Provider (default: $defaultProvider)" -ForegroundColor Cyan
                Write-Host "To switch providers, use: (ps)potify, (pq)obuz, (pd)iscogs, (pm)usicbrainz" -ForegroundColor Gray
                return (& $buildResult @{ NextStage = 'C'; ProviderAlbum = $ProviderAlbum })
            }
            else {
                # Skip this album
                return (& $buildResult @{ NextStage = 'AlbumDone' })
            }
        }
    }

    # --- Auto-prompt for ambiguous album artist (classical music) ---
    if (-not $NonInteractive -and -not $Auto -and $tracksForAlbum -and $tracksForAlbum.Count -gt 0) {
        $isAmbiguous = Assert-AlbumArtistAmbiguity -Artist $ProviderArtist -Album $ProviderAlbum -Tracks $tracksForAlbum
        if ($isAmbiguous) {
            Write-Host "`n⚠️  This classical album has ambiguous album artist assignment." -ForegroundColor Yellow
            $currentAlbumArtist = Get-IfExists $ProviderAlbum 'album_artist'
            if (-not $currentAlbumArtist) { $currentAlbumArtist = Get-IfExists $ProviderAlbum 'artist' }
            if (-not $currentAlbumArtist -and $ProviderArtist) {
                $currentAlbumArtist = Get-IfExists $ProviderArtist '_rawMusicBrainzObject' | Get-IfExists 'name'
                if (-not $currentAlbumArtist) { $currentAlbumArtist = Get-IfExists $ProviderArtist 'name' }
            }
            if ($currentAlbumArtist) {
                Write-Host "   Album artist from API: $currentAlbumArtist" -ForegroundColor Gray
            }
            Write-Host "   Multiple artists found in tracks" -ForegroundColor Gray
            Write-Host ""
            $response = Read-Host "Press 'a' to build custom album artist, or Enter to use automatic detection"
            if ($response -eq 'a') {
                $ctx.ManualAlbumArtist = Invoke-AlbumArtistBuilder -AlbumName $ProviderAlbum.name -Tracks $tracksForAlbum -CurrentAlbumArtist $ProviderArtist.name
                if ($ctx.ManualAlbumArtist) {
                    Write-Host "✓ Album artist set to: $ctx.ManualAlbumArtist" -ForegroundColor Green
                }
                else {
                    Write-Host "Skipped - will use automatic detection" -ForegroundColor Gray
                }
                Write-Host ""
            }
        }
    }

    # --- Sort method & debug output ---
    $SortMethod = 'byOrder'
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
    $ctx.PairedTracks = $null
    $ctx.RefreshTracks = $true
    $goCDisplayShown = $false

    # Local variables for state that may change during doTracks
    $loadStageBResults = $true
    $skipQuickPrompts = $true
    $cachedAlbums = $null
    $cachedArtistId = $null
    $artistQuery = $Artist
    $albumDone = $false
    $audioFiles = $ctx.AudioFiles

    # --- MissingTracks mode ---
    if ($UpdateMissingTracksOnly) {
        Write-Host "`n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
        Write-Host "🔍 MISSING TRACKS REPORT MODE" -ForegroundColor Magenta
        Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
        Write-Host ""

        $strategies = @('byOrder', 'byTitle', 'byDuration')
        $bestStrategy = $null
        $bestScore = 0
        $bestPairing = $null
        foreach ($strategy in $strategies) {
            $tempParam = @{
                SortMethod     = $strategy
                AudioFiles     = $ctx.AudioFiles
                ProviderTracks = $tracksForAlbum
            }
            $tempPairing = Set-Tracks @tempParam
            $highConfCount = @($tempPairing | Where-Object {
                $_.PSObject.Properties['ConfidenceLevel'] -and $_.ConfidenceLevel -eq 'High'
            }).Count
            if ($highConfCount -gt $bestScore) {
                $bestScore = $highConfCount
                $bestStrategy = $strategy
                $bestPairing = $tempPairing
            }
        }
        if ($bestPairing) { $ctx.PairedTracks = $bestPairing }

        $audioCount = @($ctx.AudioFiles).Count
        $providerCount = @($tracksForAlbum).Count

        if ($audioCount -ne $providerCount) {
            $unpairedProvider = @($ctx.PairedTracks | Where-Object { -not $_.AudioFile } | ForEach-Object { $_.ProviderTrack })
            $unpairedAudio = @($ctx.PairedTracks | Where-Object { -not $_.ProviderTrack } | ForEach-Object { $_.AudioFile })

            $formatDuration = {
                param([int]$ms)
                if ($ms -le 0) { return $null }
                $totalSec = [int][math]::Floor($ms / 1000)
                $min = [int][math]::Floor($totalSec / 60)
                $sec = [int]($totalSec % 60)
                return '{0}:{1:D2}' -f $min, $sec
            }

            $report = [ordered]@{
                date           = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss')
                album          = $ProviderAlbum.name
                artist         = $ProviderArtist.name
                year           = (Get-ReleaseYear -ReleaseDate (Get-IfExists $ProviderAlbum 'release_date'))
                provider       = $Provider
                albumId        = [string]$ProviderAlbum.id
                audioFileCount = $audioCount
                providerTrackCount = $providerCount
                audioFiles     = @($ctx.AudioFiles | ForEach-Object { Split-Path $_.FilePath -Leaf })
                providerTracks = @($tracksForAlbum | ForEach-Object {
                    [ordered]@{
                        disc     = [int]$_.disc_number
                        track    = [int]$_.track_number
                        name     = $_.name
                        duration = & $formatDuration $(if ($_.duration_ms) { [int]$_.duration_ms } else { 0 })
                        isrc     = if ($_.PSObject.Properties['isrc']) { $_.isrc } else { $null }
                    }
                })
                missingTracks  = @($unpairedProvider | ForEach-Object {
                    [ordered]@{
                        disc     = [int]$_.disc_number
                        track    = [int]$_.track_number
                        name     = $_.name
                        duration = & $formatDuration $(if ($_.duration_ms) { [int]$_.duration_ms } else { 0 })
                        isrc     = if ($_.PSObject.Properties['isrc']) { $_.isrc } else { $null }
                    }
                })
                extraAudioFiles = @($unpairedAudio | ForEach-Object { Split-Path $_.FilePath -Leaf })
            }

            $reportPath = Join-Path $ctx.Album.FullName '_errorreport.json'
            $report | ConvertTo-Json -Depth 4 | Out-File -FilePath $reportPath -Encoding UTF8
            Write-Host "Album: $($script:albumName)" -ForegroundColor Green
            Write-Host "Audio files: $audioCount | Provider tracks: $providerCount" -ForegroundColor Yellow
            Write-Host "Missing tracks: $($unpairedProvider.Count) | Extra files: $($unpairedAudio.Count)" -ForegroundColor Red
            Write-Host "Report written: $reportPath" -ForegroundColor Cyan
        }
        else {
            Write-Host "Album: $($script:albumName)" -ForegroundColor Green
            Write-Host "✓ All $audioCount tracks matched — no missing tracks." -ForegroundColor Green
        }

        Write-Host ""
        return (& $buildResult @{ NextStage = 'AlbumDone' })
    }

    # --- doTracks interactive loop ---
    Write-Verbose "DEBUG: Starting doTracks loop, script:pairedTracks is null: $($null -eq $ctx.PairedTracks)"
    :doTracks do {
        Write-Verbose "DEBUG: Inside doTracks, checking if we need to refresh..."
        if ($ctx.RefreshTracks -or -not $ctx.PairedTracks) {
            Write-Verbose "DEBUG: Will call Set-Tracks"
            if ($UseWhatIf) { $HostColor = 'Cyan' } else { $HostColor = 'Red' }
            $param = @{
                SortMethod    = $SortMethod
                AudioFiles    = $ctx.AudioFiles
                ProviderTracks = $tracksForAlbum
            }
            if ($ReverseSource) { $param.Reverse = $true }
            $ctx.PairedTracks = Set-Tracks @param

            # Sort paired tracks by confidence
            Write-Verbose "DEBUG: About to check confidence sorting... script:pairedTracks type: $($ctx.PairedTracks.GetType().Name), Count: $($ctx.PairedTracks.Count)"
            if ($ctx.PairedTracks -and $ctx.PairedTracks.Count -gt 0 -and $ctx.PairedTracks[0].PSObject.Properties['Confidence']) {
                $ctx.PairedTracks = $ctx.PairedTracks | Sort-Object Confidence -Descending
                Write-Verbose "Sorted $($ctx.PairedTracks.Count) tracks by confidence"
            }

            $ctx.RefreshTracks = $false
            if ($SortMethod -eq 'Manual') {
                $SortMethod = 'byOrder'
            }

            if ($GoC -and -not $goCDisplayShown) {
                if ($VerbosePreference -ne 'Continue') { Clear-Host }
                $autoReader = { param($prompt) 'q' }
                $autoShowParams = @{
                    PairedTracks  = $ctx.PairedTracks
                    AlbumName     = $ProviderAlbum.name
                    ProviderArtist = $ProviderArtist
                    ProviderAlbum = $ProviderAlbum
                }
                if ($ReverseSource) { $autoShowParams.Reverse = $true }
                if ($ctx.ShowVerbose) { $autoShowParams.Verbose = $true }
                Show-Tracks @autoShowParams -InputReader $autoReader | Out-Null
                $goCDisplayShown = $true
            }

            # AUTO MODE: Smart matching with best sort strategy
            if ($Auto -and $ctx.AutoModeActive -and -not $GoC) {
                Write-Host "🤖 AUTO: Analyzing track matches..." -ForegroundColor Cyan

                $strategies = @('byOrder', 'byTitle', 'byDuration')
                $bestStrategy = $null
                $bestScore = 0
                $bestPairing = $null

                foreach ($strategy in $strategies) {
                    $tempParam = @{
                        SortMethod    = $strategy
                        AudioFiles    = $ctx.AudioFiles
                        ProviderTracks = $tracksForAlbum
                    }
                    if ($ReverseSource) { $tempParam.Reverse = $true }
                    $tempPairing = Set-Tracks @tempParam

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

                if ($bestPairing) {
                    $ctx.PairedTracks = $bestPairing
                    $SortMethod = $bestStrategy
                }

                $totalTracks = $ctx.PairedTracks.Count
                $confidencePercent = if ($totalTracks -gt 0) {
                    [Math]::Round(($bestScore / $totalTracks) * 100, 0)
                } else { 0 }

                Write-Host "🤖 AUTO: Best strategy: '$bestStrategy' ($bestScore/$totalTracks matches, $confidencePercent% confidence)" -ForegroundColor Green

                # Check for track count mismatch
                $audioCount = @($ctx.AudioFiles).Count
                $providerCount = @($tracksForAlbum).Count
                if ($audioCount -ne $providerCount) {
                    Write-Warning "AUTO: Track count mismatch - $audioCount audio file(s) vs $providerCount provider track(s)"

                    $reportLines = @(
                        "Track Count Mismatch Report"
                        "=========================="
                        "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
                        "Album: $($ProviderAlbum.name)"
                        "Artist: $($ProviderArtist.name)"
                        "Provider: $Provider"
                        "Audio files: $audioCount"
                        "Provider tracks: $providerCount"
                        ""
                        "Audio files on disk:"
                    )
                    foreach ($af in $ctx.AudioFiles) {
                        $reportLines += "  - $(Split-Path $af.FilePath -Leaf)"
                    }
                    $reportLines += ""
                    $reportLines += "Provider tracks:"
                    foreach ($pt in $tracksForAlbum) {
                        $reportLines += "  - $($pt.disc_number).$($pt.track_number): $($pt.name)"
                    }

                    $unpairedProvider = @($ctx.PairedTracks | Where-Object { -not $_.AudioFile } | ForEach-Object { $_.ProviderTrack })
                    $unpairedAudio = @($ctx.PairedTracks | Where-Object { -not $_.ProviderTrack } | ForEach-Object { $_.AudioFile })
                    if ($unpairedProvider.Count -gt 0) {
                        $reportLines += ""
                        $reportLines += "Missing audio files (provider tracks without matching audio):"
                        foreach ($up in $unpairedProvider) {
                            $reportLines += "  - $($up.disc_number).$($up.track_number): $($up.name)"
                        }
                    }
                    if ($unpairedAudio.Count -gt 0) {
                        $reportLines += ""
                        $reportLines += "Extra audio files (no matching provider track):"
                        foreach ($ua in $unpairedAudio) {
                            $reportLines += "  - $(Split-Path $ua.FilePath -Leaf)"
                        }
                    }

                    $reportPath = Join-Path $ctx.Album.FullName "_errorreport.txt"
                    $reportLines | Out-File -FilePath $reportPath -Encoding UTF8

                    $formatDuration = {
                        param([int]$ms)
                        if ($ms -le 0) { return $null }
                        $totalSec = [int][math]::Floor($ms / 1000)
                        $min = [int][math]::Floor($totalSec / 60)
                        $sec = [int]($totalSec % 60)
                        return '{0}:{1:D2}' -f $min, $sec
                    }
                    $jsonReport = [ordered]@{
                        date               = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss')
                        album              = $ProviderAlbum.name
                        artist             = $ProviderArtist.name
                        year               = (Get-ReleaseYear -ReleaseDate (Get-IfExists $ProviderAlbum 'release_date'))
                        provider           = $Provider
                        albumId            = [string]$ProviderAlbum.id
                        audioFileCount     = $audioCount
                        providerTrackCount = $providerCount
                        audioFiles         = @($ctx.AudioFiles | ForEach-Object { Split-Path $_.FilePath -Leaf })
                        providerTracks     = @($tracksForAlbum | ForEach-Object {
                            [ordered]@{
                                disc     = [int]$_.disc_number
                                track    = [int]$_.track_number
                                name     = $_.name
                                duration = & $formatDuration $(if ($_.duration_ms) { [int]$_.duration_ms } else { 0 })
                                isrc     = if ($_.PSObject.Properties['isrc']) { $_.isrc } else { $null }
                            }
                        })
                        missingTracks      = @($unpairedProvider | ForEach-Object {
                            [ordered]@{
                                disc     = [int]$_.disc_number
                                track    = [int]$_.track_number
                                name     = $_.name
                                duration = & $formatDuration $(if ($_.duration_ms) { [int]$_.duration_ms } else { 0 })
                                isrc     = if ($_.PSObject.Properties['isrc']) { $_.isrc } else { $null }
                            }
                        })
                        extraAudioFiles    = @($unpairedAudio | ForEach-Object { Split-Path $_.FilePath -Leaf })
                    }
                    $jsonReportPath = Join-Path $ctx.Album.FullName '_errorreport.json'
                    $jsonReport | ConvertTo-Json -Depth 4 | Out-File -FilePath $jsonReportPath -Encoding UTF8

                    Write-Warning "AUTO: Error report written to: $reportPath"
                    Write-Warning "AUTO: Proceeding with matched tracks only."
                }

                if ($confidencePercent -ge ($AutoConfidenceThreshold * 100)) {
                    $updateModeText = if ($UpdateOnly -contains 'All') {
                        "auto-saving tags"
                    } else {
                        "auto-saving: $($UpdateOnly -join ', ')"
                    }
                    if ($AutoSaveCover -or $UpdateOnly -contains 'CoverArt') {
                        $updateModeText += " and cover"
                    }
                    Write-Host "✓ AUTO: Confidence threshold met, $updateModeText..." -ForegroundColor Green

                    $inputF = 'sa'
                    $GoC = $true
                }
                else {
                    Write-Warning "AUTO: Confidence too low ($confidencePercent%), falling back to interactive mode"
                    $ctx.AutoModeActive = $false
                }
            }
        }

        if ($GoC) {
            Write-Host "goC: auto-applying Save-All for album '$($ProviderAlbum.name)'." -ForegroundColor Yellow
            $inputF = 'sa'
        }
        elseif ($Auto -and $ctx.AutoModeActive -and $inputF -eq 'sa') {
            # Auto mode already set inputF to 'sa' above, proceed
        }
        else {
            if ($UseWhatIf) { $HostColor = 'Cyan' } else { $HostColor = 'Red' }
            $whatIfStatus = if ($UseWhatIf) { "ON" } else { "OFF" }
            $verboseStatus = if ($ctx.ShowVerbose) { "ON" } else { "OFF" }

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
                if ($_.Key -eq $SortMethod) { "[*$($_.Value)*]" } else { $_.Value }
            }) -join ', '

            $genreModeStatus = $ctx.GenreMode
            $optionsLine = "`nOptions: SortBy $sortMethodDisplay, (r)everse | (S)ave {[A]ll, [T]ags, [F]olderNames} | {C}over {[V]iew,[O]riginal,[S]ave,saveIn[T]ags} | (aa)AlbumArtist, (gm)GenreMode:$genreModeStatus, (rm)ReviewMarked, (b)ack/(pr)evious, (ni)NewItem, (P)rovider, (F)indmode, (w)hatIf:$whatIfStatus, (v)erbose:$verboseStatus, (X)ip"
            $commandList = @('o', 'd', 't', 'n', 'l', 'h', 'm', 'r', 'rm', 'sa', 'st', 'sf', 'cv', 'cvo', 'cs', 'ct', 'aa', 'gm', 'b', 'pr', 'ni', 'p', 'pq', 'ps', 'pd', 'pm', 'f', 'w', 'whatif', 'v', 'x')
            $paramshow = @{
                PairedTracks  = $ctx.PairedTracks
                AlbumName     = $ProviderAlbum.name
                ProviderArtist = $ProviderArtist
                ProviderAlbum = $ProviderAlbum
                OptionsText   = $optionsLine
                ValidCommands = $commandList
                PromptColor   = $HostColor
                ProviderName  = $Provider
                SortMethod    = $SortMethod
            }
            if ($ReverseSource) { $paramshow.Reverse = $true }
            if ($ctx.ShowVerbose) { $paramshow.Verbose = $true }
            if ($VerbosePreference -ne 'Continue') { Clear-Host }
            $inputF = Show-Tracks @paramshow

            if ($null -eq $inputF) { continue }
            if ($inputF -eq 'q') {
                Write-Host $optionsLine -ForegroundColor $HostColor
                $inputF = Read-Host "Select tracks(or option):"
            }
        }

        switch -Regex ($inputF) {
            '^\?$' {
                Show-OMHelp -Context 'StageC'
                continue
            }
            '^o$' { $SortMethod = 'byOrder'; $ctx.RefreshTracks = $true; continue }
            '^d$' { $SortMethod = 'byDuration'; $ctx.RefreshTracks = $true; continue }
            '^t$' { $SortMethod = 'byTrackNumber'; $ctx.RefreshTracks = $true; continue }
            '^n$' { $SortMethod = 'byName'; $ctx.RefreshTracks = $true; continue }
            '^l$' { $SortMethod = 'byTitle'; $ctx.RefreshTracks = $true; continue }
            '^h$' { $SortMethod = 'Hybrid'; $ctx.RefreshTracks = $true; continue }
            '^m$' { $SortMethod = 'Manual'; $ctx.RefreshTracks = $true; continue }
            '^f$' { $SortMethod = 'byFilesystem'; $ctx.RefreshTracks = $true; continue }
            '^r$' { $ReverseSource = -not $ReverseSource; $ctx.RefreshTracks = $true; continue }
            '^rm$' {
                # Review marked tracks in Manual mode, or all tracks if none marked
                $markedTracks = @($ctx.PairedTracks | Where-Object { $_.PSObject.Properties['Marked'] -and $_.Marked })

                $reviewAll = $false
                if ($markedTracks.Count -eq 0) {
                    $reviewAll = $true
                    $markedTracks = @($ctx.PairedTracks | Where-Object { $_.AudioFile })
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

                if ($reviewAll) {
                    $providerTrackPool = @($tracksForAlbum)
                }
                else {
                    $providerTrackPool = @($markedTracks | Where-Object { $_.ProviderTrack } | ForEach-Object { $_.ProviderTrack })
                }

                if ($providerTrackPool.Count -eq 0) {
                    Write-Host "No provider tracks available to choose from." -ForegroundColor Yellow
                    Start-Sleep -Seconds 2
                    continue
                }

                foreach ($markedTrack in $markedTracks) {
                    if (-not $markedTrack.AudioFile) { continue }
                    if ($providerTrackPool.Count -eq 0) {
                        Write-Host "No more provider tracks in pool." -ForegroundColor Yellow
                        break
                    }

                    if ($VerbosePreference -ne 'Continue') { Clear-Host }
                    Write-Host "🔖 Select correct match for:" -ForegroundColor Cyan

                    $audioDurationStr = if ($markedTrack.AudioFile.Duration) {
                        $audioDurationSpan = [TimeSpan]::FromMilliseconds($markedTrack.AudioFile.Duration)
                        "{0:mm\:ss}" -f $audioDurationSpan
                    } else {
                        "00:00"
                    }

                    Write-Host "   $(Split-Path -Leaf $markedTrack.AudioFile.FilePath) ($audioDurationStr)" -ForegroundColor Yellow
                    Write-Host ""

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

                    for ($i = 0; $i -lt $scoredPool.Count; $i++) {
                        $scored = $scoredPool[$i]
                        $track = $scored.Track
                        $num = $i + 1

                        $disc = if ($value = Get-IfExists $track 'disc_number') { $value } else { 1 }
                        $trackNum = if ($value = Get-IfExists $track 'track_number') { $value } else { 0 }
                        $durationMs = if ($value = Get-IfExists $track 'duration_ms') { $value } elseif ($value = Get-IfExists $track 'duration') { $value } else { 0 }
                        $durationSpan = [TimeSpan]::FromMilliseconds($durationMs)
                        $durationStr = "{0:mm\:ss}" -f $durationSpan

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

                            for ($i = 0; $i -lt $ctx.PairedTracks.Count; $i++) {
                                if ($ctx.PairedTracks[$i].AudioFile -and
                                    $ctx.PairedTracks[$i].AudioFile.FilePath -eq $markedTrack.AudioFile.FilePath) {
                                    $ctx.PairedTracks[$i].ProviderTrack = $selectedTrack
                                    if ($ctx.PairedTracks[$i].PSObject.Properties['Marked']) {
                                        $ctx.PairedTracks[$i].Marked = $false
                                    }
                                    Write-Host "✓ Updated" -ForegroundColor Green

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
                $ctx.RefreshTracks = $true
                continue
            }
            '^gm$' {
                $ctx.GenreMode = if ($ctx.GenreMode -eq 'Replace') { 'Merge' } else { 'Replace' }
                $modeColor = if ($ctx.GenreMode -eq 'Merge') { 'Cyan' } else { 'Green' }
                Write-Host "`n✓ Genre Mode: $($ctx.GenreMode)" -ForegroundColor $modeColor
                if ($ctx.GenreMode -eq 'Merge') {
                    Write-Host "   Genres will be merged with existing tags (deduplicated)" -ForegroundColor Gray
                } else {
                    Write-Host "   Genres will replace existing tags" -ForegroundColor Gray
                }
                Start-Sleep -Seconds 2
                $ctx.RefreshTracks = $true
                continue
            }
            '^v$' { $ctx.ShowVerbose = -not $ctx.ShowVerbose; $ctx.RefreshTracks = $true; continue }
            '^aa$' {
                if ($tracksForAlbum -and $tracksForAlbum.Count -gt 0) {
                    $ctx.ManualAlbumArtist = Invoke-AlbumArtistBuilder -AlbumName $ProviderAlbum.name -Tracks $tracksForAlbum -CurrentAlbumArtist $ProviderArtist.name
                    if ($ctx.ManualAlbumArtist) {
                        Write-Host "`n✓ Album artist set to: $ctx.ManualAlbumArtist" -ForegroundColor Green
                        $ctx.RefreshTracks = $true
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
                $ctx.ManualAlbumArtist = $null
                if ($ctx.FindMode -eq 'quick') {
                    $loadStageBResults = $false
                    $skipQuickPrompts = $false
                    $ctx.BackNavigationMode = $true
                }
                else {
                    $loadStageBResults = $false
                }
                return (& $buildResult @{
                    NextStage = 'B'
                    LoadStageBResults = $loadStageBResults
                    SkipQuickPrompts = $skipQuickPrompts
                    SortMethod = $SortMethod
                    ReverseSource = [bool]$ReverseSource
                    UseWhatIf = $UseWhatIf
                })
            }
            '^ni$' {
                # New Item: prompt for new artist/album and go back to search
                $ctx.ManualAlbumArtist = $null
                $res = Read-ArtistAlbum -DefaultArtist $QuickArtist -DefaultAlbum $QuickAlbum
                $overrides = @{
                    NextStage = 'B'
                    LoadStageBResults = $false
                    SkipQuickPrompts = $true
                    SortMethod = $SortMethod
                    ReverseSource = [bool]$ReverseSource
                    UseWhatIf = $UseWhatIf
                }
                if ($res.ChangedArtist) { $overrides.NewArtist = $res.Artist }
                if ($res.ChangedAlbum) { $overrides.NewAlbum = $res.Album }
                $ctx.BackNavigationMode = $false
                return (& $buildResult $overrides)
            }
            '^pr$' {
                $ctx.ManualAlbumArtist = $null
                if ($ctx.FindMode -eq 'quick') {
                    $loadStageBResults = $false
                    $skipQuickPrompts = $false
                    $ctx.BackNavigationMode = $true
                }
                else {
                    $loadStageBResults = $false
                }
                return (& $buildResult @{
                    NextStage = 'B'
                    LoadStageBResults = $loadStageBResults
                    SkipQuickPrompts = $skipQuickPrompts
                    SortMethod = $SortMethod
                    ReverseSource = [bool]$ReverseSource
                    UseWhatIf = $UseWhatIf
                })
            }
            '^p$' {
                $defaultProvider = $Config.DefaultProvider
                Write-Host "`nCurrent provider: $Provider (default: $defaultProvider)" -ForegroundColor Cyan
                Write-Host "To switch providers, use: (ps)potify, (pq)obuz, (pd)iscogs, (pm)usicbrainz" -ForegroundColor Gray
                continue
            }
            '^f$' {
                if ($ctx.FindMode -eq 'quick') {
                    $ctx.FindMode = 'artist-first'
                    Write-Host "✓ Switched to Artist-First Search mode" -ForegroundColor Green
                    $cachedAlbums = $null
                    $cachedArtistId = $null
                    $artistQuery = $Artist
                    $ProviderArtist = $null
                    $ProviderAlbum = $null
                }
                else {
                    $ctx.FindMode = 'quick'
                    $skipQuickPrompts = $false
                    Write-Host "✓ Switched to Quick Album Search mode" -ForegroundColor Green
                }
                return (& $buildResult @{
                    NextStage = 'A'
                    CachedAlbums = $cachedAlbums
                    CachedArtistId = $cachedArtistId
                    SkipQuickPrompts = $skipQuickPrompts
                    SortMethod = $SortMethod
                    ReverseSource = [bool]$ReverseSource
                    UseWhatIf = $UseWhatIf
                })
            }
            '^whatif$|^w$' {
                $UseWhatIf = -not $UseWhatIf
                $ctx.RefreshTracks = $true
                continue
            }
            '^x(ip)?$' {
                # Write error report if track count mismatch before skipping
                $xAudioCount = @($ctx.AudioFiles).Count
                $xProviderCount = @($tracksForAlbum).Count
                if ($xAudioCount -ne $xProviderCount) {
                    $xUnpairedProvider = @($ctx.PairedTracks | Where-Object { -not $_.AudioFile } | ForEach-Object { $_.ProviderTrack })
                    $xUnpairedAudio = @($ctx.PairedTracks | Where-Object { -not $_.ProviderTrack } | ForEach-Object { $_.AudioFile })
                    $formatDuration = {
                        param([int]$ms)
                        if ($ms -le 0) { return $null }
                        $totalSec = [int][math]::Floor($ms / 1000)
                        $min = [int][math]::Floor($totalSec / 60)
                        $sec = [int]($totalSec % 60)
                        return '{0}:{1:D2}' -f $min, $sec
                    }
                    $jsonReport = [ordered]@{
                        date               = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss')
                        album              = $ProviderAlbum.name
                        artist             = $ProviderArtist.name
                        year               = (Get-ReleaseYear -ReleaseDate (Get-IfExists $ProviderAlbum 'release_date'))
                        provider           = $Provider
                        albumId            = [string]$ProviderAlbum.id
                        audioFileCount     = $xAudioCount
                        providerTrackCount = $xProviderCount
                        audioFiles         = @($ctx.AudioFiles | ForEach-Object { Split-Path $_.FilePath -Leaf })
                        providerTracks     = @($tracksForAlbum | ForEach-Object {
                            [ordered]@{
                                disc     = [int]$_.disc_number
                                track    = [int]$_.track_number
                                name     = $_.name
                                duration = & $formatDuration $(if ($_.duration_ms) { [int]$_.duration_ms } else { 0 })
                                isrc     = if ($_.PSObject.Properties['isrc']) { $_.isrc } else { $null }
                            }
                        })
                        missingTracks      = @($xUnpairedProvider | ForEach-Object {
                            [ordered]@{
                                disc     = [int]$_.disc_number
                                track    = [int]$_.track_number
                                name     = $_.name
                                duration = & $formatDuration $(if ($_.duration_ms) { [int]$_.duration_ms } else { 0 })
                                isrc     = if ($_.PSObject.Properties['isrc']) { $_.isrc } else { $null }
                            }
                        })
                        extraAudioFiles    = @($xUnpairedAudio | ForEach-Object { Split-Path $_.FilePath -Leaf })
                        skipped            = $true
                    }
                    $jsonReportPath = Join-Path $ctx.Album.FullName '_errorreport.json'
                    $jsonReport | ConvertTo-Json -Depth 4 | Out-File -FilePath $jsonReportPath -Encoding UTF8
                    Write-Host "⚠️  Track mismatch: $xAudioCount audio file(s) vs $xProviderCount provider track(s)" -ForegroundColor Yellow
                    Write-Host "   Report: $jsonReportPath" -ForegroundColor Cyan
                }
                return (& $buildResult @{
                    NextStage = 'AlbumDone'
                    SortMethod = $SortMethod
                    ReverseSource = [bool]$ReverseSource
                    UseWhatIf = $UseWhatIf
                })
            }
            '^sf$' {
                $oldpath = $ctx.Album.FullName
                $moveResult = Invoke-OMFolderRename `
                    -AlbumPath $oldpath `
                    -ProviderAlbum $ProviderAlbum `
                    -ProviderArtist $ProviderArtist `
                    -AudioFiles $audioFiles `
                    -AlbumNameFallback $script:albumName `
                    -ManualAlbumArtist $ctx.ManualAlbumArtist `
                    -UseWhatIf $UseWhatIf
                $ctx.TargetFolderMoved = $false
                Invoke-HandleMoveSuccess -MoveResult $moveResult -UseWhatIf $UseWhatIf -OldPath $oldpath `
                    -TargetFolder $TargetFolder -NonInteractive:$NonInteractive -GoC:$GoC -Context $ctx
                if ($ctx.TargetFolderMoved) {
                    return (& $buildResult @{
                        NextStage = 'AlbumDone'
                        SortMethod = $SortMethod
                        ReverseSource = [bool]$ReverseSource
                        UseWhatIf = $UseWhatIf
                    })
                }
                continue doTracks
            }
            '^st\s+(?<range>.+)$' {
                if (-not $ctx.PairedTracks -or $ctx.PairedTracks.Count -eq 0) {
                    Write-Warning "No track matches available to save."
                    continue doTracks
                }

                $rangeText = $matches['range'].Trim()
                if (-not $rangeText) {
                    Write-Warning "No track numbers provided for 'st' command."
                    continue doTracks
                }

                try {
                    $selectedIndices = Expand-SelectionRange -RangeText $rangeText -MaxIndex $ctx.PairedTracks.Count
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
                    $saveResult = Save-OMTrackSelection -PairedTracks $ctx.PairedTracks -SelectedIndices $selectedIndices -ProviderArtist $ProviderArtist -ProviderAlbum $ProviderAlbum -UseWhatIf:$UseWhatIf
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
                $tracksForAlbum = $saveResult.UpdatedProviderTracks

                if ($saveResult.SavedDetails.Count -gt 0) {
                    Write-Host ("✓ Processed {0} track(s). Remaining: {1}" -f $saveResult.SavedDetails.Count, $ctx.PairedTracks.Count) -ForegroundColor Green
                }
                else {
                    Write-Host "No tracks were updated." -ForegroundColor Yellow
                }

                $ctx.RefreshTracks = $false
                continue doTracks
            }
            '^st$' {
                try {
                    Save-OMTagsLoop -PairedTracks $ctx.PairedTracks `
                        -ProviderArtist $ProviderArtist `
                        -ProviderAlbum $ProviderAlbum `
                        -ManualAlbumArtist $ctx.ManualAlbumArtist `
                        -GenreMode $ctx.GenreMode `
                        -UseWhatIf:$UseWhatIf

                    if (-not $UseWhatIf) {
                        foreach ($af in $audioFiles) {
                            if ($af.TagFile) {
                                try { $af.TagFile.Dispose() } catch { Write-Verbose "Failed disposing TagFile: $_" }
                                $af.TagFile = $null
                            }
                        }
                        $audioFiles = Reload-OMAudioFiles -AlbumPath $ctx.Album.FullName
                        $ctx.RefreshTracks = $true
                    }
                    continue doTracks
                }
                catch {
                    Write-Host '---- ERROR in save-tags (st) handler ----' -ForegroundColor Red
                    Write-Host "Message: $($_.Exception.Message)"
                    Write-Host "Exception: $($_ | Out-String)"
                    Write-Host "ScriptStackTrace: $($_.ScriptStackTrace)"
                    return (& $buildResult @{
                        NextStage = 'C'
                        ProviderAlbum = $ProviderAlbum
                        SortMethod = $SortMethod
                        ReverseSource = [bool]$ReverseSource
                        UseWhatIf = $UseWhatIf
                    })
                }
            }
            '^sa$' {
                $coverArtOnlyMode = ($UpdateOnly.Count -eq 1 -and $UpdateOnly[0] -eq 'CoverArt')
                $shouldSaveCoverArt = ($UpdateOnly -contains 'CoverArt' -or $AutoSaveCover)

                if ($UpdateOnly -notcontains 'All') {
                    Write-Host "ℹ️  UpdateOnly mode: $($UpdateOnly -join ', ')" -ForegroundColor Cyan
                }

                if ($shouldSaveCoverArt) {
                    $coverUrl = Get-IfExists $ProviderAlbum 'cover_url'
                    Write-Host "🖼️  Saving cover art..." -ForegroundColor Cyan
                    $config = Get-OMConfig
                    $maxSize = $config.CoverArt.FolderImageSize
                    # Save cover to the directory containing audio files (may differ from $ctx.Album.FullName
                    # when a wrapper folder exists, e.g. Artist\Album\Album - Artist\*.flac)
                    $coverSavePath = $ctx.Album.FullName
                    if ($ctx.AudioFiles -and $ctx.AudioFiles.Count -gt 0) {
                        $audioDir = Split-Path $ctx.AudioFiles[0].FilePath -Parent
                        if ($audioDir -and $audioDir -ne $ctx.Album.FullName) {
                            $coverSavePath = $audioDir
                            Write-Verbose "Cover art save path adjusted to audio file directory: $coverSavePath"
                        }
                    }
                    $null = Save-CoverArtWithFallback -CoverUrl $coverUrl -AlbumPath $coverSavePath `
                        -MaxSize $maxSize -Provider $Provider `
                        -AlbumName $QuickAlbum -ArtistName $QuickArtist `
                        -AutoFallback:$AutoFallback -UseWhatIf:$UseWhatIf
                }

                if (-not $coverArtOnlyMode) {
                    Save-OMTagsLoop -PairedTracks $ctx.PairedTracks `
                        -ProviderArtist $ProviderArtist `
                        -ProviderAlbum $ProviderAlbum `
                        -ManualAlbumArtist $ctx.ManualAlbumArtist `
                        -GenreMode $ctx.GenreMode `
                        -UseWhatIf:$UseWhatIf `
                        -UpdateOnly $UpdateOnly `
                        -RequireBothPaired
                }

                # Write JSON error report if track count mismatch
                $saAudioCount = @($ctx.AudioFiles).Count
                $saProviderCount = @($tracksForAlbum).Count
                if ($saAudioCount -ne $saProviderCount) {
                    $saUnpairedProvider = @($ctx.PairedTracks | Where-Object { -not $_.AudioFile } | ForEach-Object { $_.ProviderTrack })
                    $saUnpairedAudio = @($ctx.PairedTracks | Where-Object { -not $_.ProviderTrack } | ForEach-Object { $_.AudioFile })
                    $formatDuration = {
                        param([int]$ms)
                        if ($ms -le 0) { return $null }
                        $totalSec = [int][math]::Floor($ms / 1000)
                        $min = [int][math]::Floor($totalSec / 60)
                        $sec = [int]($totalSec % 60)
                        return '{0}:{1:D2}' -f $min, $sec
                    }
                    $jsonReport = [ordered]@{
                        date               = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss')
                        album              = $ProviderAlbum.name
                        artist             = $ProviderArtist.name
                        year               = (Get-ReleaseYear -ReleaseDate (Get-IfExists $ProviderAlbum 'release_date'))
                        provider           = $Provider
                        albumId            = [string]$ProviderAlbum.id
                        audioFileCount     = $saAudioCount
                        providerTrackCount = $saProviderCount
                        audioFiles         = @($ctx.AudioFiles | ForEach-Object { Split-Path $_.FilePath -Leaf })
                        providerTracks     = @($tracksForAlbum | ForEach-Object {
                            [ordered]@{
                                disc     = [int]$_.disc_number
                                track    = [int]$_.track_number
                                name     = $_.name
                                duration = & $formatDuration $(if ($_.duration_ms) { [int]$_.duration_ms } else { 0 })
                                isrc     = if ($_.PSObject.Properties['isrc']) { $_.isrc } else { $null }
                            }
                        })
                        missingTracks      = @($saUnpairedProvider | ForEach-Object {
                            [ordered]@{
                                disc     = [int]$_.disc_number
                                track    = [int]$_.track_number
                                name     = $_.name
                                duration = & $formatDuration $(if ($_.duration_ms) { [int]$_.duration_ms } else { 0 })
                                isrc     = if ($_.PSObject.Properties['isrc']) { $_.isrc } else { $null }
                            }
                        })
                        extraAudioFiles    = @($saUnpairedAudio | ForEach-Object { Split-Path $_.FilePath -Leaf })
                    }
                    $jsonReportPath = Join-Path $ctx.Album.FullName '_errorreport.json'
                    $jsonReport | ConvertTo-Json -Depth 4 | Out-File -FilePath $jsonReportPath -Encoding UTF8
                    Write-Host "⚠️  Track mismatch: $saAudioCount audio file(s) vs $saProviderCount provider track(s)" -ForegroundColor Yellow
                    Write-Host "   Missing: $($saUnpairedProvider.Count) | Extra: $($saUnpairedAudio.Count)" -ForegroundColor Yellow
                    Write-Host "   Report: $jsonReportPath" -ForegroundColor Cyan
                }

                if ($coverArtOnlyMode) {
                    Write-Host "✓ Cover art update complete." -ForegroundColor Green
                    return (& $buildResult @{ NextStage = 'AlbumDone'; SortMethod = $SortMethod; ReverseSource = [bool]$ReverseSource; UseWhatIf = $UseWhatIf })
                }

                # Dispose TagFile handles when applying changes
                if (-not $UseWhatIf) {
                    foreach ($a in $audioFiles) {
                        if ($value = Get-IfExists $a 'TagFile') {
                            try { $value.Dispose() } catch { Write-Verbose "Failed disposing TagFile for $($a.FilePath): $_" }
                            $a.TagFile = $null
                        }
                    }
                }
                else {
                    Write-Verbose "Preview: keeping TagFile handles open so interactive UI can display tags."
                }
                $oldpath = $ctx.Album.FullName
                $shouldRenameFolder = ($UpdateOnly -contains 'All') -or
                    ($UpdateOnly -contains 'Year') -or
                    ($UpdateOnly -contains 'AlbumArtist') -or
                    ($UpdateOnly -contains 'Album')

                if ($shouldRenameFolder) {
                    $moveResult = Invoke-OMFolderRename `
                        -AlbumPath $oldpath `
                        -ProviderAlbum $ProviderAlbum `
                        -ProviderArtist $ProviderArtist `
                        -AudioFiles $audioFiles `
                        -AlbumNameFallback $script:albumName `
                        -ManualAlbumArtist $ctx.ManualAlbumArtist `
                        -UseWhatIf $UseWhatIf `
                        -SkipTagReading:$UseWhatIf
                    $ctx.TargetFolderMoved = $false
                    Invoke-HandleMoveSuccess -MoveResult $moveResult -UseWhatIf $UseWhatIf -OldPath $oldpath `
                        -TargetFolder $TargetFolder -NonInteractive:$NonInteractive -GoC:$GoC -Context $ctx

                    if ($ctx.TargetFolderMoved) {
                        return (& $buildResult @{ NextStage = 'AlbumDone'; SortMethod = $SortMethod; ReverseSource = [bool]$ReverseSource; UseWhatIf = $UseWhatIf })
                    }

                    # Reload audio files if not WhatIf and folder wasn't moved
                    if (-not $UseWhatIf -and $moveResult -and $moveResult.NewAlbumPath -eq $oldpath) {
                        Write-Verbose "Reloading audio files to reflect saved tags (folder not moved)"
                        $ctx.AudioFiles = Reload-OMAudioFiles -AlbumPath $ctx.Album.FullName

                        if ($ctx.PairedTracks -and $ctx.PairedTracks.Count -gt 0) {
                            for ($i = 0; $i -lt [Math]::Min($ctx.PairedTracks.Count, $ctx.AudioFiles.Count); $i++) {
                                $ctx.PairedTracks[$i].AudioFile = $ctx.AudioFiles[$i]
                            }
                        }
                        $ctx.RefreshTracks = $true
                    }
                } else {
                    if (-not $UseWhatIf) {
                        $ctx.AudioFiles = Reload-OMAudioFiles -AlbumPath $ctx.Album.FullName
                        if ($ctx.PairedTracks -and $ctx.PairedTracks.Count -gt 0) {
                            for ($i = 0; $i -lt [Math]::Min($ctx.PairedTracks.Count, $ctx.AudioFiles.Count); $i++) {
                                $ctx.PairedTracks[$i].AudioFile = $ctx.AudioFiles[$i]
                            }
                        }
                    }
                    Write-Host "✓ Tags updated ($($UpdateOnly -join ', '))." -ForegroundColor Green
                }

                # AUTO MODE: Skip to next album after successful save
                if ($Auto -and $ctx.AutoModeActive) {
                    Write-Host "✓ AUTO: Album completed successfully, moving to next album..." -ForegroundColor Green
                    return (& $buildResult @{ NextStage = 'AlbumDone'; SortMethod = $SortMethod; ReverseSource = [bool]$ReverseSource; UseWhatIf = $UseWhatIf })
                }

                # Interactive mode: save-all is done, advance to next album
                if (-not $UseWhatIf) {
                    return (& $buildResult @{ NextStage = 'AlbumDone'; SortMethod = $SortMethod; ReverseSource = [bool]$ReverseSource; UseWhatIf = $UseWhatIf })
                }

                continue
            }

            '^(\d+(?:\.\.\d+|\-\d+)) (\+?\w+) (.+)$' {
                # Range-tag command
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

                $isAdd = $tagName.StartsWith('+')
                $actualTagName = if ($isAdd) { $tagName.Substring(1) } else { $tagName }

                $validTags = @('composer', 'genre', 'artist', 'albumartist', 'title')
                if ($actualTagName -notin $validTags) {
                    Write-Warning "Unsupported tag: $actualTagName (supported: $($validTags -join ', '))"
                    continue
                }

                foreach ($idx in $indices) {
                    $trackIdx = $idx - 1
                    $providerTrack = $tracksForAlbum[$trackIdx]
                    $audioFile = $audioFiles[$trackIdx]
                    $filePath = $audioFile.FilePath

                    $existingValue = $null
                    if ($isAdd) {
                        try {
                            $currentTagFile = [TagLib.File]::Create($filePath)
                            try {
                                $existingValue = switch ($actualTagName) {
                                    'composer' { $currentTagFile.Tag.Composers -join '; ' }
                                    'genre' { $currentTagFile.Tag.Genres -join '; ' }
                                    'artist' { $currentTagFile.Tag.Performers -join '; ' }
                                    'albumartist' { $currentTagFile.Tag.AlbumArtists -join '; ' }
                                    'title' { $currentTagFile.Tag.Title }
                                    default { $null }
                                }
                            }
                            finally {
                                $currentTagFile.Dispose()
                            }
                        }
                        catch {
                            Write-Verbose "Could not read existing tag for $filePath`: $_"
                        }
                    }

                    $newValue = if ($isAdd -and $existingValue) {
                        "$existingValue; $tagValue"
                    }
                    else {
                        $tagValue
                    }

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

                    $res = Save-TagsForFile -FilePath $filePath -TagValues $tags -WhatIf:$UseWhatIf
                    if ($res.Success) {
                        Write-Host ("Updated tag '$actualTagName' for track $idx ($($providerTrack.Title)): '$newValue'") -ForegroundColor Green
                    }
                    else {
                        Write-Warning ("Failed to update tag for track $($idx): $($res.Reason)")
                    }
                }

                return (& $buildResult @{ NextStage = 'AlbumDone'; SortMethod = $SortMethod; ReverseSource = [bool]$ReverseSource; UseWhatIf = $UseWhatIf })
            }
            '^pq$' {
                $Provider = 'Qobuz'
                Write-Host "Switched to provider: Qobuz" -ForegroundColor Green
                return (& $buildResult @{
                    NextStage = 'A'
                    Provider = $Provider
                    CachedAlbums = $null
                    CachedArtistId = $null
                    SortMethod = $SortMethod
                    ReverseSource = [bool]$ReverseSource
                    UseWhatIf = $UseWhatIf
                })
            }
            '^ps$' {
                $Provider = 'Spotify'
                Write-Host "Switched to provider: Spotify" -ForegroundColor Green
                return (& $buildResult @{
                    NextStage = 'A'
                    Provider = $Provider
                    CachedAlbums = $null
                    CachedArtistId = $null
                    SortMethod = $SortMethod
                    ReverseSource = [bool]$ReverseSource
                    UseWhatIf = $UseWhatIf
                })
            }
            '^pd$' {
                $Provider = 'Discogs'
                Write-Host "Switched to provider: Discogs" -ForegroundColor Green
                return (& $buildResult @{
                    NextStage = 'A'
                    Provider = $Provider
                    CachedAlbums = $null
                    CachedArtistId = $null
                    SortMethod = $SortMethod
                    ReverseSource = [bool]$ReverseSource
                    UseWhatIf = $UseWhatIf
                })
            }
            '^pm$' {
                $Provider = 'MusicBrainz'
                Write-Host "Switched to provider: MusicBrainz" -ForegroundColor Green
                return (& $buildResult @{
                    NextStage = 'A'
                    Provider = $Provider
                    CachedAlbums = $null
                    CachedArtistId = $null
                    SortMethod = $SortMethod
                    ReverseSource = [bool]$ReverseSource
                    UseWhatIf = $UseWhatIf
                })
            }
            '^cvo(\d*)$' {
                $rangeText = $matches[1]
                if (-not $rangeText) { $rangeText = "1" }
                    Write-Verbose "Stage B cvo: Show-CoverArt called with Size='original' Grid='False' Album= $($ProviderAlbum.name)"
                    Show-CoverArt -Album $ProviderAlbum -RangeText $rangeText -Provider $Provider -Size 'original' -Grid $false
                Read-Host "Press Enter to continue..."
                continue
            }
            '^cv(\d*)$' {
                $rangeText = $matches[1]
                if (-not $rangeText) { $rangeText = "1" }
                Write-Verbose "Stage B cv: Show-CoverArt called with Size='original' Grid='False' Album= $($ProviderAlbum.name)"
                Show-CoverArt -Album $ProviderAlbum -RangeText $rangeText -Provider $Provider -Size 'original' -Grid $false -LoopLabel 'stageLoop'
                Read-Host "Press Enter to continue..."
                continue
            }
            '^cs(\d*)$' {
                $coverUrl = Get-IfExists $ProviderAlbum 'cover_url'

                if ($coverUrl) {
                    $maxSize = $Config.CoverArt.FolderImageSize
                    # Save cover to the directory containing audio files
                    $csCoverPath = $ctx.Album.FullName
                    if ($ctx.AudioFiles -and $ctx.AudioFiles.Count -gt 0) {
                        $csAudioDir = Split-Path $ctx.AudioFiles[0].FilePath -Parent
                        if ($csAudioDir -and $csAudioDir -ne $ctx.Album.FullName) { $csCoverPath = $csAudioDir }
                    }
                    $result = Save-CoverArt -CoverUrl $coverUrl -AlbumPath $csCoverPath -Action SaveToFolder -MaxSize $maxSize -WhatIf:$UseWhatIf
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
                $coverUrl = Get-IfExists $ProviderAlbum 'cover_url'

                if ($coverUrl) {
                    $maxSize = $Config.CoverArt.TagImageSize
                    $result = Invoke-OMCoverArtEmbed -AlbumPath $ctx.Album.FullName -CoverUrl $coverUrl -MaxSize $maxSize -UseWhatIf:$UseWhatIf
                    if ($null -eq $result) {
                        # Warning already shown by Invoke-OMCoverArtEmbed
                    }
                    elseif (-not $result.Success) {
                        Write-Warning "Failed to embed cover art: $($result.Error)"
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

    # Fallback return (should only be reached if doTracks exits without a return)
    return (& $buildResult @{
        NextStage = if ($albumDone) { 'AlbumDone' } else { 'C' }
        SortMethod = $SortMethod
        ReverseSource = [bool]$ReverseSource
        UseWhatIf = $UseWhatIf
    })
}
