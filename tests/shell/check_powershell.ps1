#!/usr/bin/env pwsh
# Syntax-only gate for the Windows helper scripts, mirroring `make check-shell`.
# Parses each .ps1 without executing it, so this is safe to run anywhere.
#
# Usage: pwsh -NoProfile -File tests/shell/check_powershell.ps1

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptDir = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'scripts'
$failed = $false

foreach ($name in @('herdr-nav.ps1', 'herdr-resize.ps1')) {
    $path = Join-Path $scriptDir $name
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        Write-Host "FAIL: missing $path"
        $failed = $true
        continue
    }

    $errors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile(
        $path, [ref]$null, [ref]$errors)

    if ($errors -and $errors.Count -gt 0) {
        foreach ($e in $errors) { Write-Host "FAIL: ${name}: $($e.Message)" }
        $failed = $true
    } else {
        Write-Host "ok: $name"
    }
}

if ($failed) { exit 1 }
