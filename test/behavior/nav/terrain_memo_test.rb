# The terrain is asked once per kind of tile (World::Terrain) and kept while the map and its tiles stand, and for the
# way back to a map left as it was; changed tiles, a new map or a reset drop it. The regions and the sonar read it too.
class TerrainMemoTest < PokeAccessTest
  Terrain = PokeAccess::World::Terrain
  Epoch = PokeAccess::World::Epoch
  Scene = PokeAccess::Sound::Scene
  # A walled room with the player at its top left.
  ROOM = ["########",
          "#@.....#",
          "#......#",
          "########"]

  # Map data that counts the layer reads made of it; the tally is the class's, so the object and Epoch's fingerprint
  # of it stay as they were.
  class CountedData
    class << self; attr_accessor :reads; end
    def initialize(inner); @inner = inner; end
    def [](x, y, layer); CountedData.reads += 1; @inner[x, y, layer]; end
  end

  # Map data whose layer given holds, at the tiles given, the first id past any tileset's (ID_SPAN).
  class HighIdData
    def initialize(inner, layer, tiles); @inner = inner; @layer = layer; @tiles = tiles; end
    def [](x, y, layer)
      layer == @layer && @tiles.include?([x, y]) ? PokeAccess::World::Terrain::ID_SPAN : @inner[x, y, layer]
    end
  end

  # A modern engine's tag object carrying a plugin's flag (a current), counting how often the flag is read.
  class FlaggedTag
    attr_reader :reads
    def initialize; @reads = 0; end
    def current; @reads += 1; true; end
  end

  test "walking the regions again asks the engine nothing, and reaches the tiles a world read afresh does" do
    $game_map.load_grid(["##########", "#@.......#", "#........#", "#........#", "##########"])
    $game_map.place_ledge(4, 2, 2)
    $game_map.set_terrain(6, 1, 12)
    regions = PokeAccess::Routes::Regions
    counting_tags do |calls|
      first = regions.foot.tiles.sort
      cold = calls.call
      regions.forget
      again = regions.foot.tiles.sort
      warm = calls.call
      PokeAccess::World.reset!
      fresh = regions.foot.tiles.sort
      assert_equal [true, cold, first, first], [cold > 0, warm, again, fresh]
    end
  end

  test "answers each tile with its tag's kind, number and tests, the map's edges included" do
    $game_map.load_grid(ROOM)
    $game_map.place_ledge(2, 2, 2)
    { [6, 1] => 12, [3, 1] => 7, [4, 1] => 5, [5, 2] => 10, [6, 2] => 8, [0, 1] => 7, [3, 0] => 12, [7, 2] => 7,
      [4, 3] => 10 }.each { |(x, y), tag| $game_map.set_terrain(x, y, tag) }
    { [2, 2] => [:ledge, 1, true, false, false, false, false, false],
      [0, 1] => [:water, 7, false, false, true, false, false, false],
      [3, 0] => [:ice, 12, false, true, false, false, false, false],
      [7, 2] => [:water, 7, false, false, true, false, false, false],
      [4, 3] => [:tall_grass, 10, false, false, false, false, true, false],
      [6, 1] => [:ice, 12, false, true, false, false, false, false],
      [3, 1] => [:water, 7, false, false, true, false, false, false],
      [4, 1] => [:deep_water, 5, false, false, true, true, false, false],
      [5, 2] => [:tall_grass, 10, false, false, false, false, true, false],
      [6, 2] => [:waterfall, 8, false, false, true, false, false, true],
      [1, 2] => [nil, 0, false, false, false, false, false, false] }.each do |(x, y), want|
      assert_equal want, tile_answers(x, y), "at (#{x}, #{y}): kind, number, ledge, ice, surf, deep, grass, falling"
    end
  end

  test "answers no terrain past the map's edges, nor where the engine has no answer" do
    $game_map.load_grid(ROOM)
    $game_map.set_terrain(2, 1, 16)
    answering(16 => nil) do
      [[-1, 1], [3, -1], [8, 1], [3, 4], [2, 1]].each do |x, y|
        assert_equal [nil, nil, false, false, false, false, false, false], tile_answers(x, y), "at (#{x}, #{y})"
      end
    end
  end

  test "answers a plugin's flag where the tag carries it, reading it once for every tile the tag is on" do
    $game_map.load_grid(ROOM)
    $game_map.set_terrain(3, 1, 13)
    $game_map.set_terrain(5, 2, 14)
    tag = FlaggedTag.new
    answering(13 => tag, 14 => tag) do
      got = [Terrain.flag?(3, 1, :current), Terrain.flag?(3, 1, :current), Terrain.flag?(5, 2, :current),
             Terrain.flag?(3, 1, :rail), Terrain.flag?(4, 1, :current)]
      assert_equal [[true, true, true, false, false], 1], [got, tag.reads],
                   "the current kept, the same tag on other tiles classed once, no rail, none on the floor"
    end
  end

  test "asks tiles alike once, and each other kind of tile on its own" do
    $game_map.load_grid(ROOM)
    $game_map.set_terrain(2, 2, 7)
    $game_map.set_terrain(5, 2, 7)
    $game_map.set_terrain(6, 2, 12)
    counting_tags do |calls|
      got = [[Terrain.kind(2, 2), Terrain.kind(5, 2)], calls.call, Terrain.kind(6, 2), calls.call,
             [Terrain.kind(3, 1), Terrain.kind(4, 1)], calls.call]
      assert_equal [[:water, :water], 1, :ice, 2, [nil, nil], 3], got,
                   "both waters on one question, the ice on its own, the plain floor on one more"
    end
  end

  test "tells tiles apart by each of their three layers" do
    $game_map.load_grid(ROOM)
    $game_map.place_ledge(2, 1, 2)
    $game_map.place_bridge(4, 1)
    counting_tags do |calls|
      got = [Terrain.kind(3, 1), calls.call, Terrain.kind(2, 1), calls.call, Terrain.kind(4, 1), calls.call]
      assert_equal [nil, 1, :ledge, 2, :water, 3], got, "the floor, a ledge on the bottom layer, a bridge on the middle"
    end
  end

  test "asks each tile holding an id past any tileset's on its own, on its middle or top layer" do
    [1, 2].each do |layer|
      $game_map.load_grid(ROOM)
      PokeAccess::World.reset!
      with_data(HighIdData.new($game_map.data, layer, [[2, 1], [3, 1]])) do
        counting_tags do |calls|
          Terrain.kind(2, 1)
          Terrain.kind(3, 1)
          assert_equal 2, calls.call, "on layer #{layer}"
        end
      end
    end
  end

  test "answers a tile asked again from its memo, its layers not read again" do
    $game_map.load_grid(ROOM)
    $game_map.set_terrain(4, 2, 7)
    with_data(CountedData.new($game_map.data)) do
      CountedData.reads = 0
      Terrain.kind(4, 2)
      first = CountedData.reads
      Terrain.kind(4, 2)
      assert_equal [true, first], [first > 0, CountedData.reads]
    end
  end

  test "an event's end that changed no tile keeps the memo" do
    assert_equal 0, asked_again { Epoch.tiles_due! }
  end

  test "an event's end that changed a tile has the tiles asked again" do
    n = asked_again do
      $game_map.instance_variable_get(:@ledges)[[6, 1]] = 2
      Epoch.tiles_due!
    end
    assert_equal 1, n
  end

  test "each reader takes a tile an event's end changed as it is now" do
    answering(13 => FlaggedTag.new) do
      { "kind" => [lambda { Terrain.kind(4, 2) }, nil, :ice],
        "number" => [lambda { Terrain.number(4, 2) }, nil, 12],
        "tests" => [lambda { Terrain.ice?(4, 2) }, false, true],
        "label" => [lambda { Terrain.label(4, 2) }, nil, :surf_ice],
        "flag" => [lambda { Terrain.flag?(4, 2, :current) }, true, false] }.each do |what, (read, was, now)|
        $game_map.load_grid(ROOM)
        $game_map.set_terrain(4, 2, 13)
        PokeAccess::World.reset!
        first = read.call
        $game_map.instance_variable_get(:@terrain)[[4, 2]] = 12
        Epoch.tiles_due!
        assert_equal [was, now], [first, read.call], "the #{what}, a plugin's flagged tag turned to ice"
      end
    end
  end

  test "a new map has its tiles asked again" do
    n = asked_again do
      $game_map.map_id += 1
      Epoch.dirty!
    end
    assert_equal 1, n
  end

  test "a reset has its tiles asked again and their tags classed anew, by the terrain names the game has then" do
    $game_map.load_grid(ROOM)
    $game_map.set_terrain(4, 2, 13)
    counting_tags do |calls|
      before = Terrain.kind(4, 2)
      PBTerrain.const_set(:Puddle, 13)
      PokeAccess::World.reset!
      assert_equal [:neutral, :puddle, 2], [before, Terrain.kind(4, 2), calls.call],
                   "the standard neutral, then the puddle the game has named it since, the tile asked again"
    end
  ensure
    PBTerrain.send(:remove_const, :Puddle) if PBTerrain.const_defined?(:Puddle, false)
  end

  test "coming back to a map left as it was, its tiles are not asked again" do
    home = $game_map.map_id
    n = asked_again do
      [home + 1, home].each do |id|
        $game_map.map_id = id
        Epoch.dirty!
        Epoch.settle
      end
    end
    assert_equal [0, :water], [n, Terrain.kind(4, 2)]
  end

  test "coming back to a map whose tiles changed while away, its tiles are asked again" do
    home = $game_map.map_id
    n = asked_again do
      $game_map.map_id = home + 1
      Epoch.dirty!
      Epoch.settle
      $game_map.instance_variable_get(:@ledges)[[6, 1]] = 2
      $game_map.map_id = home
      Epoch.dirty!
      Epoch.settle
    end
    assert_equal 1, n
  end

  test "the sonar's water ring asks no tile again on the same ring" do
    $game_map.load_grid(ROOM)
    $game_map.set_terrain(4, 2, 7)
    counting_tags do |calls|
      found = Scene.nearest_water(1, 1, 6)
      first = calls.call
      again = Scene.nearest_water(1, 1, 6)
      assert_equal [[4, 2], true, [4, 2], first], [found, first > 0, again, calls.call]
    end
  end

  test "the sonar's water ring takes nothing but water for water" do
    $game_map.load_grid(ROOM)
    $game_map.set_terrain(2, 1, 10)
    $game_map.set_terrain(1, 2, 12)
    $game_map.set_terrain(4, 2, 7)
    assert_equal [4, 2], Scene.nearest_water(1, 1, 6), "past the grass and the ice nearer"
  end

  test "the sonar's water ring reads changed tiles as they are now" do
    terrain = nil
    { "set by the engine" => lambda { $game_map.set_terrain(2, 1, 7) },
      "found at an event's end" => lambda { terrain[[2, 1]] = 7; Epoch.tiles_due! } }.each do |how, change|
      $game_map.load_grid(ROOM)
      $game_map.clear_ledges
      $game_map.set_terrain(4, 2, 7)
      terrain = $game_map.instance_variable_get(:@terrain)
      Scene.nearest_water(1, 1, 6)
      terrain.delete([4, 2])
      change.call
      assert_equal [2, 1], Scene.nearest_water(1, 1, 6), "the water #{how}"
    end
  end

  private

  # Runs the block counting the engine's terrain questions, yielding a lambda that reads the count.
  def counting_tags
    n = [0]
    real = $game_map.method(:terrain_tag)
    $game_map.define_singleton_method(:terrain_tag) { |*a| n[0] += 1; real.call(*a) }
    yield lambda { n[0] }
  ensure
    $game_map.singleton_class.send(:remove_method, :terrain_tag)
  end

  # Runs the block with the engine answering, for each tag number of answers, its value in its place.
  def answering(answers)
    real = $game_map.method(:terrain_tag)
    $game_map.define_singleton_method(:terrain_tag) { |*a| answers.fetch(v = real.call(*a), v) }
    yield
  ensure
    $game_map.singleton_class.send(:remove_method, :terrain_tag)
  end

  # What the terrain answers at (x, y): [kind, number, ledge?, ice?, surfable?, deep?, grass?, falling?].
  def tile_answers(x, y)
    [Terrain.kind(x, y), Terrain.number(x, y), Terrain.ledge?(x, y), Terrain.ice?(x, y), Terrain.surfable?(x, y),
     Terrain.deep?(x, y), Terrain.grass?(x, y), Terrain.falling?(x, y)]
  end

  # Runs the block with the map's data read through data.
  def with_data(data)
    $game_map.define_singleton_method(:data) { data }
    yield
  ensure
    $game_map.singleton_class.send(:remove_method, :data)
  end

  # How many terrain questions a water tile read before the block takes when read after it.
  def asked_again
    $game_map.load_grid(ROOM)
    $game_map.set_terrain(4, 2, 7)
    counting_tags do |calls|
      Terrain.kind(4, 2)
      before = calls.call
      yield
      Terrain.kind(4, 2)
      calls.call - before
    end
  end
end
