<#
  Instalador del toolkit de accesibilidad (PokeAccess) para fangames sobre mkxp-z.
  Ensambla la carpeta accessibility\ (core + el juego elegido + loader + assets) dentro
  del juego y registra el cargador en mkxp.json (preloadScript). NO modifica
  Scripts.rxdata: es reversible.

  Uso:
    - Ejecuta "Instalar mod.bat": se abre un selector de carpetas para elegir el juego y
      el perfil se detecta solo (o se pregunta). Tambien puedes arrastrar la carpeta encima.
    - powershell -ExecutionPolicy Bypass -File install.ps1 "<carpeta del juego>" [pokemon_z|opalo|reminiscencia|anil|royal|armonia|relict|realidea|africanus|awakening|emerald|infinitefusion|infinitefusion_hoenn|generic]
#>
param([string]$GameDir, [string]$Game = "", [switch]$Check, [switch]$Force)

$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = Split-Path -Parent $here
$marker = "accessibility/preload_access.rb"
# UTF-8 SIN BOM en todo lo que escribe el instalador: mkxp-z y el launcher leen estos ficheros
# en crudo y el BOM les estorba (Set-Content -Encoding UTF8 lo mete siempre en PowerShell 5.1).
$utf8 = New-Object System.Text.UTF8Encoding($false)
# Las carpetas de juego llevan corchetes a menudo ("Pokemon X [v2.0]") y con -Path los cmdlets
# los tratan como comodin: no encuentran nada y borran/copian de menos. Por eso todo argumento
# de ruta sin comodin real va con -LiteralPath.

function Pause-Exit { Write-Host "`nPulsa una tecla para salir..."; try { [void][System.Console]::ReadKey($true) } catch {} }
function Fail($msg) { Write-Host "`n[ERROR] $msg" -ForegroundColor Red; Pause-Exit; exit 1 }

# Copia el CONTENIDO de una carpeta en otra, recursivo, sin pasar por el comodin. "Origen\*" es la forma
# corta y es justo la que rompe la regla de arriba: el comodin obliga a -Path, y con -Path unos corchetes
# en cualquier antepasado de la ruta se leen como clase de caracteres, no casa nada y la copia se salta
# sin error. Get-ChildItem -LiteralPath enumera los hijos y cada uno viaja por PSPath, que Copy-Item ata
# a -LiteralPath. Falla si el origen no existe: copiar cero ficheros y seguir es el modo de fallo que
# esto viene a cerrar.
# Cada arbol copiado queda anotado en $script:deployed: la verificacion del despliegue recorre ESA lista,
# asi que una carpeta nueva que pase por aqui queda comprobada sin tocar nada mas.
$script:deployed = @()
function Copy-Tree($src, $dstDir) {
    if (-not (Test-Path -LiteralPath $src)) { Fail "no existe la carpeta de origen: $src" }
    Get-ChildItem -LiteralPath $src -Force | Copy-Item -Destination $dstDir -Recurse -Force
    $script:deployed += @{ Src = $src; Dst = $dstDir }
}

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
    $preload = $false; $mkxp = $false; $hit = $null; $hitLen = -1
    foreach ($e in (Get-ChildItem -LiteralPath $dir -Filter *.exe -File -ErrorAction SilentlyContinue)) {
        try {
            $txt = [System.Text.Encoding]::ASCII.GetString([System.IO.File]::ReadAllBytes($e.FullName))
            # de los que traen la cadena se queda el MAS GRANDE, igual que el launcher: algunos
            # fangames dejan al lado un lanzador pequeno que tambien la contiene.
            if ($txt.Contains("preloadScript")) {
                $preload = $true
                if ($e.Length -gt $hitLen) { $hit = $e.Name; $hitLen = $e.Length }
            }
            if ($txt -match "mkxp") { $mkxp = $true }
        } catch {}
    }
    [pscustomobject]@{ Preload = $preload; Mkxp = $mkxp; Exe = $hit }
}

# git blob sha1 of a file: sha1 over "blob <bytes>\0" + the raw content, which is the id git (and
# the GitHub tree api) publishes for it. The launcher compares installed.json against those ids,
# so a plain sha1 here would never match and it would re-download everything.
# true when any executable of the game folder is running from THIS folder. La carpeta entera y no solo el
# ejecutable principal: un lanzador secundario abierto bloquea las DLL igual. GetProcessesByName y no
# Get-Process -Name, que interpreta comodines: un ejecutable con corchetes en el nombre no casaria consigo
# mismo y el guardia dejaria pasar la instalacion con el juego abierto. Copiado tal cual del desinstalador
# a proposito: cada script tiene que poder ejecutarse solo, sin un fichero comun que pueda faltar.
function Test-GameRunning($dir) {
    foreach ($e in (Get-ChildItem -LiteralPath $dir -Filter *.exe -File -ErrorAction SilentlyContinue)) {
        $name = [IO.Path]::GetFileNameWithoutExtension($e.Name)
        foreach ($p in @([System.Diagnostics.Process]::GetProcessesByName($name))) {
            $path = $null
            try { $path = $p.Path } catch {}
            if ($path -eq $e.FullName) { return $true }
        }
    }
    return $false
}

