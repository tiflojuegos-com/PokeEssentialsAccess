<#
  Instalador del toolkit de accesibilidad (PokeAccess) para fangames sobre mkxp-z.
  Ensambla la carpeta accessibility\ (core + el juego elegido + loader + assets) dentro
  del juego y registra el cargador en mkxp.json (preloadScript). NO modifica
  Scripts.rxdata: es reversible.

  Uso:
    - Ejecuta "Instalar mod.bat": se abre un selector de carpetas para elegir el juego y
      el perfil se detecta solo (o se pregunta). Tambien puedes arrastrar la carpeta encima.
    - powershell -ExecutionPolicy Bypass -File install.ps1 "<carpeta del juego>" [pokemon_z|opalo|reminiscencia|anil|royal|armonia|relict|realidea|africanus|awakening|generic]
#>
param([string]$GameDir, [string]$Game = "", [switch]$Check, [switch]$Force)

$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = Split-Path -Parent $here
$marker = "accessibility/preload_access.rb"

function Pause-Exit { Write-Host "`nPulsa una tecla para salir..."; try { [void][System.Console]::ReadKey($true) } catch {} }
function Fail($msg) { Write-Host "`n[ERROR] $msg" -ForegroundColor Red; Pause-Exit; exit 1 }

# opens the Windows folder picker (a standard dialog, easy with a screen reader); if it
# cannot be shown or is cancelled, asks for a typed path instead.
function Pick-Folder {
    try {
        Add-Type -AssemblyName System.Windows.Forms
        $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
        $dlg.Description = "Elige la carpeta del juego (donde esta el ejecutable)"
        $dlg.ShowNewFolderButton = $false
        if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { return $dlg.SelectedPath }
    } catch {}
    Write-Host "Escribe o pega la ruta de la carpeta del juego y pulsa Enter:"
    return (Read-Host).Trim('"')
}

# scans every .exe in the game folder for the ascii strings that tell whether its mkxp build
# accepts a preloadScript (the way this mod loads). a build can be compiled without that option,
# in which case the string is absent and the loader would never run. returns whether preloadScript
# and an mkxp engine were found, and the exe that matched, so the tester knows before installing.
function Test-Mkxp($dir) {
    $preload = $false; $mkxp = $false; $hit = $null
    foreach ($e in (Get-ChildItem $dir -Filter *.exe -File -ErrorAction SilentlyContinue)) {
        try {
            $txt = [System.Text.Encoding]::ASCII.GetString([System.IO.File]::ReadAllBytes($e.FullName))
            if ($txt.Contains("preloadScript")) { $preload = $true; if (-not $hit) { $hit = $e.Name } }
            if ($txt -match "mkxp") { $mkxp = $true }
        } catch {}
    }
    [pscustomobject]@{ Preload = $preload; Mkxp = $mkxp; Exe = $hit }
}

$core   = Join-Path $root "core"
$loader = Join-Path $root "loader"
$assets = Join-Path $root "assets"
foreach ($p in @($core, $loader, $assets)) {
    if (-not (Test-Path $p)) { Fail "Falta '$p' en el toolkit. La carpeta del instalador esta incompleta." }
}

# 1) carpeta del juego: argumento (arrastrar), o selector de carpetas, o ruta escrita.
if (-not $GameDir) { $GameDir = Pick-Folder }
if (-not $GameDir -or -not (Test-Path $GameDir)) { Fail "No se eligio una carpeta valida." }
$mainexe = if (Test-Path (Join-Path $GameDir "Game.exe")) { Join-Path $GameDir "Game.exe" }
           else { (Get-ChildItem $GameDir -Filter *.exe -ErrorAction SilentlyContinue | Sort-Object Length -Descending | Select-Object -First 1).FullName }
$json = Join-Path $GameDir "mkxp.json"
if (-not $mainexe) { Fail "No hay ningun .exe en esa carpeta. Elige la carpeta del juego." }

# compatibilidad: el mod se carga via preloadScript de mkxp-z. El ejecutable se escanea SIEMPRE, tenga o no
# el juego un mkxp.json: la ausencia del archivo no dice nada sobre el motor (es opcional para mkxp-z), y
# atarla al escaneo hacia que un juego sin config quedase marcado como incompatible sin haberlo mirado.
# Con -Check solo informa; en una instalacion normal, si no se detecta soporte se puede forzar.
$hasJson = Test-Path $json
$compat  = Test-Mkxp $GameDir
$engine  = if ($compat.Mkxp) { "mkxp-z" } else { "desconocido" }

