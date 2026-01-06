function Set-PairedTracks {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][array]$PairedTracks,
        [Parameter(Mandatory=$true)][string]$RangeText,
        [Parameter(Mandatory=$false)][int]$MaxIndex
    )

    if (-not $MaxIndex) { $MaxIndex = $PairedTracks.Count }

    $trackNumbers = Expand-SelectionRange -RangeText $RangeText -MaxIndex $MaxIndex
    if ($trackNumbers -isnot [array]) { $trackNumbers = @($trackNumbers) }

    foreach ($trackNum in $trackNumbers) {
        $idx = $trackNum - 1
        if ($idx -ge 0 -and $idx -lt $PairedTracks.Count) {
            $PairedTracks[$idx] | Add-Member -NotePropertyName 'Marked' -NotePropertyValue $true -Force
        }
    }

    return $trackNumbers.Count
}