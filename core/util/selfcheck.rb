module PokeAccess
  # In-engine verification of what the test harness can only FAKE. The suite runs on hand-written stubs,
  # so a stub more permissive than mkxp-z means a green suite and a mod that dies in the game -- the one
  # gap no CI run can close. Run from the debug menu inside a real game, this probes the live engine for
  # the assumptions the stubs hard-code, lists every hook that failed to bind HERE, and writes it all to
  # data/selfcheck.txt for the player to read back or attach to a report.
  module SelfCheck
    # Each probe: [label, ok?, detail-or-nil]. Curated to the surface the readers actually lean on; a
    # probe that raises is itself the finding.
    def self.probes
      out = []
      out.push(probe("graphics") { Graphics.width.to_i > 0 && Graphics.height.to_i > 0 })
      out.push(probe("input virtual (boton aceptar)") { Input.trigger?(Input::C); true })
      out.push(probe("mapa del juego") { !!($game_map && $game_map.respond_to?(:events)) })
      out.push(probe("jugador en mapa") { !!($game_player && $game_player.x.is_a?(Integer)) })
      out.push(probe("entrenador global") { !!(defined?($Trainer) && $Trainer) || !!(defined?($player) && $player) })
      out.push(probe("pbDrawTextPositions (captura)") { !!defined?(pbDrawTextPositions) })
      out.push(probe("_INTL (traductor del juego)") { !!defined?(_INTL) })
      out.push(probe("pictures (pantallas de imagen)") { !!($game_screen && $game_screen.pictures) })
      out.push(probe("audio 3D (PA3D_steam.dll con PA3D_Pitch)") { !!(PokeAccess::Audio3D.available? && PokeAccess::Audio3D::PITCH) })
      out.push(probe("data/ escribible") do
        f = "#{PokeAccess::Paths::DATA}/selfcheck_probe.tmp"
        File.open(f, "w") { |h| h.write("x") }
        File.delete(f)
        true
      end)
      out
    end

    def self.probe(label)
      ok = false
      detail = nil
      begin
        ok = yield ? true : false
      rescue Exception => e
        detail = "#{e.class}: #{e.message}"
      end
      [label, ok, detail]
    end

    # Engine facts worth recording even though they are not pass/fail: which era the mod detected, what
    # language the build declares, and whether this game's script patch turns Array#+ into an in-place
    # mutator (the MTS landmine the whole style guard exists for).
    def self.facts
      a = [1]
      b = (a + [2] rescue a)
      mts = a.equal?(b)
      [
        "motor: #{(PokeAccess::Engine.gamedata? rescue false) ? 'gamedata' : 'gen6'}",
        "idioma de build: #{(PokeAccess::GameLang.declared_name rescue nil) || 'sin declarar'}",
        "Array#+ mutador (MTS): #{mts ? 'SI' : 'no'}",
        "extractores registrados: #{(PokeAccess::Menus::EXTRACTORS.length rescue '?')}",
        "cuadros con texto registrados: #{(PokeAccess::PictureCues::TEXTS.length rescue '?')}",
        "audio 3D: dispositivo #{(PokeAccess::Audio3D.device_rate rescue nil) || 'sin arrancar'} Hz, latencia #{(PokeAccess::Audio3D.device_latency rescue nil) || '?'} ms"
      ]
    end

    # Runs everything, writes the report and speaks the two numbers that matter: probes failed and hooks
    # that never bound in THIS game (non-optional ones; an :optional miss is variance, not a fault).
    def self.run
      lines = ["=== autochequeo #{Time.now.strftime('%Y-%m-%d %H:%M') rescue ''} ==="]
      bad = 0
      probes.each do |label, ok, detail|
        bad += 1 unless ok
        lines.push("#{ok ? '[ok]  ' : '[MAL] '}#{label}#{detail ? " -> #{detail}" : ''}")
      end
      facts.each { |f| lines.push("[dato] #{f}") }
      miss = (PokeAccess::Hooks.missing rescue []) || []
      lines.push("hooks sin atar aqui: #{miss.length}")
      miss.each { |m| lines.push("  falta #{m}") }
      saved = ((File.open("#{PokeAccess::Paths::DATA}/selfcheck.txt", "a") { |f| f.write(lines.join("\n") + "\n\n") }; true) rescue false)
      PokeAccess.speak(PokeAccess::I18n.t(saved ? :sc_done : :sc_not_saved, :bad => bad, :miss => miss.length), true)
    rescue Exception => e
      (PokeAccess.speak(PokeAccess::I18n.t(:diag_error, :err => e.class.to_s), true) rescue nil)
    end
  end
end
