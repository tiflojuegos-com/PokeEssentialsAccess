# Builds prism_pea.dll (x86 + x64), the flat bridge the games' Ruby loads instead of talking to
# prism.dll's handle API directly. Needs: VS with C++ tools + ATL, and a prism checkout already built
# for both arches (its include/ and the prism.lib import libraries). Outputs to bridge/out/<arch>/.
# Usage:  powershell -ExecutionPolicy Bypass -File build_prism_pea.ps1 [-PrismRoot <path>]
param(
    [string]$PrismRoot = "F:\claude\repositorios genericos\prism",
    [string]$VcVarsAll = "C:\Program Files\Microsoft Visual Studio\18\Community\VC\Auxiliary\Build\vcvarsall.bat"
)
$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$src = Join-Path $here "prism_pea.c"
$inc = Join-Path $PrismRoot "include"
if (-not (Test-Path $src)) { throw "No encuentro $src" }
if (-not (Test-Path (Join-Path $inc "prism.h"))) { throw "No encuentro prism.h en $inc" }

foreach ($arch in @("x86", "x64")) {
    $lib = Join-Path $PrismRoot "build_$($arch)_claude\prism.lib"
    if (-not (Test-Path $lib)) { throw "Falta $lib (compila prism para $arch primero)" }
    # prism.h includes prism_version.h, which cmake GENERATES per build directory (it carries the version
    # macros), so the generated include tree has to be on the path beside the checked-in one.
    $gen = Join-Path $PrismRoot "build_$($arch)_claude\generated\include"
    if (-not (Test-Path (Join-Path $gen "prism_version.h"))) { throw "Falta $gen\prism_version.h (compila prism para $arch primero)" }
    $out = Join-Path $here "out\$arch"
    New-Item -ItemType Directory -Force $out | Out-Null
    $cmd = "`"$VcVarsAll`" $arch >nul 2>&1 && cl /nologo /LD /O2 /W4 /I`"$inc`" /I`"$gen`" `"$src`" `"$lib`" /Fe:`"$out\prism_pea.dll`" /Fo:`"$out\prism_pea.obj`""
    cmd /c $cmd
    if ($LASTEXITCODE -ne 0) { throw "cl fallo para $arch" }
    Write-Host "[OK] $out\prism_pea.dll"
}
Write-Host "Recuerda: prism_pea.dll necesita prism.dll de su MISMA arquitectura al lado (o en lib/)."