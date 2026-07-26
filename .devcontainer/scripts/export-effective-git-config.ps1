#!/usr/bin/env pwsh
#Requires -Version 7.0
################################################################################
# Export effective git config for a repository into a portable file.
#
# REQUIREMENTS: PowerShell 7+ (cross-platform)
#   - Windows:  https://github.com/PowerShell/PowerShell/releases
#   - macOS:    brew install powershell
#   - Linux:    https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-linux
#
# IMPORTANT: Run this on the HOST (not inside container) before dev container starts.
#
# Usage:
#   pwsh -NoProfile -File .devcontainer/scripts/export-effective-git-config.ps1 [REPO_PATH] [OUTPUT_FILE]
#
# Defaults:
#   REPO_PATH   = current directory (defaults to two levels up from script)
#   OUTPUT_FILE = .devcontainer/gitconfig.effective
#
# Output format:
#   key<TAB>base64(value)
#   One entry per line. Keys and values are separated by a tab character.
#   Values are base64-encoded to safely preserve special characters and whitespace.
#
# Behavior:
# - Exports all effective git config entries that apply to REPO_PATH.
# - Skips include-related keys: include.path, includeIf.*
#   (These are excluded to prevent circular includes in the container.)
# - Output file is used as a bind mount in devcontainer.json.
# - The mounted file is applied globally in container via apply-global-git-config.sh on startup.
#
# Notes:
# - git's `config list --null` format separates entries with NUL and, within
#   each entry, separates the key from the value with a line feed (not '=').
#   See `git help config` under "--null". This script parses that format
#   directly instead of relying on the human-readable 'key=value' output.
################################################################################

param(
    [string]$RepoPath = (Join-Path $PSScriptRoot '..' '..'),
    [string]$OutputFile = (Join-Path $RepoPath '.devcontainer' 'gitconfig.effective')
)

$ErrorActionPreference = 'Stop'

# Verify git is available
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Error "Error: git is required but not found in PATH." -ErrorAction Stop
}

# Verify repository path exists
if (-not (Test-Path -Path $RepoPath -PathType Container)) {
    Write-Error "Error: repository path does not exist: $RepoPath" -ErrorAction Stop
}

# Verify it's a git repository
$gitCheck = & git -C $RepoPath rev-parse --is-inside-work-tree 2>$null
if (-not $gitCheck) {
    Write-Error "Error: path is not a git work tree: $RepoPath" -ErrorAction Stop
}

# Create output directory
$OutputDir = Split-Path -Path $OutputFile -Parent
if (-not (Test-Path -Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

# Clear output file
Set-Content -Path $OutputFile -Value $null

function Should-Skip {
    param([string]$Key)
    
    if ($Key -eq 'include.path') { return $true }
    if ($Key -match '^includeIf\.') { return $true }
    
    return $false
}

$skippedCount = 0
$exportedCount = 0

# Capture git's NUL-delimited config list. PowerShell's native command capture
# returns one array element per line (splitting on LF/CRLF) and strips the
# line-ending characters in the process, so rejoin with "`n" to restore the
# line feeds that git uses to separate each entry's key from its value.
$rawLines = & git -C $RepoPath config list --null
$configText = ($rawLines -join "`n")

# Split into NUL-delimited entries; each entry is "key`nvalue".
$entries = $configText -split [char]0 | Where-Object { $_.Length -gt 0 }

foreach ($entry in $entries) {
    if (-not $entry) { continue }

    # First line is the key, the rest (if any) is the value.
    $lfIndex = $entry.IndexOf("`n")
    if ($lfIndex -lt 0) { continue }

    $key = $entry.Substring(0, $lfIndex)
    $value = $entry.Substring($lfIndex + 1)

    # Guard against malformed rows
    if (-not $key -or -not $value) { continue }

    if (Should-Skip $key) {
        $skippedCount++
        continue
    }

    # Base64 encode the value
    $valueBytes = [System.Text.Encoding]::UTF8.GetBytes($value)
    $valueB64 = [Convert]::ToBase64String($valueBytes)

    # Write to output file
    "$key`t$valueB64" | Add-Content -Path $OutputFile
    $exportedCount++
}

Write-Host "Export complete."
Write-Host "  Repo:       $RepoPath"
Write-Host "  Output:     $OutputFile"
Write-Host "  Exported:   $exportedCount"
Write-Host "  Skipped:    $skippedCount"

