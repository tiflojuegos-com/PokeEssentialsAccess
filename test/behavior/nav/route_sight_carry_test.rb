# Watchers the engine starts by sight whose page moves the player (Effects.sight_facet), as Realidea's sea currents: each
# tile of their line takes the player on, the walks and the regions ride them, and the guide says the press onto the line
# by what it does. A self switch their autorun page turns off at once is no change that stays (EventPages.reset_at_once?);
# a trainer that talks and fights still only watches, and a bump starts one only from in front.
class RouteSightCarryTest < PokeAccessTest
  Effects = PokeAccess::Routes::Effects
  Moves = PokeAccess::Routes::Moves
  Sight = PokeAccess::Routes::Sight
  # Two rooms a wall apart, the player in the top one; a current on the left wall of its second row looks right.
  ROOMS = ["#########",
           "#@......#",
           "#.......#",
           "#########",
           "#.......#",
           "#.......#",
           "#########"]
  # One corridor, a watcher's place on its right wall.
  CORRIDOR = ["#######",
              "#@....#",
              "#######"]
  DOWN_TWO = [37, 1, 1, 38, 0]

  test "each tile of the line carries the player through the wall, and the walk rides it" do
    rooms do
      current(0, 2, 6, "Trainer(3)", DOWN_TWO)
      t = Effects.touch_index[PokeAccess::Routes.pkey(3, 2)]
      assert_equal [true, [:carry, 0, 2], :sight], [t[0], t[1][2][0, 3], t[2]]
      assert_nil Effects.touch_index[PokeAccess::Routes.pkey(4, 2)], "past its range"
      r = PokeAccess::Routes::Planner.walk(4, 5, true)
      kinds = Moves.one_way(1, 1, 0, r.route.to_a)
      assert_equal [:found, 5, 1], [r.status, r.route.to_a.length, kinds.count(:swept)]
      assert reached?(4, 5)
      assert_equal [2], PokeAccess::Routes::Planner.plan(0, 2).route.to_a, "the way to the current ends as it takes over"
    end
  end

  test "a self switch that stays on makes the current a change, and the room below is out of reach" do
    rooms do
      current(0, 2, 6, "Trainer(3)", DOWN_TWO, false)
      assert_nil Effects.touch_index[PokeAccess::Routes.pkey(2, 2)]
      refute_equal :found, PokeAccess::Routes::Planner.walk(4, 5, true).status
    end
  end

  test "a trainer that talks and fights carries nobody along its line and still watches it" do
    rooms do
      talk = [TestCmd.new(101, ["Hey!"]), TestCmd.new(355, ["pbTrainerBattle(:HIKER, \"Al\")"]),
              World.move_player([4, 0]), TestCmd.new(0, [])]
      ev = current(0, 2, 6, "Trainer(3)", nil, true, talk)
      ev.through = false
      PokeAccess::Pathfinder.invalidate_cache(true)
      PokeAccess::Config.avoid_trainers = true
      assert_equal [nil, true], [Effects.touch_index[PokeAccess::Routes.pkey(1, 2)], Sight.seen?(1, 2)]
    end
  end

  test "a bump starts a watcher only from the tile in front of it" do
    rooms do
      current(4, 3, 8, "Trainer(1)", nil, true, [World.move_player([37, 4, 38, 0]), TestCmd.new(0, [])])
      assert_equal [nil, :carry], [Effects.touch_at(4, 3, 8, false), (Effects.touch_at(4, 3, 2, false) || [])[0]]
    end
  end

  test "a watcher that walks through on open floor is started by stepping on it, not by its sight" do
    rooms do
      current(4, 2, 6, "Trainer(3)", DOWN_TWO)
      assert_equal [nil, nil], [Effects.sight_line(4, 2), Effects.touch_index[PokeAccess::Routes.pkey(5, 2)]]
    end
  end

  test "a watcher that sends the player to another spot of the map warps them from its line" do
    rooms do
      warp = [TestCmd.new(201, [0, $game_map.map_id, 6, 5, 0, 0]), TestCmd.new(0, [])]
      current(8, 1, 4, "Trainer(2)", nil, true, warp)
      t = Effects.touch_index[PokeAccess::Routes.pkey(6, 1)]
      assert_equal [[:warp, 6, 5], :sight], [t[1][4], t[2]]
      assert_nil Effects.touch_index[PokeAccess::Routes.pkey(5, 1)]
    end
  end

  test "the way to a watcher that sends the player off the map ends with the press into its line, which no other way crosses" do
    rooms(CORRIDOR) do
      current(6, 1, 4, "Trainer(2)", nil, true, [TestCmd.new(201, [0, 999, 3, 3, 2, 0]), TestCmd.new(0, [])])
      plan = PokeAccess::Routes::Planner.plan(6, 1)
      assert_equal [:walk, [6, 6, 6]], [plan.kind, plan.route.to_a]
      assert_equal [nil, nil, nil], Moves.one_way(1, 1, 0, plan.route.to_a)
      assert_equal PokeAccess::Routes::Text.route_line(PokeAccess::Routes::Text.leg(6, 3)),
                   PokeAccess::Routes::Text.line(plan, [1, 1], Moves.one_way(1, 1, 0, plan.route.to_a))
      refute_equal :found, PokeAccess::Routes::Planner.walk(5, 1, true).status
    end
  end

  test "the guide says the press onto the line by what it does" do
    rooms do
      current(0, 2, 6, "Trainer(3)", DOWN_TWO)
      said = PokeAccess::Routes::Text.steps([2, 6, 6, 6, 2], Moves.one_way(1, 1, 0, [2, 6, 6, 6, 2]))
      down = PokeAccess::I18n.t(:dir_down)
      swept = PokeAccess::I18n.t(:loc_swept_leg, :dir => down)
      assert_equal [swept, PokeAccess::Routes::Text.leg(6, 3), PokeAccess::Routes::Text.leg(2, 1)].join(", "), said
    end
  end

  private

  # Runs the block on rows, the events, the grid and avoid_trainers put back after.
  def rooms(rows = ROOMS)
    $game_map.load_grid(rows)
    PokeAccess::Pathfinder.invalidate_cache(true)
    yield
  ensure
    PokeAccess::Config.avoid_trainers = false
    World.clear_events
    $game_map.clear_grid
  end

  # A drawn watcher at (x,y) facing d that walks through, named name, its page started by event touch: moving the player
  # by codes with Through when the player stands ahead of it, then turning on its self switch A, which an autorun page
  # turns off at once unless reset is false; list replaces the page's commands.
  def current(x, y, d, name, codes, reset = true, list = nil)
    ahead = { 2 => "$game_player.y>#{y}", 4 => "$game_player.x<#{x}", 6 => "$game_player.x>#{x}", 8 => "$game_player.y<#{y}" }
    list ||= [TestCmd.new(111, [12, ahead[d]]), World.move_player(codes, 1), TestCmd.new(0, [], 1), TestCmd.new(412, []),
              TestCmd.new(123, ["A", 0]), TestCmd.new(0, [])]
    pages = [TestPage.new(:trigger => 2, :sprite => "current", :direction => d, :through => true, :list => list)]
    if reset
      pages.push(TestPage.new(:trigger => 3, :condition => { :self_switch_valid => true, :self_switch_ch => "A" },
                              :list => [TestCmd.new(123, ["A", 1]), TestCmd.new(0, [])]))
    end
    id = $game_map.events.length + 1
    ev = TestGameEvent.new(:id => id, :x => x, :y => y, :name => name, :pages => pages)
    ev.direction = d
    ev.through = true
    $game_map.events[id] = ev
    PokeAccess::Pathfinder.invalidate_cache(true)
    ev
  end
end
