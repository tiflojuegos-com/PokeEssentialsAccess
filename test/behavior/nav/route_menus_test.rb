# Touch pages that open a menu whose options move the player (Effects::Menu), shaped as the real ones: Rejuvenation's
# "Floor?" lifts, Infinite Fusion's gap jumped with an item, Eternal Emerald's bike rails and Awakening's drop. Every
# option is a move of its own, the route takes the one it needs and says it; a menu that moves no one is no way.
class RouteMenusTest < PokeAccessTest
  Moves = PokeAccess::Routes::Moves
  Effects = PokeAccess::Routes::Effects
  Planner = PokeAccess::Routes::Planner
  Text = PokeAccess::Routes::Text
  # Three rooms a wall apart, the player in the first; a lift on (3, 1).
  ROOMS = ["###########",
           "#@..#..#..#",
           "#...#..#..#",
           "###########"]

  test "a lift with one floor joins two rooms, and the route says the floor to choose" do
    rooms do
      lift(3, 1, ["Sewer Depths"], [[6, 2]])
      assert reached?(6, 1), "the regions reach the room past the wall"
      route = walk_route(5, 2, true)
      assert_equal [6, 6, 4], route.to_a
      assert_equal({ 1 => 0 }, route.choices)
      kinds = Moves.one_way(1, 1, 0, route)
      assert_equal [nil, [:choice, "Sewer Depths"], nil], kinds
      assert_includes Text.steps(route, kinds), choose(:dir_right, "Sewer Depths")
    end
  end

  test "a lift with several floors takes the one the target is on, and the replay follows the choice" do
    rooms do
      lift(3, 1, ["Floor 3", "Top Floor", "Nevermind."], [[5, 1], [8, 1], nil])
      route = walk_route(9, 2, true)
      assert_equal({ 1 => 1 }, route.choices)
      assert_equal [5, 1], traced(1, 1, 0, route.to_a.first(2)).last.tile, "unpicked, the first floor that goes"
      assert_equal [9, 2], Moves.trace(1, 1, 0, route, PokeAccess::Pathfinder.replay_mode).last.tile
      assert_equal [:choice, "Top Floor"], Moves.one_way(1, 1, 0, route)[1]
      assert reached?(5, 2), "the other floor counts too"
    end
  end

  test "an option that leaves the player on the lift keeps it a tile to cross, with its choice told" do
    rooms(["#######",
           "#@....#",
           "#######"]) do
      lift(3, 1, ["Floor 3", "Nevermind."], [[1, 1], nil])
      route = walk_route(5, 1, true)
      assert_equal [6, 6, 6, 6], route.to_a
      assert_equal [nil, [:choice, "Nevermind."], nil, nil], Moves.one_way(1, 1, 0, route)
    end
  end

  test "the gap is jumped with the item and stays shut without it" do
    rooms(["#########",
           "#@...#..#",
           "#########"]) do
      gap(4, 1)
      refute_equal :found, Planner.walk(7, 1, true).status, "no item, no jump"
      with_bag([:WAILMERPAIL]) do
        PokeAccess::Pathfinder.invalidate_cache(true)
        route = walk_route(7, 1, true)
        assert_equal [6, 6, 6], route.to_a
        assert_equal [nil, nil, [:choice, "Yes"]], Moves.one_way(1, 1, 0, route)
        assert_equal [7, 1], Moves.trace(1, 1, 0, route, PokeAccess::Pathfinder.replay_mode).last.tile
        refute Moves.jump?(3, 1, 6), "the press onto the gap is told by its choice"
      end
    end
  end

  test "a bike rail's options each carry the player on from where its first stretch leaves them" do
    rooms(["#########",
           "#@......#",
           "#.......#",
           "#.......#",
           "#.......#",
           "#########"]) do
      rail(3, 1)
      PokeAccess::Pathfinder.invalidate_cache(true)
      opts = Effects.touch_at(3, 1, 6, true).options
      assert_equal [[0, "Left", [:carry, -2, 3]], [1, "Down", [:carry, 0, 3]]],
                   opts.map { |k, text, e| [k, text, e[0, 3]] }
      s = PokeAccess::Pathfinder.searching { Moves.step(2, 1, 0, PokeAccess::Routes::DIR_OF[6], Moves::LEDGE) }
      assert_equal [[1, 4, [0, "Left"]], [3, 4, [1, "Down"]]], ([s] + s.alts).map { |a| [a.x, a.y, a.choice] }
      assert reached?(1, 4)
      assert reached?(3, 4)
    end
  end

  test "a drop asked for falls the player to the floor below, and its no steps them back" do
    rooms(["######",
           "#@...#",
           "##.###",
           "######",
           "#....#",
           "######"]) do
      drop(2, 2)
      route = walk_route(3, 4)
      assert route, "the floor below can be got to"
      assert_equal [:choice, "Sí"], Moves.one_way(1, 1, 0, route).compact.first
    end
  end

  test "a door that asks first is gone through with its yes, and its no leaves the player on it" do
    rooms(["#######",
           "#@....#",
           "#######"]) do
      ask = [TestCmd.new(101, ["Leave the cave?"]), TestCmd.new(102, [["Yes", "No"], 2]), TestCmd.new(402, [0, "Yes"]),
             TestCmd.new(201, [0, 99, 1, 1, 0, 0], 1), TestCmd.new(0, [], 1), TestCmd.new(402, [1, "No"]),
             TestCmd.new(0, [], 1), TestCmd.new(404, [])]
      World.touch(:id => 66, :x => 3, :y => 1, :list => ask)
      PokeAccess::Pathfinder.invalidate_cache(true)
      e = Effects.touch_at(3, 1, 6, true)
      assert_equal [[:exit], [[0, "Yes", [:exit]], [1, "No", nil]]], [e.to_a, e.options]
      plan = Planner.plan(3, 1)
      assert_equal [6, 6], plan.route.to_a, "the way to the door ends with the press into it"
      assert_equal [nil, [:choice, "Yes"]], Moves.one_way(1, 1, 0, plan.route)
      route = walk_route(5, 1, true)
      assert_equal [6, 6, 6, 6], route.to_a
      assert_equal [:choice, "No"], Moves.one_way(1, 1, 0, route)[1]
    end
  end

  test "the press through a door that asks first takes its way out whatever place the menu gives it" do
    rooms(["#######",
           "#@....#",
           "#######"]) do
      ask = [TestCmd.new(101, ["Leave the cave?"]), TestCmd.new(102, [["No", "Yes"], 1]), TestCmd.new(402, [0, "No"]),
             TestCmd.new(0, [], 1), TestCmd.new(402, [1, "Yes"]), TestCmd.new(201, [0, 99, 1, 1, 0, 0], 1),
             TestCmd.new(0, [], 1), TestCmd.new(404, [])]
      World.touch(:id => 69, :x => 3, :y => 1, :list => ask)
      PokeAccess::Pathfinder.invalidate_cache(true)
      plan = Planner.plan(3, 1)
      assert_equal [6, 6], plan.route.to_a
      assert_equal [nil, [:choice, "Yes"]], Moves.one_way(1, 1, 0, plan.route)
      assert_equal [:choice, "No"], Moves.one_way(1, 1, 0, walk_route(5, 1, true))[1], "crossing it, its no"
    end
  end

  test "an option that sets something or fights leaves the player on the tile, as before such menus were read" do
    rooms(["#######",
           "#@....#",
           "#######"]) do
      gift = [TestCmd.new(101, ["Do you want to take Turtwig?"]), TestCmd.new(102, [["Yes", "No"], 2]),
              TestCmd.new(402, [0, "Yes"]), TestCmd.new(355, ["pbAddPokemon(:TURTWIG, 5)"], 1),
              TestCmd.new(121, [162, 162, 0], 1), TestCmd.new(0, [], 1), TestCmd.new(402, [1, "No"]),
              World.move_player([13], 1), TestCmd.new(0, [], 1), TestCmd.new(404, [])]
      World.touch(:id => 67, :x => 3, :y => 1, :list => gift)
      PokeAccess::Pathfinder.invalidate_cache(true)
      route = walk_route(5, 1, true)
      assert_equal [6, 6, 6, 6], route.to_a
      assert_equal [:choice, "Yes"], Moves.one_way(1, 1, 0, route)[1]
    end
  end

  test "an option that walks the player on in a cutscene that sets something is no carry" do
    rooms(["#######",
           "#@....#",
           "#######"]) do
      scene = [TestCmd.new(101, ["Ready?"]), TestCmd.new(102, [["Yes", "No"], 2]), TestCmd.new(402, [0, "Yes"]),
               World.move_player([3, 3], 1), TestCmd.new(123, ["A", 0], 1), TestCmd.new(0, [], 1),
               TestCmd.new(402, [1, "No"]), World.move_player([13], 1), TestCmd.new(0, [], 1), TestCmd.new(404, [])]
      World.touch(:id => 68, :x => 3, :y => 1, :list => scene)
      PokeAccess::Pathfinder.invalidate_cache(true)
      e = Effects.touch_at(3, 1, 6, true)
      assert_equal [[0, "Yes", nil], [1, "No", [:carry, -1, 0]]], e.options.map { |k, t, o| [k, t, o && o[0, 3]] }
    end
  end

  test "a menu whose options move no one leaves the tile as it was" do
    rooms(["#######",
           "#@....#",
           "#######"]) do
      shop = [TestCmd.new(101, ["Welcome!"]), TestCmd.new(102, [["Buy", "Sell"], 2]), TestCmd.new(402, [0, "Buy"]),
              TestCmd.new(355, ["pbPokemonMart([:POTION])"], 1), TestCmd.new(0, [], 1), TestCmd.new(402, [1, "Sell"]),
              TestCmd.new(0, [], 1), TestCmd.new(404, [])]
      World.touch(:id => 60, :x => 3, :y => 1, :list => shop)
      PokeAccess::Pathfinder.invalidate_cache(true)
      assert_nil Effects.touch_at(3, 1, 6, true)
      assert_equal [6, 6, 6, 6], walk_route(5, 1, true).to_a
    end
  end

  test "a message's own menu is read as one, its options in its words" do
    rooms do
      teleport = [TestCmd.new(101, ["Where would you like to go?\\ch[1,-1,Orange,Cancel]"]),
                  TestCmd.new(111, [1, 1, 0, 0, 0]), TestCmd.new(201, [0, $game_map.map_id, 6, 2], 1),
                  TestCmd.new(0, [], 1), TestCmd.new(412, [])]
      World.touch(:id => 61, :x => 3, :y => 1, :list => teleport)
      PokeAccess::Pathfinder.invalidate_cache(true)
      e = Effects.touch_at(3, 1, 6, true)
      assert_equal [[:warp, 6, 2], [[0, "Orange", [:warp, 6, 2]], [1, "Cancel", nil]]], [e.to_a, e.options]
    end
  end

  test "walked with the action button a menu still answers yes, and a pick takes the option asked for" do
    rooms do
      ev = lift(3, 1, ["Floor 3", "Top Floor"], [[5, 1], [8, 1]])
      assert_equal [$game_map.map_id, 5, 1], PokeAccess::EventPages.outcome(ev, 6, nil, true).transfer
      assert_equal [$game_map.map_id, 8, 1], PokeAccess::EventPages.outcome(ev, 6, nil, false, 1).transfer
      o = PokeAccess::EventPages.outcome(ev, 6)
      assert_equal [true, [[0, "Floor 3"], [1, "Top Floor"]]], [o.unknown, o.menu]
    end
  end

  private

  # Runs the block on rows, the events and the grid dropped after.
  def rooms(rows = ROOMS)
    $game_map.load_grid(rows)
    PokeAccess::Pathfinder.invalidate_cache(true)
    yield
  ensure
    World.clear_events
    $game_map.clear_grid
  end

  # A lift on (x,y) as Rejuvenation's: no sprite, "Floor?" and a menu of names, each option a transfer within the map
  # to its spot of spots, or nothing for nil.
  def lift(x, y, names, spots)
    list = [TestCmd.new(101, ["Floor? "]), TestCmd.new(102, [names, 0])]
    names.each_with_index do |n, k|
      list.push(TestCmd.new(402, [k, n]))
      list.push(TestCmd.new(201, [0, $game_map.map_id, spots[k][0], spots[k][1]], 1)) if spots[k]
      list.push(TestCmd.new(0, [], 1))
    end
    list.push(TestCmd.new(404, []))
    ev = World.touch(:id => 62, :x => x, :y => y, :list => list)
    PokeAccess::Pathfinder.invalidate_cache(true)
    ev
  end

  # Infinite Fusion's gap on (x,y): with the item, "Yes" steps the player on with Through and jumps them two on.
  def gap(x, y)
    list = [TestCmd.new(111, [12, "$PokemonBag.pbQuantity(:WAILMERPAIL)>=1"]),
            TestCmd.new(101, ["Use the Wailmer Pail?"], 1), TestCmd.new(102, [["Yes", "No"], 2], 1),
            TestCmd.new(402, [0, "Yes"], 1), World.move_player([37, 3, 38], 2), World.move_player([[14, [2, 0]]], 2),
            TestCmd.new(0, [], 2), TestCmd.new(402, [1, "No"], 1), TestCmd.new(0, [], 2), TestCmd.new(404, [], 1),
            TestCmd.new(0, [], 1), TestCmd.new(412, [])]
    World.touch(:id => 63, :x => x, :y => y, :list => list)
    PokeAccess::Pathfinder.invalidate_cache(true)
  end

  # Eternal Emerald's rail on (x,y): two tiles down with Through, then "Left" one down and two left, or "Down" one
  # down.
  def rail(x, y)
    list = [World.move_player([37, 1, 1, 38]), TestCmd.new(210, []), TestCmd.new(101, ["Will you go Left or Down?"]),
            TestCmd.new(102, [["Left", "Down"], 2]), TestCmd.new(402, [0, "Left"]),
            World.move_player([37, 1, 2, 2, 38], 1), TestCmd.new(210, [], 1), TestCmd.new(0, [], 1),
            TestCmd.new(402, [1, "Down"]), World.move_player([37, 1, 38], 1), TestCmd.new(210, [], 1),
            TestCmd.new(0, [], 1), TestCmd.new(404, [])]
    World.touch(:id => 64, :x => x, :y => y, :list => list)
  end

  # Awakening's drop on (x,y): "Sí" falls the player two tiles down with Through, "No" steps them back.
  def drop(x, y)
    list = [TestCmd.new(101, ["¿Me dejo caer?"]), TestCmd.new(102, [["Sí", "No"], 2]), TestCmd.new(402, [0, "Sí"]),
            World.move_player([37, 1, 1, 38], 1), TestCmd.new(210, [], 1), TestCmd.new(0, [], 1),
            TestCmd.new(402, [1, "No"]), World.move_player([13], 1), TestCmd.new(0, [], 1), TestCmd.new(404, [])]
    World.touch(:id => 65, :x => x, :y => y, :list => list)
    PokeAccess::Pathfinder.invalidate_cache(true)
  end

  # Runs the block with a bag holding just these items.
  def with_bag(items)
    was = $PokemonBag
    $PokemonBag = Object.new
    $PokemonBag.define_singleton_method(:pbQuantity) { |it| items.include?(it) ? 1 : 0 }
    yield
  ensure
    $PokemonBag = was
  end

  # A leg of n presses toward the direction of dir_key, as said.
  def leg(n, dir_key)
    PokeAccess::I18n.t(:loc_leg, :n => n, :dir => PokeAccess::I18n.t(dir_key))
  end

  # The press onto a menu toward dir_key choosing option, as said.
  def choose(dir_key, option)
    PokeAccess::I18n.t(:loc_choose_leg, :dir => PokeAccess::I18n.t(dir_key), :option => option)
  end
end
