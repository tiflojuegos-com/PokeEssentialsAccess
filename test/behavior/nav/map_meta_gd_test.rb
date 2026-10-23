# MapMeta over GameData::MapMetadata: outdoors, the maps under and above the sea, the bike kept on, a Pokémon Centre
# (none from metadata that cannot be read), and another map's terrain through the map factory, kept while one stays.
class MapMetaGdTest < PokeAccessTest
  MapMeta = PokeAccess::MapMeta
  # A map's metadata as GameData gives it.
  Row = Struct.new(:id, :outdoor_map, :dive_map_id, :always_bicycle, :teleport_destination)
  # Another map as the map factory builds it: its terrain tag is x * 10 + y.
  OtherMap = Struct.new(:id) do
    def terrain_tag(x, y); x * 10 + y; end
  end

  test "a map is outdoors as its metadata says, and one with none is indoors" do
    with_rows(10 => Row.new(10, true), 11 => Row.new(11, false)) do
      { 10 => true, 11 => false, 12 => false }.each { |mid, want| assert_equal want, MapMeta.outdoor?(mid), "map #{mid}" }
    end
  end

  test "the map under a map's sea is its positive dive map id, else none" do
    rows = { 10 => Row.new(10, true, 44), 11 => Row.new(11, true, 1), 12 => Row.new(12, true, 0),
             13 => Row.new(13, true, "44") }
    with_rows(rows) do
      { 10 => 44, 11 => 1, 12 => nil, 13 => nil, 14 => nil }.each do |mid, want|
        want.nil? ? assert_nil(MapMeta.dive_map(mid), "map #{mid}") : assert_equal(want, MapMeta.dive_map(mid), "map #{mid}")
      end
    end
  end

  test "the bike is kept on only where the metadata says so" do
    with_rows(10 => Row.new(10, true, nil, false), 11 => Row.new(11, false, nil, true)) do
      { 10 => false, 11 => true, 12 => false }.each do |mid, want|
        assert_equal want, MapMeta.always_bicycle?(mid), "map #{mid}"
      end
    end
  end

  test "a Pokémon Centre is a map that declares where Teleport sets the player down" do
    rows = { 10 => Row.new(10, false, nil, false, [10, 5, 7, 2]), 11 => Row.new(11, false, nil, false, []),
             12 => Row.new(12, false) }
    with_rows(rows) do
      { 10 => true, 11 => false, 12 => false, 13 => false }.each do |mid, want|
        assert_equal want, MapMeta.pokecenter?(mid), "map #{mid}"
      end
    end
  end

  test "a field the metadata does not have reads as none" do
    bare = Struct.new(:outdoor_map)
    with_rows(10 => bare.new(true)) do
      assert_equal [true, false, nil, false],
                   [MapMeta.outdoor?(10), MapMeta.always_bicycle?(10), MapMeta.dive_map(10), MapMeta.pokecenter?(10)]
    end
  end

  test "a map whose metadata cannot be read is told neither outdoors nor indoors, and keeps nobody on the bike" do
    with_try_get(lambda { |_mid| raise IOError, "the metadata cannot be read" }) do
      assert_equal [nil, false, false, nil],
                   [MapMeta.outdoor?(10), MapMeta.always_bicycle?(10), MapMeta.pokecenter?(10), MapMeta.dive_map(10)]
    end
  end

  test "an engine without try_get is read through get, a map it has no row for as none" do
    with_get_only(10 => Row.new(10, true, 44)) do
      assert_equal [true, 44], [MapMeta.outdoor?(10), MapMeta.dive_map(10)], "a map it has"
      assert_equal [false, nil], [MapMeta.outdoor?(11), MapMeta.dive_map(11)], "a map its get refuses"
    end
  end

  test "the map above a map's sea is the first that declares it as its dive map" do
    rows = [Row.new(10, true, 44), Row.new(20, true, 44), Row.new(30, true, 45), Row.new(40, true, 0),
            Row.new(50, true, "46"), Row.new(60, true, 1)]
    with_listed_rows(rows) do
      { 44 => 10, 45 => 30, 1 => 60, 46 => nil, 0 => nil, 10 => nil }.each do |mid, want|
        want.nil? ? assert_nil(MapMeta.surface_map(mid), "map #{mid}") : assert_equal(want, MapMeta.surface_map(mid), "map #{mid}")
      end
    end
  end

  test "the maps above the sea are listed once, not at each question" do
    with_listed_rows([Row.new(10, true, 44)]) do |listings|
      MapMeta.surface_map(44)
      MapMeta.surface_map(45)
      assert_equal 1, listings[0]
    end
  end

  test "another map's terrain comes through the map factory, that map built once while the player stays" do
    with_factory(:getMapNoAdd) do |built|
      assert_equal [12, 34], [MapMeta.terrain_on(5, 1, 2), MapMeta.terrain_on(5, 3, 4)], "map 5's tags"
      assert_equal [[5, nil]], built, "built once, adding nothing to the factory"
    end
  end

  test "asking about a third map builds it in place of the one kept" do
    with_factory(:getMapNoAdd) do |built|
      MapMeta.terrain_on(5, 1, 2)
      MapMeta.terrain_on(6, 1, 2)
      MapMeta.terrain_on(5, 1, 2)
      assert_equal [5, 6, 5], built.map { |mid, _add| mid }
    end
  end

  test "a map change forgets the other map built" do
    with_factory(:getMapNoAdd) do |built|
      MapMeta.terrain_on(5, 1, 2)
      PokeAccess::Caches.reset_all
      MapMeta.terrain_on(5, 1, 2)
      assert_equal [5, 5], built.map { |mid, _add| mid }
    end
  end

  test "a factory without getMapNoAdd is asked with getMap, not to add the map" do
    with_factory(:getMap) do |built|
      assert_equal 12, MapMeta.terrain_on(5, 1, 2)
      assert_equal [[5, false]], built
    end
  end

  test "an engine that keeps its map factory in $MapFactory has the other map built through it" do
    with_factory(:getMapNoAdd, :MapFactory) do |built|
      assert_equal 12, MapMeta.terrain_on(5, 1, 2)
      assert_equal [[5, nil]], built
    end
  end

  test "with no map factory another map's terrain is unknown" do
    with_factory(nil) { assert_nil MapMeta.terrain_on(5, 1, 2) }
  end

  private

  # Runs the block with GameData::MapMetadata.try_get answering rows (map id => row, nil for any other), put back after.
  def with_rows(rows, &blk)
    with_try_get(lambda { |mid| rows[mid] }, &blk)
  end

  # Runs the block with GameData::MapMetadata.try_get answering as answer does for a map id, put back after.
  def with_try_get(answer)
    md = GameData::MapMetadata
    real = md.singleton_class.instance_method(:try_get)
    md.define_singleton_method(:try_get) { |mid| answer.call(mid) }
    yield
  ensure
    md.singleton_class.send(:define_method, :try_get, real)
  end

  # Runs the block with GameData::MapMetadata answering only get, which raises for a map it has no row for (rows: map
  # id => row), as an engine without try_get; try_get put back after.
  def with_get_only(rows)
    md = GameData::MapMetadata
    real = md.singleton_class.instance_method(:try_get)
    md.singleton_class.send(:remove_method, :try_get)
    md.define_singleton_method(:get) { |mid| rows.fetch(mid) }
    yield
  ensure
    md.singleton_class.send(:remove_method, :get) if md.singleton_class.method_defined?(:get, false)
    md.singleton_class.send(:define_method, :try_get, real)
  end

  # Runs the block with GameData::MapMetadata.each yielding rows in order, counting its listings in the array yielded,
  # and the reverse index of the maps above the sea built afresh; both put back after.
  def with_listed_rows(rows)
    md = GameData::MapMetadata
    was = MapMeta.instance_variable_get(:@surface_of)
    listings = [0]
    md.define_singleton_method(:each) { |&blk| listings[0] += 1; rows.each(&blk) }
    MapMeta.instance_variable_set(:@surface_of, nil)
    yield listings
  ensure
    md.singleton_class.send(:remove_method, :each)
    MapMeta.instance_variable_set(:@surface_of, was)
  end

  # Runs the block with a factory building OtherMaps through meth (:getMapNoAdd, :getMap, or nil for no factory) in the
  # global holder names ($map_factory, or $MapFactory as older engines keep it), the other one empty; each build logged
  # as [map id, the add flag given or nil] in the array yielded; the factories and the map kept put back after.
  def with_factory(meth, holder = :map_factory)
    was = [$map_factory, $MapFactory]
    built = []
    factory = nil
    if meth == :getMapNoAdd
      factory = Object.new
      factory.define_singleton_method(:getMapNoAdd) { |mid| built.push([mid, nil]); OtherMap.new(mid) }
    elsif meth == :getMap
      factory = Object.new
      factory.define_singleton_method(:getMap) { |mid, add| built.push([mid, add]); OtherMap.new(mid) }
    end
    $map_factory = holder == :map_factory ? factory : nil
    $MapFactory = holder == :map_factory ? nil : factory
    MapMeta.forget_foreign
    yield built
  ensure
    $map_factory, $MapFactory = was
    MapMeta.forget_foreign
  end
end
