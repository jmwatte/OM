# Auto Mode Quick Reference

## Basic Commands

```powershell
# Basic auto mode (80% confidence threshold)
Start-OM -Path "C:\Music\Artist" -Auto

# With provider fallback and cover art
Start-OM -Path "C:\Music\Artist" -Auto -AutoFallback -AutoSaveCover

# Conservative matching (90% threshold)
Start-OM -Path "C:\Music\Artist" -Auto -AutoConfidenceThreshold 0.90

# Preview mode (no changes)
Start-OM -Path "C:\Music\Artist" -Auto -AutoFallback -WhatIf
```

## Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `-Auto` | Switch | Off | Enable automatic mode |
| `-AutoConfidenceThreshold` | Double | 0.80 | Minimum confidence (0.5-1.0) |
| `-AutoFallback` | Switch | Off | Enable provider fallback |
| `-AutoSaveCover` | Switch | Off | Auto-save cover art |

## Confidence Levels

| Threshold | Use Case | Behavior |
|-----------|----------|----------|
| 0.70-0.75 | Aggressive | More automation, some false positives |
| 0.80-0.85 | **Balanced** | Good for most libraries (default) |
| 0.85-0.90 | Conservative | Requires very close matches |
| 0.90-1.00 | Exact | Only perfect matches |

## Provider Fallback Chain

When `-AutoFallback` is enabled:

- **Qobuz** → Spotify → Discogs → MusicBrainz
- **Spotify** → Qobuz → Discogs → MusicBrainz

## Visual Indicators

| Icon | Meaning |
|------|---------|
| 🔍 | Searching provider |
| ✓ | Success / Match found |
| ⚠️ | Warning / Fallback |
| 🤖 | Auto mode decision |
| 🖼️ | Cover art operation |
| 🔄 | Provider switched |

## Batch Processing

```powershell
# Process all artists in a folder
Get-ChildItem "D:\__Fresh" -Directory | 
    Start-OM -Auto -AutoFallback -AutoSaveCover -Provider Qobuz

# Process with logging
Start-OM -Path "C:\Music" -Auto -AutoFallback -Verbose *>&1 | 
    Tee-Object "auto-log.txt"
```

## Troubleshooting

### Too many manual interventions
→ Lower threshold: `-AutoConfidenceThreshold 0.75`  
→ Enable fallback: `-AutoFallback`

### Wrong albums selected
→ Raise threshold: `-AutoConfidenceThreshold 0.90`  
→ Fix folder names

### Want to see decisions
→ Use: `-Verbose`  
→ Preview: `-WhatIf`

## Tips

1. Always test with `-WhatIf` first
2. Use `-Verbose` to see decision details  
3. Monitor first few albums before batch processing
4. Use higher thresholds for classical/complex albums
5. Enable `-AutoFallback` for better success rates

## Full Documentation

See **AUTO_MODE_GUIDE.md** for complete documentation.
