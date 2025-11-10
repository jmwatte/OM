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
                        # Unwrap PSObject if needed before indexing
                        $actualTarget = $target
                        if ($target -is [System.Management.Automation.PSObject] -and $target.PSObject.BaseObject) {
                            $actualTarget = $target.PSObject.BaseObject
                        }
                        if ($actualTarget -is [System.Collections.IList] -and $idx -ge 0 -and $idx -lt $actualTarget.Count) {
                            $target = $actualTarget[$idx]
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
