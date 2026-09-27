# Africanvs's chariot race (CarreraCuadrigasScene, a script of the game's own): the tutorial strip page by page, and
# the race from the scene's state each frame. The info key holds the whole race line.
module PokeAccess
  module AfricanusRace
    # The tutorial pages as tutorial.png and tutorial_eng.png paint them, by the sprite name the scene uses, the key
    # icons in words; :diagram stands for page II's two track drawings.
    TUTORIAL = {
      "tutorial" => [
        ["TUTORIAL (I) - Movimiento lateral. Pulsando las teclas Arriba y Abajo se realizan los desplazamientos " \
         "laterales, con los que adelantar, golpear o esquivar contrincantes. X: Cerrar. Derecha: TUTO (II) Turbo."],
        ["TUTORIAL (II) - Turbo y freno. Pulsando las teclas Izquierda y Derecha se cambia la velocidad. (Depende de " \
         "la zona).", :diagram, "Izquierda: TUTO (I) Mov. lateral. X: Cerrar. Derecha: TUTO (III) Colisiones."],
        ["TUTORIAL (III) - Colisiones. Al entrar en contacto con otra cuadriga, un muro exterior o la Spina (centro) " \
         "se produce una colisión que causa daños. Tras el golpe, los corredores se repelerán y frenarán un poco. " \
         "Izquierda: TUTO (II) Turbo. X: Cerrar. Derecha: TUTO (IV) Interfaz."],
        ["TUTORIAL (IV) - Interfaz. Contador de vueltas. Posición en carrera. PS y Turbo. Control de velocidad. " \
         "Izquierda: TUTO (III) Colisiones. X: Cerrar."]
      ],
      "tutorial_eng" => [
        ["TUTORIAL (I) - Lateral movement. By pressing the Up and Down keys, you can move laterally to overtake, hit " \
         "or dodge opponents. X: Exit. Right: TUTO (II) Turbo."],
        ["TUTORIAL (II) - Turbo and braking. Pressing the Left and Right keys changes the speed (depends on the " \
         "zone).", :diagram, "Left: TUTO (I) Lat. Movement. X: Exit. Right: TUTO (III) Collisions."],
        ["TUTORIAL (III) - Collisions. Contact with another chariot, an outer wall or the Spina (center) causes a " \
         "collision that results in damage. After the collision, the runners will be repelled and will slow down a " \
         "little. Left: TUTO (II) Turbo. X: Exit. Right: TUTO (IV) Interface."],
        ["TUTORIAL (IV) - Interface. Lap counter. Race position. HP and Turbo. Speed control. Left: TUTO (III) " \
         "Collisions. X: Exit."]
      ]
    }

    # The laps that end the race (loopRace returns on the seventh) and the frames a place must hold to be said.
    LAPS = 7
    PLACE_SETTLE = 20

    @scene = nil
    @kind = nil

    # Holds the scene while its tutorial or its race loop runs.
    def self.hold(scene, kind); @scene = scene; @kind = kind; end

    # Lets the scene go, and its page or race line leaves the info key.
    def self.release
      PokeAccess::Info.clear_text if @kind
      @scene = nil
      @kind = nil
    end

    # Per-frame entry point: the held phase's reader, or nothing.
    def self.poll
      return unless @scene
      @kind == :tutorial ? tutorial(@scene) : race(@scene)
    rescue StandardError
      nil
    end

    # The tutorial's sprite name and sprite, or nil.
    def self.tutorial_sprite(scene)
      h = PokeAccess.ivar(scene, :@sprites)
      return nil unless h.is_a?(Hash)
      key = TUTORIAL.keys.find { |k| h[k] }
      key ? [key, h[key]] : nil
    end

    # Reads page I on sight, then the next or previous page as each slide starts (x falling or rising); the closing
    # slide, made unseen, says nothing.
    def self.tutorial(scene)
      key, spr = tutorial_sprite(scene)
      return unless spr
      x = (spr.x rescue nil)
      return if x.nil?
      last = PokeAccess.ivar(scene, :@pa_afr_tuto_x)
      scene.instance_variable_set(:@pa_afr_tuto_x, x)
      page = PokeAccess.ivar(scene, :@pa_afr_tuto_page)
      return say_page(scene, key, 1) if page.nil?
      if x == last
        scene.instance_variable_set(:@pa_afr_tuto_sliding, false)
        return
      end
      return if PokeAccess.ivar(scene, :@pa_afr_tuto_sliding) || (spr.opacity rescue 0).to_i <= 0
      scene.instance_variable_set(:@pa_afr_tuto_sliding, true)
      say_page(scene, key, page + (x < last ? 1 : -1))
    end

    # Says one page of the strip (clamped to it) and keeps it for the info key.
    def self.say_page(scene, key, page)
      pages = TUTORIAL[key]
      page = [[page, 1].max, pages.length].min
      scene.instance_variable_set(:@pa_afr_tuto_page, page)
      t = page_text(pages[page - 1])
      PokeAccess::Info.set_info(:text, t)
      PokeAccess.speak(t, true)
    end

    # A page's parts as one line: the transcription with the keys as the player has them, and page II's drawings
    # said as the race says each half.
    def self.page_text(parts)
      diagram = "#{PokeAccess::I18n.t(:afr_race_top)}. #{PokeAccess::I18n.t(:afr_race_bottom)}."
      parts.map { |p| p == :diagram ? diagram : PokeAccess::KeyHints.localize(p) }.join(" ")
    end

    # The race: the countdown until the start, then lap, track, place, HP and turbo.
    def self.race(scene)
      q = (PokeAccess.ivar(scene, :@cuadrigas) || [])[0]
      return unless q
      return countdown(scene) unless PokeAccess.ivar(scene, :@estado) == 1
      lap(scene, q)
      track(scene, q)
      place(scene, q)
      hp(scene, q)
      turbo(scene, q)
    end

    # The countdown numeral (III, II, I, rows of orden.png) as a digit, once as each flashes in.
    def self.countdown(scene)
      spr = PokeAccess.sprite(scene, "contador")
      return unless spr && (spr.opacity rescue 0).to_i > 0
      h = (spr.src_rect.height rescue 0).to_i
      return if h <= 0
      n = ((spr.src_rect.y rescue 0).to_i / h) + 1
      PokeAccess.speak(n.to_s, true) if PokeAccess::Cursor.changed?(scene, :afr_race_count, n)
    end

    # The lap being run, at the start and as each one begins.
    def self.lap(scene, q)
      n = (q.vueltas rescue 0).to_i + 1
      return unless PokeAccess::Cursor.changed?(scene, :afr_race_lap, n)
      say(scene, PokeAccess::I18n.t(:afr_race_lap, :n => n, :total => LAPS), true)
    end

    # Says the half of the track the chariot enters, with what the arrows do there, and each change between curve and
    # straight after the start.
    def self.track(scene, q)
      half = top_half?(scene, q) ? :afr_race_top : :afr_race_bottom
      say(scene, PokeAccess::I18n.t(half), false) if PokeAccess::Cursor.changed?(scene, :afr_race_half, half)
      bend = (q.girando rescue false) ? :afr_race_curve : :afr_race_straight
      fresh = PokeAccess::Cursor.current(scene, :afr_race_bend).nil?
      return unless PokeAccess::Cursor.changed?(scene, :afr_race_bend, bend) && !fresh
      say(scene, PokeAccess::I18n.t(bend), false)
    end

    # True while the chariot is above the track's middle line, by the position the scene keeps for it.
    def self.top_half?(scene, q)
      pos = (PokeAccess.ivar(scene, :@cuadrigasPos) || {})[q]
      mid = (PokeAccess.const_at("CarreraCuadrigasScene::CENTRO_Y") || 885).to_f
      pos ? (pos.y rescue mid).to_f < mid : true
    end

    # Says the place once it has held for PLACE_SETTLE frames.
    def self.place(scene, q)
      n = (q.orden rescue 0).to_i
      return if n <= 0
      run = PokeAccess.ivar(scene, :@pa_afr_place)
      run = (run && run[0] == n) ? [n, run[1] + 1] : [n, 1]
      scene.instance_variable_set(:@pa_afr_place, run)
      return if run[1] < PLACE_SETTLE
      return unless PokeAccess::Cursor.changed?(scene, :afr_race_place, n)
      say(scene, PokeAccess::I18n.t(:afr_race_place, :n => n), false)
    end

    # The HP a hit leaves, once its loss has drained (golpeado turns back off), when it moved.
    def self.hp(scene, q)
      hit = (q.golpeado rescue false) ? true : false
      was = PokeAccess.ivar(scene, :@pa_afr_hit)
      scene.instance_variable_set(:@pa_afr_hit, hit)
      return unless was && !hit
      n = (q.ps rescue 0).to_f.round
      return unless PokeAccess::Cursor.changed?(scene, :afr_race_hp, n)
      say(scene, PokeAccess::I18n.t(:afr_race_hp, :n => n), false)
    end

    # Says the turbo a sprint leaves when it ends (aceleracion leaves 2), and when it runs out.
    def self.turbo(scene, q)
      st = (q.stamina rescue 0).to_f
      sprinting = (q.aceleracion rescue 0).to_i == 2
      was = PokeAccess.ivar(scene, :@pa_afr_sprint)
      scene.instance_variable_set(:@pa_afr_sprint, sprinting)
      key = st <= 0 ? :empty : st.round
      return unless key == :empty || (was && !sprinting)
      return unless PokeAccess::Cursor.changed?(scene, :afr_race_turbo, key)
      t = key == :empty ? PokeAccess::I18n.t(:afr_race_turbo_empty) : PokeAccess::I18n.t(:afr_race_turbo, :n => key)
      say(scene, t, false)
    end

    # The whole race line the info key repeats.
    def self.status(scene)
      q = (PokeAccess.ivar(scene, :@cuadrigas) || [])[0]
      PokeAccess::I18n.t(:afr_race_status, :lap => (q.vueltas rescue 0).to_i + 1, :total => LAPS,
                         :place => (q.orden rescue 0).to_i, :hp => (q.ps rescue 0).to_f.round,
                         :turbo => (q.stamina rescue 0).to_f.round)
    end

    # Speaks a race line and refreshes the one the info key holds.
    def self.say(scene, text, interrupt)
      PokeAccess.speak(text, interrupt)
      PokeAccess::Info.set_info(:text, status(scene))
    end
  end
end

PokeAccess::Game.define("africanus") do
  [[:showTutorial, :tutorial], [:loopRace, :race]].each do |meth, kind|
    around("CarreraCuadrigasScene", meth) do |scene, nxt, _a|
      PokeAccess::AfricanusRace.hold(scene, kind)
      begin
        nxt.call
      ensure
        PokeAccess::AfricanusRace.release
      end
    end
  end
  poll_each_frame { PokeAccess::AfricanusRace.poll }
end
