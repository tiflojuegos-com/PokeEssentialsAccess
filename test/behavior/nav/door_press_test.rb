# The press through a doorway at the end of a route: a touch event that takes the player off the map or to another
# spot of it, walked onto or bumped into, the route ending with that press from a tile it is taken from, as the route
# key, the target list, the free camera, an assisted route and the step guide say it.
class DoorPressTest < PokeAccessTest
  Locator = PokeAccess::Locator
  Planner = PokeAccess::Routes::Planner

  test "the route to a doorway ends with the press through it, from afar and from beside it" do
    door = corridor_door
    assert_equal [:walk, [6, 6, 6, 6]], plan_of(door), "three presses to the tile beside it, then the one into it"
    assert_equal [route_said(leg(4, :dir_right))], route_key(door)
    $game_player.x = 4
    assert_equal [route_said(leg(1, :dir_right))], route_key(door), "beside it, the press into it"
  end

  test "the press through a doorway turns where the doorway lies across the last tile" do
    door = niche_door
    assert_equal [:walk, [6, 6, 8, 8]], plan_of(door)
    assert_equal [route_said("#{leg(2, :dir_right)}, #{leg(2, :dir_up)}")], route_key(door)
  end

  test "the target list counts the press through a doorway among the steps" do
    door = corridor_door
    assert_equal [[6, 6, 6, 6], ", #{PokeAccess::I18n.t(:loc_steps, :n => 4)}"], Locator.route_phrase(door)
  end

  test "a door drawn with a sprite stands in the way and is bumped into, the route ending with that press" do
    door = corridor_door(:sprite => "door")
    door.blocking = true
    PokeAccess::Pathfinder.invalidate_cache(true)
    refute PokeAccess::Routes::Effects.fires_on_arrival?(door), "it fires on a bump"
    assert_equal [:walk, [6, 6, 6, 6]], plan_of(door)
    $game_player.x = 4
    assert_equal [route_said(leg(1, :dir_right))], route_key(door)
  end

  test "someone behind a counter who takes the player elsewhere is still got to across the counter, with no press" do
    $game_map.load_grid(["#######",
                         "#..C..#",
                         "#@.C..#",
                         "#######"])
    guide = World.touch(:id => 64, :x => 4, :y => 2, :trigger => 2, :sprite => "npc", :list => [leave_map])
    guide.blocking = true
    PokeAccess::Pathfinder.invalidate_cache(true)
    assert_includes Planner.doorways(4, 2), [2, 2], "the tile across the counter"
    assert_equal [:walk, [6]], plan_of(guide), "to the counter, the action button across it"
  end

  test "the press through a doorway ends a way found past someone walking about in the corridor" do
    door = corridor_door
    walker = World.event(:id => 65, :x => 3, :y => 1, :sprite => "npc")
    walker.blocking = true
    PokeAccess::Pathfinder.invalidate_cache(true)
    route = swapping(PokeAccess::Routes::Regions, :lendable_walkers, proc { [walker] }) do
      swapping(Planner, :reach, proc { |*_a| [:yes, 0] }) { plan_of(door) }
    end
    assert_equal [:walk, [6, 6, 6, 6]], route, "through the walker lent, then into the doorway"
  end

  test "a doorway its tile lets in from above and below alone is gone through from one of those sides" do
    door = middle_door
    $game_map.block_step(2, 2, 6)
    $game_map.block_step(4, 2, 4)
    PokeAccess::Pathfinder.invalidate_cache(true)
    assert_equal [[3, 1], [3, 3]], Planner.doorways(3, 2).sort, "the tiles it is gone through from"
    kind, route = plan_of(door)
    assert_equal :walk, kind
    assert_includes [[8, 6, 2], [2, 6, 8]], route, "round to above or below it, then into it"
  end

  test "the way to stairs gone through from the side runs straight into them, its turn taken before the last leg" do
    $game_map.load_grid(["#########",
                         "#.....@.#",
                         "#.......#",
                         "#.......#",
                         "#########"])
    door = World.touch(:id => 60, :x => 3, :y => 2, :list => [leave_map])
    $game_map.block_step(3, 1, 2)
    $game_map.block_step(3, 3, 8)
    PokeAccess::Pathfinder.invalidate_cache(true)
    [:regions, :astar, :dijkstra].each do |algo|
      PokeAccess::Config.path_algorithm = algo
      Planner.forget
      assert_equal [:walk, [2, 4, 4, 4]], plan_of(door), "down, then left into them (#{algo})"
    end
    PokeAccess::Config.astar_max = 1
    Planner.forget
    assert_equal [:walk, [2, 4, 4, 4]], plan_of(door), "the flood that answers past the search's budget too"
    assert_equal :flood, Locator.route_plan(door).stats[:algo]
  end

  test "a doorway its page opens to one facing alone is gone through by that facing, never from beside it" do
    door = middle_door([World.if_facing(8), leave_map(1), World.end_])
    assert_equal [[3, 3]], Planner.doorways(3, 2)
    kind, route = plan_of(door)
    assert_equal :walk, kind
    assert_includes [[2, 6, 8], [6, 2, 8]], route, "below it, across its tile or round it, then up into it"
  end

  test "a door to another room of the map ends with its press, the route landing past it" do
    $game_map.load_grid(["#########",
                         "#@..#...#",
                         "#########"])
    pad = World.touch(:id => 61, :x => 3, :y => 1, :list => [TestCmd.new(201, [0, $game_map.map_id, 6, 1])])
    PokeAccess::Pathfinder.invalidate_cache(true)
    kind, route = plan_of(pad)
    assert_equal [:walk, [6, 6]], [kind, route]
    assert_equal [6, 1], traced(1, 1, 0, route).last.tile, "the press onto it lands across the wall"
    assert_equal [], Locator.route_plan(pad).route.warps, "its own press is no transfer on the way"
  end

  test "the free camera's route to a doorway ends with the press through it, and is none on the doorway itself" do
    corridor_door
    assert_equal [6, 6, 6], Planner.plan_from(2, 1, 0, 5, 1).route.to_a
    assert_equal [6], Planner.plan_from(4, 1, 0, 5, 1).route.to_a
    assert_equal [:walk, []], [Planner.plan_from(5, 1, 0, 5, 1).kind, Planner.plan_from(5, 1, 0, 5, 1).route.to_a]
  end

  test "the presses left past an obstacle on the way to a doorway count the press through it" do
    corridor_door
    tree = World.event(:kind => :npc, :id => 80, :x => 3, :y => 1, :name => "Tree")
    tree.blocking = true
    PokeAccess::Pathfinder.invalidate_cache(true)
    steps, gate = Planner.assisted(5, 1)
    assert_equal [[6], :loc_cut_tree, 3], [steps.to_a, gate[:label], gate[:after]]
  end

  test "an action-button door and a person beside the player are next to it, with no press to say" do
    $game_map.load_grid(["#######",
                         "#.....#",
                         "#.....#",
                         "#######"])
    $game_player.x = 3
    $game_player.y = 2
    door = World.touch(:id => 62, :x => 4, :y => 2, :trigger => 0, :sprite => "doors1", :list => [leave_map])
    trainer = World.event(:kind => :npc, :id => 63, :x => 3, :y => 1, :name => "Trainer")
    next_to = route_said(PokeAccess::I18n.t(:loc_next_to))
    assert Locator.transfer_event?(door), "the door is a door"
    assert_equal [[next_to], [next_to]], [route_key(door), route_key(trainer)]
  end

  test "the step guide says the press through a doorway, and holds it beside the doorway without planning again" do
    with_guide_state do |loc|
      door = niche_door
      steps_aim(loc, door)
      assert_equal [leg(2, :dir_right)], walk_to(loc, 1, 3)
      walk_to(loc, 2, 3)
      assert_equal [leg(2, :dir_up)], walk_to(loc, 3, 3)
      assert_equal [], walk_to(loc, 3, 2), "beside it, the count falling to its press"
      assert PokeAccess::Guide.replays?(nil), "the press into it replays as the track ends"
      assert PokeAccess::Guide.on?(:steps), "on until the press is taken"
    end
  end

  test "the step guide ends with the arrival where the press through a doorway takes the player within the map" do
    with_guide_state do |loc|
      door = niche_door([TestCmd.new(201, [1, 31, 32, 33])])
      door.name = "Door"
      steps_aim(loc, door)
      assert_equal [leg(1, :dir_up)], walk_to(loc, 3, 2), "a door to where the variables tell"
      assert_equal [PokeAccess::I18n.t(:loc_arrived)], walk_to(loc, 5, 3), "taken across the room"
      refute PokeAccess::Guide.on?
    end
  end

  test "the step guide goes on toward a doorway the player steps away from beside it" do
    with_guide_state do |loc|
      door = niche_door
      steps_aim(loc, door)
      walk_to(loc, 3, 2)
      assert_equal [leg(1, :dir_right)], walk_to(loc, 2, 2), "back beside it, then into it"
      assert PokeAccess::Guide.on?(:steps)
    end
  end

  private

  # The route key's line for steps, "Route: steps".
  def route_said(steps)
    PokeAccess::Routes::Text.route_line(steps)
  end

  # A leg as the step guide says it: n presses toward the direction of dir_key.
  def leg(n, dir_key)
    PokeAccess::I18n.t(:loc_leg, :n => n, :dir => PokeAccess::I18n.t(dir_key))
  end

  # The locator's plan for target, as [kind, presses].
  def plan_of(target)
    plan = Locator.route_plan(target)
    [plan.kind, plan.route && plan.route.to_a]
  end

  # What the route key says with target selected.
  def route_key(target)
    Locator.instance_variable_set(:@target, target)
    Locator.instance_variable_set(:@targets_stale, false)
    SpeakCapture.clear
    Locator.announce_route
    SpeakCapture.lines
  end

  # The block's value with mod's own method meth answering as body does, the method put back after.
  def swapping(mod, meth, body)
    sc = mod.singleton_class
    saved = :"door_press_saved_#{meth.to_s.delete('?!')}"
    sc.send(:alias_method, saved, meth)
    mod.define_singleton_method(meth, &body)
    yield
  ensure
    if sc && sc.method_defined?(saved)
      sc.send(:alias_method, meth, saved)
      sc.send(:remove_method, saved)
    end
  end

  # A Transfer Player command to another map.
  def leave_map(indent = 0)
    TestCmd.new(201, [0, 55, 1, 1], indent)
  end

  # A corridor ending at a doorway on (5, 1) that leaves the map (its event made with opts), the player at (1, 1).
  def corridor_door(opts = {})
    $game_map.load_grid(["#######",
                         "#@....#",
                         "#######"])
    door = World.touch({ :id => 60, :x => 5, :y => 1, :list => [leave_map] }.merge(opts))
    PokeAccess::Pathfinder.invalidate_cache(true)
    door
  end

  # A room with a doorway in a niche of its top wall on (3, 1), running list, the player at (1, 3).
  def niche_door(list = [leave_map])
    $game_map.load_grid(["#######",
                         "###.###",
                         "#.....#",
                         "#@....#",
                         "#######"])
    door = World.touch(:id => 60, :x => 3, :y => 1, :list => list)
    PokeAccess::Pathfinder.invalidate_cache(true)
    door
  end

  # A room with a doorway in its middle on (3, 2), running list, the player at (2, 2) beside it.
  def middle_door(list = [leave_map])
    $game_map.load_grid(["#######",
                         "#.....#",
                         "#.@...#",
                         "#.....#",
                         "#######"])
    door = World.touch(:id => 60, :x => 3, :y => 2, :list => list)
    PokeAccess::Pathfinder.invalidate_cache(true)
    door
  end
end
