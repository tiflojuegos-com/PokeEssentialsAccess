# A map whose file holds more than RPG Maker XP's own fields, as an editor's extra layers (Terrain.extra_fields?): its three
# tile ids no longer tell what is on a tile, so each tile is asked of the game, whatever those fields hold; any other map
# keeps sharing what it asks by kind of tile.
class TerrainExtraFieldsTest < PokeAccessTest
  include TileWorldHelpers

  Terrain = PokeAccess::World::Terrain
  ROOM = ["#######", "#@..~.#", "#.....#", "#######"].freeze
  EXTRA = "@extended_layers".freeze

  # Every tile the same to the three layers, as a map painted on an editor's own layers.
  class BlankLayers
    def [](_x, _y, _z); 0; end
  end

  test "asks the game about each tile of a map holding more than RPG Maker XP's fields" do
    with_tile_world(ROOM) do |world|
      painted_elsewhere(world, EXTRA)
      assert_equal [true, false, false], [Terrain.surfable?(4, 1), Terrain.surfable?(2, 1), Terrain.surfable?(5, 1)]
      assert_equal true, Terrain.water_on_map?
    end
  end

  test "keeps sharing by kind of tile on a map with only RPG Maker XP's fields" do
    with_tile_world(ROOM) do |world|
      painted_elsewhere(world)
      assert_equal Terrain.surfable?(2, 1), Terrain.surfable?(4, 1)
    end
  end

  test "tells a map with no file to read from one holding more" do
    with_tile_world(ROOM) do |world|
      read_afresh
      world.instance_variable_set(:@map, nil)
      assert_equal false, Terrain.extra_fields?
      read_afresh
      world.instance_variable_set(:@map, map_file)
      assert_equal false, Terrain.extra_fields?, "RPG Maker XP's own, each of them"
      read_afresh
      world.instance_variable_set(:@map, map_file("@anything_else"))
      assert_equal true, Terrain.extra_fields?, "whatever the field is called"
    end
  end

  test "reads a new map's file afresh, and one that comes back with a visit" do
    with_tile_world(ROOM) do |world|
      read_afresh
      world.instance_variable_set(:@map, map_file(EXTRA))
      assert_equal true, Terrain.extra_fields?
      world.instance_variable_set(:@map, map_file)
      assert_equal true, Terrain.extra_fields?, "kept for the map"
      Terrain.forget
      assert_equal false, Terrain.extra_fields?, "a new map"
      kept = Terrain.saved
      assert_equal false, Terrain.extra_fields?
      world.instance_variable_set(:@map, map_file(EXTRA))
      Terrain.restore(kept)
      assert_equal true, Terrain.extra_fields?, "a map come back to"
    end
  end

  test "takes a bridge from the game where the three layers do not show one, only on a map holding more" do
    on_bridge_elsewhere do |map|
      map.instance_variable_set(:@map, map_file(EXTRA))
      read_afresh
      assert_equal [true, false], [Terrain.bridge_at?(2, 1), Terrain.bridge_at?(3, 1)]
      map.instance_variable_set(:@map, map_file)
      read_afresh
      assert_equal false, Terrain.bridge_at?(2, 1)
    end
  end

  test "keeps the bridge the three layers do show, on a map holding more too" do
    $game_map.load_grid(["#####", "#@..#", "#...#", "#####"])
    $game_map.place_bridge(2, 1)
    $game_map.instance_variable_set(:@map, map_file(EXTRA))
    read_afresh
    engine_says_none = lambda { |*_a| 0 }
    replacing(PokeAccess::World::Engine, :terrain_tag, engine_says_none) { assert_equal true, Terrain.bridge_at?(2, 1) }
  ensure
    $game_map.instance_variable_set(:@map, nil)
    $game_map.clear_grid
    PokeAccess::Pathfinder.invalidate_cache(true)
  end

  private

  # A map file with RPG Maker XP's fields and the ones given.
  def map_file(*extra)
    raw = Object.new
    (Terrain::MAP_FIELDS + extra).each { |f| raw.instance_variable_set(f, nil) }
    raw
  end

  def read_afresh
    PokeAccess::World::Epoch.settle
    Terrain.reset!
  end

  # The world with nothing on its three layers and these fields in its file; the game still tells each tile.
  def painted_elsewhere(world, *extra)
    world.instance_variable_set(:@data, BlankLayers.new)
    world.instance_variable_set(:@map, map_file(*extra))
    read_afresh
  end

  # A bridge the game tells of at (2,1) with nothing to show for it on the three layers.
  def on_bridge_elsewhere
    map = $game_map
    map.load_grid(["#####", "#@..#", "#...#", "#####"])
    map.place_bridge(2, 1)
    map.define_singleton_method(:data) { BlankLayers.new }
    yield map
  ensure
    map.singleton_class.send(:remove_method, :data)
    map.instance_variable_set(:@map, nil)
    map.clear_grid
    PokeAccess::Pathfinder.invalidate_cache(true)
  end

  def replacing(obj, name, body)
    was = obj.method(name)
    meta = class << obj; self; end
    meta.send(:define_method, name, &body)
    yield
  ensure
    meta.send(:define_method, name, was)
  end
end
