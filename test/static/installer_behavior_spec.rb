# Behaviour layer for the installer pair, on top of installer_spec's parse + textual locks: the two
# helper functions nothing executed (Find-LiveLine deciding where the loader is registered, and
# Test-GameRunning guarding both scripts' destructive halves) are extracted through the PowerShell AST and
# driven against fixtures, and uninstall.ps1 runs WHOLE against a fake game folder -- the surgical-removal
# promise (our entry out, the player's entries untouched) held only by a regex lock until now.
#
# Same tooling rule as the parse layer: with no pwsh/powershell on PATH the runs are reported as skipped,
# never counted as passed.

# Runs a PowerShell file with arguments, no shell in between (the array form never touches /bin/sh, which
# would mangle $ tokens on Linux). Returns [success, combined output].
def ps_run_file(exe, file, *args)
  out = IO.popen([exe, "-NoProfile", "-NonInteractive", "-File", file] + args,
                 :err => [:child, :out]) { |io| io.read }
  [$?.success?, out.to_s]
rescue StandardError => e
  [nil, e.message.to_s]
end

def ps_shell
  ["pwsh", "powershell"].find do |exe|
    begin
      IO.popen([exe, "-NoProfile", "-NonInteractive", "-Command", "exit 0"], :err => [:child, :out]) { |io| io.read }
      $?.success?
    rescue StandardError
      false
    end
  end
end

Suite.define("static/instalador: Find-LiveLine y Test-GameRunning hacen lo que dicen") do
  root = File.expand_path("../..", File.dirname(__FILE__))
  shell = ps_shell
  if shell.nil?
    puts "  (funciones del instalador sin ejecutar: no hay pwsh ni powershell en PATH)"
    truthy "sin PowerShell el resto de esta suite no aplica", true
  else
    scratch = File.join(File.dirname(__FILE__), "tmp_ps_fn")
    Dir.mkdir(scratch) unless File.directory?(scratch)
    begin
      ok, out = ps_run_file(shell, File.join(root, "test", "support", "ps", "fn_check.ps1"),
                            "-InstallPs1", File.join(root, "installer", "install.ps1"),
                            "-Scratch", scratch)
      truthy "el runner de funciones termina bien: #{out.strip[0, 160]}", ok
      truthy "Find-LiveLine salta la linea comentada y encuentra la viva", out.include?("LIVE-OK")
      truthy "Test-GameRunning dice no con carpeta vacia y con exe parado", out.include?("NOTRUN-OK")
      truthy "y detecta un proceso REAL corriendo desde la carpeta (o declara el salto)",
             out.include?("RUN-OK") || out.include?("RUN-SKIP")
      falsy "el positivo real no fallo", out.include?("RUN-FAIL")
    ensure
      require "fileutils"
      FileUtils.rm_rf(scratch)
    end
  end
end

Suite.define("static/instalador: uninstall retira SOLO nuestra entrada de mkxp.json (e2e)") do
  root = File.expand_path("../..", File.dirname(__FILE__))
  shell = ps_shell
  if shell.nil?
    puts "  (e2e de uninstall omitido: no hay pwsh ni powershell en PATH)"
    truthy "sin PowerShell el resto de esta suite no aplica", true
  else
    fixture = File.join(File.dirname(__FILE__), "tmp_fake_game")
    require "fileutils"
    FileUtils.rm_rf(fixture)
    Dir.mkdir(fixture)
    begin
      json = File.join(fixture, "mkxp.json")
      File.open(json, "wb") do |f|
        f.write("{\r\n")
        f.write("  // === MOD DE ACCESIBILIDAD (auto) ===\r\n")
        f.write("  \"preloadScript\": [\r\n")
        f.write("    \"accessibility/preload_access.rb\",\r\n")
        f.write("    \"mods/usuario.rb\"\r\n")
        f.write("  ],\r\n")
        f.write("  \"windowTitle\": \"Juego\"\r\n")
        f.write("}\r\n")
      end
      ok, out = ps_run_file(shell, File.join(root, "installer", "uninstall.ps1"), "-GameDir", fixture)
      truthy "uninstall.ps1 termina bien sobre el juego de mentira: #{out.strip[0, 160]}", ok
      after = File.read(json)
      falsy "nuestra entrada ya no esta", after.include?("preload_access.rb")
      falsy "y el rotulo del mod tampoco", after.include?("MOD DE ACCESIBILIDAD")
      truthy "la entrada del jugador sigue", after.include?("mods/usuario.rb")
      truthy "el array preloadScript sigue existiendo", after =~ /"preloadScript"\s*:\s*\[/ ? true : false
      truthy "y el resto del json esta intacto", after.include?("\"windowTitle\": \"Juego\"")
    ensure
      FileUtils.rm_rf(fixture)
    end
  end
end

# The S109 lock: the installer seals what it VERIFIED against the source tree, not merely what it found
# deployed -- the verification block must exist and abort unsealed.
Suite.define("static/instalador: el despliegue se verifica contra el ORIGEN antes de sellar") do
  root = File.expand_path("../..", File.dirname(__FILE__))
  inst = File.read(File.join(root, "installer", "install.ps1"))
  truthy "install.ps1 anota cada arbol que copia", inst.include?("$script:deployed += @{ Src = $src; Dst = $dstDir }")
  truthy "y verifica esa lista, fichero a fichero, contra el destino", inst.include?("foreach ($pair in $script:deployed)")
  truthy "y aborta sin sellar cuando falta un archivo", inst.include?("No se sella nada")
  vpos = inst.index("foreach ($pair in $script:deployed)")
  spos = inst.index("Sellar installed.json")
  truthy "la verificacion ocurre ANTES del sello", vpos && spos && vpos < spos
end
