# OM PowerShell Module

OM is a PowerShell module for managing music metadata, integrating with providers like Discogs, MusicBrainz, Qobuz, and Spotify. It supports fetching album/track details, tagging audio files, and manual pairing workflows.

## Installation

1. Clone or download the OM repository to your PowerShell Modules directory (e.g., `C:\Users\<username>\Documents\PowerShell\Modules\OM`).
2. Import the module: `Import-Module OM`

## Configuration

OM requires API keys/tokens for external services. Use `Set-OMConfig` to set them persistently.

### Discogs Token

1. Sign up for a Discogs account at [discogs.com](https://www.discogs.com/).
2. Go to [Settings > Developers](https://www.discogs.com/settings/developers) and generate a Personal Access Token.
3. Set it in OM: `Set-OMConfig -DiscogsToken "your-token-here"`

### Google Custom Search (for Qobuz and other searches)

Used for fetching release details when other providers fail.

1. **Get Google API Key**:
   - Go to [Google Cloud Console](https://console.cloud.google.com/).
   - Create/select a project.
   - Enable the "Custom Search JSON API" in APIs & Services > Library.
   - Go to APIs & Services > Credentials, click "+ Create Credentials > API key".
   - (Optional) Restrict the key to Custom Search API.
   - Copy the API key (e.g., `AIzaSy...`).

2. **Set Up Programmable Search Engine (CSE)**:
   - Go to [Programmable Search Engine](https://programmablesearchengine.google.com/controlpanel/overview).
   - Create a new search engine (e.g., restrict to music sites like qobuz.com).
   - In the control panel, note the "Search engine ID" (a string like `50bb69ba914aa45bb`).

3. **Configure in OM**:
   - `Set-OMConfig -GoogleApiKey "your-api-key-here"`
   - `Set-OMConfig -GoogleCse "your-cse-id-here"`

### Other Providers

- **MusicBrainz**: No API key needed (uses public API).
- **Qobuz**: Requires app credentials (set via config if implemented).
- **Spotify**: Requires client ID/secret (set via config).

View current config: `Get-OMConfig`

## Usage

- Start the workflow: `Start-OM -Path "C:\path\to\album"`
- Tag files: `Set-OMTags -Path "C:\path\to\file.mp3"`
- Search providers: Use internal functions like `Search-DItem` (Discogs) or `Search-QAlbum` (Qobuz).

For detailed commands, see `Get-Command -Module OM`.

## Troubleshooting

- If Google searches fail, ensure both API key and CSE ID are set and the API is enabled.
- Free Google API quota: 100 queries/day.
- For issues, check verbose output: `Start-OM -Verbose`

## Contributing

Report issues or contribute via the GitHub repo.