# Three of Realidea's bespoke minigames. All three run their own blocking loop and are never assigned to
# $scene, so each is captured with an around-hook on that loop and read by the per-frame poller -- the same
# shape used for the Africanus minigames.
#
# PPT (0301) is a type-matchup rock-paper-scissors with HP bars. It is the friendliest of the three: @comb
# already holds the three type names as plain text, so the reader just says the focused one plus the HP.
#
# Morse (0295) asks the player to key a 12-symbol sequence. @secuencia is what has been entered so far and
# @secuenciacorrecta the target, so the reader confirms each symbol as it lands and how many are in.
#
# Timon (0296) is the ship's wheel: you steer through a fixed list of headings. @combinacion is the target
# list and @combinaciontimon what has been entered, both as readable strings like "[NE]"; the game itself
# clears the entry when it overruns, which the reader reports as a reset rather than leaving silence.
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
      when :morse   then morse(@active)
      when :timon   then timon(@active)
      when :baile   then baile(@active)
      when :postres then postres(@active)
      when :postres_baya then postres_baya(@active)
      end
    rescue StandardError
      nil
    end

    # Dance: copy the move the partner shows. The direction to copy is kept as a plain string in
    # @direccionmelo, so it is simply spoken when it changes, with the hit count alongside as the only
    # feedback on whether the copy landed.
    #
    # The STEP COUNTER belongs in the signature. Danza picks the next direction at random without excluding
    # the previous one, so roughly one step in four repeats, and on the direction alone a repeat is
    # indistinguishable from the last announcement -- in a memory game whose sequence grows by one each
    # round, that hands the player a shorter sequence than the real one. @direcciones is the sequence being
    # shown and is cleared once copied, so its length is the position WITHIN the round.
    #
    # The opening value is skipped: the scene initialises the direction to a placeholder that is not a step.
    def self.baile(scene)
      dir = PokeAccess.ivar(scene, :@direccionmelo)
      hits = PokeAccess.ivar(scene, :@numaciertos)
      steps = PokeAccess.ivar(scene, :@direcciones)
      sig = [(steps.is_a?(Array) ? steps.length : nil), dir, hits]
      return if dir.nil? || dir.to_s == "Normal" || PokeAccess.ivar(scene, :@pa_baile) == sig
      scene.instance_variable_set(:@pa_baile, sig)
      name = PokeAccess.clean(dir.to_s).to_s.strip
      return if name.empty?
      PokeAccess.speak(PokeAccess::I18n.t(:rea_baile, :dir => name, :n => hits.to_i), true)
    rescue StandardError
      nil
    end

    # Parfait: pick ingredients against a filling bar. @barra is the progress (it grows by 30 per correct
    # pick and the round ends at 300), so the reader reports how full it is rather than trying to name the
    # icons, which are pictures the game swaps with sacaricono.
    def self.postres(scene)
      bar = PokeAccess.ivar(scene, :@barra)
      return if bar.nil? || PokeAccess.ivar(scene, :@pa_barra) == bar
      scene.instance_variable_set(:@pa_barra, bar)
      PokeAccess.speak(PokeAccess::I18n.t(:rea_postre, :n => (bar.to_i * 100 / 300)), false)
    rescue StandardError
      nil
    end

    # Berry parfait: a DIFFERENT game from the one above, despite the near-identical class name. Berries fall
    # into three columns and the player slides a cursor between them to catch the ones the recipe asks for.
    # It has no @barra at all -- that ivar belongs to Postresjuego -- so pointing the shared reader at this
    # class aimed it at state that does not exist and the whole minigame was silent. The column is the only
    # thing the player controls, and the recipe is the target, so those are what get said.
    def self.postres_baya(scene)
      cur = PokeAccess.ivar(scene, :@cursor)
      return unless cur.is_a?(Integer)
      PokeAccess::Cursor.announce(scene, :rea_baya, cur, true) do
        PokeAccess::I18n.t(:rea_baya, :n => cur + 1, :recipe => recipe_text)
      end
    rescue StandardError
      nil
    end

    # This game renames four berries when it paints the example jars, and only there. Reading the recipe
    # straight off the trainer named the berries by their engine names while the jars the player has to match
    # showed the renamed ones -- two different words for the same berry, and no way to tell they were the
    # same. The names on screen win.
    BERRY_NAMES = { "Chesto" => "Atania", "Cheri" => "Zreza", "Pecha" => "Meloc", "Rawst" => "Safre" }

    # The three berries the parfait needs, named as the jars name them.
    def self.recipe_text
      r = ($Trainer.receta rescue nil)
      return "" unless r.is_a?(Array)
      r.compact.map { |b| BERRY_NAMES[b.to_s] || b.to_s }.join(", ")
    rescue StandardError
      ""
    end

    # Type duel: whatever the selector is over, plus both HP totals whenever they move.
    def self.ppt(scene)
      sel = PokeAccess.ivar(scene, :@selector)
      return unless sel.is_a?(Integer) && sel >= 0
      name = focus_name(scene, sel)
      return if name.nil? || name.empty?
      hp = PokeAccess.ivar(scene, :@protahp)
      ehp = PokeAccess.ivar(scene, :@enemhp)
      PokeAccess::Cursor.announce(scene, :rea_ppt, [sel, name, hp, ehp], true) do
        PokeAccess::I18n.t(:rea_ppt, :name => name, :hp => hp.to_i, :ehp => ehp.to_i)
      end
    rescue StandardError
      nil
    end

    # What the selector is sitting on. Phase 0 runs it across the type icons in @comb, but phase 2 is a
    # different row entirely -- the two buttons the scene names Ataca and Defiende -- and reading @comb there
    # announced a type the screen was not showing at all.
    #
    # Phase 3 counts as phase 2 as well: choosing does not move the selector, it just switches the phase and
    # plays the resolution, some thirty frames during which the buttons are still what was chosen. Without
    # this the reader spent that whole animation naming a type icon the screen had already hidden. The HP
    # totals in the dedup key change during it, which turns the repeat into a report of the outcome.
    def self.focus_name(scene, sel)
      fase = PokeAccess.ivar(scene, :@fase)
      return (sel == 0 ? "Ataca" : "Defiende") if fase == 2 || fase == 3
      comb = PokeAccess.ivar(scene, :@comb)
      (comb.is_a?(Array) && sel < comb.length) ? comb[sel].to_s : nil
    rescue StandardError
      nil
    end

    # Morse: confirms each symbol as it is entered and how far along the sequence is.
    def self.morse(scene)
      seq = PokeAccess.ivar(scene, :@secuencia)
      target = PokeAccess.ivar(scene, :@secuenciacorrecta)
      return unless seq.is_a?(Array)
      PokeAccess::Cursor.announce(scene, :rea_morse, seq.length, false) do
        last = seq.last
        tot = (target.is_a?(Array) ? target.length : nil)
        sym = (last.to_s == "raya") ? PokeAccess::I18n.t(:rea_dash) : PokeAccess::I18n.t(:rea_dot)
        if seq.empty?
          PokeAccess::I18n.t(:rea_morse_start, :tot => tot.to_i)
        elsif tot
          PokeAccess::I18n.t(:rea_morse, :sym => sym, :n => seq.length, :tot => tot)
        else
          sym
        end
      end
    rescue StandardError
      nil
    end

    # Ship's wheel: the headings entered so far against the target length.
    # The wheel's live heading. @posiciones is a ROTATING list of compass points and the one being pointed at
    # is always its first entry: LEFT and RIGHT shift the array rather than move an index. Reading only the
    # registered combination meant turning the wheel said nothing, and the player learned the heading only
    # after committing it with C -- too late to be the one choosing it. The points are the game's own text.
    def self.heading(scene)
      pos = PokeAccess.ivar(scene, :@posiciones)
      return unless pos.is_a?(Array) && pos[0]
      dir = PokeAccess.clean(pos[0].to_s).to_s.strip
      return if dir.empty?
      PokeAccess::Cursor.announce(scene, :rea_timon_dir, dir, true) { dir }
    rescue StandardError
      nil
    end

    def self.timon(scene)
      heading(scene)
      got = PokeAccess.ivar(scene, :@combinaciontimon)
      target = PokeAccess.ivar(scene, :@combinacion)
      return unless got.is_a?(Array) && target.is_a?(Array)
      PokeAccess::Cursor.announce(scene, :rea_timon, got.length, false) do
        if got.empty?
          PokeAccess::I18n.t(:rea_timon_reset, :tot => target.length)
        else
          PokeAccess::I18n.t(:rea_timon, :dir => PokeAccess.clean(got.last.to_s),
                             :n => got.length, :tot => target.length)
        end
      end
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Game.define("realidea") do
  [["PPT", :update, :ppt], ["Morse", :actu, :morse], ["Timon", :actu, :timon],
   ["Bailedoki", :actu, :baile], ["Postresjuego", :actu, :postres],
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
  poll_each_frame { PokeAccess::RealideaMinigames.poll }
end
