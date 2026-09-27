# Builds prism_pea.dll (x86 + x64), the flat C bridge the games' Ruby loads over prism.dll. Needs VS with C++
# tools and ATL, and a prism checkout built for both arches: include/, and a build_<arch> or build_<arch>_<name>
# folder with prism.lib and its generated include/ (prism_version.h). Outputs to bridge/out/<arch>/. The shipped
# prism.dll is that checkout's Release build with "/d1trimfile:<checkout>" in CMAKE_C_FLAGS and CMAKE_CXX_FLAGS.
# Usage: powershell -ExecutionPolicy Bypass -File build_prism_pea.ps1 -PrismRoot <path> (or set PRISM_ROOT)
param(
    [string]$PrismRoot = $env:PRISM_ROOT,
    [string]$VcVarsAll = "C:\Program Files\Microsoft Visual Studio\18\Community\VC\Auxiliary\Build\vcvarsall.bat"
)
$ErrorActionPreference = "Stop"
if (-not $PrismRoot) { throw "Indica el checkout de prism con -PrismRoot <ruta> o con la variable PRISM_ROOT" }
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$src = Join-Path $here "prism_pea.c"
$inc = Join-Path $PrismRoot "include"
if (-not (Test-Path $src)) { throw "No se encuentra $src" }
if (-not (Test-Path (Join-Path $inc "prism.h"))) { throw "No se encuentra prism.h en $inc" }

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