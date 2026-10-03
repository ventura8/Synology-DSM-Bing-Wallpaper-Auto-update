# Shared setup for the Pester suite. Only process boundaries are faked: docker and python
# resolve to the logging stubs in ./stubs, so the scripts under test run unmodified.

$script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$script:StubDir = Join-Path $PSScriptRoot "stubs"

function Enter-StubEnvironment {
    $work = Join-Path ([System.IO.Path]::GetTempPath()) ([System.IO.Path]::GetRandomFileName())
    New-Item -ItemType Directory -Path $work | Out-Null
    $state = @{
        Work = $work
        Path = $env:PATH
        Location = (Get-Location).Path
    }
    $env:PATH = "$script:StubDir$([System.IO.Path]::PathSeparator)$env:PATH"
    $env:STUB_LOG = Join-Path $work "calls.log"
    $env:STUB_FAIL_MATCH = ""
    $env:STUB_NO_REPORT = ""
    Set-Location $work
    return $state
}

function Exit-StubEnvironment {
    param($State)
    Set-Location $State.Location
    $env:PATH = $State.Path
    Remove-Item Env:STUB_LOG, Env:STUB_FAIL_MATCH, Env:STUB_NO_REPORT, Env:STUB_OWNER_UID -ErrorAction SilentlyContinue
    Remove-Item -Recurse -Force $State.Work
}

function Get-StubCall {
    if (-not (Test-Path $env:STUB_LOG)) { return @() }
    return @(Get-Content $env:STUB_LOG)
}
