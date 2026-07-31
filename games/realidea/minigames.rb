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
      end
    rescue StandardError
      nil
    end

    # Dance: copy the move the partner shows. It looked like a timing game, but the direction to copy is kept
    # as a plain string in @direccionmelo, so it is simply spoken when it changes -- no cue needed. The hit
    # count is spoken too, which is the only feedback on whether the copy landed.
    def self.baile(scene)
      dir = PokeAccess.ivar(scene, :@direccionmelo)
      hits = PokeAccess.ivar(scene, :@numaciertos)
      sig = [dir, hits]
      return if dir.nil? || PokeAccess.ivar(scene, :@pa_baile) == sig
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

    # Type duel: the focused type, plus both HP totals whenever they move.
    def self.ppt(scene)
      sel = PokeAccess.ivar(scene, :@selector)
      comb = PokeAccess.ivar(scene, :@comb)
      return unless sel.is_a?(Integer) && comb.is_a?(Array) && sel >= 0 && sel < comb.length
      hp = PokeAccess.ivar(scene, :@protahp)
      ehp = PokeAccess.ivar(scene, :@enemhp)
      PokeAccess::Cursor.announce(scene, :rea_ppt, [sel, hp, ehp], true) do
        PokeAccess::I18n.t(:rea_ppt, :name => comb[sel].to_s, :hp => hp.to_i, :ehp => ehp.to_i)
      end
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
    def self.timon(scene)
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
   ["Postresjuegobaya", :actu, :postres]].each do |cname, meth, kind|
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
