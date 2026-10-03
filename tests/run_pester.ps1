# Run the Pester suite under code coverage and restate the result in SonarQube's generic
# coverage format, since Sonar has no native importer for PowerShell coverage.
param(
    [string]$OutputPath = "coverage-powershell.xml",
    [double]$MinimumPercent = 90
)

$ErrorActionPreference = "Stop"
$pesterVersion = "6.2.0"
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path

Import-Module Pester -RequiredVersion $pesterVersion

$targets = @(
    "scripts/lint/lint_powershell.ps1",
    "scripts/quality/quality_check.ps1",
    "scripts/testing/run_tests_local.ps1"
) | ForEach-Object { Join-Path $repoRoot $_ }

$config = New-PesterConfiguration
$config.Run.Path = Join-Path $PSScriptRoot "pester"
$config.Run.PassThru = $true
$config.Output.Verbosity = "Normal"
$config.CodeCoverage.Enabled = $true
$config.CodeCoverage.Path = $targets
# Pester always writes its own JaCoCo report; keep it out of the tree.
New-Item -ItemType Directory -Path (Join-Path $repoRoot "reports") -Force | Out-Null
$config.CodeCoverage.OutputPath = Join-Path $repoRoot "reports/pester-coverage.xml"

$result = Invoke-Pester -Configuration $config
if ($result.FailedCount -gt 0) { throw "$($result.FailedCount) Pester test(s) failed." }

# Sonar counts a line as covered when any command on it ran.
$lines = @{}
foreach ($command in $result.CodeCoverage.CommandsMissed) {
    $lines["$($command.File)|$($command.Line)"] = $false
}
foreach ($command in $result.CodeCoverage.CommandsExecuted) {
    $lines["$($command.File)|$($command.Line)"] = $true
}

$settings = [System.Xml.XmlWriterSettings]@{ Indent = $true }
$writer = [System.Xml.XmlWriter]::Create((Join-Path $repoRoot $OutputPath), $settings)
$writer.WriteStartElement("coverage")
$writer.WriteAttributeString("version", "1")
foreach ($file in $targets) {
    $writer.WriteStartElement("file")
    $writer.WriteAttributeString("path", [System.IO.Path]::GetRelativePath($repoRoot, $file).Replace("\", "/"))
    $fileKeys = $lines.Keys | Where-Object { $_.StartsWith("$file|") } | Sort-Object { [int]($_.Split("|")[-1]) }
    foreach ($key in $fileKeys) {
        $writer.WriteStartElement("lineToCover")
        $writer.WriteAttributeString("lineNumber", $key.Split("|")[-1])
        $writer.WriteAttributeString("covered", $lines[$key].ToString().ToLowerInvariant())
        $writer.WriteEndElement()
    }
    $writer.WriteEndElement()
}
$writer.WriteEndElement()
$writer.Close()

# Gate on lines, the unit Sonar reports. Start-Job bodies run in another process that
# Pester cannot instrument, so its command-based figure undercounts those scripts.
$covered = @($lines.Values | Where-Object { $_ }).Count
$coverage = 100 * $covered / [math]::Max($lines.Count, 1)
Write-Host ("PowerShell line coverage: {0:N2}% ({1}/{2}, minimum {3}%)" -f $coverage, $covered, $lines.Count, $MinimumPercent)
if ($coverage -lt $MinimumPercent) { throw "PowerShell coverage is below $MinimumPercent%." }
