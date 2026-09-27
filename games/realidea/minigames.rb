# Four of Realidea's minigames, each running its own blocking loop: held by an around-hook on that loop and read
# by the per-frame poller.
module PokeAccess
  module RealideaMinigames
    @active = nil
    @kind = nil

    def self.hold(scene, kind); @active = scene; @kind = kind; end
    def self.release; @active = nil; @kind = nil; end

    def self.poll
      return unless @active
      case @kind
      when :ppt     then ppt(@active)
      when :baile   then baile(@active)
      when :postres then postres(@active)
      when :postres_baya then postres_baya(@active)
      end
    rescue StandardError
      nil
    end

    # The partner's directions (the game's own words, also its picture names) as the direction keys.
    DANCE_DIRS = { "Arriba" => :dir_up, "Abajo" => :dir_down, "Izquierda" => :dir_left, "Derecha" => :dir_right }
    # The steps of the four turns together, the total the screen paints after "Aciertos:".
    DANCE_STEPS = 22

    # Dance: each step the partner shows while it dances, the player's turn once it stops, each answer as a hit
    # with the running count or as a miss, and the grade the final picture shows.
    def self.baile(scene)
      baile_demo(scene)
      baile_turn(scene)
      baile_answer(scene)
      baile_grade(scene)
    rescue StandardError
      nil
    end

    # A demonstrated step, once per step of each turn (@direcciones grows while @empezarcuenta is on).
    def self.baile_demo(scene)
      steps = PokeAccess.ivar(scene, :@direcciones)
      return unless PokeAccess.ivar(scene, :@empezarcuenta) && steps.is_a?(Array) && !steps.empty?
      key = [PokeAccess.ivar(scene, :@turno), steps.length]
      PokeAccess::Cursor.announce(scene, :rea_baile_demo, key, true) { dance_word(steps.last) }
    end

    # The player's turn, once per turn: the demonstration has stopped and no pause is running.
    def self.baile_turn(scene)
      return if PokeAccess.ivar(scene, :@empezarcuenta) || PokeAccess.ivar(scene, :@pausa)
      steps = PokeAccess.ivar(scene, :@direcciones)
      return unless steps.is_a?(Array) && !steps.empty?
      PokeAccess::Cursor.announce(scene, :rea_baile_turn, PokeAccess.ivar(scene, :@turno), false) do
        PokeAccess::I18n.t(:rea_baile_turn)
      end
    end

    # Each answer (the pair [@turno, @playermov] moves with every one): a hit when @numaciertos grew, else a miss.
    def self.baile_answer(scene)
      sig = [PokeAccess.ivar(scene, :@turno), PokeAccess.ivar(scene, :@playermov)]
      hits = PokeAccess.ivar_i(scene, :@numaciertos)
      prev = PokeAccess.ivar(scene, :@pa_baile_answer)
      scene.instance_variable_set(:@pa_baile_answer, [sig, hits])
      return if !prev.is_a?(Array) || prev[0] == sig
      key = hits > prev[1].to_i ? :rea_baile_hit : :rea_baile_miss
      PokeAccess.speak(PokeAccess::I18n.t(key, :n => hits, :tot => DANCE_STEPS), true)
    end

    # The grade (S, A, B or C) once its picture is shown.
    def self.baile_grade(scene)
      pic = PokeAccess.sprite(scene, "score")
      return unless pic && (pic.visible rescue false)
      grade = PokeAccess.ivar(scene, :@score).to_s
      return if grade.empty?
      PokeAccess::Cursor.announce(scene, :rea_baile_grade, grade, true) do
        PokeAccess::I18n.t(:rea_baile_grade, :grade => grade)
      end
    end

    # A dance direction as spoken, or the game's word when it is not one of the four.
    def self.dance_word(dir)
      key = DANCE_DIRS[dir.to_s]
      key ? PokeAccess::I18n.t(key) : PokeAccess.clean(dir.to_s)
    end

    # Parfait: the column under the cursor (@cursor 0..2) on every move, and the bar (@barra, full at 300) as a
    # percentage when it changes.
    def self.postres(scene)
      cur = PokeAccess.ivar(scene, :@cursor)
      if cur.is_a?(Integer)
        PokeAccess::Cursor.announce(scene, :rea_postre_col, cur, true) do
          PokeAccess::I18n.t(PokeAccess::Verbosity.keep?(:positions, :medium) ? :rea_col : :rea_col_bare, :n => cur + 1)
        end
      end
      bar = PokeAccess.ivar(scene, :@barra)
      return if bar.nil? || PokeAccess.ivar(scene, :@pa_barra) == bar
      scene.instance_variable_set(:@pa_barra, bar)
      PokeAccess.speak(PokeAccess::I18n.t(:rea_postre, :n => (bar.to_i * 100 / 300)), false)
    rescue StandardError
      nil
    end

    # The falling berries' x for each column, as sacaricono places them and the cursor sits over them.
    BERRY_COLUMNS = [115, 210, 305]
    # How many falling berry sprites the game keeps (icono0..icono4).
    BERRY_ICONS = 5

    # Berry parfait (Postresjuegobaya, a different game from Postresjuego, with no @barra): the cursor's column with
    # what is falling in it and the recipe, and each berry that starts falling in the cursor's column.
    def self.postres_baya(scene)
      cur = PokeAccess.ivar(scene, :@cursor)
      return unless cur.is_a?(Integer)
      PokeAccess::Cursor.announce(scene, :rea_baya, cur, true) { column_line(scene, cur) }
      baya_spawns(scene, cur)
    rescue StandardError
      nil
    end

    # "Columna 2 de 3, cae Zreza. Receta Atania, Zreza, Meloc": the falling berries nearest the catch first.
    def self.column_line(scene, cur)
      col = PokeAccess::I18n.t(PokeAccess::Verbosity.keep?(:positions, :medium) ? :rea_col : :rea_col_bare, :n => cur + 1)
      falling = falling_in(scene, cur)
      col = "#{col}, #{PokeAccess::I18n.t(:rea_baya_falling, :name => falling.join(', '))}" unless falling.empty?
      PokeAccess.sentences([col, PokeAccess::I18n.t(:rea_baya_recipe, :recipe => recipe_text)])
    end

    # The berries falling in a column, lowest (nearest the catch) first.
    def self.falling_in(scene, cur)
      x = BERRY_COLUMNS[cur]
      icons = (0...BERRY_ICONS).map { |i| PokeAccess.sprite(scene, "icono#{i}") }
      live = icons.compact.select { |sp| (sp.visible rescue false) && (sp.x rescue nil) == x }
      live.sort_by { |sp| -(sp.y rescue 0) }.map { |sp| berry_of(sp) }
    end

    # A berry sprite's name, from the picture it shows ("Graphics/Pictures/Postregame/Zreza").
    def self.berry_of(sprite)
      base = (sprite.name rescue "").to_s.split("/").last.to_s
      BERRY_NAMES[base] || base
    end

    # Each berry that appears at the top of the cursor's column, once per appearance.
    def self.baya_spawns(scene, cur)
      seen = PokeAccess.ivar(scene, :@pa_baya_live) || {}
      now = {}
      (0...BERRY_ICONS).each do |i|
        sp = PokeAccess.sprite(scene, "icono#{i}")
        next unless sp && (sp.visible rescue false)
        now[i] = true
        next if seen[i] || (sp.x rescue nil) != BERRY_COLUMNS[cur]
        PokeAccess.speak(PokeAccess::I18n.t(:rea_baya_falling, :name => berry_of(sp)), true)
      end
      scene.instance_variable_set(:@pa_baya_live, now)
    end

    # The berry sprites showing before the game's input runs, to tell a catch afterwards.
    def self.berries_up(scene)
      (0...BERRY_ICONS).select { |i| sp = PokeAccess.sprite(scene, "icono#{i}"); sp && (sp.visible rescue false) }
    end

    # After the game's input: a berry it caught (a sprite hidden by it) makes the next layer, or empties the glass
    # when it is not the recipe's; a completed parfait is left to the game's own message.
    def self.baya_caught(scene, before)
      caught = before.find { |i| sp = PokeAccess.sprite(scene, "icono#{i}"); sp && !(sp.visible rescue true) }
      return unless caught
      return if PokeAccess.ivar(scene, :@ganado)
      name = berry_of(PokeAccess.sprite(scene, "icono#{caught}"))
      layers = PokeAccess.ivar(scene, :@pisodefault1)
      n = layers.is_a?(Array) ? layers.length : 0
      key = n > 0 ? :rea_baya_layer : :rea_baya_wrong
      PokeAccess.speak(PokeAccess::I18n.t(key, :name => name, :n => n), true)
    rescue StandardError
      nil
    end

    # Four berries the example jars paint under other names than the engine's, said as the jars name them.
    BERRY_NAMES = { "Chesto" => "Atania", "Cheri" => "Zreza", "Pecha" => "Meloc", "Rawst" => "Safre" }

    # The three berries the parfait needs, named as the jars name them.
    def self.recipe_text
      r = ($Trainer.receta rescue nil)
      return "" unless r.is_a?(Array)
      r.compact.map { |b| BERRY_NAMES[b.to_s] || b.to_s }.join(", ")
    rescue StandardError
      ""
    end

    # Type duel: a choice that runs out of time, whatever the selector is over with both HP totals (queued behind
    # the time running out), the time a choice has (once, queued), and the rival's type as its icon slides in.
    def self.ppt(scene)
      out = ppt_timed_out?(scene)
      ppt_timeout(scene, out)
      ppt_focus(scene, !out)
      ppt_start(scene)
      ppt_rival(scene)
    rescue StandardError
      nil
    end

    # Whatever the selector is over, plus both HP totals whenever they move.
    def self.ppt_focus(scene, interrupt = true)
      sel = PokeAccess.ivar(scene, :@selector)
      return unless sel.is_a?(Integer) && sel >= 0
      name = focus_name(scene, sel)
      return if name.nil? || name.empty?
      hp = PokeAccess.ivar(scene, :@protahp)
      ehp = PokeAccess.ivar(scene, :@enemhp)
      PokeAccess::Cursor.announce(scene, :rea_ppt, [sel, name, hp, ehp], interrupt) do
        PokeAccess::I18n.t(:rea_ppt, :name => name, :hp => hp.to_i, :ehp => ehp.to_i)
      end
    end

    # Once per duel: how long each choice lasts, @tiempo2 frames at the running frame rate.
    def self.ppt_start(scene)
      frames = PokeAccess.ivar(scene, :@tiempo2)
      return unless frames && PokeAccess::Cursor.changed?(scene, :rea_ppt_start, true)
      PokeAccess.speak(PokeAccess::I18n.t(:rea_ppt_time, :t => seconds_text(frames)), false)
    end

    # The rival's type once its icon ("Icon" + @enemigo) is out in phase 1: it decides between Ataca and Defiende.
    def self.ppt_rival(scene)
      if PokeAccess.ivar(scene, :@fase) != 1
        PokeAccess::Cursor.reset(scene, :rea_ppt_rival)
        return
      end
      enemy = PokeAccess.ivar(scene, :@enemigo)
      icon = enemy.nil? ? nil : PokeAccess.sprite(scene, "Icon#{enemy}")
      return unless icon && (icon.visible rescue false)
      comb = PokeAccess.ivar(scene, :@comb)
      name = comb.is_a?(Array) ? comb[enemy.to_i].to_s : ""
      return if name.empty?
      PokeAccess::Cursor.announce(scene, :rea_ppt_rival, name, true) { PokeAccess::I18n.t(:rea_ppt_rival, :name => name) }
    end

    # True while a lost round resolves because its choice ran out: @frames sits on @tiempo2 in phase 0 or 2.
    def self.ppt_timed_out?(scene)
      frames = PokeAccess.ivar(scene, :@frames)
      fase = PokeAccess.ivar(scene, :@fase)
      (frames && frames == PokeAccess.ivar(scene, :@tiempo2) && (fase == 0 || fase == 2)) ? true : false
    end

    # "Time's up" once as a choice runs out (the next round's @frames = 0 re-arms it).
    def self.ppt_timeout(scene, out)
      return unless PokeAccess::Cursor.changed?(scene, :rea_ppt_timeout, out) && out
      PokeAccess.speak(PokeAccess::I18n.t(:rea_ppt_timeout), true)
    end

    # A frame count as the time it lasts at the running frame rate, one decimal at most ("1,5 segundos").
    def self.seconds_text(frames)
      rate = (Graphics.frame_rate rescue 40).to_f
      rate = 40.0 if rate <= 0
      s = (frames.to_f / rate * 10).round / 10.0
      s = s.to_i if s == s.floor
      "#{PokeAccess::I18n.number(s)} #{PokeAccess::I18n.t(:secs, :n => s)}"
    end

    # What the selector is on: a type icon of @comb, or in phases 2 and 3 (choosing, then its resolution) the
    # buttons the scene names Ataca and Defiende.
    def self.focus_name(scene, sel)
      fase = PokeAccess.ivar(scene, :@fase)
      return (sel == 0 ? "Ataca" : "Defiende") if fase == 2 || fase == 3
      comb = PokeAccess.ivar(scene, :@comb)
      (comb.is_a?(Array) && sel < comb.length) ? comb[sel].to_s : nil
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Game.define("realidea") do
  [["PPT", :update, :ppt], ["Bailedoki", :actu, :baile], ["Postresjuego", :actu, :postres],
   ["Postresjuegobaya", :actu, :postres_baya]].each do |cname, meth, kind|
    around(cname, meth) do |scene, nxt, _a|
      PokeAccess::RealideaMinigames.hold(scene, kind)
      begin
        nxt.call
      ensure
        PokeAccess::RealideaMinigames.release
      end
    end
  end
  around("Postresjuegobaya", :input) do |scene, nxt, _a|
    before = PokeAccess::RealideaMinigames.berries_up(scene)
    r = nxt.call
    PokeAccess::RealideaMinigames.baya_caught(scene, before)
    r
  end
  poll_each_frame { PokeAccess::RealideaMinigames.poll }
end
