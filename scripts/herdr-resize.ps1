#!/usr/bin/env pwsh
# Herdr resize helper (Windows) - port of scripts/herdr-resize.sh.
# That script is the behavioural contract; the two must stay in step.
#
# When a resize key (alt+h/j/k/l) is pressed in Herdr:
# 1. Check if the focused pane is running Neovim in the foreground
# 2. If yes: forward the key chord into that pane (Neovim's plugin handles it)
# 3. If no: resize the Herdr pane directly
#
# Zoom state is left untouched (matches smart-splits.nvim's
# disable_multiplexer_nav_when_zoomed default).
#
# Usage: herdr-resize.ps1 <left|down|up|right> [amount]

[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0)]
    [ValidateSet('left', 'down', 'up', 'right')]
    [string]$Direction,

    [Parameter(Position = 1)]
    [string]$Amount = '0.03'
)

# See herdr-nav.ps1 for why this is 1.0 rather than Latest.
Set-StrictMode -Version 1.0
$ErrorActionPreference = 'Continue'
$PSNativeCommandUseErrorActionPreference = $false

$herdr = if ($env:HERDR_BIN_PATH) { $env:HERDR_BIN_PATH } else { 'herdr' }

$spec = @{
    left  = @{ Key = 'alt+h'; ConfigKey = 'resize_key_left'  }
    down  = @{ Key = 'alt+j'; ConfigKey = 'resize_key_down'  }
    up    = @{ Key = 'alt+k'; ConfigKey = 'resize_key_up'    }
    right = @{ Key = 'alt+l'; ConfigKey = 'resize_key_right' }
}[$Direction]

$key = $spec.Key

# --- shared conf (chord override only; no unzoom/nav_at_edge here) --------
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
        # Last occurrence wins, matching the shell script's `tail -n 1`.
        if ($line -match $keyPattern) { $key = $Matches[1] }
    }
}

# --- helpers (kept in step with the copy in herdr-nav.ps1) ----------------
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

# --- resize, or hand the chord to Neovim ---------------------------------
$paneId = $null
$current = Invoke-Herdr @('pane', 'current', '--current')
if ($current) { $paneId = $current.result.pane.pane_id }

if ($paneId -and (Test-PaneRunsVim)) {
    & $herdr pane send-keys $paneId $key
} else {
    & $herdr pane resize --direction $Direction --amount $Amount --current
}
exit $LASTEXITCODE
