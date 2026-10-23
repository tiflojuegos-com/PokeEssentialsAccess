# A ledge is hopped from its high side only: routes take the hop at its cost, the regions, the list's hiding and its
# walk order cross it, a hop lands only where the engine lets the player land, and the guides say the jump.
class LedgePathfindingTest < PokeAccessTest
  Moves = PokeAccess::Routes::Moves
  # A downward ledge at (3, 2) in a walled row: the player at (3, 1) gets to the bottom only by the hop.
  SEALED_DOWN_HIGH = ["#######", "#..@..#", "###.###", "#..T..#", "#######"]
  # The same map with the player below the ledge.
  SEALED_DOWN_LOW = ["#######", "#..T..#", "###.###", "#..@..#", "#######"]
  # The sealed ledge with an open floor below it and no event.
  OPEN_LANDING = ["#######", "#..@..#", "###.###", "#.....#", "#######"]
  # Two presses right from (1, 1), then the hop down the ledge at (3, 2) beside a target at (4, 3).
  WALK_THEN_HOP = ["#######", "#@....#", "###.###", "#...T.#", "#######"]
  # The player below the ledge at (3, 2): a person right above it, past the ledge, and one four tiles along their row.
  BELOW_TWO = ["#########", "#..N....#", "###.#####", "#..@...N#", "#########"]

  # A player whose engine refuses a step into the tile they stand on, as every engine does.
  class OwnTileRefusedPlayer < Game_Player
    def passable?(x, y, d)
      dl = PokeAccess::DIR_DELTA[d] || [0, 0]
      return false if x + dl[0] == @x && y + dl[1] == @y
      super
    end
  end

  test "a route crosses a ledge from its high side, the hop one press" do
    ledge_grid(SEALED_DOWN_HIGH)
    assert_equal [2], walk_route(3, 3)
  end

  test "asked again on the unchanged map, the route takes the hop as before" do
    ledge_grid(SEALED_DOWN_HIGH)
    assert_equal [[2], [2]], [walk_route(3, 3), walk_route(3, 3)]
  end

  test "a hop is taken where walking around is longer" do
    ledge_grid(["#########", "#...@...#", "#.##.##.#", "#.......#", "#########"], [[4, 2, 2]])
    assert_equal [2], walk_route(4, 3), "one press over the ledge, not eight around it"
  end

  test "a hop is taken on a map that holds a bridge as well, in a game with no terrain rules" do
    ledge_grid(["#########", "#..@....#", "###.#####", "#.......#", "#########"])
    $game_map.place_bridge(6, 3)
    PokeAccess::World.reset!
    assert_equal [2], without_terrain_rules { walk_route(3, 3) }
  end

  test "no route climbs back over a ledge from its low side" do
    ledge_grid(SEALED_DOWN_LOW)
    assert_nil walk_route(3, 1)
  end

  test "the regions reach the landing past a ledge, never the ledge tile itself" do
    ledge_grid(SEALED_DOWN_HIGH)
    assert_equal [true, false], [reached?(3, 3), reached?(3, 2)]
  end

  test "from a ledge's low side the regions do not reach its high side" do
    ledge_grid(SEALED_DOWN_LOW)
    assert_equal false, reached?(3, 1)
  end

  test "while hiding the unreachable, the list keeps a target past a ledge and hides one walled in" do
    ledge_grid(["#########", "#..@..#N#", "###.#####", "#..N....#", "#########"])
    PokeAccess::Config.hide_unreachable = :unreachable
    assert_equal [[3, 3]], listed_tiles
  end

  test "while hiding the unreachable, from below a ledge with no target to get to, the list keeps them all" do
    ledge_grid(SEALED_DOWN_LOW)
    PokeAccess::Config.hide_unreachable = :unreachable
    assert_equal [[3, 1]], listed_tiles, "taken as the regions misreading the map"
  end

  test "in the walk order a person past a ledge the player cannot climb comes after one they walk to, though nearer" do
    ledge_grid(BELOW_TWO)
    { :walk => [[7, 3], [3, 1]], :near => [[3, 1], [7, 3]] }.each do |order, want|
      PokeAccess::Config.target_order = order
      assert_equal want, listed_tiles, "in the #{order} order"
    end
  end

  test "a hop lands two tiles on, a jump of one press" do
    ledge_grid(OPEN_LANDING)
    hop = press(3, 1, 2)
    assert_equal [3, 3, :jump, 1, false], [hop.x, hop.y, hop.kind, hop.presses, hop.warp]
  end

  test "a hop onto a landing someone stands on goes nowhere, though a step out of the landing is open" do
    ledge_grid(OPEN_LANDING)
    World.event(:kind => :npc, :id => 97, :x => 3, :y => 3).blocking = true
    PokeAccess::Pathfinder.invalidate_cache(true)
    assert_nil press(3, 1, 2), "the engine lands no one on someone"
    assert_equal [3, 3], PokeAccess::World::Probe.landing(3, 3), "where a step out of it would have taken the player"
  end

  test "a hop toward the tile the player stands on lands, asked from the hop's origin, and the player is put back" do
    ledge_grid(OPEN_LANDING)
    as_player(OwnTileRefusedPlayer.new, 3, 3, 8) do
      hop = press(3, 1, 2)
      assert_equal [3, 3, :jump], [hop.x, hop.y, hop.kind], "the hop lands on the player's own tile"
      assert_equal [3, 3, 8], [$game_player.x, $game_player.y, $game_player.direction], "where the player stands as before"
    end
  end

  test "a hop onto a transfer pad lands where the pad sends the player, as a transfer" do
    ledge_grid(OPEN_LANDING)
    pad_at_landing
    hop = press(3, 1, 2)
    assert_equal [[1, 3], true, :warp], [hop.tile, hop.warp, hop.kind]
  end

  test "a step along the floor above the pad is a one-tile walk, no transfer" do
    ledge_grid(OPEN_LANDING)
    pad_at_landing
    walk = press(1, 1, 6)
    assert_equal [[2, 1], false, :walk], [walk.tile, walk.warp, walk.kind]
  end

  test "the cane says the jump ahead where the route hops a ledge, queued" do
    ledge_grid(SEALED_DOWN_HIGH)
    with_guide_state do |loc|
      guide_aim(loc, $game_map.events[1])
      SpeakCapture.clear
      guide_frame
      assert_equal [[jump_down, false]], SpeakCapture.log
    end
  end

  test "the jump is said once where it takes off, not at every frame" do
    ledge_grid(SEALED_DOWN_HIGH)
    with_guide_state do |loc|
      guide_aim(loc, $game_map.events[1])
      guide_frame
      SpeakCapture.clear
      guide_frame
      assert_nothing_spoken
    end
  end

  test "the cane says nothing of a route that only walks" do
    ledge_grid(["######", "#@..T#", "######"], [])
    with_guide_state do |loc|
      guide_aim(loc, $game_map.events[1])
      SpeakCapture.clear
      guide_frame
      assert_nothing_spoken
    end
  end

  test "the step guide's jump, a leg of its own, cuts its own stale leg, the leg past the hop left for the landing" do
    ledge_grid(WALK_THEN_HOP)
    with_guide_state do |loc|
      steps_aim(loc, $game_map.events[1])
      guide_frame
      assert_equal [], walk_to(loc, 2, 1), "a count falling as the player walks it stays silent"
      walk_to(loc, 3, 1)
      assert_equal [[jump_down, true]], SpeakCapture.log
    end
  end

  test "the step guide's jump queues behind a line said since its last leg" do
    ledge_grid(WALK_THEN_HOP)
    with_guide_state do |loc|
      steps_aim(loc, $game_map.events[1])
      guide_frame
      walk_to(loc, 2, 1)
      PokeAccess.speak("Hola", true)
      walk_to(loc, 3, 1)
      assert_equal [[jump_down, false]], SpeakCapture.log
    end
  end

  private

  # Loads rows with the ledges given as [x, y, direction hopped] (by default the down ledge at (3, 2)), the world read
  # afresh.
  def ledge_grid(rows, ledges = [[3, 2, 2]])
    hpa_fresh_grid(rows)
    ledges.each { |x, y, d| $game_map.place_ledge(x, y, d) }
    PokeAccess::World.reset!
  end

  # A transfer pad on the landing at (3, 3) that sends the player to (1, 3) of this map.
  def pad_at_landing
    World.touch(:id => 96, :x => 3, :y => 3, :list => [TestCmd.new(201, [0, $game_map.map_id, 1, 3])])
    PokeAccess::Pathfinder.invalidate_cache(true)
  end

  # The move a press in direction d from (x, y) makes, as a search asks it with ledge hops on; nil when it goes
  # nowhere.
  def press(x, y, d)
    PokeAccess::Pathfinder.searching { Moves.step(x, y, 0, PokeAccess::Routes::DIR_OF[d], Moves::LEDGE) }
  end

  # The tiles of the targets the locator lists under :all, the category shown put back after.
  def listed_tiles
    loc = PokeAccess::Locator
    was = loc.instance_variable_get(:@cat_id)
    loc.instance_variable_set(:@cat_id, :all)
    loc.rebuild_targets
    loc.instance_variable_get(:@targets).map { |t| [t.x, t.y] }
  ensure
    loc.instance_variable_set(:@cat_id, was)
  end

  # Runs the block with player standing in for the game's on (x, y) facing d, the game's own put back after.
  def as_player(player, x, y, d)
    was = $game_player
    player.x = x
    player.y = y
    player.direction = d
    $game_player = player
    PokeAccess::Pathfinder.invalidate_cache(true)
    yield
  ensure
    $game_player = was
    PokeAccess::Pathfinder.invalidate_cache(true)
  end

  # The jump notice for a hop down.
  def jump_down
    PokeAccess::I18n.t(:loc_jump, :dir => PokeAccess::I18n.t(:dir_down))
  end

  # The step guide's leg of n presses down.
  def leg_down(n)
    PokeAccess::I18n.t(:loc_leg, :n => n, :dir => PokeAccess::I18n.t(:dir_down))
  end
end
