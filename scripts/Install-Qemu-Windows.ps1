[CmdletBinding()]
param(
    [string]$Version = "11.0.50",
    [switch]$Latest,
    [switch]$CopyToRepo
)

$ErrorActionPreference = "Stop"

$Winget = Get-Command "winget.exe" -ErrorAction SilentlyContinue
if (-not $Winget) {
    throw "winget.exe was not found. Install Windows Package Manager or install QEMU manually."
}

$Args = @(
    "install",
    "-e",
    "--id", "SoftwareFreedomConservancy.QEMU",
    "--accept-package-agreements",
    "--accept-source-agreements"
)

if (-not $Latest -and $Version) {
    $Args += @("--version", $Version)
}

Write-Host "Installing QEMU with winget..."
& $Winget.Source @Args

$Qemu = Get-Command "qemu-system-loongarch64.exe" -ErrorAction SilentlyContinue
if (-not $Qemu) {
    $Known = @(
        "C:\Program Files\qemu\qemu-system-loongarch64.exe",
        "C:\Program Files (x86)\qemu\qemu-system-loongarch64.exe"
    )
    foreach ($Candidate in $Known) {
        if (Test-Path -LiteralPath $Candidate) {
            $Qemu = [pscustomobject]@{ Source = $Candidate }
            break
        }
    }
}

if (-not $Qemu) {
    Write-Warning "QEMU was installed, but qemu-system-loongarch64.exe was not found in PATH or common install folders."
    Write-Warning "Pass -QemuDir to Start-Loongnix-Desktop.ps1 if needed."
    exit 0
}

Write-Host "Found QEMU: $($Qemu.Source)"

if ($CopyToRepo) {
    $Root = Split-Path -Parent $PSScriptRoot
    $SourceDir = Split-Path -Parent $Qemu.Source
    $TargetDir = Join-Path $Root "tools\qemu"

    New-Item -ItemType Directory -Force -Path $TargetDir | Out-Null
    robocopy $SourceDir $TargetDir /MIR /NFL /NDL /NJH /NJS /NP | Out-Null

    if ($LASTEXITCODE -ge 8) {
        throw "robocopy failed with exit code $LASTEXITCODE"
    }

    Write-Host "Copied QEMU to $TargetDir"
    Write-Host "The tools\qemu directory is ignored by Git. Do not commit redistributed QEMU binaries without satisfying QEMU's license terms."
}
