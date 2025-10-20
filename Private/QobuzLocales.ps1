# Qobuz locale utilities
# Private functions for Qobuz locale handling

function Get-ValidQobuzLocales {
    <#
    .SYNOPSIS
        Returns the list of valid Qobuz culture codes for locale configuration.
    #>
    return @('fr-FR', 'en-US', 'en-GB', 'de-DE', 'es-ES', 'it-IT', 'nl-BE', 'nl-NL', 'pt-PT', 'pt-BR', 'ja-JP')
}

function Get-QobuzUrlLocale {
    <#
    .SYNOPSIS
        Maps a culture code to the corresponding Qobuz URL locale.
    .PARAMETER CultureCode
        The culture code (e.g., 'en-US').
    .OUTPUTS
        The URL locale string (e.g., 'us-en').
    #>
    param([string]$CultureCode)
    $localeMap = @{
        'fr-FR' = 'fr-fr'
        'en-US' = 'us-en'
        'en-GB' = 'gb-en'
        'de-DE' = 'de-de'
        'es-ES' = 'es-es'
        'it-IT' = 'it-it'
        'nl-BE' = 'be-nl'
        'nl-NL' = 'nl-nl'
        'pt-PT' = 'pt-pt'
        'pt-BR' = 'br-pt'
        'ja-JP' = 'jp-ja'
    }
    return $localeMap[$CultureCode] ?? 'us-en'
}