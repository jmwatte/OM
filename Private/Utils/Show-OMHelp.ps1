function Show-OMHelp {
    <#
    .SYNOPSIS
        Displays available commands for a given stage/prompt context in Start-OM.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet(
            'QuickFind-Retry',
            'QuickFind-Select',
            'StageA-NoResults',
            'StageA-Select',
            'StageB-NoResults',
            'StageB-Select',
            'StageC',
            'StageC-NoTracks',
            'StageC-FetchFail'
        )]
        [string]$Context
    )

    $commands = switch ($Context) {
        'QuickFind-Retry' {
            @(
                @{ Cmd = 'Enter';        Desc = 'Retry search with same terms' }
                @{ Cmd = 'ps/pq/pd/pm';  Desc = 'Switch provider (Spotify/Qobuz/Discogs/MusicBrainz)' }
                @{ Cmd = 'a';            Desc = 'Switch to artist-first mode' }
                @{ Cmd = 'ni';           Desc = 'New Item - enter new artist + album' }
                @{ Cmd = 'x';            Desc = 'Skip this album' }
                @{ Cmd = '<text>';        Desc = 'Search with new album name' }
                @{ Cmd = '?';            Desc = 'Show this help' }
            )
        }
        'QuickFind-Select' {
            @(
                @{ Cmd = '1-N / Enter';  Desc = 'Select album by number (Enter = first)' }
                @{ Cmd = 'b';            Desc = 'Back to artist/album search' }
                @{ Cmd = 'p';            Desc = 'Show current provider' }
                @{ Cmd = 'ps/pq/pd/pm';  Desc = 'Switch provider' }
                @{ Cmd = 'f';            Desc = 'Switch to artist-first mode' }
                @{ Cmd = 'ni';           Desc = 'New Item - enter new artist + album' }
                @{ Cmd = 'cv/cvo/cs/ct'; Desc = 'Cover: view/original/save/tags' }
                @{ Cmd = 'x';            Desc = 'Skip this album' }
                @{ Cmd = '<text>';        Desc = 'Search with new term' }
                @{ Cmd = '?';            Desc = 'Show this help' }
            )
        }
        'StageA-NoResults' {
            @(
                @{ Cmd = 'ps/pq/pd/pm';  Desc = 'Switch provider' }
                @{ Cmd = 'p';            Desc = 'Show current provider' }
                @{ Cmd = 'x';            Desc = 'Skip this album' }
                @{ Cmd = 'id:<id>';      Desc = 'Select artist by provider ID' }
                @{ Cmd = '<text>';        Desc = 'Search with new artist name' }
                @{ Cmd = '?';            Desc = 'Show this help' }
            )
        }
        'StageA-Select' {
            @(
                @{ Cmd = '1-N / Enter';  Desc = 'Select artist by number (Enter = first)' }
                @{ Cmd = 'p';            Desc = 'Show current provider' }
                @{ Cmd = 'ps/pq/pd/pm';  Desc = 'Switch provider' }
                @{ Cmd = 'f';            Desc = 'Toggle find mode (quick/artist-first)' }
                @{ Cmd = 'id:<id>';      Desc = 'Select artist by provider ID' }
                @{ Cmd = 'al:<name>';    Desc = 'Change album name for search' }
                @{ Cmd = 'x';            Desc = 'Skip this album' }
                @{ Cmd = '<text>';        Desc = 'Search with new artist name' }
                @{ Cmd = '?';            Desc = 'Show this help' }
            )
        }
        'StageB-NoResults' {
            @(
                @{ Cmd = 'b';            Desc = 'Back to artist selection' }
                @{ Cmd = 'ps/pq/pd/pm';  Desc = 'Switch provider' }
                @{ Cmd = 'p';            Desc = 'Show current provider' }
                @{ Cmd = 'id:<id>';      Desc = 'Select album by provider ID' }
                @{ Cmd = 's / x';        Desc = 'Skip this album' }
                @{ Cmd = '<text>';        Desc = 'Filter by album name' }
                @{ Cmd = '?';            Desc = 'Show this help' }
            )
        }
        'StageB-Select' {
            @(
                @{ Cmd = '1-N / Enter';  Desc = 'Select album (Enter = first)' }
                @{ Cmd = 'b';            Desc = 'Back to artist selection' }
                @{ Cmd = 'n / pr';       Desc = 'Next / Previous page' }
                @{ Cmd = 'p';            Desc = 'Show current provider' }
                @{ Cmd = 'ps/pq/pd/pm';  Desc = 'Switch provider' }
                @{ Cmd = 'f';            Desc = 'Toggle find mode' }
                @{ Cmd = 'ni';           Desc = 'New Item - enter new artist + album' }
                @{ Cmd = 'id:<id>';      Desc = 'Select album by provider ID' }
                @{ Cmd = 'cv/cvo/cs/ct'; Desc = 'Cover: view/original/save/tags' }
                @{ Cmd = '*';            Desc = 'Select all albums' }
                @{ Cmd = 'x';            Desc = 'Skip this album' }
                @{ Cmd = '<text>';        Desc = 'Search with new term' }
                @{ Cmd = '?';            Desc = 'Show this help' }
            )
        }
        'StageC' {
            @(
                @{ Cmd = 'sa';           Desc = 'Save All (tags + cover + rename)' }
                @{ Cmd = 'st [range]';   Desc = 'Save tags (all or specific tracks)' }
                @{ Cmd = 'sf';           Desc = 'Save folder names only' }
                @{ Cmd = '---';          Desc = '' }
                @{ Cmd = 'o/d/t/n/l/h/m'; Desc = 'Sort: order/duration/track#/name/title/hybrid/manual' }
                @{ Cmd = 'r';            Desc = 'Reverse source/target columns' }
                @{ Cmd = 'rm';           Desc = 'Review marked tracks' }
                @{ Cmd = '---';          Desc = '' }
                @{ Cmd = 'cv/cvo/cs/ct'; Desc = 'Cover: view/original/save/tags' }
                @{ Cmd = 'aa';           Desc = 'Build custom album artist' }
                @{ Cmd = 'gm';           Desc = 'Toggle genre mode (Replace/Merge)' }
                @{ Cmd = 'w';            Desc = 'Toggle WhatIf mode' }
                @{ Cmd = 'v';            Desc = 'Toggle verbose output' }
                @{ Cmd = '---';          Desc = '' }
                @{ Cmd = 'b';            Desc = 'Back to album selection' }
                @{ Cmd = 'pr';           Desc = 'Previous (back in quick mode)' }
                @{ Cmd = 'p';            Desc = 'Show current provider' }
                @{ Cmd = 'ps/pq/pd/pm';  Desc = 'Switch provider' }
                @{ Cmd = 'f';            Desc = 'Toggle find mode' }
                @{ Cmd = 'x';            Desc = 'Skip this album' }
                @{ Cmd = '?';            Desc = 'Show this help' }
            )
        }
        'StageC-NoTracks' {
            @(
                @{ Cmd = 'Enter';        Desc = 'Skip this album' }
                @{ Cmd = 'b';            Desc = 'Try different release' }
                @{ Cmd = 'p';            Desc = 'Change provider' }
                @{ Cmd = '?';            Desc = 'Show this help' }
            )
        }
        'StageC-FetchFail' {
            @(
                @{ Cmd = 'Enter';        Desc = 'Skip this album' }
                @{ Cmd = 'r';            Desc = 'Retry track fetch' }
                @{ Cmd = 'b';            Desc = 'Back to album selection' }
                @{ Cmd = 'p';            Desc = 'Change provider' }
                @{ Cmd = '?';            Desc = 'Show this help' }
            )
        }
    }

    Write-Host ""
    Write-Host "  Available commands:" -ForegroundColor Cyan
    foreach ($cmd in $commands) {
        if ($cmd.Cmd -eq '---') {
            Write-Host ""
            continue
        }
        $paddedCmd = $cmd.Cmd.PadRight(18)
        Write-Host "  $paddedCmd" -ForegroundColor Yellow -NoNewline
        Write-Host " $($cmd.Desc)" -ForegroundColor Gray
    }
    Write-Host ""
}