# Which profile this folder would get, for the compatibility report: knowing it up front is what makes a
# user's problem report actionable ("detecta Opalo" vs "no detecta nada").
function Detected-Profile($dir, $exe) {
    $cat = @()
    $f = Join-Path $root "games\catalog.json"
    if (Test-Path $f) { try { $cat = @((Get-Content $f -Raw -Encoding UTF8 | ConvertFrom-Json).profiles) } catch { $cat = @() } }
    $hay = ("$dir " + $(if ($exe) { Split-Path $exe -Leaf } else { "" })).ToLower()
    foreach ($p in $cat) { if ($p.detect -and $hay -match $p.detect) { return $p } }
    return $null
}

if ($Check) {
    $det = Detected-Profile $GameDir $mainexe
    Write-Host "`n=== Comprobacion de compatibilidad ===" -ForegroundColor Cyan
    Write-Host ("  Carpeta: " + $GameDir)
    Write-Host ("  mkxp.json: " + $(if ($hasJson) { "SI" } else { "NO (se creara al instalar)" }))
    Write-Host ("  Motor: " + $engine)
    Write-Host ("  preloadScript: " + $(if ($compat.Preload) { "SI (en $($compat.Exe))" } else { "NO detectado" }))
    Write-Host ("  Perfil detectado: " + $(if ($det) { "$($det.display)  [$($det.key)]" } else { "ninguno (se elige a mano)" }))
    if ($compat.Preload) {
        Write-Host "`n[COMPATIBLE] Este fangame acepta el cargador. Instala con 'Instalar mod'." -ForegroundColor Green
    } elseif (-not $hasJson) {
        Write-Host "`n[NO COMPATIBLE] Ni mkxp.json ni 'preloadScript' en el ejecutable: no usa mkxp-z." -ForegroundColor Red
    } else {
        Write-Host "`n[DUDOSO] No veo 'preloadScript' en el ejecutable; este build podria tenerlo desactivado." -ForegroundColor Yellow
        Write-Host "Puedes intentarlo igualmente: 'Instalar mod' y responde si al aviso de forzar."
    }
    Pause-Exit; exit 0
}

# A game can be a perfectly good mkxp-z build and still ship no mkxp.json (Infinite Fusion does): the config
# file is optional for the engine, but the mod needs it because preloadScript is declared there. So the
# absence of the file only blocks when the executable ALSO lacks preloadScript support -- otherwise the file
# is created with just the loader in it, which is what the register step below would have added anyway.
if (-not $hasJson) {
    if (-not $compat.Preload) {
        Fail "Ni mkxp.json ni soporte de 'preloadScript' en el ejecutable: este juego no usa mkxp-z."
    }
    # No accents here on purpose: mkxp-z has a known bug parsing non-ASCII in this file.
    [System.IO.File]::WriteAllText($json, "{}", (New-Object System.Text.UTF8Encoding($false)))
    Write-Host "[OK] Creado mkxp.json (el juego no traia; su ejecutable si acepta preloadScript)." -ForegroundColor Green
}
if (-not $compat.Preload -and -not $Force) {
    Write-Host "`n[AVISO] No detecto soporte de 'preloadScript' en el ejecutable de este juego." -ForegroundColor Yellow
    Write-Host "El mod se carga por esa via; sin ella podria no funcionar. Puedes forzar y probarlo en el juego."
    $ans = (Read-Host "Forzar instalacion de todos modos? (s/N)").Trim().ToLower()
    if ($ans -ne "s" -and $ans -ne "si") { Fail "Instalacion cancelada. Usa 'Comprobar compatibilidad' para revisar el juego." }
    Write-Host "[!] Forzando instalacion: compatibilidad no garantizada." -ForegroundColor Yellow
} else {
    Write-Host ("[OK] Compatibilidad: el juego acepta preloadScript (motor $engine).") -ForegroundColor Green
}

# refuse to (re)install while the game is open: its dlls would be locked and the wipe could
# leave a half-installed folder.
$exeName = [IO.Path]::GetFileNameWithoutExtension($mainexe)
$running = @(Get-Process -Name $exeName -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $mainexe })
if ($running.Count -gt 0) { Fail "El juego esta abierto. Cierralo del todo y vuelve a ejecutar el instalador." }

