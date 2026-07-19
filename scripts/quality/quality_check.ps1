param(
    [switch]$InstallDeps
)

$ErrorActionPreference = "Stop"
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\\..")

if ($InstallDeps) {
    Write-Host "Installing Python quality dependencies..." -ForegroundColor Cyan
    python -m pip install -r requirements/dev.txt
    if ($LASTEXITCODE -ne 0) {
        throw "Dependency installation failed."
    }
}

Write-Host "Running pre-commit quality checks..." -ForegroundColor Cyan
python -m pre_commit run --all-files --show-diff-on-failure
if ($LASTEXITCODE -ne 0) {
    throw "Pre-commit quality checks failed."
}

Write-Host "Running explicit non-Markdown line length check..." -ForegroundColor Cyan
python (Join-Path $repoRoot "scripts/quality/check_line_length.py")
if ($LASTEXITCODE -ne 0) {
    throw "Line length validation failed."
}

Write-Host "All quality checks passed." -ForegroundColor Green
