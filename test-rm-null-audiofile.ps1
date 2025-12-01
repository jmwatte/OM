# Test: rm command with tracks that have null AudioFile
# Simulates marking tracks where some have no audio file match

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest  # This is what Start-OM uses!

Write-Host "`n=== Test: rm Command with Null AudioFile ===" -ForegroundColor Cyan

# Simulate pairedTracks array with mixed null/valid AudioFiles
$pairedTracks = @(
    # Track with valid AudioFile
    [PSCustomObject]@{
        AudioFile = [PSCustomObject]@{
            FilePath = "C:\test\track1.flac"
            Duration = 150000
        }
        SpotifyTrack = [PSCustomObject]@{
            id = "track1"
            name = "Track 1"
        }
        Marked = $true
    },
    # Track with NULL AudioFile (unmatched provider track)
    [PSCustomObject]@{
        AudioFile = $null
        SpotifyTrack = [PSCustomObject]@{
            id = "track2"
            name = "Track 2 - No Audio File"
        }
        Marked = $true
    },
    # Another track with valid AudioFile
    [PSCustomObject]@{
        AudioFile = [PSCustomObject]@{
            FilePath = "C:\test\track3.flac"
            Duration = 180000
        }
        SpotifyTrack = [PSCustomObject]@{
            id = "track3"
            name = "Track 3"
        }
        Marked = $true
    }
)

Write-Host "Initial pairedTracks:"
for ($i = 0; $i -lt $pairedTracks.Count; $i++) {
    $hasAudio = if ($pairedTracks[$i].AudioFile) { "✓" } else { "✗" }
    Write-Host "  [$i] AudioFile: $hasAudio, Marked: $($pairedTracks[$i].Marked)"
}

# Simulate rm command logic - get marked tracks
$markedTracks = @($pairedTracks | Where-Object { $_.PSObject.Properties['Marked'] -and $_.Marked })
Write-Host "`nMarked tracks: $($markedTracks.Count)"

# Build provider track pool (this works fine)
$providerTrackPool = @($markedTracks | Where-Object { $_.SpotifyTrack } | ForEach-Object { $_.SpotifyTrack })
Write-Host "Provider track pool: $($providerTrackPool.Count)"

# Simulate iterating through marked tracks (should skip null AudioFiles)
Write-Host "`n--- Step 1: Iterate marked tracks (should skip nulls) ---" -ForegroundColor Yellow
foreach ($markedTrack in $markedTracks) {
    if (-not $markedTrack.AudioFile) { 
        Write-Host "  Skipped: No AudioFile" -ForegroundColor Gray
        continue 
    }
    Write-Host "  Processing: $($markedTrack.AudioFile.FilePath)" -ForegroundColor Green
}

# Simulate user selecting a match for LAST track with audio file (index 2)
# This forces loop to iterate through index 1 (null AudioFile) first
Write-Host "`n--- Step 2: User selects match for Track 3 ---" -ForegroundColor Yellow
$markedTrack = $markedTracks[2]  # Track 3 with valid AudioFile (index 2 in pairedTracks)
$selectedTrack = [PSCustomObject]@{
    id = "newtrack3"
    name = "New Track 3"
}

Write-Host "Selected track: $($selectedTrack.name)"
Write-Host "Looking for AudioFile.FilePath = $($markedTrack.AudioFile.FilePath)"

# THIS IS WHERE THE BUG OCCURS - looping through ALL pairedTracks
Write-Host "`n--- Step 3: Update pairedTracks (OLD CODE - WILL FAIL) ---" -ForegroundColor Yellow
$testFailed = $false
try {
    for ($i = 0; $i -lt $pairedTracks.Count; $i++) {
        # BUG: This line throws error when AudioFile is null
        if ($pairedTracks[$i].AudioFile.FilePath -eq $markedTrack.AudioFile.FilePath) {
            Write-Host "  Found match at index $i"
            $pairedTracks[$i].SpotifyTrack = $selectedTrack
            $pairedTracks[$i].Marked = $false
            break
        }
    }
    Write-Host "❌ UNEXPECTED: No error occurred (test may be invalid)" -ForegroundColor Red
    $testFailed = $true
}
catch {
    Write-Host "✓ Expected error caught: $($_.Exception.Message)" -ForegroundColor Green
    Write-Host "  Error at index 1 (null AudioFile)" -ForegroundColor Gray
}

# Now test FIXED version
Write-Host "`n--- Step 4: Update pairedTracks (FIXED CODE) ---" -ForegroundColor Yellow
$updateCount = 0
for ($i = 0; $i -lt $pairedTracks.Count; $i++) {
    # FIX: Check if AudioFile exists before accessing properties
    if ($pairedTracks[$i].AudioFile -and 
        $pairedTracks[$i].AudioFile.FilePath -eq $markedTrack.AudioFile.FilePath) {
        Write-Host "  Found match at index $i" -ForegroundColor Green
        $pairedTracks[$i].SpotifyTrack = $selectedTrack
        $pairedTracks[$i].Marked = $false
        $updateCount++
        break
    }
}

if ($updateCount -eq 1) {
    Write-Host "✓ Successfully updated pairedTracks without error" -ForegroundColor Green
} else {
    Write-Host "❌ Failed to update pairedTracks" -ForegroundColor Red
    $testFailed = $true
}

# Verify update
Write-Host "`n--- Step 5: Verify update ---" -ForegroundColor Yellow
if ($pairedTracks[0].SpotifyTrack.id -eq "track1" -and $pairedTracks[0].Marked) {
    Write-Host "✓ Track 0: Unchanged (still marked, original track)" -ForegroundColor Green
} else {
    Write-Host "❌ Track 0: Unexpected state" -ForegroundColor Red
    $testFailed = $true
}

if ($null -eq $pairedTracks[1].AudioFile -and $pairedTracks[1].Marked) {
    Write-Host "✓ Track 1: Still null AudioFile, still marked (untouched)" -ForegroundColor Green
} else {
    Write-Host "❌ Track 1: Unexpected state" -ForegroundColor Red
    $testFailed = $true
}

if ($pairedTracks[2].SpotifyTrack.id -eq "newtrack3" -and -not $pairedTracks[2].Marked) {
    Write-Host "✓ Track 2: Updated to newtrack3, unmarked" -ForegroundColor Green
} else {
    Write-Host "❌ Track 2: Update failed" -ForegroundColor Red
    $testFailed = $true
}

# Final result
Write-Host "`n========================================" -ForegroundColor Cyan
if (-not $testFailed) {
    Write-Host "✅ TEST PASSED: Fix handles null AudioFile correctly" -ForegroundColor Green
    exit 0
} else {
    Write-Host "❌ TEST FAILED" -ForegroundColor Red
    exit 1
}
