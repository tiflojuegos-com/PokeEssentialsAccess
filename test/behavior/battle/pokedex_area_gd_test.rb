# The v21 Pokedex area and forms pages say what they paint, else a composed line, and the area page names the places
# its squares light: by the game's own pbGetEncounterPoints, or by a v19 page's inline loop over the encounter tables.
class PokedexAreaGdTest < PokeAccessTest
  PDX = PokeAccess::PokedexInfoV21
  # A region's town map points, [x, y, name], with the switch that hides a point at [7].
  POINTS = [[3, 2, "Ruta 1"], [4, 2, "Ruta 1 Norte"], [10, 5, "Bosque"], [12, 7, "Cueva"], [1, 1, "Cabo Lejano"],
            [14, 9, "Isla", nil, nil, nil, nil, 50]]
  # A v19 world's encounter tables, [species, map]: Pikachu on maps 1, 2, 3 and 5, Rattata on map 4.
  TABLES = [[:PIKACHU, 1], [:PIKACHU, 2], [:PIKACHU, 3], [:RATTATA, 4], [:PIKACHU, 5]]
  # Each map's town-map position [region, x, y] and size [width, mask]: map 1 two squares wide, map 3 in region 1,
  # map 5 on the hidden point.
  METAS = { 1 => [[0, 3, 2], [2, "11"]], 2 => [[0, 10, 5], nil], 3 => [[1, 1, 1], nil], 4 => [[0, 12, 7], nil],
            5 => [[0, 14, 9], nil] }

  test "the area page is said as it paints it" do
    PokemonPokedexInfo_Scene.new.drawPage(2)
    assert_equal [["Area unknown, Kanto", true]], SpeakCapture.log
  end

  test "the area page painted again unchanged is not said again" do
    scene = PokemonPokedexInfo_Scene.new
    scene.drawPage(2)
    SpeakCapture.clear
    scene.drawPage(2)
    assert_equal [], SpeakCapture.log
  end

  test "the page's paint capture is let go once the page is read" do
    PokemonPokedexInfo_Scene.new.drawPage(2)
    assert_equal false, PokeAccess::PaintCapture.armed?(:pdx_page)
  end

  test "an area page that paints nothing says the species' area" do
    ["", "   ", nil].each do |painted|
      assert_equal t(:pdx_zone, :name => "Pikachu"), PDX.area_text("Pikachu", painted), "painted #{painted.inspect}"
    end
  end

  test "the places the page lights are named after what it painted" do
    assert_equal "Kanto. #{t(:pdx_places, :list => 'placeRuta 1, placeBosque')}",
                 PDX.area_text("Pikachu", "Kanto", ["placeRuta 1", "placeBosque"])
  end

  test "with no place lit, what the page painted stands alone" do
    [nil, []].each { |places| assert_equal "Kanto", PDX.area_text("Pikachu", "Kanto", places), "#{places.inspect}" }
  end

  test "the squares the game's encounter points light are named, each place once, the unlit left out" do
    town = Struct.new(:point).new([[3, 2, "Ruta 1"], [4, 2, "Ruta 1"], [10, 5, "Bosque"], [12, 7, "Cueva"]])
    scene = lit_scene(town, [[3, 2], [4, 2], [10, 5]], 30)
    assert_equal ["placeRuta 1", "placeBosque"], with_region_map(2, 31) { PDX.area_places(scene) }
  end

  test "a page that sizes its map by the picture numbers its squares by the picture's width" do
    arcky = lit_scene(Struct.new(:point).new([[15, 62, "Ruta 1"], [25, 103, "Otra"]]), [[15, 62]], 50)
    arcky.instance_variable_set(:@mapWidth, 800)
    assert_equal ["placeRuta 1"], with_region_map(0, 29, 16) { PDX.area_places(arcky) }
  end

  test "encounter points the game fails to give name no places" do
    failing = { "points that raise" => lambda { raise ArgumentError, "no map" }, "no points" => lambda { nil } }
    failing.each do |what, pts|
      scene = Object.new
      scene.define_singleton_method(:pbGetEncounterPoints, &pts)
      scene.instance_variable_set(:@mapdata, Struct.new(:point).new(POINTS))
      assert_equal [], with_region_map(0, 29) { PDX.area_places(scene) }, what
    end
  end

  test "a v19 page lights the maps of its region whose encounters hold the species, each of their squares" do
    assert_equal ["placeRuta 1", "placeRuta 1 Norte", "placeBosque"], v19_places(v19_scene)
  end

  test "a v19 point behind a switch lights nothing until the switch is on" do
    scene = v19_scene
    hidden = 14 + 9 * 30
    off = with_v19_world(TABLES, METAS) { PDX.inline_encounter_points(scene)[hidden] }
    assert_nil off, "its square stays dark while the switch is off"
    $game_switches[50] = true
    assert_equal ["placeRuta 1", "placeRuta 1 Norte", "placeBosque", "placeIsla"], v19_places(scene),
                 "and it is named once the switch is on"
  end

  test "a v19 map with no town-map data lights nothing" do
    metas = METAS.reject { |map, _m| map == 2 }
    assert_equal ["placeRuta 1", "placeRuta 1 Norte"], v19_places(v19_scene, TABLES, metas)
  end

  test "a v19 map's size lights its squares row by row, the blanks in its mask staying dark" do
    points = [[3, 2, "A"], [4, 2, "B"], [3, 3, "C"], [4, 3, "D"], [3, 4, "E"], [4, 4, "F"]]
    assert_equal ["placeA", "placeB", "placeC", "placeF"],
                 v19_places(v19_scene(points), [[:PIKACHU, 1]], { 1 => [[0, 3, 2], [2, "111001"]] })
  end

  test "a v19 map one square wide lights its squares down the column" do
    points = [[3, 2, "A"], [3, 3, "B"], [4, 2, "C"]]
    assert_equal ["placeA", "placeB"], v19_places(v19_scene(points), [[:PIKACHU, 1]], { 1 => [[0, 3, 2], [1, "11"]] })
  end

  test "a v19 map whose size has no width lights its own square alone" do
    points = [[3, 2, "A"], [4, 2, "B"]]
    assert_equal ["placeA"], v19_places(v19_scene(points), [[:PIKACHU, 1]], { 1 => [[0, 3, 2], [0, "11"]] })
  end

  test "a v19 page with no encounter tables names no places" do
    assert_equal [], v19_places(v19_scene, nil)
  end

  test "the forms page is said as it paints it, the sex included" do
    scene = PokemonPokedexInfo_Scene.new
    scene.instance_variable_set(:@paint, lambda { drawTextEx(nil, 0, 0, 200, 1, "Pikachu, Female") })
    scene.drawPage(3)
    assert_equal [["Pikachu, Female", true]], SpeakCapture.log
  end

  test "a forms page that paints nothing says the form's name, else the species' forms" do
    form = Struct.new(:form_name)
    { form.new("Alola") => t(:pdx_form, :name => "Pikachu", :f => "Alola"),
      form.new("") => t(:pdx_forms, :name => "Pikachu"), form.new(nil) => t(:pdx_forms, :name => "Pikachu"),
      Object.new => t(:pdx_forms, :name => "Pikachu") }.each do |data, want|
      [nil, "  "].each do |painted|
        assert_equal want, PDX.forms_text("Pikachu", data, painted), "#{data.inspect}, painted #{painted.inspect}"
      end
    end
  end

  private

  def t(key, args = {})
    PokeAccess::I18n.t(key, args)
  end

  # An area page with its own pbGetEncounterPoints, lighting squares [x, y] of a grid width squares wide, over town.
  def lit_scene(town, squares, width)
    scene = Object.new
    scene.instance_variable_set(:@mapdata, town)
    scene.define_singleton_method(:pbGetEncounterPoints) do
      lit = []
      squares.each { |x, y| lit[x + y * width] = true }
      lit
    end
    scene
  end

  # A v19 area page on Pikachu in region 0, its town map's points in the older [region][2] shape, with its own
  # pbFindEncounter as the three v19 games have it.
  def v19_scene(points = POINTS)
    scene = Object.new
    scene.instance_variable_set(:@species, :PIKACHU)
    scene.instance_variable_set(:@region, 0)
    scene.instance_variable_set(:@mapdata, { 0 => [nil, nil, points] })
    def scene.pbFindEncounter(types, species); types.include?(species); end
    scene
  end

  # The places a v19 page names in a world of those tables and map data, on a region map 30 squares wide.
  def v19_places(scene, tables = TABLES, metas = METAS)
    with_v19_world(tables, metas) { PDX.area_places(scene) }
  end

  # Runs the block on a region map whose squares run from left to right, square_width pixels each, as the game's
  # PokemonRegionMap_Scene defines them.
  def with_region_map(left, right, square_width = 16)
    prior = Object.const_defined?(:PokemonRegionMap_Scene) ? Object.send(:remove_const, :PokemonRegionMap_Scene) : nil
    map = Module.new
    { :LEFT => left, :RIGHT => right, :SQUARE_WIDTH => square_width }.each { |k, v| map.const_set(k, v) }
    Object.const_set(:PokemonRegionMap_Scene, map)
    yield
  ensure
    Object.send(:remove_const, :PokemonRegionMap_Scene)
    Object.const_set(:PokemonRegionMap_Scene, prior) if prior
  end

  # Runs the block in a v19 world on a region map 30 squares wide: the encounter tables of the current version
  # ([species, map]; nil for a game without them) and each map's town-map [position, size], as GameData answers them.
  def with_v19_world(tables, metas)
    enc = Struct.new(:types, :map)
    data = Struct.new(:town_map_position, :town_map_size)
    prior = GameData.const_defined?(:Encounter) ? GameData.send(:remove_const, :Encounter) : nil
    if tables
      GameData.const_set(:Encounter, Class.new)
      GameData::Encounter.define_singleton_method(:each_of_version) do |_version, &b|
        tables.each { |species, map| b.call(enc.new([species], map)) }
      end
    end
    try_get = GameData::MapMetadata.singleton_class.instance_method(:try_get)
    GameData::MapMetadata.define_singleton_method(:try_get) { |m| metas[m] ? data.new(*metas[m]) : nil }
    version = $PokemonGlobal.respond_to?(:encounter_version) ? $PokemonGlobal.method(:encounter_version) : nil
    $PokemonGlobal.define_singleton_method(:encounter_version) { 0 }
    with_region_map(2, 31) { yield }
  ensure
    GameData.send(:remove_const, :Encounter) if GameData.const_defined?(:Encounter)
    GameData.const_set(:Encounter, prior) if prior
    GameData::MapMetadata.singleton_class.send(:define_method, :try_get, try_get)
    if version
      $PokemonGlobal.define_singleton_method(:encounter_version, version)
    else
      $PokemonGlobal.singleton_class.send(:remove_method, :encounter_version)
    end
  end
end
