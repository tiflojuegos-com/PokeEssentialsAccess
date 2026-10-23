# The gen-6 nest page (PokemonNestMapScene#pbStartScene): under the page's name, its bottom bar as painted, then the
# places whose squares its point sprites light, named by the town map of the region on show (a point behind a switch
# still off gives way); kept for the info key.
class PokedexNestTest < PokeAccessTest
  BAR = "Kanto, Nido de 25".freeze

  # The town maps: Kanto's points, a square holding a cave behind switch 50 and a meadow; Johto's one point.
  TOWNS = { 0 => ["Kanto", "kanto.png", [[3, 2, "Ruta 1"], [4, 2, "Ruta 1"], [10, 5, "Bosque"],
                                         [12, 7, "Cueva", nil, nil, nil, nil, 50], [12, 7, "Pradera"],
                                         [20, 9, "Isla"]]],
            1 => ["Johto", "johto.png", [[3, 2, "Ruta 29"]]] }.freeze

  test "hands back the page's own value" do
    assert_equal true, nest([[10, 5]]).pbStartScene(25, 0)
  end

  test "says its bar, then each place its map lights, once each, in the order lit" do
    nest([[10, 5], [3, 2], [4, 2]]).pbStartScene(25, 0)
    assert_equal [["#{bar}. #{places('placeBosque, placeRuta 1')}", true]], SpeakCapture.log
  end

  test "gives a point behind a switch still off way to the next point on its square" do
    nest([[12, 7]]).pbStartScene(25, 0)
    assert_equal ["#{bar}. #{places('placePradera')}"], SpeakCapture.lines
  end

  test "names a point behind a switch that is on" do
    $game_switches[50] = true
    nest([[12, 7]]).pbStartScene(25, 0)
    assert_equal ["#{bar}. #{places('placeCueva')}"], SpeakCapture.lines
  end

  test "names the places of the region asked for" do
    nest([[3, 2]]).pbStartScene(25, 1)
    assert_equal ["#{bar}. #{places('placeRuta 29')}"], SpeakCapture.lines
  end

  test "asked for the first region, names its places wherever the player's map lies" do
    with_map_data(1) { nest([[3, 2]]).pbStartScene(25, 0) }
    assert_equal ["#{bar}. #{places('placeRuta 1')}"], SpeakCapture.lines
  end

  test "asked for no region, names the places of the region the engine's data puts the player's map in" do
    with_map_data(1) { nest([[3, 2]]).pbStartScene(25) }
    assert_equal ["#{bar}. #{places('placeRuta 29')}"], SpeakCapture.lines
  end

  test "asked for no region with nothing known of the player's map, names the first region's places" do
    nest([[10, 5]]).pbStartScene(25)
    assert_equal ["#{bar}. #{places('placeBosque')}"], SpeakCapture.lines
  end

  test "asked for no region, names the places of the region the map's metadata puts the player's map in" do
    with_metadata_region(1) { nest([[3, 2]]).pbStartScene(25) }
    assert_equal ["#{bar}. #{places('placeRuta 29')}"], SpeakCapture.lines
  end

  test "names a point the message tables hold no name for as the town map writes it" do
    GameFunctions.with(:pbGetMessageFromHash => lambda { |_type, _raw| "" }) { nest([[10, 5]]).pbStartScene(25, 0) }
    assert_equal ["#{bar}. #{places('Bosque')}"], SpeakCapture.lines
  end

  test "says a text the bar paints twice once" do
    PokeAccess::DexEntry.gen6_area(World.stub_scene, ["Kanto", "Kanto", "Nido de 25"], 0)
    assert_equal [[BAR, true]], SpeakCapture.log
  end

  test "names the places from the town map the engine's data keeps when the page holds none" do
    scene = nest([[3, 2]])
    scene.mapdata = nil
    with_map_data(nil, 0 => [[3, 2, "Ruta 2"]]) { scene.pbStartScene(25, 0) }
    assert_equal ["#{bar}. #{places('placeRuta 2')}"], SpeakCapture.lines
  end

  test "says only the bar for a species with no nests, or one whose lit squares hold no place" do
    nest([]).pbStartScene(25, 0)
    nest([[1, 1]]).pbStartScene(25, 0)
    assert_equal [bar, bar], SpeakCapture.lines
  end

  test "lays the points 16 pixels apart when the region map scene has no square constants (pre-v16)" do
    without_square_constants { nest([[3, 2], [10, 5]]).pbStartScene(776, 0) }
    assert_equal ["#{zone(776)}. Kanto, Nido de 776. #{places('placeRuta 1, placeBosque')}"], SpeakCapture.lines
  end

  test "keeps the page's line for the info key and Ctrl+T, not the info page's" do
    PokeAccess::Info.set_info(:text, "007 Especie7, capturado", "007 Especie7, capturado")
    nest([[10, 5]]).pbStartScene(25, 0)
    said = "#{bar}. #{places('placeBosque')}"
    assert_equal [said, said], [PokeAccess::Info.info_text, PokeAccess::Info.row_text]
  end

  test "heads the page with its name after the species shown" do
    nest([]).pbStartScene(25, 0)
    assert_equal ["#{PokeAccess::I18n.t(:pdx_zone, :name => 'Especie25')}. #{BAR}"], SpeakCapture.lines
  end

  test "composes the bar from its bottom sprite's place and details when nothing was painted" do
    bottom = Struct.new(:maplocation).new("Ruta 3")
    bottom.instance_variable_set(:@mapdetails, "Cueva Oscura")
    PokeAccess::DexEntry.gen6_area(World.stub_scene(:@sprites => { "mapbottom" => bottom }), [], 0)
    assert_equal [["Ruta 3. Cueva Oscura", true]], SpeakCapture.log
  end

  test "says nothing when nothing was painted and the page has no bottom bar" do
    PokeAccess::DexEntry.gen6_area(World.stub_scene, [], 0)
    assert_nothing_spoken
  end

  private

  # The nest page with the town maps and the given squares lit.
  def nest(lit)
    scene = PokemonNestMapScene.new
    scene.mapdata = TOWNS
    scene.lit = lit
    scene
  end

  # The places line for a list of names.
  def places(list)
    PokeAccess::I18n.t(:pdx_places, :list => list)
  end

  # The page's name for species sp, which heads what the page says.
  def zone(sp)
    PokeAccess::I18n.t(:pdx_zone, :name => "Especie#{sp}")
  end

  # The bar as the page says it for species 25: under the page's name.
  def bar
    "#{zone(25)}. #{BAR}"
  end

  # Runs the block with the engine's data provider putting the player's map in region (nil: unknown) and keeping
  # the given town maps' points, as an engine holding its own map data does.
  def with_map_data(region, towns = {})
    provider = Object.new
    provider.define_singleton_method(:map_position) { |_map_id| region.nil? ? nil : [region, 0, 0] }
    provider.define_singleton_method(:town_points) { |r| towns[r] }
    Harness.with_provider(provider) { yield }
  end

  # Runs the block with the game's map metadata putting every map in region, as a gen-6 game's pbGetMetadata answers
  # MetadataMapPosition; the constant and the function are taken away afterwards.
  def with_metadata_region(region)
    made = !Object.const_defined?(:MetadataMapPosition, false)
    Object.const_set(:MetadataMapPosition, 1) if made
    position = Object.const_get(:MetadataMapPosition)
    GameFunctions.with(:pbGetMetadata => lambda { |_map_id, type| type == position ? [region, 4, 6] : nil }) { yield }
  ensure
    Object.send(:remove_const, :MetadataMapPosition) if made
  end

  # Runs the block with PokemonRegionMapScene's square constants removed, as the pre-v16 region map has none.
  def without_square_constants
    k = PokemonRegionMapScene
    saved = [:SQUAREWIDTH, :SQUAREHEIGHT].map { |c| [c, k.const_get(c)] }
    saved.each { |c, _v| k.send(:remove_const, c) }
    yield
  ensure
    saved.each { |c, v| k.const_set(c, v) unless k.const_defined?(c, false) } if saved
  end
end
