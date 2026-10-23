# The v17.2 Pokedex entry over gen-6 data (Awakening, Soulstones), with no GameData to ask: the info page's types from
# the dex data file, and the area page's lit squares from the encounter tables, as drawPageInfo and drawPageArea do.
class PokedexInfoG6Test < PokeAccessTest
  PDX = PokeAccess::PokedexInfoV21
  G6 = PokeAccess::PokedexInfoG6
  # The region's town map points, [x, y, name], with the switch that hides a point at [7].
  POINTS = [[3, 2, "Ruta 1"], [4, 2, "Ruta 1 Norte"], [10, 5, "Bosque"], [12, 7, "Cueva"], [1, 1, "Cabo Lejano"],
            [14, 9, "Isla", nil, nil, nil, nil, 50]]
  # The encounter tables by map, each [slots of [species, level]]: Pikachu (25) on maps 1, 2, 4 and 5, Rattata (19)
  # on map 3.
  ENCOUNTERS = { 1 => [nil, [[[25, 5]]]], 2 => [nil, [[[25, 5]]]], 3 => [nil, [[[19, 5]]]], 4 => [nil, [[[25, 5]]]],
                 5 => [nil, [[[25, 5]]]] }
  # Each map's town-map position [region, x, y]: map 4 in region 1, map 5 on the hidden point.
  POSITIONS = { 1 => [0, 3, 2], 2 => [0, 10, 5], 3 => [0, 12, 7], 4 => [1, 1, 1], 5 => [0, 14, 9] }
  # Map 1 is two squares wide.
  SIZES = { 1 => [2, "11"] }

  test "an owned species' types are the type bytes of its dex record, named" do
    assert_equal [PBTypes.getName(1), PBTypes.getName(2)], PDX.shown_types(dex_scene(1), nil, true)
  end

  test "a species whose two type bytes match has one type" do
    assert_equal [PBTypes.getName(13)], PDX.shown_types(dex_scene(25), nil, true)
  end

  test "a species only seen shows no types, and one whose ownership is unknown shows them" do
    assert_equal [[], [PBTypes.getName(13)]], [false, nil].map { |owned| PDX.shown_types(dex_scene(25), nil, owned) }
  end

  test "a form's types are read from the form's own record" do
    scene = dex_scene(1)
    scene.instance_variable_set(:@form, 1)
    forms = { :pbGetFSpeciesFromForm => lambda { |species, form| form == 1 ? 25 : species } }
    assert_equal [PBTypes.getName(13)], GameFunctions.with(forms) { PDX.shown_types(scene, nil, true) }
  end

  test "the info page says the types after the category, as painted" do
    painted = ["025 Pikachu", "Mouse Pokemon", "Height", "0.4 m"]
    assert_equal ["025 Pikachu", PokeAccess::I18n.t(:dex_caught), "Mouse Pokemon",
                  PokeAccess::I18n.t(:pdx_type, :t => PBTypes.getName(13)), "Height", "0.4 m"].join(", "),
                 PDX.painted_info(painted, dex_scene(25), nil, true)
  end

  test "the area page names the maps of its region holding the species, each of their squares" do
    assert_equal ["placeRuta 1", "placeRuta 1 Norte", "placeBosque"], area_places
  end

  test "the area line names the places after what the page painted" do
    places = PokeAccess::I18n.t(:pdx_places, :list => "placeRuta 1, placeRuta 1 Norte, placeBosque")
    assert_equal "Kanto, Pikachu's area. #{places}", PDX.area_text("Pikachu", "Kanto, Pikachu's area", area_places)
  end

  test "a point behind a switch lights nothing until the switch is on" do
    lit = [false, true].map do |on|
      $game_switches[50] = on
      with_area_data(ENCOUNTERS, POSITIONS, SIZES) { PDX.inline_encounter_points(dex_scene(25))[14 + 9 * 30] }
    end
    assert_equal [nil, true], lit, "its square, dark while the switch is off"
    assert_equal ["placeRuta 1", "placeRuta 1 Norte", "placeBosque", "placeIsla"], area_places,
                 "and named once it is on"
  end

  test "a map with no town-map position lights nothing" do
    positions = POSITIONS.reject { |map, _p| map == 2 }
    assert_equal ["placeRuta 1", "placeRuta 1 Norte"], area_places(ENCOUNTERS, positions)
  end

  test "a map's size lights its squares row by row, the blanks in its mask staying dark" do
    points = [[3, 2, "A"], [4, 2, "B"], [3, 3, "C"], [4, 3, "D"], [3, 4, "E"], [4, 4, "F"]]
    assert_equal ["placeA", "placeB", "placeC", "placeF"],
                 area_places({ 1 => [nil, [[[25, 5]]]] }, { 1 => [0, 3, 2] }, { 1 => [2, "111001"] }, points)
  end

  test "a map one square wide lights its squares down the column" do
    points = [[3, 2, "A"], [3, 3, "B"], [4, 2, "C"]]
    assert_equal ["placeA", "placeB"],
                 area_places({ 1 => [nil, [[[25, 5]]]] }, { 1 => [0, 3, 2] }, { 1 => [1, "11"] }, points)
  end

  test "a map whose size has no width lights its own square alone" do
    points = [[3, 2, "A"], [4, 2, "B"]]
    assert_equal ["placeA"], area_places({ 1 => [nil, [[[25, 5]]]] }, { 1 => [0, 3, 2] }, { 1 => [0, "11"] }, points)
  end

  test "with encounter data it cannot read, the area page names no places" do
    assert_equal [], area_places(nil)
  end

  private

  # An entry scene on species (a gen-6 number), form 0, region 0, its town map's points in the [region][2] shape.
  def dex_scene(species, points = POINTS)
    scene = Object.new
    scene.instance_variable_set(:@species, species)
    scene.instance_variable_set(:@form, 0)
    scene.instance_variable_set(:@region, 0)
    scene.instance_variable_set(:@mapdata, { 0 => [nil, nil, points] })
    scene
  end

  # The places Pikachu's area page names, its game's data being encounters (nil: unreadable), positions and sizes
  # by map, on a region map 30 squares wide.
  def area_places(encounters = ENCOUNTERS, positions = POSITIONS, sizes = SIZES, points = POINTS)
    with_area_data(encounters, positions, sizes) { PDX.area_places(dex_scene(25, points)) }
  end

  # Runs the block with drawPageArea's data answering as given, the game's pbFindEncounter, and a region map whose
  # squares run from column 2 to 31.
  def with_area_data(encounters, positions, sizes)
    saved = [:encounters, :position, :size].map { |m| [m, G6.method(m)] }
    G6.define_singleton_method(:encounters) { encounters || raise(IOError, "Data/encounters.dat") }
    G6.define_singleton_method(:position) { |map| positions[map] }
    G6.define_singleton_method(:size) { |map| sizes[map] }
    find = { :pbFindEncounter => lambda { |enc, species| enc.any? { |slots| slots.any? { |s| s[0] == species } } } }
    prior = Object.const_defined?(:PokemonRegionMap_Scene) ? Object.send(:remove_const, :PokemonRegionMap_Scene) : nil
    map = Module.new
    map.const_set(:LEFT, 2)
    map.const_set(:RIGHT, 31)
    Object.const_set(:PokemonRegionMap_Scene, map)
    GameFunctions.with(find) { yield }
  ensure
    saved.each { |m, orig| G6.define_singleton_method(m, orig) }
    Object.send(:remove_const, :PokemonRegionMap_Scene)
    Object.const_set(:PokemonRegionMap_Scene, prior) if prior
  end
end
