function Get-StringSimilarity-Jaccard {
    <#
    .SYNOPSIS
        Jaccard similarity between two strings (word/token overlap).
    .DESCRIPTION
        Tokenizes strings by extracting Unicode word-like tokens, lowercases them,
        removes punctuation/noise, always returns a [double] and is defensive against
        PowerShell single-item unwrapping.
    .PARAMETER String1
    .PARAMETER String2
    #>
    param (
        [Parameter(Mandatory = $false)]
        [object]$String1,
        [Parameter(Mandatory = $false)]
        [object]$String2
    )

    # Coerce nulls and objects to strings
    $s1 = if ($null -eq $String1) { '' } else { [string]$String1 }
    $s2 = if ($null -eq $String2) { '' } else { [string]$String2 }

    # Helper: tokenize using Unicode-aware regex; returns an ARRAY even for 0/1 tokens
    function _tokenize([string]$in) {
        if ([string]::IsNullOrWhiteSpace($in)) { return @() }

        $in = $in.ToLowerInvariant()

        # Extract tokens: words, numbers, hyphenated words (Unicode letters & numbers)
        $matchesb = [regex]::Matches($in, '\p{L}[\p{L}\p{N}\-]*')

        # Build an explicit array to avoid single-item unwrapping
        $tokens = @()
        foreach ($m in $matchesb) {
            $t = $m.Value.Trim('-')
            if ($t -and -not ($tokens -contains $t)) {
                $tokens += $t
            }
        }

        return $tokens
    }

    # Always coerce tokenizer results into arrays
    $words1 = @($null) ; $words2 = @($null)
    $words1 = @(_tokenize $s1)
    $words2 = @(_tokenize $s2)

    # If both empty -> identical (1.0), if one empty -> 0.0
    if ($words1.Count -eq 0 -and $words2.Count -eq 0) { return 1.0 }
    if ($words1.Count -eq 0 -or $words2.Count -eq 0) { return 0.0 }

    # Compute intersection using a hashset for stability and speed
    $set1 = [System.Collections.Generic.HashSet[string]]::new()
    foreach ($w in $words1) { $set1.Add($w) | Out-Null }

    $set2 = [System.Collections.Generic.HashSet[string]]::new()
    foreach ($w in $words2) { $set2.Add($w) | Out-Null }

    $intersection = 0
    foreach ($w in $set2) {
        if ($set1.Contains($w)) { $intersection++ }
    }

    $union = $set1.Count + $set2.Count - $intersection
    if ($union -eq 0) { return 0.0 }

    return [double]$intersection / $union
}