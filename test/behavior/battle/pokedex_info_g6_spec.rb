# The v17.2 Pokedex entry over gen-6 data (core/battle/gen6/pokedex_info_g6.rb; Awakening and Soulstones): the shared
# entry reader's types and area squares answered as drawPageInfo and drawPageArea work them out, there being no
# GameData to ask. The gen-6 pass runs with the override in place, as those games do.
Suite.define("pokedex entry, gen 6: the area page names the places its own loop lights") do
  pdx = PokeAccess::PokedexInfoV21
  g6 = PokeAccess::PokedexInfoG6
  saved = [:encounters, :position, :size].map { |m| [m, g6.method(m)] }
  had_find = Object.private_method_defined?(:pbFindEncounter) || Object.method_defined?(:pbFindEncounter)
  made_map = !Object.const_defined?(:PokemonRegionMap_Scene)
  Object.const_set(:PokemonRegionMap_Scene, Module.new) if made_map
  PokemonRegionMap_Scene.const_set(:LEFT, 0) unless PokemonRegionMap_Scene.const_defined?(:LEFT)
  PokemonRegionMap_Scene.const_set(:RIGHT, 29) unless PokemonRegionMap_Scene.const_defined?(:RIGHT)
  begin
    encounters = { 1 => [nil, [[[25, 5]]]], 2 => [nil, [[[25, 5]]]], 3 => [nil, [[[19, 5]]]], 4 => [nil, [[[25, 5]]]] }
    positions = { 1 => [0, 3, 2], 2 => [0, 10, 5], 3 => [0, 12, 7], 4 => [1, 1, 1] }
    sizes = { 1 => [2, "11"] }
    g6.define_singleton_method(:encounters) { encounters }
    g6.define_singleton_method(:position) { |m| positions[m] }
    g6.define_singleton_method(:size) { |m| sizes[m] }
    Object.send(:define_method, :pbFindEncounter) do |enc, species|
      (enc || []).any? { |slots| (slots || []).any? { |s| s[0] == species } }
    end unless had_find

    scene = Object.new
    scene.instance_variable_set(:@species, 25)
    scene.instance_variable_set(:@region, 0)
    scene.instance_variable_set(:@mapdata, { 0 => [nil, nil, [[3, 2, "Ruta 1"], [4, 2, "Ruta 1 Norte"], [10, 5, "Bosque"],
                                                               [12, 7, "Cueva"], [1, 1, "Cabo Lejano"]]] })
    eq "the maps of the region holding the species, the second square of a two-square map included; not a map of " \
       "another region, whose square is a place here too",
       pdx.area_places(scene), ["placeRuta 1", "placeRuta 1 Norte", "placeBosque"]
    places = PokeAccess::I18n.t(:pdx_places, :list => "placeRuta 1, placeRuta 1 Norte, placeBosque")
    eq "the page's area line then names them",
       pdx.area_text("Pikachu", "Kanto, Pikachu's area", pdx.area_places(scene)), "Kanto, Pikachu's area. #{places}"
  ensure
    saved.each { |m, orig| g6.define_singleton_method(m, orig) }
    Object.send(:remove_method, :pbFindEncounter) unless had_find
    Object.send(:remove_const, :PokemonRegionMap_Scene) if made_map
  end
end

# The info page draws the type icons from the v17 dex data (two bytes at offset 8 of the form's record), there being
# no GameData to ask.
Suite.define("pokedex entry, gen 6: an owned species' types come from the dex data file, as its page reads them") do
  file = Struct.new(:bytes) do
    def fgetb; bytes.shift; end
    def close; end
  end
  Object.send(:alias_method, :g6_spec_open_dex, :pbOpenDexData)
  Object.send(:alias_method, :g6_spec_dex_offset, :pbDexDataOffset)
  Object.send(:define_method, :pbOpenDexData) { file.new([13, 4]) }
  Object.send(:define_method, :pbDexDataOffset) { |_f, _s, off| $g6_dex_offset = off }
  begin
    scene = Object.new
    scene.instance_variable_set(:@species, 25)
    eq "the two type bytes of the form's record, named", PokeAccess::PokedexInfoV21.shown_types(scene, nil, true),
       [PBTypes.getName(13), PBTypes.getName(4)]
    eq "read at the offset the page reads them", $g6_dex_offset, 8
    eq "and none for a species only seen", PokeAccess::PokedexInfoV21.shown_types(scene, nil, false), []
    types = PokeAccess::I18n.t(:pdx_type, :t => "#{PBTypes.getName(13)} #{PBTypes.getName(4)}")
    eq "said on the info page after the category, as painted",
       PokeAccess::PokedexInfoV21.painted_info(["025 Pikachu", "Mouse Pokemon", "Height", "0.4 m"], scene, nil, true),
       ["025 Pikachu", PokeAccess::I18n.t(:dex_caught), "Mouse Pokemon", types, "Height", "0.4 m"].join(", ")
  ensure
    Object.send(:alias_method, :pbOpenDexData, :g6_spec_open_dex)
    Object.send(:alias_method, :pbDexDataOffset, :g6_spec_dex_offset)
    Object.send(:remove_method, :g6_spec_open_dex)
    Object.send(:remove_method, :g6_spec_dex_offset)
  end
end
