# Run tests locally using Docker with kcov coverage matching CI pipeline (Parallel execution)

$dsmImage = "dsm-mock"
$coverageBase = Join-Path $PWD "coverage"

Write-Host "Running mandatory quality checks before tests..." -ForegroundColor Cyan
& "$PSScriptRoot/../quality/quality_check.ps1"
if ($LASTEXITCODE -ne 0) { throw "Quality checks failed." }

# Clean previous runs
if (Test-Path $coverageBase) { Remove-Item -Recurse -Force $coverageBase }
New-Item -ItemType Directory -Path $coverageBase | Out-Null

# 1. Build the Docker image
Write-Host "Building Docker image..." -ForegroundColor Cyan
docker build -t $dsmImage -f tests/Dockerfile.dsm_mock .
if ($LASTEXITCODE -ne 0) { Write-Error "Docker build failed."; exit 1 }

# 2. Run Tests in Parallel using PowerShell Jobs
Write-Host "Starting Parallel Test Runs (Unit, Component, E2E)..." -ForegroundColor Cyan

$testTasks = @(
    @{
                Name = "Unit"
                CoverageSubdir = "unit"
                CoverageMode = "unit"
    },
    @{
                Name = "Component"
                CoverageSubdir = "comp"
                CoverageMode = "component"
    },
    @{
                Name = "E2E"
                CoverageSubdir = "e2e"
                CoverageMode = "e2e"
    }
)

$jobs = @()
foreach ($task in $testTasks) {
    New-Item -ItemType Directory -Path (Join-Path $coverageBase $task.Name.ToLower()) -Force | Out-Null
    Write-Host "Launching $($task.Name) tests..." -ForegroundColor Green
    $jobs += Start-Job -ScriptBlock {
        param($taskConfig, $name, $basePath, $image)
        Write-Host "Running $name Job..."
        $coverageMount = "${basePath}/$($taskConfig.CoverageSubdir):/app/coverage"
        $bashCommand = "./run_kcov_cases.sh '$($taskConfig.CoverageMode)' /app/coverage"
        $dockerArgs = @(
            "run",
            "--rm",
            "--security-opt",
            "seccomp=unconfined",
            "--cap-add",
            "SYS_PTRACE",
            "-v",
            $coverageMount,
            $image,
            "bash",
            "-c",
            $bashCommand
        )
        & docker @dockerArgs
        if ($LASTEXITCODE -ne 0) {
            throw "$name job failed with exit code $LASTEXITCODE"
        }
    } -ArgumentList $task, $task.Name, $coverageBase, $dsmImage
}

Write-Host "Waiting for tests to complete..." -ForegroundColor Yellow
Wait-Job $jobs | Out-Null

# Check for failure
$jobErrors = @()
$jobResults = Receive-Job $jobs -ErrorAction SilentlyContinue -ErrorVariable jobErrors
$jobResults | Write-Host

foreach ($job in $jobs) {
    if ($job.State -ne "Completed") {
        throw "Job $($job.Name) failed with state $($job.State)"
    }
}

if ($jobErrors.Count -gt 0) {
    foreach ($jobError in $jobErrors) {
        Write-Host $jobError
    }
    throw "One or more parallel test jobs failed."
}

# 3. Merge Coverage Output
Write-Host "Merging Coverage Reports..." -ForegroundColor Cyan
New-Item -ItemType Directory -Path "$coverageBase/merged" | Out-Null

$mergeScript = @'
#!/bin/bash
DIRS=$(find coverage -name coverage.db -exec dirname {} \;)
if [ -z "$DIRS" ]; then
    echo "No coverage directories found!"
    exit 1
fi
echo "Merging directories: $DIRS"
kcov --merge coverage/merged $DIRS
'@

$mergeScript | Out-File -FilePath "$coverageBase/merge_all.sh" -Encoding ascii

docker run --rm `
    --security-opt seccomp=unconfined `
    --cap-add SYS_PTRACE `
    -v "${PWD}:/workdir" `
    -w /workdir `
    $dsmImage bash -c "dos2unix coverage/merge_all.sh && chmod +x coverage/merge_all.sh && ./coverage/merge_all.sh"
if ($LASTEXITCODE -ne 0) {
    throw "Coverage merge failed."
}

# 4. Check for report
$foundXmlPath = Get-ChildItem -Path "$coverageBase/merged" -Recurse -Filter "cobertura.xml" |
    Select-Object -First 1 |
    Select-Object -ExpandProperty FullName

if ($foundXmlPath) {
    Write-Host "Merged Coverage Report Found: $foundXmlPath" -ForegroundColor Green

    # Transform XML for compatibility check
    Write-Host "Transforming XML..."
    python tests/transform_coverage.py "$foundXmlPath"
    if ($LASTEXITCODE -ne 0) {
        throw "Coverage XML transform failed."
    }

    Write-Host "Enforcing minimum coverage threshold (90%)..." -ForegroundColor Cyan
    python scripts/coverage_checks/check_coverage_threshold.py "$foundXmlPath" 90
    if ($LASTEXITCODE -ne 0) {
        throw "Coverage threshold check failed."
    }

    # Display the cobertura summary
    [xml]$xml = Get-Content $foundXmlPath
    $classes = $xml.SelectNodes("//class")
    Write-Host "Found $($classes.Count) classes in merged report." -ForegroundColor Yellow
    foreach ($class in $classes) {
        Write-Host "Class: $($class.name) (File: $($class.filename)) - Coverage: $($class.'line-rate')" -ForegroundColor Cyan
    }

    # Debug: Print the first few lines of the transformed XML to verify structure (First 5 lines)
    Write-Host "--- Transformed XML Preview ---" -ForegroundColor Gray
    Get-Content $foundXmlPath -TotalCount 5
    Write-Host "-------------------------------" -ForegroundColor Gray

    # 5. Run Irongut CodeCoverageSummary locally (Best Effort)
    Write-Host "Running CodeCoverageSummary (CI Simulation)..." -ForegroundColor Cyan

    # Run CodeCoverageSummary from the report directory so a simple relative path works reliably.
    $xmlDirInContainer = "/github/workspace/coverage/merged/kcov-merged"

    docker run --rm `
        -v "${PWD}:/github/workspace" `
        -w "$xmlDirInContainer" `
        ghcr.io/irongut/codecoveragesummary:v1.3.0 `
        commandline `
        --files cobertura.xml `
        --badge true `
        --fail false `
        --format markdown `
        --hidebranch false `
        --hidecomplexity false `
        --indicators true `
        --output both `
        --thresholds '90 95'
    if ($LASTEXITCODE -ne 0) {
        throw "CodeCoverageSummary execution failed."
    }

    # Move the badge to assets
    if (Test-Path "badge.svg") {
        Write-Host "Updating assets/coverage.svg..." -ForegroundColor Green
        if (-not (Test-Path "assets")) { New-Item -ItemType Directory -Path "assets" | Out-Null }
        Move-Item -Force "badge.svg" "assets/coverage.svg"
    }

    # 6. Generate final text summary last so local output ends with overall and per-file metrics.
    Write-Host "Generating Detailed Coverage Report (Python)..." -ForegroundColor Cyan
    python tests/generate_detailed_coverage.py "$foundXmlPath"
    if ($LASTEXITCODE -ne 0) {
        throw "Detailed coverage report generation failed."
    }

}
else {
    Write-Error "Coverage XML not found."
    exit 1
}
