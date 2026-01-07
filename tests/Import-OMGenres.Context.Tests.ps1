Describe 'Import-OMGenres Context propagation' {
    It 'imports JSON and emits messages via Show-Message' {
        Import-Module (Join-Path $PSScriptRoot '..\OM.psm1') -Force
        . (Join-Path $PSScriptRoot '..\Private\Utils\Show-Message.ps1')

        $tmp = Join-Path $env:TEMP ("om_import_genres_" + (Get-Random) + ".json")
        $payload = @{ AllowedGenreNames = @('Pop','Jazz'); GenreMappings = @{ 'x'='y' }; GarbageGenres = @() } | ConvertTo-Json -Depth 5
        Set-Content -Path $tmp -Value $payload -Encoding UTF8

        # Stub current config
        Mock -CommandName Get-OMConfig -ModuleName OM -MockWith { @{ Genres = [PSCustomObject]@{ AllowedGenreNames = @('Pop'); GenreMappings = @{}; GarbageGenres = @() } } }

        $script:messages = New-Object System.Collections.Concurrent.ConcurrentBag[System.String]
        Mock -CommandName Show-Message -ModuleName OM -MockWith { $script:messages.Add($args[0]) }

        Import-OMGenres -Path $tmp -Force -Context [PSCustomObject]@{}

        $script:messages | Should -Not -BeNullOrEmpty
        ($script:messages -join "`n") | Should -Match 'Imported|saved to|Merged'

        Remove-Item -LiteralPath $tmp -Force
    }
}