function Get-GitBlobSha1($path) {
    $bytes  = [System.IO.File]::ReadAllBytes($path)
    $header = [System.Text.Encoding]::ASCII.GetBytes("blob " + $bytes.Length + [char]0)
    $buf    = New-Object byte[] ($header.Length + $bytes.Length)
    [Array]::Copy($header, 0, $buf, 0, $header.Length)
    [Array]::Copy($bytes, 0, $buf, $header.Length, $bytes.Length)
    $sha = [System.Security.Cryptography.SHA1]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($buf)) -replace "-", "").ToLowerInvariant() }
    finally { $sha.Dispose() }
}

# reads a text file with the encoding it REALLY has: strict UTF-8 first, cp1252 (the ANSI code page RPG
# Maker wrote on a Western Windows) after. Get-Content -Encoding UTF8 over an ANSI file turns every
# accented byte into U+FFFD, and saving that string back burns the mojibake into the file for good, which
# is how an accented windowTitle got corrupted for ever. Returns the encoding too, because whatever writes
# the file again must reuse THE SAME one: decoding cp1252 and saving UTF-8 rewrites the player's title
# bytes behind their back. Same pair of attempts as the launcher (detect.rs: decode_ini).
function Read-TextFile($path) {
    $bytes  = [System.IO.File]::ReadAllBytes($path)
    $strict = New-Object System.Text.UTF8Encoding($false, $true)
    try { return [pscustomobject]@{ Text = $strict.GetString($bytes); Encoding = $utf8 } }
    catch {
        $ansi = [System.Text.Encoding]::GetEncoding(1252)
        return [pscustomobject]@{ Text = $ansi.GetString($bytes); Encoding = $ansi }
    }
}

# index of the first LIVE line matching a pattern, or -1. mkxp.json admits // comments and the
# engine ignores those lines: a commented key must not count as present (it would leave the mod
# unregistered) nor be written into (the entry would stay commented out).
# $parts comes from [regex]::Split($text, '(\r?\n)'), so the original line breaks survive a rejoin.
function Find-LiveLine($parts, $pattern) {
    for ($i = 0; $i -lt $parts.Count; $i++) {
        if ($parts[$i].TrimStart().StartsWith("//")) { continue }
        if ($parts[$i] -match $pattern) { return $i }
    }
    return -1
}

