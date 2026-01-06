$errors = @()
[void][System.Management.Automation.Language.Parser]::ParseFile("Public/Start-OM.ps1", [ref]$null, [ref]$errors)
if ($errors.Count -eq 0) { Write-Output 'No parse errors' } else { foreach ($e in $errors) { Write-Output "$($e.Message) -- Line: $($e.Extent.StartLineNumber) Col: $($e.Extent.StartColumnNumber)" } }