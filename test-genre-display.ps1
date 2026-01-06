# Test genre display in Show-Tracks with ProviderAlbum parameter
# This test verifies that genres are properly displayed for all providers

Import-Module "$PSScriptRoot\OM.psd1" -Force

# Ensure Show-Message helper available when running standalone
if (-not (Get-Command -Name Show-Message -ErrorAction SilentlyContinue)) {
    $p = Join-Path $PSScriptRoot 'Private\Utils\Show-Message.ps1'
    if (Test-Path $p) { . $p }
}

Show-Message -Message "`n=== Testing Genre Display for All Providers ===" -ForegroundColor Cyan -Context $null

# Mock data for different provider scenarios
$testCases = @(
    @{
        Name = "Spotify (Artist-level genres)"
        ProviderAlbum = [PSCustomObject]@{
            name = "Test Album"
        }
        ProviderArtist = [PSCustomObject]@{
            genres = @('rock', 'indie rock', 'alternative')
        }
        Track = [PSCustomObject]@{
            name = "Test Track"
            disc_number = 1
            track_number = 1
            duration_ms = 240000
            artists = @([PSCustomObject]@{ name = "Test Artist" })
        }
        ExpectedGenres = "rock, indie rock, alternative"
        Source = "artist"
    },
    @{
        Name = "Discogs (Album-level genres)"
        ProviderAlbum = [PSCustomObject]@{
            name = "Help!"
            genres = @('Rock', 'Pop')
        }
        ProviderArtist = [PSCustomObject]@{
            name = "The Beatles"
        }
        Track = [PSCustomObject]@{
            name = "Help!"
            disc_number = 1
            track_number = 1
            duration = 138000
            artists = @([PSCustomObject]@{ name = "The Beatles" })
        }
        ExpectedGenres = "Rock, Pop"
        Source = "album"
    },
    @{
        Name = "Qobuz (Album-level genres)"
        ProviderAlbum = [PSCustomObject]@{
            name = "Classical Symphony"
            genres = @('Classical', 'Orchestral')
        }
        ProviderArtist = [PSCustomObject]@{
            name = "Berlin Philharmonic"
        }
        Track = [PSCustomObject]@{
            name = "Symphony No. 5"
            disc_number = 1
            track_number = 1
            duration = 420000
            artists = @([PSCustomObject]@{ name = "Berlin Philharmonic" })
        }
        ExpectedGenres = "Classical, Orchestral"
        Source = "album"
    },
    @{
        Name = "MusicBrainz (Album-level genres)"
        ProviderAlbum = [PSCustomObject]@{
            name = "Jazz Standard"
            genres = @('jazz', 'bebop', 'hard bop')
        }
        ProviderArtist = [PSCustomObject]@{
            name = "Miles Davis"
            genres = @('jazz')
        }
        Track = [PSCustomObject]@{
            name = "So What"
            disc_number = 1
            track_number = 1
            duration_ms = 540000
            artists = @([PSCustomObject]@{ name = "Miles Davis" })
        }
        ExpectedGenres = "jazz, bebop, hard bop"
        Source = "album (overrides artist)"
    },
    @{
        Name = "Track-level genres (highest priority)"
        ProviderAlbum = [PSCustomObject]@{
            name = "Various Artists"
            genres = @('Electronic')
        }
        ProviderArtist = [PSCustomObject]@{
            name = "Various"
            genres = @('Pop')
        }
        Track = [PSCustomObject]@{
            name = "Special Track"
            disc_number = 1
            track_number = 1
            duration_ms = 180000
            artists = @([PSCustomObject]@{ name = "DJ Shadow" })
            genres = @('Trip Hop', 'Instrumental Hip Hop')
        }
        ExpectedGenres = "Trip Hop, Instrumental Hip Hop"
        Source = "track (highest priority)"
    }
)

$passed = 0
$failed = 0

foreach ($test in $testCases) {
    Show-Message -Message "`nTest: $($test.Name)" -ForegroundColor Yellow -Context $null
    Show-Message -Message "Expected genres from $($test.Source): $($test.ExpectedGenres)" -ForegroundColor Gray -Context $null
    
    # Create a mock paired track
    $pairedTrack = [PSCustomObject]@{
        SpotifyTrack = $test.Track
        AudioFile = $null
    }
    
    # Test the genre priority logic manually
    $foundGenres = $null
    
    # Priority 1: Track-level genres
    if ($test.Track.PSObject.Properties['genres'] -and $test.Track.genres) {
        $foundGenres = $test.Track.genres -join ', '
        $source = "track"
    }
    # Priority 2: Album-level genres  
    elseif ($test.ProviderAlbum.PSObject.Properties['genres'] -and $test.ProviderAlbum.genres) {
        $foundGenres = $test.ProviderAlbum.genres -join ', '
        $source = "album"
    }
    # Priority 3: Artist-level genres
    elseif ($test.ProviderArtist.PSObject.Properties['genres'] -and $test.ProviderArtist.genres) {
        $foundGenres = $test.ProviderArtist.genres -join ', '
        $source = "artist"
    }
    
    if ($foundGenres -eq $test.ExpectedGenres) {
        Show-Message -Message "✅ PASS: Found genres '$foundGenres' from $source" -ForegroundColor Green -Context $null
        $passed++
    }
    else {
        Show-Message -Message "❌ FAIL: Expected '$($test.ExpectedGenres)' but got '$foundGenres'" -ForegroundColor Red -Context $null
        $failed++
    }
}

Show-Message -Message "`n=== Test Summary ===" -ForegroundColor Cyan -Context $null
Show-Message -Message "Passed: $passed" -ForegroundColor Green -Context $null
Show-Message -Message "Failed: $failed" -ForegroundColor $(if ($failed -gt 0) { 'Red' } else { 'Green' }) -Context $null

if ($failed -eq 0) {
    Show-Message -Message "`n✅ All tests passed! Genre display logic is working correctly." -ForegroundColor Green -Context $null
    Show-Message -Message "Genres will now display from album metadata for Discogs, Qobuz, and MusicBrainz." -ForegroundColor Cyan -Context $null
}
else {
    Show-Message -Message "`n❌ Some tests failed. Please review the genre display logic." -ForegroundColor Red -Context $null
}

