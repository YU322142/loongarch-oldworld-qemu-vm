[CmdletBinding()]
param(
    [string]$Version = ("qemu-vm-{0:yyyyMMdd}" -f (Get-Date)),
    [string]$OutDir
)

$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
if (-not $OutDir) {
    $OutDir = Join-Path $Root "dist"
}

$Stage = Join-Path $OutDir "stage-$Version"
$Zip = Join-Path $OutDir "loongarch-oldworld-$Version.zip"

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
Remove-Item -LiteralPath $Stage -Recurse -Force -ErrorAction SilentlyContinue
Get-ChildItem -LiteralPath $OutDir -Filter "loongarch-oldworld-*.zip" -ErrorAction SilentlyContinue | Remove-Item -Force
New-Item -ItemType Directory -Force -Path $Stage | Out-Null

$ExcludedPrefixes = @(
    ".git\",
    "dist\",
    "tmp\",
    "tools\qemu\"
)

$ExcludedExact = @(
    ".git"
)

$Files = Get-ChildItem -LiteralPath $Root -Recurse -File -Force | Where-Object {
    $Relative = $_.FullName.Substring($Root.Length + 1)
    $Normalized = $Relative.Replace("/", "\")

    if ($ExcludedExact -contains $Normalized) {
        return $false
    }

    foreach ($Prefix in $ExcludedPrefixes) {
        if ($Normalized.StartsWith($Prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
            return $false
        }
    }

    if ($Normalized.StartsWith("images\", [System.StringComparison]::OrdinalIgnoreCase)) {
        return ($Normalized -eq "images\README.md")
    }

    if ($Normalized.StartsWith("shared\", [System.StringComparison]::OrdinalIgnoreCase)) {
        return ($Normalized -eq "shared\README.md" -or $Normalized -eq "shared\setup-loongnix-test-desktop.sh" -or $Normalized -eq "shared\pic.png")
    }

    if ($Normalized.StartsWith("logs\", [System.StringComparison]::OrdinalIgnoreCase)) {
        return ($Normalized -eq "logs\README.md")
    }

    if ($Normalized.StartsWith("firmware\", [System.StringComparison]::OrdinalIgnoreCase)) {
        return ($Normalized -eq "firmware\README.md")
    }

    return $true
}

foreach ($File in $Files) {
    $Relative = $File.FullName.Substring($Root.Length + 1)
    $Target = Join-Path $Stage $Relative
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Target) | Out-Null
    Copy-Item -LiteralPath $File.FullName -Destination $Target
}

$Manifest = @"
Package: loongarch-oldworld-qemu-vm
Version: $Version
Generated: $(Get-Date -Format o)

This package contains launcher scripts and documentation only.
It intentionally excludes:
- QEMU binaries and firmware
- Loongnix qcow2 images
- writable VM work disks
- user test packages in shared/; the tracked guest setup helper and default wallpaper are included
- logs and screenshots

Fetch third-party assets with scripts/Install-Qemu-Windows.ps1 and scripts/Download-LoongnixImage.ps1.
"@

$Manifest | Set-Content -LiteralPath (Join-Path $Stage "PACKAGE-MANIFEST.txt") -Encoding UTF8

Compress-Archive -Path (Join-Path $Stage "*") -DestinationPath $Zip -Force
Write-Host $Zip
