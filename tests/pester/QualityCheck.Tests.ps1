BeforeAll {
    . (Join-Path $PSScriptRoot "TestHelpers.ps1")
    $script:Target = Join-Path $script:RepoRoot "scripts/quality/quality_check.ps1"
}

Describe "quality_check.ps1" {
    BeforeEach { $script:State = Enter-StubEnvironment }
    AfterEach { Exit-StubEnvironment $script:State }

    It "runs pre-commit then the line length check" {
        & $script:Target
        $calls = Get-StubCall
        $calls[0] | Should -Match "pre_commit run --all-files"
        $calls[1] | Should -Match "check_line_length.py"
    }

    It "installs dependencies when asked" {
        & $script:Target -InstallDeps
        (Get-StubCall)[0] | Should -Match "pip install -r requirements/dev.txt"
    }

    It "fails when <Match> fails" -ForEach @(
        @{ Match = "pip install"; Message = "Dependency installation failed." }
        @{ Match = "pre_commit"; Message = "Pre-commit quality checks failed." }
        @{ Match = "check_line_length"; Message = "Line length validation failed." }
    ) {
        $env:STUB_FAIL_MATCH = $Match
        { & $script:Target -InstallDeps } | Should -Throw $Message
    }
}
