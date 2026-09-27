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
    rescue StandardError
      nil
    end

    # Announces a spin's start, each change of direction (the flag stays on through a chain of turns) and its stop.
    def self.spin_poll
      on = ($PokemonGlobal.spinning rescue false) ? true : false
      key = on ? (spin_key || :fs_spin_on) : nil
      return if key == @spin_last
      was = @spin_last
      @spin_last = key
      return PokeAccess.speak(PokeAccess::I18n.t(:fs_spin_stop), true) if key.nil? && !was.nil?
      PokeAccess.speak(PokeAccess::I18n.t(key), true) if key
    rescue StandardError
      nil
    end

    # Lens of Truth (Drimer's plugin): announces when it takes effect and when it wears off
    # (Scene_Map#eye_of_truth_time counts the frames left); what it reveals is left to the locator.
    def self.lens_poll
      t = ($scene.is_a?(Scene_Map) ? ($scene.eye_of_truth_time rescue 0) : 0).to_i
      on = t > 0
      return if on == @lens_on
      @lens_on = on
      PokeAccess.speak(PokeAccess::I18n.t(on ? :fs_lens_on : :fs_lens_off), true)
    rescue StandardError
      nil
    end

    # Clears both flags on a map change; the lens goes to false, not nil, so a fresh map does not announce it
    # wearing off.
    def self.reset
      @spin_last = nil
      @lens_on = false
    end
  end
end

PokeAccess::Keys.on_frame do
  PokeAccess::FieldStates.spin_poll
  PokeAccess::FieldStates.lens_poll
end

PokeAccess::Caches.register(:field_states) { PokeAccess::FieldStates.reset }
