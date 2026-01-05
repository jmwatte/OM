

Describe 'Reload-OMAudioFiles' {
    BeforeAll {
        Write-Host "[RELOAD-TEST] BeforeAll start"

        # compute helper path candidates now that $env:RELOAD_TRACE exists
        $pCandidates = @()
        if ($PSScriptRoot) { $pCandidates += Join-Path $PSScriptRoot '..\Utils\Reload-OMAudioFiles.ps1' }
        if ($MyInvocation.MyCommand.Path) { $pCandidates += Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) '..\Utils\Reload-OMAudioFiles.ps1' }
        $pCandidates += Join-Path (Get-Location).Path 'Private\Utils\Reload-OMAudioFiles.ps1'
        $pCandidates += Join-Path (Join-Path (Get-Location).Path '..') 'Private\Utils\Reload-OMAudioFiles.ps1'
        $p = $pCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
        if (-not $p) { Throw "Helper not found at runtime: $p" }
        Write-Verbose "Dot-sourcing helper: $p"
        $resolved = (Resolve-Path -LiteralPath $p -ErrorAction Stop).Path
        Write-Verbose "Resolved helper path: $resolved"
        . $resolved
        # Attempt to dot-source Get-ApeDuration helper if available so tests can mock/override it
        $apeCandidate = Join-Path (Split-Path -Parent $resolved) '..\Get-ApeDuration.ps1'
        if (Test-Path $apeCandidate) {
            $apeCandidate = (Resolve-Path -LiteralPath $apeCandidate -ErrorAction SilentlyContinue).Path
            Write-Verbose "Dot-sourcing APE helper: $apeCandidate"
            . $apeCandidate
        }

        # Dot-source shared Get-OMTagFile helper so tests can mock it consistently
        $tagHelper = Join-Path (Split-Path -Parent $resolved) 'Get-OMTagFile.ps1'
        if (Test-Path $tagHelper) {
            $tagHelper = (Resolve-Path -LiteralPath $tagHelper -ErrorAction SilentlyContinue).Path
            Write-Verbose "Dot-sourcing Get-OMTagFile helper: $tagHelper"
            . $tagHelper
        }
        Write-Host "[RELOAD-TEST] BeforeAll end"
    }

    It 'returns audio file objects for a small temp folder' {
        Write-Host "[RELOAD-TEST] it1 start"
        $tmp = Join-Path $env:TEMP "om_reload_test_$([guid]::NewGuid().ToString())"
        New-Item -Path $tmp -ItemType Directory -Force | Out-Null
        $f = Join-Path $tmp '1 - Test.mp3'
        New-Item -Path $f -ItemType File -Force | Out-Null

        # Mock Get-OMTagFile to return an object with expected properties
        Mock -CommandName Get-OMTagFile -MockWith { [PSCustomObject]@{ Tag = [PSCustomObject]@{ Disc = 1; Track = 1; Title = 'Test'; Composers = @('C1'); Performers = @('A1') }; Properties = [PSCustomObject]@{ Duration = [TimeSpan]::FromMilliseconds(1234) } } }

        $res = Reload-OMAudioFiles -AlbumPath $tmp -Trace
        $res | Should -Not -Be $null
        $res.Count | Should -Be 1
        $res[0].FilePath | Should -Be $f
        $res[0].Duration | Should -Be 1234

        Remove-Item -LiteralPath $tmp -Recurse -Force
        Write-Host "[RELOAD-TEST] it1 end"
    }

    It 'handles .ape files by calling Get-ApeDuration' {
        Write-Host "[RELOAD-TEST] it2 start"
        $tmp = Join-Path $env:TEMP "om_reload_test_$([guid]::NewGuid().ToString())"
        New-Item -Path $tmp -ItemType Directory -Force | Out-Null
        $f = Join-Path $tmp '1 - Test.ape'
        New-Item -Path $f -ItemType File -Force | Out-Null

        Mock -CommandName Get-ApeDuration -MockWith { return 555 }

        $res = Reload-OMAudioFiles -AlbumPath $tmp -Trace
        $res.Count | Should -Be 1
        $res[0].Duration | Should -Be 555

        Remove-Item -LiteralPath $tmp -Recurse -Force
        Write-Host "[RELOAD-TEST] it2 end"
    }

    It 'skips corrupted files and logs a warning' {
        Write-Host "[RELOAD-TEST] it3 start"
        $tmp = Join-Path $env:TEMP "om_reload_test_$([guid]::NewGuid().ToString())"
        New-Item -Path $tmp -ItemType Directory -Force | Out-Null
        $f = Join-Path $tmp '1 - Bad.mp3'
        New-Item -Path $f -ItemType File -Force | Out-Null

        Mock -CommandName Get-OMTagFile -MockWith { throw 'bad file' }

        { Reload-OMAudioFiles -AlbumPath $tmp } | Should -Not -Throw

        Remove-Item -LiteralPath $tmp -Recurse -Force
        Write-Host "[RELOAD-TEST] it3 end"
    }


}