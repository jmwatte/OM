function Sync-OMStateToScript {
    <#
    .SYNOPSIS
        Synchronizes State object properties to script-scope variables.
    
    .DESCRIPTION
        During the Phase 3.1 migration, this function keeps script-scope variables
        in sync with the State object. This allows gradual migration without breaking
        existing code that reads from $script: variables.
    
    .PARAMETER State
        The State object to sync from.
    
    .PARAMETER ScriptScope
        Reference to the script scope for variable access.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$State
    )

    # Sync all State properties to script-scope variables
    $script:album = $State.Album
    $script:albumName = $State.AlbumName
    $script:artist = $State.Artist
    $script:trackCount = $State.TrackCount
    $script:audioFiles = $State.AudioFiles
    $script:pairedTracks = $State.PairedTracks
    $script:refreshTracks = $State.RefreshTracks
    $script:findMode = $State.FindMode
    $script:quickAlbumCandidates = $State.QuickAlbumCandidates
    $script:quickCurrentPage = $State.QuickCurrentPage
    $script:autoModeActive = $State.AutoModeActive
    $script:showVerbose = $State.ShowVerbose
    $script:genreMode = $State.GenreMode
    $script:ManualAlbumArtist = $State.ManualAlbumArtist
    $script:backNavigationMode = $State.BackNavigationMode
    $script:isSingleAlbumPath = $State.IsSingleAlbumPath
    $script:originalPath = $State.OriginalPath
}

function Sync-OMScriptToState {
    <#
    .SYNOPSIS
        Synchronizes script-scope variables back to State object.
    
    .DESCRIPTION
        During the Phase 3.1 migration, this function keeps the State object
        in sync with changes made by existing code that writes to $script: variables.
        Only syncs variables that have been set (are not undefined).
    
    .PARAMETER State
        The State object to sync to.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$State
    )

    # Sync script-scope variables back to State (only if they've been set)
    # Use Get-Variable with -ErrorAction SilentlyContinue to check if variables exist
    # Only sync if the variable has a non-null value to avoid overwriting State with nulls
    $audioFilesVar = Get-Variable -Name 'audioFiles' -Scope Script -ErrorAction SilentlyContinue
    if ($audioFilesVar -and $null -ne $audioFilesVar.Value) {
        $State.AudioFiles = $script:audioFiles
    }
    $pairedTracksVar = Get-Variable -Name 'pairedTracks' -Scope Script -ErrorAction SilentlyContinue
    if ($pairedTracksVar -and $null -ne $pairedTracksVar.Value) {
        $State.PairedTracks = $script:pairedTracks
    }
    # NOTE: RefreshTracks is NOT synced from script scope - it's only used via $State.RefreshTracks
    # The script-scope variable is legacy and should not overwrite the State value
    
    # For other variables, keep original logic (these can be null)
    if ($null -ne (Get-Variable -Name 'album' -Scope Script -ErrorAction SilentlyContinue)) {
        $State.Album = $script:album
    }
    if ($null -ne (Get-Variable -Name 'albumName' -Scope Script -ErrorAction SilentlyContinue)) {
        $State.AlbumName = $script:albumName
    }
    if ($null -ne (Get-Variable -Name 'artist' -Scope Script -ErrorAction SilentlyContinue)) {
        $State.Artist = $script:artist
    }
    if ($null -ne (Get-Variable -Name 'trackCount' -Scope Script -ErrorAction SilentlyContinue)) {
        $State.TrackCount = $script:trackCount
    }
    if ($null -ne (Get-Variable -Name 'findMode' -Scope Script -ErrorAction SilentlyContinue)) {
        $State.FindMode = $script:findMode
    }
    if ($null -ne (Get-Variable -Name 'quickAlbumCandidates' -Scope Script -ErrorAction SilentlyContinue)) {
        $State.QuickAlbumCandidates = $script:quickAlbumCandidates
    }
    if ($null -ne (Get-Variable -Name 'quickCurrentPage' -Scope Script -ErrorAction SilentlyContinue)) {
        $State.QuickCurrentPage = $script:quickCurrentPage
    }
    if ($null -ne (Get-Variable -Name 'autoModeActive' -Scope Script -ErrorAction SilentlyContinue)) {
        $State.AutoModeActive = $script:autoModeActive
    }
    if ($null -ne (Get-Variable -Name 'showVerbose' -Scope Script -ErrorAction SilentlyContinue)) {
        $State.ShowVerbose = $script:showVerbose
    }
    if ($null -ne (Get-Variable -Name 'genreMode' -Scope Script -ErrorAction SilentlyContinue)) {
        $State.GenreMode = $script:genreMode
    }
    if ($null -ne (Get-Variable -Name 'ManualAlbumArtist' -Scope Script -ErrorAction SilentlyContinue)) {
        $State.ManualAlbumArtist = $script:ManualAlbumArtist
    }
    if ($null -ne (Get-Variable -Name 'backNavigationMode' -Scope Script -ErrorAction SilentlyContinue)) {
        $State.BackNavigationMode = $script:backNavigationMode
    }
    if ($null -ne (Get-Variable -Name 'isSingleAlbumPath' -Scope Script -ErrorAction SilentlyContinue)) {
        $State.IsSingleAlbumPath = $script:isSingleAlbumPath
    }
    if ($null -ne (Get-Variable -Name 'originalPath' -Scope Script -ErrorAction SilentlyContinue)) {
        $State.OriginalPath = $script:originalPath
    }
}
