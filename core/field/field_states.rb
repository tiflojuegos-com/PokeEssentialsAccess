module PokeAccess
  # Two field mechanics shown only through animation, spin tiles and the Lens of Truth: flags on the running game,
  # watched once per frame.
  module FieldStates
    # Spin tiles (Vendily/thepsynergist plugin): $PokemonGlobal.spinning is the flag and the player's facing the
    # direction; the terrain tag under the player already names the next tile.
    SPIN_DIRS = { 2 => :fs_spin_down, 4 => :fs_spin_left, 6 => :fs_spin_right, 8 => :fs_spin_up }

    @spin_last = nil
    @lens_on = false

    # The direction key for the spin in progress, from the player's facing.
    def self.spin_key
      SPIN_DIRS[$game_player.direction]
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # Announces a spin's start and each change of direction (the flag stays on through a chain of turns), cutting in,
    # and its stop queued, after where the spin left the player (ForcedMove, said the frame before).
    def self.spin_poll
      on = ($PokemonGlobal.spinning rescue false) ? true : false
      key = on ? (spin_key || :fs_spin_on) : nil
      return if key == @spin_last
      was = @spin_last
      @spin_last = key
      return PokeAccess.speak(PokeAccess::I18n.t(:fs_spin_stop), false) if key.nil? && !was.nil?
      PokeAccess.speak(PokeAccess::I18n.t(key), true) if key
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # Whether a copy of the lens with no timer has it on: its eye_of_truth flag, up until the player lowers it.
    def self.lens_flag?
      $scene.is_a?(Scene_Map) && $scene.respond_to?(:eye_of_truth) && $scene.eye_of_truth == true
    end

    # Lens of Truth (Drimer's plugin): announces when it takes effect and when it wears off (Scene_Map#eye_of_truth_time
    # counts the frames left; the copies with no timer keep only the flag); what it reveals is left to the locator.
    def self.lens_poll
      on = ($scene.is_a?(Scene_Map) && $scene.respond_to?(:eye_of_truth_time) && $scene.eye_of_truth_time.to_i > 0) || lens_flag?
      return if on == @lens_on
      @lens_on = on
      PokeAccess.speak(PokeAccess::I18n.t(on ? :fs_lens_on : :fs_lens_off), true)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # Clears both flags on a map change. A lens on a timer goes to false, not nil, so a fresh map says it again while it
    # runs and does not announce it wearing off; a flag the player keeps up goes on unsaid from door to door.
    def self.reset
      @spin_last = nil
      @lens_on = lens_flag?
    end
  end
end

PokeAccess::Frame.each_pulse do
  PokeAccess::FieldStates.spin_poll
  PokeAccess::FieldStates.lens_poll
end

PokeAccess::Caches.register(:field_states) { PokeAccess::FieldStates.reset }
