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
}
