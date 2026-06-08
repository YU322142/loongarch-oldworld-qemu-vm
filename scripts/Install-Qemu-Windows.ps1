[CmdletBinding()]
param(
    [string]$Version = "11.0.50",
    [string]$QemuDir,
    [switch]$Latest,
    [switch]$CopyToRepo,
    [switch]$NoCopyToRepo,
    [switch]$ForceInstall
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
$TargetDir = Join-Path $Root "tools\qemu"

function Get-QemuInstall {
    param([string[]]$Directories)

    foreach ($Directory in $Directories) {
        if (-not $Directory) {
            continue
        }

        $SystemExe = Join-Path $Directory "qemu-system-loongarch64.exe"
        $ImgExe = Join-Path $Directory "qemu-img.exe"
        if ((Test-Path -LiteralPath $SystemExe) -and (Test-Path -LiteralPath $ImgExe)) {
            return [pscustomobject]@{
                Directory = (Resolve-Path -LiteralPath $Directory).Path
                SystemExe = (Resolve-Path -LiteralPath $SystemExe).Path
                ImgExe = (Resolve-Path -LiteralPath $ImgExe).Path
            }
        }
    }

    return $null
}

function Search-QemuInstall {
    param([string[]]$SearchRoots)

    foreach ($SearchRoot in $SearchRoots) {
        if (-not $SearchRoot -or -not (Test-Path -LiteralPath $SearchRoot)) {
            continue
        }

        $SystemExe = Get-ChildItem -LiteralPath $SearchRoot -Recurse -Filter "qemu-system-loongarch64.exe" -File -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $SystemExe) {
            continue
        }

        $Directory = Split-Path -Parent $SystemExe.FullName
        $Found = Get-QemuInstall -Directories @($Directory)
        if ($Found) {
            return $Found
        }
    }

    return $null
}

function Resolve-QemuInstall {
    param([string]$RequestedQemuDir, [string]$RootDir)

    $Candidates = @()
    if ($RequestedQemuDir) {
        $Candidates += $RequestedQemuDir
    }

    $Candidates += @(
        (Join-Path $RootDir "tools\qemu"),
        "C:\Program Files\qemu",
        "C:\Program Files (x86)\qemu"
    )

    $Found = Get-QemuInstall -Directories $Candidates
    if ($Found) {
        return $Found
    }

    $Found = Search-QemuInstall -SearchRoots @(
        $RequestedQemuDir,
        (Join-Path $RootDir "tools\qemu")
    )
    if ($Found) {
        return $Found
    }

    $SystemCommand = Get-Command "qemu-system-loongarch64.exe" -ErrorAction SilentlyContinue
    if ($SystemCommand) {
        $Found = Get-QemuInstall -Directories @((Split-Path -Parent $SystemCommand.Source))
        if ($Found) {
            return $Found
        }
    }

    $ImgCommand = Get-Command "qemu-img.exe" -ErrorAction SilentlyContinue
    if ($ImgCommand) {
        $Found = Get-QemuInstall -Directories @((Split-Path -Parent $ImgCommand.Source))
        if ($Found) {
            return $Found
        }
    }

    return $null
}

function Invoke-WingetInstall {
    param(
        [string]$WingetPath,
        [string]$Version,
        [switch]$Latest,
        [string]$Location,
        [switch]$Force
    )

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

    if ($Location) {
        $Args += @("--location", $Location)
    }

    if ($Force) {
        $Args += "--force"
    }

    Write-Host "Installing QEMU with winget..."
    Write-Host "winget $($Args -join ' ')"
    & $WingetPath @Args 2>&1 | ForEach-Object {
        Write-Host $_
    }
    $ExitCode = [int]$LASTEXITCODE
    $global:LASTEXITCODE = 0

    return $ExitCode
}

