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

# Cuerpo dentro de un try: con $ErrorActionPreference = Stop un fallo no previsto cerraria la
# ventana sin la pausa final, y quien no ve la pantalla no se enteraria de nada.
try {

    if (-not $GameDir) { $GameDir = Pick-Folder }
    if (-not $GameDir -or -not (Test-Path -LiteralPath $GameDir)) { Fail "No se eligio una carpeta valida." }

    $json = Join-Path $GameDir "mkxp.json"
    $bak  = "$json.access.bak"
    # Retirada quirurgica SIEMPRE, tambien habiendo copia de seguridad: el .bak es una foto del
    # mkxp.json del dia de la instalacion, y restaurarlo entero le desharia al jugador la resolucion,
    # el pantalla completa o cualquier ajuste que cambiase despues. Se quita solo el cargador y el
    # .bak se queda en disco como red de seguridad manual.
    if (Test-Path -LiteralPath $json) {
        $content = Get-Content -LiteralPath $json -Raw -Encoding UTF8
        $content = $content -replace '(?s)\{\s*// === MOD DE ACCESIBILIDAD.*?"preloadScript"\s*:\s*\[".*?"\],\s*', "{`n"
        $content = $content -replace ('"' + [regex]::Escape($marker) + '"\s*,\s*'), ""
        $content = $content -replace ('\s*,\s*"' + [regex]::Escape($marker) + '"'), ""
        $content = $content -replace ('"' + [regex]::Escape($marker) + '"'), ""
        [System.IO.File]::WriteAllText($json, $content, $utf8)
        Write-Host "[OK] Cargador retirado de mkxp.json." -ForegroundColor Green
    }

    $dst = Join-Path $GameDir "accessibility"
    $keptByUser = $false
    if (Test-Path -LiteralPath $dst) {
        # Aviso antes de borrar: en accessibility\data viven la configuracion del mod y las etiquetas
        # de objetos que el jugador se ha ido poniendo, y se van con la carpeta.
        Write-Host "`n[AVISO] Se va a borrar la carpeta accessibility del juego." -ForegroundColor Yellow
        Write-Host "Con ella se borran tu configuracion del mod y tus etiquetas de objetos (accessibility\data)."
        Write-Host "Si quieres guardarlas, copia esa carpeta a otro sitio antes de seguir."
        $ans = (Read-Host "Borrar la carpeta accessibility? (s/N)").Trim().ToLower()
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
