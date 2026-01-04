function Get-StringSimilarity {
    param(
        $String1,
        $String2
    )
    try {
        # Handle arrays first (before null checks)
        if ($String1 -is [array]) { $String1 = $String1[0] }
        if ($String2 -is [array]) { $String2 = $String2[0] }
        
        # Now check for null/empty
        if (-not $String1 -or -not $String2) { return 0.0 }
        
        # Force to string and normalize
        $s1 = [string]$String1
        $s2 = [string]$String2
        
        # Normalize: remove punctuation that gets replaced in file paths
        # Approve-PathSegment replaces : \ / with _ for Windows compatibility
        # So "TRON: Legacy" matches "TRON_ Legacy"
        $s1 = $s1.ToLower() -replace '[:\\/\-_]', '' -replace '\s+', ' '
        $s2 = $s2.ToLower() -replace '[:\\/\-_]', '' -replace '\s+', ' '
        $s1 = $s1.Trim()
        $s2 = $s2.Trim()
        
        if ($s1 -eq $s2) { return 1.0 }
        
        [int]$len1 = $s1.Length
        [int]$len2 = $s2.Length
        [int]$maxLen = [Math]::Max($len1, $len2)
        
        if ($maxLen -eq 0) { return 1.0 }
        
        # Use Levenshtein distance - create array differently
        $matrix = [int[,]]::new($len1 + 1, $len2 + 1)
        
        for ($i = 0; $i -le $len1; $i++) { $matrix[$i, 0] = $i }
        for ($j = 0; $j -le $len2; $j++) { $matrix[0, $j] = $j }
        
        for ($i = 1; $i -le $len1; $i++) {
            for ($j = 1; $j -le $len2; $j++) {
                [int]$cost = if ($s1[$i - 1] -eq $s2[$j - 1]) { 0 } else { 1 }
                
                # PowerShell multidimensional arrays can return arrays - use GetValue
                [int]$deletion = [int]$matrix.GetValue(($i - 1), $j)
                [int]$insertion = [int]$matrix.GetValue($i, ($j - 1))
                [int]$substitution = [int]$matrix.GetValue(($i - 1), ($j - 1))
                
                [int]$minVal = [Math]::Min([Math]::Min(($deletion + 1), ($insertion + 1)), ($substitution + $cost))
                $matrix.SetValue($minVal, $i, $j)
            }
        }
        
        # Extract final distance
        [int]$distance = [int]$matrix.GetValue($len1, $len2)
        [double]$result = 1.0 - ([double]$distance / [double]$maxLen)
        return $result
    }
    catch {
        Write-Warning "Get-StringSimilarity error: $_ | String1 type: $($String1.GetType().Name), String2 type: $($String2.GetType().Name)"
        return 0.0
    }
}
