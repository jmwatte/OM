function New-OMContext {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)][scriptblock]$InputReader,
        [Parameter(Mandatory = $false)][scriptblock]$DisplayWriter,
        [Parameter(Mandatory = $false)][object]$Config,
        [Parameter(Mandatory = $false)][string]$Provider,
        [Parameter(Mandatory = $false)][switch]$UseWhatIf,
        [Parameter(Mandatory = $false)][switch]$NonInteractive,
        [Parameter(Mandatory = $false)][hashtable]$InitialState
    )

    # Defaults: InputReader -> Read-Host -Prompt ; DisplayWriter -> Write-Host wrapper
    $ir = if ($InputReader) { $InputReader } else { { param($prompt) Read-Host -Prompt $prompt } }
    $dw = if ($DisplayWriter) { $DisplayWriter } else { { param($msg, $foregroundColor = $null) if ($foregroundColor) { Write-Host $msg -ForegroundColor $foregroundColor } else { Write-Host $msg } } }

    $state = [ordered]@{
        InputReader = $ir
        DisplayWriter = $dw
        Config = $Config
        Provider = $Provider
        Album = $null
        AlbumCandidates = @()
        TracksForAlbum = @()
        PairedTracks = @()
        UseWhatIf = [bool]$UseWhatIf
        NonInteractive = [bool]$NonInteractive
        CachedAlbums = $null
        CachedArtistId = $null
        Stage = $null
        Verbose = $false
    }

    if ($InitialState) {
        foreach ($k in $InitialState.Keys) {
            if ($state.ContainsKey($k)) { $state[$k] = $InitialState[$k] }
            else { $state[$k] = $InitialState[$k] }
        }
    }

    return [PSCustomObject]$state
}
