[CmdletBinding()]
param(
    [ValidateSet("sdl", "gtk")]
    [string]$Display = "sdl",

    [ValidateRange(1, 24)]
    [int]$Cores = 6,

    [ValidateRange(1024, 24576)]
    [int]$MemoryMB = 6144,

    [ValidateRange(1024, 65535)]
    [int]$SshPort = 2222,

    [ValidateSet("dsound", "sdl", "none")]
    [string]$Audio = "dsound",

    [string]$QemuDir,
    [string]$DiskPath,
    [string]$SharePath,

    [switch]$NoHostShare,
    [switch]$Snapshot,
    [switch]$NoAudio,
    [switch]$UseMaxCpu,
    [switch]$NoWait
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

function Resolve-QemuExe {
    param([string]$RequestedQemuDir, [string]$Root)

    $Candidates = @()
    if ($RequestedQemuDir) {
        $Candidates += (Join-Path $RequestedQemuDir "qemu-system-loongarch64.exe")
    }

    $Candidates += @(
        (Join-Path $Root "tools\qemu\qemu-system-loongarch64.exe"),
        "C:\Program Files\qemu\qemu-system-loongarch64.exe",
        "C:\Program Files (x86)\qemu\qemu-system-loongarch64.exe"
    )

    $Found = Get-ExistingPath -Candidates $Candidates
    if ($Found) {
        return $Found
    }

    $Command = Get-Command "qemu-system-loongarch64.exe" -ErrorAction SilentlyContinue
    if ($Command) {
        return $Command.Source
    }

    throw "qemu-system-loongarch64.exe was not found. Run scripts\Install-Qemu-Windows.ps1, copy QEMU to tools\qemu, or pass -QemuDir."
}

$Root = Split-Path -Parent $PSScriptRoot
$Qemu = Resolve-QemuExe -RequestedQemuDir $QemuDir -Root $Root
$QemuHome = Split-Path -Parent $Qemu

$Disk = if ($DiskPath) {
    if (-not (Test-Path -LiteralPath $DiskPath)) { throw "Disk image not found: $DiskPath" }
    (Resolve-Path -LiteralPath $DiskPath).Path
} else {
    Join-Path $Root "images\loongnix-abi1-work.qcow2"
}

$Logs = Join-Path $Root "logs"
$ShareDir = if ($SharePath) { $SharePath } else { Join-Path $Root "shared" }
$QemuShare = Join-Path $QemuHome "share"
$CodeFd = Join-Path $QemuShare "edk2-loongarch64-code.fd"
$VarsTemplate = Join-Path $QemuShare "edk2-loongarch64-vars.fd"
$VarsFd = Join-Path $Root "firmware\edk2-loongarch64-vars-work.fd"

foreach ($Path in @($Qemu, $Disk, $CodeFd, $VarsTemplate)) {
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Missing required file: $Path"
    }
}

New-Item -ItemType Directory -Force -Path $Logs, $ShareDir, (Split-Path -Parent $VarsFd) | Out-Null

if (-not (Test-Path -LiteralPath $VarsFd)) {
    Copy-Item -LiteralPath $VarsTemplate -Destination $VarsFd
}

$SerialLog = Join-Path $Logs ("serial-{0:yyyyMMdd-HHmmss}.log" -f (Get-Date))
$Cpu = if ($UseMaxCpu) { "max" } else { "la464" }
$DisplayArg = if ($Display -eq "gtk") { "gtk,gl=off,clipboard=on" } else { "sdl,gl=off,show-cursor=on" }
$EnableAudio = (-not $NoAudio -and $Audio -ne "none")
$EnableHostShare = (-not $NoHostShare)

$Args = @(
    "-name", "LoongArch-OldWorld-ABI1-X11",
    "-L", $QemuShare,
    "-machine", "virt",
    "-cpu", $Cpu,
    "-accel", "tcg,thread=multi,tb-size=1024",
    "-smp", "$Cores",
    "-m", "$MemoryMB",
    "-display", $DisplayArg,
    "-device", "virtio-gpu-pci",
    "-device", "qemu-xhci",
    "-device", "usb-kbd",
    "-device", "usb-tablet",
    "-drive", "if=pflash,format=raw,readonly=on,file=$CodeFd",
    "-drive", "if=pflash,format=raw,file=$VarsFd",
    "-drive", "if=none,id=system,format=qcow2,file=$Disk,cache=writeback,aio=threads,discard=unmap",
    "-device", "virtio-blk-pci,drive=system,bootindex=0",
    "-netdev", "user,id=net0,hostfwd=tcp:127.0.0.1:$SshPort-:22",
    "-device", "virtio-net-pci,netdev=net0",
    "-device", "virtio-rng-pci",
    "-boot", "order=c,menu=on",
    "-serial", "file:$SerialLog",
    "-monitor", "none"
)

if ($EnableAudio) {
    $Args += @(
        "-audiodev", "$Audio,id=audio0",
        "-device", "intel-hda",
        "-device", "hda-duplex,audiodev=audio0"
    )
}

if ($EnableHostShare) {
    $QemuSharePath = $ShareDir.Replace("\", "/")
    $Args += @(
        "-drive", "if=none,id=hostshare,format=raw,media=disk,file=fat:rw:$QemuSharePath",
        "-device", "virtio-blk-pci,drive=hostshare"
    )
}

if ($Snapshot) {
    $Args += "-snapshot"
}

$ArgLog = Join-Path $Logs "last-qemu-args.txt"
$Args | Set-Content -LiteralPath $ArgLog -Encoding ASCII

Write-Host "Starting visible LoongArch old-world ABI1.0 X11 VM..."
Write-Host "QEMU: $Qemu"
Write-Host "Disk: $Disk"
Write-Host "Display: $DisplayArg"
Write-Host "CPU/RAM: $Cores cores, $MemoryMB MB, cpu=$Cpu"
if ($EnableAudio) {
    Write-Host "Audio: $Audio + Intel HDA duplex"
} else {
    Write-Host "Audio: disabled"
}
Write-Host "SSH forward: 127.0.0.1:$SshPort -> guest:22"
if ($EnableHostShare) {
    Write-Host "Host share: $ShareDir"
} else {
    Write-Host "Host share: disabled"
}
Write-Host "Serial log: $SerialLog"
Write-Host "PowerShell waits while the QEMU window is open. Close the QEMU window to return to the prompt, or start with -NoWait."
Write-Host "The serial log may stop updating after GRUB hands off to Linux; continue by watching the visible QEMU window."
Write-Host "During boot, keep the mouse pointer outside the QEMU window while the guest screen is blank or has no stable image."
Write-Host "After LightDM or the desktop is visible, adjust the window only if needed and re-check mouse click alignment."
Write-Host ""

$Process = Start-Process -FilePath $Qemu -ArgumentList $Args -PassThru
Start-Sleep -Milliseconds 800
try {
    $Process.PriorityClass = "AboveNormal"
} catch {
    Write-Warning "Could not raise QEMU priority: $($_.Exception.Message)"
}

if ($NoWait) {
    Write-Host "QEMU started with process id $($Process.Id). Not waiting because -NoWait was specified."
    return
}

Wait-Process -Id $Process.Id
exit $Process.ExitCode
