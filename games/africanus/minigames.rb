# Africanus's three bespoke minigames plus the truth-tables gallery.
#
# Two of them (the cage kick and the archery range) are TIMING games: a cursor slides up and down and you
# press at the right moment. Speech is useless there -- by the time a sentence is read the cursor has moved --
# so these use an audio cue instead: a tick whose PITCH rises as the cursor approaches the perfect point.
# Speech is left for what does not change every frame (the running score after each arrow).
#
# None of these scenes is ever assigned to $scene: the game builds them inside a plain function
# (`scene = EscapeGaulScene.new(...)`) and drives its own blocking loop. So the instance is captured with an
# around-hook on that loop and held while it runs, and the per-frame poller reads the held one -- the same
# shape the core uses for Triple Triad's blocking pickers.
module PokeAccess
  module AfricanusMinigames
    @active = nil
    @kind = nil

    # Holds the running minigame while its blocking loop is on the stack.
    def self.hold(scene, kind); @active = scene; @kind = kind; end
    def self.release; @active = nil; @kind = nil; end

    # Per-frame entry point: routes to the reader of whichever minigame is running, or does nothing.
    def self.poll
      return unless @active
      case @kind
      when :kick   then kick(@active)
      when :archer then archer(@active); archer_score(@active)
      when :tables then tables(@active)
      end
    rescue StandardError
      nil
    end

    # Maps a 0.0-1.0 closeness (1.0 = dead on the perfect point) to a playback pitch and plays the tick.
    # The range spans roughly an octave so the target is unmistakable by ear.
    def self.tick(closeness)
      PokeAccess::Spatial.gauge(closeness)
    end

    # Cage kick: the "kickpoint" sprite slides between @cursorMinY and @cursorMaxY, perfect at PERFECT_KICK_Y.
    # Ticks once per sprite move, so a still cursor stays quiet.
    def self.kick(scene)
      spr = PokeAccess.sprite(scene, "kickpoint")
      return unless spr
      y = (spr.y rescue nil)
      return if y.nil? || PokeAccess.ivar(scene, :@pa_kick_y) == y
      scene.instance_variable_set(:@pa_kick_y, y)
      perfect = (EscapeGaulScene::PERFECT_KICK_Y rescue 142)
      lo = PokeAccess.ivar(scene, :@cursorMinY).to_i
      hi = PokeAccess.ivar(scene, :@cursorMaxY).to_i
      span = ((hi - lo).abs / 2.0)
      span = 1.0 if span <= 0
      tick(1.0 - ((y - perfect).abs / span))
    rescue StandardError
      nil
    end

    # Archery: same idea on the "selector" sprite -- except that the bullseye is NOT the midpoint of the
    # travel, so the game's own PERFECT_SHOT_Y is what the pitch peaks on. The scene builds the range as
    # PERFECT_SHOT_Y - CURSOR_MOVEMENT * CURSOR_STEPS .. PERFECT_SHOT_Y + 6 + CURSOR_MOVEMENT * CURSOR_STEPS,
    # so the bottom half is six pixels longer and (lo + hi) / 2 lands three below the spot that actually
    # scores -- three pixels of telling the player to release in the wrong place.
    def self.archer(scene)
      spr = PokeAccess.sprite(scene, "selector")
      return unless spr
      y = (spr.y rescue nil)
      return if y.nil? || PokeAccess.ivar(scene, :@pa_arch_y) == y
      scene.instance_variable_set(:@pa_arch_y, y)
      lo = PokeAccess.ivar(scene, :@cursorMinY).to_i
      hi = PokeAccess.ivar(scene, :@cursorMaxY).to_i
      mid = (PokeAccess.const_at("TheArcherScene::PERFECT_SHOT_Y") || ((lo + hi) / 2.0)).to_f
      span = [(mid - lo).abs, (hi - mid).abs].max
      span = 1.0 if span <= 0
      tick(1.0 - ((y - mid).abs / span))
    rescue StandardError
      nil
    end

    # Spoken after each arrow: how many are shot and the running total.
    def self.archer_score(scene)
      n = PokeAccess.ivar(scene, :@arrowCount)
      pts = PokeAccess.ivar(scene, :@sumPoints)
      sig = [n, pts]
      return if PokeAccess.ivar(scene, :@pa_arch_score) == sig
      scene.instance_variable_set(:@pa_arch_score, sig)
      return if n.nil? || n.to_i <= 0
      PokeAccess.speak(PokeAccess::I18n.t(:afr_archer, :n => n.to_i, :pts => pts.to_i), false)
    rescue StandardError
      nil
    end

    # Truth tables: a 2-column grid whose cursor is a LOCAL variable, so the focus is read back from the
    # selector sprite's position -- the game places it at x = 16 + col*246, y = 24 + row*44.
    def self.tables(scene)
      sel = PokeAccess.ivar(scene, :@selector)
      return unless sel && (sel.visible rescue false)
      col = (((sel.x rescue 16) - 16) / 246)
      row = (((sel.y rescue 24) - 24) / 44)
      idx = (row * 2) + col
      return if idx < 0
      PokeAccess::Cursor.announce(scene, :afr_tables, idx, true) do
        open = (scene.can_access_table?(idx) rescue true)
        PokeAccess::I18n.t(open ? :afr_table : :afr_table_locked, :n => idx + 1)
      end
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Game.define("africanus") do
  [["EscapeGaulScene", :pbMain, :kick], ["TheArcherScene", :pbMain, :archer],
   ["TablesScreen", :mainLoop, :tables]].each do |cname, meth, kind|
    around(cname, meth) do |scene, nxt, _a|
      PokeAccess::AfricanusMinigames.hold(scene, kind)
      begin
        nxt.call
      ensure
        PokeAccess::AfricanusMinigames.release
      end
    end
  end
  poll_each_frame { PokeAccess::AfricanusMinigames.poll }
end