# Todo el cuerpo va dentro de un try: con $ErrorActionPreference = Stop, cualquier fallo no
# previsto (permisos, disco lleno, un archivo bloqueado) cerraria el script sin la pausa final
# y la ventana desapareceria sin decir nada, que para quien no ve la pantalla es silencio total.
$tmpSave = $null
$dataDir = $null
try {

    $core   = Join-Path $root "core"
    $loader = Join-Path $root "loader"
    $assets = Join-Path $root "assets"
    foreach ($p in @($core, $loader, $assets)) {
        if (-not (Test-Path -LiteralPath $p)) { Fail "Falta '$p' en el toolkit. La carpeta del instalador esta incompleta." }
    }

    # 1) carpeta del juego: argumento (arrastrar), o selector de carpetas, o ruta escrita.
    if (-not $GameDir) { $GameDir = Pick-Folder }
    if (-not $GameDir -or -not (Test-Path -LiteralPath $GameDir)) { Fail "No se eligio una carpeta valida." }

    # compatibilidad: el mod se carga via preloadScript de mkxp-z. El ejecutable se escanea SIEMPRE, tenga o no
    # el juego un mkxp.json: la ausencia del archivo no dice nada sobre el motor (es opcional para mkxp-z), y
    # atarla al escaneo hacia que un juego sin config quedase marcado como incompatible sin haberlo mirado.
    # Con -Check solo informa; en una instalacion normal, si no se detecta soporte se puede forzar.
    $compat = Test-Mkxp $GameDir
    $engine = if ($compat.Mkxp) { "mkxp-z" } else { "desconocido" }

    # Ejecutable principal (criterio compartido con el launcher, decidido 2026-08-01): el que CONTIENE
    # la cadena "preloadScript", porque ese es el binario de mkxp-z que carga el mod y no siempre se
    # llama Game.exe; si ninguno la trae, Game.exe; y si tampoco existe, el .exe mas grande.
    $mainexe = if ($compat.Exe) { Join-Path $GameDir $compat.Exe }
               elseif (Test-Path -LiteralPath (Join-Path $GameDir "Game.exe")) { Join-Path $GameDir "Game.exe" }
               else { (Get-ChildItem -LiteralPath $GameDir -Filter *.exe -File -ErrorAction SilentlyContinue | Sort-Object Length -Descending | Select-Object -First 1).FullName }
    $json    = Join-Path $GameDir "mkxp.json"
    $hasJson = Test-Path -LiteralPath $json
    if (-not $mainexe) {
        # One of the thirteen real games ships one level down (ReminiscenciaV2_3\ReminiscenciaV2_3), and the
        # message stopped at "wrong folder" -- true, and no help at all when the right one is a single click
        # away. dump_scripts.rb already answers this the useful way; so does this now.
        $nested = @(Get-ChildItem -LiteralPath $GameDir -Directory -ErrorAction SilentlyContinue |
                    Where-Object { @(Get-ChildItem -LiteralPath $_.FullName -Filter *.exe -File -ErrorAction SilentlyContinue).Count -gt 0 })
        if ($nested.Count -gt 0) {
            $paths = @($nested | ForEach-Object { $_.FullName }) -join " | "
            Fail "No hay ningun .exe en esa carpeta, pero si en una de dentro. Prueba con: $paths"
        }
        Fail "No hay ningun .exe en esa carpeta. Elige la carpeta del juego."
    }

    # The game's declared title: mkxp.json "windowTitle"/"title" first, then Game.ini Title= -- the signal a
    # player never renames, unlike the folder. Misma forma que el launcher (detect.rs: game_title), y de ahi
    # las tres reglas: 1) la clave vale con o sin el prefijo window y en cualquier caja -- buscar solo "title"
    # era una RAMA MUERTA, porque de los 12 mkxp.json reales ninguno la usa y 5 declaran windowTitle; 2) las
    # lineas COMENTADAS no cuentan, que es lo que salva de leer el '// "windowTitle": "Custom Title"' del
    # mkxp.json de ejemplo (comentado en 5 de los 12) como si fuera un titulo de verdad; 3) el valor del
    # Game.ini es lo que siga al PRIMER '=', asi que 'Title = X' con espacios se lee igual en los dos.
    # Cada fichero con SU codificacion (Read-TextFile): los Game.ini de fangames viejos suelen ser ANSI y
    # leerlos como UTF-8 devolvia "Pok<FFFD>mon <FFFD>palo", con lo que los dos instaladores elegian perfiles
    # distintos para el mismo juego -- justo la deriva que el catalogo compartido existe para evitar.
    function Get-GameTitle($dir) {
        $mj = Join-Path $dir "mkxp.json"
        if (Test-Path -LiteralPath $mj) {
            try {
                $live = @((Read-TextFile $mj).Text -split "`r?`n" | Where-Object { -not $_.TrimStart().StartsWith("//") })
                if (($live -join "`n") -match '(?i)"(?:window)?title"\s*:\s*"([^"]+)"') {
                    $t = $Matches[1].Trim(); if ($t) { return $t }
                }
            } catch {}
        }
        $ini = Join-Path $dir "Game.ini"
        if (Test-Path -LiteralPath $ini) {
            try {
                foreach ($line in ((Read-TextFile $ini).Text -split "`r?`n")) {
                    $l  = $line.TrimStart([char]0xFEFF).Trim()
                    $eq = $l.IndexOf("=")
                    if ($eq -lt 1 -or $l.Substring(0, $eq).Trim() -ne "title") { continue }
                    $t = $l.Substring($eq + 1).Trim()
                    if ($t) { return $t }
                }
            } catch {}
        }
        return $null
    }

    # Which profile this folder would get, for the compatibility report: knowing it up front is what makes a
    # user's problem report actionable ("detecta Opalo" vs "no detecta nada"). LAYERED detection, mirroring
    # the launcher (order decided 2026-08-01): 1) declared titles against the game's own title (longest
    # declared match wins), 2) detect regex over folder+exe (LONGEST match wins, not first -- kills the
    # list-order dependency), 3) a distinctive exe name (Game.exe never identifies), 4) nothing -> ask.
    function Detected-Profile($dir, $exe) {
        $cat = @()
        $f = Join-Path $root "games\catalog.json"
        if (Test-Path -LiteralPath $f) { try { $cat = @((Get-Content -LiteralPath $f -Raw -Encoding UTF8 | ConvertFrom-Json).profiles) } catch { $cat = @() } }
        if (-not $cat) { return $null }

        # ToLowerInvariant y no ToLower en todo el emparejamiento: en un Windows turco ToLower convierte la I
        # en 'i' sin punto, asi que "INFINITE FUSION" se volvia "infinite fusion" y no casaba con NINGUNA
        # entrada del catalogo. El catalogo esta escrito en minuscula invariante.
        $title = Get-GameTitle $dir
        if ($title) {
            $tl = $title.ToLowerInvariant()
            $best = $null; $bestLen = -1
            foreach ($p in $cat) {
                foreach ($cand in @($p.titles)) {
                    if ($cand -and $tl.Contains($cand.ToLowerInvariant()) -and $cand.Length -gt $bestLen) {
                        $best = $p; $bestLen = $cand.Length
                    }
                }
            }
            if ($best) { return $best }
        }

        $hay = ("$dir " + $(if ($exe) { Split-Path $exe -Leaf } else { "" })).ToLowerInvariant()
        $best = $null; $bestLen = -1
        foreach ($p in $cat) {
            if (-not $p.detect) { continue }
            # Un 'detect' invalido en el catalogo tiraba el script ENTERO (ErrorActionPreference = Stop), o
            # sea que un typo en el catalogo dejaba sin instalar cualquier juego, tuviera o no que ver con
            # ese perfil. Un patron roto solo puede costar su propia autodeteccion; el launcher lo loguea
            # igual (catalog.rs) y sigue.
            $m = $null
            try { $m = [regex]::Match($hay, $p.detect, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase) }
            catch { Write-Host ("[!] Patron de deteccion invalido en el catalogo (perfil '" + $p.key + "'): se ignora.") -ForegroundColor Yellow }
            if ($m -and $m.Success -and $m.Length -gt $bestLen) { $best = $p; $bestLen = $m.Length }
        }
        if ($best) { return $best }

        if ($exe) {
            $en = (Split-Path $exe -Leaf).ToLowerInvariant()
            foreach ($p in $cat) {
                foreach ($x in @($p.exes)) {
                    if ($x -and $x.ToLowerInvariant() -eq $en) { return $p }
                }
            }
        }
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
        # Two lines and not "{}": the register step below inserts its block in place of the first opening
        # brace, so a one-line "{}" came out as {\n  "preloadScript": [...],} -- a trailing comma, which is
        # not valid JSON. mkxp-z tolerates it and the game boots, but the launcher and anything else that
        # parses strictly does not, and the file stays that way until the next reinstall.
        # No accents here on purpose: mkxp-z has a known bug parsing non-ASCII in this file.
        [System.IO.File]::WriteAllText($json, "{`n}", $utf8)
        Write-Host "[OK] Creado mkxp.json (el juego no traia; su ejecutable si acepta preloadScript)." -ForegroundColor Green
    }
    if (-not $compat.Preload -and -not $Force) {
        Write-Host "`n[AVISO] No detecto soporte de 'preloadScript' en el ejecutable de este juego." -ForegroundColor Yellow
        Write-Host "El mod se carga por esa via; sin ella podria no funcionar. Puedes forzar y probarlo en el juego."
        $ans = (Read-Host "Forzar instalacion de todos modos? (s/N)").Trim().ToLowerInvariant()
        if ($ans -ne "s" -and $ans -ne "si") { Fail "Instalacion cancelada. Usa 'Comprobar compatibilidad' para revisar el juego." }
        Write-Host "[!] Forzando instalacion: compatibilidad no garantizada." -ForegroundColor Yellow
    } else {
        Write-Host ("[OK] Compatibilidad: el juego acepta preloadScript (motor $engine).") -ForegroundColor Green
    }

    # refuse to (re)install while the game is open: its dlls would be locked and the wipe could
    # leave a half-installed folder.
    #
    # GetProcessesByName y no Get-Process -Name: el segundo interpreta comodines, y varios de estos juegos
    # traen corchetes en el nombre del .exe, asi que no casaba consigo mismo y el guardia dejaba pasar la
    # instalacion con el juego abierto. Se mira la carpeta entera, como en el desinstalador: un lanzador
    # secundario abierto bloquea las DLL igual.
    if (Test-GameRunning $GameDir) { Fail "El juego esta abierto. Cierralo del todo y vuelve a ejecutar el instalador." }

    # 2) que perfil de juego instalar: autodetecta por nombre, si no pregunta con un menu.
    $available = @(Get-ChildItem -LiteralPath (Join-Path $root "games") -Directory | Select-Object -ExpandProperty Name)
    # El catalogo (games\catalog.json) es la fuente unica de perfiles: patron de autodeteccion + nombre
    # hablado, compartido con el actualizador. Si falta, se cae a la lista de carpetas sin nombres bonitos.
    $catalog = @()
    $catFile = Join-Path $root "games\catalog.json"
    if (Test-Path -LiteralPath $catFile) {
        try { $catalog = @((Get-Content -LiteralPath $catFile -Raw -Encoding UTF8 | ConvertFrom-Json).profiles) } catch { $catalog = @() }
    }
    function Display-Name($key) {
        $e = $catalog | Where-Object { $_.key -eq $key } | Select-Object -First 1
        if ($e -and $e.display) { $e.display } else { $key }
    }
    # Autodeteccion por capas (titulo declarado -> regex mas largo -> exe distintivo), la MISMA ruta que
    # 'Comprobar compatibilidad', para que comprobar e instalar nunca diverjan. Best-effort: si ninguna capa
    # identifica el juego (carpeta renombrada y sin titulo), se elige el perfil a mano abajo.
    if (-not $Game) {
        $det = Detected-Profile $GameDir $mainexe
        if ($det) { $Game = $det.key }
    }
    # Fallback manual: elegir el perfil de la lista (con su nombre hablado). Cubre carpetas no detectadas y
    # el caso de forzar a mano un perfil distinto (p. ej. usar el generico en una version del juego no soportada).
    if (-not $Game -or -not ($available -contains $Game)) {
        Write-Host "`nQue juego es? Escribe el numero y pulsa Enter:"
        for ($i = 0; $i -lt $available.Count; $i++) {
            Write-Host ("  {0}) {1}" -f ($i + 1), (Display-Name $available[$i]))
        }
        $idx = 0; [void][int]::TryParse((Read-Host "Numero"), [ref]$idx)
        if ($idx -lt 1 -or $idx -gt $available.Count) { Fail "Opcion no valida." }
        $Game = $available[$idx - 1]
    }
    $gaming = Join-Path $root "games\$Game"
    if (-not (Test-Path -LiteralPath $gaming)) { Fail "No existe el perfil de juego '$Game' en el toolkit." }
    Write-Host "[OK] Juego detectado: $Game" -ForegroundColor Green

    # 1) Ensamblar accessibility\ (core + game + loader + assets)
    # Al actualizar (reinstalar encima) se conserva data\ ENTERA, no una lista de nombres: ahi viven la
    # configuracion, las etiquetas de objetos, los nombres de mapa que el jugador se ha puesto a mano y sus
    # grabaciones, y NADA de eso es parte del mod. Salvar cuatro nombres sueltos se llevaba por delante
    # map_names.txt y recordings\ en cada reinstalacion -- y 'instalar_todos.bat' reinstala los 13 de golpe.
    # installed.json va tambien: si algo falla despues del borrado, el sello de la instalacion ANTERIOR
    # sobrevive y el launcher sigue viendo la version vieja en vez de un juego sin instalar.
    $dst = Join-Path $GameDir "accessibility"
    $dataDir = Join-Path $dst "data"
    # Las instalaciones anteriores a data\ dejaban estos cuatro sueltos en la raiz de accessibility\.
    $legacyFlat = @("settings.ini", "tags.txt", "tags_export.txt", "tags_import.txt")
    if (Test-Path -LiteralPath $dst) {
        $tmpSave = Join-Path ([IO.Path]::GetTempPath()) ("pokeaccess_" + [guid]::NewGuid().ToString("N"))
        $tmpData = Join-Path $tmpSave "data"
        New-Item -ItemType Directory -Force $tmpData | Out-Null
        # Copiar y no mover: %TEMP% suele caer en C: y el juego en otra unidad, y Move-Item se niega a mover
        # CARPETAS entre volumenes (data\recordings\ es una).
        if (Test-Path -LiteralPath $dataDir) {
            foreach ($it in @(Get-ChildItem -LiteralPath $dataDir -Force)) {
                Copy-Item -LiteralPath $it.FullName -Destination $tmpData -Recurse -Force
            }
        }
        foreach ($f in $legacyFlat) {
            $old = Join-Path $dst $f
            if ((Test-Path -LiteralPath $old) -and -not (Test-Path -LiteralPath (Join-Path $tmpData $f))) {
                Copy-Item -LiteralPath $old -Destination (Join-Path $tmpData $f) -Force
            }
        }
        # Contado ANTES de borrar y sin silenciar errores: si no se puede ni contar lo que se acaba de
        # guardar, Stop aborta aqui y accessibility\ sigue intacta.
        $savedCount = @(Get-ChildItem -LiteralPath $tmpData -Recurse -File).Count
        Remove-Item -LiteralPath $dst -Recurse -Force
    }
    foreach ($sub in @("core", "game", "plugins", "sounds", "lib", "data", "lang")) {
        New-Item -ItemType Directory -Force (Join-Path $dst $sub) | Out-Null
    }
    $script:deployed = @()
    Copy-Tree $core   (Join-Path $dst "core")
    Copy-Tree $gaming (Join-Path $dst "game")
    # Los lectores de plugins de terceros: se copia la carpeta ENTERA y el manifiesto del perfil decide
    # cuales se cargan. Que el instalador resolviera esa lista pondria la misma logica en dos instaladores
    # y volveria por perfil la contabilidad de la desinstalacion, para ahorrar unos KB de Ruby sin evaluar.
    # Obligatorias las dos, igual que core: un arbol sin plugins\ o sin lang\ no es el mod, y Copy-Tree
    # aborta si faltan en vez de sellar una instalacion muda.
    Copy-Tree (Join-Path $root "plugins") (Join-Path $dst "plugins")
    Copy-Tree (Join-Path $root "lang")    (Join-Path $dst "lang")
    Copy-Item -LiteralPath (Join-Path $loader "boot.rb")           -Destination $dst -Force
    Copy-Item -LiteralPath (Join-Path $loader "preload_access.rb") -Destination $dst -Force

    # detect the game's architecture from its executable and copy the matching voice dlls.
    $arch = "x86"
    try {
        $fs = [IO.File]::OpenRead($mainexe); $br = New-Object IO.BinaryReader($fs)
        $fs.Seek(0x3C, 0) | Out-Null; $pe = $br.ReadInt32(); $fs.Seek($pe + 4, 0) | Out-Null
        $m = $br.ReadUInt16(); $fs.Close()
        if ($m -eq 0x8664) { $arch = "x64" }
    } catch {}
    # sounds and libraries each go to their own subfolder (the mod reads them from there). Recurse siempre,
    # tambien en lang\ y en lib\: hoy son planas, pero el dia que una subcarpeta aparezca en el repo el
    # launcher la desplegaria (baja el arbol entero) y el PS la perderia en silencio.
    Copy-Tree (Join-Path $assets "sounds") (Join-Path $dst "sounds")
    Copy-Tree (Join-Path $assets $arch)     (Join-Path $dst "lib")

    Write-Host "[OK] Mod '$Game' copiado a $dst (voz $arch)" -ForegroundColor Green

    # restaura data\ entera (configuracion, etiquetas, nombres de mapa, grabaciones) tras actualizar.
    if ($tmpSave) {
        $tmpData  = Join-Path $tmpSave "data"
        $expected = @(Get-ChildItem -LiteralPath $tmpData -Recurse -File -ErrorAction SilentlyContinue)
        foreach ($it in @(Get-ChildItem -LiteralPath $tmpData -Force -ErrorAction SilentlyContinue)) {
            Copy-Item -LiteralPath $it.FullName -Destination $dataDir -Recurse -Force
        }
        # Contado en el DESTINO, y fichero a fichero. Contarlo sobre $tmpData -como se hacia- comparaba la
        # copia consigo misma: $savedCount salio de esa misma carpeta unas lineas antes, asi que la unica
        # forma de que difirieran era que %TEMP% se vaciara entre dos sentencias. Nada miraba si los
        # ficheros habian LLEGADO. Un fichero bloqueado, una ruta larga o un antivirus y el bucle se lo
        # deja: Copy-Item -Force no lanza por eso, la comparacion daba igualdad, se imprimia "[OK]
        # Conservados" y la rama else borraba la copia de seguridad. Lo que se pierde asi -etiquetas,
        # nombres de mapa a mano, grabaciones- no se puede regenerar. Perderlo ya es malo; perderlo en
        # silencio es lo que impide recuperarlo, asi que aqui se dice y NO se borra la copia.
        $restored = @($expected | Where-Object {
            $rel = $_.FullName.Substring($tmpData.Length).TrimStart('\', '/')
            Test-Path -LiteralPath (Join-Path $dataDir $rel)
        }).Count
        if ($restored -lt $savedCount) {
            Write-Host "`n[!] Se guardaron $savedCount archivos de tus datos y solo han vuelto $restored." -ForegroundColor Red
            Write-Host "    El resto sigue en: $tmpData" -ForegroundColor Red
            Write-Host "    Esa carpeta NO se ha borrado: copia su contenido a accessibility\data." -ForegroundColor Red
        } else {
            Remove-Item -LiteralPath $tmpSave -Recurse -Force
            $tmpSave = $null
            if ($restored -gt 0) { Write-Host "[OK] Conservados tus datos del mod ($restored archivos de accessibility\data)." -ForegroundColor Green }
        }
    }

    # La verdad del despliegue viene del ORIGEN: lo que se pidio copiar, fichero a fichero, no lo que
    # aparecio. Copy-Item -Force no lanza por un fichero bloqueado, una ruta larga o un antivirus, asi
    # que sin esto un hueco solo bajaba el numero del sello y todo seguia diciendo [OK]. Aqui aborta con
    # el primer ausente, ANTES de tocar mkxp.json y de sellar.
    $missing = @()
    foreach ($pair in $script:deployed) {
        $have = @{}
        foreach ($f in @(Get-ChildItem -LiteralPath $pair.Dst -Recurse -File -ErrorAction SilentlyContinue)) {
            $have[($f.FullName.Substring($pair.Dst.Length) -replace '^[\\/]+', '').ToLowerInvariant()] = $true
        }
        foreach ($f in @(Get-ChildItem -LiteralPath $pair.Src -Recurse -File -ErrorAction SilentlyContinue)) {
            $rel = $f.FullName.Substring($pair.Src.Length) -replace '^[\\/]+', ''
            if (-not $have.ContainsKey($rel.ToLowerInvariant())) { $missing += (Join-Path $pair.Dst $rel) }
        }
    }
    foreach ($f in @("boot.rb", "preload_access.rb")) {
        if (-not (Test-Path -LiteralPath (Join-Path $dst $f))) { $missing += (Join-Path $dst $f) }
    }
    if ($missing.Count -gt 0) {
        Fail "Faltan $($missing.Count) archivos del despliegue (el primero: $($missing[0])). No se sella nada; cierra el antivirus o libera los archivos y reinstala."
    }

    # 2) Registrar el cargador en mkxp.json (con copia de seguridad del original). VA ANTES DE SELLAR:
    # sellando primero, un fallo aqui dejaba un juego MUDO (el mod copiado pero sin cargar) marcado como
    # "al dia" con la version nueva, y el launcher no vuelve a tocar lo que ya esta al dia. Registrando
    # primero, si esto falla no hay sello nuevo: queda el de la instalacion anterior (data\ se conserva) o
    # ninguno, y en los dos casos el launcher sigue ofreciendo la instalacion. Mismo orden que el
    # launcher, que sella despues de registrar y en el fallo sella la version PREVIA (apply.rs).
    $bak = "$json.access.bak"
    if (-not (Test-Path -LiteralPath $bak)) { Copy-Item -LiteralPath $json -Destination $bak -Force }
    # Leido y reescrito con SU codificacion: un mkxp.json en ANSI leido como UTF-8 volvia con U+FFFD donde
    # tenia los acentos, y al reescribirlo el windowTitle del juego quedaba corrupto para siempre.
    $src   = Read-TextFile $json
    $parts = [regex]::Split($src.Text, '(\r?\n)')
    if ((Find-LiveLine $parts ([regex]::Escape($marker))) -ge 0) {
        Write-Host "[OK] El cargador ya estaba registrado en mkxp.json." -ForegroundColor Green
    }
    else {
        # sin ancla de principio de linea: hay mkxp.json escritos en UNA sola linea, y no verlos
        # llevaba a meter una SEGUNDA clave "preloadScript" que el motor ignora.
        $i = Find-LiveLine $parts '"preloadScript"\s*:\s*\['
        if ($i -ge 0) {
            # El separador solo si el array TIENE algo detras. Un preloadScript vacio es el estado normal
            # tras desinstalar (la desinstalacion retira la entrada y deja []), y meterle ", " deja la coma
            # colgando delante del corchete: JSON invalido que mkxp-z traga y el launcher no.
            if ($parts[$i] -match '"preloadScript"\s*:\s*\[\s*\]') {
                $parts[$i] = ([regex]'("preloadScript"\s*:\s*\[)(\s*)(\])').Replace($parts[$i], "`$1`"$marker`"`$2`$3", 1)
            }
            else {
                $parts[$i] = ([regex]'("preloadScript"\s*:\s*\[)').Replace($parts[$i], "`$1`"$marker`", ", 1)
            }
            [System.IO.File]::WriteAllText($json, ($parts -join ""), $src.Encoding)
            Write-Host "[OK] Cargador anadido al preloadScript existente." -ForegroundColor Green
        }
        else {
            # Solo la clave, sin rotulo: el comentario que se escribia aqui lo dejaba huerfano cualquier
            # desinstalacion que retire el cargador por entradas (la del launcher no lo borra), apuntando
            # a un mod que ya no esta. El launcher escribe exactamente esta linea y nada mas (mkxp.rs).
            $block = @"
{
    "preloadScript": ["$marker"],
"@
            # insert right after the FIRST opening brace (the JSON root), which may sit below a block
            # of // comments (e.g. Anil's mkxp.json); anchoring to ^ would miss it then.
            $i = Find-LiveLine $parts '\{'
            if ($i -lt 0) { Fail "mkxp.json no parece un JSON valido: no encuentro la llave de apertura." }
            $parts[$i] = ([regex]'\{').Replace($parts[$i], $block, 1)
            [System.IO.File]::WriteAllText($json, ($parts -join ""), $src.Encoding)
            Write-Host "[OK] preloadScript creado en mkxp.json." -ForegroundColor Green
        }
    }

    # Coma colgante antes de la llave de cierre: la deja el propio bloque de arriba cuando el JSON no tenia
    # ninguna otra clave (juego sin mkxp.json, que creamos vacio). mkxp-z la traga y el juego arranca, pero no
    # es JSON valido y el launcher -- o cualquier lector estricto -- se atraganta. FUERA del else, para que
    # una reinstalacion sobre un juego que ya tiene el cargador tambien lo repare.
    # Se busca por LINEAS VIVAS y no con un patron sobre todo el texto: el mkxp.json de serie lleva decenas
    # de lineas de ejemplo comentadas, algunas detras de la llave de cierre y otras acabadas en coma, asi que
    # un patron global tocaria comentarios o no llegaria al final.
    # Dos formas, porque la llave de cierre puede estar en su linea o pegada a la coma. La segunda sale de un
    # juego cuyo mkxp.json es {} en una sola linea: ahi la insercion deja  ...],}  y la busqueda que solo
    # miraba "la ultima linea viva acabada en coma, con la llave sola detras" no encontraba nada que corregir.
    $after = (Read-TextFile $json)
    $lines = [regex]::Split($after.Text, '(\r?\n)')
    # Los dos cierres, llave y corchete: la coma puede quedar colgando delante de cualquiera de ellos, y un
    # mkxp.json que ya venga danado de una version anterior se cura aqui aunque la insercion ya no lo cree.
    $fix = -1
    $sameLine = $false
    $sawCloser = $false
    for ($k = $lines.Count - 1; $k -ge 0; $k--) {
        $t = $lines[$k].Trim()
        if ($t -eq "" -or $t.StartsWith("//")) { continue }
        if ($t -match ',\s*[\}\]]$') { $fix = $k; $sameLine = $true; break }
        if ($t -eq "}" -or $t -eq "]") { $sawCloser = $true; continue }
        if ($sawCloser -and $t.EndsWith(",")) { $fix = $k }
        break
    }
    if ($fix -ge 0) {
        if ($sameLine) { $lines[$fix] = $lines[$fix] -replace ',(\s*)([\}\]])$', '$1$2' }
        else           { $lines[$fix] = $lines[$fix] -replace ',\s*$', '' }
        [System.IO.File]::WriteAllText($json, ($lines -join ""), $after.Encoding)
        Write-Host "[OK] Corregida una coma sobrante en mkxp.json." -ForegroundColor Green
    }
    # releer y comprobar de verdad: si el cargador no acabo en una linea viva, el juego arrancaria
    # sin mod y el instalador habria cantado un [OK] falso.
    $written = [regex]::Split((Read-TextFile $json).Text, '(\r?\n)')
    if ((Find-LiveLine $written ([regex]::Escape($marker))) -lt 0) {
        Fail "No he podido registrar el cargador en mkxp.json. Tienes el original en '$bak': copialo encima de mkxp.json y avisa del fallo."
    }

    # 3) Sellar installed.json en data\: que version del mod y que perfil quedo instalado, mas el hash
    # de cada archivo desplegado. El actualizador (launcher) lo compara con el repo para bajar SOLO lo
    # que cambio y para recordar si se instalo el perfil especifico o el generico (p. ej. un juego cuya
    # version difiere de la soportada va mejor con el generico).
    $modVersion = "0.0.0"
    $verFile = Join-Path $root "version.json"
    if (Test-Path -LiteralPath $verFile) {
        try { $modVersion = (Get-Content -LiteralPath $verFile -Raw -Encoding UTF8 | ConvertFrom-Json).version } catch {}
    }
    $profileMode = if ($Game -eq "generic") { "generic" } else { "specific" }
    $dataPrefix = $dataDir + "\"
    $hashes = @{}
    Get-ChildItem -LiteralPath $dst -Recurse -File | Where-Object {
        # los datos del usuario (data\) no forman parte del mod; no se versionan ni se comparan.
        # Comparacion literal, no -like: un corchete en la ruta del juego romperia el patron.
        -not $_.FullName.StartsWith($dataPrefix, [StringComparison]::OrdinalIgnoreCase)
    } | ForEach-Object {
        $rel = $_.FullName.Substring($dst.Length + 1) -replace "\\", "/"
        $hashes[$rel] = Get-GitBlobSha1 $_.FullName
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
    [System.IO.File]::WriteAllText((Join-Path $dataDir "installed.json"), ($installed | ConvertTo-Json -Depth 5), $utf8)
    Write-Host "[OK] Sellado installed.json (mod $modVersion, perfil $Game, $($hashes.Count) archivos)" -ForegroundColor Green

    Write-Host "`nInstalacion completada. Abre el juego con un lector de pantalla activo (NVDA)." -ForegroundColor Cyan
    Write-Host "Para desinstalar usa 'Desinstalar mod.bat'."
    Pause-Exit
}
catch {
    $err  = $_.Exception.Message
    $line = $_.InvocationInfo.ScriptLineNumber
    # Si el fallo cae despues del borrado de accessibility\, los datos del jugador (configuracion,
    # etiquetas, nombres de mapa y grabaciones) estan en %TEMP%: se devuelven a su sitio si aun existe la
    # carpeta destino, y si no se dice donde quedaron.
    if ($tmpSave -and (Test-Path -LiteralPath $tmpSave)) {
        $tmpData = Join-Path $tmpSave "data"
        $kept = @(Get-ChildItem -LiteralPath $tmpData -Recurse -File -ErrorAction SilentlyContinue)
        if ($kept.Count -gt 0) {
            $back = $false
            if ($dataDir -and (Test-Path -LiteralPath $dataDir)) {
                try {
                    foreach ($k in @(Get-ChildItem -LiteralPath $tmpData -Force)) {
                        Copy-Item -LiteralPath $k.FullName -Destination $dataDir -Recurse -Force
                    }
                    Remove-Item -LiteralPath $tmpSave -Recurse -Force
                    $back = $true
                } catch {}
            }
            if ($back) {
                Write-Host "`n[!] Tus datos del mod se han devuelto a $dataDir." -ForegroundColor Yellow
            } else {
                Write-Host "`n[!] Tus datos del mod NO se han perdido, estan guardados en:" -ForegroundColor Yellow
                Write-Host "    $tmpData"
                Write-Host "    Copia ese contenido a accessibility\data del juego cuando la instalacion funcione."
            }
        }
    }
    Fail "$err (linea $line)"
}
