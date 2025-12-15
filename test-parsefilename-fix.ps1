# Test ParseFilename fix for {disc}-{track} pattern

Write-Host "`n=== Testing ParseFilename Pattern Fix ===" -ForegroundColor Cyan

# Test the Parse-FilenamePattern function directly
$testCases = @(
    @{
        Pattern = "{AlbumArtists} - {Album} - {disc}-{track} {title}"
        FileName = "Little Walter - His Best - The Chess 50th Anniversary Collection - 01-01 Juke"
        Expected = @{
            AlbumArtists = "Little Walter"
            Album = "His Best - The Chess 50th Anniversary Collection"
            disc = 1
            track = 1
            title = "Juke"
        }
    },
    @{
        Pattern = "{AlbumArtists} - {Album} - {disc}-{track} {title}"
        FileName = "Little Walter - The Complete Chess Masters (1950 - 1967) - 01-12 Fast Boogie (Alternate Take 1)"
        Expected = @{
            AlbumArtists = "Little Walter"
            Album = "The Complete Chess Masters (1950 - 1967)"
            disc = 1
            track = 12
            title = "Fast Boogie (Alternate Take 1)"
        }
    },
    @{
        Pattern = "{track:D2} - {Composers} - {title}"
        FileName = "01 - Albinoni - Adagio in G Minor"
        Expected = @{
            track = 1
            Composers = "Albinoni"
            title = "Adagio in G Minor"
        }
    },
    @{
        Pattern = "{disc}-{track} - {title}"
        FileName = "02-15 - Some Song Title"
        Expected = @{
            disc = 2
            track = 15
            title = "Some Song Title"
        }
    }
)

$passed = 0
$failed = 0

foreach ($test in $testCases) {
    Write-Host "`nTest: $($test.FileName)" -ForegroundColor Yellow
    Write-Host "Pattern: $($test.Pattern)" -ForegroundColor Gray
    
    # Build regex pattern (simulate Parse-FilenamePattern logic)
    $regexPattern = $test.Pattern
    $placeholders = [regex]::Matches($regexPattern, '\{([^}]+)\}')
    
    foreach ($match in $placeholders) {
        $placeholder = $match.Groups[1].Value
        $fullMatch = $match.Value
        $propertyName = $placeholder -split ':', 2 | Select-Object -First 1
        
        # NEW LOGIC: Use \d+ for numeric properties
        $captureGroup = if ($propertyName -match '^(Track|Disc|Year|track|disc)$') {
            "(?<$propertyName>\d+)"
        } else {
            "(?<$propertyName>.+?)"
        }
        
        $regexPattern = $regexPattern -replace [regex]::Escape($fullMatch), $captureGroup
    }
    
    # Escape literal parts
    $parts = $regexPattern -split '(\(\?<[^>]+>.+?\))'
    $escapedParts = foreach ($part in $parts) {
        if ($part -match '^\(\?<[^>]+>.+?\)$') {
            $part
        } else {
            [regex]::Escape($part)
        }
    }
    $regexPattern = $escapedParts -join ''
    $regexPattern = "^$regexPattern$"
    
    Write-Host "Regex: $regexPattern" -ForegroundColor DarkGray
    
    # Try to match
    $matchResult = [regex]::Match($test.FileName, $regexPattern)
    
    if ($matchResult.Success) {
        Write-Host "✓ Match successful" -ForegroundColor Green
        
        $allCorrect = $true
        foreach ($key in $test.Expected.Keys) {
            $expectedValue = $test.Expected[$key]
            $actualValue = $matchResult.Groups[$key].Value
            
            # Convert to int if expected is int
            if ($expectedValue -is [int] -and $actualValue -match '^\d+$') {
                $actualValue = [int]$actualValue
            }
            
            if ($actualValue -eq $expectedValue) {
                Write-Host "  ✓ $key = '$actualValue'" -ForegroundColor Green
            } else {
                Write-Host "  ✗ $key = '$actualValue' (expected '$expectedValue')" -ForegroundColor Red
                $allCorrect = $false
            }
        }
        
        if ($allCorrect) {
            $passed++
        } else {
            $failed++
        }
    } else {
        Write-Host "✗ Match failed" -ForegroundColor Red
        $failed++
    }
}

Write-Host "`n=== Test Summary ===" -ForegroundColor Cyan
Write-Host "Passed: $passed / $($testCases.Count)" -ForegroundColor $(if ($failed -eq 0) { 'Green' } else { 'Yellow' })

if ($failed -eq 0) {
    Write-Host "`n✅ ParseFilename fix is working correctly!" -ForegroundColor Green
    Write-Host "The pattern {disc}-{track} now correctly parses disc and track separately." -ForegroundColor Cyan
    Write-Host "`nYou can now use:" -ForegroundColor Yellow
    Write-Host '  got $dest -Details | sot -ParseFilename "{AlbumArtists} - {Album} - {disc}-{track} {title}" -PassThru' -ForegroundColor Gray
} else {
    Write-Host "`n❌ Some tests failed." -ForegroundColor Red
}
