Describe 'Export-OMTagsCsv' {
    BeforeAll {
        $fnPath = Join-Path $PSScriptRoot '..\..\Public\Export-OMTagsCsv.ps1'
        if (-not (Test-Path $fnPath)) { throw "Function file not found: $fnPath" }
        . $fnPath
    }

    It 'writes CSV with exact header order and mapped values' {
        $albumDir = Join-Path $TestDrive 'Album'
        New-Item -Path $albumDir -ItemType Directory -Force | Out-Null

        $trackPath = Join-Path $albumDir '01 - Intro.mp3'
        New-Item -Path $trackPath -ItemType File -Force | Out-Null

        Mock -CommandName Get-OMTags -MockWith {
            @(
                [PSCustomObject]@{
                    Path         = $trackPath
                    Title        = 'Song, "Quoted"'
                    Artists      = @('Artist A', 'Artist B')
                    AlbumArtists = @('Album Artist')
                    Album        = 'The Album'
                    Track        = 1
                    Disc         = 2
                    Year         = 2024
                    Genres       = @('Rock', 'Folk')
                    Composers    = @('Composer A')
                }
            )
        }

        $csvPath = Export-OMTagsCsv -Path $albumDir

        $csvPath | Should -Not -BeNullOrEmpty
        (Test-Path -LiteralPath $csvPath) | Should -BeTrue

        $header = Get-Content -LiteralPath $csvPath -TotalCount 1
        $header | Should -Be '"Full Path","Title","Artist","Album Artist","Album","Tracknumber","Discnumber","Year","Genre","Composer","Date Added"'

        $row = Import-Csv -LiteralPath $csvPath | Select-Object -First 1
        $row.'Full Path' | Should -Be $trackPath
        $row.Title | Should -Be 'Song, "Quoted"'
        $row.Artist | Should -Be 'Artist A; Artist B'
        $row.'Album Artist' | Should -Be 'Album Artist'
        $row.Album | Should -Be 'The Album'
        $row.Tracknumber | Should -Be '1'
        $row.Discnumber | Should -Be '2'
        $row.Year | Should -Be '2024'
        $row.Genre | Should -Be 'Rock; Folk'
        $row.Composer | Should -Be 'Composer A'
        $row.'Date Added' | Should -Match '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}$'
    }

    It 'creates a timestamped file if target CSV already exists' {
        $albumDir = Join-Path $TestDrive 'AlbumWithCollision'
        New-Item -Path $albumDir -ItemType Directory -Force | Out-Null

        $trackPath = Join-Path $albumDir '02 - Track.flac'
        New-Item -Path $trackPath -ItemType File -Force | Out-Null

        $existingPath = Join-Path $albumDir 'audio-tags.csv'
        'existing' | Set-Content -LiteralPath $existingPath -Encoding UTF8

        Mock -CommandName Get-OMTags -MockWith {
            @(
                [PSCustomObject]@{
                    Path         = $trackPath
                    Title        = 'Track'
                    Artists      = @('Artist')
                    AlbumArtists = @('Artist')
                    Album        = 'Album'
                    Track        = 2
                    Disc         = 1
                    Year         = 2025
                    Genres       = @('Electronic')
                    Composers    = @('Composer')
                }
            )
        }

        $csvPath = Export-OMTagsCsv -Path $albumDir

        $csvPath | Should -Not -Be $existingPath
        [System.IO.Path]::GetFileName($csvPath) | Should -Match '^audio-tags-\d{8}-\d{6}\.csv$'
        (Test-Path -LiteralPath $csvPath) | Should -BeTrue
    }
}