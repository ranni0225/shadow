try {
    Push-Location -Path $PSScriptRoot

    function Out-Message {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
            [string[]]$Messages,

            [Parameter(Mandatory = $false)]
            [ValidateSet("Information", "Warning", "Error" )]
            [string]$Level = "Information"
        )

        begin {
            $Configuration = @{
                "Information" = @{ Prefix = "[-]"; Color = "Gray" }
                "Warning"     = @{ Prefix = "[?]"; Color = "Yellow" }
                "Error"       = @{ Prefix = "[!]"; Color = "Red" }
            }
        }

        process {
            $CurrentConfiguration = $Configuration[$Level]
            $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"

            foreach ($Message in $Messages) {
                Write-Host "[$Timestamp] $($CurrentConfiguration.Prefix) $Message" -ForegroundColor $CurrentConfiguration.Color
            }
        }
    }

    $SourceDirectory = $PSScriptRoot
    $DestinationDirectory = Split-Path -Parent $SourceDirectory
    $GitIgnoreFilePath = Join-Path $DestinationDirectory ".gitignore"
    [string[]]$CurrentGitIgnoreEntries = @(Get-Content $GitIgnoreFilePath -ErrorAction SilentlyContinue | ForEach-Object Trim)
    $NewGitIgnoreEntries = [System.Collections.Generic.List[string]]::new()

    $Items = [ordered]@{
        ".clang-format"                       = $null
        ".editorconfig"                       = $null
        ".prettierrc"                         = $null
        "Directory.Build.AfterCppProps.props" = $null
        "Directory.Build.props"               = $null

        "__.pre-commit-config.yaml"           = ".pre-commit-config.yaml"
    }

    foreach ($Item in $Items.GetEnumerator()) {
        $SourceFileName = $Item.Key
        $SourceFilePath = Join-Path $SourceDirectory $SourceFileName

        $DestinationFileName = if ($null -ne $Item.Value) { $Item.Value } else { $SourceFileName }
        $DestinationFilePath = Join-Path $DestinationDirectory $DestinationFileName

        if (Test-Path $SourceFilePath) {
            Remove-Item -Path $DestinationFilePath -Force -ErrorAction SilentlyContinue

            try {
                New-Item -Path $DestinationFilePath -Target $SourceFilePath -ItemType SymbolicLink -ErrorAction Stop | Out-Null
                Out-Message "symbolic link updated: `"$DestinationFilePath`" => `"$SourceFilePath`""

                $NewGitIgnoreEntry = "/$DestinationFileName"
                if ( $NewGitIgnoreEntry -notin $CurrentGitIgnoreEntries -and $NewGitIgnoreEntry -notin $NewGitIgnoreEntries ) {
                    $NewGitIgnoreEntries.Add($NewGitIgnoreEntry)
                }
            }
            catch {
                Out-Message "symbolic link not updated: (exception occurred when processing `"$SourceFileName`") ($($_.Exception.Message))" -Level Error
            }
        }
        else {
            Out-Message "symbolic link not updated: `"$SourceFilePath`" does not exist" -Level Warning
        }
    }
    $UTF8EncodingWithoutBOM = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::AppendAllLines($GitIgnoreFilePath, $NewGitIgnoreEntries, $UTF8EncodingWithoutBOM)

    pip install pre-commit
    npm install prettier @prettier/plugin-xml --save-dev
    Install-Module -Name PSScriptAnalyzer
    Set-Location $DestinationDirectory ; if ($?) { pre-commit install }
}
finally {
    Pop-Location
}
