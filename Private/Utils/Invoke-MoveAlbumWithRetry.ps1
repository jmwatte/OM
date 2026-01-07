function Invoke-MoveAlbumWithRetry {
    param(
        [hashtable]$mvArgs,
        [switch]$UseWhatIf,
        [ScriptBlock]$OnRetry,
        [switch]$AutoSkip,
        [int]$MaxRetries = 5
    )

    $moveSucceeded = $false
    $attempts = 0
    do {
        try {
            $moveResult = Move-AlbumFolder @mvArgs -WhatIf:$UseWhatIf
            $moveSucceeded = $true
        }
        catch {
            $attempts++
            Write-Verbose "Invoke-MoveAlbumWithRetry: Move-AlbumFolder failed (attempt $attempts): $($_.Exception.Message)"

            if ($AutoSkip) {
                Write-Verbose "AutoSkip enabled: skipping move"
                return $null
            }

            if ($OnRetry) {
                try {
                    $choice = & $OnRetry $_
                }
                catch {
                    Write-Verbose "OnRetry callback failed: $($_.Exception.Message)"
                    return $null
                }

                if ($choice -eq 's' -or $choice -eq 'S' -or $choice -eq 'skip') {
                    Write-Verbose "OnRetry requested skip"
                    return $null
                }

                # otherwise assume caller chose to retry; loop continues
            }
            else {
                # No callback provided; default to skipping to avoid hanging in tests
                Write-Verbose "No OnRetry callback provided; skipping"
                return $null
            }

            if ($attempts -ge $MaxRetries) {
                Write-Verbose "Maximum retries ($MaxRetries) reached; giving up"
                return $null
            }
        }
    } while (-not $moveSucceeded)

    return $moveResult
}