# 2) que perfil de juego instalar: autodetecta por nombre, si no pregunta con un menu.
$available = @(Get-ChildItem (Join-Path $root "games") -Directory | Select-Object -ExpandProperty Name)
# El catalogo (games\catalog.json) es la fuente unica de perfiles: patron de autodeteccion + nombre
# hablado, compartido con el actualizador. Si falta, se cae a la lista de carpetas sin nombres bonitos.
$catalog = @()
$catFile = Join-Path $root "games\catalog.json"
if (Test-Path $catFile) {
    try { $catalog = @((Get-Content $catFile -Raw -Encoding UTF8 | ConvertFrom-Json).profiles) } catch { $catalog = @() }
}
function Display-Name($key) {
    $e = $catalog | Where-Object { $_.key -eq $key } | Select-Object -First 1
    if ($e -and $e.display) { $e.display } else { $key }
}
# Autodeteccion por el patron del catalogo sobre 'carpeta + exe'. La deteccion siempre es best-effort:
# si la carpeta tiene un nombre raro (p. ej. renombrada) no acierta y se elige el perfil a mano abajo.
if (-not $Game) {
    $hay = ("$GameDir " + (Split-Path $mainexe -Leaf)).ToLower()
    foreach ($p in $catalog) {
        if ($p.detect -and $hay -match $p.detect) { $Game = $p.key; break }
    }
}
# Fallback manual: elegir el perfil de la lista (con su nombre hablado). Cubre carpetas no detectadas y
# el caso de forzar a mano un perfil distinto (p. ej. usar el generico en una version del juego no soportada).
if (-not $Game -or -not ($available -contains $Game)) {
    Write-Host "`n¿Que juego es? Escribe el numero y pulsa Enter:"
    for ($i = 0; $i -lt $available.Count; $i++) {
        Write-Host ("  {0}) {1}" -f ($i + 1), (Display-Name $available[$i]))
    }
    $idx = 0; [void][int]::TryParse((Read-Host "Numero"), [ref]$idx)
    if ($idx -lt 1 -or $idx -gt $available.Count) { Fail "Opcion no valida." }
    $Game = $available[$idx - 1]
}
$gaming = Join-Path $root "games\$Game"
if (-not (Test-Path $gaming)) { Fail "No existe el perfil de juego '$Game' en el toolkit." }
Write-Host "[OK] Juego detectado: $Game" -ForegroundColor Green

