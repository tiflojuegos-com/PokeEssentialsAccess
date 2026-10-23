module PokeAccess
  # Where a forced move left the player (Control.motion :forced or :sliding: a move route, an ice slide, or a run the
  # engine walks in one update, like a waterfall or a climb): said from where it began once control is back, and kept
  # leg by leg for the info key while the player stands where it ended; a teleport restarts it, a map change drops it.
  module ForcedMove
    @from = nil
    @last = nil
    @moves = []
    @slid = false
    @line = nil
    @at = nil

    # One map frame, whether or not the player has control: drops the last move's line once the player is off where it
    # ended, follows a forced move's tiles until the player has control back, then says where it left them.
    def self.tick
      return unless $game_player && $game_map
      here = [$game_player.x, $game_player.y, $game_map.map_id]
      drawn = PokeAccess::Locator.drawn_at
      @line = nil unless @at == here
      m = PokeAccess::Control.motion
      run = run?(here, drawn, m)
      @carried = run || (@carried && m == :moving)
      forced = m == :forced || m == :sliding || @carried
      if forced
        @from ||= @last || here
        @slid ||= m == :sliding
      end
      if @from
        forced || !PokeAccess::Control.free? ? follow(here, run) : finish(here)
      end
      @last = here
      @drawn = drawn
      @serial = PokeAccess::Frame.serial
    end

    # True when, since the map frame just before, the player went two tiles or more one way, stepping (motion), while
    # the drawn player moved a tile at most (Locator.drawn_walk?): a run the engine walks in one update, the sprite yet
    # to make it. A transfer moves the drawn player with the tile.
    def self.run?(here, drawn, motion)
      prev = @last
      return false unless motion == :moving && prev && prev[2] == here[2] && @serial == PokeAccess::Frame.serial - 1
      dx = here[0] - prev[0]
      dy = here[1] - prev[1]
      return false unless (dx == 0 || dy == 0) && dx.abs + dy.abs >= 2
      PokeAccess::Locator.drawn_walk?(@drawn, drawn)
    end

    # Adds the tiles the player moved since the last frame, a direction code each; a teleport (more than a hop, no jump:
    # a jump lands in the frame it takes off; no run: see run?) or a new map starts the move afresh from here.
    def self.follow(here, run = false)
      prev = @trail || @from
      @trail = here
      return if here == prev
      dx = here[0] - prev[0]
      dy = here[1] - prev[1]
      far = !run && dx.abs + dy.abs > 2 && !PokeAccess::Control.flag($game_player, :jumping?)
      if here[2] != prev[2] || far
        @from = here
        @moves = []
        return
      end
      dx.abs.times { @moves.push(dx < 0 ? 4 : 6) }
      dy.abs.times { @moves.push(dy < 0 ? 8 : 2) }
    end

    # The move has ended at here: says how far from where it began (Routes::Text.moved), unless back on that tile, and
    # keeps its way for the info key.
    def self.finish(here)
      from = @from
      moves = @moves
      slid = @slid
      forget
      return if from[2] != here[2]
      dx = here[0] - from[0]
      dy = here[1] - from[1]
      return if dx == 0 && dy == 0
      PokeAccess.speak(PokeAccess::Routes::Text.moved(dx, dy), false)
      @line = PokeAccess::Routes::Text.moved_path(moves, slid)
      @at = here
    end

    # The info key's line while the player stands where the last forced move ended, else nil.
    def self.line
      return nil unless @line && $game_player && $game_map
      return @line if @at == [$game_player.x, $game_player.y, $game_map.map_id]
      @line = nil
    end

    # Forgets the move under way.
    def self.forget
      @from = nil
      @trail = nil
      @moves = []
      @slid = false
      @carried = false
    end

    # Forgets the move under way and the last one's line; run on a map change.
    def self.reset
      forget
      @last = nil
      @drawn = nil
      @line = nil
      @at = nil
    end
  end
end

PokeAccess::Caches.register(:forced_move) { PokeAccess::ForcedMove.reset }
