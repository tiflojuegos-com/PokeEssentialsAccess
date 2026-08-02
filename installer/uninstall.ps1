<#
  Desinstalador del toolkit PokeAccess. Quita el cargador de mkxp.json y borra la
  carpeta accessibility\. No toca Scripts.rxdata ni partidas guardadas.
#>
param([string]$GameDir)

$ErrorActionPreference = "Stop"
$marker = "accessibility/preload_access.rb"
# UTF-8 sin BOM y -LiteralPath en todas las rutas, por los mismos motivos que el instalador:
# mkxp-z lee el json en crudo y las carpetas de juego suelen llevar corchetes ("Pokemon X [v2.0]").
$utf8 = New-Object System.Text.UTF8Encoding($false)

function Pause-Exit { Write-Host "`nPulsa una tecla para salir..."; try { [void][System.Console]::ReadKey($true) } catch {} }
function Fail($msg) { Write-Host "`n[ERROR] $msg" -ForegroundColor Red; Pause-Exit; exit 1 }

# opens the Windows folder picker (accessible with a screen reader); falls back to a
# typed path if it cannot be shown or is cancelled.
function Pick-Folder {
    try {
        Add-Type -AssemblyName System.Windows.Forms
        $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
        $dlg.Description = "Elige la carpeta del juego a desinstalar"
        $dlg.ShowNewFolderButton = $false
        if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { return $dlg.SelectedPath }
    } catch {}
    Write-Host "Escribe o pega la ruta de la carpeta del juego y pulsa Enter:"
    return (Read-Host).Trim('"')
}

# reads a text file with the encoding it REALLY has: strict UTF-8 first, cp1252 after. Copia deliberada
# del helper del instalador (cada script tiene que poder ejecutarse solo). Devuelve tambien la
# codificacion porque reescribir el fichero con otra distinta le corrompe al jugador el windowTitle
# acentuado: leer ANSI como UTF-8 mete U+FFFD y guardarlo lo deja asi para siempre.
function Read-TextFile($path) {
    $bytes  = [System.IO.File]::ReadAllBytes($path)
    $strict = New-Object System.Text.UTF8Encoding($false, $true)
    try { return [pscustomobject]@{ Text = $strict.GetString($bytes); Encoding = $utf8 } }
    catch {
        $ansi = [System.Text.Encoding]::GetEncoding(1252)
        return [pscustomobject]@{ Text = $ansi.GetString($bytes); Encoding = $ansi }
    }
}

# drops whole // comment lines. mkxp-z los ignora, asi que una copia comentada de una clave no es la que
# hay que editar ni cuenta como presente. Misma regla que el launcher (mkxp.rs: strip_comment_lines).
function Strip-CommentLines($text) {
    return ((($text -split "`n") | Where-Object { -not $_.TrimStart().StartsWith("//") }) -join "`n")
}

# offset of the "preloadScript" key mkxp-z will honour, skipping any commented-out copy; -1 when every
# occurrence is commented or absent.
function Find-ActiveKey($text) {
    $from = 0
    while ($from -lt $text.Length) {
        $pos = $text.IndexOf('"preloadScript"', $from, [System.StringComparison]::Ordinal)
        if ($pos -lt 0) { return -1 }
        $nl = $text.LastIndexOf("`n", $pos)
        $start = $(if ($nl -lt 0) { 0 } else { $nl + 1 })
        if (-not $text.Substring($start, $pos - $start).TrimStart().StartsWith("//")) { return $pos }
        $from = $pos + 1
    }
    return -1
}

# true when a comma separated slice of the array holds the marker as its only live value.
function Test-MarkerEntry($entry) {
    return ((Strip-CommentLines $entry).Trim().Trim('"') -eq $marker)
}

# Retira el cargador del array preloadScript VIVO, entrada a entrada, dejando cada trozo restante byte a
# byte (asi sobreviven los saltos de linea y los // del jugador, y ningun comentario se traga el corchete
# de cierre). Antes se hacia con un regex de bloque sobre '"preloadScript"\s*:\s*\[".*?"\],' que borraba
# el ARRAY ENTERO: con ["accessibility/preload_access.rb", "mi_script.rb"] se llevaba tambien el script
# del jugador, y ese bloque lo tienen 11 de los 12 mkxp.json reales. Misma semantica que el launcher
# (mkxp.rs: remove_marker), que es la implementacion de referencia.
function Remove-Marker($text) {
    $key = Find-ActiveKey $text
    if ($key -lt 0) { return $text }
    $open = $text.IndexOf("[", $key)
    if ($open -lt 0) { return $text }
    $close = $text.IndexOf("]", $open)
    if ($close -lt 0) { return $text }
    $kept = @()
    foreach ($e in ($text.Substring($open + 1, $close - $open - 1) -split ",")) {
        if ($e.Length -eq 0 -or (Test-MarkerEntry $e)) { continue }
        $kept += $e
    }
    return ($text.Substring(0, $open + 1) + ($kept -join ",") + $text.Substring($close))
}

