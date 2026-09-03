# installer/ had no coverage of any kind: not a behaviour test, not even a syntax parse. A mutation sweep
# put nine changes past the whole suite, syntax errors among them -- and a broken param() block ships in the
# release zip, where the first person to notice is a blind player who cannot install the mod at all. Two of
# those mutations were worse than a crash: they install quietly and leave the game mute.
#
# Two layers, because one of them needs a tool that CI may not have:
#   - the real PowerShell parser, when pwsh or powershell is on PATH. It knows all the syntax; a pattern
#     list only knows what it was taught.
#   - textual invariants, always. These encode the rules the two scripts must keep between them, which no
#     parser can check.
#
# Absent PowerShell the parse is reported as skipped and the invariants still run. Saying OK for a check
# that did not happen is the failure mode the 1.8.7 sweep already taught this repo.
Suite.define("static/instalador: los .ps1 parsean y respetan su contrato") do
  root = File.expand_path("../..", File.dirname(__FILE__))
  inst = File.read(File.join(root, "installer", "install.ps1"))
  unin = File.read(File.join(root, "installer", "uninstall.ps1"))

  # Sin shell de por medio a proposito: en Linux los backticks de Ruby pasan por /bin/sh, que expande $e y
  # $null a cadena vacia y le entrega a PowerShell un guion mutilado. La forma de array no invoca ningun shell.
  run_ps = lambda do |exe, script|
    begin
      out = IO.popen([exe, "-NoProfile", "-NonInteractive", "-Command", script],
                     :err => [:child, :out]) { |io| io.read }
      [$?.success?, out.to_s]
    rescue StandardError => e
      [nil, e.message.to_s]
    end
  end

  shell = ["pwsh", "powershell"].find { |exe| run_ps.call(exe, "exit 0")[0] }

  if shell
    ["install.ps1", "uninstall.ps1"].each do |name|
      path = File.join(root, "installer", name).tr("\\", "/")
      script = "$e = $null; " \
               "[void][System.Management.Automation.Language.Parser]::ParseFile('#{path}', [ref]$null, [ref]$e); " \
               "if ($e -and $e.Count -gt 0) { $e[0].Message } else { 'PARSE-OK' }"
      ok, out = run_ps.call(shell, script)
      Assert.check("#{name} parsea con el parser de PowerShell",
                   ok && out.include?("PARSE-OK"), out.strip[0, 200])
    end
  else
    puts "  (parse de PowerShell omitido: no hay pwsh ni powershell en PATH)"
  end

  # Un Copy-Item con comodin obliga a -Path, y con -Path unos corchetes en cualquier antepasado de la ruta
  # se leen como clase de caracteres: la copia no casa nada, no lanza, y el mod queda a medio desplegar en
  # una carpeta llamada "Pokemon [v2.0]". El instalador ya declara esa regla en su cabecera.
  wild = inst.split("\n").each_with_index.select do |line, _i|
    l = line.strip
    !l.start_with?("#") && l =~ /Copy-Item/ && l =~ /\*/ && l !~ /-LiteralPath/
  end
  eq("ningun Copy-Item con comodin sin -LiteralPath", wild.map { |l, i| "#{i + 1}: #{l.strip[0, 70]}" }, [])

  # Los dos ficheros del cargador. Si uno no se copia el juego arranca sin mod y el instalador canta [OK]:
  # es la mutacion mas barata de todas y la mas cara para el jugador.
  ["boot.rb", "preload_access.rb"].each do |f|
    truthy("install.ps1 despliega #{f}", inst.include?(f))
  end

  # El contrato entre los dos scripts: la cadena que uno escribe en mkxp.json es la que el otro busca para
  # retirarla. Si divergen, desinstalar deja el cargador dentro y el juego intenta cargar un mod que ya no
  # esta en disco.
  mk = lambda { |src| src[/^\$marker\s*=\s*"([^"]+)"/, 1] }
  eq("install y uninstall comparten el marcador", mk.call(inst), mk.call(unin))
  truthy("el marcador no esta vacio", !mk.call(inst).to_s.empty?)

  # Desinstalar retira la ENTRADA, nunca el array entero: llevarse preloadScript completo borra los scripts
  # que el jugador tenga puestos por su cuenta, y eso no se deshace.
  falsy("uninstall no borra el preloadScript entero",
        unin =~ /"preloadScript"\s*:\s*\[\s*\]\s*"/ ? true : false)

  # A Copy-Item without -LiteralPath re-opens the bracket-path hole through any spelling (a wildcard moved
  # into a variable included); the rule is absolute in both scripts, so the check is too.
  [["install.ps1", inst], ["uninstall.ps1", unin]].each do |name, src|
    loose = src.split("\n").each_with_index.select do |line, _i|
      l = line.strip
      !l.start_with?("#") && l =~ /Copy-Item/ && l !~ /-LiteralPath/
    end
    eq("#{name}: todo Copy-Item usa -LiteralPath", loose.map { |l, i| "#{i + 1}: #{l.strip[0, 60]}" }, [])
  end

  # The loader must be COPIED, not merely mentioned: the marker line alone satisfies a substring check.
  truthy("install.ps1 copia preload_access.rb (no solo lo nombra)",
         inst =~ /Copy-Item\s+-LiteralPath[^\n]*preload_access\.rb/ ? true : false)

  # The marker is pinned from outside: both scripts agreeing on a WRONG path would still uninstall
  # cleanly, but register a loader mkxp-z never finds. This assertion is the external fixture.
  eq("el marcador es la ruta real del cargador", mk.call(inst), "accessibility/preload_access.rb")

  # Each payload root is copied under its exact name; a typo turns the Test-Path guard around it into a
  # silent skip that still prints [OK].
  %w[core loader assets plugins lang games].each do |d|
    truthy("install.ps1 referencia la carpeta #{d}", inst.include?("Join-Path $root \"#{d}\""))
  end

  # The PE machine test that picks the voice DLLs; inverted, a 32-bit game gets 64-bit DLLs and the
  # voice bridge dies while the suite keeps proving that dying quietly is fine.
  truthy("la deteccion de arquitectura compara 0x8664 con -eq", inst =~ /-eq\s+0x8664/ ? true : false)

  # The player-data rescue copies directories too; without -Recurse the backup is a hollow tree and the
  # "Conservados" counter compares the truncation with itself.
  truthy("el rescate de data/ copia con -Recurse",
         inst =~ /Copy-Item[^\n]*\$tmpData[^\n]*-Recurse/ ? true : false)

  # The .bat files are the double-click path a blind player actually uses; each must point at a .ps1 that
  # exists, or PowerShell falls into an interactive prompt no screen reader announces as a failure.
  Dir[File.join(root, "installer", "*.bat")].sort.each do |bat|
    body = File.read(bat)
    refs = body.scan(/%~dp0([^"\s]+\.ps1)/).flatten.uniq
    truthy("#{File.basename(bat)} invoca algun .ps1", !refs.empty?)
    refs.each do |ps|
      truthy("#{File.basename(bat)} -> #{ps} existe", File.exist?(File.join(root, "installer", ps)))
    end
  end
end
