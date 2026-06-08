[CmdletBinding()]
param(
    [string]$ImageUrl = "https://pkg.loongnix.cn/loongnix/isos/Loongnix-20.7.rc1/Loongnix-20.7.rc1.kde.mini.loongarch64.en.qcow2",
    [string]$ExpectedMd5 = "3ca44ded43023602deafaad416756cf7",
    [string]$ExpectedSha256 = "c960ce8718ce7c8fecd442059ba845b9edc9f0abf90e930b04711f109bf6737c",
    [string]$QemuDir,
    [switch]$Force,
    [switch]$SkipWorkDisk,
    [switch]$FullCopyWorkDisk
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

function Save-File {
    param([string]$Uri, [string]$Destination, [switch]$Overwrite)

    if ((Test-Path -LiteralPath $Destination) -and -not $Overwrite) {
        Write-Host "Already exists: $Destination"
        return
    }

    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Destination) | Out-Null

    $Bits = Get-Command "Start-BitsTransfer" -ErrorAction SilentlyContinue
    if ($Bits) {
        Start-BitsTransfer -Source $Uri -Destination $Destination
    } else {
        Invoke-WebRequest -Uri $Uri -OutFile $Destination
    }
}

function Resolve-QemuImg {
    param([string]$RequestedQemuDir, [string]$Root)

    $Candidates = @()
    if ($RequestedQemuDir) {
        $Candidates += (Join-Path $RequestedQemuDir "qemu-img.exe")
    }

    $Candidates += @(
        (Join-Path $Root "tools\qemu\qemu-img.exe"),
        "C:\Program Files\qemu\qemu-img.exe",
        "C:\Program Files (x86)\qemu\qemu-img.exe"
    )

    $Found = Get-ExistingPath -Candidates $Candidates
    if ($Found) {
        return $Found
    }

    $Command = Get-Command "qemu-img.exe" -ErrorAction SilentlyContinue
    if ($Command) {
        return $Command.Source
    }

    $SystemCandidates = @()
    if ($RequestedQemuDir) {
        $SystemCandidates += (Join-Path $RequestedQemuDir "qemu-system-loongarch64.exe")
    }
    $SystemCandidates += @(
        (Join-Path $Root "tools\qemu\qemu-system-loongarch64.exe"),
        "C:\Program Files\qemu\qemu-system-loongarch64.exe",
        "C:\Program Files (x86)\qemu\qemu-system-loongarch64.exe"
    )

    $QemuSystem = Get-ExistingPath -Candidates $SystemCandidates
    if (-not $QemuSystem) {
        $SystemCommand = Get-Command "qemu-system-loongarch64.exe" -ErrorAction SilentlyContinue
        if ($SystemCommand) {
            $QemuSystem = $SystemCommand.Source
        }
    }

    if ($QemuSystem) {
        $Sibling = Join-Path (Split-Path -Parent $QemuSystem) "qemu-img.exe"
        if (Test-Path -LiteralPath $Sibling) {
            return (Resolve-Path -LiteralPath $Sibling).Path
        }
    }

    return $null
}

$Root = Split-Path -Parent $PSScriptRoot
$Images = Join-Path $Root "images"
$ImageName = Split-Path -Leaf $ImageUrl
$Base = Join-Path $Images $ImageName
$Work = Join-Path $Images "loongnix-abi1-work.qcow2"

New-Item -ItemType Directory -Force -Path $Images | Out-Null

Save-File -Uri $ImageUrl -Destination $Base -Overwrite:$Force

$Md5 = (Get-FileHash -Algorithm MD5 -LiteralPath $Base).Hash.ToLowerInvariant()
$Sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $Base).Hash.ToLowerInvariant()

if ($ExpectedMd5 -and $Md5 -ne $ExpectedMd5.ToLowerInvariant()) {
    throw "MD5 mismatch for $Base. Expected $ExpectedMd5, got $Md5."
}

if ($ExpectedSha256 -and $Sha256 -ne $ExpectedSha256.ToLowerInvariant()) {
    throw "SHA256 mismatch for $Base. Expected $ExpectedSha256, got $Sha256."
}

"$Md5  $ImageName" | Set-Content -LiteralPath "$Base.md5" -Encoding ASCII
"$Sha256  $ImageName" | Set-Content -LiteralPath "$Base.sha256" -Encoding ASCII

Write-Host "Verified image:"
Write-Host "  MD5    $Md5"
Write-Host "  SHA256 $Sha256"

if ($SkipWorkDisk) {
    exit 0
}

$QemuImg = Resolve-QemuImg -RequestedQemuDir $QemuDir -Root $Root

if (-not $QemuImg) {
    Write-Warning "The Loongnix image was downloaded and verified, but the writable work disk was not created because qemu-img.exe was not found."
    Write-Host ""
    Write-Host "Image file:"
    Write-Host "  $Base"
    Write-Host ""
    Write-Host "Next steps:"
    Write-Host "  1. Install QEMU, then run this script again:"
    Write-Host "     .\scripts\Install-Qemu-Windows.ps1"
    Write-Host "     .\scripts\Download-LoongnixImage.ps1"
    Write-Host "  2. If QEMU is already installed elsewhere, pass its directory:"
    Write-Host "     .\scripts\Download-LoongnixImage.ps1 -QemuDir D:\Path\To\qemu"
    Write-Host "  3. If you only wanted to download and verify the image:"
    Write-Host "     .\scripts\Download-LoongnixImage.ps1 -SkipWorkDisk"
    Write-Host ""
    throw "qemu-img.exe was not found; no work disk was created."
}

if ((Test-Path -LiteralPath $Work) -and -not $Force) {
    Write-Host "Work disk already exists: $Work"
    Write-Host "Use -Force to recreate it."
    exit 0
}

Remove-Item -LiteralPath $Work -Force -ErrorAction SilentlyContinue
if ($FullCopyWorkDisk) {
    & $QemuImg convert -p -f qcow2 -O qcow2 -o compat=1.1,lazy_refcounts=on,preallocation=metadata $Base $Work
} else {
    & $QemuImg create -f qcow2 -F qcow2 -b $Base $Work
}

& $QemuImg info $Work
