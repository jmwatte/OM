Describe 'Move-OMTags Context propagation' {
    It 'uses Context and emits moved/renamed messages' {
        . (Join-Path $PSScriptRoot '..\Public\Move-OMTags.ps1')
        . (Join-Path $PSScriptRoot '..\Private\Utils\Show-Message.ps1')

        $testDir = Join-Path $env:TEMP ("OMMoveTest_" + (Get-Random))
        New-Item -ItemType Directory -Path $testDir | Out-Null
        $albumFolder = Join-Path $testDir 'Album'
        New-Item -ItemType Directory -Path $albumFolder | Out-Null
        $file = Join-Path $albumFolder '01 - track.mp3'
        New-Item -ItemType File -Path $file | Out-Null

        # Ensure TagLib presence by adding a fake assembly named with TagLib
        Add-Type -TypeDefinition 'public class _X {}' -Language CSharp -AssemblyName 'TagLib.Fake'

        # Stub functions and cmdlets used by Move-OMTags
        Mock -CommandName Get-OMTags -MockWith { @([PSCustomObject]@{ Path = $file; AlbumArtists = 'Artist'; Year = 2000; Album = 'Album'; Disc = 1; Track = 1; TrackCount = 1; DiscCount = 1 }) }
        Mock -CommandName Expand-RenamePattern -MockWith { param($Pattern,$TagObject,$FileExtension) return "01 - Title$FileExtension" }

        # Mock Move-Item and Get-ChildItem so we don't touch disk
        Mock -CommandName Move-Item -MockWith { }
        Mock -CommandName Get-ChildItem -MockWith { param($LiteralPath,$Filter,$Recurse,$File) return [PSCustomObject]@{ FullName = Join-Path $LiteralPath $Filter } }

        $script:messages = @()
        Mock -CommandName Show-Message -MockWith { param($Message,$ForegroundColor,$NoNewline,$DisplayWriter,$Context) $script:messages += $Message }

        $ctx = [PSCustomObject]@{ DisplayWriter = { param($msg,$color,$no) $script:messages += "DW: $msg" } }

        $target = Join-Path $testDir 'Target'
        New-Item -ItemType Directory -Path $target | Out-Null

        Move-OMTags -Path $albumFolder -TargetFolder $target -FileRenamePattern '{Track} - {Title}' -Context $ctx -PassThru

        $script:messages | Should -Not -BeNullOrEmpty
        ($script:messages -join "`n") | Should -Match 'Moved folder to|Renamed'

        # Cleanup
        Remove-Item -LiteralPath $testDir -Recurse -Force
    }
}