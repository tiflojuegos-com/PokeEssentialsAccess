# The buildings every town of both Infinite Fusion games reaches through one shared map: their doors only call a script,
# and each leads where the game's own constants and tables say. The way out returns to the town the player came from,
# which only the game knows.
module PokeAccess
  module IFBuildings
    # The shared mart as [map, x, y], from the constants enter_pokemart reads.
    def self.mart
      [PokeAccess.const_at("POKEMART_MAP_ID")] + Array(PokeAccess.const_at("POKEMART_DOOR_POS"))
    end

    # A shared building as [map, x, y], from the table enter_common_building reads, or nil.
    def self.building(name)
      table = PokeAccess.const_at(PokeAccess.const_at("Settings::HOENN") ? "COMMON_MAPS_HOENN" : "COMMON_MAPS_KANTO")
      entry = table.is_a?(Hash) ? table[name.to_sym] : nil
      entry ? [entry[:id]] + Array(entry[:position]) : nil
    end
  end
end

PokeAccess::Game.define("infinitefusion_common") do
  transfer_script(/^\s*enter_pokemart\s*\(/) { |_m| PokeAccess::IFBuildings.mart }
  transfer_script(/^\s*enter_common_building\s*\(\s*:(\w+)/) { |m| PokeAccess::IFBuildings.building(m[1]) }
  transfer_script(/^\s*enter_pokemon_center\s*\(/) { |_m| PokeAccess::IFBuildings.building("POKEMON_CENTER") }
  transfer_script(/^\s*exit_(?:pokemart|common_building|pokemon_center)\b/)
end
