Describe 'Show-CoverArt' {
    BeforeAll {
        # Dot-source helper and dependencies
        $pCandidates = @()
        if ($PSScriptRoot) { $pCandidates += Join-Path $PSScriptRoot '..\Utils\Show-CoverArt.ps1' }
        if ($MyInvocation.MyCommand.Path) { $pCandidates += Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) '..\Utils\Show-CoverArt.ps1' }
        $pCandidates += Join-Path (Get-Location).Path 'Private\Utils\Show-CoverArt.ps1'
        $p = $pCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
        if (-not $p) { Throw "Helper not found at runtime: $p" }
        . $p

        # Dot-source Expand-SelectionRange for range parsing
        $xCandidates = @()
        if ($PSScriptRoot) { $xCandidates += Join-Path $PSScriptRoot '..\Utils\Expand-SelectionRange.ps1' }
        if ($MyInvocation.MyCommand.Path) { $xCandidates += Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) '..\Utils\Expand-SelectionRange.ps1' }
        $xCandidates += Join-Path (Get-Location).Path 'Private\Utils\Expand-SelectionRange.ps1'
        $x = $xCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
        if ($x) { . $x }

        # Dot-source Get-IfExists if available
        $gCandidates = @()
        if ($PSScriptRoot) { $gCandidates += Join-Path $PSScriptRoot '..\Get-IfExists.ps1' }
        if ($MyInvocation.MyCommand.Path) { $gCandidates += Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) '..\Get-IfExists.ps1' }
        $gCandidates += Join-Path (Get-Location).Path 'Private\Get-IfExists.ps1'
        $g = $gCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
        if ($g) { . $g }
    }

    It 'falls back to browser when chafa is not available' {
        $albums = @(
            @{ name = 'A'; cover_url = 'http://example.com/a.jpg' },
            @{ name = 'B'; cover_url = 'http://example.com/b.jpg' }
        )

        # Simulate chafa not installed by making Get-Command throw for 'chafa'
        Mock -CommandName Get-Command -MockWith { param($Name,$ErrorAction) if ($Name -eq 'chafa') { throw 'not found' } else { return $null } }

        # Capture any attempts to open the browser
        Mock -CommandName Start-Process -MockWith { param($FilePath) return $FilePath }

        Show-CoverArt -RangeText '1-2' -AlbumList $albums

        # Should have attempted to open each cover URL in the browser
        Assert-MockCalled -CommandName Start-Process -Times 2
        Assert-MockCalled -CommandName Start-Process -ParameterFilter { $FilePath -eq 'http://example.com/a.jpg' } -Times 1
        Assert-MockCalled -CommandName Start-Process -ParameterFilter { $FilePath -eq 'http://example.com/b.jpg' } -Times 1
    }

    It 'emits warnings when albums are missing cover art' {
        $albums = @(
            @{ name = 'NoCover' },
            @{ name = 'Has'; cover_url = 'http://example.com/h.jpg' },
            @{ name = 'AlsoNo' }
        )

        # Simulate chafa not installed to take the simpler browser-fallback path
        Mock -CommandName Get-Command -MockWith { param($Name,$ErrorAction) if ($Name -eq 'chafa') { throw 'not found' } else { return $null } }

        # Avoid actually opening browser
        Mock -CommandName Start-Process -MockWith { param($FilePath) return $FilePath }

        # Capture warnings
        Mock -CommandName Write-Warning -MockWith { param($Message) return $Message }

        Show-CoverArt -RangeText '1..3' -AlbumList $albums

        # Two albums lack cover_url and should trigger warnings
        Assert-MockCalled -CommandName Write-Warning -Times 2
        Assert-MockCalled -CommandName Write-Warning -ParameterFilter { $Message -match 'No cover art available for album 1' } -Times 1
        Assert-MockCalled -CommandName Write-Warning -ParameterFilter { $Message -match 'No cover art available for album 3' } -Times 1
    }

    It 'downloads images and falls back to browser when chafa lacks image support' {
        $albums = @(
            @{ name = 'C'; cover_url = 'http://example.com/c.jpg' },
            @{ name = 'D'; cover_url = 'http://example.com/d.jpg' }
        )

        # Simulate chafa present but terminal does not support images
        Mock -CommandName Get-Command -MockWith { param($Name,$ErrorAction) if ($Name -eq 'chafa') { return [PSCustomObject]@{ Name = 'chafa' } } else { return $null } }

        # Provide a fake chafa --help output that lacks 'sixel' or 'kitty'
        function chafa { param($args) return "chafa help text: no image protocols reported" }

        # Mock download to avoid network calls
        Mock -CommandName Invoke-WebRequest -MockWith { param($Uri) return [PSCustomObject]@{ Content = [System.Text.Encoding]::UTF8.GetBytes('img') } }

        # Capture fallback browser opens
        Mock -CommandName Start-Process -MockWith { param($FilePath) return $FilePath }

        Show-CoverArt -RangeText '1-2' -AlbumList $albums

        # Should have downloaded and then opened each URL in the browser due to chafa lacking image support
        Assert-MockCalled -CommandName Start-Process -Times 2
        Assert-MockCalled -CommandName Start-Process -ParameterFilter { $FilePath -eq 'http://example.com/c.jpg' } -Times 1
        Assert-MockCalled -CommandName Start-Process -ParameterFilter { $FilePath -eq 'http://example.com/d.jpg' } -Times 1

        # Cleanup temp files that Show-CoverArt leaves behind (cover1.jpg, cover2.jpg)
        $t1 = Join-Path $env:TEMP 'cover1.jpg'
        $t2 = Join-Path $env:TEMP 'cover2.jpg'
        if (Test-Path $t1) { Remove-Item -LiteralPath $t1 -Force -ErrorAction SilentlyContinue }
        if (Test-Path $t2) { Remove-Item -LiteralPath $t2 -Force -ErrorAction SilentlyContinue }
    }

    It 'uses chafa when chafa supports sixel/kitty' {
        $albums = @(
            @{ name = 'E'; cover_url = 'http://example.com/e.jpg' },
            @{ name = 'F'; cover_url = 'http://example.com/f.jpg' }
        )

        # Simulate chafa present
        Mock -CommandName Get-Command -MockWith { param($Name,$ErrorAction) if ($Name -eq 'chafa') { return [PSCustomObject]@{ Name = 'chafa' } } else { return $null } }

        # Make chafa --help report sixel support
        function global:chafa { param($args) return "chafa help: supports sixel" }

        # No process mocking to avoid interfering with helper types; rely on function chafa for --help probing
        $script:chafaStarted = $false

        # Mock network download
        Mock -CommandName Invoke-WebRequest -MockWith { param($Uri) return [PSCustomObject]@{ Content = [System.Text.Encoding]::UTF8.GetBytes('img') } }

        # Ensure no browser fallback attempted
        Mock -CommandName Start-Process -MockWith { param($FilePath) return $FilePath }

        # Create a helper chafa.bat in Private/ and add to PATH so '& chafa --help' returns expected help text
        $chafaDir = (Join-Path (Get-Location).Path 'Private')
        $chafaFile = Join-Path $chafaDir 'chafa.bat'
        $origPath = $env:PATH
        $bat = '@echo off
if "%1"=="--help" ( echo chafa help: supports sixel ) else ( exit /b 0 )'
        Set-Content -LiteralPath $chafaFile -Value $bat -Encoding ASCII
        $env:PATH = "$chafaDir;$env:PATH"

        $verboseOut = & { $VerbosePreference = 'Continue'; Show-CoverArt -RangeText '1-2' -AlbumList $albums } 4>&1

        # Restore PATH and remove helper
        $env:PATH = $origPath
        if (Test-Path $chafaFile) { Remove-Item -LiteralPath $chafaFile -Force -ErrorAction SilentlyContinue }

        # Downloads should have been attempted
        Assert-MockCalled -CommandName Invoke-WebRequest -Times 2

        # No browser fallback
        Assert-MockNotCalled -CommandName Start-Process

        # Cleanup
        if (Test-Path $t1) { Remove-Item -LiteralPath $t1 -Force -ErrorAction SilentlyContinue }
        if (Test-Path $t2) { Remove-Item -LiteralPath $t2 -Force -ErrorAction SilentlyContinue }
    }

    It 'warns and reports no cover art when all downloads fail' {
        $albums = @(
            @{ name = 'X'; cover_url = 'http://example.com/x.jpg' },
            @{ name = 'Y'; cover_url = 'http://example.com/y.jpg' }
        )

        # Simulate chafa present
        Mock -CommandName Get-Command -MockWith { param($Name,$ErrorAction) if ($Name -eq 'chafa') { return [PSCustomObject]@{ Name = 'chafa' } } else { return $null } }

        # Add transient chafa helper to PATH so --help reports sixel support
        $chafaDir = (Join-Path (Get-Location).Path 'Private')
        $chafaFile = Join-Path $chafaDir 'chafa.bat'
        $origPath = $env:PATH
        $bat = '@echo off
if "%1"=="--help" ( echo chafa help: supports sixel ) else ( exit /b 0 )'
        Set-Content -LiteralPath $chafaFile -Value $bat -Encoding ASCII
        $env:PATH = "$chafaDir;$env:PATH"

        # Simulate failed downloads for all albums
        Mock -CommandName Invoke-WebRequest -MockWith { throw 'network' }

        # Capture warnings
        Mock -CommandName Write-Warning -MockWith { param($Message) return $Message }

        # Avoid browser fallback
        Mock -CommandName Start-Process -MockWith { param($FilePath) return $FilePath }

        Show-CoverArt -RangeText '1-2' -AlbumList $albums

        # Expect per-album download failure warnings and a final 'No cover art could be downloaded' warning
        Assert-MockCalled -CommandName Write-Warning -ParameterFilter { $Message -match 'Failed to download cover for album 1' } -Times 1
        Assert-MockCalled -CommandName Write-Warning -ParameterFilter { $Message -match 'Failed to download cover for album 2' } -Times 1
        Assert-MockCalled -CommandName Write-Warning -ParameterFilter { $Message -match 'No cover art could be downloaded' } -Times 1

        # Cleanup transient helper
        $env:PATH = $origPath
        if (Test-Path $chafaFile) { Remove-Item -LiteralPath $chafaFile -Force -ErrorAction SilentlyContinue }
    }
}