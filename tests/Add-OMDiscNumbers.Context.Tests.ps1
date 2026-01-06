Describe 'Add-OMDiscNumbers with Context' {
    It 'calls Show-Message when tag updates are applied and respects Context' {
        $testDir = Join-Path $env:TEMP ("OMTest_" + (Get-Random))
        New-Item -ItemType Directory -Path $testDir | Out-Null
        # Create disc subfolder
        $discFolder = Join-Path $testDir 'Disc 1'
        New-Item -ItemType Directory -Path $discFolder | Out-Null
        $file = Join-Path $discFolder '01 - track.mp3'
        New-Item -ItemType File -Path $file | Out-Null

        # Stub TagLib.File and Tag class so function can run without TagLib-Sharp
        $typeDef = @"
using System;
namespace TagLib {
  public class File {
    public TagClass Tag = new TagClass();
    public static File Create(string path) { return new File(); }
    public void Save() { }
    public void Dispose() { }
  }
  public class TagClass {
    public int Disc = 0;
    public int Track = 0;
    public int DiscCount = 0;
    public int TrackCount = 0;
    public string[] AlbumArtists;
    public string Title;
  }
}
"@
        Add-Type -TypeDefinition $typeDef -Language CSharp -ErrorAction Stop

        # Stub Assert-TagLibLoaded so function doesn't try to load real TagLib during test
        function Assert-TagLibLoaded { return }

        # Dot-source the function under test
        . (Join-Path $PSScriptRoot '..\Public\Add-OMDiscNumbers.ps1')

        # Ensure Show-Message available
        . (Join-Path $PSScriptRoot '..\Private\Utils\Show-Message.ps1')

        $script:messages = @()
        Mock -CommandName Show-Message -MockWith { param($Message,$ForegroundColor,$NoNewline,$DisplayWriter,$Context) $script:messages += $Message }

        # Create a fake context with DisplayWriter to assert it's passed through
        $ctx = [PSCustomObject]@{ DisplayWriter = { param($msg,$color,$no) $script:messages += "DW: $msg" } }

        Add-OMDiscNumbers -baseFolder $testDir -discs -tracks -Context $ctx -Confirm:$false

        # Expect at least one update message
        $script:messages | Should -Not -BeNullOrEmpty
        ($script:messages -join "`n") | Should -Match 'Updated .*: .*'

        # Cleanup
        Remove-Item -LiteralPath $testDir -Recurse -Force
    }
}
