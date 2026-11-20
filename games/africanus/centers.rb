module PokeAccess
  # Africanvs' Pokemon Centres: the game declares no healing spot (MapMeta.pokecenter?), so a map is one when it holds
  # the centre's nurse.
  module AfricanusCenters
    # The nurse page's first command, pbSetPokemonCenter on its own.
    CENTER_START = /\A\s*(?:Kernel\.)?pbSetPokemonCenter(?:\(\s*\))?\s*\z/

    @centers = {}

    # True if the map holds the centre's nurse (nurse?), read from its file once per run: the map files do not change
    # while the game runs, so the answer, a map that fails to load included, is kept across map changes and loads.
    def self.pokecenter?(api, map_id)
      return false unless map_id.is_a?(Integer) && map_id > 0 && api.respond_to?(:pbLoadRxData, true)
      return @centers[map_id] if @centers.key?(map_id)
      @centers[map_id] = false
      map = api.send(:pbLoadRxData, sprintf("Data/Map%03d", map_id))
      events = map.respond_to?(:events) ? map.events : nil
      @centers[map_id] = events.is_a?(Hash) && events.values.any? { |event| nurse?(event) }
    rescue StandardError => e
      PokeAccess.swallowed(e)
      false
    end

    # True for the centre's nurse: an action-button page on the game's blank "000" sheet that starts with
    # pbSetPokemonCenter and recovers the whole party.
    def self.nurse?(event)
      (event.pages || []).any? do |page|
        list = page.list || []
        first = list[0]
        page.trigger == 0 && page.graphic.character_name == "000" && first && first.code == 355 &&
          first.parameters[0].to_s =~ CENTER_START && list.any? { |c| c.code == 314 && c.parameters[0] == 0 }
      end
    end
  end
end

PokeAccess::Game.define("africanus") do
  override("PokeAccess::MapMeta", :pokecenter?) do |metadata, original, args|
    original.call || PokeAccess::AfricanusCenters.pokecenter?(metadata, args[0])
  end
end
