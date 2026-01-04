# Tests for Invoke-ProviderWithFallback
$p = Join-Path $PSScriptRoot '..\Utils\Invoke-ProviderWithFallback.ps1'
if (-not (Test-Path $p)) { Throw "Helper not found: $p" }

Describe 'Invoke-ProviderWithFallback' {
    BeforeAll {
        $p = Join-Path $PSScriptRoot '..\Utils\Invoke-ProviderWithFallback.ps1'
        if (-not (Test-Path $p)) { Throw "Helper not found: $p" }
        . $p
        $g = Join-Path $PSScriptRoot '..\Utils\Get-BestAutoMatch.ps1'
        if (-not (Test-Path $g)) { Throw "Helper not found: $g" }
        . $g
        $c = Join-Path $PSScriptRoot '..\Utils\Get-AlbumMatchConfidence.ps1'
        if (-not (Test-Path $c)) { Throw "Helper not found: $c" }
        . $c
        $s = Join-Path $PSScriptRoot '..\Utils\Get-StringSimilarity.ps1'
        if (-not (Test-Path $s)) { Throw "Helper not found: $s" }
        . $s
        $i = Join-Path $PSScriptRoot '..\Get-IfExists.ps1'
        if (-not (Test-Path $i)) { Throw "Helper not found: $i" }
        . $i
    }

    It 'returns primary provider match when primary yields high-confidence' {
        function Invoke-ProviderSearch {
            param($Provider,$Album,$Artist,$Type)
            if ($Provider -eq 'Spotify') { return [PSCustomObject]@{ albums = [PSCustomObject]@{ items = @([PSCustomObject]@{ name='Album'; artists=@([PSCustomObject]@{ name='Artist' }); total_tracks = 10 }) } } }
            else { return [PSCustomObject]@{ albums = [PSCustomObject]@{ items = @() } } }
        }
        function Get-BestAutoMatch { param($Candidates,$LocalArtist,$LocalAlbum,$LocalTrackCount,$Threshold) return @{ Album = $Candidates[0]; Index = 1; Confidence = 80 } }
        $res = Invoke-ProviderWithFallback -PrimaryProvider 'Spotify' -Artist 'Artist' -Album 'Album' -TrackCount 10 -Threshold 0.7 -EnableFallback:$false
        $res | Should -Not -Be $null
        $res.Provider | Should -Be 'Spotify'
        $res.IsFallback | Should -BeFalse
    }

    It 'falls back to another provider when primary yields no candidates and fallback enabled' {
        function Invoke-ProviderSearch {
            param($Provider,$Album,$Artist,$Type)
            switch ($Provider) {
                'Spotify' { return [PSCustomObject]@{ albums = [PSCustomObject]@{ items = @() } } }
                'Qobuz' { return [PSCustomObject]@{ albums = [PSCustomObject]@{ items = @([PSCustomObject]@{ name='Album'; artists=@([PSCustomObject]@{ name='Artist' }); total_tracks = 10 }) } } }
                default { return [PSCustomObject]@{ albums = [PSCustomObject]@{ items = @() } } }
            }
        }
        function Get-BestAutoMatch { param($Candidates,$LocalArtist,$LocalAlbum,$LocalTrackCount,$Threshold) return @{ Album = $Candidates[0]; Index = 1; Confidence = 75 } }
        $res = Invoke-ProviderWithFallback -PrimaryProvider 'Spotify' -Artist 'Artist' -Album 'Album' -TrackCount 10 -Threshold 0.7 -EnableFallback:$true
        $res | Should -Not -Be $null
        $res.Provider | Should -Be 'Qobuz'
        $res.IsFallback | Should -BeTrue
    }

    It 'returns null when primary fails and fallback disabled' {
        function Invoke-ProviderSearch { throw 'Service unavailable' }
        $res = Invoke-ProviderWithFallback -PrimaryProvider 'Spotify' -Artist 'Artist' -Album 'Album' -TrackCount 10 -Threshold 0.7 -EnableFallback:$false
        $res | Should -Be $null
    }
}
