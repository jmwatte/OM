function Invoke-OMFolderMove {
    <#
    .SYNOPSIS
        Prepares and executes album folder move operations.
    
    .DESCRIPTION
        This helper consolidates the folder preparation and move logic shared
        by the 'sf' (save folder) and 'sa' (save all) commands. It handles:
        - Extracting release year from provider album
        - Sanitizing album and artist names for the file system
        - Building the move arguments
        - Optional garbage collection before move
        - Executing the move with retry logic
    
    .PARAMETER ProviderAlbum
        The provider album object containing name and release_date.
    
    .PARAMETER ProviderArtist
        The provider artist object.
    
    .PARAMETER AlbumPath
        The current album folder path.
    
    .PARAMETER AudioFiles
        Array of audio file objects for artist name detection.
    
    .PARAMETER ManualAlbumArtist
        Optional manual album artist override.
    
    .PARAMETER AlbumName
        The local album name for fallback detection.
    
    .PARAMETER UseWhatIf
        If true, shows what would happen without making changes.
    
    .PARAMETER ReloadTags
        If true, tells Get-OMArtistNameForFolder to reload tags from files.
    
    .PARAMETER ForceGC
        If true, forces garbage collection even in WhatIf mode (for sf command).
    
    .OUTPUTS
        PSCustomObject with properties:
        - Success: Boolean indicating if move completed
        - MoveResult: The result from Invoke-MoveAlbumWithRetry
        - OldPath: The original album path
        - MvArgs: The arguments used for the move
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $ProviderAlbum,
        
        [Parameter(Mandatory)]
        $ProviderArtist,
        
        [Parameter(Mandatory)]
        [string]$AlbumPath,
        
        [Parameter(Mandatory)]
        [array]$AudioFiles,
        
        [string]$ManualAlbumArtist,
        
        [string]$AlbumName,
        
        [switch]$UseWhatIf,
        
        [switch]$ReloadTags,
        
        [switch]$ForceGC
    )
    
    $year = Get-ReleaseYear -ReleaseDate (Get-IfExists $ProviderAlbum 'release_date')
    $oldpath = $AlbumPath
    $safeAlbumName = Approve-PathSegment -Segment (Get-IfExists $ProviderAlbum 'name') -Replacement '_' -CollapseRepeating -Transliterate
    
    # Determine artist for folder name using helper
    $artistParams = @{
        AudioFiles     = $AudioFiles
        ProviderAlbum  = $ProviderAlbum
        ProviderArtist = $ProviderArtist
        AlbumName      = $AlbumName
    }
    if ($ManualAlbumArtist) {
        $artistParams['ManualAlbumArtist'] = $ManualAlbumArtist
    }
    if ($ReloadTags) {
        $artistParams['ReloadTags'] = $true
    }
    
    $artistNameForFolder = Get-OMArtistNameForFolder @artistParams
    $safeArtistName = Approve-PathSegment -Segment $artistNameForFolder -Replacement '_' -CollapseRepeating -Transliterate
    
    $mvArgs = @{
        AlbumPath    = $oldpath
        NewArtist    = $safeArtistName
        NewYear      = $year
        NewAlbumName = $safeAlbumName
    }
    
    # Force garbage collection to release any lingering file handles before folder rename
    if ($ForceGC -or (-not $UseWhatIf)) {
        Write-Verbose "Forcing garbage collection before folder move to release file handles"
        [System.GC]::Collect()
        [System.GC]::WaitForPendingFinalizers()
        [System.GC]::Collect()
        Start-Sleep -Milliseconds 100  # Brief pause to ensure OS releases locks
    }
    
    $moveResult = Invoke-MoveAlbumWithRetry -mvArgs $mvArgs -UseWhatIf:$UseWhatIf
    
    return [PSCustomObject]@{
        Success    = ($moveResult -ne $null)
        MoveResult = $moveResult
        OldPath    = $oldpath
        MvArgs     = $mvArgs
    }
}