# true when any executable of the game folder is running from THIS folder. Se mira la carpeta entera y no
# solo el ejecutable principal (que el instalador identifica leyendo los .exe en busca de "preloadScript")
# porque desinstalar no necesita ese escaneo de cientos de MB y un lanzador secundario abierto bloquea las
# DLL igual. GetProcessesByName y no Get-Process -Name: el segundo interpreta comodines y un ejecutable
# con corchetes en el nombre no casaria consigo mismo.
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

# Cuerpo dentro de un try: con $ErrorActionPreference = Stop un fallo no previsto cerraria la
# ventana sin la pausa final, y quien no ve la pantalla no se enteraria de nada.
try {

    if (-not $GameDir) { $GameDir = Pick-Folder }
    if (-not $GameDir -or -not (Test-Path -LiteralPath $GameDir)) { Fail "No se eligio una carpeta valida." }

    # Con el juego abierto sus DLL de voz estan cargadas: Remove-Item revienta a media carpeta y, si el
    # cargador ya se hubiera retirado, el juego quedaria con accessibility\ a medio borrar y sin mod. Se
    # comprueba ANTES de tocar nada, como hace el instalador antes de recopiar.
    if (Test-GameRunning $GameDir) { Fail "El juego esta abierto. Cierralo del todo y vuelve a ejecutar el desinstalador." }

    $json = Join-Path $GameDir "mkxp.json"
    $bak  = "$json.access.bak"
    # Retirada quirurgica SIEMPRE, tambien habiendo copia de seguridad: el .bak es una foto del
    # mkxp.json del dia de la instalacion, y restaurarlo entero le desharia al jugador la resolucion,
    # el pantalla completa o cualquier ajuste que cambiase despues. Se quita solo el cargador y el
    # .bak se queda en disco como red de seguridad manual.
    if (Test-Path -LiteralPath $json) {
        $src   = Read-TextFile $json
        $clean = Remove-Marker $src.Text
        # El rotulo lo escribian las versiones viejas del instalador (lo tienen 11 de los 12 juegos
        # reales). Retirando solo la entrada se quedaria apuntando a un cargador que ya no esta.
        $clean = $clean -replace '(?m)^[ \t]*//[ \t]*=== MOD DE ACCESIBILIDAD.*(\r?\n)?', ''
        if ($clean -ne $src.Text) {
            # Se reescribe SOLO si de verdad cambio algo, y con la codificacion con la que se leyo: un
            # fichero que el mod nunca toco conserva sus bytes y su fecha.
            [System.IO.File]::WriteAllText($json, $clean, $src.Encoding)
            Write-Host "[OK] Cargador retirado de mkxp.json." -ForegroundColor Green
        } else {
            Write-Host "[OK] El cargador no estaba en mkxp.json (nada que retirar)." -ForegroundColor Green
        }
    }

    $dst = Join-Path $GameDir "accessibility"
    $keptByUser = $false
    if (Test-Path -LiteralPath $dst) {
        # Aviso antes de borrar: en accessibility\data viven la configuracion del mod, las etiquetas de
        # objetos, los nombres de mapa que el jugador se ha puesto y sus grabaciones, y se van con la carpeta.
        Write-Host "`n[AVISO] Se va a borrar la carpeta accessibility del juego." -ForegroundColor Yellow
        Write-Host "Con ella se borran tu configuracion del mod, tus etiquetas de objetos, tus nombres de mapa"
        Write-Host "y tus grabaciones (todo lo de accessibility\data)."
        Write-Host "Si quieres guardarlas, copia esa carpeta a otro sitio antes de seguir."
        $ans = (Read-Host "Borrar la carpeta accessibility? (s/N)").Trim().ToLowerInvariant()
        if ($ans -eq "s" -or $ans -eq "si") {
            Remove-Item -LiteralPath $dst -Recurse -Force
            Write-Host "[OK] Carpeta accessibility eliminada." -ForegroundColor Green
        } else {
            $keptByUser = $true
            Write-Host "[i] Carpeta accessibility conservada; el juego ya no la carga." -ForegroundColor Yellow
        }
    }

    Write-Host "`nMod desinstalado. El juego queda como estaba." -ForegroundColor Cyan
    if (Test-Path -LiteralPath $bak) {
        Write-Host "Se conserva la copia del mkxp.json original en:"
        Write-Host "    $bak"
        Write-Host "Solo hace falta si algo quedo raro: copiala encima de mkxp.json (perderias los ajustes hechos despues)."
    }
    if (-not $keptByUser) {
        # Con el juego en una carpeta de solo lectura (Archivos de programa), Windows le desvia las
        # escrituras a AppData\Local\VirtualStore: alli puede quedar otra copia de accessibility.
        Write-Host "Si el juego esta en una carpeta de solo lectura (Archivos de programa), Windows pudo dejar otra"
        Write-Host "copia de accessibility en AppData\Local\VirtualStore; borrala a mano si la encuentras."
    }
    Pause-Exit
}
catch {
    Fail "$($_.Exception.Message) (linea $($_.InvocationInfo.ScriptLineNumber))"
}
