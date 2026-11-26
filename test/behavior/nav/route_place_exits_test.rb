# Ways off the map that a parallel page takes as the player stands where it compares their place with a
# number (Effects.place_facet), shaped as Africanvs' roads ("$game_player.x == 56") and Perseida's sea ("y > 54"): the
# tiles of that line send the player off as they arrive, the list has one exit per map they lead to, and the way to it
# ends with the press onto the line.
class RoutePlaceExitsTest < PokeAccessTest
  Effects = PokeAccess::Routes::Effects
  Loc = PokeAccess::Locator
  # A field the player walks across, the player at (1, 1).
  FIELD = ["##########",
           "#@.......#",
           "#........#",
           "##########"]

  test "a column a parallel page watches sends the player off from each of its tiles, as the engine runs it" do
    field do
      watcher([TestCmd.new(111, [12, "$game_player.x == 7"]), TestCmd.new(201, [0, 99, 1, 1, 0, 0], 1),
               TestCmd.new(0, [], 1), TestCmd.new(412, [])])
      exit = { 2 => [:exit], 4 => [:exit], 6 => [:exit], 8 => [:exit] }
      assert_equal [true, exit, :place, 99], Effects.touch_index[PokeAccess::Routes.pkey(7, 2)]
      assert_equal({ 99 => [[7, 0], [7, 1], [7, 2], [7, 3]] }, Effects.place_exits)
      assert_nil Effects.touch_index[PokeAccess::Routes.pkey(6, 2)]
      refute reached?(8, 1), "the field past the line is out of reach"
    end
  end

  test "the list has the way off once, named as a map edge's, on the tile the player gets to first" do
    field do
      watcher([TestCmd.new(111, [12, "$game_player.x == 7"]), TestCmd.new(201, [0, 99, 1, 1, 0, 0], 1),
               TestCmd.new(0, [], 1), TestCmd.new(412, [])])
      exits = Loc.candidates(:exits).select { |t| t.is_a?(Loc::SurfaceTarget) && t.key == :place_exit }
      assert_equal [[7, 1, 99]], exits.map { |t| [t.x, t.y, t.ref] }
      assert_equal Loc.edge_name(99), Loc.target_name(exits[0])
      plan = Loc.route_plan(exits[0])
      assert_equal [:walk, [6, 6, 6, 6, 6, 6]], [plan.kind, plan.route.to_a], "the last press steps onto the line"
    end
  end

  test "a page that compares past a number watches the row next to it" do
    field do
      watcher([TestCmd.new(111, [12, "$game_player.y > 1"]), TestCmd.new(355, ["Kernel.pbTransferSurfing(98,2,3)"], 1),
               TestCmd.new(0, [], 1), TestCmd.new(412, [])])
      assert_equal [[98, (0..9).map { |x| [x, 2] }]], Effects.place_exits.to_a
      assert_nil Effects.touch_index[PokeAccess::Routes.pkey(3, 1)]
    end
  end

  test "a page that keeps the player's place in a variable and compares it watches that column" do
    field do
      watcher([TestCmd.new(122, [10, 10, 0, 6, -1, 0]), TestCmd.new(111, [1, 10, 0, 7, 0]),
               TestCmd.new(201, [0, 99, 1, 1, 0, 0], 1), TestCmd.new(0, [], 1), TestCmd.new(412, [])])
      assert_equal [99], Effects.place_exits.keys
      assert_equal [:exit], Effects.touch_index[PokeAccess::Routes.pkey(7, 1)][1][6]
    end
  end

  test "a parallel page that transfers wherever the player stands is no place, and one within the map no exit" do
    field do
      watcher([TestCmd.new(111, [1, 5, 0, 0, 0]), TestCmd.new(201, [0, 99, 1, 1, 0, 0], 1), TestCmd.new(0, [], 1),
               TestCmd.new(412, []), TestCmd.new(111, [12, "$game_player.x == 7"]),
               TestCmd.new(201, [0, 98, 1, 1, 0, 0], 1), TestCmd.new(0, [], 1), TestCmd.new(412, [])])
      assert_equal({}, Effects.place_exits, "a cutscene that sends the player off first, wherever they stand")
      World.clear_events
      watcher([TestCmd.new(111, [12, "$game_player.x == 7"]), TestCmd.new(201, [0, $game_map.map_id, 8, 1, 0, 0], 1),
               TestCmd.new(0, [], 1), TestCmd.new(412, [])])
      assert_equal [:warp, 8, 1], Effects.touch_index[PokeAccess::Routes.pkey(7, 2)][1][2]
      assert_equal({}, Effects.place_exits)
      assert reached?(8, 1), "the line takes the player across"
    end
  end

  test "a page that looks once where the player came in is no place: an autorun, or one that erases itself" do
    field do
      look = [TestCmd.new(111, [12, "$game_player.x <= 3"]), TestCmd.new(201, [0, 99, 1, 1, 0, 0], 1),
              TestCmd.new(0, [], 1), TestCmd.new(412, [])]
      watcher(look, 3)
      assert_equal({}, Effects.place_exits, "an autorun page")
      World.clear_events
      watcher(look + [TestCmd.new(116, [])])
      assert_equal({}, Effects.place_exits, "a parallel page that erases itself")
    end
  end

  private

  # Runs the block on rows, the events and the grid dropped after.
  def field(rows = FIELD)
    $game_map.load_grid(rows)
    PokeAccess::Pathfinder.invalidate_cache(true)
    yield
  ensure
    World.clear_events
    $game_map.clear_grid
  end

  # A parallel page (or one of trigger) with no sprite on (2, 2) running list.
  def watcher(list, trigger = 4)
    World.touch(:id => 70, :x => 2, :y => 2, :trigger => trigger, :list => list)
    PokeAccess::Pathfinder.invalidate_cache(true)
  end
end
