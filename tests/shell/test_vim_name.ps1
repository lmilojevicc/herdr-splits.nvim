#!/usr/bin/env pwsh
# PowerShell twin of tests/shell/test_vim_name.sh: covers Test-VimProcessName,
# the helper that decides "is this pane running Vim?" on Windows.
#
# The function is lifted out of the real script via the PowerShell AST rather
# than copied here, so the test can never drift from what actually ships.
#
# Usage: pwsh -NoProfile -File tests/shell/test_vim_name.ps1

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptDir = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'scripts'

# Returns the function's source text. The caller dot-sources it at script
# scope -- dot-sourcing in here would define it in this function's scope only.
function Get-FunctionSource {
    param([string]$Path, [string]$Name)

    $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile(
        $Path, [ref]$null, [ref]$errors)
    if ($errors -and $errors.Count -gt 0) {
        throw "parse errors in ${Path}: $($errors[0].Message)"
    }

    $fn = $ast.Find({
            param($node)
            $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
            $node.Name -eq $Name
        }, $true)
    if (-not $fn) { throw "function $Name not found in $Path" }

    return $fn.Extent.Text
}

$failed = 0

function Expect-Match {
    param([string]$Name)
    if (-not (Test-VimProcessName $Name)) {
        Write-Host "FAIL: expected '$Name' to be treated as Vim"
        $script:failed++
    }
}

function Expect-NoMatch {
    param([string]$Name)
    if (Test-VimProcessName $Name) {
        Write-Host "FAIL: expected '$Name' NOT to be treated as Vim"
        $script:failed++
    }
}

foreach ($psScript in @('herdr-nav.ps1', 'herdr-resize.ps1')) {
    . ([scriptblock]::Create(
            (Get-FunctionSource -Path (Join-Path $scriptDir $psScript) -Name 'Test-VimProcessName')))

    # POSIX-style names.
    'vim', 'nvim', 'view', 'gvim', 'vimdiff', 'gvimdiff', 'nvimdiff' |
        ForEach-Object { Expect-Match $_ }

    # Windows reports szExeFile verbatim, extension included.
    'nvim.exe', 'vim.exe', 'gvim.exe', 'vimdiff.exe', 'NVIM.EXE' |
        ForEach-Object { Expect-Match $_ }

    # A full path can reach us via argv0; the basename is what matters.
    Expect-Match 'C:\tools\neovim\bin\nvim.exe'
    Expect-Match '/usr/bin/nvim'

    # Near misses that must not be mistaken for an editor.
    'bash', 'node', 'pwsh.exe', 'nvimpager', 'vimrc', 'nvim-qt', 'myvim.exe' |
        ForEach-Object { Expect-NoMatch $_ }

    # Degenerate input must not throw.
    Expect-NoMatch ''
    Expect-NoMatch '   '

    if ($failed -eq 0) { Write-Host "ok: $psScript Test-VimProcessName" }
}

if ($failed -gt 0) {
    Write-Host "$failed assertion(s) failed"
    exit 1
}
