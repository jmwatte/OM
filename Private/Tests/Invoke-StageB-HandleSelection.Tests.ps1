Describe 'Invoke-StageB-HandleSelection' {
    BeforeAll {
        $pCandidates = @()
        if ($PSScriptRoot) { $pCandidates += Join-Path $PSScriptRoot '..\Utils\Invoke-StageB-HandleSelection.ps1' }
        if ($MyInvocation.MyCommand.Path) { $pCandidates += Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) '..\Utils\Invoke-StageB-HandleSelection.ps1' }
        $pCandidates += Join-Path (Get-Location).Path 'Private\Utils\Invoke-StageB-HandleSelection.ps1'
        $p = $pCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
        if (-not $p) { Throw "Helper not found: $p" }
        . $p

        # Ensure helper deps
        $g = Join-Path (Split-Path -Parent $p) '..\Get-IfExists.ps1'
        if (Test-Path $g) { . $g }

        # Dot-source Expand-SelectionRange for range parsing
        $x = Join-Path (Split-Path -Parent $p) '..\Expand-SelectionRange.ps1'
        if (Test-Path $x) { . $x }

        # Define stubs so Mock can target them even if not present in the environment
        if (-not (Get-Command Save-CoverArt -ErrorAction SilentlyContinue)) { function Save-CoverArt { param($args) } }
        if (-not (Get-Command Get-OMConfig -ErrorAction SilentlyContinue)) { function Get-OMConfig { param($args) } }
        if (-not (Get-Command Get-OMAudioFile -ErrorAction SilentlyContinue)) { function Get-OMAudioFile { param($args) } }
    }

    It 'saves cover art to folder for selected indices' {
        $albums = @(
            @{ name = 'A'; cover_url = 'http://a' },
            @{ name = 'B'; cover_url = 'http://b' }
        )

        Mock -CommandName Get-OMConfig -MockWith { return [PSCustomObject]@{ CoverArt = @{ FolderImageSize = 300 } } }
        Mock -CommandName Save-CoverArt -MockWith { param($CoverUrl,$AlbumPath,$Action,$MaxSize,$WhatIf) return [PSCustomObject]@{ Success = $true } }

        $res = Invoke-StageB-HandleSelection -Action 'SaveToFolder' -RangeText '1..2' -AlbumCandidates $albums -AlbumPath 'C:\tmp' -UseWhatIf:$true
        $res.UpdatedCount | Should -Be 2
        Assert-MockCalled -CommandName Save-CoverArt -Times 2
    }

    It 'warns when save fails for one album' {
        $albums = @(
            @{ name = 'A'; cover_url = 'http://a' },
            @{ name = 'B'; cover_url = 'http://b' }
        )
        Mock -CommandName Get-OMConfig -MockWith { return [PSCustomObject]@{ CoverArt = @{ FolderImageSize = 300 } } }
        Mock -CommandName Save-CoverArt -MockWith { param($CoverUrl,$AlbumPath,$Action,$MaxSize,$WhatIf) if ($CoverUrl -match 'b') { return [PSCustomObject]@{ Success = $false; Error = 'disk' } } else { return [PSCustomObject]@{ Success = $true } } }
        Mock -CommandName Write-Warning -MockWith { param($Message) return $Message }

        $res = Invoke-StageB-HandleSelection -Action 'SaveToFolder' -RangeText '1..2' -AlbumCandidates $albums -AlbumPath 'C:\tmp'
        $res.UpdatedCount | Should -Be 1
        Assert-MockCalled -CommandName Write-Warning -ParameterFilter { $Message -match 'Failed to save cover art for album 2' } -Times 1
    }

    It 'skips when cover_url missing' {
        $albums = @(
            @{ name = 'A' }, @{ name = 'B'; cover_url = 'http://b' }
        )
        Mock -CommandName Get-OMConfig -MockWith { return [PSCustomObject]@{ CoverArt = @{ FolderImageSize = 300 } } }
        Mock -CommandName Save-CoverArt -MockWith { param($CoverUrl,$AlbumPath,$Action,$MaxSize,$WhatIf) return [PSCustomObject]@{ Success = $true } }
        Mock -CommandName Write-Warning -MockWith { param($Message) return $Message }

        $res = Invoke-StageB-HandleSelection -Action 'SaveToFolder' -RangeText '1..2' -AlbumCandidates $albums -AlbumPath 'C:\tmp'
        $res.UpdatedCount | Should -Be 1
        Assert-MockCalled -CommandName Write-Warning -ParameterFilter { $Message -match 'No cover art available for album 1' } -Times 1
    }

    It 'reports no audio files for EmbedInTags when none found' {
        $albums = @(@{ name = 'A'; cover_url = 'http://a' })
        Mock -CommandName Get-OMConfig -MockWith { return [PSCustomObject]@{ CoverArt = @{ TagImageSize = 200 } } }
        Mock -CommandName Get-OMAudioFile -MockWith { param($Path,$SortMethod) return @() }
        Mock -CommandName Write-Warning -MockWith { param($Message) return $Message }

        $res = Invoke-StageB-HandleSelection -Action 'EmbedInTags' -RangeText '1' -AlbumCandidates $albums -AlbumPath 'C:\tmp'
        $res.NoAudioFiles | Should -BeTrue
        Assert-MockCalled -CommandName Write-Warning -ParameterFilter { $Message -match 'No audio files found to embed cover art in' } -Times 1
    }

    It 'embeds in tags when audio files present' {
        $albums = @(@{ name = 'A'; cover_url = 'http://a' })
        $fakeAudio = @([PSCustomObject]@{ FilePath = 'C:\tmp\1.mp3' })
        Mock -CommandName Get-OMConfig -MockWith { return [PSCustomObject]@{ CoverArt = @{ TagImageSize = 200 } } }
        Mock -CommandName Get-OMAudioFile -MockWith { param($Path,$SortMethod) return $fakeAudio }
        Mock -CommandName Save-CoverArt -MockWith { param($CoverUrl,$AudioFiles,$Action,$MaxSize,$WhatIf) return [PSCustomObject]@{ Success = $true } }

        $res = Invoke-StageB-HandleSelection -Action 'EmbedInTags' -RangeText '1' -AlbumCandidates $albums -AlbumPath 'C:\tmp'
        $res.UpdatedCount | Should -Be 1
        Assert-MockCalled -CommandName Save-CoverArt -Times 1
    }
}