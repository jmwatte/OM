function Save-CoverArt {
    <#
    .SYNOPSIS
        Downloads and processes cover art images for albums.

    .DESCRIPTION
        Downloads cover art from provider URLs, resizes according to configuration,
        and either saves to album folder or embeds in audio file metadata.

    .PARAMETER CoverUrl
        URL of the cover art image to download

    .PARAMETER AlbumPath
        Path to the album folder (for saving cover.jpg)

    .PARAMETER AudioFiles
        Array of audio file objects (for embedding in tags)

    .PARAMETER Action
        What to do with the image: 'SaveToFolder' or 'EmbedInTags'

    .PARAMETER MaxSize
        Maximum dimension (width/height) for the image in pixels

    .PARAMETER WhatIf
        Preview the action without actually performing it

    .EXAMPLE
        Save-CoverArt -CoverUrl "https://..." -AlbumPath "C:\Music\Album" -Action SaveToFolder -MaxSize 1000

    .EXAMPLE
        Save-CoverArt -CoverUrl "https://..." -AudioFiles $files -Action EmbedInTags -MaxSize 500
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)]
        [string]$CoverUrl,

        [Parameter(Mandatory = $false)]
        [string]$AlbumPath,

        [Parameter(Mandatory = $false)]
        [array]$AudioFiles,

        [Parameter(Mandatory = $true)]
        [ValidateSet('SaveToFolder', 'EmbedInTags')]
        [string]$Action,

        [Parameter(Mandatory = $true)]
        [int]$MaxSize,

        [Parameter(Mandatory = $false)]
        [switch]$WhatIf
    )

    try {
        # Validate parameters based on action
        if ($Action -eq 'SaveToFolder' -and -not $AlbumPath) {
            throw "AlbumPath is required for SaveToFolder action"
        }
        if ($Action -eq 'EmbedInTags' -and -not $AudioFiles) {
            throw "AudioFiles is required for EmbedInTags action"
        }

        # Determine the best size to request from the provider
        # For folder saves, we want the largest available size
        # For tag embedding, we use the configured max size
        $desiredSize = if ($Action -eq 'SaveToFolder') { 'large' } else { 'medium' }

        # Try to determine provider from URL pattern
        $provider = $null
        if ($CoverUrl -match 'qobuz\.com') {
            $provider = 'Qobuz'
        }
        elseif ($CoverUrl -match 'spotify\.com') {
            $provider = 'Spotify'
        }
        elseif ($CoverUrl -match 'discogs\.com') {
            $provider = 'Discogs'
        }
        elseif ($CoverUrl -match 'coverartarchive\.org') {
            $provider = 'MusicBrainz'
        }

        # Get the optimal URL for the desired size
        $downloadUrl = if ($provider) {
            Get-CoverArtUrl -CoverUrl $CoverUrl -Provider $provider -Size $desiredSize
        } else {
            $CoverUrl  # Fallback to original URL
        }

        Write-Verbose "Downloading cover art from: $downloadUrl (provider: $provider, size: $desiredSize)"

        # Download the image
        try {
            $response = Invoke-WebRequest -Uri $downloadUrl -Method Get -UseBasicParsing -ErrorAction Stop
            $imageBytes = $response.Content
        }
        catch {
            Write-Warning "Failed to download cover art: $_"
            return [PSCustomObject]@{
                Success = $false
                Error = "Download failed: $_"
            }
        }

        # Load System.Drawing for image processing
        Add-Type -AssemblyName System.Drawing

        # Create image from bytes
        $memoryStream = New-Object System.IO.MemoryStream($imageBytes, 0, $imageBytes.Length)
        $originalImage = [System.Drawing.Image]::FromStream($memoryStream)

        # Calculate new dimensions maintaining aspect ratio
        $originalWidth = $originalImage.Width
        $originalHeight = $originalImage.Height
        $aspectRatio = $originalWidth / $originalHeight

        $newWidth = $MaxSize
        $newHeight = $MaxSize

        if ($originalWidth -gt $originalHeight) {
            # Landscape
            $newHeight = [int]($MaxSize / $aspectRatio)
        }
        else {
            # Portrait or square
            $newWidth = [int]($MaxSize * $aspectRatio)
        }

        # Ensure we don't exceed max size
        if ($newWidth -gt $MaxSize) { $newWidth = $MaxSize }
        if ($newHeight -gt $MaxSize) { $newHeight = $MaxSize }

        Write-Verbose "Resizing image from ${originalWidth}x${originalHeight} to ${newWidth}x${newHeight}"

        # Create resized bitmap
        $resizedBitmap = New-Object System.Drawing.Bitmap($newWidth, $newHeight)
        $graphics = [System.Drawing.Graphics]::FromImage($resizedBitmap)
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.DrawImage($originalImage, 0, 0, $newWidth, $newHeight)

        # Save to memory stream as JPEG
        $outputStream = New-Object System.IO.MemoryStream
        $resizedBitmap.Save($outputStream, [System.Drawing.Imaging.ImageFormat]::Jpeg)

        # Get the resized image bytes
        $resizedBytes = $outputStream.ToArray()

        # Clean up
        $graphics.Dispose()
        $resizedBitmap.Dispose()
        $originalImage.Dispose()
        $memoryStream.Dispose()
        $outputStream.Dispose()

        if ($Action -eq 'SaveToFolder') {
            $coverPath = Join-Path $AlbumPath "cover.jpg"

            if ($WhatIf) {
                Write-Host "WhatIf: Would save cover art to: $coverPath (${newWidth}x${newHeight})" -ForegroundColor Cyan
                return [PSCustomObject]@{
                    Success = $true
                    Action = "Preview"
                    Path = $coverPath
                    Size = "${newWidth}x${newHeight}"
                }
            }

            if ($PSCmdlet.ShouldProcess($coverPath, "Save cover art")) {
                [System.IO.File]::WriteAllBytes($coverPath, $resizedBytes)
                Write-Host "✓ Saved cover art to: $coverPath (${newWidth}x${newHeight})" -ForegroundColor Green
                return [PSCustomObject]@{
                    Success = $true
                    Action = "SavedToFolder"
                    Path = $coverPath
                    Size = "${newWidth}x${newHeight}"
                }
            }
        }
        elseif ($Action -eq 'EmbedInTags') {
            if ($WhatIf) {
                Write-Host "WhatIf: Would embed cover art (${newWidth}x${newHeight}) in $($AudioFiles.Count) audio files" -ForegroundColor Cyan
                return [PSCustomObject]@{
                    Success = $true
                    Action = "Preview"
                    FileCount = $AudioFiles.Count
                    Size = "${newWidth}x${newHeight}"
                }
            }

            $successCount = 0
            $failedFiles = @()

            foreach ($audioFile in $AudioFiles) {
                try {
                    $filePath = $audioFile.FilePath
                    if ($PSCmdlet.ShouldProcess($filePath, "Embed cover art")) {
                        $tagFile = [TagLib.File]::Create($filePath)

                        # Create picture object
                        $picture = [TagLib.Picture]::new()
                        $picture.Type = [TagLib.PictureType]::FrontCover
                        $picture.MimeType = "image/jpeg"
                        $picture.Description = "Cover"
                        $picture.Data = $resizedBytes

                        # Set the picture
                        $tagFile.Tag.Pictures = @($picture)

                        # Save the file
                        $tagFile.Save()
                        $tagFile.Dispose()

                        $successCount++
                        Write-Verbose "Embedded cover art in: $(Split-Path -Leaf $filePath)"
                    }
                }
                catch {
                    $failedFiles += $audioFile.FilePath
                    Write-Warning "Failed to embed cover art in $(Split-Path -Leaf $audioFile.FilePath): $_"
                }
            }

            if ($successCount -gt 0) {
                Write-Host "✓ Embedded cover art (${newWidth}x${newHeight}) in $successCount of $($AudioFiles.Count) files" -ForegroundColor Green
            }

            return [PSCustomObject]@{
                Success = $true
                Action = "EmbeddedInTags"
                SuccessCount = $successCount
                FailedCount = $failedFiles.Count
                Size = "${newWidth}x${newHeight}"
            }
        }
    }
    catch {
        Write-Warning "Failed to process cover art: $_"
        return [PSCustomObject]@{
            Success = $false
            Error = "Processing failed: $_"
        }
    }
}