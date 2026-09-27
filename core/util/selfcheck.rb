module PokeAccess
  # Debug-menu self-check in the real game: probes the live engine for what the test stubs assume, lists the
  # hooks that failed to bind, and appends it all to selfcheck.txt in the data folder.
  module SelfCheck
    # The engine probes, each [label, ok?, detail-or-nil]; a probe that raises fails with the error as detail.
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

    # Engine facts that are not pass/fail: the era, the build's language, whether Array#+ mutates in place (MTS),
    # the registry sizes and the 3D audio device.
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

    # Runs everything, appends the report and speaks how many probes failed and how many hooks never bound here.
    def self.run
      lines = ["=== autochequeo #{Time.now.strftime('%Y-%m-%d %H:%M') rescue ''} ==="]
      bad = 0
      probes.each do |label, ok, detail|
        bad += 1 unless ok
        lines.push("#{ok ? '[ok]  ' : '[MAL] '}#{label}#{detail ? " -> #{detail}" : ''}")
      end
      facts.each { |f| lines.push("[dato] #{f}") }
      miss = (PokeAccess::Hooks.missing + PokeAccess::Hooks.unbound rescue []) || []
      lines.push("hooks sin atar aqui: #{miss.length}")
      miss.each { |m| lines.push("  falta #{m}") }
      saved = ((File.open("#{PokeAccess::Paths::DATA}/selfcheck.txt", "a") { |f| f.write(lines.join("\n") + "\n\n") }; true) rescue false)
      PokeAccess.speak(PokeAccess::I18n.t(saved ? :sc_done : :sc_not_saved, :bad => bad, :miss => miss.length), true)
    rescue Exception => e
      (PokeAccess.speak(PokeAccess::I18n.t(:diag_error, :err => e.class.to_s), true) rescue nil)
    end
  end
end
