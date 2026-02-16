function Invoke-OMCoverArtEmbed {
    <#
    .SYNOPSIS
        Loads audio files with TagLib handles, embeds cover art, and cleans up.
    .DESCRIPTION
        Shared helper for the 'ct' (cover art to tags) command used in both
        Stage B (album selection) and Stage C (track matching) of Start-OM.
        Opens fresh TagLib handles, calls Save-CoverArt -Action EmbedInTags,
        then disposes all handles regardless of outcome.
    .PARAMETER AlbumPath
        The album folder to find audio files in.
    .PARAMETER CoverUrl
        URL of the cover art image to embed.
    .PARAMETER MaxSize
        Maximum pixel dimension for the embedded image.
    .PARAMETER UseWhatIf
        When set, passes -WhatIf to Save-CoverArt.
    .OUTPUTS
        PSCustomObject with Success and Error properties from Save-CoverArt,
        or $null if no audio files were found.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$AlbumPath,

        [Parameter(Mandatory)]
        [string]$CoverUrl,

        [Parameter()]
        [int]$MaxSize,

        [Parameter()]
        [switch]$UseWhatIf
    )

    # Load audio files with fresh TagLib handles for embedding
    $audioFilesForCover = Get-ChildItem -LiteralPath $AlbumPath -File -Recurse |
        Where-Object { $_.Extension -match '\.(mp3|flac|wav|m4a|aac|ogg|ape)' } |
        Sort-Object { [regex]::Replace($_.Name, '(\d+)', { $args[0].Value.PadLeft(10, '0') }) } |
        ForEach-Object {
            try {
                $tagFile = [TagLib.File]::Create($_.FullName)
                [PSCustomObject]@{
                    FilePath = $_.FullName
                    TagFile  = $tagFile
                }
            }
            catch {
                Write-Warning "Skipping invalid audio file: $($_.FullName)"
                $null
            }
        } | Where-Object { $_ -ne $null }

    if (-not $audioFilesForCover -or $audioFilesForCover.Count -eq 0) {
        Write-Warning "No audio files found to embed cover art in"
        return $null
    }

    try {
        $saveParams = @{
            CoverUrl   = $CoverUrl
            AudioFiles = $audioFilesForCover
            Action     = 'EmbedInTags'
        }
        if ($MaxSize) { $saveParams['MaxSize'] = $MaxSize }

        $result = Save-CoverArt @saveParams -WhatIf:$UseWhatIf
        return $result
    }
    finally {
        # Always clean up TagFile handles
        foreach ($af in $audioFilesForCover) {
            if ($af.TagFile) {
                try { $af.TagFile.Dispose() } catch { }
            }
        }
    }
}
