# Ice and bridges in the routes: a step onto ice ends where the slide stops, an event slid over deciding where; on a
# bridge map the search carries the level its ramps set and puts the player's own back afterwards, whatever happens.
class IceBridgeTest < PokeAccessTest
  PF = PokeAccess::Pathfinder
  Moves = PokeAccess::Routes::Moves
  RIGHT = [1, 0, 6]
  # The bridge's ramps on row 3 of a TwoLevelMap, event id => [x, script]: on at x 1 and 6, off at x 0 and 7.
  RAMPS = { 1 => [1, "pbBridgeOn"], 2 => [6, "pbBridgeOn"], 3 => [0, "pbBridgeOff"], 4 => [7, "pbBridgeOff"] }

  # A bridge map on two levels: the deck is row 3 from x 2 to 5, over a path at x 3 that runs from top to bottom; on
  # the bridge (level above 0) the deck is crossed side to side, below it the path is walked up and down. The rest of
  # row 3 is ground. Passability is answered for the level $PokemonGlobal.bridge holds, as the engine answers it.
  class TwoLevelMap
    attr_accessor :map_id, :events

    def initialize; @map_id = 778; @events = {}; end
    def terrain_tag(*_args); 0; end
    def valid?(x, y); x >= 0 && y >= 0 && x < 9 && y < 7; end
    def width; 9; end
    def height; 7; end
    def deck?(x, y); y == 3 && x >= 2 && x <= 5; end

    def stand?(x, y, lvl)
      return lvl > 0 || x == 3 if deck?(x, y)
      (y == 3 && x >= 0 && x <= 7) || (x == 3 && y >= 0 && y <= 6)
    end

    def passable?(x, y, d)
      lvl = ($PokemonGlobal.bridge rescue 0).to_i
      dl = { 8 => [0, -1], 2 => [0, 1], 4 => [-1, 0], 6 => [1, 0] }[d]
      return stand?(x, y, lvl) if dl.nil?
      nx = x + dl[0]
      ny = y + dl[1]
      return false unless stand?(nx, ny, lvl)
      vertical = (d == 2 || d == 8)
      return !vertical if lvl > 0 && (deck?(nx, ny) || deck?(x, y))
      return vertical if lvl == 0 && ([nx, ny] == [3, 3] || [x, y] == [3, 3])
      true
    end
  end

  # The player on a TwoLevelMap, who moves where the map lets them.
  class BridgePlayer
    attr_accessor :x, :y, :through

    def initialize(x, y); @x = x; @y = y; end
    def passable?(x, y, d); $game_map.passable?(x, y, d); end
  end

  # A map that keeps no events and reads no tile ids: row 1 open from x 1 to 6, ice from x 2 to 5.
  class EventlessIceMap
    attr_reader :map_id

    def initialize; @map_id = 777; end
    def terrain_tag(x, y, *_rest); y == 1 && x >= 2 && x <= 5 ? 12 : 0; end
    def valid?(x, y); x >= 0 && y >= 0 && x < 9 && y < 3; end
    def width; 9; end
    def height; 3; end

    def passable?(x, y, d)
      nx = x + (d == 6 ? 1 : (d == 4 ? -1 : 0))
      ny = y + (d == 2 ? 1 : (d == 8 ? -1 : 0))
      ny == 1 && nx >= 1 && nx <= 6
    end
  end

  test "a slide over ice stops on the first floor past it" do
    ice_row("#@.....#", 2..5)
    assert_equal [6, 1], Moves.ice_slide(2, 1, 1, 0, 6)
  end

  test "a slide stops on the last ice before a wall" do
    ice_row("#@....#", 2..5)
    assert_equal [5, 1], Moves.ice_slide(2, 1, 1, 0, 6)
  end

  test "a step onto ice ends where the slide does, as a slide" do
    ice_row("#@.....#", 2..5)
    s = Moves.step(1, 1, 0, RIGHT, 0)
    assert_equal [6, 1, 0, :slide], [s.x, s.y, s.level, s.kind]
  end

  test "a step onto ice a wall stops at once is a plain walk" do
    ice_row("#@.#", 2..2)
    s = Moves.step(1, 1, 0, RIGHT, 0)
    assert_equal [2, 1, :walk], [s.x, s.y, s.kind]
  end

  test "a warp pad slid over sets where the slide ends" do
    ice_row("#@.....#", 2..5, "#......#")
    World.touch(:id => 61, :x => 4, :y => 1, :list => [TestCmd.new(201, [0, $game_map.map_id, 1, 2])])
    assert_equal [1, 2], Moves.ice_slide(2, 1, 1, 0, 6)
    s = Moves.step(1, 1, 0, RIGHT, 0)
    assert_equal [1, 2], [s.x, s.y], "and the step onto the ice lands there"
  end

  test "on a map whose events cannot be read, a slide goes by the tiles alone" do
    old = $game_map
    $game_map = EventlessIceMap.new
    PF.invalidate_cache(true)
    assert_equal [6, 1], Moves.ice_slide(2, 1, 1, 0, 6)
  ensure
    $game_map = old
    PF.invalidate_cache(true)
  end

  test "a doorway out of the map on the ice voids the step onto it" do
    ice_row("#@.....#", 2..5)
    World.touch(:id => 62, :x => 4, :y => 1, :list => [TestCmd.new(201, [0, 99, 5, 5])])
    assert_nil Moves.step(1, 1, 0, RIGHT, 0)
  end

  test "on a bridge map the route climbs the ramp and crosses the deck" do
    on_bridge_map(0, 3) { assert_equal [6, 6, 6, 6, 6, 6], walk_route(7, 3) }
  end

  test "the ramp is a move of its own, onto the deck's level, and the deck is walked on it" do
    on_bridge_map(0, 3) do
      assert_equal [[1, 3, 2, :ramp], [2, 3, 2, :walk], [3, 3, 2, :walk]],
                   traced(0, 3, 0, [6, 6, 6]).map { |s| [s.x, s.y, s.level, s.kind] }
    end
  end

  test "after a search on a bridge map the player's own level is put back" do
    on_bridge_map(0, 3) do
      walk_route(7, 3)
      assert_equal 0, $PokemonGlobal.bridge
    end
  end

  test "under the bridge the ground is walked at the ground's level" do
    on_bridge_map(3, 1) { assert_equal [2, 2, 2], walk_route(3, 5) }
  end

  test "a search another left on the deck still starts from the player's level" do
    on_bridge_map(3, 1) do
      assert_equal [0, [2, 2, 2]], PF.searching { PF.use_level(2); [PF.bridge_level, walk_route(3, 5)] }
    end
  end

  test "the probe keeps each level's own answer for the same step" do
    on_bridge_map(3, 1) do
      probe = PokeAccess::World::Probe
      assert_equal [true, false, true],
                   PF.searching { [0, 2, 0].map { |lvl| PF.use_level(lvl); probe.step?(3, 2, 2) } }
    end
  end

  test "without a ramp the deck is out of reach, as it is in the game" do
    on_bridge_map(0, 3, false) { assert_nil walk_route(7, 3) }
  end

  test "the player's level is put back even when the search raises" do
    on_bridge_map(0, 3) do
      assert_raises(RuntimeError) { PF.with_level_kept { PF.use_level(2); raise "boom" } }
      assert_equal 0, $PokemonGlobal.bridge
    end
  end

  test "on a map with no ramp the engine's level is never moved" do
    hpa_fresh_grid(["#####", "#@..#", "#####"])
    assert_equal [0, 0], [PF.searching { PF.use_level(2); $PokemonGlobal.bridge }, $PokemonGlobal.bridge]
  end

  test "outside a search the engine's level is not moved" do
    on_bridge_map(0, 3) do
      PF.use_level(2)
      assert_equal 0, $PokemonGlobal.bridge
    end
  end

  test "once a search's level is put back, the rest of its operation moves it no more" do
    on_bridge_map(0, 3) do
      assert_equal 0, PF.with_limits { PF.with_level_kept { PF.use_level(2) }; PF.use_level(2); $PokemonGlobal.bridge }
    end
  end

  private

  # Loads a map of one walled row (rows: the row, then any rows below it) with ice on the columns of xs.
  def ice_row(row, xs, *below)
    hpa_fresh_grid(["#" * row.length, row] + below + ["#" * row.length])
    xs.each { |x| $game_map.set_terrain(x, 1, 12) }
    PF.invalidate_cache(true)
  end

  # Runs the block on a TwoLevelMap with the player at (x, y), off the bridge, and with ramps its RAMPS; the real map,
  # player and level put back after.
  def on_bridge_map(x, y, ramps = true)
    old = [$game_map, $game_player]
    $game_map = TwoLevelMap.new
    $game_player = BridgePlayer.new(x, y)
    $PokemonGlobal.bridge = 0
    if ramps
      RAMPS.each { |id, (rx, script)| World.touch(:id => id, :x => rx, :y => 3, :list => [TestCmd.new(355, [script])]) }
    end
    PF.invalidate_cache(true)
    yield
  ensure
    $game_map, $game_player = old
    $PokemonGlobal.bridge = 0
    PF.invalidate_cache(true)
  end
end
