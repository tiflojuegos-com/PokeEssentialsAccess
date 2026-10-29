# Revival's world map (the MAPAMUNDI item used from the bag): one picture with no cursor, closed by Use or Back, whose
# labels are the territories (underlined) and the regions inside them, Isla Espejismo added once switch 256 is on, in
# the game's language; three regions are painted in colour, and the island too once it is there, the rest in grey.
# Said whole as it opens.
module PokeAccess
  module RevivalWorldMap
    # The item whose use from the bag shows the map.
    ITEM = :MAPAMUNDI

    # The switch that adds the island to the picture.
    ISLAND_SWITCH = 256

    # The picture's labels by the game's language, north to south and west to east: the territories, the regions with
    # the island, which only the second picture paints, and the regions painted in colour.
    LABELS = {
      :es => [["Tensei", "Sibarnia", "Galran", "Imperio de Kurev", "Tierras Mercantes", "Híspera", "Órnica", "Zahlen",
               "Nostalia"],
              ["Morrigan", "Aurora", "Floresta", "Almia", "Isla Espejismo", "Albion", "Kalos", "Hisui", "Sinnoh",
               "Paldea", "Teselia", "Mandalia", "Cleyra", "Cosmo", "Aura", "Johto", "Kanto", "Alola", "Hoenn"],
              ["Albion", "Paldea", "Teselia"]],
      :en => [["Tensei", "Sibarnia", "Galran", "Kurev Empire", "Merchant Lands", "Hispera", "Ornica", "Zahlen",
               "Nostalia"],
              ["Morrigan", "Aurora", "Fiore", "Almia", "Mirage Island", "Albion", "Kalos", "Hisui", "Sinnoh", "Paldea",
               "Unova", "Mandalia", "Cleyra", "Cosmo", "Orre", "Johto", "Kanto", "Alola", "Hoenn"],
              ["Albion", "Paldea", "Unova"]]
    }

    # Where the island stands among the regions.
    ISLAND_AT = 4

    # Whether an item used from the bag is the map.
    def self.map?(item)
      (item.is_a?(Symbol) ? item : (item.id rescue nil)) == ITEM
    end

    # The picture as it is painted now: the item's name, the territories, the regions and those in colour.
    def self.text
      lands, regions, coloured = LABELS[PokeAccess::RevivalLang.english? ? :en : :es]
      shown = regions.dup
      if ($game_switches[ISLAND_SWITCH] rescue false)
        coloured = [regions[ISLAND_AT]] + coloured
      else
        shown.delete_at(ISLAND_AT)
      end
      PokeAccess.sentences([PokeAccess::Data.item_name(ITEM),
                            PokeAccess::I18n.t(:rv_map_lands, :list => lands.join(", ")),
                            PokeAccess::I18n.t(:rv_map_regions, :list => shown.join(", ")),
                            PokeAccess::I18n.t(:rv_map_colour, :list => coloured.join(", "))])
    end

    # Says the map as its use opens it, queued, with the keys that close it while key hints are said; the info key
    # keeps the picture's labels until it closes.
    def self.opening(item)
      return unless map?(item)
      whole = text
      PokeAccess::Info.set_info(:text, whole)
      PokeAccess.speak(PokeAccess::Verbosity.with_hint(whole, PokeAccess::I18n.t(:rv_map_hint)), false)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # Drops the labels from the info key once the map is closed.
    def self.closed(item)
      PokeAccess::Info.clear_text if map?(item)
    end
  end
end

PokeAccess::Hooks.wrap_singleton("ItemHandlers", :triggerUseFromBag, "revival_world_map", :before) do |args, _r|
  PokeAccess::RevivalWorldMap.opening(args[0])
end

PokeAccess::Hooks.wrap_singleton("ItemHandlers", :triggerUseFromBag, "revival_world_map_closed", :after) do |args, _r|
  PokeAccess::RevivalWorldMap.closed(args[0])
end
