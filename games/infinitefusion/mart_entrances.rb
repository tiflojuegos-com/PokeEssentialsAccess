module PokeAccess
  # Kanto's cities share a mart interior. The city symbol chooses its stock;
  # the game's constants choose the destination, so no town list belongs here.
  module IFMartEntrances
    ENTER = /\A\s*enter_pokemart\s*\(\s*:[A-Za-z_]\w*\s*\)\s*(?:#[^\n]*)?\s*\z/
    EXIT = /\A\s*exit_pokemart\s*(?:\(\s*\))?\s*(?:#[^\n]*)?\s*\z/

    def self.map_id
      return nil unless Object.const_defined?("POKEMART_MAP_ID")
      value = Object.const_get("POKEMART_MAP_ID")
      value.is_a?(Integer) && value > 0 ? value : nil
    end

    # Read the transfer without executing the game's shop, fade or state changes.
    def self.destination(script)
      return nil unless ENTER.match(script.to_s)
      mid = map_id
      return nil unless mid
      xy = Object.const_defined?("POKEMART_DOOR_POS") ? Object.const_get("POKEMART_DOOR_POS") : nil
      valid = xy.is_a?(Array) && xy.length >= 2 &&
              xy[0].is_a?(Integer) && xy[1].is_a?(Integer) && xy[0] >= 0 && xy[1] >= 0
      valid ? [mid, xy[0], xy[1]] : [mid, nil, nil]
    end

    # Its exit chooses the city at runtime. It is a door with an unknown
    # destination, rather than an invented map id or a call to the game function.
    def self.exit_event?(event)
      return false unless map_id
      trigger = PokeAccess.ivar_i(event, :@trigger)
      return false if trigger == 3 || trigger == 4
      sprite = event.character_name.to_s
      return false unless sprite.empty? || Locator.doorway_sprite?(sprite) || Locator.teleporter_sprite?(sprite)
      Locator.transfer_command_lists(event).any? do |list|
        Locator.script_calls(list).any? { |script| EXIT.match(script.to_s) }
      end
    end

    # IF 6.9.1's Cianwood table has [709.8, 46] instead of [709, 8, 46].
    # The exact malformed return raises before Scene_Map can transfer the player.
    # Keep the correction separate from generic entrance discovery and preserve
    # every ordinary transfer, including a future corrected game table.
    def self.repair_return(temp, current_map)
      return unless temp && map_id && current_map == map_id
      return unless [temp.player_new_map_id, temp.player_new_x, temp.player_new_y] == [709.8, 46, nil]
      temp.player_new_map_id = 709
      temp.player_new_x = 8
      temp.player_new_y = 46
    end
  end
end

PokeAccess::Game.define("infinitefusion") do
  before("Scene_Map", :transfer_player) do |_scene, _args|
    PokeAccess::IFMartEntrances.repair_return($game_temp, $game_map && $game_map.map_id)
  end
  override(PokeAccess::Locator, :script_transfer_map) do |_locator, original, args|
    destination = PokeAccess::IFMartEntrances.destination(args[0])
    destination ? destination[0] : original.call
  end
  override(PokeAccess::Locator, :script_transfer_dest) do |_locator, original, args|
    PokeAccess::IFMartEntrances.destination(args[0]) || original.call
  end
  override(PokeAccess::Locator, :transfer_event_uncached?) do |_locator, original, args|
    original.call || PokeAccess::IFMartEntrances.exit_event?(args[0])
  end
end
