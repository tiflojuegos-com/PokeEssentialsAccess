module PokeAccess
  # A touch event that fires on arrival and carries the player on only while the arrow they arrived with is still held
  # (six of Insurgence's diagonal stairs; the rest fire on a bump, the arrow already down): reached with the key let
  # go, it leaves them on its tile, and the arrow pressed again walks on without it. Once they stand there still, how
  # to take it is said, once per arrival: a step back, then on again with the arrow held.
  module HeldCarry
    # Frames standing still on such a tile before the key is said.
    WAIT = 12
    # The arrow each facing is walked with, and the word for it where the key is not remapped.
    ARROWS = { 2 => [:down, :key_arrow_down], 4 => [:left, :key_arrow_left], 6 => [:right, :key_arrow_right],
               8 => [:up, :key_arrow_up] }
    @at = nil
    @dir = nil
    @since = nil
    @said = true

    # One map frame with the player in control: notes each tile stepped to (the engine moves x and y as the step
    # starts), then says the key once they have stood still WAIT frames on one whose carry they missed.
    def self.tick
      return unless $game_player && $game_map
      here = [$game_player.x, $game_player.y, $game_map.map_id]
      unless here == @at
        @at = here
        @dir = $game_player.direction
        @since = nil
        @said = !held_carry?(here[0], here[1], @dir)
        return
      end
      return if @said
      if PokeAccess::Control.motion != :still
        @since = nil
        return
      end
      now = PokeAccess::Frame.serial.to_i
      @since ||= now
      return if now - @since < WAIT
      @said = true
      PokeAccess.speak(hint(@dir), false)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # Whether arriving at (x, y) facing d fires a carry that needs the arrow held down.
    def self.held_carry?(x, y, d)
      e = PokeAccess::Routes::Effects.touch_at(x, y, d, true)
      e && e[0] == :carry && e[5] ? true : false
    end

    # The line saying how to take the carry, with the arrow the player arrived by.
    def self.hint(d)
      sym, word = ARROWS[d] || ARROWS[2]
      PokeAccess::I18n.t(:nav_hold_key, :key => PokeAccess::KeyHints.key(sym, PokeAccess::I18n.t(word)))
    end

    # Forgets the tile; run on a map change and a reset.
    def self.reset
      @at = nil
      @since = nil
      @said = true
    end
  end
end

PokeAccess::Caches.register(:held_carry) { PokeAccess::HeldCarry.reset }