function Copy-QemuToRepo {
    param([string]$SourceDir, [string]$TargetDir)

    $ResolvedSourceDir = (Resolve-Path -LiteralPath $SourceDir).Path
    $ResolvedTargetDir = if (Test-Path -LiteralPath $TargetDir) {
        (Resolve-Path -LiteralPath $TargetDir).Path
    } else {
        $TargetDir
    }

    if ($ResolvedSourceDir.Equals($ResolvedTargetDir, [System.StringComparison]::OrdinalIgnoreCase)) {
        Write-Host "QEMU is already available in $TargetDir"
        Write-Host "The tools\qemu directory is ignored by Git and excluded from Release packages."
        return
    }

    New-Item -ItemType Directory -Force -Path $TargetDir | Out-Null
    robocopy $ResolvedSourceDir $TargetDir /MIR /NFL /NDL /NJH /NJS /NP | Out-Null

    if ($LASTEXITCODE -ge 8) {
        throw "robocopy failed with exit code $LASTEXITCODE"
    }
    $global:LASTEXITCODE = 0

    Write-Host "Copied QEMU to $TargetDir"
    Write-Host "The tools\qemu directory is ignored by Git and excluded from Release packages."
    Write-Host "Do not commit or redistribute QEMU binaries without satisfying QEMU's license terms."
}

$ShouldCopyToRepo = -not $NoCopyToRepo
if ($CopyToRepo) {
    $ShouldCopyToRepo = $true
}

if ($QemuDir -and -not (Test-Path -LiteralPath $QemuDir)) {
    throw "QEMU directory was not found: $QemuDir"
}

if ($QemuDir) {
    $ResolvedQemuDir = (Resolve-Path -LiteralPath $QemuDir).Path
    if (-not (Test-Path -LiteralPath $ResolvedQemuDir -PathType Container)) {
        $ResolvedQemuDir = Split-Path -Parent $ResolvedQemuDir
    }
    $QemuDir = $ResolvedQemuDir
}

$Existing = Resolve-QemuInstall -RequestedQemuDir $QemuDir -RootDir $Root
if ($Existing -and -not $ForceInstall) {
    Write-Host "Found QEMU: $($Existing.Directory)"
    if ($ShouldCopyToRepo) {
        Copy-QemuToRepo -SourceDir $Existing.Directory -TargetDir $TargetDir
    } else {
        Write-Host "Skipped copying QEMU to tools\qemu because -NoCopyToRepo was specified."
    }
    exit 0
}

$Winget = Get-Command "winget.exe" -ErrorAction SilentlyContinue
if (-not $Winget) {
    if ($QemuDir) {
        throw "QEMU was not valid in $QemuDir, and winget.exe was not found."
    }
    throw "winget.exe was not found. Install Windows Package Manager, install QEMU manually, or pass -QemuDir D:\Path\To\qemu."
}

$WingetLocation = if ($ShouldCopyToRepo) { $TargetDir } else { $null }
if ($WingetLocation) {
    New-Item -ItemType Directory -Force -Path $WingetLocation | Out-Null
}
$ExitCode = Invoke-WingetInstall -WingetPath $Winget.Source -Version $Version -Latest:$Latest -Location $WingetLocation -Force

if ($ExitCode -ne 0 -and $ShouldCopyToRepo -and $WingetLocation) {
    Write-Warning "winget install with --location failed or was not supported. Retrying without --location, then the script will copy QEMU to tools\qemu if it can find it."
    $ExitCode = Invoke-WingetInstall -WingetPath $Winget.Source -Version $Version -Latest:$Latest -Force
}

if ($ExitCode -ne 0) {
    throw "winget install failed with exit code $ExitCode"
}

$Installed = Resolve-QemuInstall -RequestedQemuDir $QemuDir -RootDir $Root
if (-not $Installed) {
    Write-Warning "QEMU was installed or already registered by winget, but qemu-system-loongarch64.exe and qemu-img.exe were not found in tools\qemu, PATH, or common install folders."
    Write-Host ""
    Write-Host "Next steps:"
    Write-Host "  1. If you know the QEMU directory, run:"
    Write-Host "     .\scripts\Install-Qemu-Windows.ps1 -QemuDir D:\Path\To\qemu"
    Write-Host "  2. If winget has stale install metadata, uninstall QEMU from Windows Settings or winget, then run this script again."
    Write-Host "  3. You can also manually unpack/copy QEMU so this file exists:"
    Write-Host "     tools\qemu\qemu-system-loongarch64.exe"
    Write-Host ""
    throw "QEMU executables were not found after installation."
}

Write-Host "Found QEMU: $($Installed.Directory)"
if ($ShouldCopyToRepo) {
    Copy-QemuToRepo -SourceDir $Installed.Directory -TargetDir $TargetDir
} else {
    Write-Host "Skipped copying QEMU to tools\qemu because -NoCopyToRepo was specified."
}
