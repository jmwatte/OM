function Show-Message {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [string]$ForegroundColor,

        [Parameter(Mandatory = $false)]
        [switch]$NoNewline,

        [Parameter(Mandatory = $false)][scriptblock]$DisplayWriter,
        [Parameter(Mandatory = $false)][object]$Context
    )

    # Decide which writer to call: explicit DisplayWriter, then Context.DisplayWriter, then fallback Write-Host
    $writer = if ($DisplayWriter) { $DisplayWriter } elseif ($Context -and $Context.DisplayWriter) { $Context.DisplayWriter } else { { param($msg, $color=$null, $none=$null) if ($color) { if ($PSBoundParameters.ContainsKey('NoNewline')) { Write-Host -NoNewline -ForegroundColor $color $msg } else { Write-Host $msg -ForegroundColor $color } } else { if ($PSBoundParameters.ContainsKey('NoNewline')) { Write-Host -NoNewline $msg } else { Write-Host $msg } } } }

    if ($NoNewline) {
        & $writer $Message $ForegroundColor $true
    }
    else {
        & $writer $Message $ForegroundColor
    }
}
