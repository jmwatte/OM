# Quick Genre Update - One-Liners

## Find albums missing genres
```powershell
.\find-missing-genres.ps1 -Path "C:\Music"
```

## Preview updates (safe, no changes)
```powershell
.\find-missing-genres.ps1 -Path "C:\Music" -PassThru | ForEach-Object { Start-OM -Path $_ -UpdateGenresOnly -Auto -Provider Discogs -WhatIf }
```

## Update missing genres (Discogs)
```powershell
.\find-missing-genres.ps1 -Path "C:\Music" -PassThru | ForEach-Object { Start-OM -Path $_ -UpdateGenresOnly -Auto -Provider Discogs }
```

## Update missing genres (Qobuz - good for classical)
```powershell
.\find-missing-genres.ps1 -Path "C:\Music\Classical" -PassThru | ForEach-Object { Start-OM -Path $_ -UpdateGenresOnly -Auto -Provider Qobuz }
```

## Merge genres (add to existing, don't replace)
```powershell
.\find-missing-genres.ps1 -Path "C:\Music" -PassThru | ForEach-Object { Start-OM -Path $_ -UpdateGenresOnly -GenreMode Merge -Auto -Provider Discogs }
```

## Export list to CSV for later
```powershell
.\find-missing-genres.ps1 -Path "C:\Music" -ExportCsv "missing-genres.csv"
```

## Process from CSV (after review)
```powershell
Import-Csv "missing-genres.csv" | Select -ExpandProperty Path | ForEach-Object { Start-OM -Path $_ -UpdateGenresOnly -Auto -Provider Discogs }
```

## Find albums with incomplete genres (< 2 genres)
```powershell
.\find-missing-genres.ps1 -Path "C:\Music" -MinGenreCount 2 -PassThru | ForEach-Object { Start-OM -Path $_ -UpdateGenresOnly -GenreMode Merge -Auto -Provider Discogs }
```

## Interactive mode (select album manually for each folder)
```powershell
.\find-missing-genres.ps1 -Path "C:\Music" -PassThru | ForEach-Object { Start-OM -Path $_ -UpdateGenresOnly -Provider Qobuz }
```
