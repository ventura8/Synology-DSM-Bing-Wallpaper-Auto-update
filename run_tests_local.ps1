# Run tests locally using Docker with kcov coverage matching CI pipeline (Parallel execution)

$dsmImage = "dsm-mock"
$coverageBase = Join-Path $PWD "coverage"

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
        Cmd  = "docker run --rm --security-opt seccomp=unconfined --cap-add SYS_PTRACE -v `"${coverageBase}/unit:/app/coverage`" $dsmImage bash -c `"export BING_RESOLUTION='4k' ENABLE_ARCHIVE='false' CHECK_ARCHIVE='false' && kcov --include-pattern=bing_wallpaper_auto_update.sh /app/coverage ./bing_wallpaper_auto_update.sh && ./verify_dsm_mock.sh`""
    },
    @{
        Name = "Component"
        Cmd  = "docker run --rm --security-opt seccomp=unconfined --cap-add SYS_PTRACE -v `"${coverageBase}/comp:/app/coverage`" $dsmImage bash -c `"export BING_RESOLUTION='4k' ENABLE_ARCHIVE='true' CHECK_ARCHIVE='true' && kcov --include-pattern=bing_wallpaper_auto_update.sh /app/coverage ./bing_wallpaper_auto_update.sh && ./verify_dsm_mock.sh`""
    },
    @{
        Name = "E2E"
        Cmd  = "docker run --rm --security-opt seccomp=unconfined --cap-add SYS_PTRACE -v `"${coverageBase}/e2e:/app/coverage`" $dsmImage bash -c `"export BING_RESOLUTION='1080p' ENABLE_ARCHIVE='false' CHECK_ARCHIVE='false' && kcov --include-pattern=bing_wallpaper_auto_update.sh /app/coverage ./bing_wallpaper_auto_update.sh && ./verify_dsm_mock.sh`""
    }
)

$jobs = @()
foreach ($task in $testTasks) {
    New-Item -ItemType Directory -Path (Join-Path $coverageBase $task.Name.ToLower()) -Force | Out-Null
    Write-Host "Launching $($task.Name) tests..." -ForegroundColor Green
    $jobs += Start-Job -ScriptBlock {
        param($cmd, $name)
        Write-Host "Running $name Job..."
        Invoke-Expression $cmd
    } -ArgumentList $task.Cmd, $task.Name
}

Write-Host "Waiting for tests to complete..." -ForegroundColor Yellow
Wait-Job $jobs | Out-Null

# Check for failure
$jobResults = Receive-Job $jobs
$jobResults | Write-Host

foreach ($job in $jobs) {
    if ($job.State -ne "Completed") {
        Write-Error "Job $($job.Name) failed with state $($job.State)"
    }
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

# 4. Check for report
$foundXmlPath = Get-ChildItem -Path "$coverageBase/merged" -Recurse -Filter "cobertura.xml" | Select-Object -First 1 | Select-Object -ExpandProperty FullName

if ($foundXmlPath) {
    Write-Host "Merged Coverage Report Found: $foundXmlPath" -ForegroundColor Green
    
    # Transform XML for compatibility check
    Write-Host "Transforming XML..."
    python tests/transform_coverage.py "$foundXmlPath"

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

    # 5. Generate Text Summary using Local Python Script
    # This proves the coverage reporting is working reliably locally
    Write-Host "Generating Detailed Coverage Report (Python)..." -ForegroundColor Cyan
    python tests/generate_detailed_coverage.py "$foundXmlPath"

    # 6. Run Irongut CodeCoverageSummary locally (Best Effort)
    Write-Host "Running CodeCoverageSummary (CI Simulation)..." -ForegroundColor Cyan
    
    # We mount the directory containing the XML to /tmp/report
    # And we assume the tool can read it from an absolute path if we pass it
    # We use format 'markdown' to see the output
    $xmlDir = Split-Path $foundXmlPath -Parent
    
    docker run --rm `
        -v "${xmlDir}:/tmp/report" `
        -v "${PWD}:/github/workspace" `
        -w "/github/workspace" `
        ghcr.io/irongut/codecoveragesummary:v1.3.0 `
        commandline --files /tmp/report/*/cobertura.xml --badge true --fail false --format markdown --hidebranch false --hidecomplexity true --indicators true --output both --thresholds '90 95'

    # Move the badge to assets
    if (Test-Path "badge.svg") {
        Write-Host "Updating assets/coverage.svg..." -ForegroundColor Green
        if (-not (Test-Path "assets")) { New-Item -ItemType Directory -Path "assets" | Out-Null }
        Move-Item -Force "badge.svg" "assets/coverage.svg"
    }

}
else {
    Write-Error "Coverage XML not found."
    exit 1
}
