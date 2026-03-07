function Invoke-StageA-ArtistSelection {
    <#
    .SYNOPSIS
        Stage A: Artist search and selection for Start-OM workflow.
    
    .DESCRIPTION
        Searches for artists using the configured provider and lets the user select one.
        Supports provider switching, find-mode toggling, and direct ID input.
    
    .OUTPUTS
        Hashtable with:
        - NextStage: 'A', 'B', or 'AlbumDone'
        - Provider: Updated provider name
        - ProviderArtist: Selected artist object
        - ArtistQuery: Updated search query
        - AlbumName: Updated album name (if changed via al: command)
        - CachedAlbums: $null if cleared
        - CachedArtistId: $null if cleared
        - SkipQuickPrompts: Updated value
        - LoadStageBResults: $true (always)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Provider,
        
        [Parameter(Mandatory)]
        [string]$ArtistQuery,
        
        [Parameter()]
        [string]$Artist,
        
        [Parameter()]
        [string]$AlbumName,
        
        [Parameter()]
        [string]$ArtistId,
        
        [Parameter()]
        [switch]$NonInteractive,
        
        [Parameter()]
        [switch]$AutoSelect,
        
        [Parameter()]
        [switch]$GoA,
        
        [Parameter()]
        [scriptblock]$ShowHeader,
        
        [Parameter()]
        [scriptblock]$NormalizeDiscogsId,

        [Parameter()]
        [hashtable]$Context
    )

    # --- Resolve context: use passed Context or snapshot from $script: ---
    if ($Context) {
        $ctx = $Context
    } else {
        $ctx = @{
            FindMode = $script:findMode
        }
    }

    # Build default result hashtable
    $defaultResult = @{
        NextStage          = 'A'
        Provider           = $Provider
        ProviderArtist     = $null
        ArtistQuery        = $ArtistQuery
        AlbumName          = $AlbumName
        CachedAlbums       = $false  # sentinel: $false means "not changed"
        CachedArtistId     = $false  # sentinel: $false means "not changed"
        SkipQuickPrompts   = $false  # sentinel: $false means "not changed"
        LoadStageBResults  = $true
    }
    # Helper: sync $ctx back to $script: variables
    $syncBack = {
        $script:findMode = $ctx.FindMode
    }

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

    # Always clear candidates and perform fresh search
    $candidates = $null

    Write-Verbose "Searching for artist: '$ArtistQuery' with provider: $Provider"
    try { $r = Invoke-ProviderSearch -Provider $Provider -query $ArtistQuery -Type artist } catch { Write-Warning "Search failed: $_"; $r = $null }
    $candidates = @()
    if ($value = Get-IfExists $r.artists "items") { $candidates = $value }
    $candidates = @($candidates | Where-Object { $_ -ne $null })
    Write-Verbose "Search returned $($candidates.Count) candidates"

    if (-not $candidates -or $candidates.Count -eq 0) {
        Write-Host "No artist candidates found for '$ArtistQuery'."
        if ($NonInteractive) {
            Write-Warning "NonInteractive: skipping album because no artist candidates were found for '$ArtistQuery'."
            $defaultResult.NextStage = 'AlbumDone'
            return $defaultResult
        }
        $inputF = Read-Host "Enter new search, (ps)potify, (pq)obuz, (pd)iscogs, (pm)usicbrainz, (p)rovider info, '(x)ip' to skip album, 'id:<id>', or (?) help"
        switch -Regex ($inputF) {
            '^\?$' {
                Show-OMHelp -Context 'StageA-NoResults'
                return $defaultResult
            }
            '^p$' {
                $defaultProvider = (Get-OMConfig).DefaultProvider
                Write-Host "`nCurrent provider: $Provider (default: $defaultProvider)" -ForegroundColor Cyan
                Write-Host "To switch providers, use: (ps)potify, (pq)obuz, (pd)iscogs, (pm)usicbrainz" -ForegroundColor Gray
                return $defaultResult
            }
            '^x(ip)?$' {
                $defaultResult.NextStage = 'AlbumDone'
                return $defaultResult
            }
            '^ps$' {
                $defaultResult.Provider = 'Spotify'
                Write-Host "Switched to provider: Spotify" -ForegroundColor Green
                return $defaultResult
            }
            '^pq$' {
                $defaultResult.Provider = 'Qobuz'
                Write-Host "Switched to provider: Qobuz" -ForegroundColor Green
                return $defaultResult
            }
            '^pd$' {
                $defaultResult.Provider = 'Discogs'
                Write-Host "Switched to provider: Discogs" -ForegroundColor Green
                return $defaultResult
            }
            '^pm$' {
                $defaultResult.Provider = 'MusicBrainz'
                Write-Host "Switched to provider: MusicBrainz" -ForegroundColor Green
                return $defaultResult
            }
            '^id:(.+)$' {
                $id = $matches[1].Trim()
                if ($Provider -eq 'Discogs' -and $NormalizeDiscogsId) { $id = & $NormalizeDiscogsId $id }
                $defaultResult.NextStage = 'B'
                $defaultResult.ProviderArtist = @{ id = $id; name = $id }
                return $defaultResult
            }
            default {
                if ($inputF) {
                    $defaultResult.ArtistQuery = $inputF
                    Write-Verbose "Updated artistQuery to: '$inputF' (from no-candidates prompt)"
                }
                return $defaultResult
            }
        }
    }

    Write-Host "$Provider Artist candidates for '$ArtistQuery':" -ForegroundColor Green
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

    # Non-interactive selection
    if ($ArtistId) {
        $defaultResult.NextStage = 'B'
        $defaultResult.ProviderArtist = @{ id = $ArtistId; name = $ArtistId }
        return $defaultResult
    }
    if ($GoA) {
        $defaultResult.NextStage = 'B'
        $defaultResult.ProviderArtist = $candidates[0]
        return $defaultResult
    }
    if ($AutoSelect -or $NonInteractive) {
        $defaultResult.NextStage = 'B'
        $defaultResult.ProviderArtist = $candidates[0]
        return $defaultResult
    }

    Write-Host "Select artist [number] (Enter=first), '(x)ip', 'id:<id>', (p)rovider, ps/pq/pd/pm, 'al:<name>', (f)indmode, (?) help, or new search:" -ForegroundColor Yellow -NoNewline
    $inputF = Read-Host

    if ($inputF -eq '?') {
        Show-OMHelp -Context 'StageA-Select'
        return $defaultResult
    }
    if ($inputF -eq 'p') {
        $defaultProvider = (Get-OMConfig).DefaultProvider
        Write-Host "`nCurrent provider: $Provider (default: $defaultProvider)" -ForegroundColor Cyan
        Write-Host "To switch providers, use: (ps)potify, (pq)obuz, (pd)iscogs, (pm)usicbrainz" -ForegroundColor Gray
        return $defaultResult
    }
    if ($inputF -eq '') {
        $defaultResult.NextStage = 'B'
        $defaultResult.ProviderArtist = $candidates[0]
        return $defaultResult
    }
    if ($inputF -like 'id:*') {
        $id = $inputF.Substring(3)
        if ($Provider -eq 'Discogs' -and $NormalizeDiscogsId) { $id = & $NormalizeDiscogsId $id }
        $defaultResult.NextStage = 'B'
        $defaultResult.ProviderArtist = @{ id = $id; name = $id }
        return $defaultResult
    }
    if ($inputF -like 'al:*') {
        $newAlbumName = $inputF.Substring(3).Trim()
        if ($newAlbumName) {
            $defaultResult.AlbumName = $newAlbumName
            Write-Verbose "Updated albumName to: '$newAlbumName' (from al: prompt)"
        }
        return $defaultResult
    }
    if ($inputF -match '^\d+$') {
        $idx = [int]$inputF
        if ($idx -ge 1 -and $idx -le $candidates.Count) {
            $defaultResult.NextStage = 'B'
            $defaultResult.ProviderArtist = $candidates[$idx - 1]
            return $defaultResult
        }
        else {
            Write-Warning "Invalid"
            return $defaultResult
        }
    }
    if ($inputF -eq 'x' -or $inputF -eq 'xip') {
        $defaultResult.NextStage = 'AlbumDone'
        return $defaultResult
    }
    if ($inputF -eq 'ps') {
        $defaultResult.Provider = 'Spotify'
        Write-Host "Switched to provider: Spotify" -ForegroundColor Green
        return $defaultResult
    }
    if ($inputF -eq 'pq') {
        $defaultResult.Provider = 'Qobuz'
        Write-Host "Switched to provider: Qobuz" -ForegroundColor Green
        return $defaultResult
    }
    if ($inputF -eq 'pd') {
        $defaultResult.Provider = 'Discogs'
        Write-Host "Switched to provider: Discogs" -ForegroundColor Green
        return $defaultResult
    }
    if ($inputF -eq 'pm') {
        $defaultResult.Provider = 'MusicBrainz'
        Write-Host "Switched to provider: MusicBrainz" -ForegroundColor Green
        return $defaultResult
    }
    if ($inputF -eq 'f' -or $inputF -eq 'fm') {
        Write-Host "`nCurrent find mode: $($ctx.FindMode)" -ForegroundColor Cyan
        Write-Host "Available modes: (q)uick album search, (a)rtist-first search" -ForegroundColor Gray
        $newMode = Read-Host "Select mode [q/a]"
        if ($newMode -eq 'q' -or $newMode -eq 'quick') {
            $ctx.FindMode = 'quick'
            $defaultResult.SkipQuickPrompts = $false
            Write-Host "✓ Switched to Quick Album Search mode" -ForegroundColor Green
        }
        elseif ($newMode -eq 'a' -or $newMode -eq 'artist-first') {
            $ctx.FindMode = 'artist-first'
            Write-Host "✓ Switched to Artist-First Search mode" -ForegroundColor Green
            $defaultResult.CachedAlbums = $null
            $defaultResult.CachedArtistId = $null
            $defaultResult.ArtistQuery = $Artist
            $defaultResult.ProviderArtist = $null
        }
        else {
            Write-Warning "Invalid mode: $newMode. Staying with $($ctx.FindMode)."
        }
        & $syncBack
        return $defaultResult
    }

    # Default: treat input as new search query
    $defaultResult.ArtistQuery = $inputF
    Write-Verbose "Updated artistQuery to: '$inputF' (from selection prompt)"
    return $defaultResult
}
