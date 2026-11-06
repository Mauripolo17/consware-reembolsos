#requires -Version 7.0
<#
.SYNOPSIS
Starts one Consware component using its documented development configuration.
.EXAMPLE
pwsh -File scripts/start.ps1 api
.EXAMPLE
pwsh -File scripts/start.ps1 mobile-web
.EXAMPLE
pwsh -File scripts/start.ps1 mobile-android -Device emulator-5554
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0)]
    [ValidateSet('api', 'mobile-web', 'mobile-android', 'web')]
    [string]$Target,
    [string]$ApiBaseUrl,
    [string]$Device = 'emulator-5554',
    [string]$FlutterPath
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
if (-not $ApiBaseUrl) {
    $ApiBaseUrl = if ($Target -eq 'mobile-android') { 'http://10.0.2.2:5000' } else { 'http://localhost:5000' }
}

function Resolve-Flutter {
    if ($FlutterPath) {
        if (-not (Test-Path -LiteralPath $FlutterPath -PathType Leaf)) { throw "Flutter executable not found: $FlutterPath" }
        return $FlutterPath
    }
    $command = Get-Command flutter -ErrorAction SilentlyContinue
    if ($command) { return $command.Source }
    $candidate = Join-Path $env:LOCALAPPDATA 'consware-tools/flutter/bin/flutter.bat'
    if (Test-Path -LiteralPath $candidate -PathType Leaf) { return $candidate }
    throw 'Flutter was not found. Add it to PATH or pass -FlutterPath with the full executable path.'
}

Push-Location $repositoryRoot
try {
    switch ($Target) {
        'api' {
            & dotnet run --project backend/Consware.Reimbursements.Api --no-launch-profile --urls http://0.0.0.0:5000
        }
        'mobile-web' {
            $flutterExecutable = Resolve-Flutter
            Set-Location mobile
            & $flutterExecutable run -d edge --web-hostname localhost --web-port 8080 "--dart-define=API_BASE_URL=$ApiBaseUrl"
        }
        'mobile-android' {
            $flutterExecutable = Resolve-Flutter
            Set-Location mobile
            & $flutterExecutable run -d $Device "--dart-define=API_BASE_URL=$ApiBaseUrl"
        }
        'web' {
            Set-Location web
            & npm.cmd start -- --host localhost --port 4200
        }
    }
    $componentExitCode = $LASTEXITCODE
} finally {
    Pop-Location
}
exit $componentExitCode
