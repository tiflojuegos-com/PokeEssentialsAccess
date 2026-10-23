# Getting to a target is one answer for hiding, ordering and routing (Locator.goal_of): an object of several tiles from
# any of them, a map edge or wide doorway at its tile the fewest presses away on foot, where a ledge hop is one press.
class TargetReachTest < PokeAccessTest
  Loc = PokeAccess::Locator
  Edge = PokeAccess::Locator::SurfaceTarget
  # A room whose top border opens at (2, 0) and (8, 0), the near opening walled off from the player's row.
  BORDER = ["##.#####.#",
            "#........#",
            "#######..#",
            "#@.......#",
            "##########"]
  # Two rows joined by the one-way ledge at (3, 2), hopped down.
  LEDGE_ROOM = ["#######",
                "#..@..#",
                "###.###",
                "#.....#",
                "#######"]

  test "acts on an object of several tiles from any tile of its area" do
    $game_map.load_grid(["#######",
                         "#######",
                         "#....@#",
                         "#######"])
    statue = World.event(:id => 4, :x => 1, :y => 2, :name => "Estatua size(3,1)")
    PokeAccess::Pathfinder.invalidate_cache(true)
    plan = Loc.route_plan(statue)
    assert_equal [true, true, :walk, [4]],
                 [PokeAccess::Pathfinder.reach_tiles(1, 2).include?([4, 2]), Loc.reachable?(statue), plan.kind,
                  plan.route.to_a],
                 "the tile beside its far end counts, so it is got to by the one step there"
  end

  test "aims a map edge at its border tile the fewest presses away on foot, and stands on it" do
    $game_map.load_grid(BORDER)
    PokeAccess::Pathfinder.invalidate_cache(true)
    Loc.instance_variable_set(:@conn_edges, { 4 => [[2, 0], [8, 0]] })
    t = Loc.aim_connection(Edge.new(2, 0, "salida a Ruta 4", nil, 4))
    plan = Loc.route_plan(t)
    assert_equal [[8, 0], 10, :walk, 10, [8, 0]],
                 [[t.x, t.y], PokeAccess::Routes::Regions.foot.presses_to([[8, 0]]), plan.kind, plan.route.length,
                  traced(1, 3, 0, plan.route).last.tile],
                 "the far opening, ten presses away, not the near one round the wall, its route ending on it"
  ensure
    Loc.instance_variable_set(:@conn_edges, nil)
  end

  test "leaves a map edge as it is with one border tile, or with none the player can get to" do
    $game_map.load_grid(["####.##.#",
                         "#@..#..##",
                         "#########"])
    PokeAccess::Pathfinder.invalidate_cache(true)
    { [[4, 0]] => 5, [[4, 0], [7, 0]] => 6 }.each do |edges, dest|
      Loc.instance_variable_set(:@conn_edges, { dest => edges })
      t = Edge.new(4, 0, "salida a Ruta #{dest}", nil, dest)
      assert_same t, Loc.aim_connection(t), "with border tiles #{edges.inspect}"
    end
  ensure
    Loc.instance_variable_set(:@conn_edges, nil)
  end

  test "hides, while hiding, a map edge the player cannot get to, as any target" do
    $game_map.load_grid(["####.##",
                         "#@..#.#",
                         "#######"])
    PokeAccess::Pathfinder.invalidate_cache(true)
    PokeAccess::Config.hide_unreachable = :unreachable
    npc = World.event(:id => 3, :x => 3, :y => 1)
    edge = Edge.new(4, 0, "salida a Ruta 5", nil, 5)
    assert_equal [false, [npc]], [Loc.reachable?(edge), Loc.filtered([npc, edge], :exits)],
                 "the edge past the wall cannot be got to, so it is hidden and the person kept"
  end

  test "lists every target while hiding when none can be got to, taking the regions to misread the map" do
    $game_map.load_grid(["#######",
                         "#@#.#.#",
                         "#######"])
    PokeAccess::Pathfinder.invalidate_cache(true)
    PokeAccess::Config.hide_unreachable = :unreachable
    sealed = [World.event(:id => 3, :x => 3, :y => 1), World.event(:id => 4, :x => 5, :y => 1)]
    assert_equal [[false, false], sealed], [sealed.map { |e| Loc.reachable?(e) }, Loc.filtered(sealed, :people)]
  end

  test "stands a wide doorway, while hiding, by a tile the player can get to" do
    $game_map.load_grid(["########",
                         "#@.....#",
                         "#.###..#",
                         "#.#.#..#",
                         "#.##...#",
                         "########"])
    PokeAccess::Pathfinder.invalidate_cache(true)
    World.touch(:id => 7, :x => 3, :y => 3, :list => [TestCmd.new(201, [0, 5, 4, 4])])
    World.touch(:id => 8, :x => 4, :y => 4, :list => [TestCmd.new(201, [0, 5, 5, 4])])
    PokeAccess::Config.hide_unreachable = :unreachable
    Loc.clear_targets
    Loc.instance_variable_set(:@cat_id, :exits)
    Loc.step(1)
    assert_equal [8, [:event, 7]], [Loc.target.id, Loc.identity(Loc.target)],
                 "the tile the player can get to, not the nearer sealed one, under the doorway's one identity"
  ensure
    Loc.instance_variable_set(:@cat_id, :all)
  end

  test "stands a wide doorway, in the walk order, by its tile the fewest presses away on foot" do
    $game_map.load_grid(["#########",
                         "#@#.....#",
                         "#.#.....#",
                         "#.......#",
                         "#########"])
    PokeAccess::Pathfinder.invalidate_cache(true)
    World.touch(:id => 7, :x => 3, :y => 1, :list => [TestCmd.new(201, [0, 5, 4, 4])])
    World.touch(:id => 8, :x => 3, :y => 2, :list => [TestCmd.new(201, [0, 5, 4, 5])])
    Loc.instance_variable_set(:@cat_id, :exits)
    stand_ins = [:near, :walk].map do |order|
      PokeAccess::Config.target_order = order
      Loc.clear_targets
      Loc.step(1)
      Loc.target.id
    end
    assert_equal [7, 8], stand_ins, "the top tile is nearer in a straight line, the lower one on foot round the wall"
  ensure
    Loc.instance_variable_set(:@cat_id, :all)
  end

  test "counts the presses on foot with a ledge hop as one press for two tiles" do
    $game_map.load_grid(LEDGE_ROOM)
    $game_map.place_ledge(3, 2, 2)
    PokeAccess::Pathfinder.invalidate_cache(true)
    reg = PokeAccess::Routes::Regions.foot
    { [[3, 3]] => 1, [[1, 3]] => 3, [[5, 1]] => 2, [[1, 3], [5, 1]] => 2 }.each do |tiles, want|
      assert_equal want, reg.presses_to(tiles), "to #{tiles.inspect}"
    end
  end

  test "counts no presses back up a ledge" do
    $game_map.load_grid(LEDGE_ROOM)
    $game_map.place_ledge(3, 2, 2)
    $game_player.y = 3
    PokeAccess::Pathfinder.invalidate_cache(true)
    assert_nil PokeAccess::Routes::Regions.foot.presses_to([[3, 1]])
  end
end
