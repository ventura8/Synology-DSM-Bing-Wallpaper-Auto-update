$ErrorActionPreference = "Stop"
$minPwshVersion = [version]"7.4.14"
if ($PSVersionTable.PSVersion -lt $minPwshVersion) {
    throw "PowerShell $minPwshVersion or newer is required (found $($PSVersionTable.PSVersion))."
}

$requiredVersion = "1.25.0"

$installedModule = Get-Module -ListAvailable -Name PSScriptAnalyzer |
    Where-Object { $_.Version -eq [version]$requiredVersion } |
    Select-Object -First 1

if (-not $installedModule) {
    Write-Host "Installing PSScriptAnalyzer $requiredVersion..." -ForegroundColor Cyan
    Install-Module -Name PSScriptAnalyzer -RequiredVersion $requiredVersion -Scope CurrentUser -Force -Repository PSGallery

    $installedModule = Get-Module -ListAvailable -Name PSScriptAnalyzer |
        Where-Object { $_.Version -eq [version]$requiredVersion } |
        Select-Object -First 1
}

if (-not $installedModule) {
    throw "Required PSScriptAnalyzer version $requiredVersion was not installed."
}

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\\..")
$psFiles = @(Get-ChildItem -Path $repoRoot -Recurse -File -Include *.ps1,*.psm1 |
    Where-Object {
        $_.FullName -notmatch "\\.git\\" -and
        $_.FullName -notmatch "\\.venv\\" -and
        $_.FullName -notmatch "\\venv\\"
    } |
    ForEach-Object { $_.FullName })

if ($psFiles.Count -eq 0) {
    Write-Host "No PowerShell files found to lint." -ForegroundColor Yellow
    exit 0
}

$results = @()
foreach ($psFile in $psFiles) {
    $results += Invoke-ScriptAnalyzer -Path $psFile -Settings .psscriptanalyzer.psd1 -Recurse
}
if ($results) {
    $results | Format-Table -AutoSize | Out-String | Write-Host
    throw "PowerShell linting failed."
}

Write-Host "PowerShell linting passed." -ForegroundColor Green
