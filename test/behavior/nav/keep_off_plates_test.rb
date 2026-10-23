# A walk on foot keeps off the tiles where a step would change the map's puzzle (Routes::Controls.keep_off): the
# plates a wall reads, as Pokemon Z's third gym has them, and a floor grid's cells while a letter is formed on it, as
# in its Santuario. With no way around, a route crosses a plate only while its press leaves the rest of the route
# open; the presses a controls route plans never walk across a plate they do not press.
class KeepOffPlatesTest < PokeAccessTest
  OPEN = ["#########",
          "#@......#",
          "#.#####.#",
          "#.......#",
          "#########"]

  test "a walk goes round a plate whose press would bring a wall back across its way" do
    gym(OPEN) do
      r = walk(7, 1)
      assert_equal [:found, [2, 2, 6, 6, 6, 6, 6, 6, 8, 8]], [r.status, r.route.to_a]
    end
  end

  test "with no way round, a route a plate would close is no walk" do
    gym(["#########", "#@......#", "#########"]) do
      assert_equal :exhausted, walk(7, 1).status
    end
  end

  test "with no way round, a plate whose press leaves the rest open is crossed" do
    gym(["#########", "#@......#", "#########"], 0) do
      r = walk(7, 1)
      assert_equal [:found, [6, 6, 6, 6, 6, 6]], [r.status, r.route.to_a]
    end
  end

  test "a walk keeps off a floor grid's cells only while a letter is formed on it" do
    active = false
    grid(lambda { active }) do
      assert_equal [6, 6, 6, 6], walk(5, 1).route.to_a
      active = true
      assert_equal [2, 6, 6, 6, 6, 8], walk(5, 1).route.to_a
    end
  end

  test "an assisted route counts no presses past its obstacle when a plate on the way to it brings a wall back" do
    gym(["#########", "#@......#", "#########"]) do
      World.event(:kind => :npc, :id => 80, :x => 4, :y => 1, :name => "Tree").blocking = true
      PokeAccess::Pathfinder.invalidate_cache(true)
      head, gate = PokeAccess::Routes::Planner.assisted(7, 1)
      assert_equal [[6, 6], :loc_cut_tree, nil], [head.to_a, gate[:label], gate[:after]],
                   "the plate at (3,1) brings the rays at (5,1) back across the way past the tree"
    end
  end

  test "the floor read for presses is entered at a plate but never walked past it" do
    floor = { 1 => [[2, 0, 0]], 2 => [[3, 0, 0]], 3 => [] }
    reach = PokeAccess::Routes::Controls.region(floor, 1, {}, { 2 => true })
    assert_equal [1, 2], reach.keys.sort
  end

  private

  def walk(x, y)
    PokeAccess::Routes::Planner.walk(x, y, true)
  end

  # Lays the rows out with switch 144 on: a plate at (3,1) writing it to value (1 off, 0 on), and rays at (5,1) drawn
  # while it is off, gone now; the mechanic of Z's gym declared over them.
  def gym(rows, value = 1)
    $game_map.load_grid(rows)
    $game_switches[144] = true
    plate = TestPage.new(:trigger => 1, :sprite => "", :list => [TestCmd.new(121, [144, 144, value])])
    $game_map.events[43] = TestGameEvent.new(:id => 43, :x => 3, :y => 1, :pages => [plate])
    rays = [TestPage.new(:trigger => 0, :sprite => "rayosR"),
            TestPage.new(:trigger => 0, :sprite => "", :condition => { :switch1_valid => true, :switch1_id => 144 })]
    $game_map.events[20] = TestGameEvent.new(:id => 20, :x => 5, :y => 1, :pages => rays)
    declare(:kind => :state,
      :watch => [{ :switch => 144, :label => :gym3_red, :on => :gym3_on, :off => :gym3_off }], :controls => true,
      :obstacles => [{ :match => /rayos/i, :kind => :wall }])
    settle
    yield
  ensure
    tidy
  end

  # Lays a room out with one grid cell at (3,1) on the straight way, active as the call says.
  def grid(active)
    $game_map.load_grid(["#######", "#@....#", "#.....#", "#######"])
    declare(:kind => :grid, :cols => 1, :rows => 1,
      :cells => [[3, 1]], :lit => lambda { |_i| false }, :active => active, :target => lambda { nil },
      :solved => lambda { false })
    settle
    yield
  ensure
    tidy
  end

  # Declares the room's mechanic on the test map, the profile's declarations kept aside for tidy.
  def declare(spec)
    @defs ||= PokeAccess::World::Mechanics.instance_variable_get(:@defs).dup
    PokeAccess::World::Mechanics.declare($game_map.map_id, spec)
  end

  # Drops the instance and the route cache over the declaration just made.
  def settle
    PokeAccess::World::Mechanics.forget
    PokeAccess::Pathfinder.invalidate_cache(true)
  end

  def tidy
    $game_switches[144] = false
    PokeAccess::World::Mechanics.instance_variable_set(:@defs, @defs) if @defs
    PokeAccess::World::Mechanics.forget
    PokeAccess::World::Mechanics::Links.forget
    World.clear_events
    $game_map.clear_grid
  end
end
