# A field-move obstacle in the way (a tree to cut, a rock to smash): an assisted search sets it aside, out of the probe's
# memo; the route runs up to it, the step guide holds there naming it, the target list and route key say what blocks.
class RouteGatesTest < PokeAccessTest
  test "an assisted search asks the engine anew for each step onto an obstacle, once for any other" do
    tree_corridor
    asked = counting_asks do
      gates_open do
        2.times { PokeAccess::World::Probe.step?(1, 1, 6) }
        2.times { PokeAccess::World::Probe.step?(2, 1, 6) }
      end
    end
    assert_equal({ [1, 1, 6] => 1, [2, 1, 6] => 2 }, asked, "[x, y, d] => times the engine was asked")
  end

  test "an assisted search sets an obstacle of several tiles aside over its whole area" do
    tree_corridor("CutTree size(2,1)")
    asked = counting_asks do
      gates_open do
        [[5, 1, 4], [2, 1, 6], [1, 1, 6]].each { |x, y, d| 2.times { PokeAccess::World::Probe.step?(x, y, d) } }
      end
    end
    assert_equal({ [5, 1, 4] => 2, [2, 1, 6] => 2, [1, 1, 6] => 1 }, asked, "[x, y, d] => times the engine was asked")
  end

  test "an obstacle closes the way to a route on foot" do
    tree_corridor
    assert_nil walk_route(5, 1)
  end

  test "the regions on foot take the obstacle for a wall, so a second walk past it is told without a search" do
    tree_corridor
    PokeAccess::Routes::Planner.walk(5, 1)
    again = PokeAccess::Routes::Planner.walk(5, 1)
    assert_equal [:exhausted, 0, :regions], [again.status, again.expanded, again.algo]
  end

  test "the assisted route runs up to the obstacle and names it, the move that clears it, its tile and the way past" do
    { "Tree" => [:loc_cut_tree, :CUT], "Rock" => [:loc_rock_smash, :ROCKSMASH] }.each do |name, (label, move)|
      ev = tree_corridor(name)
      gate = { :kind => :field, :label => label, :move => move, :item => nil, :ev => ev, :x => 3, :y => 1,
               :after => 2 }
      assert_equal [[6], gate], PokeAccess::Routes::Planner.assisted(5, 1), "an event named #{name}"
    end
  end

  test "an object no field move clears is no obstacle an assisted search sets aside" do
    tree_corridor("Headbutt tree")
    assert_nil PokeAccess::Routes::Planner.assisted(5, 1)
  end

  test "an assisted search leaves the obstacle standing in the way" do
    tree = tree_corridor
    PokeAccess::Routes::Planner.assisted(5, 1)
    assert_nil tree.through, "its through is put back as it was"
    assert_nil walk_route(5, 1), "so it still closes the way on foot"
  end

  test "the target list says what blocks the way and the move that clears it" do
    tree_corridor
    blocked = PokeAccess::I18n.t(:loc_gate_route, :what => PokeAccess::I18n.t(:loc_cut_tree), :move => cut_name)
    assert_equal [nil, ", " + blocked], PokeAccess::Locator.route_phrase(chest)
  end

  test "the target list says the move is needed once nobody can use it, as the step guide does" do
    tree_corridor
    needed = PokeAccess::I18n.t(:loc_gate_route_need, :what => PokeAccess::I18n.t(:loc_cut_tree), :move => cut_name)
    with_nobody_knowing_moves do
      assert_equal [nil, ", " + needed], PokeAccess::Locator.route_phrase(chest)
    end
  end

  test "beside the obstacle the step guide names it and its move once, and stays on" do
    tree_corridor
    loc = PokeAccess::Locator
    steps_aim(loc, chest)
    assert_equal [gate_line(:loc_gate_use)], walk_to(loc, 2, 1), "it names the tree and the move"
    assert_equal true, PokeAccess::Guide.on?(:steps), "the step guide stays on"
    assert_equal [], walk_to(loc, 2, 1), "said once on the tile"
  end

  test "beside the obstacle, once nobody can use its move, the step guide says on the same tile that it is needed" do
    tree_corridor
    loc = PokeAccess::Locator
    steps_aim(loc, chest)
    walk_to(loc, 2, 1)
    with_nobody_knowing_moves do
      assert_equal [gate_line(:loc_gate_need)], walk_to(loc, 2, 1), "a new line on the tile is said"
    end
  end

  test "once the obstacle is cut down, the step guide goes on with the route on foot" do
    tree = tree_corridor
    loc = PokeAccess::Locator
    steps_aim(loc, chest)
    walk_to(loc, 2, 1)
    tree.blocking = false
    PokeAccess::Pathfinder.invalidate_cache(true)
    PokeAccess::Guide.event_ended
    assert_equal [PokeAccess::I18n.t(:loc_leg, :n => 2, :dir => PokeAccess::I18n.t(:dir_right))], walk_to(loc, 2, 1)
  end

  test "the step guide says the leg up to the obstacle before it" do
    tree_corridor
    loc = PokeAccess::Locator
    steps_aim(loc, chest)
    assert_equal [PokeAccess::I18n.t(:loc_leg, :n => 1, :dir => PokeAccess::I18n.t(:dir_right))], walk_to(loc, 1, 1)
  end

  test "the route key says the way up to the obstacle, what it is and the way past it" do
    tree_corridor
    with_selected(chest) do |loc|
      SpeakCapture.clear
      loc.announce_route
      assert_equal [[route_line(loc.route_plan(chest).gate), true]], SpeakCapture.log
    end
  end

  test "with route stats on, the route key adds how its search went" do
    tree_corridor
    PokeAccess::Config.route_stats = true
    t = PokeAccess::I18n
    with_selected(chest) do |loc|
      SpeakCapture.clear
      loc.announce_route
      ms = t.number(loc.route_plan(chest).stats[:ms])
      stats = t.t(:route_stats, :algo => t.t(:algo_astar), :n => 2, :ms => ms)
      assert_equal [["#{route_line(loc.route_plan(chest).gate)}. #{stats}", true]], SpeakCapture.log, "A* examined the two tiles short of the tree"
    end
  end

  test "one obstacle and a longer way round beat several in a row" do
    $game_map.load_grid(["#########",
                         "#.......#",
                         "#.#####.#",
                         "#.#####.#",
                         "#@......#",
                         "#########"])
    trees = [[3, 4], [4, 4], [5, 4], [7, 3]].each_with_index.map do |(x, y), i|
      tree = World.event(:kind => :npc, :id => 81 + i, :x => x, :y => y, :name => "Tree")
      tree.blocking = true
      tree
    end
    gate = { :kind => :field, :label => :loc_cut_tree, :move => :CUT, :item => nil, :ev => trees[3], :x => 7, :y => 3,
             :after => 2 }
    assert_equal [[8, 8, 8, 6, 6, 6, 6, 6, 6, 2], gate], PokeAccess::Routes::Planner.assisted(6, 4),
                 "round the top to the one tree at (7, 3), not through the three in a row"
  end

  private

  # A corridor closed at (3, 1) by a blocking event named name (a tree by default), the player at (1, 1); the event.
  def tree_corridor(name = "Tree")
    $game_map.load_grid(["#######",
                         "#@....#",
                         "#######"])
    tree = World.event(:kind => :npc, :id => 80, :x => 3, :y => 1, :name => name)
    tree.blocking = true
    tree
  end

  # The spot at the corridor's far end, past the tree.
  def chest
    PokeAccess::Locator::SurfaceTarget.new(5, 1, "cofre", :spot)
  end

  # Cut's name as the game spells it.
  def cut_name
    PokeAccess::FieldMoves.name(:CUT)
  end

  # What the step guide says beside the tree, to its right, with key (use the move, or it is needed).
  def gate_line(key)
    PokeAccess::I18n.t(key, :what => PokeAccess::I18n.t(:loc_cut_tree), :dir => PokeAccess::I18n.t(:side_right),
                            :move => cut_name)
  end

  # The route key's line for the way up to the tree, one step right, what to do beside it (gate's) and the presses
  # left past it, two.
  def route_line(gate)
    t = PokeAccess::I18n
    hold = PokeAccess::Routes::Text.hold(gate, 2, 1)
    steps = "#{t.t(:loc_leg, :n => 1, :dir => t.t(:dir_right))}; #{hold}; #{t.t(:loc_route_after, :n => 2)}"
    t.t(:loc_route_gate, :what => t.t(:loc_cut_tree), :steps => steps)
  end

  # Runs the block as an assisted search does, the obstacles set aside.
  def gates_open(&blk)
    PokeAccess::Pathfinder.with_gates_open { PokeAccess::Pathfinder.searching(&blk) }
  end

  # The engine's passability questions while the block runs, as { [x, y, d] => times asked }; the map's own answers
  # given.
  def counting_asks
    asked = Hash.new(0)
    own = $game_map.method(:passable?)
    $game_map.define_singleton_method(:passable?) do |x, y, d|
      asked[[x, y, d]] += 1
      own.call(x, y, d)
    end
    yield
    asked
  ensure
    $game_map.singleton_class.send(:remove_method, :passable?)
  end

  # Runs the block with no Pokemon of the party knowing any move.
  def with_nobody_knowing_moves
    tr = PokeAccess::Engine.player
    def tr.get_pokemon_with_move(_move); nil; end
    yield
  ensure
    tr.singleton_class.send(:remove_method, :get_pokemon_with_move)
  end

  # Runs the block with target selected and the target list taken as current; the block gets the locator.
  def with_selected(target)
    loc = PokeAccess::Locator
    stale = loc.instance_variable_get(:@targets_stale)
    loc.instance_variable_set(:@target, target)
    loc.instance_variable_set(:@targets_stale, false)
    yield loc
  ensure
    loc.instance_variable_set(:@targets_stale, stale)
  end
end
