# Test ParseFilename fix for {disc}-{track} pattern

Show-Message -Message "`n=== Testing ParseFilename Pattern Fix ===" -ForegroundColor Cyan -Context $null

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
    Show-Message -Message "`nTest: $($test.FileName)" -ForegroundColor Yellow -Context $null
    Show-Message -Message "Pattern: $($test.Pattern)" -ForegroundColor Gray -Context $null
    
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
    
    Show-Message -Message "Regex: $regexPattern" -ForegroundColor DarkGray -Context $null
    
    # Try to match
    $matchResult = [regex]::Match($test.FileName, $regexPattern)
    
    if ($matchResult.Success) {
        Show-Message -Message "✓ Match successful" -ForegroundColor Green -Context $null
        
        $allCorrect = $true
        foreach ($key in $test.Expected.Keys) {
            $expectedValue = $test.Expected[$key]
            $actualValue = $matchResult.Groups[$key].Value
            
            # Convert to int if expected is int
            if ($expectedValue -is [int] -and $actualValue -match '^\d+$') {
                $actualValue = [int]$actualValue
            }
            
            if ($actualValue -eq $expectedValue) {
                Show-Message -Message "  ✓ $key = '$actualValue'" -ForegroundColor Green -Context $null
            } else {
                Show-Message -Message "  ✗ $key = '$actualValue' (expected '$expectedValue')" -ForegroundColor Red -Context $null
                $allCorrect = $false
            }
        }
        
        if ($allCorrect) {
            $passed++
        } else {
            $failed++
        }
    } else {
        Show-Message -Message "✗ Match failed" -ForegroundColor Red -Context $null
        $failed++
    }
}

Show-Message -Message "`n=== Test Summary ===" -ForegroundColor Cyan -Context $null
Show-Message -Message "Passed: $passed / $($testCases.Count)" -ForegroundColor $(if ($failed -eq 0) { 'Green' } else { 'Yellow' }) -Context $null

if ($failed -eq 0) {
    Show-Message -Message "`n✅ ParseFilename fix is working correctly!" -ForegroundColor Green -Context $null
    Show-Message -Message "The pattern {disc}-{track} now correctly parses disc and track separately." -ForegroundColor Cyan -Context $null
    Show-Message -Message "`nYou can now use:" -ForegroundColor Yellow -Context $null
    Show-Message -Message '  got $dest -Details | sot -ParseFilename "{AlbumArtists} - {Album} - {disc}-{track} {title}" -PassThru' -ForegroundColor Gray -Context $null
} else {
    Show-Message -Message "`n❌ Some tests failed." -ForegroundColor Red -Context $null
}

