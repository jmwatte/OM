function Invoke-StageB-HandleSelection {
    [CmdletBinding()]
    param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('SaveToFolder','EmbedInTags')]
    [string]$Action,

    [Parameter(Mandatory=$true)][string]$RangeText,
    [Parameter(Mandatory=$true)][array]$AlbumCandidates,
    [Parameter(Mandatory=$false)][string]$AlbumPath,
    [Parameter(Mandatory=$false)][string]$AudioSortMethod = 'alphabetical',
    [Parameter(Mandatory=$false)][bool]$UseWhatIf = $false,
    [Parameter(Mandatory=$false)][string]$Provider
)

# Ensure helper deps are available at runtime
$pCandidates = @()
if ($PSScriptRoot) { $pCandidates += Join-Path $PSScriptRoot '..\Utils\Expand-SelectionRange.ps1' }
if ($MyInvocation.MyCommand.Path) { $pCandidates += Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) '..\Utils\Expand-SelectionRange.ps1' }
$pCandidates += Join-Path (Get-Location).Path 'Private\Utils\Expand-SelectionRange.ps1'
$p = $pCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if ($p) { . $p }

$gCandidates = @()
if ($PSScriptRoot) { $gCandidates += Join-Path $PSScriptRoot '..\Get-IfExists.ps1' }
if ($MyInvocation.MyCommand.Path) { $gCandidates += Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) '..\Get-IfExists.ps1' }
$gCandidates += Join-Path (Get-Location).Path 'Private\Get-IfExists.ps1'
$g = $gCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if ($g) { . $g }

    $result = [PSCustomObject]@{
        Success = $true
        UpdatedCount = 0
        SkippedCount = 0
        Warnings = @()
        Error = $null
        NoAudioFiles = $false
    }

    try {
        $selectedIndices = Expand-SelectionRange -RangeText $RangeText -MaxIndex $AlbumCandidates.Count
    } catch {
        $result.Success = $false
        $result.Error = "Invalid range syntax for ${Action}: ${RangeText} - $_"
        return $result
    }

    if ($selectedIndices -isnot [array]) { $selectedIndices = @($selectedIndices) }
    if ($selectedIndices.Count -eq 0) {
        $result.Success = $false
        $result.Error = "No valid albums selected for $Action"
        return $result
    }

    if ($Action -eq 'SaveToFolder') {
        $config = Get-OMConfig
        $maxSize = $config.CoverArt.FolderImageSize

        foreach ($index in $selectedIndices) {
            $albumIndex = $index - 1
            $selectedAlbum = $AlbumCandidates[$albumIndex]
            $coverUrl = Get-IfExists $selectedAlbum 'cover_url'
            if ($coverUrl) {
                $saveRes = Save-CoverArt -CoverUrl $coverUrl -AlbumPath $AlbumPath -Action SaveToFolder -MaxSize $maxSize -WhatIf:$UseWhatIf
                if (-not $saveRes.Success) {
                    $msg = "Failed to save cover art for album $index ($($selectedAlbum.name)): $($saveRes.Error)"
                    Write-Warning $msg
                    $result.Warnings += $msg
                } else {
                    $result.UpdatedCount++
                }
            } else {
                $msg = "No cover art available for album $index ($($selectedAlbum.name))"
                Write-Warning $msg
                $result.Warnings += $msg
            }
        }
        return $result
    }

    if ($Action -eq 'EmbedInTags') {
        $config = Get-OMConfig
        $maxSize = $config.CoverArt.TagImageSize

        # Get audio files for embedding
        $audioFiles = Get-OMAudioFile -Path $AlbumPath -SortMethod $AudioSortMethod | Where-Object { $_ -ne $null }
        if ($audioFiles.Count -eq 0) {
            $msg = "No audio files found to embed cover art in"
            Write-Warning $msg
            $result.Success = $false
            $result.NoAudioFiles = $true
            $result.Error = $msg
            return $result
        }

        foreach ($index in $selectedIndices) {
            $albumIndex = $index - 1
            $selectedAlbum = $AlbumCandidates[$albumIndex]
            $coverUrl = Get-IfExists $selectedAlbum 'cover_url'
            if ($coverUrl) {
                $embedRes = Save-CoverArt -CoverUrl $coverUrl -AudioFiles $audioFiles -Action EmbedInTags -MaxSize $maxSize -WhatIf:$UseWhatIf
                if (-not $embedRes.Success) {
                    $msg = "Failed to embed cover art for album $index ($($selectedAlbum.name)): $($embedRes.Error)"
                    Write-Warning $msg
                    $result.Warnings += $msg
                } else {
                    $result.UpdatedCount++
                }
            } else {
                $msg = "No cover art available for album $index ($($selectedAlbum.name))"
                Write-Warning $msg
                $result.Warnings += $msg
            }
        }

        # Clean up tag files if any were created by Save-CoverArt (contract: Save-CoverArt may leave TagFile on each audioFile)
        foreach ($af in $audioFiles) {
            if ($af.TagFile) {
                try { $af.TagFile.Dispose() } catch { }
            }
        }

        return $result
    }

    return $result
}