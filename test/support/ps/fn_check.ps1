# Extracts Find-LiveLine and Test-GameRunning from install.ps1 via the PowerShell AST and drives them
# against fixtures, printing one token per check. Run by test/static/installer_behavior_spec.rb; the
# tokens are the contract (LIVE-OK / NOTRUN-OK / RUN-OK / RUN-SKIP).
param([string]$InstallPs1, [string]$Scratch)

$errs = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($InstallPs1, [ref]$null, [ref]$errs)
if ($errs -and $errs.Count -gt 0) { Write-Output "PARSE-FAIL $($errs[0].Message)"; exit 1 }
$fns = $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)
foreach ($name in @('Find-LiveLine', 'Test-GameRunning')) {
    $fn = $fns | Where-Object { $_.Name -eq $name } | Select-Object -First 1
    if (-not $fn) { Write-Output "MISSING-$name"; exit 1 }
    . ([scriptblock]::Create($fn.Extent.Text))
}

# Find-LiveLine: a // commented twin of the key must not count as present, the live line must, and a file
# with only the commented twin must answer "absent". Split keeps the separators, so the live line sits at
# index 4 exactly when the commented one at index 2 was skipped.
$both = [regex]::Split("{`n// `"preloadScript`": [muerta]`n  `"preloadScript`": [`n}", '(\r?\n)')
$live = Find-LiveLine $both '"preloadScript"\s*:\s*\['
$dead = [regex]::Split("{`n// `"preloadScript`": [muerta]`n}", '(\r?\n)')
$none = Find-LiveLine $dead '"preloadScript"\s*:\s*\['
if ($live -eq 4 -and $none -eq -1) { Write-Output "LIVE-OK" } else { Write-Output "LIVE-FAIL live=$live none=$none" }

# Test-GameRunning: an empty folder and a folder whose exe exists but is not running must both say no.
$empty = Join-Path $Scratch "tg_empty"; New-Item -ItemType Directory -Force $empty | Out-Null
$fake  = Join-Path $Scratch "tg_fake";  New-Item -ItemType Directory -Force $fake  | Out-Null
Set-Content -LiteralPath (Join-Path $fake "juego.exe") -Value "no soy un pe"
$a = Test-GameRunning $empty
$b = Test-GameRunning $fake
if (-not $a -and -not $b) { Write-Output "NOTRUN-OK" } else { Write-Output "NOTRUN-FAIL vacio=$a parado=$b" }

# The true positive -- the check that catches a mutant returning $false forever. Windows only: it runs a
# real process from the fixture folder (a copied cmd.exe pinging localhost) and expects detection by
# name + path. Elsewhere the half-check is declared skipped, never silently passed -- and so is a machine
# whose policy blocks copying or launching that process: RUN-FAIL is reserved for a process that IS
# running and goes undetected.
if ($env:OS -eq "Windows_NT") {
    $rundir = Join-Path $Scratch "tg_run"; New-Item -ItemType Directory -Force $rundir | Out-Null
    $exe = Join-Path $rundir "fakegame_pa.exe"
    $p = $null
    try {
        Copy-Item -LiteralPath (Join-Path $env:SystemRoot "System32\cmd.exe") -Destination $exe -Force -ErrorAction Stop
        $p = Start-Process -FilePath $exe -ArgumentList "/c", "ping -n 6 127.0.0.1 > nul" -PassThru -WindowStyle Hidden -ErrorAction Stop
    } catch { $p = $null }
    if ($null -eq $p) {
        Write-Output "RUN-SKIP (el entorno no dejo copiar o lanzar el proceso de prueba)"
    } else {
        try {
            Start-Sleep -Milliseconds 500
            if ($p.HasExited) { Write-Output "RUN-SKIP (el proceso de prueba termino antes de la comprobacion)" }
            elseif (Test-GameRunning $rundir) { Write-Output "RUN-OK" } else { Write-Output "RUN-FAIL" }
        } finally {
            try { Stop-Process -Id $p.Id -Force } catch {}
        }
    }
} else {
    Write-Output "RUN-SKIP"
}
