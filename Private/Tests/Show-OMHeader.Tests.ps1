$helperPath = Join-Path $PSScriptRoot '..\Utils\Show-OMHeader.ps1'
if (-not (Test-Path $helperPath)) { Throw "Helper not found: $helperPath" }

Describe 'Show-OMHeader' {
    BeforeAll { . (Join-Path $PSScriptRoot '..\Utils\Show-OMHeader.ps1') }
    It 'runs without error for basic input' {
        { Show-OMHeader -Provider 'Test' -Artist 'Artist' -AlbumName 'Album' -TrackCount 3 } | Should -Not -Throw
    }

    It 'handles Qobuz locale and script album input' {
        $scriptAlbum = @{ Name = '2011 - Example Album'; FullName = 'C:\\temp\\2011 - Example Album' }
        { Show-OMHeader -Provider 'Qobuz' -Artist 'Artist' -AlbumName 'Album' -QobuzUrlLocale 'en-US' -ScriptAlbum $scriptAlbum } | Should -Not -Throw
    }

    It 'prints header only once for repeated identical calls' {
        # Reset dedupe state and capture Show-Message output for deterministic assertion
        Remove-Variable -Name __lastShownOMHeader -Scope Script -ErrorAction SilentlyContinue
        $script:msgs = [System.Collections.Generic.List[string]]::new()
        function global:Show-Message { param($m,$c,$no) $script:msgs.Add($m) }

        Show-OMHeader -Provider 'Test' -Artist 'Artist' -AlbumName 'Album' -TrackCount 3
        Show-OMHeader -Provider 'Test' -Artist 'Artist' -AlbumName 'Album' -TrackCount 3

        ($script:msgs | Where-Object { $_ -match 'Original Album' }).Count | Should -Be 1
    }

    It 'skips entirely empty header' {
        Remove-Variable -Name __lastShownOMHeader -Scope Script -ErrorAction SilentlyContinue
        $script:msgs = [System.Collections.Generic.List[string]]::new()
        function global:Show-Message { param($m,$c,$no) $script:msgs.Add($m) }

        Show-OMHeader -Provider '' -Artist '' -AlbumName ''

        $script:msgs.Count | Should -Be 0
    }
}
