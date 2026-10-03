BeforeAll {
    . (Join-Path $PSScriptRoot "TestHelpers.ps1")
    $script:Target = Join-Path $script:RepoRoot "scripts/testing/run_tests_local.ps1"
}

Describe "run_tests_local.ps1" {
    BeforeEach {
        $script:State = Enter-StubEnvironment
        Mock Write-Host { }
    }
    AfterEach { Exit-StubEnvironment $script:State }

    It "builds, runs every lane, merges, checks the threshold and updates the badge" {
        New-Item -ItemType Directory -Path "coverage" | Out-Null
        & $script:Target
        $calls = Get-StubCall
        $calls | Should -Contain "docker build -t dsm-mock -f tests/Dockerfile.dsm_mock ."
        ($calls -match "rm -rf coverage").Count | Should -Be 1
        foreach ($mode in "unit", "component", "e2e") {
            ($calls -match "run_kcov_cases.sh '$mode'").Count | Should -Be 1
        }
        ($calls -match "check_coverage_threshold.py .* 90").Count | Should -Be 1
        ($calls -match "generate_detailed_coverage.py").Count | Should -Be 1
        "assets/coverage.svg" | Should -Exist
        "reports/agent-logs/unit.log" | Should -Exist
    }

    It "fails when <Match> fails" -ForEach @(
        @{ Match = "pre_commit"; Message = "Pre-commit quality checks failed." }
        @{ Match = "merge_all.sh"; Message = "Coverage merge failed." }
        @{ Match = "transform_coverage"; Message = "Coverage XML transform failed." }
        @{ Match = "check_coverage_threshold"; Message = "Coverage threshold check failed." }
        @{ Match = "codecoveragesummary"; Message = "CodeCoverageSummary execution failed." }
        @{ Match = "generate_detailed"; Message = "Detailed coverage report generation failed." }
        @{ Match = "run_kcov_cases.sh 'unit'"; Message = "*failed with state Failed*" }
    ) {
        $env:STUB_FAIL_MATCH = $Match
        { & $script:Target } | Should -Throw $Message
    }

    It "fails when stale coverage cannot be removed" {
        New-Item -ItemType Directory -Path "coverage" | Out-Null
        $env:STUB_FAIL_MATCH = "rm -rf coverage"
        { & $script:Target } | Should -Throw "Could not remove the previous coverage directory."
    }

    It "fails when the docker image does not build" {
        $env:STUB_FAIL_MATCH = "build -t dsm-mock"
        { & $script:Target } | Should -Throw "Docker build failed."
    }

    It "reclaims root-owned coverage output and fails if it cannot" {
        $env:STUB_OWNER_UID = "0"
        & $script:Target
        (Get-StubCall) -match "chown -R" | Should -Not -BeNullOrEmpty
        $env:STUB_FAIL_MATCH = "chown -R"
        { & $script:Target } | Should -Throw "Could not reclaim ownership of the coverage directory."
    }

    It "fails when the merge leaves no report" {
        $env:STUB_NO_REPORT = "1"
        { $ErrorActionPreference = "Stop"; & $script:Target } | Should -Throw "Coverage XML not found."
    }
}
