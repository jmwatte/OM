function Invoke-StageA-ArtistSelection {
    <#
    .SYNOPSIS
        Stage A: Artist selection for the OM workflow.

    .DESCRIPTION
        Searches for artists via the configured provider and handles artist selection UI.
        Returns the selected artist or navigation commands.

    .PARAMETER Provider
        The music provider to search (Spotify, Qobuz, Discogs, MusicBrainz).

    .PARAMETER ArtistQuery
        The artist name to search for.

    .PARAMETER ArtistId
        Optional pre-selected artist ID to bypass search.

    .PARAMETER FindMode
        Current find mode ('quick' or 'artist-first').

    .PARAMETER ShowHeader
        Scriptblock to display the header.

    .PARAMETER Artist
        Current artist name for header display.

    .PARAMETER AlbumName
        Current album name for header display.

    .PARAMETER TrackCount
        Current track count for header display.

    .PARAMETER NonInteractive
        If true, auto-select first candidate without prompting.

    .PARAMETER AutoSelect
        If true, auto-select first candidate (alias for goA behavior).

    .PARAMETER GoA
        If true, auto-select first artist candidate.

    .PARAMETER Context
        The OM context object for display operations.

    .OUTPUTS
        Hashtable with:
        - NextStage: 'A', 'B', or 'Skip'
        - SelectedArtist: The selected provider artist object (if NextStage='B')
        - UpdatedProvider: New provider if user switched
        - UpdatedArtistQuery: New artist query if user entered new search
        - UpdatedAlbumName: New album name if user used 'al:' command
        - UpdatedFindMode: New find mode if user switched
        - SkipQuickPrompts: Whether to skip quick prompts after mode switch
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Provider,

        [Parameter(Mandatory)]
        [string]$ArtistQuery,

        [Parameter()]
        [string]$ArtistId,

        [Parameter()]
        [string]$FindMode = 'artist-first',

        [Parameter()]
        [scriptblock]$ShowHeader,

        [Parameter()]
        [string]$Artist,

        [Parameter()]
        [string]$AlbumName,

        [Parameter()]
        [int]$TrackCount = 0,

        [Parameter()]
        [switch]$NonInteractive,

        [Parameter()]
        [switch]$AutoSelect,

        [Parameter()]
        [switch]$GoA,

        [Parameter()]
        [object]$Context
    )

    # Initialize result hashtable
    $result = @{
        NextStage = 'A'  # Default to stay in Stage A
        SelectedArtist = $null
        UpdatedProvider = $null
        UpdatedArtistQuery = $null
        UpdatedAlbumName = $null
        UpdatedFindMode = $null
        SkipQuickPrompts = $false
    }

    # Clear screen and show header
    if ($VerbosePreference -ne 'Continue') { Clear-Host }
    
    if ($ShowHeader -is [scriptblock]) {
        try {
            & $ShowHeader -Provider $Provider -Artist $Artist -AlbumName $AlbumName -TrackCount $TrackCount
        } catch {
            Write-Verbose "ShowHeader invocation failed: $($_.Exception.Message)"
        }
    }

    # Display find mode
    if ($FindMode -eq 'quick') {
        Show-Message -Message "🔍 Find Mode: Quick Album Search" -ForegroundColor Magenta -Context $Context
    } else {
        Show-Message -Message "🔍 Find Mode: Artist-First" -ForegroundColor Magenta -Context $Context
    }
    Show-Message -Message "" -Context $Context

    # Search for artists
    Write-Verbose "Searching for artist: '$ArtistQuery' with provider: $Provider"
    $candidates = @()
    try {
        $r = Invoke-ProviderSearch -Provider $Provider -query $ArtistQuery -Type artist
        if ($value = Get-IfExists $r.artists "items") { 
            $candidates = @($value | Where-Object { $_ -ne $null })
        }
    } catch {
        Write-Warning "Search failed: $_"
        Dump-ExceptionDiagnostics -ErrorRecord $_ -ContextMsg "Invoke-ProviderSearch artist $Provider"
    }
    Write-Verbose "Search returned $($candidates.Count) candidates"

    # Handle no candidates found
    if (-not $candidates -or $candidates.Count -eq 0) {
        Show-Message -Message "No artist candidates found for '$ArtistQuery'." -Context $Context
        
        if ($NonInteractive) {
            Write-Warning "NonInteractive: skipping album because no artist candidates were found for '$ArtistQuery'."
            $result.NextStage = 'Skip'
            return $result
        }

        $inputF = Show-OMPrompt -Prompt "Enter new search, (ps)potify, (pq)obuz, (pd)iscogs, (pm)usicbrainz, '(x)ip' to skip album, or 'id:<id>' to select by id" -Context $Context
        
        switch -Regex ($inputF) {
            '^x(ip)?$' { 
                $result.NextStage = 'Skip'
                return $result
            }
            '^p([qsdm])$' {
                $newProvider = Switch-OMProvider -Input $matches[0] -Context $Context
                if ($newProvider) {
                    $result.UpdatedProvider = $newProvider
                }
                return $result
            }
            '^id:(.+)$' { 
                $id = $matches[1].Trim()
                if ($Provider -eq 'Discogs') { $id = ConvertTo-DiscogsId -InputId $id }
                $result.SelectedArtist = @{ id = $id; name = $id }
                $result.NextStage = 'B'
                return $result
            }
            default {
                if ($inputF) { 
                    $result.UpdatedArtistQuery = $inputF
                    Write-Verbose "Updated artistQuery to: '$inputF' (from no-candidates prompt)"
                }
                return $result
            }
        }
    }

    # Display candidates
    Show-Message -Message "$Provider Artist candidates for '$ArtistQuery':" -ForegroundColor Green -Context $Context
    for ($i = 0; $i -lt $candidates.Count; $i++) {
        $nameToDisplay = Get-IfExists $candidates[$i] 'displayName'
        if ($null -eq $nameToDisplay) {
            $nameToDisplay = $candidates[$i].name
        }
        Show-Message -Message "[$($i+1)] $nameToDisplay - $($candidates[$i].genres -join ', ') (id: $($candidates[$i].id))" -Context $Context
    }

    # Non-interactive selection: prefer explicit ArtistId, then goA, then AutoSelect/NonInteractive
    if ($ArtistId) {
        $result.SelectedArtist = @{ id = $ArtistId; name = $ArtistId }
        $result.NextStage = 'B'
        return $result
    }
    if ($GoA) {
        $result.SelectedArtist = $candidates[0]
        $result.NextStage = 'B'
        return $result
    }
    if ($AutoSelect -or $NonInteractive) {
        $result.SelectedArtist = $candidates[0]
        $result.NextStage = 'B'
        return $result
    }

    # Interactive selection
    $inputF = Show-OMPrompt -Prompt "Select artist [number] (Enter=first), number, '(x)ip' album, 'id:<id>', (ps)potify, (pq)obuz, (pd)iscogs, (pm)usicbrainz, 'al:<albumName>', '(F)indmode or new search term" -Context $Context
    
    # Empty input = select first
    if ($inputF -eq '') { 
        $result.SelectedArtist = $candidates[0]
        $result.NextStage = 'B'
        return $result
    }
    
    # Handle id: prefix
    if ($inputF -like 'id:*') { 
        $id = $inputF.Substring(3)
        if ($Provider -eq 'Discogs') { $id = ConvertTo-DiscogsId -InputId $id }
        $result.SelectedArtist = @{ id = $id; name = $id }
        $result.NextStage = 'B'
        return $result
    }
    
    # Handle al: prefix (album name override)
    if ($inputF -like 'al:*') {
        $newAlbumName = $inputF.Substring(3).Trim()
        if ($newAlbumName) {
            $result.UpdatedAlbumName = $newAlbumName
            Write-Verbose "Updated albumName to: '$newAlbumName' (from al: prompt)"
        }
        return $result
    }
    
    # Handle numeric selection
    if ($inputF -match '^\d+$') { 
        $idx = [int]$inputF
        if ($idx -ge 1 -and $idx -le $candidates.Count) { 
            $result.SelectedArtist = $candidates[$idx - 1]
            $result.NextStage = 'B'
            return $result
        } else { 
            Write-Warning "Invalid selection: $idx"
            return $result
        }
    }
    
    # Handle skip
    if ($inputF -eq 'x' -or $inputF -eq 'xip') { 
        $result.NextStage = 'Skip'
        return $result
    }
    
    # Handle provider switches
    $newProvider = Switch-OMProvider -Input $inputF -Context $Context
    if ($newProvider) {
        $result.UpdatedProvider = $newProvider
        return $result
    }
    
    # Handle find mode switch
    if ($inputF -eq 'f' -or $inputF -eq 'fm') {
        Show-Message -Message "`nCurrent find mode: $FindMode" -ForegroundColor Cyan -Context $Context
        Show-Message -Message "Available modes: (q)uick album search, (a)rtist-first search" -ForegroundColor Gray -Context $Context
        $newMode = Show-OMPrompt -Prompt "Select mode [q/a]" -Context $Context
        
        if ($newMode -eq 'q' -or $newMode -eq 'quick') {
            $result.UpdatedFindMode = 'quick'
            $result.SkipQuickPrompts = $false
            Show-Message -Message "✓ Switched to Quick Album Search mode" -ForegroundColor Green -Context $Context
        }
        elseif ($newMode -eq 'a' -or $newMode -eq 'artist-first') {
            $result.UpdatedFindMode = 'artist-first'
            Show-Message -Message "✓ Switched to Artist-First Search mode" -ForegroundColor Green -Context $Context
        }
        else {
            Write-Warning "Invalid mode: $newMode. Staying with $FindMode."
        }
        return $result
    }
    
    # Default: treat as new search term
    $result.UpdatedArtistQuery = $inputF
    Write-Verbose "Updated artistQuery to: '$inputF' (from selection prompt)"
    return $result
}
