#!/usr/bin/env pwsh
# Herdr navigation helper (Windows) - port of scripts/herdr-nav.sh.
# That script is the behavioural contract; the two must stay in step.
#
# When a navigation key is pressed in Herdr:
# 1. Check if the focused pane is running Neovim in the foreground.
#    - If yes: forward the key chord into that pane. The Neovim plugin owns
#      in-split movement, edge crossing, and unzoom - do NOT unzoom here, or
#      moving between Neovim splits would incorrectly unzoom the pane.
# 2. If no (a plain Herdr pane): unzoom if needed, then move Herdr pane focus.
#    At a layout edge, focus wraps around to the opposite side (smart-splits
#    style), unless `nav_at_edge=stop`.
#
# Usage: herdr-nav.ps1 <left|down|up|right>

[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0)]
    [ValidateSet('left', 'down', 'up', 'right')]
    [string]$Direction
)

# Deliberately 1.0, not Latest: Herdr omits absent JSON members (for example
# `foreground_processes` when nothing is running), and Latest throws on a
# missing property of a PSCustomObject. 1.0 still catches undefined variables.
Set-StrictMode -Version 1.0
$ErrorActionPreference = 'Continue'
# PowerShell 7.4+ turns a non-zero native exit into a terminating error, which
# would destroy the shell script's `|| true` semantics. We check codes ourselves.
$PSNativeCommandUseErrorActionPreference = $false

$herdr = if ($env:HERDR_BIN_PATH) { $env:HERDR_BIN_PATH } else { 'herdr' }

$spec = @{
    left  = @{ Key = 'ctrl+h'; ConfigKey = 'nav_key_left';  Opposite = 'right' }
    down  = @{ Key = 'ctrl+j'; ConfigKey = 'nav_key_down';  Opposite = 'up'    }
    up    = @{ Key = 'ctrl+k'; ConfigKey = 'nav_key_up';    Opposite = 'down'  }
    right = @{ Key = 'ctrl+l'; ConfigKey = 'nav_key_right'; Opposite = 'left'  }
}[$Direction]

$key       = $spec.Key
$opposite  = $spec.Opposite
$unzoom    = $true
$navAtEdge = 'wrap'

# --- shared conf (the same file the Neovim plugin writes) -----------------
if ($env:HERDR_SPLITS_CONFIG) {
    $configPath = $env:HERDR_SPLITS_CONFIG
} elseif ($env:HERDR_PLUGIN_CONFIG_DIR) {
    $configPath = Join-Path $env:HERDR_PLUGIN_CONFIG_DIR 'herdr-splits.conf'
} elseif ($env:XDG_CONFIG_HOME) {
    $configPath = Join-Path $env:XDG_CONFIG_HOME 'herdr/plugins/config/herdr-splits/herdr-splits.conf'
} else {
    $configPath = Join-Path $env:APPDATA 'herdr/plugins/config/herdr-splits/herdr-splits.conf'
}

if ($configPath -and (Test-Path -LiteralPath $configPath -PathType Leaf)) {
    $keyPattern = '^\s*{0}\s*=\s*([^\s#]+)' -f [regex]::Escape($spec.ConfigKey)
    foreach ($line in Get-Content -LiteralPath $configPath) {
        # Last occurrence wins for the chord, matching the script's `tail -n 1`;
        # the booleans are any-line-matches, matching its `grep -q`.
        if ($line -match $keyPattern) {
            $key = $Matches[1]
        } elseif ($line -match '^\s*unzoom_on_nav\s*=\s*false') {
            $unzoom = $false
        } elseif ($line -match '^\s*nav_at_edge\s*=\s*stop') {
            $navAtEdge = 'stop'
        }
    }
}

# --- helpers (kept in step with the copy in herdr-resize.ps1) -------------
function Invoke-Herdr {
    param([string[]]$HerdrArgs)
    $out = & $herdr @HerdrArgs 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $out) { return $null }
    try { return (($out -join '') | ConvertFrom-Json) } catch { return $null }
}

# Herdr reports PROCESSENTRY32W.szExeFile verbatim on Windows, so the name
# arrives as "nvim.exe". Strip any directory and extension before matching the
# same base-name alternation the shell script uses.
function Test-VimProcessName {
    param([string]$Name)
    if ([string]::IsNullOrWhiteSpace($Name)) { return $false }
    $stem = [System.IO.Path]::GetFileNameWithoutExtension(
        [System.IO.Path]::GetFileName($Name))
    return $stem -match '^(?i:g?(view|l?n?vim?x?)(diff)?)$'
}

function Test-PaneRunsVim {
    $info = Invoke-Herdr @('pane', 'process-info', '--current')
    if (-not $info) { return $false }
    foreach ($proc in @($info.result.process_info.foreground_processes)) {
        if ($proc -and (Test-VimProcessName $proc.name)) { return $true }
    }
    return $false
}

# --- is the focused pane running Neovim? ---------------------------------
# Best-effort: an empty pane id falls through to the non-vim path below,
# which uses --current directly.
$paneId = $null
$current = Invoke-Herdr @('pane', 'current', '--current')
if ($current) { $paneId = $current.result.pane.pane_id }

if ($paneId -and (Test-PaneRunsVim)) {
    # Vim pane: forward the chord; the Neovim plugin decides movement + unzoom.
    & $herdr pane send-keys $paneId $key
    exit $LASTEXITCODE
}

# --- plain Herdr pane: unzoom if needed, then focus (wrapping at edges) ---
$edges        = Invoke-Herdr @('pane', 'edges', '--current')
$edgesTrusted = $true

if ($edges -and $edges.result.edges.layout.zoomed) {
    if ($unzoom) {
        & $herdr pane zoom --off --current 2>$null | Out-Null
        # Layout changed; re-read so the wrap check is accurate.
        $edges = Invoke-Herdr @('pane', 'edges', '--current')
    } else {
        # Still zoomed: the edge flags cannot be trusted, so skip the wrap check.
        $edgesTrusted = $false
    }
}

$atEdge = $false
if ($edges) { $atEdge = [bool]$edges.result.edges.$Direction }

if ($edgesTrusted -and $atEdge) {
    if ($navAtEdge -eq 'stop') { exit 0 }
    & $herdr pane focus --direction $opposite --current
} else {
    & $herdr pane focus --direction $Direction --current
}
exit $LASTEXITCODE
