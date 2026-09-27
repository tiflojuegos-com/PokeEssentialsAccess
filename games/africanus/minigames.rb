# Africanus's two minigames and the truth-tables gallery: the cage kick and archery play a tick whose pitch rises
# toward the perfect point, and say each kick and each arrow's points. Each scene is held by an around-hook on its
# blocking loop and read per frame.
module PokeAccess
  module AfricanusMinigames
    @active = nil
    @kind = nil

    # The points each numeral of the archery's "points" sprite stands for, by the x its source rect is cut at: X,
    # VII, V and I.
    ARROW_POINTS = { 0 => 10, 78 => 7, 172 => 5, 202 => 1 }

    # Holds the running minigame while its blocking loop is on the stack.
    def self.hold(scene, kind); @active = scene; @kind = kind; end
    def self.release; @active = nil; @kind = nil; end

    # Per-frame entry point: routes to the reader of whichever minigame is running, or does nothing.
    def self.poll
      return unless @active
      case @kind
      when :kick   then kick(@active); kick_count(@active)
      when :archer then archer(@active); archer_score(@active)
      when :tables then tables(@active)
      end
    rescue StandardError
      nil
    end

    # Plays the gauge tick for a 0.0-1.0 closeness (1.0 = dead on the perfect point).
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

    # Says each kick once, against the kick that fells the door.
    def self.kick_count(scene)
      n = PokeAccess.ivar(scene, :@kickCount)
      return if n.nil? || n.to_i <= 0
      PokeAccess::Cursor.announce(scene, :afr_kick, n.to_i, false) do
        PokeAccess::I18n.t(:afr_kick, :n => n.to_i, :total => kicks_to_fall)
      end
    rescue StandardError
      nil
    end

    # The kick that fells the door: three rope states of NUM_KICKS_PER_STATE kicks each.
    def self.kicks_to_fall
      (PokeAccess.const_at("EscapeGaulScene::NUM_KICKS_PER_STATE") || 3).to_i * 3
    end

    # Archery: the same on the "selector" sprite, peaking on the game's PERFECT_SHOT_Y, which is not the travel's
    # midpoint (the lower half is six pixels longer).
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

    # Says each arrow once, with the points its numeral sprite shows.
    def self.archer_score(scene)
      n = PokeAccess.ivar(scene, :@arrowCount)
      return if n.nil? || n.to_i <= 0
      PokeAccess::Cursor.announce(scene, :afr_archer, n.to_i, false) do
        pts = arrow_points(scene)
        pts ? PokeAccess::I18n.t(:afr_archer, :arrow => n.to_i, :n => pts) : nil
      end
    rescue StandardError
      nil
    end

    # The points of the last arrow, from the source rect of the "points" sprite, or nil when it cannot be read.
    def self.arrow_points(scene)
      spr = PokeAccess.sprite(scene, "points")
      x = spr ? (spr.src_rect.x rescue nil) : nil
      x.nil? ? nil : ARROW_POINTS[x.to_i]
    end

    # Truth tables: the cell under the selector (x = 16 + col*246, y = 24 + row*44), said by the name its shelf's
    # background paints.
    def self.tables(scene)
      sel = PokeAccess.ivar(scene, :@selector)
      return unless sel && (sel.visible rescue false)
      col = (((sel.x rescue 16) - 16) / 246)
      row = (((sel.y rescue 24) - 24) / 44)
      idx = (row * 2) + col
      return if idx < 0
      PokeAccess::Cursor.announce(scene, :afr_tables, idx, true) do
        name = PokeAccess::AfricanusTablas.cell_name(PokeAccess.ivar(scene, :@pictures_prefix), idx)
        open = (scene.can_access_table?(idx) rescue true)
        (name.nil? || open) ? name : PokeAccess::I18n.t(:afr_table_locked, :name => name)
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
