function Invoke-OMFolderRename {
    <#
    .SYNOPSIS
        Build move args, run GC, and invoke folder rename with retry support.
    .DESCRIPTION
        Handles artist name resolution, path sanitization, GC for file handle release,
        CWD management, and folder rename with interactive retry.
    #>
    param(
        [string]$AlbumPath,
        $ProviderAlbum,
        $ProviderArtist,
        [array]$AudioFiles,
        [string]$AlbumNameFallback,
        $ManualAlbumArtist,
        [bool]$UseWhatIf,
        [switch]$SkipTagReading
    )

    $year = Get-ReleaseYear -ReleaseDate (Get-IfExists $ProviderAlbum 'release_date')
    $safeAlbumName = Approve-PathSegment -Segment (Get-IfExists $ProviderAlbum 'name') -Replacement '_' -CollapseRepeating -Transliterate

    $artistNameForFolder = Get-ArtistNameForFolder `
        -AudioFiles $AudioFiles `
        -ProviderAlbum $ProviderAlbum `
        -ProviderArtist $ProviderArtist `
        -AlbumNameFallback $AlbumNameFallback `
        -ManualAlbumArtist $ManualAlbumArtist `
        -SkipTagReading:$SkipTagReading

    $safeArtistName = Approve-PathSegment -Segment $artistNameForFolder -Replacement '_' -CollapseRepeating -Transliterate

    $mvArgs = @{
        AlbumPath    = $AlbumPath
        NewArtist    = $safeArtistName
        NewYear      = $year
        NewAlbumName = $safeAlbumName
    }

    # Force garbage collection to release any lingering file handles before folder rename
    if (-not $UseWhatIf) {
        Write-Verbose "Forcing garbage collection before folder move to release file handles"
        [System.GC]::Collect()
        [System.GC]::WaitForPendingFinalizers()
        [System.GC]::Collect()
        Start-Sleep -Milliseconds 100
    }

    # If the current working directory is inside the album folder, temporarily move out
    $cwdInsideAlbum = $false
    $resolvedAlbumPath = (Resolve-Path -LiteralPath $AlbumPath -ErrorAction SilentlyContinue).ProviderPath
    $currentCwd = (Get-Location).ProviderPath
    if ($resolvedAlbumPath -and $currentCwd -and
        ($currentCwd -eq $resolvedAlbumPath -or $currentCwd.StartsWith($resolvedAlbumPath + [System.IO.Path]::DirectorySeparatorChar))) {
        $cwdInsideAlbum = $true
        $cwdParent = Split-Path -Parent $resolvedAlbumPath
        Write-Verbose "CWD is inside album folder - temporarily changing to parent: $cwdParent"
        Push-Location -LiteralPath $cwdParent
    }

    try {
        # Interactive retry wrapper around the core move function
        $onRetry = { param($err) return (Read-Host "Folder may be in use by another process. Free the folder (close files/apps) and press Enter to retry, or 's' to skip") }
        $result = Invoke-MoveAlbumWithRetryCore -mvArgs $mvArgs -UseWhatIf:$UseWhatIf -OnRetry $onRetry
    }
    finally {
        if ($cwdInsideAlbum) {
            Pop-Location
            if ($result -and $result.Success -and $result.NewAlbumPath -ne $AlbumPath) {
                if (Test-Path -LiteralPath $result.NewAlbumPath -PathType Container) {
                    Set-Location -LiteralPath $result.NewAlbumPath
                    Write-Verbose "Updated CWD to renamed album folder: $($result.NewAlbumPath)"
                }
            }
        }
    }

    return $result
}
