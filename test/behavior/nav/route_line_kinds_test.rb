# The route key's line says the presses that cannot be undone the same way by what they do, as the step guide does
# ("jump right", "slide right"), and, for an assisted route, what to do at its obstacle, from the tile the route ends
# on, and how many presses are left past it with their hops and slides, only when nothing more stands in the way.

class RouteLineKindsTest < PokeAccessTest
  ICE = 12
  RIGHT = 6
  Text = PokeAccess::Routes::Text

  test "says a ledge hop and a slide by what they do" do
    on_row("#@.......#") do |loc|
      $game_map.place_ledge(3, 1, RIGHT)
      [5, 6].each { |x| $game_map.set_terrain(x, 1, ICE) }
      PokeAccess::Pathfinder.invalidate_cache(true)
      legs = [t(:loc_leg, :n => 1, :dir => t(:dir_right)), Text.jump(RIGHT), t(:loc_slide_leg, :dir => t(:dir_right))]
      assert_equal [t(:loc_route, :steps => legs.join(", "))], route_key(loc, 8, 1)
    end
  end

  test "ends an assisted route with what to do at its obstacle and the presses left past it" do
    on_row("#@.......#") do |loc|
      tree(4)
      gate = loc.route_plan(chest(7, 1)).gate
      steps = "#{Text.steps([6, 6])}; #{Text.hold(gate, 3, 1)}; #{t(:loc_route_after, :n => 3)}"
      assert_equal [t(:loc_route_gate, :what => Text.gate_what(gate), :steps => steps)], route_key(loc, 7, 1)
    end
  end

  test "says what to do at the obstacle from the tile the route ends on, not from the player's" do
    on_grid(["#######", "#....##", "####.##", "#@...##", "#######"]) do |loc|
      tree(4, 2)
      gate = loc.route_plan(chest(1, 1)).gate
      refute_equal Text.hold(gate, 1, 3), Text.hold(gate, 4, 3), "the tree is to the player's right, above the end"
      steps = "#{Text.steps([6, 6, 6])}; #{Text.hold(gate, 4, 3)}; #{t(:loc_route_after, :n => 4)}"
      assert_equal [t(:loc_route_gate, :what => Text.gate_what(gate), :steps => steps)], route_key(loc, 1, 1)
    end
  end

  test "counts a ledge hop among the presses left past the obstacle" do
    on_row("#@.......#") do |loc|
      tree(3)
      $game_map.place_ledge(5, 1, RIGHT)
      PokeAccess::Pathfinder.invalidate_cache(true)
      gate = loc.route_plan(chest(8, 1)).gate
      after = "#{t(:loc_route_after, :n => 4)}, #{t(:loc_with, :what => t(:loc_a_jump))}"
      steps = "#{Text.steps([6])}; #{Text.hold(gate, 2, 1)}; #{after}"
      assert_equal [t(:loc_route_gate, :what => Text.gate_what(gate), :steps => steps)], route_key(loc, 8, 1)
    end
  end

  test "counts the slides past the obstacle with its hops, both told together" do
    on_row("#@...........#") do |loc|
      tree(3)
      $game_map.place_ledge(5, 1, RIGHT)
      [7, 8].each { |x| $game_map.set_terrain(x, 1, ICE) }
      PokeAccess::Pathfinder.invalidate_cache(true)
      gate = loc.route_plan(chest(12, 1)).gate
      note = t(:loc_with, :what => Text.and_list([t(:loc_a_jump), t(:loc_a_slide)]))
      steps = "#{Text.steps([6])}; #{Text.hold(gate, 2, 1)}; #{t(:loc_route_after, :n => 6)}, #{note}"
      assert_equal [t(:loc_route_gate, :what => Text.gate_what(gate), :steps => steps)], route_key(loc, 12, 1)
    end
  end

  test "says nothing of the way past an obstacle when a second one stands on it" do
    on_row("#@.......#") do |loc|
      tree(3)
      tree(5, 1, 81)
      gate = loc.route_plan(chest(8, 1)).gate
      steps = "#{Text.steps([6])}; #{Text.hold(gate, 2, 1)}"
      assert_equal [t(:loc_route_gate, :what => Text.gate_what(gate), :steps => steps)], route_key(loc, 8, 1)
    end
  end

  private

  # A text of the mod's.
  def t(key, args = {}); PokeAccess::I18n.t(key, args); end

  # A spot target on (x, y), as the locator selects it.
  def chest(x, y)
    PokeAccess::Locator::SurfaceTarget.new(x, y, "cofre", :spot)
  end

  # A blocking event named Tree on (x, y), event id, which an assisted route cuts.
  def tree(x, y = 1, id = 80)
    World.event(:kind => :npc, :id => id, :x => x, :y => y, :name => "Tree").blocking = true
    PokeAccess::Pathfinder.invalidate_cache(true)
  end

  # A corridor row between two walls, the player on '@', laid out for the block (on_grid).
  def on_row(row, &blk)
    wall = "#" * row.length
    on_grid([wall, row, wall], &blk)
  end

  # Rows laid out, the player on '@', for the block, given the locator; its target, the events, the ledges and the
  # grid put back after.
  def on_grid(rows)
    loc = PokeAccess::Locator
    saved = loc.instance_variable_get(:@target)
    $game_map.load_grid(rows)
    yield loc
  ensure
    loc.instance_variable_set(:@target, saved)
    World.clear_events
    $game_map.clear_ledges
    $game_map.clear_grid
  end

  # What the route key says with a spot on (x, y) selected.
  def route_key(loc, x, y)
    loc.instance_variable_set(:@target, chest(x, y))
    loc.instance_variable_set(:@targets_stale, false)
    SpeakCapture.clear
    loc.announce_route
    SpeakCapture.lines
  end
end
