function Expand-SelectionRange {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RangeText,

        [Parameter(Mandatory = $true)]
        [ValidateRange(1, [int]::MaxValue)]
        [int]$MaxIndex
    )

    if (-not $RangeText) {
        return @()
    }

    $segments = $RangeText.Split(',')
    $indices = New-Object System.Collections.Generic.HashSet[int]

    foreach ($segmentRaw in $segments) {
        $segment = $segmentRaw.Trim()
        if (-not $segment) {
            continue
        }

        if ($segment -match '^(?<single>\d+)$') {
            $value = [int]$matches.single
            if ($value -lt 1 -or $value -gt $MaxIndex) {
                throw "Track number '$value' is outside the valid range 1-$MaxIndex."
            }
            $indices.Add($value) | Out-Null
            continue
        }

        if ($segment -match '^(?<start>\d+)(?:-|\.\.)(?<end>\d+)$') {
            $start = [int]$matches.start
            $end = [int]$matches.end
            if ($start -gt $end) {
                $temp = $start
                $start = $end
                $end = $temp
            }
            if ($start -lt 1 -or $end -gt $MaxIndex) {
                throw "Track range '$segment' is outside the valid range 1-$MaxIndex."
            }
            for ($i = $start; $i -le $end; $i++) {
                $indices.Add($i) | Out-Null
            }
            continue
        }

        throw "Unrecognized track selection segment '$segment'. Use numbers or ranges like '4-7'."
    }

    return ($indices | Sort-Object)
}
