# A bridge tile (on any layer, or any tile whose layers cannot be read) is the water under it off the bridge and the
# bridge on it, its answers kept per bridge height, other tiles' once; the surf launch alike, regions walked or not.
class TerrainBridgeMemoTest < PokeAccessTest
  Terrain = PokeAccess::World::Terrain
  # A walled room with the player at its top left, where the tests lay bridge tiles, the first at (3, 1).
  ROOM = ["########",
          "#@.....#",
          "#......#",
          "########"]
  # A shore room whose way to the target at (10, 1) crosses the water below; the pond at its top leads nowhere.
  SHORE = ["############",
           "#@....~~#..#",
           "#.....~~#..#",
           "#.......#..#",
           "#.......~~~#",
           "#.......~~~#",
           "############"]

  # Map layers that fail to be read.
  class Unreadable
    def [](*_); raise ArgumentError, "unreadable"; end
  end

  # The map's layers with the bridge tile at (3, 1) moved to the layer given.
  class BridgeOnLayer
    def initialize(inner, layer); @inner = inner; @layer = layer; end
    def [](x, y, layer)
      return @inner[x, y, layer] unless [x, y] == [3, 1]
      layer == @layer ? TestMapData::BRIDGE_TILE : 0
    end
  end

  test "reads a bridge tile as the water under it off the bridge and as the bridge on it, at any height" do
    $game_map.load_grid(ROOM)
    $game_map.place_bridge(3, 1)
    $game_map.place_bridge(5, 2)
    got = [0, 1, 2, 0].map do |h|
      $PokemonGlobal.bridge = h
      [Terrain.kind(3, 1), Terrain.number(3, 1), Terrain.surfable?(3, 1), Terrain.kind(3, 1, true), Terrain.label(3, 1),
       Terrain.kind(5, 2)]
    end
    off = [:water, 7, true, :bridge, :surf_bridge, :water]
    on = [:bridge, 15, false, :bridge, :surf_bridge, :bridge]
    assert_equal [off, on, on, off], got,
                 "off it, on it at heights 1 and 2, off it again; asked for bridges and named, the bridge at any " \
                 "height; another bridge tile alike"
  end

  test "takes a tile for a bridge's whichever of its three layers holds the bridge" do
    $game_map.load_grid(ROOM)
    $game_map.place_bridge(3, 1)
    got = [0, 1, 2].map do |layer|
      PokeAccess::World.reset!
      with_data(BridgeOnLayer.new($game_map.data, layer)) do
        [0, 2].map do |h|
          $PokemonGlobal.bridge = h
          Terrain.kind(3, 1)
        end
      end
    end
    assert_equal [[:water, :bridge]] * 3, got
  end

  test "asks again at another height only a bridge tile, or a step with a bridge tile at either end" do
    $game_map.load_grid(ROOM)
    $game_map.place_bridge(3, 1)
    $game_map.set_terrain(5, 1, 10)
    $game_map.place_ledge(5, 2, 2)
    asked = counting_questions do
      PokeAccess::Pathfinder.invalidate_cache(true)
      [0, 2].each do |h|
        $PokemonGlobal.bridge = h
        Terrain.kind(5, 1)
        Terrain.kind(5, 2)
        Terrain.kind(3, 1)
        [[5, 1], [2, 1], [3, 1]].each { |x, y| PokeAccess::World::Probe.step?(x, y, 6) }
      end
    end
    keys = [[:tag, 5, 1], [:tag, 5, 2], [:tag, 3, 1], [:pass, 5, 1, 6], [:pass, 2, 1, 6], [:pass, 3, 1, 6]]
    assert_equal [1, 1, 2, 1, 2, 2], keys.map { |k| asked[k] },
                 "the grass, the ledge the tileset tags and the step off the grass once; the bridge, onto it and " \
                 "off it, once a height"
  end

  test "keeps a tile's answer per bridge height where the map's layers cannot be read" do
    $game_map.load_grid(ROOM)
    { "no layers" => nil, "layers that fail" => Unreadable.new }.each do |what, data|
      PokeAccess::World.reset!
      asked = counting_questions do
        with_data(data) do
          [0, 2].each do |h|
            $PokemonGlobal.bridge = h
            Terrain.kind(5, 1)
          end
        end
      end
      assert_equal 2, asked[[:tag, 5, 1]], "with #{what}, the ground tile is taken for a bridge's"
    end
  end

  test "finds the same shore to push off from whether the regions are walked yet or not" do
    with_tile_world(SHORE) do
      regions = PokeAccess::Routes::Regions
      unwalked = regions.foot.done?
      fresh = PokeAccess::Routes::Planner.surf(10, 1)
      regions.foot.tiles
      walked = regions.foot.done?
      again = PokeAccess::Routes::Planner.surf(10, 1)
      assert_equal [false, [[7, 4], 6], true, [[7, 4], 6]], [unwalked, launch(fresh), walked, launch(again)],
                   "the shore (7, 4), pushing off to the right, both times"
    end
  end

  private

  # Runs the block counting the engine's terrain questions ([:tag, x, y]) and steps asked ([:pass, x, y, d]); the
  # counts, with the map's own methods put back.
  def counting_questions
    asked = Hash.new(0)
    m = $game_map
    tag = m.method(:terrain_tag)
    pass = m.method(:passable?)
    m.define_singleton_method(:terrain_tag) { |x, y, *a| asked[[:tag, x, y]] += 1; tag.call(x, y, *a) }
    m.define_singleton_method(:passable?) { |x, y, d| asked[[:pass, x, y, d]] += 1; pass.call(x, y, d) }
    yield
    asked
  ensure
    m.singleton_class.send(:remove_method, :terrain_tag)
    m.singleton_class.send(:remove_method, :passable?)
  end

  # Runs the block with the map's data read as data.
  def with_data(data)
    $game_map.define_singleton_method(:data) { data }
    yield
  ensure
    $game_map.singleton_class.send(:remove_method, :data)
  end

  # Where a surf plan has the player push off: [the tile its route ends on, the way it pushes off].
  def launch(surf)
    [traced($game_player.x, $game_player.y, 0, surf[0]).last.tile, surf[1]]
  end
end
