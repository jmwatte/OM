Describe 'Set-Tracks Integration Tests' {
    BeforeAll {
        Import-Module "$PSScriptRoot\..\OM.psd1" -Force
        
        # Use existing test files
        $script:testAlbumPath = "$PSScriptRoot\..\testfiles\The Beatles\1965 - Help! (Remastered)"
        
        # Skip if test files don't exist
        if (-not (Test-Path $script:testAlbumPath)) {
            Set-ItResult -Skipped -Because "Test files not found at $script:testAlbumPath"
        }
        
        # Get a reference to Set-Tracks from the module
        $script:SetTracks = (Get-Module OM).Invoke({ Get-Command Set-Tracks }).ScriptBlock
        $script:ReloadAudioFiles = (Get-Module OM).Invoke({ Get-Command Reload-OMAudioFiles }).ScriptBlock
    }
    
    Context 'Set-Tracks with real audio files' {
        BeforeEach {
            # Load audio files using the module function
            $script:audioFiles = InModuleScope OM {
                Reload-OMAudioFiles -AlbumPath $testAlbumPath -SkipSort:$false
            } -Parameters @{ testAlbumPath = $script:testAlbumPath }
            
            # Create mock Spotify tracks (simulating API response)
            $script:mockSpotifyTracks = @(
                [PSCustomObject]@{ id = '1'; name = 'Help!'; track_number = 1; disc_number = 1; duration_ms = 138000 }
                [PSCustomObject]@{ id = '2'; name = 'The Night Before'; track_number = 2; disc_number = 1; duration_ms = 153000 }
                [PSCustomObject]@{ id = '3'; name = "You've Got To Hide Your Love Away"; track_number = 3; disc_number = 1; duration_ms = 131000 }
                [PSCustomObject]@{ id = '4'; name = 'I Need You'; track_number = 4; disc_number = 1; duration_ms = 148000 }
                [PSCustomObject]@{ id = '5'; name = 'Another Girl'; track_number = 5; disc_number = 1; duration_ms = 124000 }
                [PSCustomObject]@{ id = '6'; name = "You're Going To Lose That Girl"; track_number = 6; disc_number = 1; duration_ms = 140000 }
                [PSCustomObject]@{ id = '7'; name = 'Ticket To Ride'; track_number = 7; disc_number = 1; duration_ms = 192000 }
                [PSCustomObject]@{ id = '8'; name = 'Act Naturally'; track_number = 8; disc_number = 1; duration_ms = 149000 }
                [PSCustomObject]@{ id = '9'; name = "It's Only Love"; track_number = 9; disc_number = 1; duration_ms = 115000 }
                [PSCustomObject]@{ id = '10'; name = 'You Like Me Too Much'; track_number = 10; disc_number = 1; duration_ms = 158000 }
                [PSCustomObject]@{ id = '11'; name = 'Tell Me What You See'; track_number = 11; disc_number = 1; duration_ms = 138000 }
                [PSCustomObject]@{ id = '12'; name = "I've Just Seen A Face"; track_number = 12; disc_number = 1; duration_ms = 127000 }
                [PSCustomObject]@{ id = '13'; name = 'Yesterday'; track_number = 13; disc_number = 1; duration_ms = 125000 }
                [PSCustomObject]@{ id = '14'; name = 'Dizzy Miss Lizzy'; track_number = 14; disc_number = 1; duration_ms = 164000 }
            )
        }
        
        AfterEach {
            # Dispose of TagLib file handles
            if ($script:audioFiles) {
                foreach ($af in @($script:audioFiles)) {
                    if ($af.TagFile) {
                        try { $af.TagFile.Dispose() } catch { }
                    }
                }
            }
        }
        
        It 'should handle null AudioFiles array' {
            $tracks = $script:mockSpotifyTracks
            $result = InModuleScope OM {
                Set-Tracks -SortMethod 'byOrder' -AudioFiles $null -SpotifyTracks $tracks
            } -Parameters @{ tracks = $tracks }
            
            $result | Should -Not -BeNullOrEmpty
            # Should return unpaired Spotify tracks
        }
        
        It 'should handle null SpotifyTracks array' {
            $audio = $script:audioFiles
            $result = InModuleScope OM {
                Set-Tracks -SortMethod 'byOrder' -AudioFiles $audio -SpotifyTracks $null
            } -Parameters @{ audio = $audio }
            
            $result | Should -Not -BeNullOrEmpty
            # Should return unpaired audio files
        }
        
        It 'should handle empty AudioFiles array' {
            $tracks = $script:mockSpotifyTracks
            $result = InModuleScope OM {
                Set-Tracks -SortMethod 'byOrder' -AudioFiles @() -SpotifyTracks $tracks
            } -Parameters @{ tracks = $tracks }
            
            $result | Should -Not -BeNullOrEmpty
        }
        
        It 'should handle empty SpotifyTracks array' {
            $audio = $script:audioFiles
            $result = InModuleScope OM {
                Set-Tracks -SortMethod 'byOrder' -AudioFiles $audio -SpotifyTracks @()
            } -Parameters @{ audio = $audio }
            
            $result | Should -Not -BeNullOrEmpty
        }
        
        It 'should handle single AudioFile (not array)' {
            $singleFile = $script:audioFiles | Select-Object -First 1
            $tracks = $script:mockSpotifyTracks
            $result = InModuleScope OM {
                Set-Tracks -SortMethod 'byOrder' -AudioFiles $singleFile -SpotifyTracks $tracks
            } -Parameters @{ singleFile = $singleFile; tracks = $tracks }
            
            $result | Should -Not -BeNullOrEmpty
        }
        
        It 'should handle single SpotifyTrack (not array)' {
            $audio = $script:audioFiles
            $singleTrack = $script:mockSpotifyTracks | Select-Object -First 1
            $result = InModuleScope OM {
                Set-Tracks -SortMethod 'byOrder' -AudioFiles $audio -SpotifyTracks $singleTrack
            } -Parameters @{ audio = $audio; singleTrack = $singleTrack }
            
            $result | Should -Not -BeNullOrEmpty
        }
        
        It 'should pair tracks using byOrder sort method' {
            $audio = $script:audioFiles
            $tracks = $script:mockSpotifyTracks
            $result = InModuleScope OM {
                Set-Tracks -SortMethod 'byOrder' -AudioFiles $audio -SpotifyTracks $tracks
            } -Parameters @{ audio = $audio; tracks = $tracks }
            
            $result | Should -Not -BeNullOrEmpty
            @($result).Count | Should -BeGreaterThan 0
            
            # Check that tracks are paired
            $paired = @($result | Where-Object { $_.SpotifyTrack -and $_.AudioFile })
            $paired.Count | Should -BeGreaterThan 0
        }
        
        It 'should pair tracks using byFilesystem sort method' {
            $audio = $script:audioFiles
            $tracks = $script:mockSpotifyTracks
            $result = InModuleScope OM {
                Set-Tracks -SortMethod 'byFilesystem' -AudioFiles $audio -SpotifyTracks $tracks
            } -Parameters @{ audio = $audio; tracks = $tracks }
            
            $result | Should -Not -BeNullOrEmpty
            @($result).Count | Should -BeGreaterThan 0
        }
        
        It 'should pair tracks using byTitle sort method' {
            $audio = $script:audioFiles
            $tracks = $script:mockSpotifyTracks
            $result = InModuleScope OM {
                Set-Tracks -SortMethod 'byTitle' -AudioFiles $audio -SpotifyTracks $tracks
            } -Parameters @{ audio = $audio; tracks = $tracks }
            
            $result | Should -Not -BeNullOrEmpty
            @($result).Count | Should -BeGreaterThan 0
        }
        
        It 'should pair tracks using byDuration sort method' {
            $audio = $script:audioFiles
            $tracks = $script:mockSpotifyTracks
            $result = InModuleScope OM {
                Set-Tracks -SortMethod 'byDuration' -AudioFiles $audio -SpotifyTracks $tracks
            } -Parameters @{ audio = $audio; tracks = $tracks }
            
            $result | Should -Not -BeNullOrEmpty
            @($result).Count | Should -BeGreaterThan 0
        }
        
        It 'should work with Reverse flag' {
            $audio = $script:audioFiles
            $tracks = $script:mockSpotifyTracks
            $result = InModuleScope OM {
                Set-Tracks -SortMethod 'byOrder' -AudioFiles $audio -SpotifyTracks $tracks -Reverse
            } -Parameters @{ audio = $audio; tracks = $tracks }
            
            $result | Should -Not -BeNullOrEmpty
            @($result).Count | Should -BeGreaterThan 0
        }
        
        It 'should handle mismatched track counts (more provider tracks)' {
            $audio = $script:audioFiles
            # Provider has 14 tracks, audio has 14, but let's add more
            $extraTracks = $script:mockSpotifyTracks + @(
                [PSCustomObject]@{ id = '15'; name = 'Bonus Track 1'; track_number = 15; disc_number = 1; duration_ms = 180000 }
                [PSCustomObject]@{ id = '16'; name = 'Bonus Track 2'; track_number = 16; disc_number = 1; duration_ms = 200000 }
            )
            
            $result = InModuleScope OM {
                Set-Tracks -SortMethod 'byOrder' -AudioFiles $audio -SpotifyTracks $extraTracks
            } -Parameters @{ audio = $audio; extraTracks = $extraTracks }
            
            $result | Should -Not -BeNullOrEmpty
            # Should have some unpaired Spotify tracks
            $unpairedSpotify = @($result | Where-Object { $_.SpotifyTrack -and -not $_.AudioFile })
            $unpairedSpotify.Count | Should -Be 2
        }
    }
}
