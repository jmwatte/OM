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
        }
        elseif ($target -is [psobject]) {
            $prop = $target.PSObject.Properties[$segment]
            if ($prop) { $target = $prop.Value } else { return $null }
        }
        else {
            # Support classic .NET objects with public properties
            try {
                $propInfo = $target.GetType().GetProperty($segment)
                if ($propInfo) { $target = $propInfo.GetValue($target, $null) }
                else {
                    # Support indexed numeric access for arrays/lists: segment '0' => target[0]
                    if ($segment -match '^\d+$') {
                        $idx = [int]$segment
                        if ($target -is [System.Collections.IList] -and $idx -ge 0 -and $idx -lt $target.Count) {
                            $target = $target[$idx]
                        }
                        else { return $null }
                    }
                    else { return $null }
                }
            }
            catch {
                return $null
            }
        }
    }
    return $target
}
