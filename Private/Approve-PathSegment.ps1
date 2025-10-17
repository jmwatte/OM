function Approve-PathSegment {
    <#
    .SYNOPSIS
        Make a safe file/folder name from an arbitrary string.

    .DESCRIPTION
        Replaces invalid filename/path characters, optionally transliterates Unicode
        (removes diacritics), collapses repeated replacement characters, trims trailing
        dots/spaces, avoids Windows reserved names, and truncates to a safe max length.

    .PARAMETER Segment
        The input name (album, artist, etc).

    .PARAMETER Replacement
        The single-character replacement to use for invalid characters (default: '_').

    .PARAMETER CollapseRepeating
        Collapse multiple consecutive replacement characters into a single one.

    .PARAMETER Transliterate
        Remove diacritics (e.g., "Å" => "A").

    .PARAMETER MaxLength
        Maximum length for the resulting segment (default 240; leave margin under MAX_PATH).

    .OUTPUTS
        String - sanitized segment.

    .EXAMPLE
        Sanitize-PathSegment -Segment "Tchaikovsky: Symphonies/No. 6" -Replacement '_'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$Segment,
        [string]$Replacement = '_',
        [switch]$CollapseRepeating,
        [switch]$Transliterate,
        [int]$MaxLength = 240
    )

    begin {
        if ($null -eq $Segment) { return '' }
        if ([string]::IsNullOrWhiteSpace($Segment)) { return 'unnamed' }
        if ($Replacement -eq '') { $Replacement = '_' }
        $Replacement = [string]$Replacement
        if ($Replacement.Length -ne 1) { $Replacement = $Replacement.Substring(0,1) }
    }

    process {
        $s = $Segment

        # Optional transliteration: remove diacritics (normalize + strip NonSpacingMark)
        if ($Transliterate) {
            try {
                $normalized = $s.Normalize([System.Text.NormalizationForm]::FormD)
                $sb = New-Object System.Text.StringBuilder
                foreach ($c in $normalized.ToCharArray()) {
                    $cat = [Globalization.CharUnicodeInfo]::GetUnicodeCategory($c)
                    if ($cat -ne [Globalization.UnicodeCategory]::NonSpacingMark) {
                        [void]$sb.Append($c)
                    }
                }
                $s = $sb.ToString().Normalize([System.Text.NormalizationForm]::FormC)
            } catch {
                # if transliteration fails for any reason, continue with original string
            }
        }

        # Remove control characters
        $s = $s -replace '[\p{C}]', ''

        # Build regex of invalid characters (use GetInvalidFileNameChars)
        $invalidChars = [System.IO.Path]::GetInvalidFileNameChars() + [System.IO.Path]::GetInvalidPathChars()
        $invalidChars = $invalidChars | Select-Object -Unique
        # Escape each for regex char class
        $escaped = ($invalidChars | ForEach-Object { [Regex]::Escape($_) }) -join ''
        if ($escaped -ne '') {
            $pattern = '[' + $escaped + ']'
            $s = $s -replace $pattern, $Replacement
        }

        # Also remove common troublesome characters/spaces sequences
        # Replace forward/back slashes (if any remain) and colon just in case
        $s = $s -replace '[:\\/]', $Replacement

        # Remove trailing spaces and dots (Windows forbids trailing space/dot)
        $s = $s.TrimEnd('.', ' ')

        # Collapse multiple replacement characters if requested
        if ($CollapseRepeating) {
            $escRep = [Regex]::Escape($Replacement)
            $s = $s -replace "($escRep){2,}", $Replacement
        }

        # Collapse multiple whitespace to single space, then replace spaces with Replacement if desired
        $s = $s -replace '\s{2,}', ' '
        $s = $s.Trim()

        # Truncate to MaxLength, keeping start and end (prefer start)
        if ($MaxLength -gt 0 -and $s.Length -gt $MaxLength) {
            $s = $s.Substring(0, $MaxLength)
        }

        # Avoid Windows reserved file names (CON, PRN, AUX, NUL, COM1..9, LPT1..9)
        $reserved = @('CON','PRN','AUX','NUL') + (1..9 | ForEach-Object { "COM$_" }) + (1..9 | ForEach-Object { "LPT$_" })
        if ($reserved -contains ($s.ToUpper())) {
            $s = '_' + $s
        }

        # If resulting string empty, fallback to 'unnamed'
        if ([string]::IsNullOrWhiteSpace($s)) { $s = 'unnamed' }

        return $s
    }
}

function Sanitize-Path {
    <#
    .SYNOPSIS
        Sanitize each segment of a filesystem path.

    .DESCRIPTION
        Splits a path into segments, sanitizes each with Sanitize-PathSegment, and rejoins.
        Use when you build a new path from external input (artist/album names).
    .PARAMETER Path
        The path to sanitize (can be partial path segments too).
    .PARAMETER Replacement
        Replacement character forwarded to Sanitize-PathSegment.
    .PARAMETER CollapseRepeating
    .PARAMETER Transliterate
    .PARAMETER MaxSegmentLength
    .EXAMPLE
        Sanitize-Path -Path "Tchaikovsky: Symphonies\No. 6" -Transliterate -CollapseRepeating
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$Path,
        [string]$Replacement = '_',
        [switch]$CollapseRepeating,
        [switch]$Transliterate,
        [int]$MaxSegmentLength = 240
    )

    begin {
        if ($null -eq $Path) { return '' }
    }

    process {
        # Normalize separators to single '\'
        $normalized = $Path -replace '[\\/]+', '\'

        # If path is rooted, preserve drive or root prefix (e.g., "C:\")
        $prefix = ''
        if ($normalized -match '^\w:\\') {
            $prefix = $matches[0]
            $tail = $normalized.Substring($prefix.Length)
            $segments = $tail -split '\\'
        } else {
            $segments = $normalized -split '[\\/]'
        }

        $sanitizedSegments = @()
        foreach ($seg in $segments) {
            if ($seg -eq '') { continue }
            $san = Sanitize-PathSegment -Segment $seg -Replacement $Replacement -CollapseRepeating:$CollapseRepeating -Transliterate:$Transliterate -MaxLength $MaxSegmentLength
            $sanitizedSegments += $san
        }

        if ($prefix) {
            return ($prefix + ( ($sanitizedSegments -join '\') ))
        } else {
            return ($sanitizedSegments -join '\')
        }
    }
}