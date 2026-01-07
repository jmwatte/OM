function Invoke-OMSaveAll {
    <#
    .SYNOPSIS
        Saves tags to all paired tracks and prepares folder move parameters.
    
    .DESCRIPTION
        This function handles the tag-saving and folder-move aspects of the 'sa' 
        (save-all) command. It saves tags to all paired tracks, disposes handles,
        calculates the new folder path parameters, and performs the folder move.
        
        The caller is responsible for handling UI feedback and script-state updates.
    
    .PARAMETER PairedTracks
        Array of paired track objects containing AudioFile and SpotifyTrack properties.
    
    .PARAMETER ProviderArtist
        The provider artist object.
    
    .PARAMETER ProviderAlbum
        The provider album object.
    
    .PARAMETER AlbumPath
        The current album folder path.
    
    .PARAMETER AudioFiles
        Array of audio file objects.
    
    .PARAMETER ManualAlbumArtist
        Optional manual album artist override.
    
    .PARAMETER GenreMergeMode
        Whether to merge genres with existing tags.
    
    .PARAMETER AlbumName
        The album name for folder naming.
    
    .PARAMETER UseWhatIf
        If true, shows what would happen without making changes.
    
    .PARAMETER Context
        Optional context for Show-Message calls.
    
    .OUTPUTS
        PSCustomObject with properties:
        - Success: Boolean indicating overall success
        - TagsSaved: Number of tracks with tags saved
        - TagsSkipped: Number of tracks skipped
        - MoveResult: Result from Move-AlbumFolder (or null if no move)
        - NewAlbumPath: New album path after move (or original if no move)
        - ReloadRequired: Boolean indicating if audio files need to be reloaded
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$PairedTracks,
        
        [Parameter(Mandatory)]
        $ProviderArtist,
        
        [Parameter(Mandatory)]
        $ProviderAlbum,
        
        [Parameter(Mandatory)]
        [string]$AlbumPath,
        
        [Parameter(Mandatory)]
        [array]$AudioFiles,
        
        [string]$ManualAlbumArtist,
        
        [switch]$GenreMergeMode,
        
        [string]$AlbumName,
        
        [switch]$UseWhatIf,
        
        $Context
    )

    $result = [PSCustomObject]@{
        Success        = $false
        TagsSaved      = 0
        TagsSkipped    = 0
        MoveResult     = $null
        NewAlbumPath   = $AlbumPath
        ReloadRequired = $false
    }

    # Phase 1: Save tags to all paired tracks
    foreach ($pair in $PairedTracks) {
        if ($null -ne (Get-IfExists $pair 'AudioFile') -and $null -ne (Get-IfExists $pair 'SpotifyTrack')) {
            $filePath = $pair.AudioFile.FilePath
            $tagsParams = @{
                Artist       = $ProviderArtist
                Album        = $ProviderAlbum
                SpotifyTrack = $pair.SpotifyTrack
            }
            
            if ($ManualAlbumArtist) {
                Write-Verbose "ManualAlbumArtist type: $($ManualAlbumArtist.GetType().FullName)"
                Write-Verbose "ManualAlbumArtist value: $($ManualAlbumArtist | Out-String)"
                
                $albumArtistString = if ($ManualAlbumArtist -is [string]) {
                    $ManualAlbumArtist
                }
                elseif ($ManualAlbumArtist -is [array]) {
                    $ManualAlbumArtist -join '; '
                }
                else {
                    $ManualAlbumArtist.ToString()
                }
                $tagsParams['ManualAlbumArtist'] = $albumArtistString
            }
            
            $tags = Get-Tags @tagsParams
            Write-Verbose ("Saving tags to: {0}" -f $filePath)
            Write-Verbose ("Tag values:`n{0}" -f ($tags | Out-String))
            
            $res = Save-TagsForFile -FilePath $filePath -TagValues $tags -WhatIf:$UseWhatIf -GenreMergeMode:$GenreMergeMode
            if ($res.Success) { 
                Show-Message -Message (("Saved tags: {0} -> {1:D2}.{2:D2}: {3}" -f (Split-Path -Leaf $filePath), $tags.Disc, $tags.Track, $tags.Title)) -ForegroundColor Green -Context $Context 
                $result.TagsSaved++
            }
            else { 
                Write-Warning ("Skipped/Failed: {0} ({1})" -f $filePath, ($res.Reason -or 'unknown')) 
                $result.TagsSkipped++
            }
        }
        else {
            if ($null -eq $pair.AudioFile) {
                Write-Verbose ("Skipping track '{0}' - no matching audio file" -f $pair.SpotifyTrack.name)
            }
            if ($null -eq $pair.SpotifyTrack) {
                Write-Verbose ("Skipping track '{0}' - no matching Spotify track" -f $pair.AudioFile.name)
            }
            $result.TagsSkipped++
        }
    }

    # Phase 2: Dispose TagFile handles (only when actually applying changes)
    if (-not $UseWhatIf) {
        foreach ($a in $AudioFiles) {
            if ($value = Get-IfExists $a 'TagFile') {
                try { $value.Dispose() } catch { Write-Verbose "Failed disposing TagFile for $($a.FilePath): $_" }
                $a.TagFile = $null
            }
        }
    }
    else {
        Write-Verbose "Preview: keeping TagFile handles open so interactive UI can display tags."
    }

    # Phase 3: Calculate new folder path and move
    $year = Get-ReleaseYear -ReleaseDate (Get-IfExists $ProviderAlbum 'release_date')
    $safeAlbumName = Approve-PathSegment -Segment (Get-IfExists $ProviderAlbum 'name') -Replacement '_' -CollapseRepeating -Transliterate
    
    # Determine artist for folder name
    $artistNameForFolder = Get-OMArtistNameForFolder `
        -ManualAlbumArtist $ManualAlbumArtist `
        -AudioFiles $AudioFiles `
        -ProviderAlbum $ProviderAlbum `
        -ProviderArtist $ProviderArtist `
        -AlbumName $AlbumName `
        -ReloadTags:(-not $UseWhatIf)
    
    $safeArtistName = Approve-PathSegment -Segment $artistNameForFolder -Replacement '_' -CollapseRepeating -Transliterate

    $mvArgs = @{
        AlbumPath    = $AlbumPath
        NewArtist    = $safeArtistName
        NewYear      = $year
        NewAlbumName = $safeAlbumName
    }

    # Force garbage collection before folder rename
    if (-not $UseWhatIf) {
        Write-Verbose "Forcing garbage collection before folder move to release file handles"
        [System.GC]::Collect()
        [System.GC]::WaitForPendingFinalizers()
        [System.GC]::Collect()
        Start-Sleep -Milliseconds 100
    }

    $moveResult = Invoke-MoveAlbumWithRetry -mvArgs $mvArgs -UseWhatIf:$UseWhatIf
    $result.MoveResult = $moveResult

    if ($moveResult -and $moveResult.Success) {
        $result.Success = $true
        $result.NewAlbumPath = $moveResult.NewAlbumPath
        
        if (-not $UseWhatIf -and $moveResult.NewAlbumPath -ne $AlbumPath) {
            $result.ReloadRequired = $true
        }
        elseif (-not $UseWhatIf) {
            # Folder wasn't moved but tags were saved - still need reload
            $result.ReloadRequired = $true
        }
    }
    elseif ($result.TagsSaved -gt 0) {
        # Tags were saved even if move failed/skipped
        $result.Success = $true
        $result.ReloadRequired = -not $UseWhatIf
    }

    return $result
}
