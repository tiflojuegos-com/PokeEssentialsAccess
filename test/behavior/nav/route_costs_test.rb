# What a route pays beyond its presses (Routes::Moves.costed?): the tiles a profile's tile_cost prices and, with
# avoid_grass, the grass where wild Pokemon appear; the rules a map has counted once per map, and the rules that count
# with the puzzle assist alone.
class RouteCostsTest < PokeAccessTest
  Moves = PokeAccess::Routes::Moves
  Config = PokeAccess::Config
  # A room two rows deep: four presses along the top row to (5,1), six round the second row.
  ROOM = ["#######",
          "#@....#",
          "#.....#",
          "#######"]
  STRAIGHT = [6, 6, 6, 6]
  ROUND = [2, 6, 6, 6, 6, 8]
  # The land encounters of a map as the game's table answers them, from Essentials 19 on and before it.
  Modern = Struct.new(:land) { def has_land_encounters?; land; end }
  Old = Struct.new(:land) { def isGrass?; land; end }

  test "with no rule and the option off, nothing costs more and the routes stay as they were" do
    room do
      assert_equal [false, true, STRAIGHT], [Moves.costed?, Moves.uniform?, walk_route(5, 1, true).to_a]
    end
  end

  test "a tile that costs more than the way round is gone round, one that costs less is crossed" do
    [[5, ROUND], [1, STRAIGHT], [0, STRAIGHT], [nil, STRAIGHT]].each do |extra, want|
      room do
        Moves.tile_cost_rule { |x, y| [x, y] == [3, 1] ? extra : nil }
        assert_equal want, walk_route(5, 1, true).to_a, "a tile that costs #{extra.inspect} more"
      end
    end
  end

  test "each search answers with the costs: A*, the regions router, the flood, and JPS gives way to A*" do
    [:astar, :regions, :jps, :dijkstra].each do |algo|
      room do
        Config.path_algorithm = algo
        Moves.tile_cost_rule(:tiles => lambda { |x, y| [x, y] == [3, 1] }) { |_x, _y| 5 }
        PokeAccess::Routes::Regions.foot.status([[0, 0]]) if algo == :regions
        r = PokeAccess::Routes::Planner.walk(5, 1, true)
        assert_equal [ROUND, algo == :jps ? :astar : algo], [r.route.to_a, r.algo], algo.to_s
      end
    end
  end

  test "a hop or a slide pays every tile it crosses, a carry or a transfer the tile it lands on" do
    room do
      Moves.tile_cost_rule { |x, y| x >= 3 ? y + 1 : nil }
      Moves.costed?
      assert_equal [2 + 2, 2, 3, 2], [Moves.crossed_extra(1, 1, 4, 1, [1, 0, 6]), Moves.crossed_extra(1, 1, 3, 1, [1, 0, 6]),
                                      Moves.crossed_extra(1, 1, 3, 2, [1, 0, 6]),
                                      Moves.crossed_extra(1, 1, 4, 1, [1, 0, 6], 0, true)]
    end
  end

  test "a move lands the player without a walk when it carries, transfers or climbs at the action button" do
    step = Moves::Step
    landed = [step.new(4, 1, 0, 1, nil, false, true, :walk), step.new(4, 1, 0, 1, nil, false, false, :carry),
              step.new(4, 1, 0, 1, nil, false, false, :warp), step.new(4, 1, 0, 1, { :kind => :act }, false, false, :assist)]
    walked = [step.new(4, 1, 0, 1), step.new(4, 1, 0, 1, nil, false, false, :slide),
              step.new(4, 1, 0, 1, { :kind => :field }, false, false, :assist)]
    assert_equal [[true] * 4, [false] * 3], [landed.map { |s| Moves.relocated?(s) }, walked.map { |s| Moves.relocated?(s) }]
  end

  test "on a bridge, what lies below costs nothing; under it, or off it, the tile costs what it costs" do
    room do
      $game_map.place_bridge(3, 2)
      PokeAccess::Pathfinder.invalidate_cache(true)
      Moves.tile_cost_rule { |_x, _y| 5 }
      Moves.costed?
      assert_equal [0, 5, 5], [Moves.tile_extra(3, 2, 2), Moves.tile_extra(3, 2, 0), Moves.tile_extra(2, 2, 2)]
    end
  end

  test "on a map with a bridge, a rule for tiles it has not keeps the grid searches, one for the bridge's tiles not" do
    room do
      $game_map.place_bridge(3, 2)
      PokeAccess::Pathfinder.invalidate_cache(true)
      Moves.tile_cost_rule(:tags => [88]) { |_x, _y| 4 }
      Moves.arrival_rule(:tags => [88]) { |_x, _y, _d| nil }
      other = [Moves.costed?, Moves.uniform?]
      Moves.tile_cost_rule(:tags => [15]) { |_x, _y| 4 }
      assert_equal [[false, true], true], [other, Moves.costed?]
    end
  end

  test "a tile cost makes the map no uniform grid only where its rule owns a tile" do
    room do
      Moves.tile_cost_rule(:tags => [77]) { |_x, _y| 4 }
      before = [Moves.costed?, Moves.uniform?]
      $game_map.set_terrain(3, 2, 77)
      PokeAccess::Pathfinder.invalidate_cache(true)
      assert_equal [[false, true], [true, false]], [before, [Moves.costed?, Moves.uniform?]]
    end
  end

  test "a terrain rule counts only on a map with a tile it owns, or with no owner on any" do
    room do
      Moves.arrival_rule(:tags => [77]) { |_x, _y, _d| nil }
      before = Moves.uniform?
      $game_map.set_terrain(3, 2, 77)
      PokeAccess::Pathfinder.invalidate_cache(true)
      owned = Moves.uniform?
      $game_map.set_terrain(3, 2, 0)
      PokeAccess::Pathfinder.invalidate_cache(true)
      Moves.leave_rule { |_x, _y, _d| nil }
      assert_equal [true, false, false], [before, owned, Moves.uniform?]
    end
  end

  test "rules that ask for the puzzle assist count with it alone, and turning it routes afresh" do
    [[:terrain_rule, lambda { Moves.arrival_rule(:assist => true, :tiles => lambda { |x, y| [x, y] == [3, 1] }) { |_x, _y, _d| false } }],
     [:tile_cost, lambda { Moves.tile_cost_rule(:assist => true) { |x, y| [x, y] == [3, 1] ? 5 : nil } }]].each do |verb, register|
      room do
        register.call
        PokeAccess::Routes::Regions.foot.status([[0, 0]])
        off = [walk_route(5, 1, true).to_a, Moves.uniform?]
        Config.set(:puzzle_assist, true)
        PokeAccess::Routes::Regions.foot.status([[0, 0]])
        on = [walk_route(5, 1, true).to_a, Moves.uniform?]
        Config.set(:puzzle_assist, false)
        assert_equal [[STRAIGHT, true], [ROUND, false], STRAIGHT], [off, on, walk_route(5, 1, true).to_a], verb.to_s
      end
    end
  end

  test "a rule whose tiles are where an event stands is read with the map's events, as Insurgence's pitfalls" do
    room do
      Moves.arrival_rule(:tiles => lambda { |x, y| PokeAccess::World::Events.anchored(x, y).any? { |r| r.name.to_s == "Pitfall" } }) { |_x, _y, _d| false }
      before = Moves.uniform?
      World.event(:kind => :npc, :id => 70, :x => 3, :y => 2, :name => "Pitfall")
      PokeAccess::Pathfinder.invalidate_cache(true)
      assert_equal [true, false], [before, Moves.uniform?]
    end
  end

  test "the grass option is off by default, and on it goes round grass where wild Pokemon appear" do
    room do
      $game_map.set_terrain(3, 1, 2)
      PokeAccess::Pathfinder.invalidate_cache(true)
      seen = [Config.avoid_grass, walk_route(5, 1, true).to_a]
      Config.set(:avoid_grass, true)
      [[Modern.new(true), ROUND], [Old.new(true), ROUND], [Modern.new(false), STRAIGHT], [nil, STRAIGHT]].each do |enc, want|
        with_encounters(enc) { seen.push(walk_route(5, 1, true).to_a == want) }
      end
      assert_equal [false, STRAIGHT, true, true, true, true], seen
    end
  end

  test "with the grass option on, grass costs GRASS_COST presses more a tile" do
    room do
      $game_map.set_terrain(3, 1, 2)
      Config.set(:avoid_grass, true)
      with_encounters(Modern.new(true)) do
        Moves.costed?
        assert_equal [Moves::GRASS_COST, 0], [Moves.tile_extra(3, 1), Moves.tile_extra(2, 1)]
      end
    end
  end

  private

  # The room laid out with no rule of the suite's profiles or plugins registered, the route memos taken afresh.
  def room
    without_terrain_rules do
      $game_map.clear_ledges
      $game_map.clear_grid
      $game_map.load_grid(ROOM)
      PokeAccess::Pathfinder.invalidate_cache(true)
      yield
    end
  ensure
    $game_map.clear_grid
  end

  # Runs the block with $PokemonEncounters answering enc, the route memos taken afresh; put back after.
  def with_encounters(enc)
    had = $PokemonEncounters
    $PokemonEncounters = enc
    PokeAccess::Pathfinder.invalidate_cache(true)
    yield
  ensure
    $PokemonEncounters = had
  end
end
