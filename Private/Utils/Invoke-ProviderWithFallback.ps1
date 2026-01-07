function Invoke-ProviderWithFallback {
    param(
        [string]$PrimaryProvider,
        [string]$Artist,
        [string]$Album,
        [int]$TrackCount,
        [double]$Threshold,
        [switch]$EnableFallback
    )
    
    # Try primary provider
    Write-Host "🔍 AUTO: Searching $PrimaryProvider for '$Album' by '$Artist'..." -ForegroundColor Cyan
    Write-Verbose ("Invoke-ProviderWithFallback: PrimaryProvider={0}, Album={1}, Artist={2}, TrackCount={3}, Threshold={4}, EnableFallback={5}" -f $PrimaryProvider, $Album, $Artist, $TrackCount, $Threshold, $EnableFallback)

    if ([string]::IsNullOrWhiteSpace($PrimaryProvider)) { Write-Verbose "Invoke-ProviderWithFallback: PrimaryProvider is empty"; return $null }

    try {
        $results = Invoke-ProviderSearch -Provider $PrimaryProvider -Album $Album -Artist $Artist -Type album
        $candidates = if ($results -and $results.albums -and $results.albums.PSObject.Properties.Name -contains 'items' -and $results.albums.items) { @($results.albums.items | Where-Object { $_ -ne $null }) } else { @() }
    }
    catch {
        Write-Verbose "Primary provider search failed: $_"
        $candidates = @()
    }
    
    if ($candidates.Count -gt 0) {
        $bestMatch = Get-BestAutoMatch -Candidates $candidates -LocalArtist $Artist `
            -LocalAlbum $Album -LocalTrackCount $TrackCount -Threshold $Threshold
        
        if ($bestMatch) {
            Write-Host "✓ AUTO: Found high-confidence match on $PrimaryProvider ($($bestMatch.Confidence)%)" -ForegroundColor Green
            return @{
                Provider = $PrimaryProvider
                Album = $bestMatch.Album
                Confidence = $bestMatch.Confidence
                IsFallback = $false
            }
        }
    }
    
    # No good match - try fallback if enabled
    if (-not $EnableFallback) {
        Write-Verbose "No high-confidence match on $PrimaryProvider and fallback disabled"
        return $null
    }
    
    # Fallback chain: Qobuz → Spotify → Discogs → MusicBrainz
    # Always try Qobuz first (most reliable), then Spotify
    $fallbackChain = switch ($PrimaryProvider) {
        'Qobuz' { @('Spotify', 'Discogs', 'MusicBrainz') }
        'Spotify' { @('Qobuz', 'Discogs', 'MusicBrainz') }
        'Discogs' { @('Qobuz', 'Spotify', 'MusicBrainz') }
        'MusicBrainz' { @('Qobuz', 'Spotify', 'Discogs') }
    }
    
    foreach ($fallbackProvider in $fallbackChain) {
        Write-Host "⚠️  AUTO: No good match on $PrimaryProvider, trying $fallbackProvider..." -ForegroundColor Yellow
        
        try {
            $fallbackResults = Invoke-ProviderSearch -Provider $fallbackProvider -Album $Album -Artist $Artist -Type album
            $fallbackCandidates = if ($fallbackResults -and $fallbackResults.albums -and $fallbackResults.albums.PSObject.Properties.Name -contains 'items' -and $fallbackResults.albums.items) { @($fallbackResults.albums.items | Where-Object { $_ -ne $null }) } else { @() }
        }
        catch {
            Write-Verbose "Fallback provider $fallbackProvider search failed: $_"
            continue
        }
        
        if ($fallbackCandidates.Count -gt 0) {
            $bestMatch = Get-BestAutoMatch -Candidates $fallbackCandidates -LocalArtist $Artist `
                -LocalAlbum $Album -LocalTrackCount $TrackCount -Threshold $Threshold
            
            if ($bestMatch) {
                Write-Host "✓ AUTO: Found high-confidence match on $fallbackProvider ($($bestMatch.Confidence)% confidence)" -ForegroundColor Green
                return @{
                    Provider = $fallbackProvider
                    Album = $bestMatch.Album
                    Confidence = $bestMatch.Confidence
                    IsFallback = $true
                }
            }
        }
    }
    
    Write-Verbose "No high-confidence match found on any provider"
    return $null
}

