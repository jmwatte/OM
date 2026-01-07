function Invoke-OMQuickFind {
    <#
    .SYNOPSIS
        Quick Find mode: Search albums directly by artist+album name.

    .DESCRIPTION
        Handles the Quick Find workflow in Start-OM. Auto-detects artist/album from
        folder structure, searches providers, and presents album selection UI.

    .PARAMETER State
        The OM State object containing Album, FindMode, etc.

    .PARAMETER Provider
        The music provider to search.

    .PARAMETER ShowHeader
        Scriptblock to display the workflow header.

    .PARAMETER SkipQuickPrompts
        If true, skip artist/album prompts and use current values.

    .PARAMETER CurrentArtist
        Current artist name for search.

    .PARAMETER CurrentAlbum
        Current album name for search.

    .PARAMETER Auto
        If true, enable auto-selection mode.

    .PARAMETER AutoFallback
        If true, try fallback providers when no match found.

    .PARAMETER AutoConfidenceThreshold
        Minimum confidence threshold for auto-selection (0-1).

    .PARAMETER NonInteractive
        If true, skip albums that can't be auto-matched.

    .PARAMETER UseWhatIf
        If true, run in WhatIf mode for saves.

    .PARAMETER Context
        OM context object for display.

    .OUTPUTS
        Hashtable with:
        - Action: 'Selected', 'SwitchMode', 'Skip', 'Continue', 'ProviderSwitch'
        - NextStage: 'A', 'C', or $null
        - ProviderArtist: Selected artist object
        - ProviderAlbum: Selected album object
        - Provider: Updated provider (if switched)
        - CurrentArtist: Updated artist
        - CurrentAlbum: Updated album
        - SkipQuickPrompts: Updated flag
        - AlbumCandidates: Search results for caching
        - AutoModeActive: Whether auto mode selected an album
        - BackNavigationMode: Updated flag
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$State,

        [Parameter(Mandatory)]
        [string]$Provider,

        [Parameter()]
        [scriptblock]$ShowHeader,

        [Parameter()]
        [bool]$SkipQuickPrompts = $false,

        [Parameter()]
        [string]$CurrentArtist,

        [Parameter()]
        [string]$CurrentAlbum,

        [Parameter()]
        [switch]$Auto,

        [Parameter()]
        [switch]$AutoFallback,

        [Parameter()]
        [double]$AutoConfidenceThreshold = 0.8,

        [Parameter()]
        [switch]$NonInteractive,

        [Parameter()]
        [switch]$UseWhatIf,

        [Parameter()]
        $Context
    )

    # Initialize result
    $result = @{
        Action            = $null
        NextStage         = $null
        ProviderArtist    = $null
        ProviderAlbum     = $null
        Provider          = $Provider
        CurrentArtist     = $CurrentArtist
        CurrentAlbum      = $CurrentAlbum
        SkipQuickPrompts  = $SkipQuickPrompts
        AlbumCandidates   = @()
        AutoModeActive    = $false
        BackNavigationMode = $false
        FindMode          = 'quick'
    }

    # Display header
    if ($VerbosePreference -ne 'Continue') { Clear-Host }
    if ($ShowHeader -and $ShowHeader -is [scriptblock]) {
        try {
            & $ShowHeader -Provider $Provider -Artist $State.Artist -AlbumName $State.AlbumName -TrackCount $State.TrackCount
        } catch {
            Write-Verbose "ShowHeader failed: $_"
        }
    }
    Show-Message -Message "🔍 Find Mode: Quick Album Search" -ForegroundColor Magenta -Context $Context
    Show-Message -Message "" -Context $Context

    # Auto-detect artist and album from folder structure
    if (-not $SkipQuickPrompts) {
        Write-Verbose "DEBUG: Running auto-detection (SkipQuickPrompts=$SkipQuickPrompts)"
        $folderName = $State.Album.Name
        $artistFolderName = $State.Album.Parent.Name
        
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
            $firstAudioFile = Get-ChildItem -LiteralPath $State.Album.FullName -File -Recurse -ErrorAction Stop | 
                Where-Object { $_.Extension -in '.flac', '.mp3', '.m4a', '.ogg', '.opus', '.wma', '.ape' } |
                Select-Object -First 1
            
            if ($firstAudioFile -and $firstAudioFile.FullName) {
                Write-Verbose "DEBUG: Loading tag from $($firstAudioFile.Name)"
                
                # Load TagLib if not already loaded
                if (-not ([System.Management.Automation.PSTypeName]'TagLib.File').Type) {
                    $tagLibPath = Join-Path $PSScriptRoot '..' '..' 'lib' 'taglib-sharp.dll'
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
            Show-Message -Message "📁 Auto-detected from folder: Artist='$detectedArtist', Album='$detectedAlbum'" -ForegroundColor Gray -Context $Context
            Show-Message -Message "🎵 Using AlbumArtist tag for better match: '$tagArtist'" -ForegroundColor Green -Context $Context
            $detectedArtist = $tagArtist
            
            # Also check if album name has "Artist - Title" pattern and strip it
            if ($detectedAlbum -match '^([^-]+?)\s*-\s*(.+)$') {
                $possibleArtist = $matches[1].Trim()
                $possibleAlbumOnly = $matches[2].Trim()
                # If the album prefix looks like part of artist name, strip it
                if ($possibleArtist -match [regex]::Escape($detectedArtist) -or $detectedArtist -match [regex]::Escape($possibleArtist)) {
                    $detectedAlbum = $possibleAlbumOnly
                    Show-Message -Message "   Cleaned album name to: '$detectedAlbum'" -ForegroundColor Gray -Context $Context
                }
            }
        }
        # Otherwise check if album name has "Artist - Title" pattern
        elseif ($detectedAlbum -match '^([^-]+?)\s*-\s*(.+)$') {
            $possibleArtist = $matches[1].Trim()
            $possibleAlbumOnly = $matches[2].Trim()
            
            if ($possibleArtist -match [regex]::Escape($detectedArtist)) {
                Show-Message -Message "📁 Auto-detected from folder: Artist='$detectedArtist', Album='$detectedAlbum'" -ForegroundColor Gray -Context $Context
                Show-Message -Message "🎵 Using artist from album name: '$possibleArtist'" -ForegroundColor Green -Context $Context
                $detectedArtist = $possibleArtist
                $detectedAlbum = $possibleAlbumOnly
            }
            else {
                Show-Message -Message "📁 Auto-detected from folder structure: Artist='$detectedArtist', Album='$detectedAlbum'" -ForegroundColor Green -Context $Context
            }
        }
        else {
            Show-Message -Message "📁 Auto-detected from folder structure: Artist='$detectedArtist', Album='$detectedAlbum'" -ForegroundColor Green -Context $Context
        }
        
        $result.CurrentArtist = $detectedArtist
        $result.CurrentAlbum = $detectedAlbum
        Write-Verbose "DEBUG: Set CurrentArtist='$($result.CurrentArtist)', CurrentAlbum='$($result.CurrentAlbum)'"
        $result.SkipQuickPrompts = $true
    }
    else {
        Write-Verbose "DEBUG: Skipping auto-detection (SkipQuickPrompts=$SkipQuickPrompts), using CurrentArtist='$CurrentArtist'"
    }

    $quickArtist = $result.CurrentArtist
    $quickAlbum = $result.CurrentAlbum

    # Check if we have cached albums from back navigation
    $albumCandidates = @()
    if ($State.BackNavigationMode -and $State.QuickAlbumCandidates) {
        $albumCandidates = $State.QuickAlbumCandidates
        Show-Message -Message "Using cached album results for back navigation..." -ForegroundColor Cyan -Context $Context
    }
    else {
        # Search for albums
        Show-Message -Message "Searching for '$quickAlbum' by '$quickArtist'..." -ForegroundColor Cyan -Context $Context
        Write-Verbose "TRACE: Quick search: quickAlbum='$quickAlbum' quickArtist='$quickArtist' Provider='$Provider'"
        
        :quickSearchLoop while ($true) {
            $quickAlbum = $result.CurrentAlbum
            $quickArtist = $result.CurrentArtist
            try {
                $quickResults = Invoke-ProviderSearch -Provider $Provider -Album $quickAlbum -Artist $quickArtist -Type album
                $albumCandidates = if ($quickResults -and $quickResults.albums -and $quickResults.albums.PSObject.Properties.Name -contains 'items' -and $quickResults.albums.items) { 
                    @($quickResults.albums.items | Where-Object { $_ -ne $null }) 
                } else { 
                    @() 
                }
            }
            catch {
                Write-Warning "Quick search failed: $_"
                Dump-ExceptionDiagnostics -ErrorRecord $_ -ContextMsg "Invoke-ProviderSearch quick $Provider"
                $albumCandidates = @()
            }
            
            # Handle no results
            if ($null -eq $albumCandidates -or $albumCandidates.Count -eq 0) {
                Show-Message -Message "No albums found for '$quickAlbum' by '$quickArtist' with $Provider." -ForegroundColor Red -Context $Context
                $retryChoice = Show-OMPrompt -Prompt "Press Enter to retry, (ps)potify, (pq)obuz, (pd)iscogs, (pm)usicbrainz, '(a)' artist-first mode, (ni) New Item (enter new artist+album), (x) skip album, or enter new album name" -Context $Context
                
                # Check for provider switch
                $newProvider = Switch-OMProvider -Input $retryChoice -Context $Context
                if ($newProvider) {
                    $result.Provider = $newProvider
                    $Provider = $newProvider
                    continue quickSearchLoop
                }
                elseif ($retryChoice -eq 'a') {
                    $result.Action = 'SwitchMode'
                    $result.NextStage = 'A'
                    $result.FindMode = 'artist-first'
                    return $result
                }
                elseif ($retryChoice -eq 'ni') {
                    # Prompt for new artist AND album together
                    $res = Read-ArtistAlbum -DefaultArtist $result.CurrentArtist -DefaultAlbum $result.CurrentAlbum
                    if ($res.ChangedArtist) { $result.CurrentArtist = $res.Artist }
                    if ($res.ChangedAlbum) { $result.CurrentAlbum = $res.Album }
                }
                elseif ($retryChoice -eq 'x' -or $retryChoice -eq 'xip') {
                    Show-Message -Message "Skipping album: $quickAlbum" -ForegroundColor Yellow -Context $Context
                    $result.Action = 'Skip'
                    return $result
                }
                elseif ($retryChoice) {
                    # Assume it's a new album name
                    $result.CurrentAlbum = $retryChoice
                }
                else {
                    continue quickSearchLoop
                }
            }
            else {
                break quickSearchLoop
            }
        }

        # Store candidates for back navigation
        $result.AlbumCandidates = $albumCandidates
        $result.BackNavigationMode = $false
    }

    # AUTO MODE: Check for high-confidence match
    if ($Auto) {
        $bestMatch = $null
        if ($albumCandidates.Count -gt 0) {
            Show-Message -Message "🤖 AUTO: Calculating confidence scores..." -ForegroundColor Cyan -Context $Context
            $index = 1
            foreach ($candidate in @($albumCandidates)) {
                $scoreVal = Get-AlbumMatchConfidence -Candidate $candidate -LocalArtist $quickArtist -LocalAlbum $quickAlbum -LocalTrackCount $State.TrackCount
                $scorePercent = $scoreVal * 100
                $displayName = if ($candidate.name) { $candidate.name } else { $candidate.title }
                try { "$(Get-Date -Format o) | INVOKE: Get-AlbumMatchConfidence Index=$index DisplayName=$displayName LocalArtist=$quickArtist LocalAlbum=$quickAlbum" | Out-File -FilePath (Join-Path $env:TEMP 'start_om_invocation_log.txt') -Append -Encoding utf8 -Force } catch { }
                Show-Message -Message "   [$index] $displayName : $([math]::Round($scorePercent, 1))%" -ForegroundColor $(if ($scorePercent -ge ($AutoConfidenceThreshold * 100)) { 'Green' } else { 'Yellow' }) -Context $Context
                $index++
            }
            
            try { "$(Get-Date -Format o) | INVOKE: Get-BestAutoMatch CandidatesCount=$($albumCandidates.Count) LocalArtist=$quickArtist LocalAlbum=$quickAlbum Threshold=$AutoConfidenceThreshold" | Out-File -FilePath (Join-Path $env:TEMP 'start_om_invocation_log.txt') -Append -Encoding utf8 -Force } catch { }
            $bestMatch = Get-BestAutoMatch -Candidates $albumCandidates -LocalArtist $quickArtist -LocalAlbum $quickAlbum -LocalTrackCount $State.TrackCount -Threshold $AutoConfidenceThreshold
            
            if ($bestMatch) {
                Show-Message -Message "✓ AUTO: Found high-confidence match on $Provider ($($bestMatch.Confidence)%)" -ForegroundColor Green -Context $Context
            } else {
                Show-Message -Message "⚠️  AUTO: Best match below threshold (need $([math]::Round($AutoConfidenceThreshold * 100, 1))%)" -ForegroundColor Yellow -Context $Context
            }
        }
        else {
            Show-Message -Message "⚠️  AUTO: No albums found on $Provider" -ForegroundColor Yellow -Context $Context
        }
        
        # Try fallback providers if no match
        if (-not $bestMatch -and $AutoFallback) {
            if ($albumCandidates.Count -gt 0) {
                Show-Message -Message "⚠️  AUTO: No high-confidence match on $Provider, trying fallback providers..." -ForegroundColor Yellow -Context $Context
            }
            else {
                Show-Message -Message "⚠️  AUTO: Trying fallback providers..." -ForegroundColor Yellow -Context $Context
            }
            
            $fallbackChain = switch ($Provider) {
                'Qobuz' { @('Spotify', 'Discogs', 'MusicBrainz') }
                'Spotify' { @('Qobuz', 'Discogs', 'MusicBrainz') }
                'Discogs' { @('Qobuz', 'Spotify', 'MusicBrainz') }
                'MusicBrainz' { @('Qobuz', 'Spotify', 'Discogs') }
            }
            
            foreach ($fallbackProvider in @($fallbackChain)) {
                Show-Message -Message "   Trying $fallbackProvider..." -ForegroundColor Cyan -Context $Context
                
                try {
                    try { "$(Get-Date -Format o) | INVOKE: Invoke-ProviderSearch Provider=$fallbackProvider Album=$quickAlbum Artist=$quickArtist" | Out-File -FilePath (Join-Path $env:TEMP 'start_om_invocation_log.txt') -Append -Encoding utf8 -Force } catch { }
                    $fallbackResults = Invoke-ProviderSearch -Provider $fallbackProvider -Album $quickAlbum -Artist $quickArtist -Type album
                    $fallbackCandidates = if ($fallbackResults -and $fallbackResults.albums -and $fallbackResults.albums.items) { @($fallbackResults.albums.items | Where-Object { $_ -ne $null }) } else { @() }
                }
                catch {
                    Write-Verbose "Fallback provider $fallbackProvider search failed: $_"
                    continue
                }
                
                if ($fallbackCandidates.Count -gt 0) {
                    $fallbackMatch = Get-BestAutoMatch -Candidates $fallbackCandidates -LocalArtist $quickArtist -LocalAlbum $quickAlbum -LocalTrackCount $State.TrackCount -Threshold $AutoConfidenceThreshold
                    
                    if ($fallbackMatch) {
                        Show-Message -Message "   ✓ Found high-confidence match on $fallbackProvider ($($fallbackMatch.Confidence)%)" -ForegroundColor Green -Context $Context
                        $bestMatch = $fallbackMatch
                        $result.Provider = $fallbackProvider
                        $Provider = $fallbackProvider
                        Show-Message -Message "🔄 AUTO: Switched to provider $Provider for better match" -ForegroundColor Cyan -Context $Context
                        break
                    }
                }
            }
        }
        
        # If we found a match, return it
        if ($bestMatch) {
            $result.ProviderAlbum = $bestMatch.Album
            
            # Extract artist from album metadata
            $artistNameFromAlbum = $null
            if ($value = Get-IfExists $result.ProviderAlbum 'artists') {
                if ($value -is [array] -and $value.Count -gt 0) {
                    $artistNameFromAlbum = if ($value[0].name) { $value[0].name } else { $value[0].ToString() }
                }
            }
            elseif ($value = Get-IfExists $result.ProviderAlbum 'artist') {
                $artistNameFromAlbum = $value
            }
            
            if (-not $artistNameFromAlbum) {
                $artistNameFromAlbum = $quickArtist
            }
            
            # For Spotify, fetch full artist details
            if ($Provider -eq 'Spotify' -and $result.ProviderAlbum.artists -and $result.ProviderAlbum.artists.Count -gt 0) {
                $artistId = $result.ProviderAlbum.artists[0].id
                if ($artistId) {
                    $result.ProviderArtist = Invoke-ProviderGetArtist -Provider $Provider -ArtistId $artistId
                    if (-not $result.ProviderArtist) {
                        $result.ProviderArtist = @{ name = $artistNameFromAlbum; id = $artistNameFromAlbum }
                    }
                }
                else {
                    $result.ProviderArtist = @{ name = $artistNameFromAlbum; id = $artistNameFromAlbum }
                }
            }
            else {
                $result.ProviderArtist = @{ name = $artistNameFromAlbum; id = $artistNameFromAlbum }
            }
            
            Show-Message -Message "✓ AUTO: Selected album: $($result.ProviderAlbum.name)" -ForegroundColor Green -Context $Context
            $result.Action = 'Selected'
            $result.NextStage = 'C'
            $result.AutoModeActive = $true
            return $result
        }
        else {
            Write-Warning "AUTO: No high-confidence match found. Falling back to interactive selection."
            $result.AutoModeActive = $false
            if ($NonInteractive) {
                Write-Warning "NonInteractive: Skipping album '$($State.AlbumName)' (no auto match)."
                $result.Action = 'Skip'
                return $result
            }
        }
    }

    # Album selection for quick mode (interactive)
    $result.ProviderArtist = @{ name = $quickArtist; id = $quickArtist }

    :albumSelectionLoop while ($true) {
        if ($VerbosePreference -ne 'Continue') { Clear-Host }
        if ($ShowHeader -and $ShowHeader -is [scriptblock]) {
            try {
                Write-Verbose ("TRACE: showHeader args: Provider=$Provider; Artist=$($State.Artist); AlbumName=$($State.AlbumName); TrackCount=$($State.TrackCount)")
                & $ShowHeader -Provider $Provider -Artist $State.Artist -AlbumName $State.AlbumName -TrackCount $State.TrackCount
            } catch {
                Write-Verbose "ShowHeader failed: $_"
            }
        }
        Show-Message -Message "🔍 Find Mode: Quick Album Search" -ForegroundColor Magenta -Context $Context
        Show-Message -Message "" -Context $Context
        
        Show-Message -Message "$Provider Album candidates for '$quickAlbum' by '$quickArtist':" -ForegroundColor Green -Context $Context
        for ($i = 0; $i -lt $albumCandidates.Count; $i++) {
            $album = $albumCandidates[$i]
            $artistDisplay = if ($album.artists -and $album.artists[0].name) { $album.artists[0].name } else { 'Unknown Artist' }
            
            $year = Get-IfExists $album 'release_date'
            $trackCount = Get-IfExists $album 'total_tracks'
            if (-not $trackCount) { $trackCount = Get-IfExists $album 'track_count' }
            if (-not $trackCount) { $trackCount = Get-IfExists $album 'tracks_count' }
            $trackInfo = if ($trackCount) { " ($trackCount tracks)" } else { "" }
            
            Show-Message -Message "[$($i+1)] $($album.name) - $artistDisplay (id: $($album.id)) (year: $year)$trackInfo" -Context $Context
        }

        $modeIndicator = if ($State.BackNavigationMode) { " (Back Navigation - use 'f' to search again)" } else { "" }
        $albumChoice = Show-OMPrompt -Prompt "Select album [number] (Enter=first), (P)rovider, {F}indMode, (ni) New Item (enter new artist+album), (x)ip, (C)over {[V]iew,[O]riginal,[S]ave,saveIn[T]ags}, or new search term$modeIndicator" -Context $Context
        if ($albumChoice -eq '') { $albumChoice = '1' }
        
        if ($albumChoice -eq 'p') {
            $config = Get-OMConfig
            $defaultProvider = $config.DefaultProvider
            Show-Message -Message "`nCurrent provider: $Provider (default: $defaultProvider)" -ForegroundColor Cyan -Context $Context
            Show-Message -Message "To switch providers, use: (ps)potify, (pq)obuz, (pd)iscogs, (pm)usicbrainz" -ForegroundColor Gray -Context $Context
            continue albumSelectionLoop
        }
        
        # Check for provider switch
        $newProvider = Switch-OMProvider -Input $albumChoice -Context $Context
        if ($newProvider) {
            $result.Provider = $newProvider
            $result.SkipQuickPrompts = $true
            $result.BackNavigationMode = $false
            $result.Action = 'ProviderSwitch'
            return $result
        }
        elseif ($albumChoice.ToLower() -eq 'f') {
            $result.Action = 'SwitchMode'
            $result.NextStage = 'A'
            $result.FindMode = 'artist-first'
            $result.BackNavigationMode = $false
            return $result
        }
        elseif ($albumChoice -eq 'ni') {
            $res = Read-ArtistAlbum -DefaultArtist $result.CurrentArtist -DefaultAlbum $result.CurrentAlbum
            if ($res.ChangedArtist) { $result.CurrentArtist = $res.Artist }
            if ($res.ChangedAlbum) { $result.CurrentAlbum = $res.Album }
            $result.SkipQuickPrompts = $true
            $result.BackNavigationMode = $false
            $result.Action = 'Continue'
            return $result
        }
        elseif ($albumChoice -match '^cvo(.*)$') {
            $rangeText = $matches[1]
            if (-not $rangeText) { $rangeText = "1" }
            Show-CoverArt -RangeText $rangeText -AlbumList $albumCandidates -Provider $Provider -Size 'original' -Grid $false
            Prompt-PressEnter -Context $Context
            continue albumSelectionLoop
        }
        elseif ($albumChoice -match '^cv(.*)$') {
            $rangeText = $matches[1]
            if (-not $rangeText) { $rangeText = "1" }
            Show-CoverArt -RangeText $rangeText -AlbumList $albumCandidates -Provider $Provider -Size 'original' -Grid $false
            Prompt-PressEnter -Context $Context
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
            if ($selectedIndices -isnot [array]) { $selectedIndices = @($selectedIndices) }
            if ($selectedIndices.Count -eq 0) {
                Write-Warning "No valid albums selected for cs command"
                continue albumSelectionLoop
            }
            $config = Get-OMConfig
            $maxSize = $config.CoverArt.FolderImageSize
            foreach ($index in @($selectedIndices)) {
                $albumIndex = $index - 1
                $selectedAlbum = $albumCandidates[$albumIndex]
                if ($selectedAlbum.cover_url) {
                    $saveResult = Save-CoverArt -CoverUrl $selectedAlbum.cover_url -AlbumPath $State.Album.FullName -Action SaveToFolder -MaxSize $maxSize -WhatIf:$UseWhatIf
                    if (-not $saveResult.Success) {
                        Write-Warning "Failed to save cover art for album $index ($($selectedAlbum.name)): $($saveResult.Error)"
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
            if ($selectedIndices -isnot [array]) { $selectedIndices = @($selectedIndices) }
            if ($selectedIndices.Count -eq 0) {
                Write-Warning "No valid albums selected for ct command"
                continue albumSelectionLoop
            }
            $config = Get-OMConfig
            $maxSize = $config.CoverArt.TagImageSize
            $audioFiles = Get-OMAudioFile -Path $State.Album.FullName

            if ($audioFiles.Count -gt 0) {
                foreach ($index in @($selectedIndices)) {
                    $albumIndex = $index - 1
                    $selectedAlbum = $albumCandidates[$albumIndex]
                    if ($selectedAlbum.cover_url) {
                        $saveResult = Save-CoverArt -CoverUrl $selectedAlbum.cover_url -AudioFiles $audioFiles -Action EmbedInTags -MaxSize $maxSize -WhatIf:$UseWhatIf
                        if (-not $saveResult.Success) {
                            Write-Warning "Failed to embed cover art for album $index ($($selectedAlbum.name)): $($saveResult.Error)"
                        }
                    }
                    else {
                        Write-Warning "No cover art available for album $index ($($selectedAlbum.name))"
                    }
                }
                # Clean up tag files
                foreach ($af in @($audioFiles)) {
                    if ($af.TagFile) {
                        try { $af.TagFile.Dispose() } catch { Write-Verbose "Dispose failed: $($_.Exception.Message)" }
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
                $result.ProviderAlbum = $albumCandidates[$idx - 1]
                
                # Extract artist name from album metadata
                $artistNameFromAlbum = $null
                if ($value = Get-IfExists $result.ProviderAlbum 'artists') {
                    if ($value -is [array] -and $value.Count -gt 0) {
                        $artistNameFromAlbum = if ($value[0].name) { $value[0].name } else { $value[0].ToString() }
                    } elseif ($value.name) {
                        $artistNameFromAlbum = $value.name
                    } else {
                        $artistNameFromAlbum = $value.ToString()
                    }
                } elseif ($value = Get-IfExists $result.ProviderAlbum 'artist') {
                    $artistNameFromAlbum = $value
                }
                
                if (-not $artistNameFromAlbum) {
                    $artistNameFromAlbum = $quickArtist
                    Write-Verbose "No artist in album metadata, using folder name: $artistNameFromAlbum"
                } else {
                    Write-Verbose "Extracted artist from album metadata: $artistNameFromAlbum"
                }
                
                # For Spotify, fetch full artist details
                if ($Provider -eq 'Spotify' -and $result.ProviderAlbum.artists -and $result.ProviderAlbum.artists.Count -gt 0) {
                    $artistId = $result.ProviderAlbum.artists[0].id
                    if ($artistId) {
                        Write-Verbose "Fetching full artist details for ID: $artistId"
                        $result.ProviderArtist = Invoke-ProviderGetArtist -Provider $Provider -ArtistId $artistId
                        if (-not $result.ProviderArtist) {
                            Write-Verbose "Failed to fetch artist details, using simplified object"
                            $result.ProviderArtist = @{ name = $artistNameFromAlbum; id = $artistNameFromAlbum }
                        }
                    }
                    else {
                        $result.ProviderArtist = @{ name = $artistNameFromAlbum; id = $artistNameFromAlbum }
                    }
                }
                else {
                    $result.ProviderArtist = @{ name = $artistNameFromAlbum; id = $artistNameFromAlbum }
                }
                
                $result.BackNavigationMode = $false
                $result.Action = 'Selected'
                $result.NextStage = 'C'
                return $result
            }
            else {
                Write-Warning "Invalid selection"
                continue albumSelectionLoop
            }
        }
        elseif ($albumChoice -eq 'x' -or $albumChoice -eq 'xip') {
            $result.Action = 'Skip'
            return $result
        }
        else {
            # New search term
            if ($State.BackNavigationMode) {
                Show-Message -Message "Back navigation mode: Enter album number to select, or use commands. To search again, use 'f' to change find mode first." -ForegroundColor Yellow -Context $Context
                continue albumSelectionLoop
            }
            else {
                $result.CurrentAlbum = $albumChoice
                $result.Action = 'Continue'
                return $result
            }
        }
    }
}
