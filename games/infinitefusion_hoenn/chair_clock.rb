module PokeAccess
  # Infinite Fusion 2's chair tiles (sit_on_chair, walked into off the bike): the player sits until an arrow toward
  # another chair jumps them onto it (jumpTowards) or one toward a free tile stands them up, which ends the loop. The
  # screen paints nothing for either.
  module IF2Chair
    # Runs the chair's loop: the seat said first, queued, with the arrows while key hints are said; standing up said
    # as the loop returns, cutting in as the arrow that made it.
    def self.sit
      seat = PokeAccess::I18n.t(:if2_seat)
      PokeAccess.speak(PokeAccess::Verbosity.with_hint(seat, PokeAccess::I18n.t(:if2_chair_hint)), false)
      @seated = true
      ret = yield
      PokeAccess.speak(PokeAccess::I18n.t(:if2_standing), true)
      ret
    ensure
      @seated = false
    end

    # Runs a jump of the player's: one that takes them to another tile while seated is the move onto another seat,
    # said cutting in; one the next chair blocks leaves them where they were and says nothing.
    def self.jump(player)
      from = [player.x, player.y]
      ret = yield
      PokeAccess.speak(PokeAccess::I18n.t(:if2_seat_other), true) if @seated && [player.x, player.y] != from
      ret
    end
  end

  # Infinite Fusion 2's chair clock (showTimeWindow): sitting on a chair outdoors shows the hour in a sign window that
  # runs faster the longer the player sits and is repainted every frame. Said once, queued, as it appears; the info
  # key on the map says the hour it shows now while it is up.
  module IF2ChairClock
    # Keeps the clock's window and says the hour it shows.
    def self.shown(win)
      @window = win
      t = hour
      PokeAccess.speak(t, false) if t
    end

    # The hour the clock shows now, or nil once its window is gone.
    def self.hour
      w = @window
      return nil if w.nil?
      if (w.disposed? rescue true)
        @window = nil
        return nil
      end
      t = PokeAccess.clean((w.text rescue nil).to_s)
      t.empty? ? nil : t
    end
  end
end

# The seat is said before the chair's loop runs, so outdoors the clock's hour follows it.
PokeAccess::Game.define("infinitefusion_hoenn") do
  kernel("sit_on_chair", :around) { |_args, nxt| PokeAccess::IF2Chair.sit { nxt.call } }
  around("Game_Player", :jumpTowards, :optional => true) do |player, nxt, _a|
    PokeAccess::IF2Chair.jump(player) { nxt.call }
  end
  kernel("showTimeWindow", :after) { |_a, win| PokeAccess::IF2ChairClock.shown(win) }
  PokeAccess::Info.map_owner(:if2_chair_clock) { PokeAccess::IF2ChairClock.hour }
end
