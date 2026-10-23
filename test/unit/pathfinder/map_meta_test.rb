# A map's gen-6 metadata (MapMeta): outdoors, Cycling Road, the healing spot and the map under the sea by field index,
# the map above a sea from every map's rows, and another map's terrain through the engine's map factory.
class MapMetaTest < PokeAccessTest
  MM = PokeAccess::MapMeta

  # A map the factory builds, whose terrain tag tells the map and the tile it was asked for.
  class TerrainOnly
    def initialize(mid); @mid = mid; end
    def terrain_tag(x, y); @mid * 100 + x * 10 + y; end
  end

  # A data provider keeping an engine's own map data: { map id => { GameData accessor => value } }.
  class OwnMapData
    def initialize(rows); @rows = rows; end
    def map_metadata(mid); @rows[mid] || {}; end
    def dive_maps
      out = {}
      @rows.each { |mid, row| out[mid] = row[:dive_map_id] if row[:dive_map_id] }
      out
    end
  end

  test "a map's row tells whether it is outdoors, and a map with none is indoors" do
    with_metadata(20 => { 1 => true }, 21 => { 1 => false }) do
      { 20 => true, 21 => false, 22 => false }.each { |mid, want| assert_equal want, MM.outdoor?(mid), "map #{mid}" }
    end
  end

  test "a cycling road keeps the player on the bike, and no other map does" do
    with_metadata(20 => { 4 => false }, 21 => { 4 => true }) do
      { 20 => false, 21 => true, 22 => false }.each { |mid, want| assert_equal want, MM.always_bicycle?(mid), "map #{mid}" }
    end
  end

  test "the map under the sea is the one the dive field names" do
    with_metadata(20 => { 8 => 51 }, 21 => { 8 => 0 }, 23 => { 8 => "51" }, 24 => { 8 => 1 }) do
      assert_equal [51, 1], [MM.dive_map(20), MM.dive_map(24)]
      [21, 22, 23].each { |mid| assert_nil MM.dive_map(mid), "map #{mid}" }
    end
  end

  test "a Pokemon Centre is a map that declares a healing spot" do
    with_metadata(30 => { 5 => [30, 4, 7] }, 31 => { 5 => [] }) do
      { 30 => true, 31 => false, 32 => false }.each { |mid, want| assert_equal want, MM.pokecenter?(mid), "map #{mid}" }
    end
  end

  test "the field's index is the game's own Metadata constant where it defines one" do
    rows = { 20 => { 1 => false, 4 => false, 5 => nil, 8 => 51, 11 => true, 12 => true, 13 => [20, 1, 1], 14 => 52 } }
    with_metadata(rows) do
      with_constants(:MetadataOutdoor => 11, :MetadataBicycleAlways => 12, :MetadataHealingSpot => 13,
                     :MetadataDiveMap => 14) do
        assert_equal [true, true, true, 52], [MM.outdoor?(20), MM.always_bicycle?(20), MM.pokecenter?(20), MM.dive_map(20)]
      end
    end
  end

  test "with no metadata at all, outdoors cannot be told and nothing else holds" do
    assert_equal [nil, false, false, nil], [MM.outdoor?(20), MM.always_bicycle?(20), MM.pokecenter?(20), MM.dive_map(20)]
  end

  test "metadata the engine fails to read is no answer" do
    with_global(:pbGetMetadata, lambda { |_mid, _field| raise "no metadata" }) do
      assert_equal [nil, false, nil], [MM.outdoor?(20), MM.always_bicycle?(20), MM.dive_map(20)]
    end
  end

  test "the map whose sea a map lies under is found from every map's rows, the first that names it" do
    rows = [[nil] * 8 + [53], [nil] * 8 + [55], [nil] * 8 + [51], [nil] * 8 + [51], [nil] * 8 + [0], "not a row",
            [nil] * 8 + [52], [nil] * 8 + [1], nil]
    with_surface_index_unbuilt do
      with_global(:pbLoadMetadata, lambda { rows }) do
        assert_equal [1, 2, 6, 7], [MM.surface_map(55), MM.surface_map(51), MM.surface_map(52), MM.surface_map(1)]
        [53, 0, 54].each { |mid| assert_nil MM.surface_map(mid), "map #{mid}: the global row and no row are none" }
      end
    end
  end

  test "the dive field of every map's rows is the game's own constant where it defines one" do
    rows = [nil, [nil, 60] + [nil] * 7]
    with_surface_index_unbuilt do
      with_constants(:MetadataDiveMap => 1) do
        with_global(:pbLoadMetadata, lambda { rows }) { assert_equal 1, MM.surface_map(60) }
      end
    end
  end

  test "the index of the maps above a sea is built once" do
    loads = 0
    with_surface_index_unbuilt do
      with_global(:pbLoadMetadata, lambda { loads += 1; [nil, [nil] * 8 + [51]] }) do
        assert_equal [1, 1, 1], [MM.surface_map(51), MM.surface_map(51), loads]
      end
    end
  end

  test "with no metadata rows there is no map above any sea" do
    with_surface_index_unbuilt do
      assert_nil MM.surface_map(51)
      with_surface_index_unbuilt do
        with_global(:pbLoadMetadata, lambda { raise "unreadable" }) { assert_nil MM.surface_map(51), "unreadable rows" }
      end
    end
  end

  test "a data provider keeping the engine's map data answers for it over the gen-6 rows, a map it keeps none for indoors" do
    rows = { 20 => { :outdoor_map => true, :teleport_destination => [20, 4, 7], :dive_map_id => 51 }, 21 => {} }
    with_metadata(20 => { 1 => false, 8 => 99 }, 21 => { 1 => true, 5 => [21, 1, 1] }) do
      Harness.with_provider(OwnMapData.new(rows)) do
        assert_equal [true, false, true, 51], [MM.outdoor?(20), MM.always_bicycle?(20), MM.pokecenter?(20), MM.dive_map(20)]
        assert_equal [false, false, false, nil], [MM.outdoor?(21), MM.always_bicycle?(21), MM.pokecenter?(21), MM.dive_map(21)]
      end
    end
  end

  test "the map above a sea is found from the data provider's map data where it keeps it, the first by map id" do
    with_surface_index_unbuilt do
      with_global(:pbLoadMetadata, lambda { [nil, [nil] * 8 + [77]] }) do
        Harness.with_provider(OwnMapData.new(32 => { :dive_map_id => 51 }, 30 => { :dive_map_id => 51 }, 31 => {})) do
          assert_equal [30, nil], [MM.surface_map(51), MM.surface_map(77)]
        end
      end
    end
  end

  test "another map's terrain is read through the map factory, its map kept while asked about" do
    built = []
    factory = Object.new
    factory.define_singleton_method(:getMapNoAdd) { |mid| built.push(mid); TerrainOnly.new(mid) }
    with_factory(:$map_factory, factory) do
      assert_equal [51 * 100 + 23, 51 * 100 + 45], [MM.terrain_on(51, 2, 3), MM.terrain_on(51, 4, 5)]
      assert_equal [51], built, "one map built for both"
      assert_equal 52 * 100 + 23, MM.terrain_on(52, 2, 3)
      MM.forget_foreign
      MM.terrain_on(52, 2, 3)
      assert_equal [51, 52, 52], built, "another map, or the map forgotten, is built anew"
    end
  end

  test "an older map factory builds the other map without adding it" do
    asked = []
    factory = Object.new
    factory.define_singleton_method(:getMap) { |mid, add| asked.push([mid, add]); TerrainOnly.new(mid) }
    with_factory(:$MapFactory, factory) do
      assert_equal 51 * 100 + 23, MM.terrain_on(51, 2, 3)
      assert_equal [[51, false]], asked
    end
  end

  test "with no map factory another map has no terrain" do
    with_factory(:$map_factory, nil) { assert_nil MM.terrain_on(51, 2, 3) }
  end

  private

  # Runs the block with gen-6 metadata rows: { map id => { field index => value } }.
  def with_metadata(rows, &blk)
    with_global(:pbGetMetadata, lambda { |mid, field| (rows[mid] || {})[field] }, &blk)
  end

  # Runs the block with a private method of every object (a gen-6 global function) answered by body, putting back
  # whatever was defined before.
  def with_global(name, body)
    had = Object.private_method_defined?(name) ? Object.instance_method(name) : nil
    Object.send(:define_method, name, &body)
    Object.send(:private, name)
    yield
  ensure
    Object.send(:remove_method, name)
    if had
      Object.send(:define_method, name, had)
      Object.send(:private, name)
    end
  end

  # Runs the block with top-level constants set (a game's), each removed or put back after.
  def with_constants(values)
    had = {}
    values.each do |name, v|
      had[name] = Object.const_get(name) if Object.const_defined?(name, false)
      Object.send(:remove_const, name) if Object.const_defined?(name, false)
      Object.const_set(name, v)
    end
    yield
  ensure
    values.each_key do |name|
      Object.send(:remove_const, name) if Object.const_defined?(name, false)
      Object.const_set(name, had[name]) if had.key?(name)
    end
  end

  # Runs the block with the index of the maps above a sea not built yet, dropping the one it builds.
  def with_surface_index_unbuilt
    was = MM.instance_variable_get(:@surface_of)
    MM.instance_variable_set(:@surface_of, nil)
    yield
  ensure
    MM.instance_variable_set(:@surface_of, was)
  end

  # Runs the block with the global map factory (name: :$map_factory or the older :$MapFactory) set to factory and
  # the other one unset, the map built for terrain_on forgotten before and after.
  def with_factory(name, factory)
    had = [$map_factory, $MapFactory]
    $map_factory = nil
    $MapFactory = nil
    name == :$map_factory ? ($map_factory = factory) : ($MapFactory = factory)
    MM.forget_foreign
    yield
  ensure
    $map_factory, $MapFactory = had
    MM.forget_foreign
  end
end
