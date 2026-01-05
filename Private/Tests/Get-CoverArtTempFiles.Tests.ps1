Describe 'Get-CoverArtTempFiles' {
    BeforeAll {
        $pCandidates = @()
        if ($PSScriptRoot) { $pCandidates += Join-Path $PSScriptRoot '..\Utils\Get-CoverArtTempFiles.ps1' }
        if ($MyInvocation.MyCommand.Path) { $pCandidates += Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) '..\Utils\Get-CoverArtTempFiles.ps1' }
        $pCandidates += Join-Path (Get-Location).Path 'Private\Utils\Get-CoverArtTempFiles.ps1'
        $p = $pCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
        if (-not $p) { Throw "Helper not found at runtime: $p" }
        . $p
        # Ensure helper deps are available
        $g = Join-Path (Split-Path -Parent $p) '..\Get-IfExists.ps1'
        if (Test-Path $g) { . $g }
    }

    It 'downloads cover images to temp files' {
        $albums = @(
            @{ name = 'X'; cover_url = 'http://example.com/x.jpg' },
            @{ name = 'Y'; cover_url = 'http://example.com/y.jpg' }
        )

        Mock -CommandName Invoke-WebRequest -MockWith { param($Uri) return [PSCustomObject]@{ Content = [System.Text.Encoding]::UTF8.GetBytes('img') } }
        function Get-CoverArtUrl { param($CoverUrl,$Provider,$Size) return $CoverUrl }

        $files = Get-CoverArtTempFiles -AlbumList $albums -Size 'large'
        $files.Count | Should -Be 2
        foreach ($f in $files) { Test-Path $f | Should -BeTrue }

        # Cleanup
        foreach ($f in $files) { Remove-Item -LiteralPath $f -Force -ErrorAction SilentlyContinue }
    }

    It 'skips albums without cover_url' {
        $albums = @(@{ name = 'No' }, @{ name = 'Yes'; cover_url = 'http://example.com/v.jpg' })
        Mock -CommandName Invoke-WebRequest -MockWith { param($Uri) return [PSCustomObject]@{ Content = [System.Text.Encoding]::UTF8.GetBytes('img') } }
        $files = Get-CoverArtTempFiles -AlbumList $albums
        $files.Count | Should -Be 1
        foreach ($f in $files) { Remove-Item -LiteralPath $f -Force -ErrorAction SilentlyContinue }
    }

    It 'returns empty list when downloads fail' {
        $albums = @(@{ name = 'B'; cover_url = 'http://example.com/b.jpg' })
        Mock -CommandName Invoke-WebRequest -MockWith { throw 'network' }
        $files = Get-CoverArtTempFiles -AlbumList $albums
        $files.Count | Should -Be 0
    }
}