# The v17.2 Pokedex entry (PokemonPokedexInfo_Scene over gen-6 data, Awakening and Soulstones): the shared reader
# (battle/v21) asks GameData for the types the info page draws and for the squares the area page lights, and gets
# nothing on this era, so both are answered here the way drawPageInfo and drawPageArea work them out.
module PokeAccess
  module PokedexInfoG6
    # The type names drawPageInfo draws for an owned species: the form's two type bytes in the dex data (offset 8),
    # none for a species only seen.
    def self.shown_types(scene, owned)
      return [] if owned == false
      species = PokeAccess.ivar(scene, :@species)
      form = (PokeAccess.ivar(scene, :@form) || 0).to_i
      fspecies = (pbGetFSpeciesFromForm(species, form) rescue species)
      PokeAccess::Data.species_types(fspecies).reject { |n| n.to_s.empty? }
    rescue StandardError
      []
    end

    # The game's data drawPageArea reads: the encounter tables, and a map's town-map position and size.
    def self.encounters; load_data("Data/encounters.dat"); end
    def self.position(map); pbGetMetadata(map, MetadataMapPosition); end
    def self.size(map); pbGetMetadata(map, MetadataMapSize); end

    # The squares drawPageArea lights, by index in its row-major grid: every map whose encounters hold the species,
    # on the region shown, not behind an off switch, over its town-map size; nil when the data cannot be read.
    def self.area_points(scene)
      species = PokeAccess.ivar(scene, :@species)
      region = PokeAccess.ivar(scene, :@region)
      locs = (PokeAccess.ivar(scene, :@mapdata)[region][2] rescue nil) || []
      width = 1 + PokemonRegionMap_Scene::RIGHT - PokemonRegionMap_Scene::LEFT
      points = []
      encdata = encounters
      encdata.keys.each do |enc|
        next unless pbFindEncounter(encdata[enc][1], species)
        pos = position(enc)
        next if !pos || pos[0] != region
        next if locs.any? { |l| l[0] == pos[1] && l[1] == pos[2] && l[7] && !$game_switches[l[7]] }
        size = size(enc)
        if size && size[0] && size[0] > 0
          w = size[0]
          h = (size[1].length * 1.0 / w).ceil
          w.times do |i|
            h.times { |j| points[pos[1] + i + (pos[2] + j) * width] = true if size[1][i + j * w, 1].to_i > 0 }
          end
        else
          points[pos[1] + pos[2] * width] = true
        end
      end
      points
    rescue StandardError
      nil
    end
  end
end

if PokeAccess::Engine.gen6?
  PokeAccess::Hooks.override("PokeAccess::PokedexInfoV21", :shown_types, :optional => true,
                             :tag => "gen6") do |_m, _o, args|
    PokeAccess::PokedexInfoG6.shown_types(args[0], args[2])
  end
  PokeAccess::Hooks.override("PokeAccess::PokedexInfoV21", :inline_encounter_points, :optional => true,
                             :tag => "gen6") do |_m, _o, args|
    PokeAccess::PokedexInfoG6.area_points(args[0])
  end
end
