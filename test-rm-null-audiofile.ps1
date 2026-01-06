# Test: rm command with tracks that have null AudioFile
# Simulates marking tracks where some have no audio file match

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest  # This is what Start-OM uses!

# Ensure Show-Message helper available when running standalone
if (-not (Get-Command -Name Show-Message -ErrorAction SilentlyContinue)) {
    $p = Join-Path $PSScriptRoot 'Private\Utils\Show-Message.ps1'
    if (Test-Path $p) { . $p }
}

Show-Message -Message "`n=== Test: rm Command with Null AudioFile ===" -ForegroundColor Cyan -Context $null

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

Show-Message -Message "Initial pairedTracks:" -Context $null
for ($i = 0; $i -lt $pairedTracks.Count; $i++) {
    $hasAudio = if ($pairedTracks[$i].AudioFile) { "✓" } else { "✗" }
    Show-Message -Message "  [$i] AudioFile: $hasAudio, Marked: $($pairedTracks[$i].Marked)" -Context $null
}

# Simulate rm command logic - get marked tracks
$markedTracks = @($pairedTracks | Where-Object { $_.PSObject.Properties['Marked'] -and $_.Marked })
Show-Message -Message "`nMarked tracks: $($markedTracks.Count)" -Context $null

# Build provider track pool (this works fine)
$providerTrackPool = @($markedTracks | Where-Object { $_.SpotifyTrack } | ForEach-Object { $_.SpotifyTrack })
Show-Message -Message "Provider track pool: $($providerTrackPool.Count)" -Context $null

# Simulate iterating through marked tracks (should skip null AudioFiles)
Show-Message -Message "`n--- Step 1: Iterate marked tracks (should skip nulls) ---" -ForegroundColor Yellow -Context $null
foreach ($markedTrack in $markedTracks) {
    if (-not $markedTrack.AudioFile) { 
        Show-Message -Message "  Skipped: No AudioFile" -ForegroundColor Gray -Context $null
        continue 
    }
    Show-Message -Message "  Processing: $($markedTrack.AudioFile.FilePath)" -ForegroundColor Green -Context $null
}

# Simulate user selecting a match for LAST track with audio file (index 2)
# This forces loop to iterate through index 1 (null AudioFile) first
Show-Message -Message "`n--- Step 2: User selects match for Track 3 ---" -ForegroundColor Yellow -Context $null
$markedTrack = $markedTracks[2]  # Track 3 with valid AudioFile (index 2 in pairedTracks)
$selectedTrack = [PSCustomObject]@{
    id = "newtrack3"
    name = "New Track 3"
}

Show-Message -Message "Selected track: $($selectedTrack.name)" -Context $null
Show-Message -Message "Looking for AudioFile.FilePath = $($markedTrack.AudioFile.FilePath)" -Context $null

# THIS IS WHERE THE BUG OCCURS - looping through ALL pairedTracks
Show-Message -Message "`n--- Step 3: Update pairedTracks (OLD CODE - WILL FAIL) ---" -ForegroundColor Yellow -Context $null
$testFailed = $false
try {
    for ($i = 0; $i -lt $pairedTracks.Count; $i++) {
        # BUG: This line throws error when AudioFile is null
        if ($pairedTracks[$i].AudioFile.FilePath -eq $markedTrack.AudioFile.FilePath) {
            Show-Message -Message "  Found match at index $i" -Context $null
            $pairedTracks[$i].SpotifyTrack = $selectedTrack
            $pairedTracks[$i].Marked = $false
            break
        }
    }
    Show-Message -Message "❌ UNEXPECTED: No error occurred (test may be invalid)" -ForegroundColor Red -Context $null
    $testFailed = $true
}
catch {
    Show-Message -Message "✓ Expected error caught: $($_.Exception.Message)" -ForegroundColor Green -Context $null
    Show-Message -Message "  Error at index 1 (null AudioFile)" -ForegroundColor Gray -Context $null
} 

# Now test FIXED version
Show-Message -Message "`n--- Step 4: Update pairedTracks (FIXED CODE) ---" -ForegroundColor Yellow -Context $null
$updateCount = 0
for ($i = 0; $i -lt $pairedTracks.Count; $i++) {
    # FIX: Check if AudioFile exists before accessing properties
    if ($pairedTracks[$i].AudioFile -and 
        $pairedTracks[$i].AudioFile.FilePath -eq $markedTrack.AudioFile.FilePath) {
        Show-Message -Message "  Found match at index $i" -ForegroundColor Green -Context $null
        $pairedTracks[$i].SpotifyTrack = $selectedTrack
        $pairedTracks[$i].Marked = $false
        $updateCount++
        break
    }
} 

if ($updateCount -eq 1) {
    Show-Message -Message "✓ Successfully updated pairedTracks without error" -ForegroundColor Green -Context $null
} else {
    Show-Message -Message "❌ Failed to update pairedTracks" -ForegroundColor Red -Context $null
    $testFailed = $true
}

# Verify update
Show-Message -Message "`n--- Step 5: Verify update ---" -ForegroundColor Yellow -Context $null
if ($pairedTracks[0].SpotifyTrack.id -eq "track1" -and $pairedTracks[0].Marked) {
    Show-Message -Message "✓ Track 0: Unchanged (still marked, original track)" -ForegroundColor Green -Context $null
} else {
    Show-Message -Message "❌ Track 0: Unexpected state" -ForegroundColor Red -Context $null
    $testFailed = $true
}

if ($null -eq $pairedTracks[1].AudioFile -and $pairedTracks[1].Marked) {
    Show-Message -Message "✓ Track 1: Still null AudioFile, still marked (untouched)" -ForegroundColor Green -Context $null
} else {
    Show-Message -Message "❌ Track 1: Unexpected state" -ForegroundColor Red -Context $null
    $testFailed = $true
}

if ($pairedTracks[2].SpotifyTrack.id -eq "newtrack3" -and -not $pairedTracks[2].Marked) {
    Show-Message -Message "✓ Track 2: Updated to newtrack3, unmarked" -ForegroundColor Green -Context $null
} else {
    Show-Message -Message "❌ Track 2: Update failed" -ForegroundColor Red -Context $null
    $testFailed = $true
} 

# Final result
Show-Message -Message "`n========================================" -ForegroundColor Cyan -Context $null
if (-not $testFailed) {
    Show-Message -Message "✅ TEST PASSED: Fix handles null AudioFile correctly" -ForegroundColor Green -Context $null
    exit 0
} else {
    Show-Message -Message "❌ TEST FAILED" -ForegroundColor Red -Context $null
    exit 1
}

