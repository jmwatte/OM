function Get-IfExists {
    param($target, $path)

    if (-not $target -or -not $path) { return $null }

    $segments = $path -split '\.'
    foreach ($segment in $segments) {
        if ($target -is [hashtable]) {
            if ($target.ContainsKey($segment)) {
                $target = $target[$segment]
            } else {
                return $null
            }
        } elseif ($target -is [psobject]) {
            $prop = $target.PSObject.Properties[$segment]
            if ($prop) {
                $target = $prop.Value
            } else {
                return $null
            }
        } else {
            return $null
        }
    }
    return $target
}
