# A target got to only by stepping onto it, where its touch event takes the player on elsewhere (a switch that
# transfers them within the map, an arrow floor): the route ends on that press (Moves::Step#entry) by every search, on
# foot, past a boulder, over the ice it lies on and past the presses that open the way to it, with the puzzle assist
# and without it; a pad beside the target is no way to it.
class RouteEntryTest < PokeAccessTest
  Routes = PokeAccess::Routes
  Planner = PokeAccess::Routes::Planner
  Pathfinder = PokeAccess::Pathfinder

  # A run of ice from the player to the switch's tile, (5, 1), and a closet past the wall: the slide carries the player
  # past the last tile beside the switch, so none of them is ever stood on.
  ICE_ROWS = ["##########",
              "#@...S#..#",
              "##########"]
  # The same run behind a boulder on (4, 2), which only a push down into the pocket below gets out of the way, from
  # (4, 1); the switch on (7, 2).
  ROCK_ROWS = ["##########",
               "###..#####",
               "#@......##",
               "####.#####",
               "##########"]
  # A run of ice from (2, 1) to (6, 1) with the switch on (4, 1), on the ice itself: a slide passes over it before
  # reaching the tiles past it, and none of the tiles beside it is ever stood on; a closet past the wall.
  MID_ICE_ROWS = ["###########",
                  "#@.....#..#",
                  "###########"]
  # The ice run behind rays on (2, 1), gone while switch 142 is on, which the plate below the player on (1, 2) turns on.
  RAY_ROWS = ["##########",
              "#@...S#..#",
              "#.########",
              "##########"]

  test "a switch that transfers the player is walked onto, the route ending on that press" do
    both_assists do |on|
      ice_run { World.touch(:id => 70, :x => 5, :y => 1, :list => [transfer_to(7, 1)]) }
      assert_equal [6], walk_route(5, 1), "one press slides onto the switch (assist #{on})"
      assert_equal [[7, 1, :warp, Routes.pkey(5, 1)]], last_moves([6]), "and the switch takes the player across"
      assert_equal :yes, Planner.reach(Planner.goal_for(5, 1, false))[0], "the regions tell it can be got to"
    end
  end

  test "an arrow floor that carries the player off is walked onto, the route ending on that press" do
    both_assists do |on|
      ice_run { World.touch(:id => 71, :x => 5, :y => 1, :list => [World.move_player([3, 3])]) }
      assert_equal [6], walk_route(5, 1), "one press slides onto the arrow (assist #{on})"
      assert_equal [[7, 1, :carry, Routes.pkey(5, 1)]], last_moves([6]), "and the arrow carries the player across"
    end
  end

  test "a switch on the ice that a slide passes over is got to by that slide, the route ending on its press" do
    both_assists do |on|
      ice_run(MID_ICE_ROWS, 2..6) { World.touch(:id => 77, :x => 4, :y => 1, :list => [transfer_to(8, 1)]) }
      assert_equal [6], walk_route(4, 1), "one press slides over the switch (assist #{on})"
      assert_equal [[8, 1, :warp, Routes.pkey(4, 1)]], last_moves([6]), "and the switch takes the player across"
      assert_equal :yes, Planner.reach(Planner.goal_for(4, 1, false))[0], "the regions tell it can be got to"
    end
  end

  test "the presses that open the way count a switch got to only by stepping onto it" do
    rayed_run
    assert_equal :none, Planner.plan(5, 1).kind, "the rays close the way without the puzzle assist"
    PokeAccess::Config.puzzle_assist = true
    Pathfinder.invalidate_cache(true)
    plan = Planner.plan(5, 1)
    assert_equal [:assisted, [], :control, [1, 2]],
                 [plan.kind, plan.route.to_a, plan.gate && plan.gate[:kind], plan.gate && [plan.gate[:x], plan.gate[:y]]],
                 "with it, to the plate below that takes the rays away"
  end

  test "every search ends on the press onto the switch: the regions router, A*, the flood and the fewest presses" do
    ice_run { World.touch(:id => 72, :x => 5, :y => 1, :list => [transfer_to(7, 1)]) }
    goal = Planner.goal_for(5, 1, false)
    cost = Routes::CostModel.new(:shortest)
    mode = Routes::Moves::LEDGE
    Routes::Regions.foot.status([[0, 0]])
    routed = Pathfinder.searching { Routes::Regions.searched(goal, cost, mode, Routes::Search.bound_for(goal, mode)) }
    astar = Pathfinder.searching { Routes::Search.fresh(goal, mode) }
    flood = Pathfinder.searching { Routes::Flood.for(cost, mode).route_to(goal) }
    assert_equal [[:found, [6]], [:found, [6]], [:found, [6]]],
                 [routed, astar, flood].map { |r| [r.status, r.route.to_a] }, "the router, A* and the flood"
    assert_equal [0, []], [astar.route.rooms, astar.route.warps], "the transfer after it is none on the way"
    assert_equal 1, Routes::Regions.foot.presses_to(goal.tiles, goal.entry), "one press away"
    assert_nil Routes::Regions.foot.presses_to(goal.tiles), "standing beside it, none"
  end

  test "a switch past a boulder is got to by pushing the boulder aside first, with the puzzle assist and without it" do
    both_assists do |on|
      rock = nil
      rock_run { rock = boulder(93, 4, 2) }
      assert_nil walk_route(7, 2), "the boulder closes the way on foot (assist #{on})"
      steps, gate = Planner.assisted(7, 2)
      assert_equal [[6, 6, 8, 6], [:field, rock, 4, 2]], [steps.to_a, [gate[:kind], gate[:ev], gate[:x], gate[:y]]],
                   "up beside the boulder to push it down (assist #{on})"
    end
  end

  test "a pad beside the target is not stepped on for it, though it is the nearest of the tiles beside it" do
    $game_map.load_grid(["########",
                         "#......#",
                         "#@..####",
                         "########"])
    World.touch(:id => 73, :x => 2, :y => 2, :list => [transfer_to(6, 1)])
    World.event(:id => 74, :x => 3, :y => 2, :sprite => "npc")
    Pathfinder.invalidate_cache(true)
    assert_equal [8, 6, 6], walk_route(3, 2), "round the pad to the tile above the target"
  end

  private

  # Runs the block once with the puzzle assist off and once on, told which.
  def both_assists
    [false, true].each do |on|
      PokeAccess::Config.puzzle_assist = on
      yield on
    end
  ensure
    PokeAccess::Config.puzzle_assist = false
  end

  # An ice run (ICE_ROWS, or rows with ice on the columns of ice along row 1), its touch event placed by the block.
  def ice_run(rows = ICE_ROWS, ice = 2..4)
    World.clear_events
    $game_map.load_grid(rows)
    ice.each { |x| $game_map.set_terrain(x, 1, 12) }
    yield
    Pathfinder.invalidate_cache(true)
  end

  # The ice run behind rays (RAY_ROWS), the switch on (5, 1) sending the player to (7, 1), declared as a puzzle whose
  # rays are walls that read switch 142 and whose plate writes it.
  def rayed_run
    ice_run(RAY_ROWS, 3..4) do
      World.touch(:id => 76, :x => 5, :y => 1, :list => [transfer_to(7, 1)])
      World.touch(:id => 43, :x => 1, :y => 2, :list => [TestCmd.new(121, [142, 142, 0])])
      gone = TestPage.new(:trigger => 0, :sprite => "", :condition => { :switch1_valid => true, :switch1_id => 142 })
      rays = TestGameEvent.new(:id => 20, :x => 2, :y => 1, :pages => [TestPage.new(:trigger => 0, :sprite => "rayosR"), gone])
      rays.blocking = true
      $game_map.events[20] = rays
      PokeAccess::World::Mechanics.declare($game_map.map_id, :kind => :state, :controls => true,
                                           :watch => [{ :switch => 142, :label => :gym3_red, :on => :gym3_on, :off => :gym3_off }],
                                           :obstacles => [{ :match => /rayos/i, :kind => :wall }])
      PokeAccess::World::Mechanics.forget
    end
  end

  # The run behind a boulder (ROCK_ROWS), the boulder placed by the block, the switch on (7, 2) sending the player to
  # (3, 1).
  def rock_run
    World.clear_events
    $game_map.load_grid(ROCK_ROWS)
    $game_map.set_terrain(6, 2, 12)
    World.touch(:id => 75, :x => 7, :y => 2, :list => [transfer_to(3, 1)])
    yield
    Pathfinder.invalidate_cache(true)
  end

  # A Strength boulder at (x, y), moved as the engine moves one.
  def boulder(id, x, y)
    ev = World.touch(:id => id, :name => "Boulder", :x => x, :y => y, :trigger => 0, :sprite => "boulder",
                     :list => [TestCmd.new(355, ["pbPushThisBoulder"])])
    ev.blocking = true
    def ev.passableStrict?(x, y, d)
      nx = x + (d == 6 ? 1 : (d == 4 ? -1 : 0)); ny = y + (d == 2 ? 1 : (d == 8 ? -1 : 0))
      return true if through
      !$game_map.blocked?(nx, ny)
    end
    ev
  end

  # A Transfer Player command to (x, y) of this map.
  def transfer_to(x, y)
    TestCmd.new(201, [0, $game_map.map_id, x, y])
  end

  # The last press of a route from the player replayed: [x, y, kind, entry].
  def last_moves(path)
    s = traced($game_player.x, $game_player.y, 0, path).last
    [[s.x, s.y, s.kind, s.entry]]
  end
end
