module PokeAccess
  # Revival's Pokemon Centres: the game declares no healing spot (MapMeta.pokecenter?), so a map is one when its own
  # name says so.
  module RevivalCenters
    # A Pokemon Centre's map name, in the game's Spanish ("Ciudad Zahlen Centro Pokemon", "Centros Pokemon Galar") or
    # English.
    CENTER_NAME = /\bcentros? pok|\bpok\S*mon cent(?:er|re)\b/i

    # True if the game's name for the map (pbGetMapNameFromId) is a Pokemon Centre's.
    def self.pokecenter?(api, map_id)
      return false unless map_id.is_a?(Integer) && map_id > 0 && api.respond_to?(:pbGetMapNameFromId, true)
      api.send(:pbGetMapNameFromId, map_id).to_s =~ CENTER_NAME ? true : false
    rescue StandardError => e
      PokeAccess.swallowed(e)
      false
    end
  end
end

PokeAccess::Game.define("revival") do
  override("PokeAccess::MapMeta", :pokecenter?) do |metadata, original, args|
    original.call || PokeAccess::RevivalCenters.pokecenter?(metadata, args[0])
  end
end
