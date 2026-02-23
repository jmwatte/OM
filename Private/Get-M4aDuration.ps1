function Get-M4aDuration {
    <#
    .SYNOPSIS
        Calculate duration for M4A/MP4 files by parsing the container atoms directly.

    .DESCRIPTION
        TagLib-Sharp sometimes fails to read MP4/M4A properties correctly, returning
        a zero duration. This function parses the ISO Base Media File Format (ISO 14496-12)
        box/atom structure. It handles both standard MP4 (duration in mvhd/mdhd) and
        fragmented MP4 (duration computed from moof/traf/tfhd/trun fragments).

    .PARAMETER FilePath
        Path to the M4A/MP4 file.

    .OUTPUTS
        Duration in milliseconds, or 0 if unable to calculate.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$FilePath
    )

    try {
        $stream = [System.IO.File]::OpenRead($FilePath)
        $reader = [System.IO.BinaryReader]::new($stream)
        $fileLength = $stream.Length

        # Helper: read a big-endian UInt32
        $readUInt32BE = {
            $b = $reader.ReadBytes(4)
            if ($b.Count -lt 4) { return $null }
            [uint32](([uint32]$b[0] -shl 24) -bor ([uint32]$b[1] -shl 16) -bor ([uint32]$b[2] -shl 8) -bor [uint32]$b[3])
        }

        # Helper: read a big-endian UInt64
        $readUInt64BE = {
            $b = $reader.ReadBytes(8)
            if ($b.Count -lt 8) { return $null }
            [uint64](
                ([uint64]$b[0] -shl 56) -bor ([uint64]$b[1] -shl 48) -bor
                ([uint64]$b[2] -shl 40) -bor ([uint64]$b[3] -shl 32) -bor
                ([uint64]$b[4] -shl 24) -bor ([uint64]$b[5] -shl 16) -bor
                ([uint64]$b[6] -shl 8)  -bor [uint64]$b[7]
            )
        }

        # Helper: read atom header, returns (type, payloadStart, atomEnd) or $null
        $readAtomHeader = {
            if ($stream.Position -ge ($fileLength - 8)) { return $null }
            $aStart = $stream.Position
            $aSize = & $readUInt32BE
            if ($null -eq $aSize) { return $null }
            $aTypeBytes = $reader.ReadBytes(4)
            if ($aTypeBytes.Count -lt 4) { return $null }
            $aType = [System.Text.Encoding]::ASCII.GetString($aTypeBytes)
            if ($aSize -eq 1) {
                $aSize = & $readUInt64BE
                if ($null -eq $aSize) { return $null }
            }
            elseif ($aSize -eq 0) { $aSize = $fileLength - $aStart }
            if ($aSize -lt 8) { return $null }
            [PSCustomObject]@{ Type = $aType; PayloadStart = $stream.Position; End = ($aStart + $aSize) }
        }

        # Helper: read timescale+duration from a version-tagged header (mvhd or mdhd)
        $readTimeDuration = {
            $ver = $reader.ReadByte()
            $null = $reader.ReadBytes(3) # flags
            if ($ver -eq 0) {
                $null = & $readUInt32BE  # creation_time
                $null = & $readUInt32BE  # modification_time
                $ts = & $readUInt32BE    # timescale
                $dur = & $readUInt32BE   # duration
            }
            elseif ($ver -eq 1) {
                $null = & $readUInt64BE  # creation_time
                $null = & $readUInt64BE  # modification_time
                $ts = & $readUInt32BE    # timescale
                $dur = & $readUInt64BE   # duration
            }
            else { return $null }
            [PSCustomObject]@{ TimeScale = $ts; Duration = $dur }
        }

        # ---- Phase 1: Scan top-level atoms, collect moov position and moof positions ----
        $moovAtom = $null
        $moofPositions = [System.Collections.Generic.List[int64[]]]::new()
        $timeScale = [uint32]0

        $stream.Position = 0
        while ($stream.Position -lt ($fileLength - 8)) {
            $atom = & $readAtomHeader
            if ($null -eq $atom) { break }

            if ($atom.Type -eq 'moov') {
                $moovAtom = $atom
            }
            elseif ($atom.Type -eq 'moof') {
                $moofPositions.Add(@([int64]$atom.PayloadStart, [int64]$atom.End))
            }

            if ($atom.End -le $stream.Position) { break }
            $stream.Position = $atom.End
        }

        # ---- Phase 2: Try moov/mvhd and moov/trak/mdia/mdhd for standard MP4 ----
        if ($moovAtom) {
            $moovStart = $moovAtom.PayloadStart
            $moovEnd = $moovAtom.End
            Write-Verbose "Found moov at offset $moovStart (end $moovEnd)"

            # Scan moov children
            $stream.Position = $moovStart
            while ($stream.Position -lt ($moovEnd - 8)) {
                $child = & $readAtomHeader
                if ($null -eq $child) { break }

                if ($child.Type -eq 'mvhd') {
                    $info = & $readTimeDuration
                    if ($info -and $info.TimeScale -gt 0) {
                        $timeScale = $info.TimeScale
                        if ($info.Duration -gt 0) {
                            $durationMs = [int64](([double]$info.Duration / [double]$info.TimeScale) * 1000.0)
                            Write-Verbose "mvhd: timeScale=$($info.TimeScale), duration=$($info.Duration) -> $durationMs ms"
                            return $durationMs
                        }
                        Write-Verbose "mvhd: timeScale=$($info.TimeScale), duration=0 (fragmented?)"
                    }
                }
                elseif ($child.Type -eq 'trak') {
                    # Search trak/mdia/mdhd
                    $stream.Position = $child.PayloadStart
                    while ($stream.Position -lt ($child.End - 8)) {
                        $tChild = & $readAtomHeader
                        if ($null -eq $tChild) { break }
                        if ($tChild.Type -eq 'mdia') {
                            $stream.Position = $tChild.PayloadStart
                            while ($stream.Position -lt ($tChild.End - 8)) {
                                $mChild = & $readAtomHeader
                                if ($null -eq $mChild) { break }
                                if ($mChild.Type -eq 'mdhd') {
                                    $info = & $readTimeDuration
                                    if ($info -and $info.TimeScale -gt 0) {
                                        if ($timeScale -eq 0) { $timeScale = $info.TimeScale }
                                        if ($info.Duration -gt 0) {
                                            $durationMs = [int64](([double]$info.Duration / [double]$info.TimeScale) * 1000.0)
                                            Write-Verbose "mdhd: timeScale=$($info.TimeScale), duration=$($info.Duration) -> $durationMs ms"
                                            return $durationMs
                                        }
                                        Write-Verbose "mdhd: timeScale=$($info.TimeScale), duration=0"
                                    }
                                }
                                if ($mChild.End -le $stream.Position) { break }
                                $stream.Position = $mChild.End
                            }
                        }
                        if ($tChild.End -le $stream.Position) { break }
                        $stream.Position = $tChild.End
                    }
                }

                if ($child.End -le $stream.Position) { break }
                $stream.Position = $child.End
            }
        }

        # ---- Phase 3: Fragmented MP4 — sum samples from moof/traf/trun ----
        if ($moofPositions.Count -eq 0) {
            Write-Verbose "No moov duration and no moof fragments found"
            return 0
        }

        Write-Verbose "Fragmented MP4 detected: $($moofPositions.Count) moof atoms, scanning for duration..."

        # We need: default_sample_duration from tfhd, sample counts from trun
        $defaultSampleDuration = [uint32]0
        $totalSampleCount = [int64]0

        foreach ($moofPos in $moofPositions) {
            $moofPayload = $moofPos[0]
            $moofEnd = $moofPos[1]

            $stream.Position = $moofPayload
            while ($stream.Position -lt ($moofEnd - 8)) {
                $child = & $readAtomHeader
                if ($null -eq $child) { break }

                if ($child.Type -eq 'traf') {
                    $stream.Position = $child.PayloadStart
                    while ($stream.Position -lt ($child.End - 8)) {
                        $tChild = & $readAtomHeader
                        if ($null -eq $tChild) { break }

                        if ($tChild.Type -eq 'tfhd' -and $defaultSampleDuration -eq 0) {
                            # Parse tfhd to get default_sample_duration
                            $null = $reader.ReadByte()  # version
                            $fb = $reader.ReadBytes(3)
                            $flags = ([uint32]$fb[0] -shl 16) -bor ([uint32]$fb[1] -shl 8) -bor [uint32]$fb[2]
                            $null = & $readUInt32BE  # track_ID
                            if ($flags -band 0x01) {
                                $null = & $readUInt32BE  # base_data_offset lo
                                $null = & $readUInt32BE  # base_data_offset hi
                            }
                            if ($flags -band 0x02) { $null = & $readUInt32BE }  # sample_description_index
                            if ($flags -band 0x08) {
                                $defaultSampleDuration = & $readUInt32BE
                                Write-Verbose "tfhd: default_sample_duration=$defaultSampleDuration"
                            }
                        }
                        elseif ($tChild.Type -eq 'trun') {
                            # Parse trun to get sample count (and per-sample durations if present)
                            $null = $reader.ReadByte()  # version
                            $fb = $reader.ReadBytes(3)
                            $flags = ([uint32]$fb[0] -shl 16) -bor ([uint32]$fb[1] -shl 8) -bor [uint32]$fb[2]
                            $sampleCount = & $readUInt32BE
                            $totalSampleCount += $sampleCount

                            # Check if per-sample durations are present (flag 0x100)
                            # If so, sum them instead of using default
                            # (We skip this complexity for now - default_sample_duration is sufficient)
                        }

                        if ($tChild.End -le $stream.Position) { break }
                        $stream.Position = $tChild.End
                    }
                }

                if ($child.End -le $stream.Position) { break }
                $stream.Position = $child.End
            }
        }

        if ($defaultSampleDuration -gt 0 -and $totalSampleCount -gt 0 -and $timeScale -gt 0) {
            $totalDurationUnits = [int64]$totalSampleCount * [int64]$defaultSampleDuration
            $durationMs = [int64](([double]$totalDurationUnits / [double]$timeScale) * 1000.0)
            Write-Verbose "Fragmented: $totalSampleCount samples x $defaultSampleDuration = $totalDurationUnits units / $timeScale Hz -> $durationMs ms ($([math]::Round($durationMs / 1000.0, 1)) sec)"
            return $durationMs
        }

        Write-Verbose "Could not determine duration (defaultDur=$defaultSampleDuration, samples=$totalSampleCount, timeScale=$timeScale)"
        return 0
    }
    catch {
        Write-Verbose "Error reading M4A file: $($_.Exception.Message)"
        return 0
    }
    finally {
        if ($reader) { $reader.Dispose() }
        if ($stream) { $stream.Dispose() }
    }
}
