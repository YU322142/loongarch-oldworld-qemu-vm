[CmdletBinding()]
param(
    [string]$ImageUrl = "https://pkg.loongnix.cn/loongnix/isos/Loongnix-20.7.rc1/Loongnix-20.7.rc1.kde.mini.loongarch64.en.qcow2",
    [string]$ExpectedMd5 = "3ca44ded43023602deafaad416756cf7",
    [string]$ExpectedSha256 = "c960ce8718ce7c8fecd442059ba845b9edc9f0abf90e930b04711f109bf6737c",
    [string]$QemuDir,
    [ValidateRange(1, 64)]
    [int]$Connections = 64,
    [ValidateRange(0, 10)]
    [int]$DownloadRetries = 3,
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

function Save-FileSingle {
    param([string]$Uri, [string]$Destination)

    $Bits = Get-Command "Start-BitsTransfer" -ErrorAction SilentlyContinue
    if ($Bits) {
        Write-Host "Downloading with BITS fallback..."
        Start-BitsTransfer -Source $Uri -Destination $Destination
    } else {
        Write-Host "Downloading with Invoke-WebRequest fallback..."
        Invoke-WebRequest -Uri $Uri -OutFile $Destination -UseBasicParsing
    }
}

function Get-RemoteRangeInfo {
    param([string]$Uri)

    try {
        $Request = [System.Net.HttpWebRequest]::Create($Uri)
        $Request.Method = "GET"
        $Request.AddRange([int64]0, [int64]0)
        $Response = $Request.GetResponse()
        try {
            $ContentRange = [string]$Response.Headers["Content-Range"]
            if ([int]$Response.StatusCode -eq 206 -and $ContentRange -match "/(\d+)$") {
                return [PSCustomObject]@{
                    SupportsRanges = $true
                    Length = [int64]$Matches[1]
                }
            }
        } finally {
            $Response.Close()
        }
    } catch {
        Write-Verbose "Range probe failed: $($_.Exception.Message)"
    }

    try {
        $Request = [System.Net.HttpWebRequest]::Create($Uri)
        $Request.Method = "HEAD"
        $Response = $Request.GetResponse()
        try {
            if ($Response.ContentLength -gt 0) {
                return [PSCustomObject]@{
                    SupportsRanges = $false
                    Length = [int64]$Response.ContentLength
                }
            }

            $ContentLength = [string]$Response.Headers["Content-Length"]
            if ($ContentLength -match "^\d+$") {
                return [PSCustomObject]@{
                    SupportsRanges = $false
                    Length = [int64]$ContentLength
                }
            }
        } finally {
            $Response.Close()
        }
    } catch {
        Write-Verbose "HEAD probe failed: $($_.Exception.Message)"
    }

    return [PSCustomObject]@{
        SupportsRanges = $false
        Length = 0
    }
}

function Save-FileParallel {
    param(
        [string]$Uri,
        [string]$Destination,
        [int]$Connections,
        [int]$Retries,
        [int64]$Length
    )

    $TempFile = "$Destination.download"
    $PartDir = "$Destination.parts"
    Remove-Item -LiteralPath $TempFile -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $PartDir -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Force -Path $PartDir | Out-Null

    $ChunkSize = [int64][Math]::Ceiling($Length / [double]$Connections)
    $Ranges = @()
    for ($Index = 0; $Index -lt $Connections; $Index++) {
        $Start = [int64]($Index * $ChunkSize)
        if ($Start -ge $Length) {
            break
        }

        $End = [Math]::Min($Start + $ChunkSize - 1, $Length - 1)
        $Ranges += [PSCustomObject]@{
            Index = $Index
            Start = $Start
            End = [int64]$End
            Path = Join-Path $PartDir ("{0:D3}.part" -f $Index)
        }
    }

    Write-Host ("Downloading with {0} parallel range requests ({1:N0} bytes)..." -f $Ranges.Count, $Length)

    $Jobs = foreach ($Range in $Ranges) {
        Start-Job -ArgumentList $Uri, $Range.Path, $Range.Start, $Range.End, $Retries -ScriptBlock {
            param($Uri, $PartPath, [int64]$Start, [int64]$End, [int]$Retries)

            $ProgressPreference = "SilentlyContinue"
            $ExpectedLength = $End - $Start + 1
            Remove-Item -LiteralPath $PartPath -Force -ErrorAction SilentlyContinue

            $Attempt = 0
            $LastLength = 0
            while ($true) {
                try {
                    $ExistingLength = 0
                    if (Test-Path -LiteralPath $PartPath) {
                        $ExistingLength = (Get-Item -LiteralPath $PartPath).Length
                    }

                    if ($ExistingLength -eq $ExpectedLength) {
                        return [PSCustomObject]@{
                            Path = $PartPath
                            Bytes = $ExistingLength
                        }
                    }

                    if ($ExistingLength -gt $ExpectedLength) {
                        throw "Part length mismatch for $PartPath. Expected at most $ExpectedLength, got $ExistingLength."
                    }

                    $RequestStart = $Start + $ExistingLength

                    $Request = [System.Net.HttpWebRequest]::Create($Uri)
                    $Request.Method = "GET"
                    $Request.AddRange($RequestStart, $End)
                    $Response = $Request.GetResponse()
                    try {
                        if ([int]$Response.StatusCode -ne 206) {
                            throw "Server returned HTTP $([int]$Response.StatusCode) for range $RequestStart-$End."
                        }

                        $InputStream = $Response.GetResponseStream()
                        $OutputStream = [System.IO.File]::Open($PartPath, [System.IO.FileMode]::Append, [System.IO.FileAccess]::Write)
                        try {
                            $InputStream.CopyTo($OutputStream)
                        } finally {
                            $OutputStream.Dispose()
                            $InputStream.Dispose()
                        }
                    } finally {
                        $Response.Close()
                    }

                    $ActualLength = (Get-Item -LiteralPath $PartPath).Length
                    if ($ActualLength -lt $ExpectedLength) {
                        if ($ActualLength -gt $LastLength) {
                            $Attempt = 0
                            $LastLength = $ActualLength
                        } else {
                            if ($Attempt -ge $Retries) {
                                throw "Part download made no progress for $PartPath. Expected $ExpectedLength, got $ActualLength."
                            }

                            Start-Sleep -Seconds ([Math]::Min(30, [Math]::Pow(2, $Attempt)))
                            $Attempt++
                        }

                        continue
                    }

                    if ($ActualLength -gt $ExpectedLength) {
                        throw "Part length mismatch for $PartPath. Expected $ExpectedLength, got $ActualLength."
                    }

                    return [PSCustomObject]@{
                        Path = $PartPath
                        Bytes = $ActualLength
                    }
                } catch {
                    if ($Attempt -ge $Retries) {
                        throw
                    }

                    Start-Sleep -Seconds ([Math]::Min(30, [Math]::Pow(2, $Attempt)))
                    $Attempt++
                }
            }
        }
    }

    try {
        while (($Jobs | Where-Object { $_.State -eq "Running" -or $_.State -eq "NotStarted" }).Count -gt 0) {
            $Downloaded = 0
            Get-ChildItem -LiteralPath $PartDir -Filter "*.part" -ErrorAction SilentlyContinue | ForEach-Object {
                $Downloaded += $_.Length
            }

            $Percent = [Math]::Min(100, [Math]::Floor(($Downloaded / [double]$Length) * 100))
            Write-Progress -Activity "Downloading Loongnix image" -Status ("{0:N0} / {1:N0} bytes" -f $Downloaded, $Length) -PercentComplete $Percent
            Start-Sleep -Milliseconds 500
        }

        Write-Progress -Activity "Downloading Loongnix image" -Completed
        foreach ($Job in $Jobs) {
            Receive-Job -Job $Job -ErrorAction Stop | Out-Null
        }

        $Output = [System.IO.File]::Open($TempFile, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write)
        try {
            foreach ($Range in ($Ranges | Sort-Object Index)) {
                $Input = [System.IO.File]::OpenRead($Range.Path)
                try {
                    $Input.CopyTo($Output)
                } finally {
                    $Input.Dispose()
                }
            }
        } finally {
            $Output.Dispose()
        }

        $Actual = (Get-Item -LiteralPath $TempFile).Length
        if ($Actual -ne $Length) {
            throw "Downloaded file size mismatch. Expected $Length, got $Actual."
        }

        Move-Item -LiteralPath $TempFile -Destination $Destination -Force
    } finally {
        Write-Progress -Activity "Downloading Loongnix image" -Completed
        $Jobs | Remove-Job -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $PartDir -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $TempFile -Force -ErrorAction SilentlyContinue
    }
}

function Save-File {
    param(
        [string]$Uri,
        [string]$Destination,
        [switch]$Overwrite,
        [int]$Connections,
        [int]$Retries
    )

    if ((Test-Path -LiteralPath $Destination) -and -not $Overwrite) {
        Write-Host "Already exists: $Destination"
        return
    }

    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Destination) | Out-Null
    Remove-Item -LiteralPath $Destination -Force -ErrorAction SilentlyContinue

    $RangeInfo = Get-RemoteRangeInfo -Uri $Uri
    if ($Connections -gt 1 -and $RangeInfo.SupportsRanges -and $RangeInfo.Length -gt 0) {
        Save-FileParallel -Uri $Uri -Destination $Destination -Connections $Connections -Retries $Retries -Length $RangeInfo.Length
    } else {
        if ($Connections -gt 1) {
            Write-Warning "The server did not report HTTP Range support; falling back to single-connection download."
        }

        Save-FileSingle -Uri $Uri -Destination $Destination
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

Save-File -Uri $ImageUrl -Destination $Base -Overwrite:$Force -Connections $Connections -Retries $DownloadRetries

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
