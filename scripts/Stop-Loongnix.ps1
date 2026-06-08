[CmdletBinding()]
param(
    [string]$QemuDir
)

$Root = Split-Path -Parent $PSScriptRoot
$Candidates = @()

if ($QemuDir) {
    $Candidates += (Join-Path $QemuDir "qemu-system-loongarch64.exe")
}

$Candidates += @(
    (Join-Path $Root "tools\qemu\qemu-system-loongarch64.exe"),
    "C:\Program Files\qemu\qemu-system-loongarch64.exe",
    "C:\Program Files (x86)\qemu\qemu-system-loongarch64.exe"
)

$ResolvedCandidates = @()
foreach ($Candidate in $Candidates) {
    if ($Candidate -and (Test-Path -LiteralPath $Candidate)) {
        $ResolvedCandidates += (Resolve-Path -LiteralPath $Candidate).Path
    }
}

$Processes = Get-Process -Name "qemu-system-loongarch64" -ErrorAction SilentlyContinue
if ($ResolvedCandidates) {
    $Processes = $Processes | Where-Object { $ResolvedCandidates -contains $_.Path }
}

if (-not $Processes) {
    Write-Host "No matching LoongArch QEMU process is running."
    exit 0
}

$Processes | Stop-Process -Force
Write-Host "Stopped $($Processes.Count) LoongArch QEMU process(es)."
