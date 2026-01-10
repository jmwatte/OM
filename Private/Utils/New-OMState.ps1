function New-OMState {
    <#
    .SYNOPSIS
        Creates a new OM workflow state object.
    
    .DESCRIPTION
        Initializes the central state object used throughout the Start-OM workflow.
        This object replaces scattered $script: scoped variables with an explicit,
        passable state container.
    
    .PARAMETER Path
        The album or artist folder path being processed.
    
    .PARAMETER Provider
        The initial provider to use (Spotify, Qobuz, etc.).
    
    .PARAMETER Context
        Optional context object for Show-Message calls.
    
    .OUTPUTS
        PSCustomObject containing all workflow state.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        
        [string]$Provider = 'Spotify',
        
        [object]$Context = $null
    )

    return [PSCustomObject]@{
        # Path information
        OriginalPath      = $Path
        IsSingleAlbumPath = $false
        
        # Current album being processed
        Album             = $null          # DirectoryInfo object
        AlbumName         = $null          # Album folder name
        Artist            = $null          # Artist name (from folder structure)
        TrackCount        = 0
        
        # Audio files
        AudioFiles        = @()            # Array of audio file objects with TagLib handles
        
        # Provider state
        Provider          = $Provider
        ProviderArtist    = $null          # Selected artist from provider
        ProviderAlbum     = $null          # Selected album from provider
        
        # Track matching
        PairedTracks      = @()            # Array of matched local/provider track pairs
        RefreshTracks     = $false         # Flag to trigger display refresh
        
        # Quick find mode state
        FindMode          = 'quick'        # 'quick' or 'artist-first'
        QuickAlbumCandidates = $null       # Cached album search results
        QuickCurrentPage  = 1              # Pagination for quick find
        
        # Auto mode state
        AutoModeActive    = $false         # Whether auto-processing is active
        TriedProviders    = @()            # Providers tried for current album (for AutoFallback)
        
        # User preferences (per-session)
        ShowVerbose       = $false         # Toggle verbose track display
        GenreMode         = 'Replace'      # 'Replace' or 'Merge' genres
        ManualAlbumArtist = $null          # User-specified album artist override
        
        # Navigation
        BackNavigationMode = $false        # Flag for back navigation
        StageHistory      = @()            # Stack of previous stages for back navigation
        
        # Context for UI
        Context           = $Context
    }
}
