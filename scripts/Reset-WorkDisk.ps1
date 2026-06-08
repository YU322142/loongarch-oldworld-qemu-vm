[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$Force,
    [switch]$ResetFirmwareVars,
    [switch]$FullCopy,
    [string]$QemuDir
)

$ErrorActionPreference = "Stop"

function Get-ExistingPath {
    param([string[]]$Candidates)
    foreach ($Candidate in $Candidates) {
        if ($Candidate -and (Test-Path -LiteralPath $Candidate)) {
            return (Resolve-Path -LiteralPath $Candidate).Path
        }
    }
    return $null
}

$Root = Split-Path -Parent $PSScriptRoot
$QemuImg = Get-ExistingPath -Candidates @(
    $(if ($QemuDir) { Join-Path $QemuDir "qemu-img.exe" }),
    (Join-Path $Root "tools\qemu\qemu-img.exe"),
    "C:\Program Files\qemu\qemu-img.exe",
    "C:\Program Files (x86)\qemu\qemu-img.exe"
)

if (-not $QemuImg) {
    $Command = Get-Command "qemu-img.exe" -ErrorAction SilentlyContinue
    if ($Command) { $QemuImg = $Command.Source }
}

if (-not $QemuImg) {
    throw "qemu-img.exe was not found. Install QEMU or pass -QemuDir."
}

$Base = Join-Path $Root "images\Loongnix-20.7.rc1.kde.mini.loongarch64.en.qcow2"
$Work = Join-Path $Root "images\loongnix-abi1-work.qcow2"
$QemuHome = Split-Path -Parent $QemuImg
$VarsTemplate = Join-Path $QemuHome "share\edk2-loongarch64-vars.fd"
$VarsFd = Join-Path $Root "firmware\edk2-loongarch64-vars-work.fd"

foreach ($Path in @($QemuImg, $Base)) {
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Missing required file: $Path"
    }
}

if (-not $Force) {
    Write-Host "This will replace the writable work disk:"
    Write-Host "  $Work"
    Write-Host "Run again with -Force to continue."
    exit 2
}

$QemuProcesses = Get-Process -Name "qemu-system-loongarch64" -ErrorAction SilentlyContinue
if ($QemuProcesses) {
    throw "A LoongArch QEMU process is running. Shut it down before resetting the work disk."
}

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Work), (Split-Path -Parent $VarsFd) | Out-Null

if ($PSCmdlet.ShouldProcess($Work, "reset from clean Loongnix base image")) {
    Remove-Item -LiteralPath $Work -Force -ErrorAction SilentlyContinue
    if ($FullCopy) {
        & $QemuImg convert -p -f qcow2 -O qcow2 -o compat=1.1,lazy_refcounts=on,preallocation=metadata $Base $Work
    } else {
        & $QemuImg create -f qcow2 -F qcow2 -b $Base $Work
    }
}

if ($ResetFirmwareVars) {
    if (-not (Test-Path -LiteralPath $VarsTemplate)) {
        throw "Missing firmware variable template: $VarsTemplate"
    }
    Copy-Item -LiteralPath $VarsTemplate -Destination $VarsFd -Force
}

& $QemuImg info $Work
