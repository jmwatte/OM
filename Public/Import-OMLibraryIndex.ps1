function Import-OMLibraryIndex {
<#
.SYNOPSIS
    Imports a music library index from a foobar2000 export file.

.DESCRIPTION
    Reads a pipe-delimited text file exported from foobar2000 containing
    Path|Artist|Title|Album|Duration and returns objects for playlist matching.
    
    To export from foobar2000:
    1. Select all in Media Library (Ctrl+A)
    2. Right-click → Utilities → Text Tools → Copy with pattern:
       %path%|%artist%|%title%|%album%|%length_seconds%
    3. Paste to a text file

.PARAMETER Path
    Path to the foobar2000 export text file.

.PARAMETER Delimiter
    Field delimiter. Default: '|'

.EXAMPLE
    $library = Import-OMLibraryIndex -Path "C:\library-export.txt"
    
.EXAMPLE
    # Quick count
    (Import-OMLibraryIndex -Path "C:\library.txt").Count

.OUTPUTS
    Array of PSCustomObject with Path, Artist, Title, Album, Duration properties.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [string]$Path,
        
        [string]$Delimiter = '|'
    )
    
    begin {
        $results = [System.Collections.Generic.List[PSCustomObject]]::new()
        $lineNum = 0
        $errorCount = 0
    }
    
    process {
        if (-not (Test-Path -LiteralPath $Path)) {
            throw "File not found: $Path"
        }
        
        Write-Host "Loading library index from $Path..." -ForegroundColor Cyan
        $startTime = Get-Date
        
        # Use StreamReader for memory efficiency with large files
        $reader = [System.IO.StreamReader]::new($Path)
        try {
            while ($null -ne ($line = $reader.ReadLine())) {
                $lineNum++
                
                if ([string]::IsNullOrWhiteSpace($line)) { continue }
                
                $parts = $line -split [regex]::Escape($Delimiter)
                
                if ($parts.Count -lt 4) {
                    $errorCount++
                    Write-Verbose "Line $lineNum`: Parse error - not enough fields"
                    continue
                }
                
                # Handle missing album (shown as ?)
                $album = if ($parts[3] -eq '?' -or [string]::IsNullOrWhiteSpace($parts[3])) { 
                    $null 
                } else { 
                    $parts[3] 
                }
                
                # Parse duration (might be missing)
                $duration = 0
                if ($parts.Count -ge 5 -and $parts[4] -match '^\d+$') {
                    $duration = [int]$parts[4]
                }
                
                $results.Add([PSCustomObject]@{
                    Path     = $parts[0]
                    Artist   = $parts[1]
                    Title    = $parts[2]
                    Album    = $album
                    Duration = $duration
                })
                
                # Progress every 10000 lines
                if ($lineNum % 10000 -eq 0) {
                    Write-Host "  Loaded $lineNum tracks..." -ForegroundColor DarkGray
                }
            }
        }
        finally {
            $reader.Dispose()
        }
        
        $elapsed = (Get-Date) - $startTime
        Write-Host "Loaded $($results.Count) tracks in $([math]::Round($elapsed.TotalSeconds, 1))s" -ForegroundColor Green
        if ($errorCount -gt 0) {
            Write-Warning "$errorCount lines could not be parsed"
        }
    }
    
    end {
        return $results.ToArray()
    }
}
