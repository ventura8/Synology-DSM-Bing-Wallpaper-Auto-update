BeforeAll {
    . (Join-Path $PSScriptRoot "TestHelpers.ps1")
    $script:Target = Join-Path $script:RepoRoot "scripts/lint/lint_powershell.ps1"
}

# PSScriptAnalyzer and the PowerShell Gallery are external modules, so they are mocked;
# the file discovery and result handling in the script run for real.
Describe "lint_powershell.ps1" {
    BeforeEach {
        Mock Invoke-ScriptAnalyzer { @() }
        Mock Install-Module { }
        Mock Write-Host { }
    }

    It "lints every PowerShell file in the repository" {
        Mock Get-Module { [pscustomobject]@{ Name = "PSScriptAnalyzer"; Version = [version]"1.25.0" } } -ParameterFilter { $ListAvailable }
        & $script:Target
        Should -Invoke Install-Module -Times 0
        Should -Invoke Invoke-ScriptAnalyzer -ParameterFilter { $Path -like "*run_tests_local.ps1" }
        Should -Invoke Write-Host -ParameterFilter { $Object -eq "PowerShell linting passed." }
    }

    It "fails when the analyzer reports findings" {
        Mock Get-Module { [pscustomobject]@{ Name = "PSScriptAnalyzer"; Version = [version]"1.25.0" } } -ParameterFilter { $ListAvailable }
        Mock Invoke-ScriptAnalyzer { [pscustomobject]@{ RuleName = "PSAvoidLongLines" } }
        { & $script:Target } | Should -Throw "PowerShell linting failed."
    }

    It "installs the pinned analyzer when it is missing" {
        $global:AnalyzerInstalled = $false
        Mock Get-Module {
            if ($global:AnalyzerInstalled) { [pscustomobject]@{ Name = "PSScriptAnalyzer"; Version = [version]"1.25.0" } }
        } -ParameterFilter { $ListAvailable }
        Mock Install-Module { $global:AnalyzerInstalled = $true }
        & $script:Target
        Should -Invoke Install-Module -Times 1 -ParameterFilter { $RequiredVersion -eq "1.25.0" }
    }

    It "fails when the analyzer cannot be installed" {
        Mock Get-Module { } -ParameterFilter { $ListAvailable }
        { & $script:Target } | Should -Throw "Required PSScriptAnalyzer version 1.25.0 was not installed."
    }
}
