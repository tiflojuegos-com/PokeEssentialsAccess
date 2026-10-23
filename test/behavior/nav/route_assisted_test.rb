# Assisted routes (Routes::Planner.assisted, Routes::Pushes, World::Probe.event_movable?): climbs, pushes and pulls,
# getting off the bike and Waterfall, each route cut at its first such step and said; walks see events move or turn.
class RouteAssistedTest < PokeAccessTest
  Routes = PokeAccess::Routes
  Planner = PokeAccess::Routes::Planner
  Pushes = PokeAccess::Routes::Pushes
  Text = PokeAccess::Routes::Text
  Pathfinder = PokeAccess::Pathfinder
  Probe = PokeAccess::World::Probe
  PUSH_COST = 1 + PokeAccess::Pathfinder::GATE_COST
  STATUE = "Estatua"

  CLIMB_ROWS = ['#####',
                '#...#',
                '#####',
                '#####',
                '#.@.#',
                '#####']
  CORRIDOR_ROWS = ['#######',
                   '#@....#',
                   '#######']
  GRASS_ROWS = ['######',
                '#@gg.#',
                '######']
  WATERFALL_ROWS = ['#####',
                    '#~~~#',
                    '#~V~#',
                    '##W##',
                    '##W##',
                    '#~~~#',
                    '#@###',
                    '#####']
  ALCOVE_ROWS = ['#######',
                 '#...###',
                 '#@....#',
                 '###.###',
                 '#######']
  CARRY_ROWS = ['#######',
                '###...#',
                '#.....#',
                '#######']
  CORNER_ROWS = ['#####',
                 '#@..#',
                 '###.#',
                 '###.#',
                 '#####']
  GAP_ROWS = ['#########',
              '#.......#',
              '#@......#',
              '####.####',
              '###...###',
              '#########']
  SIDE_GAP_ROWS = ['######',
                   '#.@###',
                   '#..###',
                   '#..#.#',
                   '#....#',
                   '#..#.#',
                   '#..###',
                   '#..###',
                   '######']
  HALL_ROWS = ['###################################',
               '#@...........................#....#',
               '#............................#....#',
               '#............................#....#',
               '#.................................#',
               '#............................#....#',
               '#............................#....#',
               '#............................#....#',
               '###################################']

  test "a wall climbed with the action button ends the route at its foot, facing it" do
    climb_room(CLIMB_ROWS)
    assert_nil walk_route(3, 1), "the top cannot be walked to"
    assert_equal [[], { :kind => :act, :face => 8, :x => 2, :y => 4 }], Planner.assisted(3, 1)
  end

  test "walks to the foot of a climb first, the route stopping where the button is pressed" do
    climb_room(['#####',
                '#...#',
                '#####',
                '#####',
                '#@..#',
                '#####'])
    assert_equal [[6], { :kind => :act, :face => 8, :x => 2, :y => 4 }], Planner.assisted(3, 1)
  end

  test "hops a ledge on its way to a climb" do
    $game_map.load_grid(['#######',
                         '#.....#',
                         '#######',
                         '#######',
                         '#.....#',
                         '#######',
                         '#@...##',
                         '#######'])
    $game_map.place_ledge(4, 5, 8)
    assisted_climb(90, 2, 3, [4, 4, 4])
    Pathfinder.invalidate_cache(true)
    assert_equal [[6, 6, 6, 8, 4, 4], { :kind => :act, :face => 8, :x => 2, :y => 4, :after => 2 }],
                 Planner.assisted(5, 1)
  end

  test "takes the climb's button for a move only inside an assisted search" do
    climb_room(CLIMB_ROWS)
    up = Routes::DIR_OF[8]
    step = Pathfinder.with_gates_open { Routes::Moves.step(2, 4, 0, up, Pathfinder.moves_mode(false, false)) }
    assert_equal [:assist, { :kind => :act, :face => 8, :x => 2, :y => 4 }, [2, 1]], [step.kind, step.gate, step.tile]
    assert_nil Routes::Moves.step(2, 4, 0, up, 0), "outside an assisted search it is no move"
  end

  test "the guide says to face the climb and press the action button" do
    climb_room(CLIMB_ROWS)
    assert_equal phrase(:loc_act_here, :dir => phrase(:side_up)), Text.hold(Planner.assisted(3, 1)[1], 2, 4)
  end

  test "the target list says the way is passed with the action button" do
    climb_room(CLIMB_ROWS)
    assert_equal phrase(:loc_act_route), Text.gate_route(Planner.assisted(3, 1)[1])
  end

  test "takes a climb whose page also sets a switch for a scene, not a way up" do
    $game_map.load_grid(CLIMB_ROWS)
    assisted_climb(91, 2, 3, [4, 4, 4], [TestCmd.new(121, [30, 30, 0], 1)])
    Pathfinder.invalidate_cache(true)
    assert_nil Planner.assisted(3, 1)
  end

  test "searches for an assisted route only where something could assist" do
    with_still_clock(100.0) do
      with_assist_sources([]) do
        $game_map.load_grid(['############',
                             '#@....#....#',
                             '#.....#....#',
                             '#.....#....#',
                             '############'])
        Pathfinder.invalidate_cache(true)
        PokeAccess::Config.route_limit = :time
        PokeAccess::Config.route_budget_ms = -1
        bare = Pathfinder.searching { |l| [Planner.assisted(9, 2), l.cuts] }
        assisted_boulder(97, 3, 1)
        Pathfinder.invalidate_cache(true)
        rocky = Pathfinder.searching { |l| [Planner.assisted(9, 2), l.cuts] }
        assert_equal [[nil, 0], [nil, 1]], [bare, rocky],
                     "with nothing to assist no search runs; with a boulder, the spent budget stops the one it makes"
      end
    end
  end

  test "takes a boulder, an obstacle, an action-button way, a registered step, the water or the bike for an assist" do
    { :nothing => false, :boulder => true, :tree => true, :climb => true, :registered => true, :surfing => true,
      :bike => true }.each do |what, want|
      got = with_assist_sources([]) do
        $game_map.load_grid(CORRIDOR_ROWS)
        $PokemonGlobal.surfing = what == :surfing
        $PokemonGlobal.bicycle = what == :bike
        place_assist(what)
        Pathfinder.invalidate_cache(true)
        Pathfinder.assist_possible?
      end
      assert_equal want, got, "with #{what}"
    end
  end

  test "takes a game global with no water or bike to read for no assist" do
    with_assist_sources([]) do
      $game_map.load_grid(CORRIDOR_ROWS)
      Pathfinder.invalidate_cache(true)
      assert_equal false, with_global(Object.new) { Pathfinder.assist_possible? }
    end
  end

  test "gives no assisted route to a target walked to, a boulder standing off the way" do
    $game_map.load_grid(['#######',
                         '#@....#',
                         '#.....#',
                         '#######'])
    assisted_boulder(140, 3, 2)
    Pathfinder.invalidate_cache(true)
    assert_equal [6, 6, 6], walk_route(5, 1), "the target is walked to"
    assert_nil Planner.assisted(5, 1), "no step on the way needs help, so no push search cuts it"
  end

  test "gives no assisted route to a target walked to, a climb waiting elsewhere" do
    climb_room(['#####',
                '#...#',
                '#####',
                '#####',
                '#@..#',
                '#####'])
    assert_equal [6], walk_route(3, 4), "the target is walked to"
    assert_nil Planner.assisted(3, 4), "the climb is off the way and no boulder is there to push"
  end

  test "pushes a boulder along a corridor, the route stopping beside it" do
    $game_map.load_grid(CORRIDOR_ROWS)
    rock = assisted_boulder(92, 3, 1)
    Pathfinder.invalidate_cache(true)
    assert_nil walk_route(5, 1), "the boulder closes the corridor"
    gate = { :kind => :field, :label => :loc_strength_boulder, :ev => rock, :move => :STRENGTH, :x => 3, :y => 1,
             :act => true }
    assert_equal [[6], gate], Planner.assisted(5, 1)
  end

  test "the guide says which way the boulder is and to use Strength on it" do
    said = with_strength(70) do
      $game_map.load_grid(CORRIDOR_ROWS)
      assisted_boulder(92, 3, 1)
      Pathfinder.invalidate_cache(true)
      Text.hold(Planner.assisted(5, 1)[1], 2, 1)
    end
    assert_equal phrase(:loc_gate_use, :what => phrase(:loc_strength_boulder), :dir => phrase(:side_right),
                        :move => "Mov70"), said
  end

  test "the target list says a boulder blocks the way and Strength moves it" do
    said = with_strength(70) do
      $game_map.load_grid(CORRIDOR_ROWS)
      assisted_boulder(92, 3, 1)
      Pathfinder.invalidate_cache(true)
      Text.gate_route(Planner.assisted(5, 1)[1])
    end
    assert_equal phrase(:loc_gate_route, :what => phrase(:loc_strength_boulder), :move => "Mov70"), said
  end

  test "hops a ledge on its way to a boulder" do
    $game_map.load_grid(['##########',
                         '#@.......#',
                         '##########'])
    $game_map.place_ledge(3, 1, 6)
    rock = assisted_boulder(160, 6, 1)
    Pathfinder.invalidate_cache(true)
    assert_equal [6, 6], walk_route(5, 1), "on foot the ledge is hopped"
    gate = { :kind => :field, :label => :loc_strength_boulder, :ev => rock, :move => :STRENGTH, :x => 6, :y => 1,
             :act => true }
    assert_equal [[6, 6, 6], gate], Planner.assisted(8, 1)
  end

  test "starts each push plan on a way as cheap as brute force's, and misses none, in random boulder rooms" do
    checked, bad = plans_against_brute_force(1..60, false)
    assert_operator checked, :>, 80, "push plans checked"
    assert_equal [], bad.first(5), "each first push lies on a cheapest plan, and a room with a plan gets one"
  end

  test "starts each plan of pulls and pushes on a way as cheap as brute force's, and misses none, in random statue rooms" do
    checked, bad = with_pull_scripts([/pbMoverEstatuas/]) { plans_against_brute_force(101..160, true) }
    assert_operator checked, :>, 80, "plans checked"
    assert_equal [], bad.first(5), "each first pull or push lies on a cheapest plan, and a room with a plan gets one"
  end

  test "leaves the way shut past a boulder that a wall keeps from moving" do
    $game_map.load_grid(CORNER_ROWS)
    assisted_boulder(94, 3, 1)
    Pathfinder.invalidate_cache(true)
    assert_nil Planner.assisted(3, 3)
  end

  test "pushes no boulder into another right beyond it, along a row or down a column" do
    PokeAccess::Config.puzzle_assist = true
    lines = { "a row" => [['########', '#@.....#', '########'], [2, 1], [3, 1], [6, 1]],
              "a column" => [['###', '#@#'] + ['#.#'] * 5 + ['###'], [1, 2], [1, 3], [1, 6]] }
    lines.each do |what, (rows, near, far, target)|
      $game_map.load_grid(rows)
      assisted_boulder(120, *near)
      Pathfinder.invalidate_cache(true)
      lone = Planner.assisted(*target)
      assisted_boulder(121, *far)
      Pathfinder.invalidate_cache(true)
      assert_equal [near, nil], [lone && [lone[1][:x], lone[1][:y]], Planner.assisted(*target)],
                   "along #{what}: the lone boulder is pushed, the one with another beyond it is not"
    end
  end

  test "pushes a boulder into an alcove from above rather than twice along the corridor" do
    $game_map.load_grid(ALCOVE_ROWS)
    assisted_boulder(98, 3, 2)
    Pathfinder.invalidate_cache(true)
    assert_nil walk_route(5, 2), "no route with the boulder where it is"
    route, gate = Planner.assisted(5, 2)
    assert_equal [[3, 1], 3, [3, 2]], [traced(1, 2, 0, route).last.tile, route.length, [gate[:x], gate[:y]]],
                 "three presses to stand above it, then the push down"
  end

  test "without the puzzle assist, leaves a way that needs two boulders moved to the player" do
    two_boulder_room
    assert_nil walk_route(8, 2), "the two boulders close the corridor"
    assert_nil Planner.assisted(8, 2)
  end

  test "with the puzzle assist, plans a room of boulders, starting with the first in the way" do
    two_boulder_room
    PokeAccess::Config.puzzle_assist = true
    route, gate = Planner.assisted(8, 2)
    assert_equal [[3, 1], [3, 2]], [traced(1, 2, 0, route).last.tile, [gate[:x], gate[:y]]],
                 "above the first boulder, to push it down out of the way"
  end

  test "with the puzzle assist, a route moves up to twelve boulders, and no more" do
    PokeAccess::Config.puzzle_assist = true
    got = [12, 13].map do |n|
      target = boulder_staircase(n)
      g = Planner.assisted(*target)
      g && [g[0], [g[1][:x], g[1][:y]]]
    end
    assert_equal [[[6], [3, 1]], nil], got, "twelve corners pushed clear, the first push first; thirteen are too many"
  end

  test "takes a boulder pushed into the corner of the only way on as blocking it" do
    $game_map.load_grid(CORNER_ROWS)
    assisted_boulder(99, 2, 1)
    Pathfinder.invalidate_cache(true)
    assert_nil Planner.assisted(3, 3)
  end

  test "sets the obstacles aside in a push search too, stopping at a tree before the boulder behind it" do
    $game_map.load_grid(['########',
                         '#@.....#',
                         '########'])
    tree = World.event(:kind => :npc, :id => 80, :x => 2, :y => 1, :name => "Tree")
    tree.blocking = true
    assisted_boulder(81, 4, 1)
    Pathfinder.invalidate_cache(true)
    assert_equal [[], { :kind => :field, :label => :loc_cut_tree, :move => :CUT, :item => nil, :ev => tree, :x => 2,
                        :y => 1 }],
                 Planner.assisted(6, 1)
  end

  test "counts a push search that reaches its cap as stopped short, so the plan is cut rather than none" do
    $game_map.load_grid(HALL_ROWS)
    assisted_boulder(102, 10, 4)
    assisted_boulder(103, 29, 4)
    assisted_boulder(104, 30, 4)
    Pathfinder.invalidate_cache(true)
    assert_equal :exhausted, Planner.walk(33, 4).status, "on foot the target has no way, shown to the end"
    assert_equal [nil, 1], Pathfinder.searching { |l| [Planner.assisted(33, 4), l.cuts] }, "the push search stopped"
    assert_equal :cut, Planner.plan(33, 4).kind
  end

  test "gives a target out of every assisted reach no route, with no search stopped short" do
    walled_hall
    assert_equal [nil, 0], Pathfinder.searching { |l| [Planner.assisted(33, 4), l.cuts] }
  end

  test "with edge_relax on, searches the pushes for a target the assisted regions rule out" do
    walled_hall
    PokeAccess::Config.edge_relax = true
    assert_equal [nil, 1], Pathfinder.searching { |l| [Planner.assisted(33, 4), l.cuts] }
  end

  test "a statue no game lets pull, in a gap no push clears, closes it for good" do
    with_pull_scripts([]) do
      statue_gap(GAP_ROWS, 4, 3)
      assert_nil Planner.assisted(3, 4)
    end
  end

  test "pulls a statue the game lets pull out of a gap, the route stopping above it" do
    with_pull_scripts([/pbMoverEstatuas/]) do
      st = statue_gap(GAP_ROWS, 4, 3)
      assert_nil walk_route(3, 4), "the statue closes the gap"
      assert_equal [[6, 6, 6], { :kind => :pull, :label => :loc_pushable, :ev => st, :face => 2, :x => 4, :y => 3 }],
                   Planner.assisted(3, 4)
    end
  end

  test "pulls a statue sideways out of a gap in a wall" do
    with_pull_scripts([/pbMoverEstatuas/]) do
      st = statue_gap(SIDE_GAP_ROWS, 3, 4)
      assert_equal [[2, 2, 2], { :kind => :pull, :label => :loc_pushable, :ev => st, :face => 6, :x => 3, :y => 4 }],
                   Planner.assisted(4, 3)
    end
  end

  test "the guide says to pull the statue facing it, naming it as the locator does" do
    with_pull_scripts([/pbMoverEstatuas/]) do
      statue_gap(GAP_ROWS, 4, 3)
      assert_equal phrase(:loc_gate_pull, :what => STATUE, :dir => phrase(:side_down), :toward => phrase(:toward_up)),
                   Text.hold(Planner.assisted(3, 4)[1], 4, 2)
    end
  end

  test "the guide says a statue is pulled the way opposite to it, toward the player" do
    with_pull_scripts([/pbMoverEstatuas/]) do
      statue_gap(SIDE_GAP_ROWS, 3, 4)
      said = Text.hold(Planner.assisted(4, 3)[1], 2, 4)
      assert_equal phrase(:loc_gate_pull, :what => STATUE, :dir => phrase(:side_right), :toward => phrase(:toward_left)),
                   said
      assert_includes said, phrase(:toward_left), "the statue on the right comes left, toward the player"
    end
  end

  test "the target list says the statue blocks the way and can be pulled" do
    with_pull_scripts([/pbMoverEstatuas/]) do
      statue_gap(GAP_ROWS, 4, 3)
      assert_equal phrase(:loc_gate_route_pull, :what => STATUE), Text.gate_route(Planner.assisted(3, 4)[1])
    end
  end

  test "never pulls a statue walked into, which turning toward it pushes" do
    with_pull_scripts([/pbMoverEstatuas/]) do
      statue_gap(GAP_ROWS, 4, 3, 1)
      assert_nil Planner.assisted(3, 4)
    end
  end

  test "pulls no statue with a boulder where the player would step back" do
    with_pull_scripts([/pbMoverEstatuas/]) do
      statue_gap(GAP_ROWS, 4, 3)
      assisted_boulder(142, 4, 1)
      Pathfinder.invalidate_cache(true)
      assert_nil Planner.assisted(3, 4)
    end
  end

  test "pushes a pullable statue into an alcove rather than pulling it aside a press dearer" do
    with_pull_scripts([/pbMoverEstatuas/]) do
      $game_map.load_grid(ALCOVE_ROWS)
      st = pull_statue(117, 3, 2)
      Pathfinder.invalidate_cache(true)
      gate = { :kind => :field, :label => :loc_pushable, :ev => st, :move => nil, :x => 3, :y => 2, :act => true }
      assert_equal [[6, 8, 6], gate], Planner.assisted(5, 2), "above it, then the push down"
    end
  end

  test "prices a pull as a push to the press, carrying a statue by two pulls or by two pushes and the step between" do
    with_pull_scripts([/pbMoverEstatuas/]) do
      { [4, 1] => [[4, 2], :pull], [5, 1] => [[2], :field] }.each do |(px, py), want|
        plan = Planner.carry(carry_room(px, py), [2, 2, 2, 2])
        assert_equal want, [plan.route, plan.gate[:kind]],
                     "from (#{px}, #{py}): pulls if both sides are as near, pushes if theirs is two presses nearer"
      end
    end
  end

  test "pulls no statue where the player cannot step back, a wall or the statue's own check in the way" do
    with_pull_scripts([/pbMoverEstatuas/]) do
      walled = GAP_ROWS.dup
      walled[1] = '#...#...#'
      { "a wall" => [walled, false], "a floor event" => [GAP_ROWS, true] }.each do |what, (rows, plate)|
        statue_gap(rows, 4, 3)
        World.event(:kind => :npc, :id => 144, :x => 4, :y => 1, :name => "Plate").blocking = false if plate
        Pathfinder.invalidate_cache(true)
        assert_nil Planner.assisted(3, 4), "with #{what} behind the player"
      end
    end
  end

  test "pulls no statue onto a floor event its own check keeps it off" do
    with_pull_scripts([/pbMoverEstatuas/]) do
      statue_gap(GAP_ROWS, 4, 3)
      World.event(:kind => :npc, :id => 143, :x => 4, :y => 2, :name => "Plate").blocking = false
      Pathfinder.invalidate_cache(true)
      assert_equal [6, 6, 6], walk_route(4, 2, true), "the player stands on the plate to pull"
      assert_nil Planner.assisted(3, 4)
    end
  end

  test "pushes an action-button statue along a corridor, the route stopping beside it" do
    st = statue_corridor(0)
    gate = { :kind => :field, :label => :loc_pushable, :ev => st, :move => nil, :x => 3, :y => 1, :act => true }
    assert_equal [[6], gate], Planner.assisted(6, 1)
  end

  test "the guide says to hold the way toward an action-button statue and press the button" do
    statue_corridor(0)
    assert_equal phrase(:loc_gate_push_act, :what => STATUE, :dir => phrase(:side_right),
                                            :toward => phrase(:toward_right)),
                 Text.hold(Planner.assisted(6, 1)[1], 2, 1)
  end

  test "the guide says to walk into a statue pushed by walking" do
    statue_corridor(1)
    assert_equal phrase(:loc_gate_push, :what => STATUE, :dir => phrase(:side_right), :toward => phrase(:toward_right)),
                 Text.hold(Planner.assisted(6, 1)[1], 2, 1)
  end

  test "the target list says a pushable blocks the way and can be pushed" do
    statue_corridor(1)
    assert_equal phrase(:loc_gate_route_push, :what => STATUE), Text.gate_route(Planner.assisted(6, 1)[1])
  end

  test "to act on the end of a corridor, pushes the statue in it along" do
    $game_map.load_grid(CORRIDOR_ROWS)
    st = pull_statue(116, 3, 1, 1)
    Pathfinder.invalidate_cache(true)
    gate = { :kind => :field, :label => :loc_pushable, :ev => st, :move => nil, :x => 3, :y => 1 }
    assert_equal [[6], gate], Planner.assisted(5, 1)
  end

  test "to stand on the end of a corridor, finds no way where the statue pushed along would end up there" do
    $game_map.load_grid(CORRIDOR_ROWS)
    pull_statue(116, 3, 1, 1)
    Pathfinder.invalidate_cache(true)
    assert_nil Planner.assisted(5, 1, true)
  end

  test "riding into tall grass, the route stops to get off the bike, facing the way on" do
    with_tile_world(GRASS_ROWS) do
      $PokemonGlobal.bicycle = true
      assert_nil walk_route(4, 1), "riding, the grass closes the way"
      assert_equal [[], { :kind => :dismount, :face => 6, :x => 1, :y => 1 }], Planner.assisted(4, 1),
                   "the way on, replayed on the bike, gets off it again on the next grass: no count of what is left"
    end
  end

  test "the guide says to get off the bike and go on toward the grass" do
    with_tile_world(GRASS_ROWS) do
      $PokemonGlobal.bicycle = true
      assert_equal phrase(:loc_dismount_here, :dir => phrase(:side_right)), Text.hold(Planner.assisted(4, 1)[1], 1, 1)
    end
  end

  test "the target list says the player has to get off the bike" do
    with_tile_world(GRASS_ROWS) do
      $PokemonGlobal.bicycle = true
      assert_equal phrase(:loc_dismount_route), Text.gate_route(Planner.assisted(4, 1)[1])
    end
  end

  test "planning a dismount leaves the player on the bike" do
    with_tile_world(GRASS_ROWS) do
      $PokemonGlobal.bicycle = true
      Planner.assisted(4, 1)
      assert_equal true, $PokemonGlobal.bicycle
    end
  end

  test "on a map that never lets the player off the bike, gives no dismount route" do
    with_tile_world(GRASS_ROWS) do
      $PokemonGlobal.bicycle = true
      with_bike_only_map { assert_nil Planner.assisted(4, 1) }
    end
  end

  test "afloat above a waterfall, one press down its crest drops to the pool below" do
    with_tile_world(WATERFALL_ROWS) do
      $PokemonGlobal.surfing = true
      $game_player.x = 2
      $game_player.y = 1
      assert_equal [2], walk_route(1, 5)
      assert_equal [[2, 5, 0]], spots(traced(2, 1, 0, [2])), "landing below the fall"
    end
  end

  test "below a waterfall, the route climbs it with Waterfall from where the player floats" do
    with_tile_world(WATERFALL_ROWS) do
      below_waterfall
      assert_nil walk_route(1, 1), "it cannot be swum up"
      assert_equal [[], { :kind => :field, :label => :surf_waterfall, :move => :WATERFALL, :x => 2, :y => 4 }],
                   Planner.assisted(1, 1)
    end
  end

  test "the guide says to use Waterfall up the fall" do
    said = with_move_id(:WATERFALL, 127) do
      with_tile_world(WATERFALL_ROWS) do
        below_waterfall
        Text.hold(Planner.assisted(1, 1)[1], 2, 5)
      end
    end
    assert_equal phrase(:loc_gate_use, :what => phrase(:surf_waterfall), :dir => phrase(:side_up), :move => "Mov127"),
                 said
  end

  test "a character in a corridor closes it, opens it stepping aside and closes it stepping back, no event ending" do
    $game_map.load_grid(['#######',
                         '#@....#',
                         '###.###',
                         '#######'])
    npc = World.touch(:id => 93, :x => 3, :y => 1, :trigger => 0, :sprite => "npc", :list => [TestCmd.new(101, ["Hola"])])
    npc.blocking = true
    Pathfinder.invalidate_cache(true)
    standing = walk_route(5, 1)
    npc.y = 2
    aside = walk_route(5, 1)
    npc.y = 1
    assert_equal [nil, [6, 6, 6], nil], [standing, aside, walk_route(5, 1)]
  end

  test "a walk asked again on foot crosses the grass the bike could not, with nothing invalidated" do
    with_tile_world(GRASS_ROWS) do
      $PokemonGlobal.bicycle = true
      riding = walk_route(4, 1)
      $PokemonGlobal.bicycle = false
      assert_equal [nil, [6, 6]], [riding, walk_route(4, 1)]
    end
  end

  test "an event gone through opens the corridor for the next search, and solid again closes it" do
    $game_map.load_grid(CORRIDOR_ROWS)
    wall = World.touch(:id => 96, :x => 3, :y => 1, :trigger => 0, :sprite => "rock", :list => [TestCmd.new(101, ["..."])])
    wall.blocking = true
    Pathfinder.invalidate_cache(true)
    solid = walk_route(5, 1)
    wall.through = true
    through = walk_route(5, 1)
    wall.through = false
    assert_equal [nil, [6, 6, 6], nil], [solid, through, walk_route(5, 1)]
  end

  test "a warp pad whose page turns to one that does nothing is no way across for the next search" do
    $game_map.load_grid(['########',
                         '#@.#...#',
                         '########'])
    pad = World.touch(:id => 97, :x => 2, :y => 1, :list => [TestCmd.new(201, [0, $game_map.map_id, 5, 1])])
    Pathfinder.invalidate_cache(true)
    warping = walk_route(6, 1)
    quiet = TestPage.new(:trigger => 1, :sprite => "", :list => [TestCmd.new(0, [])])
    [:@active, :@page].each { |iv| pad.instance_variable_set(iv, quiet) }
    pad.instance_variable_set(:@list, quiet.list)
    assert_equal [[6], nil], [warping, walk_route(6, 1)]
  end

  test "a push asks the event by the check its engine gives it, from the tile it is asked from" do
    modern = Object.new
    def modern.can_move_in_direction?(_d, _strict); true; end
    def modern.passable?(x, y, d, strict); [x, y, d, strict] == [3, 1, 6, true]; end
    gen6 = Object.new
    def gen6.passableStrict?(x, y, d); [x, y, d] == [3, 1, 2]; end
    plain = Object.new
    def plain.passable?(x, y, d); [x, y, d] == [3, 1, 8]; end
    { [:modern, 3, 1, 6] => true, [:modern, 3, 1, 4] => false, [:modern, 4, 1, 6] => false,
      [:gen6, 3, 1, 2] => true, [:gen6, 3, 1, 8] => false,
      [:plain, 3, 1, 8] => true, [:plain, 4, 1, 8] => false }.each do |(kind, x, y, d), want|
      ev = { :modern => modern, :gen6 => gen6, :plain => plain }[kind]
      assert_equal want, Probe.event_movable?(ev, x, y, d), "#{kind} event from (#{x}, #{y}) toward #{d}"
    end
  end

  test "asks a boulder a search made through as solid, and leaves it through after" do
    $game_map.load_grid(['#####',
                         '#@..#',
                         '#####'])
    rock = assisted_boulder(99, 3, 1)
    rock.through = true
    assert_equal [false, true], [Probe.event_movable?(rock, 3, 1, 6), rock.through]
  end

  test "takes an event whose check raises for one that does not move, and puts it back as it was" do
    ev = TestGameEvent.new(:id => 122, :x => 3, :y => 1)
    ev.through = true
    ev.define_singleton_method(:passableStrict?) { |_x, _y, _d| raise "broken" }
    assert_equal [false, true, false], [Probe.event_movable?(ev, 3, 1, 6), ev.through, Probe.quiet?]
  end

  test "keeps the probe quiet while it asks an event, and not once answered" do
    ev = TestGameEvent.new(:id => 121, :x => 3, :y => 1)
    heard = []
    ev.define_singleton_method(:passableStrict?) { |_x, _y, _d| heard.push(PokeAccess::World::Probe.quiet?) }
    Probe.event_movable?(ev, 3, 1, 6)
    assert_equal [[true], false], [heard, Probe.quiet?]
  end

  test "asks an event with it and the player where the search has them, both put back after" do
    $game_map.load_grid(CORRIDOR_ROWS)
    ev = TestGameEvent.new(:id => 123, :x => 3, :y => 1)
    seen = []
    ev.define_singleton_method(:passableStrict?) do |_x, _y, _d|
      seen.push([x, y, $game_player.x, $game_player.y])
      true
    end
    Probe.event_movable?(ev, 4, 2, 6, [4, 2, 2, 3])
    assert_equal [[[4, 2, 2, 3]], [3, 1, 1, 1]], [seen, [ev.x, ev.y, $game_player.x, $game_player.y]]
  end

  test "refuses a statue where the player's or its own tile is in its way, not once the search has moved them" do
    $game_map.load_grid(CORRIDOR_ROWS)
    st = pull_statue(110, 3, 1)
    { [2, 1, nil] => false, [2, 1, [2, 1, 4, 1]] => true,
      [4, 1, nil] => false, [4, 1, [4, 1, 5, 1]] => true }.each do |(x, y, stand), want|
      assert_equal want, Probe.event_movable?(st, x, y, 4, stand), "from (#{x}, #{y}) standing #{stand.inspect}"
    end
    assert_equal [3, 1, 1, 1], [st.x, st.y, $game_player.x, $game_player.y], "both put back"
  end

  test "planning a push leaves the boulders as solid as they were" do
    $game_map.load_grid(CORRIDOR_ROWS)
    rock = assisted_boulder(92, 3, 1)
    rock.through = false
    Pathfinder.invalidate_cache(true)
    Planner.assisted(5, 1)
    assert_equal false, rock.through
  end

  test "lending no events lends nothing" do
    assert_equal false, Probe.lend_through([]) { Probe.lending? }
  end

  test "names the tiles lent, sorted, a nested lending adding to the outer one's until it ends" do
    a = TestGameEvent.new(:id => 150, :x => 4, :y => 2)
    b = TestGameEvent.new(:id => 151, :x => 2, :y => 3)
    seen = Probe.lend_through([a]) do
      [Probe.lent_tiles, Probe.lend_through([b]) { Probe.lent_tiles }, Probe.lent_tiles]
    end
    outer = [Probe.key(4, 2)]
    assert_equal [outer, [Probe.key(2, 3), Probe.key(4, 2)], outer, nil], seen + [Probe.lent_tiles]
  end

  test "packs a state into the same Integer whatever order its boulders were moved in" do
    a = Routes.pkey(5, 5)
    b = Routes.pkey(7, 7)
    one = Pushes.moved_to(Pushes.moved_to([], a, 6, 5), b, 7, 8)
    other = Pushes.moved_to(Pushes.moved_to([], b, 7, 8), a, 6, 5)
    assert_equal Pushes.pack([3, 4, one]), Pushes.pack([3, 4, other])
  end

  test "packs states apart that differ in where the player or a boulder is" do
    a = Routes.pkey(5, 5)
    b = Routes.pkey(7, 7)
    both = Pushes.moved_to(Pushes.moved_to([], a, 6, 5), b, 7, 8)
    { "no boulder moved" => [3, 4, []], "only one moved" => [3, 4, Pushes.moved_to([], a, 6, 5)],
      "the two swapped" => [3, 4, [[a, 7, 8], [b, 6, 5]]], "the player elsewhere" => [4, 3, both] }.each do |what, st|
      refute_equal Pushes.pack([3, 4, both]), Pushes.pack(st), what
    end
  end

  test "a boulder's goal is met inside its zone, and without the boulder's pushes on record it estimates none" do
    rock = Routes.pkey(5, 5)
    goal = Pushes::RockGoal.new(rock, 5, 5, [7, 2, 8, 3])
    { [] => [0, false], [[rock, 7, 3]] => [0, true], [[rock, 8, 2]] => [0, true], [[rock, 6, 3]] => [0, false],
      [[rock, 9, 1]] => [0, false], [[rock, 8, 4]] => [0, false],
      [[Routes.pkey(1, 1), 7, 3]] => [0, false] }.each do |moved, want|
      assert_equal want, [goal.bound(0, 0, moved), goal.hit?(0, 0, moved)], "moved #{moved.inspect}"
    end
  end

  test "allows assisted steps only while an assisted frame's block runs" do
    modes = Pathfinder.searching do
      inside = Pathfinder.with_gates_open { Pathfinder.moves_mode(false, false) }
      [inside, Pathfinder.moves_mode(false, false)]
    end
    assert_equal [Routes::Moves::ASSIST, 0], modes
  end

  private

  # The mod's text for key, in the language the tests pin.
  def phrase(key, vars = nil)
    PokeAccess::I18n.t(key, vars)
  end

  # Loads rows with a climb on (2, 3) that lifts the player from (2, 4) to the top row.
  def climb_room(rows)
    $game_map.load_grid(rows)
    assisted_climb(90, 2, 3, [4, 4, 4])
    Pathfinder.invalidate_cache(true)
  end

  # An action-button event on (x, y) whose question, answered yes, moves the player by codes with Through on;
  # extra commands go inside the yes branch.
  def assisted_climb(id, x, y, codes, extra = [])
    World.touch(:id => id, :x => x, :y => y, :trigger => 0,
                :list => [TestCmd.new(101, ["¿Quieres usar el Equipo de Escalada?"]), TestCmd.new(102, [["Sí", "No"], 2]),
                          TestCmd.new(402, [0, "Sí"]), World.move_player([37] + codes + [38], 1)] + extra +
                         [TestCmd.new(402, [1, "No"]), TestCmd.new(404, [])])
  end

  # A Strength boulder on (x, y), solid, that moves when the grid tile beyond it is open; through, it passes
  # anywhere, as the engine's own check does.
  def assisted_boulder(id, x, y)
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

  # A statue as the games' own move theirs (Awakening's pbMoverEstatuas), checked as their engine checks it: the tile
  # it or the player really stands on is in its way. trigger 0 is an action-button event, 1 one walked into.
  def pull_statue(id, x, y, trigger = 0)
    ev = World.touch(:id => id, :name => STATUE, :x => x, :y => y, :trigger => trigger, :sprite => "statue",
                     :list => [TestCmd.new(355, ["pbMoverEstatuas"])])
    ev.blocking = true
    def ev.passableStrict?(x, y, d)
      nx = x + (d == 6 ? 1 : (d == 4 ? -1 : 0)); ny = y + (d == 2 ? 1 : (d == 8 ? -1 : 0))
      return true if through
      return false if $game_map.blocked?(nx, ny)
      return false if $game_map.events.values.any? { |e| e.x == nx && e.y == ny && !e.through }
      $game_player.x != nx || $game_player.y != ny
    end
    ev
  end

  # Loads rows with a statue of trigger on (x, y) in a gap, and answers it.
  def statue_gap(rows, x, y, trigger = 0)
    $game_map.load_grid(rows)
    st = pull_statue(112, x, y, trigger)
    Pathfinder.invalidate_cache(true)
    st
  end

  # A corridor with a statue of trigger on (3, 1) between the player and its far end (6, 1); answers the statue.
  def statue_corridor(trigger)
    $game_map.load_grid(['########',
                         '#@.....#',
                         '########'])
    st = pull_statue(114, 3, 1, trigger)
    Pathfinder.invalidate_cache(true)
    st
  end

  # CARRY_ROWS with the player on (px, py) and an action-button statue on (4, 2), two tiles east of its zone (2, 2):
  # its west side is reached from the top row down (3, 1), its east side down (5, 1). Answers the statue.
  def carry_room(px, py)
    $game_map.load_grid(CARRY_ROWS)
    $game_player.x = px
    $game_player.y = py
    st = pull_statue(118, 4, 2)
    Pathfinder.invalidate_cache(true)
    st
  end

  # A corridor with two boulders, each with an alcove to push it into from above.
  def two_boulder_room
    $game_map.load_grid(['##########',
                         '#...#..###',
                         '#@.......#',
                         '###.##.###',
                         '##########'])
    assisted_boulder(100, 3, 2)
    assisted_boulder(101, 6, 2)
    Pathfinder.invalidate_cache(true)
  end

  # A staircase going down to the right whose n corners each hold a boulder, pushed clear into the dead end beyond
  # it; answers the tile past the last one.
  def boulder_staircase(n)
    rows = Array.new(2 * n + 3) { "#" * (2 * n + 5) }
    x = 1
    n.times do |i|
      y = 1 + 2 * i
      (x..x + 3).each { |cx| rows[y][cx, 1] = "." }
      rows[y + 1][x + 2, 1] = "."
      x += 2
    end
    (x..x + 2).each { |cx| rows[2 * n + 1][cx, 1] = "." }
    rows[1][1, 1] = "@"
    $game_map.load_grid(rows)
    n.times { |i| assisted_boulder(200 + i, 3 + 2 * i, 1 + 2 * i) }
    Pathfinder.invalidate_cache(true)
    [x + 2, 2 * n + 1]
  end

  # Plans every floor tile not walked to in the random rooms of seeds (of action-button statues, with pulls; else of
  # boulders) and checks each plan against brute force; answers how many plans came back, and the tiles whose plan
  # starts off every cheapest way or that got none where brute force finds one and no search was stopped short.
  def plans_against_brute_force(seeds, pulls)
    checked = 0
    bad = []
    seeds.each do |seed|
      rows, rocks, limit = random_boulder_room(seed, pulls)
      next unless rows
      start = [$game_player.x, $game_player.y]
      floor_of(rows).each do |tx, ty|
        next if rocks.include?([tx, ty]) || walk_route(tx, ty)
        goal = [[tx, ty]] + Routes::DIRS.map { |dx, dy, _d| [tx + dx, ty + dy] }
        want = cheapest_pushes(rows, start, rocks, [], limit, goal, pulls)
        plan, cuts = Pathfinder.searching { |l| [Planner.assisted(tx, ty), l.cuts] }
        checked += 1 if plan
        ok = if plan
               !want.nil? && cost_through_push(rows, start, plan, rocks, limit, goal, pulls) == want
             else
               want.nil? || cuts > 0
             end
        bad.push([seed, tx, ty, plan && [plan[0], plan[1][:kind]], want]) unless ok
      end
    end
    [checked, bad]
  end

  # Loads a walled 9x7 room with walls at random, the player at its top left and one or two boulders (with statues,
  # action-button statues) on its floor, the puzzle assist on or off at random; answers the rows, the boulders' tiles
  # and how many a route may move, or nil for a room with too little floor.
  def random_boulder_room(seed, statues = false)
    rng = Random.new(seed)
    rows = Array.new(7) do |y|
      (0...9).map { |x| x == 0 || y == 0 || x == 8 || y == 6 || rng.rand < 0.3 ? "#" : "." }.join
    end
    rows[1][1, 1] = "@"
    floor = floor_of(rows)
    return nil if floor.length < 6
    rocks = floor.sample(1 + rng.rand(2), :random => rng)
    PokeAccess::Config.puzzle_assist = rng.rand < 0.5
    $game_map.load_grid(rows)
    rocks.each_with_index { |(x, y), i| statues ? pull_statue(300 + i, x, y) : assisted_boulder(300 + i, x, y) }
    Pathfinder.invalidate_cache(true)
    [rows, rocks, PokeAccess::Config.puzzle_assist ? Pushes::LIMIT : 1]
  end

  # The open floor tiles of rows, the player's own left out.
  def floor_of(rows)
    rows.each_with_index.flat_map { |row, y| (0...row.length).select { |x| row[x, 1] == "." }.map { |x| [x, y] } }
  end

  # The least cost, by brute force, for the player on at to stand on a goal tile, the boulders on rocks (the indexes in
  # moved moved already, at most limit of them ever moved): a Dijkstra where a step costs a press, and a push (or, with
  # pulls, a pull) PUSH_COST. A push leaves the player put and the boulder on the tile beyond, a pull steps the player
  # back and the boulder onto the tile left; the tile taken has to be open floor with no boulder. nil for no way.
  def cheapest_pushes(rows, at, rocks, moved, limit, goal, pulls = false)
    free = lambda do |(x, y), stones|
      y >= 0 && y < rows.length && x >= 0 && x < rows[y].length && rows[y][x, 1] != "#" && !stones.include?([x, y])
    end
    start = [at, rocks, moved]
    best = { start => 0 }
    queue = { 0 => [start] }
    cost = 0
    until queue.empty?
      (queue.delete(cost) || []).each do |state|
        next if best[state] < cost
        (x, y), stones, done = state
        return cost if goal.include?([x, y])
        Routes::DIRS.each do |dx, dy, _d|
          ahead = [x + dx, y + dy]
          i = stones.index(ahead)
          moves = if i.nil? then [[ahead, nil, ahead, 1]]
                  elsif done.include?(i) || done.length < limit
                    beyond = [x + 2 * dx, y + 2 * dy]
                    back = [x - dx, y - dy]
                    [[[x, y], beyond, beyond, PUSH_COST]] + (pulls ? [[back, [x, y], back, PUSH_COST]] : [])
                  else []
                  end
          moves.each do |player, rock, taken, price|
            next unless free.call(taken, stones)
            nxt = rock ? [player, stones.dup.tap { |s| s[i] = rock }, (done | [i]).sort] : [player, stones, done]
            next unless best[nxt].nil? || cost + price < best[nxt]
            best[nxt] = cost + price
            (queue[cost + price] ||= []).push(nxt)
          end
        end
      end
      cost += 1
    end
    nil
  end

  # What a plan from start costs through its first push or pull: its steps, that move, then the cheapest rest by brute
  # force; nil when that move takes none of rocks next to the player or nothing reaches goal after it.
  def cost_through_push(rows, start, plan, rocks, limit, goal, pulls = false)
    route, gate = plan
    x, y = route.inject(start) { |(px, py), d| [px + PokeAccess::DIR_DELTA[d][0], py + PokeAccess::DIR_DELTA[d][1]] }
    i = rocks.index([gate[:x], gate[:y]])
    return nil unless i && (gate[:x] - x).abs + (gate[:y] - y).abs == 1
    moved = rocks.dup
    if gate[:kind] == :pull
      moved[i] = [x, y]
      x, y = 2 * x - gate[:x], 2 * y - gate[:y]
    else
      moved[i] = [2 * gate[:x] - x, 2 * gate[:y] - y]
    end
    rest = cheapest_pushes(rows, [x, y], moved, [i], limit, goal, pulls)
    rest && route.length + PUSH_COST + rest
  end

  # The hall split by a wall with one boulder in it, the far side walled off from every assisted reach.
  def walled_hall
    rows = HALL_ROWS.dup
    rows[4] = '#............................#....#'
    $game_map.load_grid(rows)
    assisted_boulder(102, 10, 4)
    Pathfinder.invalidate_cache(true)
  end

  # Puts on the corridor what could assist: a boulder, a cut tree, a climb, a registered step, or nothing.
  def place_assist(what)
    case what
    when :boulder then assisted_boulder(97, 3, 1)
    when :tree then World.event(:kind => :npc, :id => 80, :x => 3, :y => 1, :name => "Tree").blocking = true
    when :climb then assisted_climb(90, 3, 1, [6, 6])
    when :registered then Routes::Moves.assist_source { |_x, _y, _dir, _lvl| nil }
    end
  end

  # The player afloat in the pool below the waterfall.
  def below_waterfall
    $PokemonGlobal.surfing = true
    $game_player.x = 2
    $game_player.y = 5
  end

  # Runs the block with exactly patterns registered as the scripts that also pull, the registrations put back after.
  def with_pull_scripts(patterns)
    fx = Routes::Effects
    was = fx.instance_variable_get(:@pull_scripts)
    fx.instance_variable_set(:@pull_scripts, patterns)
    yield
  ensure
    fx.instance_variable_set(:@pull_scripts, was)
  end

  # Runs the block with exactly sources registered as assisted steps (the harness's plugins register one), put back
  # after; answers the block's value.
  def with_assist_sources(sources)
    mv = Routes::Moves
    was = mv.instance_variable_get(:@assist_sources)
    mv.instance_variable_set(:@assist_sources, sources)
    yield
  ensure
    mv.instance_variable_set(:@assist_sources, was)
  end

  # The block's value with global standing for the game's $PokemonGlobal, the game's own put back after.
  def with_global(global)
    was = $PokemonGlobal
    $PokemonGlobal = global
    yield
  ensure
    $PokemonGlobal = was
  end

  # The block's value with the game numbering move id, which the gen-6 stub names "Mov<id>"; PBMoves as it was after.
  def with_move_id(move, id)
    had = PBMoves.const_defined?(move, false) ? [PBMoves.send(:remove_const, move)] : nil
    PBMoves.const_set(move, id)
    yield
  ensure
    PBMoves.send(:remove_const, move) if PBMoves.const_defined?(move, false)
    PBMoves.const_set(move, had[0]) if had
  end

  # Runs the block in a game that pushes boulders with Strength (move id id), its Kernel.pbStrength defined.
  def with_strength(id)
    Kernel.define_singleton_method(:pbStrength) { |*_args| nil }
    with_move_id(:STRENGTH, id) { yield }
  ensure
    sc = Kernel.singleton_class
    sc.send(:remove_method, :pbStrength) if sc.method_defined?(:pbStrength, false)
  end

  # The block's value with PokeAccess.clock standing still at seconds, the clock put back after.
  def with_still_clock(seconds)
    clock = PokeAccess.singleton_class
    clock.send(:alias_method, :clock__route_assisted, :clock)
    clock.send(:define_method, :clock) { seconds }
    yield
  ensure
    clock.send(:alias_method, :clock, :clock__route_assisted)
    clock.send(:remove_method, :clock__route_assisted)
  end

  # Runs the block on a map where the game never lets the player off the bike, MapMeta put back after.
  def with_bike_only_map
    meta = PokeAccess::MapMeta.singleton_class
    meta.send(:alias_method, :always_bicycle__route_assisted, :always_bicycle?)
    meta.send(:define_method, :always_bicycle?) { |_mid| true }
    yield
  ensure
    meta.send(:alias_method, :always_bicycle?, :always_bicycle__route_assisted)
    meta.send(:remove_method, :always_bicycle__route_assisted)
  end
end
