module PokeAccess
  # Two field mechanics that take control away from the player, or change what the map contains, and say so
  # only through animation. Neither is a screen, so no reader could ever have been bound to one: they are
  # flags on the running game, watched once per frame.
  module FieldStates
    # Spin tiles (the Vendily/thepsynergist plugin, two games): stepping on one drags the player in its
    # direction until a wall or a stop tile, redirecting on every further spin tile. $PokemonGlobal.spinning
    # is the flag and the terrain tag under the player is the direction, which is how the plugin itself
    # decides where to push.
    SPIN_TAGS = { 31 => :fs_spin_up, 32 => :fs_spin_down, 33 => :fs_spin_left, 34 => :fs_spin_right }

    @spin_last = nil
    @lens_on = false

    # The direction key for the tile under the player, or nil when it is not a spin tile.
    def self.spin_key
      tag = ($game_player.pbTerrainTag rescue nil)
      tag = (tag.respond_to?(:id) ? tag.id : tag)
      SPIN_TAGS[tag.is_a?(Integer) ? tag : nil]
    rescue StandardError
      nil
    end

    # Announces starting to spin, every change of direction, and coming to a stop.
    #
    # The direction is part of the key, not just the on/off: the plugin redirects the player on each new
    # spin tile without ever clearing the flag, so an on/off key would announce the first direction and
    # then stay quiet through a whole chain of turns.
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

    # Lens of Truth (Drimer's plugin, six games): an item that for a few seconds fades hidden events in and
    # visible ones out within a small radius. Scene_Map#eye_of_truth_time counts the frames left.
    #
    # Only the WINDOW is announced, not what appeared: the tiles it reveals are already reachable, both by
    # the locator's own category for them and by the notice the player gets on stepping onto one. What was
    # missing is that the item did anything at all, and how long it lasts -- a countdown a sighted player
    # reads off the fading sprites.
    def self.lens_poll
      t = ($scene.is_a?(Scene_Map) ? ($scene.eye_of_truth_time rescue 0) : 0).to_i
      on = t > 0
      return if on == @lens_on
      @lens_on = on
      PokeAccess.speak(PokeAccess::I18n.t(on ? :fs_lens_on : :fs_lens_off), true)
    rescue StandardError
      nil
    end

    # Both flags belong to the map the player just left. The lens starts at false and not at nil: an unset
    # slot differs from "off" and the first look on a fresh map would announce that the lens had worn off
    # when it had never been used.
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
