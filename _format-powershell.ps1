param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Files
)

foreach ($File in $Files) {
    if (Test-Path $File) {
        try {
            $FileContent = Get-Content -Path $File -Raw
            $FormattedFileContent = Invoke-Formatter -ScriptDefinition $FileContent
            if ($null -ne $FormattedFileContent -and $FileContent -ne $FormattedFileContent) {
                $FormattedFileContent | Set-Content -Path $File -NoNewline -Encoding UTF8
            }
        }
        catch {
        }
    }
}
