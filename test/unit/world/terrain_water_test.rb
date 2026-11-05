# Whether a map has water at all (Terrain.water_on_map?): told by its tiles, row by row where a deadline is given, kept until the
# map or its tiles change; and what it spares on a map with none: the way by water and the map frames' walk of it.
class TerrainWaterTest < PokeAccessTest
  include TileWorldHelpers

  Terrain = PokeAccess::World::Terrain
  Regions = PokeAccess::Routes::Regions
  DRY = ["#######", "#@....#", "#.....#", "#######"].freeze

  # A map's tile ids by layer: the same three everywhere but on one tile.
  class LayeredData
    def initialize(ids, odd_tile = nil, odd_ids = nil)
      @ids = ids
      @odd_tile = odd_tile
      @odd_ids = odd_ids
    end

    def [](x, y, layer)
      ([x, y] == @odd_tile ? @odd_ids : @ids)[layer]
    end
  end

  WET = ["#######", "#@....#", "#....~#", "#######"].freeze

  test "tells a map with water from one without" do
    with_tile_world(DRY) { assert_equal false, Terrain.water_on_map? }
    with_tile_world(WET) { assert_equal true, Terrain.water_on_map? }
  end

  test "reads every column of every row" do
    with_tile_world(["~######", "#@....#", "#######"]) { assert_equal true, Terrain.water_on_map? }
    with_tile_world(["#######", "#@....#", "######~"]) { assert_equal true, Terrain.water_on_map? }
  end

  test "goes on from the row it stopped at when the deadline comes first" do
    with_tile_world(WET) do
      assert_nil Terrain.water_on_map?(PokeAccess.clock - 1), "a deadline already past stops it after a row"
      assert_equal 1, Terrain.instance_variable_get(:@wet_row)
      assert_nil Terrain.water_on_map?(PokeAccess.clock - 1)
      assert_equal 2, Terrain.instance_variable_get(:@wet_row)
      assert_equal true, Terrain.water_on_map?(PokeAccess.clock - 1), "and the third row has it"
    end
  end

  test "never leaves a whole map unanswered for a deadline past at its last row" do
    with_tile_world(DRY) do
      3.times { assert_nil Terrain.water_on_map?(PokeAccess.clock - 1) }
      assert_equal false, Terrain.water_on_map?(PokeAccess.clock - 1)
    end
  end

  test "keeps the answer until the tiles change" do
    with_tile_world(DRY) do
      assert_equal false, Terrain.water_on_map?
      replacing(Terrain, :wet_kind?, lambda { |*_a| raise "read again" }) { assert_equal false, Terrain.water_on_map? }
      Terrain.forget
      assert_nil Terrain.instance_variable_get(:@wet)
      assert_nil Terrain.instance_variable_get(:@wet_row)
      assert_equal false, Terrain.water_on_map?
    end
  end

  test "keeps the answer with what Visits keeps of a map, and not the row a read had got to" do
    with_tile_world(DRY) do
      assert_equal false, Terrain.water_on_map?
      kept = Terrain.saved
      Terrain.forget
      assert_nil Terrain.water_on_map?(PokeAccess.clock - 1)
      assert_equal 1, Terrain.instance_variable_get(:@wet_row)
      Terrain.restore(kept)
      assert_equal false, Terrain.instance_variable_get(:@wet)
      assert_nil Terrain.instance_variable_get(:@wet_row)
    end
  end

  test "asks about each kind of tile once" do
    with_tile_world(DRY) do
      read_afresh
      asked = 0
      was = Terrain.method(:index)
      replacing(Terrain, :index, lambda { |*a| asked += 1; was.call(*a) }) { assert_equal false, Terrain.water_on_map? }
      assert_equal 1, asked, "walls and floor are one kind of tile to this map"
    end
  end

  test "tells kinds of tile apart by all three layers, and shares those alike in all three" do
    [[1, 9, 2], [1, 3, 9], [9, 3, 2]].each do |water|
      with_tile_world(WET) do |world|
        read_afresh
        world.instance_variable_set(:@data, LayeredData.new([1, 3, 2], [5, 2], water))
        assert_equal true, Terrain.water_on_map?, water.inspect
      end
    end
    with_tile_world(DRY) do |world|
      read_afresh
      world.instance_variable_set(:@data, LayeredData.new([1, 3, 2]))
      asked = 0
      was = Terrain.method(:index)
      replacing(Terrain, :index, lambda { |*a| asked += 1; was.call(*a) }) { assert_equal false, Terrain.water_on_map? }
      assert_equal 1, asked
    end
  end

  test "asks about every tile where kinds of tile are not shared" do
    with_tile_world(DRY) do
      read_afresh
      Terrain.instance_variable_set(:@layers, 4)
      begin
        asked = 0
        was = Terrain.method(:index)
        replacing(Terrain, :index, lambda { |*a| asked += 1; was.call(*a) }) { assert_equal false, Terrain.water_on_map? }
        assert_equal 7 * 4, asked
      ensure
        Terrain.instance_variable_set(:@layers, nil)
      end
    end
  end

  test "counts any bridge from up on one, where the engine tells only the bridge" do
    on_bridged_ground do
      $PokemonGlobal.bridge = 1
      Terrain.forget
      assert_equal true, Terrain.water_on_map?
      Terrain.forget
      replacing(Terrain, :bridge_at?, lambda { |*_a| false }) do
        assert_equal false, Terrain.water_on_map?, "the engine alone tells no water from up there"
      end
    end
  end

  test "reads the water under a bridge from below as the engine gives it" do
    on_bridged_ground { assert_equal true, Terrain.water_on_map? }
  end

  test "takes no map for wet up on a bridge that has no bridge tile" do
    with_tile_world(DRY) do
      $PokemonGlobal.bridge = 1
      begin
        assert_equal false, Terrain.water_on_map?
      ensure
        $PokemonGlobal.bridge = 0
      end
    end
  end

  test "takes a map it cannot read for one with water" do
    with_tile_world(DRY) do
      replacing(Terrain, :index, lambda { |*_a| raise "no map" }) { assert_equal true, Terrain.water_on_map? }
    end
  end

  test "gives a plan only so long to tell a map's water, and looks by water while it cannot tell" do
    with_tile_world(DRY) do
      given = nil
      before = PokeAccess.clock
      replacing(Terrain, :water_on_map?, lambda { |d| given = d; nil }) { PokeAccess::Pathfinder.surf_plan(4, 2) }
      after = PokeAccess.clock
      assert_operator given, :>=, before + PokeAccess::Pathfinder::WATER_READ
      assert_operator given, :<=, after + PokeAccess::Pathfinder::WATER_READ
      assert Regions.instance_variable_get(:@sets).keys.any? { |k| k[0] == :water }, "the regions by water were asked"
    end
  end

  test "looks for no way by water on a map with none" do
    with_tile_world(DRY) do
      assert_nil PokeAccess::Pathfinder.surf_plan(4, 2)
      refute Regions.instance_variable_get(:@sets).keys.any? { |k| k[0] == :water }, "the regions by water were left alone"
    end
  end

  test "walks on foot but not by water in the map frames on a map with no water" do
    PokeAccess::Config.regions_background = true
    with_tile_world(DRY) do
      Regions.foot
      Regions.instance_variable_set(:@calm, 0)
      60.times { Regions.tick }
      sets = Regions.instance_variable_get(:@sets).keys.map { |k| k[0] }
      assert_equal [true, false], [sets.include?(:foot), sets.include?(:water)]
      assert Regions.foot.done?
    end
  end

  test "walks by water in the map frames on a map with water" do
    PokeAccess::Config.regions_background = true
    with_tile_world(WET) do
      Regions.foot
      Regions.instance_variable_set(:@calm, 0)
      60.times { Regions.tick }
      assert Regions.instance_variable_get(:@sets).keys.any? { |k| k[0] == :water }
    end
  end

  test "gives the map's water the frame's time to be read in" do
    PokeAccess::Config.regions_background = true
    PokeAccess::Config.regions_slice_ms = 13
    with_tile_world(WET) do
      foot = Regions.foot
      foot.status([[1, 1]])
      Regions.instance_variable_set(:@calm, 0)
      60.times { break if foot.done?; Regions.tick }
      Regions::STILL_FRAMES.times { Regions.slice_ms }
      given = nil
      before = PokeAccess.clock
      replacing(Terrain, :water_on_map?, lambda { |d| given = d; nil }) { Regions.tick }
      after = PokeAccess.clock
      assert_operator given, :>=, before + 0.013
      assert_operator given, :<=, after + 0.013
    end
  ensure
    PokeAccess::Config.regions_slice_ms = PokeAccess::Config.setting(:regions_slice_ms).default
  end

  test "walks nothing in a frame the map's water runs out of time" do
    PokeAccess::Config.regions_background = true
    with_tile_world(WET) do
      foot = Regions.foot
      Regions.instance_variable_set(:@calm, 0)
      replacing(Terrain, :water_on_map?, lambda { |*_a| nil }) { 5.times { Regions.tick } }
      assert_equal 0, foot.instance_variable_get(:@head)
    end
  end

  private

  # With the world settled, what a kept visit may have put back, and all that was read of the tiles, forgotten.
  def read_afresh
    PokeAccess::World::Epoch.settle
    Terrain.reset!
  end

  # A dry room with a bridge over water, the player down.
  def on_bridged_ground
    $game_map.load_grid(["#####", "#@..#", "#...#", "#####"])
    $game_map.place_bridge(2, 1)
    PokeAccess::Pathfinder.invalidate_cache(true)
    yield
  ensure
    $PokemonGlobal.bridge = 0
    $game_map.clear_grid
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
