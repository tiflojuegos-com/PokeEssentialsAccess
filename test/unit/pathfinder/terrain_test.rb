# The map's terrain (World::Terrain) and the engine behind it (World::Engine): each tag's kind, number and tag tests,
# read once per kind of tile, none off the map, and the bridge height wherever the engine keeps it.
class TerrainTest < PokeAccessTest
  Terrain = PokeAccess::World::Terrain
  Engine = PokeAccess::World::Engine
  SURF = Terrain::SURF
  LEDGE = Terrain::LEDGE
  ICE = Terrain::ICE
  DEEP = Terrain::DEEP
  GRASS = Terrain::GRASS
  FALLING = Terrain::FALLING
  # A modern tag object (GameData::TerrainTag) with the flags the tag tests read and one a plugin adds (rail).
  ModernTag = Struct.new(:id, :id_number, :can_surf, :ledge, :ice, :can_dive, :rail)
  # The standard kind of each number, as every era numbers the standard tags.
  STANDARD_KINDS = { 0 => nil, 1 => :ledge, 2 => :grass, 3 => :sand, 4 => :rock, 5 => :deep_water,
                     6 => :still_water, 7 => :water, 8 => :waterfall, 9 => :waterfall_crest, 10 => :tall_grass,
                     11 => :underwater_grass, 12 => :ice, 13 => :neutral, 14 => :soot_grass, 15 => :bridge,
                     16 => :puddle, 17 => nil }

  # A map that answers a terrain tag per tile (an Integer or a tag object) and logs every tile it is asked about. Each
  # distinct tag has tile ids of its own unless ids gives a tile's three layers.
  class TagMap
    attr_reader :asked, :width, :height
    attr_accessor :map_id

    def initialize(tags, ids = {}, width = 8, height = 4)
      @tags = tags
      @ids = ids
      @width = width
      @height = height
      @map_id = 950
      @asked = []
    end

    def terrain_tag(x, y, *_count_bridge)
      @asked.push([x, y])
      @tags.fetch([x, y], 0)
    end

    def data; self; end
    def [](x, y, layer); (@ids[[x, y]] || own_ids(x, y))[layer]; end
    def valid?(x, y); x >= 0 && y >= 0 && x < @width && y < @height; end

    private

    def own_ids(x, y)
      [@tags.key?([x, y]) ? 2 + @tags.values.uniq.index(@tags[[x, y]]) : 1, 0, 0]
    end
  end

  test "a modern tag object answers each tag test by its own flag, whatever its number says" do
    {
      ModernTag.new(:Water, 7, true, false, false, false) => SURF,
      ModernTag.new(:Ledge, 1, false, true, false, false) => LEDGE,
      ModernTag.new(:DeepWater, 5, true, false, false, true) => SURF | DEEP,
      ModernTag.new(:Ice, 12, false, false, true, false) => ICE,
      ModernTag.new(:Ice, 12, false, false, false, false) => 0,
      ModernTag.new(:TallGrass, 10, false, false, false, false) => GRASS,
      ModernTag.new(:Waterfall, 8, true, false, false, false) => SURF | FALLING
    }.each { |tag, bits| assert_equal bits, Terrain.bits_of(tag), "for #{tag.id} #{tag.to_a.inspect}" }
  end

  test "a modern tag object's kind is its id, else its number, and its number is its id_number" do
    assert_equal :ice, Terrain.kind_of(ModernTag.new(:Ice, 99)), "an id the standard tags know"
    assert_equal :sand, Terrain.kind_of(ModernTag.new(:Rail, 3)), "a game's own id falls back to its number"
    assert_nil Terrain.kind_of(ModernTag.new(:Rail, 99)), "and a number no standard tag has is no kind"
    assert_equal 99, Terrain.number_of(ModernTag.new(:Ice, 99))
  end

  test "a raw tag's number is the gen-6 Integer itself, and nothing else has one" do
    { 7 => 7, 0 => 0, nil => nil, "7" => nil, :water => nil }.each do |tag, n|
      assert_equal_or_nil n, Terrain.number_of(tag), "for #{tag.inspect}"
    end
  end

  test "with no PBTerrain names, each standard number is its standard kind" do
    without_pbterrain_names do
      STANDARD_KINDS.each { |n, kind| assert_equal_or_nil kind, Terrain.kind_of(n), "for #{n}" }
    end
  end

  test "a number the game names otherwise is no standard kind, and one it leaves unnamed keeps its own" do
    assert_equal :rock, Terrain.kind_of(4), "unnamed, 4 is rock"
    with_pbterrain(:RockClimb => 4, :Charco => 16) do
      assert_nil Terrain.kind_of(4), "named RockClimb (Insurgence), it is no standard kind"
      assert_nil Terrain.kind_of(16), "nor is a puddle the game calls Charco"
      assert_equal :tall_grass, Terrain.kind_of(10), "while a standard name reads as ever"
    end
  end

  test "where two names share a number the standard one wins, whichever the engine lists first" do
    assert_equal({ 16 => :puddle }, Terrain.kinds_of_names([[:Puddle, 16], [:Charco, 16]]))
    assert_equal({ 16 => :puddle }, Terrain.kinds_of_names([[:Charco, 16], [:Puddle, 16]]))
    assert_equal({ 16 => nil, 4 => :rock }, Terrain.kinds_of_names([[:Charco, 16], [:Rock, 4], [:Odd, "x"]]),
                 "a name of its own maps to no kind, and a value that is no number is left out")
    with_pbterrain(:Charco => 16, :Puddle => 16) do
      assert_equal :puddle, Terrain.kind_of(16), "and the engine's own names are read so"
    end
  end

  test "gen-6 numbers take PBTerrain's own tag test where it has one, and the standard numbers where not" do
    {
      0 => 0, 1 => LEDGE, 2 => GRASS, 3 => 0, 4 => 0, 5 => SURF | DEEP, 6 => 0, 7 => SURF, 8 => SURF | FALLING,
      9 => SURF | FALLING, 10 => GRASS, 11 => 0, 12 => ICE, 13 => 0, 14 => GRASS, 15 => 0, 16 => 0
    }.each { |n, bits| assert_equal bits, Terrain.bits_of(n), "for #{n}" }
  end

  test "with no surf test of the engine's own, the standard numbers count still water as surfable" do
    without_pbterrain_surf_test do
      { 4 => 0, 5 => SURF | DEEP, 6 => SURF, 7 => SURF, 8 => SURF | FALLING, 9 => SURF | FALLING, 10 => GRASS }
        .each { |n, bits| assert_equal bits, Terrain.bits_of(n), "for #{n}" }
    end
  end

  test "the global surf test of the copies older than v15 is asked before the standard numbers" do
    without_pbterrain_surf_test do
      with_global_surf_test([5, 7, 8, 9]) do
        assert_equal 0, Terrain.bits_of(6) & SURF, "still water the game does not surf on"
        assert_equal SURF, Terrain.bits_of(7) & SURF, "water it does"
      end
    end
  end

  test "each tile of a row is classed by its own tag" do
    $game_map.load_grid(["##########", "#@.......#", "##########"])
    tags = [2, 3, 5, 6, 7, 10, 12, 14]
    tags.each_with_index { |tag, i| $game_map.set_terrain(1 + i, 1, tag) }
    want = [:grass, :sand, :deep_water, :still_water, :water, :tall_grass, :ice, :soot_grass]
    assert_equal want, (1..8).map { |x| Terrain.kind(x, 1) }, "read left to right"
    assert_equal want.reverse, 8.downto(1).map { |x| Terrain.kind(x, 1) }, "and again right to left"
    assert_equal tags, (1..8).map { |x| Terrain.number(x, 1) }, "with their numbers"
  end

  test "the tag tests of a tile are its tag's" do
    $game_map.load_grid(["########", "#@.....#", "########"])
    { 1 => 1, 2 => 12, 3 => 5, 4 => 9, 5 => 10 }.each { |x, tag| $game_map.set_terrain(x, 1, tag) }
    {
      :ledge? => [true, false, false, false, false],
      :ice? => [false, true, false, false, false],
      :surfable? => [false, false, true, true, false],
      :deep? => [false, false, true, false, false],
      :falling? => [false, false, false, true, false],
      :grass? => [false, false, false, false, true]
    }.each { |test, want| assert_equal want, (1..5).map { |x| Terrain.send(test, x, 1) }, "#{test} along the row" }
  end

  test "a bridge tile is the water below while the player is off it, unless bridges are counted" do
    $game_map.load_grid(["#####", "#@..#", "#####"])
    $game_map.place_bridge(2, 1)
    assert_equal [SURF, 7, :water, true],
                 [Terrain.cell(2, 1) & SURF, Terrain.number(2, 1), Terrain.kind(2, 1), Terrain.surfable?(2, 1)]
    assert_equal [0, 15, :bridge, false],
                 [Terrain.cell(2, 1, true) & SURF, Terrain.number(2, 1, true), Terrain.kind(2, 1, true),
                  Terrain.surfable?(2, 1, true)], "bridges counted"
  end

  test "a bridge tile is read again on a bridge of any height, and the tile beside it stays its own" do
    $game_map.load_grid(["#####", "#@..#", "#####"])
    $game_map.place_bridge(2, 1)
    assert_equal :water, Terrain.kind(2, 1), "off the bridge"
    $PokemonGlobal.bridge = 1
    assert_equal [0, 15, :bridge, :surf_bridge],
                 [Terrain.cell(2, 1) & SURF, Terrain.number(2, 1), Terrain.kind(2, 1), Terrain.label(2, 1)], "at height 1"
    assert_nil Terrain.kind(3, 1)
  end

  test "a bridge tile is found on any of its three layers" do
    [0, 1, 2].each do |layer|
      ids = [0, 0, 0]
      ids[layer] = 2015
      map = TagMap.new({}, { [1, 1] => ids })
      map.instance_variable_set(:@terrain_tags, { 2015 => 15 })
      def map.terrain_tag(*_a); $PokemonGlobal.bridge > 0 ? 15 : 7; end
      on_map(map) do
        $PokemonGlobal.bridge = 0
        assert_equal :water, Terrain.kind(1, 1), "off the bridge, layer #{layer}"
        $PokemonGlobal.bridge = 2
        assert_equal :bridge, Terrain.kind(1, 1), "on it, layer #{layer}"
      end
    end
  end

  test "a map whose tiles cannot be read counts every tile as a bridge's, kept per bridge height" do
    no_tables = TagMap.new({})
    unreadable = TagMap.new({})
    unreadable.instance_variable_set(:@terrain_tags, {})
    def unreadable.[](_x, _y, _layer); raise "no tile ids"; end
    [no_tables, unreadable].each do |map|
      def map.terrain_tag(*_a); $PokemonGlobal.bridge > 0 ? 15 : 7; end
      on_map(map) do
        $PokemonGlobal.bridge = 0
        assert_equal :water, Terrain.kind(1, 1), "off the bridge"
        $PokemonGlobal.bridge = 2
        assert_equal :bridge, Terrain.kind(1, 1), "on it, read again"
      end
    end
  end

  test "a tile id past every tileset's is asked on its own, tiles below it share their kind of tile's tag" do
    tags = { [1, 1] => 7, [2, 1] => 12, [3, 1] => 7, [4, 1] => 12, [5, 1] => 7, [6, 1] => 12, [7, 1] => 7,
             [8, 1] => 12 }
    ids = { [1, 1] => [5, 0, 8192], [2, 1] => [5, 0, 8192], [3, 1] => [5, 8192, 0], [4, 1] => [5, 8192, 0],
            [5, 1] => [5, 8191, 8191], [6, 1] => [5, 8191, 8191], [7, 1] => [5, 1, 3], [8, 1] => [5, 2, 3] }
    map = TagMap.new(tags, ids, 10)
    on_map(map) do
      assert_equal [:water, :ice, :water, :ice], (1..4).map { |x| Terrain.kind(x, 1) }, "ids from 8192 up"
      assert_equal [:water, :water], [Terrain.kind(5, 1), Terrain.kind(6, 1)], "ids below it, alike"
      assert_equal [:water, :ice], [Terrain.kind(7, 1), Terrain.kind(8, 1)], "ids below it, another middle layer"
      assert_equal [[1, 1], [2, 1], [3, 1], [4, 1], [5, 1], [7, 1], [8, 1]], map.asked,
                   "the engine asked once for the two alike"
    end
  end

  test "off the map there is no terrain, and the engine is not asked" do
    map = TagMap.new({ [0, 0] => 5, [7, 3] => 5 })
    on_map(map) do
      assert_equal [nil, nil, 0, false, false, nil, false],
                   [Terrain.kind(-1, 3), Terrain.number(3, -1), Terrain.cell(8, 3), Terrain.ledge?(3, 4),
                    Terrain.flag?(-1, 0, :rail), Terrain.label(8, 0), Terrain.water?(0, 4)],
                   "past each edge"
      assert_equal [], map.asked
      assert_equal [:deep_water, :deep_water], [Terrain.kind(0, 0), Terrain.kind(7, 3)], "while the corners have one"
    end
  end

  test "a map that cannot tell its size has no terrain on it" do
    [:width, :height].each do |side|
      map = TagMap.new({ [0, 0] => 5 })
      map.define_singleton_method(side) { raise "no size" }
      on_map(map) do
        assert_nil Terrain.kind(0, 0), "no #{side}"
        assert_equal [], map.asked
      end
    end
  end

  test "on a new map the first question about its terrain reads it afresh" do
    rail = ModernTag.new(:Rail, 20, false, false, false, false, true)
    [
      ["flag?", lambda { Terrain.flag?(1, 1, :rail) }, rail, true, false],
      ["label", lambda { Terrain.label(1, 1) }, 10, :surf_tallgrass, :surf_water],
      ["kind", lambda { Terrain.kind(1, 1) }, 10, :tall_grass, :water],
      ["water?", lambda { Terrain.water?(1, 1) }, 10, false, true]
    ].each do |name, ask, tag, was, now|
      on_map(TagMap.new({ [1, 1] => tag })) do
        assert_equal was, ask.call, "#{name} on the first map"
        $game_map = TagMap.new({ [1, 1] => 7 })
        $game_map.map_id = 951
        World.next_frame
        assert_equal now, ask.call, "#{name} on the next"
      end
    end
  end

  test "a reset reads every tile afresh" do
    map = TagMap.new({ [1, 1] => 12 })
    on_map(map) do
      assert_equal :ice, Terrain.kind(1, 1)
      Terrain.reset!
      assert_equal [:ice, [[1, 1], [1, 1]]], [Terrain.kind(1, 1), map.asked]
    end
  end

  test "a flag a plugin adds to the modern tag object is read per tile, and a gen-6 tag carries none" do
    rail = ModernTag.new(:Rail, 20, false, false, false, false, true)
    plain = ModernTag.new(:Rail, 21, false, false, false, false, false)
    on_map(TagMap.new({ [1, 1] => rail, [2, 1] => plain, [3, 1] => 7 })) do
      assert_equal [true, false, false], (1..3).map { |x| Terrain.flag?(x, 1, :rail) }, "the rail flag"
      assert_equal false, Terrain.flag?(1, 1, :current), "a flag the tag does not carry"
      assert_equal true, Terrain.flag?(1, 1, :rail), "asked again, the same"
    end
  end

  test "a surface's label is a game's rule first, else the standard one with bridges counted, else water when surfable" do
    $game_map.load_grid(["#######", "#@....#", "#######"])
    { 1 => 10, 2 => 6, 3 => 5, 4 => 13 }.each { |x, tag| $game_map.set_terrain(x, 1, tag) }
    $game_map.place_bridge(5, 1)
    assert_equal [:surf_tallgrass, :surf_water, :surf_deepwater, nil, :surf_bridge], (1..5).map { |x| Terrain.label(x, 1) }
    with_label_rule(lambda { |x, _y| raise "broken" if x == 1; x == 4 ? :surf_custom : nil }) do
      assert_equal [:surf_tallgrass, :surf_custom, :surf_water], [1, 4, 2].map { |x| Terrain.label(x, 1) },
                   "a rule answers its tiles, one that raises is passed over"
    end
    swamp = ModernTag.new(:Swamp, 99, true, false, false, false)
    on_map(TagMap.new({ [1, 1] => swamp })) do
      assert_equal :surf_water, Terrain.label(1, 1), "a surfable tag no standard name covers"
    end
  end

  test "water for the sonar is any surface whose label names water" do
    swamp = ModernTag.new(:Swamp, 99, true, false, false, false)
    tags = { [0, 0] => 7, [1, 0] => 5, [2, 0] => 8, [3, 0] => 10, [5, 0] => swamp }
    on_map(TagMap.new(tags)) do
      assert_equal [true, true, true, false, false, true], (0..5).map { |x| Terrain.water?(x, 0) }
      assert_equal [true, false], [Terrain.water?(0, 0), Terrain.water?(4, 0)], "asked again, the same"
    end
  end

  test "the tiles read and their classes are put back as they were kept" do
    map = TagMap.new({ [1, 1] => 12 })
    on_map(map) do
      assert_equal :ice, Terrain.kind(1, 1)
      kept = Terrain.saved
      Terrain.reset!
      Terrain.restore(kept)
      assert_equal [:ice, [[1, 1]]], [Terrain.kind(1, 1), map.asked], "the tile is not asked again"
    end
  end

  test "a raw tag read on another map is classed as this map's are" do
    { 5 => SURF | DEEP, 12 => ICE, 0 => 0, nil => 0 }.each do |tag, bits|
      assert_equal bits, Terrain.tag_bits(tag), "for #{tag.inspect}"
    end
  end

  test "an engine whose terrain tag takes no bridge argument is never offered one" do
    with_bridge_arg_unjudged do
      map = TagMap.new({ [1, 1] => 15 })
      def map.terrain_tag(x, y); @asked.push([x, y]); @tags.fetch([x, y], 0); end
      on_map(map) { assert_equal [false, 15], [Engine.bridge_arg?, Engine.terrain_tag(1, 1, true)] }
    end
  end

  test "an engine that refuses the bridge argument is asked without it from then on" do
    with_bridge_arg_unjudged do
      map = TagMap.new({ [1, 1] => 15 })
      def map.terrain_tag(*args)
        raise ArgumentError, "wrong number of arguments" if args.length > 2
        @asked.push(args)
        @tags.fetch(args, 0)
      end
      on_map(map) do
        assert_equal true, Engine.bridge_arg?, "a method taking any arguments is offered it"
        assert_equal [15, 15], [Engine.terrain_tag(1, 1, true), Engine.terrain_tag(1, 1, true)]
        assert_equal [false, [[1, 1], [1, 1]]], [Engine.bridge_arg?, map.asked], "and once refused, never again"
      end
    end
  end

  test "with no map the engine has no terrain tag" do
    on_map(nil) { assert_nil Engine.terrain_tag(1, 1) }
  end

  test "from v16 the bridge height is kept on $PokemonGlobal" do
    assert_same $PokemonGlobal, Engine.bridge_holder
    $PokemonGlobal.bridge = 2
    assert_equal [2, 2], [Engine.bridge_height, PokeAccess::Pathfinder.bridge_level], "read there"
    Engine.set_bridge(0)
    assert_equal 0, $PokemonGlobal.bridge, "and set there"
  end

  test "before v16 the bridge height is kept on $PokemonMap" do
    old_map = Object.new
    class << old_map; attr_accessor :bridge; end
    old_map.bridge = 2
    with_bridge_globals(Object.new, old_map) do
      assert_same old_map, Engine.bridge_holder
      assert_equal [2, 2], [Engine.bridge_height, PokeAccess::Pathfinder.bridge_level], "read there"
      Engine.set_bridge(0)
      assert_equal 0, old_map.bridge, "and set there"
    end
  end

  test "an engine that keeps no bridge height has no bridge" do
    with_bridge_globals(Object.new, nil) do
      assert_nil Engine.bridge_holder
      assert_equal 0, Engine.bridge_height
      assert_nil Engine.set_bridge(2), "setting one does nothing"
    end
  end

  test "a bridge height the engine cannot read or set is no bridge, and setting it does not raise" do
    broken = Object.new
    def broken.bridge; raise "unreadable"; end
    with_bridge_globals(broken, nil) do
      assert_equal 0, Engine.bridge_height
      assert_nil Engine.set_bridge(2)
    end
  end

  private

  # assert_equal, or assert_nil when the expected value is nil (minitest refuses assert_equal nil).
  def assert_equal_or_nil(want, got, msg)
    want.nil? ? assert_nil(got, msg) : assert_equal(want, got, msg)
  end

  # Runs the block with map as $game_map (nil for none) and the world read afresh, putting the real map back.
  def on_map(map)
    old = $game_map
    $game_map = map
    PokeAccess::World.reset!
    yield
  ensure
    $game_map = old
    PokeAccess::World.reset!
  end

  # Runs the block with PBTerrain given the constants in names, the terrain classed afresh before and after.
  def with_pbterrain(names)
    added = names.keys.reject { |c| PBTerrain.const_defined?(c, false) }
    names.each { |c, n| PBTerrain.const_set(c, n) }
    Terrain.reset!
    yield
  ensure
    added.each { |c| PBTerrain.send(:remove_const, c) }
    Terrain.reset!
  end

  # Runs the block with PBTerrain naming no number, as in an engine without it.
  def without_pbterrain_names
    kept = PBTerrain.constants.map { |c| [c, PBTerrain.const_get(c)] }
    kept.each { |c, _n| PBTerrain.send(:remove_const, c) }
    Terrain.reset!
    yield
  ensure
    kept.each { |c, n| PBTerrain.const_set(c, n) unless PBTerrain.const_defined?(c, false) }
    Terrain.reset!
  end

  # Runs the block with PBTerrain answering no surf test (the copies older than v15).
  def without_pbterrain_surf_test
    PBTerrain.singleton_class.send(:alias_method, :kept_isSurfable?, :isSurfable?)
    PBTerrain.singleton_class.send(:remove_method, :isSurfable?)
    yield
  ensure
    PBTerrain.singleton_class.send(:alias_method, :isSurfable?, :kept_isSurfable?)
    PBTerrain.singleton_class.send(:remove_method, :kept_isSurfable?)
  end

  # Runs the block with the global pbIsSurfableTag? of the copies older than v15 answering true for numbers.
  def with_global_surf_test(numbers)
    Object.send(:define_method, :pbIsSurfableTag?) { |tag| numbers.include?(tag) }
    Object.send(:private, :pbIsSurfableTag?)
    yield
  ensure
    Object.send(:remove_method, :pbIsSurfableTag?)
  end

  # Runs the block with a game's label rule registered, taking it back after.
  def with_label_rule(rule)
    rules = Terrain.instance_variable_get(:@label_rules)
    Terrain.label_rule(&rule)
    yield
  ensure
    rules.delete_if { |r| r.equal?(rule) }
  end

  # Runs the block with the engine's bridge argument judged afresh, putting back the judgement it found.
  def with_bridge_arg_unjudged
    was = Engine.instance_variable_get(:@bridge_arg)
    Engine.instance_variable_set(:@bridge_arg, nil)
    yield
  ensure
    Engine.instance_variable_set(:@bridge_arg, was)
  end

  # Runs the block with $PokemonGlobal and $PokemonMap set as an engine of that era keeps them.
  def with_bridge_globals(global, map)
    had = [$PokemonGlobal, $PokemonMap]
    $PokemonGlobal = global
    $PokemonMap = map
    yield
  ensure
    $PokemonGlobal, $PokemonMap = had
  end
end