# 1) Ensamblar accessibility\ (core + game + loader + assets)
# Al actualizar (reinstalar encima) se conservan los datos del usuario: su configuracion
# y sus etiquetas de objetos, que no son parte del mod y se perderian al recopiar.
$dst = Join-Path $GameDir "accessibility"
$dataDir = Join-Path $dst "data"
$preserve = @("settings.ini", "tags.txt", "tags_export.txt", "tags_import.txt")
$tmpSave = $null
if (Test-Path $dst) {
    $tmpSave = Join-Path ([IO.Path]::GetTempPath()) ("pokeaccess_" + [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Force $tmpSave | Out-Null
    foreach ($f in $preserve) {
        # new layout keeps these in data\; also check the old flat root for upgrades.
        $old = @((Join-Path $dataDir $f), (Join-Path $dst $f)) | Where-Object { Test-Path $_ } | Select-Object -First 1
        if ($old) { Copy-Item $old (Join-Path $tmpSave $f) -Force }
    }
    Remove-Item $dst -Recurse -Force
}
foreach ($sub in @("core", "game", "sounds", "lib", "data", "lang")) {
    New-Item -ItemType Directory -Force (Join-Path $dst $sub) | Out-Null
}
Copy-Item (Join-Path $core "*")   (Join-Path $dst "core") -Recurse -Force
Copy-Item (Join-Path $gaming "*") (Join-Path $dst "game") -Recurse -Force
$lang = Join-Path $root "lang"
if (Test-Path $lang) { Copy-Item (Join-Path $lang "*") (Join-Path $dst "lang") -Force }
Copy-Item (Join-Path $loader "boot.rb")           $dst -Force
Copy-Item (Join-Path $loader "preload_access.rb") $dst -Force

# detect the game's architecture from its executable and copy the matching voice dlls.
$arch = "x86"
try {
    $fs = [IO.File]::OpenRead($mainexe); $br = New-Object IO.BinaryReader($fs)
    $fs.Seek(0x3C, 0) | Out-Null; $pe = $br.ReadInt32(); $fs.Seek($pe + 4, 0) | Out-Null
    $m = $br.ReadUInt16(); $fs.Close()
    if ($m -eq 0x8664) { $arch = "x64" }
} catch {}
# sounds and libraries each go to their own subfolder (the mod reads them from there). Recurse so the
# per-rate subfolder (sounds\48000) and its contents are copied, not just the top-level 44100 files.
Copy-Item (Join-Path $assets "sounds\*")  (Join-Path $dst "sounds") -Recurse -Force
Copy-Item (Join-Path $assets "$arch\*")   (Join-Path $dst "lib") -Force
Write-Host "[OK] Mod '$Game' copiado a $dst (voz $arch)" -ForegroundColor Green

# restaura los datos del usuario conservados (config y etiquetas) en data\ tras actualizar.
if ($tmpSave) {
    $restored = 0
    foreach ($f in $preserve) {
        $sv = Join-Path $tmpSave $f
        if (Test-Path $sv) { Copy-Item $sv (Join-Path $dataDir $f) -Force; $restored++ }
    }
    Remove-Item $tmpSave -Recurse -Force
    if ($restored -gt 0) { Write-Host "[OK] Conservada tu configuracion y etiquetas ($restored archivos)." -ForegroundColor Green }
}

# 1b) Sellar installed.json en data\: qué versión del mod y qué perfil quedó instalado, más el hash
# de cada archivo desplegado. El actualizador (launcher) lo compara con el repo para bajar SOLO lo
# que cambió y para recordar si se instaló el perfil específico o el genérico (p. ej. un juego cuya
# version difiere de la soportada va mejor con el genérico).
$modVersion = "0.0.0"
$verFile = Join-Path $root "version.json"
if (Test-Path $verFile) {
    try { $modVersion = (Get-Content $verFile -Raw | ConvertFrom-Json).version } catch {}
}
$profileMode = if ($Game -eq "generic") { "generic" } else { "specific" }
$hashes = @{}
Get-ChildItem $dst -Recurse -File | Where-Object {
    # los datos del usuario (data\) no forman parte del mod; no se versionan ni se comparan.
    $_.FullName -notlike (Join-Path $dataDir "*")
} | ForEach-Object {
    $rel = $_.FullName.Substring($dst.Length + 1) -replace "\\", "/"
    $hashes[$rel] = (Get-FileHash $_.FullName -Algorithm SHA1).Hash.ToLower()
}
$installed = [ordered]@{
    mod_version  = $modVersion
    profile      = $Game
    profile_mode = $profileMode
    voice_arch   = $arch
    installed_at = (Get-Date).ToString("o")
    files        = $hashes
}
New-Item -ItemType Directory -Force $dataDir | Out-Null
$installed | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $dataDir "installed.json") -Encoding UTF8
Write-Host "[OK] Sellado installed.json (mod $modVersion, perfil $Game, $($hashes.Count) archivos)" -ForegroundColor Green

# 2) Registrar el cargador en mkxp.json (con copia de seguridad del original)
$bak = "$json.access.bak"
if (-not (Test-Path $bak)) { Copy-Item $json $bak -Force }
$content = Get-Content $json -Raw
if ($content -match [regex]::Escape($marker)) {
    Write-Host "[OK] El cargador ya estaba registrado en mkxp.json." -ForegroundColor Green
}
elseif ($content -match '(?m)^\s*"preloadScript"\s*:\s*\[') {
    $content = $content -replace '("preloadScript"\s*:\s*\[)', "`$1`"$marker`", "
    [System.IO.File]::WriteAllText($json, $content, (New-Object System.Text.UTF8Encoding($false)))
    Write-Host "[OK] Cargador anadido al preloadScript existente." -ForegroundColor Green
}
else {
    $block = @"
{
    // === MOD DE ACCESIBILIDAD (anadido por el instalador) ===
    "preloadScript": ["$marker"],
"@
    # insert right after the FIRST opening brace (the JSON root), which may sit below a block
    # of // comments (e.g. Anil's mkxp.json); anchoring to ^ would miss it then.
    $content = ([regex]'\{').Replace($content, $block, 1)
    [System.IO.File]::WriteAllText($json, $content, (New-Object System.Text.UTF8Encoding($false)))
    Write-Host "[OK] preloadScript creado en mkxp.json." -ForegroundColor Green
}

Write-Host "`nInstalacion completada. Abre el juego con un lector de pantalla activo (NVDA)." -ForegroundColor Cyan
Write-Host "Para desinstalar usa 'Desinstalar mod.bat'."
Pause-Exit
