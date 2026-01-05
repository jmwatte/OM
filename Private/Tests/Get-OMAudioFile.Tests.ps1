Describe 'Get-OMAudioFile' {
    BeforeAll {
        # Dot-source helper and shared tag helper so mocks can apply
        $pCandidates = @()
        if ($PSScriptRoot) { $pCandidates += Join-Path $PSScriptRoot '..\Utils\Get-OMAudioFile.ps1' }
        if ($MyInvocation.MyCommand.Path) { $pCandidates += Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) '..\Utils\Get-OMAudioFile.ps1' }
        $pCandidates += Join-Path (Get-Location).Path 'Private\Utils\Get-OMAudioFile.ps1'
        $p = $pCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
        if (-not $p) { Throw "Helper not found at runtime: $p" }
        . $p

        # Dot-source tag helper and APE helper stubs if they exist
        $tagp = Join-Path (Split-Path -Parent $p) 'Get-OMTagFile.ps1'
        if (Test-Path $tagp) { . $tagp }
        $apep = Join-Path (Split-Path -Parent $p) '..\Get-ApeDuration.ps1'
        if (Test-Path $apep) { . $apep }
    }

    It 'returns audio file objects for a small temp folder' {
        $tmp = Join-Path $env:TEMP "om_audiofile_test_$([guid]::NewGuid().ToString())"
        New-Item -Path $tmp -ItemType Directory -Force | Out-Null
        $f = Join-Path $tmp '1 - Test.mp3'
        New-Item -Path $f -ItemType File -Force | Out-Null

        Mock -CommandName Get-OMTagFile -MockWith { [PSCustomObject]@{ Tag = [PSCustomObject]@{ Disc = 1; Track = 1; Title = 'Test'; Composers = @('C1'); Performers = @('A1') }; Properties = [PSCustomObject]@{ Duration = [TimeSpan]::FromMilliseconds(1234) } } }

        $res = Get-OMAudioFile -Path $tmp -Trace
        $res | Should -Not -Be $null
        $res.Count | Should -Be 1
        $res[0].FilePath | Should -Be $f
        $res[0].Duration | Should -Be 1234

        Remove-Item -LiteralPath $tmp -Recurse -Force
    }

    It 'handles .ape files by calling Get-ApeDuration' {
        $tmp = Join-Path $env:TEMP "om_audiofile_test_$([guid]::NewGuid().ToString())"
        New-Item -Path $tmp -ItemType Directory -Force | Out-Null
        $f = Join-Path $tmp '1 - Test.ape'
        New-Item -Path $f -ItemType File -Force | Out-Null

        Mock -CommandName Get-ApeDuration -MockWith { return 555 }

        $res = Get-OMAudioFile -Path $tmp -Trace
        $res.Count | Should -Be 1
        $res[0].Duration | Should -Be 555

        Remove-Item -LiteralPath $tmp -Recurse -Force
    }

    It 'skips corrupted files and logs a warning' {
        $tmp = Join-Path $env:TEMP "om_audiofile_test_$([guid]::NewGuid().ToString())"
        New-Item -Path $tmp -ItemType Directory -Force | Out-Null
        $f = Join-Path $tmp '1 - Bad.mp3'
        New-Item -Path $f -ItemType File -Force | Out-Null

        Mock -CommandName Get-OMTagFile -MockWith { throw 'bad file' }

        { Get-OMAudioFile -Path $tmp } | Should -Not -Throw

        Remove-Item -LiteralPath $tmp -Recurse -Force
    }
}