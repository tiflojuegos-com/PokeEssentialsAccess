# Builds prism_pea.dll (x86 + x64), the flat bridge the games' Ruby loads instead of talking to
# prism.dll's handle API directly. Needs: VS with C++ tools + ATL, and a prism checkout already built
# for both arches: its include/, plus a build folder per arch (build_<arch>, or build_<arch>_<name>)
# holding prism.lib. Outputs to bridge/out/<arch>/.
# Usage:  powershell -ExecutionPolicy Bypass -File build_prism_pea.ps1 -PrismRoot <path>
#         (or set PRISM_ROOT and leave -PrismRoot out)
param(
    [string]$PrismRoot = $env:PRISM_ROOT,
    [string]$VcVarsAll = "C:\Program Files\Microsoft Visual Studio\18\Community\VC\Auxiliary\Build\vcvarsall.bat"
)
$ErrorActionPreference = "Stop"
if (-not $PrismRoot) { throw "Indica el checkout de prism con -PrismRoot <ruta> o con la variable PRISM_ROOT" }
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$src = Join-Path $here "prism_pea.c"
$inc = Join-Path $PrismRoot "include"
if (-not (Test-Path $src)) { throw "No encuentro $src" }
if (-not (Test-Path (Join-Path $inc "prism.h"))) { throw "No encuentro prism.h en $inc" }

# The prism build folder for one arch: build_<arch> when it holds prism.lib, else the first build_<arch>_*
# that does.
function Find-PrismBuild([string]$root, [string]$arch) {
    $cands = @(Join-Path $root "build_$arch")
    $cands += @(Get-ChildItem -Directory -Path $root -Filter "build_$($arch)_*" -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName })
    foreach ($c in $cands) { if (Test-Path (Join-Path $c "prism.lib")) { return $c } }
    throw "Falta prism.lib en build_$arch o build_$($arch)_* dentro de $root (compila prism para $arch primero)"
}

foreach ($arch in @("x86", "x64")) {
    $build = Find-PrismBuild $PrismRoot $arch
    $lib = Join-Path $build "prism.lib"
    # prism.h includes prism_version.h, which cmake GENERATES per build directory (it carries the version
    # macros), so the generated include tree has to be on the path beside the checked-in one.
    $gen = Join-Path $build "generated\include"
    if (-not (Test-Path (Join-Path $gen "prism_version.h"))) { throw "Falta $gen\prism_version.h (compila prism para $arch primero)" }
    $out = Join-Path $here "out\$arch"
    New-Item -ItemType Directory -Force $out | Out-Null
    $cmd = "`"$VcVarsAll`" $arch >nul 2>&1 && cl /nologo /LD /O2 /W4 /I`"$inc`" /I`"$gen`" `"$src`" `"$lib`" /Fe:`"$out\prism_pea.dll`" /Fo:`"$out\prism_pea.obj`""
    cmd /c $cmd
    if ($LASTEXITCODE -ne 0) { throw "cl fallo para $arch" }
    Write-Host "[OK] $out\prism_pea.dll"
}
Write-Host "Recuerda: prism_pea.dll necesita prism.dll de su MISMA arquitectura al lado (o en lib/)."