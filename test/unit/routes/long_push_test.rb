# An event that sends itself off when walked into, through whatever lies between (Z's electric crystals, Realidea's red
# ones): a route takes it for a push, the ways its page has, through a wall, leaving it where the route sends it or gone
# when the page it opens stops nobody, and again from there if it sets nothing that stays; a push its own self switch has
# spent is none. A piece carried into a box counts each of these as one push.

class LongPushTest < PokeAccessTest
  FX = PokeAccess::Routes::Effects
  RIGHT = 6
  LEFT = 4
  UP = 8
  DOWN = 2

  test "pushes through the wall behind it, which a step could not" do
    on_grid(["########", "#@...###", "####.###", "########"]) do
      crystal(RIGHT, [3, 3, 3], 4, 1)
      route, gate = push_route(4, 2)
      assert_equal [[6, 6], 4, 1, :loc_pushable, nil], [route.to_a, gate[:x], gate[:y], gate[:label], gate[:move]]
    end
  end

  test "goes only the way its page has" do
    on_grid(["########", "#@.....#", "####.###", "########"]) do
      steppable(crystal(LEFT, [2, 2, 2], 4, 1))
      assert_nil push_route(4, 2), "a step to the right would clear the turn, and the page has none"
    end
  end

  test "goes again from where it lands when the push sets nothing that stays" do
    on_grid(["##########", "#@.......#", "#####.####", "##########"]) do
      crystal(RIGHT, [3, 3], 3, 1)
      route, gate = push_route(5, 2)
      assert_equal [[6], 3], [route.to_a, gate[:x]], "the first push leaves it on the turn, the second clears it"
    end
  end

  test "goes only once when the push sets something that stays, a variable or a script's switch as much as a switch" do
    on_grid(["##########", "#@.......#", "#####.####", "##########"]) do
      [TestCmd.new(122, [87, 87, 1, 0, 1], 1), TestCmd.new(355, ['setTempSwitchOn("A")'], 1),
       TestCmd.new(121, [133, 133, 0], 1)].each do |set|
        event(61, 3, 1, [TestCmd.new(111, [6, -1, RIGHT], 0), route_cmd([3, 3], 1), set, TestCmd.new(412, [], 0)])
        assert_nil push_route(5, 2), "command #{set.code}: where it lands it shuts the way down"
      end
    end
  end

  test "is not pushed again off the map" do
    on_grid(["######", "#@...#", "######"]) do
      crystal(RIGHT, [3, 3], 2, 1)
      key = PokeAccess::Routes.pkey(2, 1)
      dir = PokeAccess::Routes::DIR_OF[RIGHT]
      pushes = PokeAccess::Routes::Pushes
      assert pushes.pushes?(1, 1, dir, key, [], FX.boulder_index)
      assert pushes.pushes?(2, 1, dir, key, [[key, 3, 1]], FX.boulder_index), "it lands on the map's last tile"
      refute pushes.pushes?(3, 1, dir, key, [[key, 4, 1]], FX.boulder_index), "it would land past the edge"
    end
    on_grid(["#####", "#@..#", "#...#", "#####"]) do
      crystal(DOWN, [1, 1], 2, 1)
      key = PokeAccess::Routes.pkey(2, 1)
      dir = PokeAccess::Routes::DIR_OF[DOWN]
      pushes = PokeAccess::Routes::Pushes
      assert pushes.pushes?(2, 0, dir, key, [], FX.boulder_index)
      refute pushes.pushes?(2, 1, dir, key, [[key, 2, 2]], FX.boulder_index), "it would land past the bottom"
    end
  end

  test "lands where the net of its route says, a bounce counted" do
    on_grid(["##########", "#@.......#", "#####.####", "##########"]) do
      crystal(RIGHT, [29, 3, 3, 3, 3, 44, 2, 29], 3, 1, :after => [:switch, 133, "crystal"])
      route, gate = push_route(5, 2)
      assert_equal [[6], 3], [route.to_a, gate[:x]], "three on leaves the turn free"
    end
  end

  test "lands down the map as well as along it" do
    on_grid(["#####", "#@..#", "##.##", "##.##", "##.##", "##.##", "#####"]) do
      crystal(DOWN, [1, 1], 2, 2, :after => [:switch, 133, "crystal"])
      assert_nil push_route(2, 5), "where it lands it fills the corridor"
      route, gate = push_route(2, 3)
      assert_equal [[6], 2], [route.to_a, gate[:y]]
    end
  end

  test "leaves the way free when the page it opens has no graphic" do
    on_grid(["##########", "#@.......#", "#####.####", "##########"]) do
      crystal(RIGHT, [3, 3], 3, 1, :after => [:switch, 133, ""])
      assert_equal [[RIGHT]], [push_route(5, 2)[0].to_a]
      assert_equal({ RIGHT => [2, 0, true, false] }, FX.long_pushes($game_map.events[61]))
    end
  end

  test "stays in the way when the page it opens still shows it" do
    on_grid(["##########", "#@.......#", "#####.####", "##########"]) do
      crystal(RIGHT, [3, 3], 3, 1, :after => [:switch, 133, "crystal"])
      assert_nil push_route(5, 2)
      assert_equal({ RIGHT => [2, 0, false, false] }, FX.long_pushes($game_map.events[61]))
    end
  end

  test "reads every facing of an if and else page, the plain else too" do
    on_grid(["#####", "#@..#", "#####"]) do
      list = [TestCmd.new(111, [6, -1, LEFT], 0), route_cmd([2, 2, 2, 3], 1), TestCmd.new(411, [], 0),
              TestCmd.new(111, [6, -1, UP], 1), route_cmd([4, 4, 4, 1], 2), TestCmd.new(411, [], 1),
              route_cmd([1, 1, 1, 1], 2), TestCmd.new(412, [], 1), TestCmd.new(412, [], 0)]
      ev = event(61, 3, 1, list)
      assert_equal({ LEFT => [-2, 0, false, true], UP => [0, -2, false, true], DOWN => [0, 4, false, true],
                     RIGHT => [0, 4, false, true] },
                   FX.long_pushes(ev))
    end
  end

  test "is no push once its own self switch has spent it, and is again when the switch goes off" do
    was = $game_self_switches
    $game_self_switches = {}
    on_grid(["##########", "#@.......#", "#####.####", "##########"]) do
      list = [TestCmd.new(111, [6, -1, RIGHT], 0), TestCmd.new(111, [2, "A", 1], 1), route_cmd([3, 3, 3], 2),
              TestCmd.new(123, ["A", 0], 2), TestCmd.new(412, [], 1), TestCmd.new(412, [], 0)]
      ev = event(61, 3, 1, list)
      assert_includes rocks, 61
      $game_self_switches[[$game_map.map_id, 61, "A"]] = true
      World.next_frame
      assert_empty FX.long_pushes(ev)
      refute_includes rocks, 61
      $game_self_switches[[$game_map.map_id, 61, "A"]] = false
      World.next_frame
      assert_includes rocks, 61
    end
  ensure
    $game_self_switches = was
  end

  test "reads a text and a variable on the way, as the Staryu of Soulstones 1 has" do
    on_grid(["#####", "#@..#", "#####"]) do
      list = [TestCmd.new(111, [6, -1, DOWN], 0), TestCmd.new(101, ["Back to the water."], 1),
              TestCmd.new(122, [87, 87, 1, 0, 1], 1), route_cmd([1, 1, 1, 1], 1), TestCmd.new(123, ["A", 0], 1),
              TestCmd.new(412, [], 0)]
      ev = event(61, 2, 1, list, :after => [:self, "A", ""])
      assert_equal({ DOWN => [0, 4, true, false] }, FX.long_pushes(ev))
    end
  end

  test "is no long push when its walk moves the player, fights, or its route is short or goes nowhere" do
    on_grid(["#####", "#@..#", "#####"]) do
      branch = lambda { |*inside| [TestCmd.new(111, [6, -1, RIGHT], 0)] + inside + [TestCmd.new(412, [], 0)] }
      [branch.call(route_cmd([3, 3], 1), World.move_player([3], 1)),
       branch.call(route_cmd([3, 3], 1), TestCmd.new(301, [1, false, false], 1)),
       branch.call(route_cmd([3], 1)),
       branch.call(route_cmd([3, 2], 1)),
       branch.call(route_cmd([9, 3, 3], 1)),
       branch.call(TestCmd.new(209, [0, TestMoveRoute.new([TestMoveCmd.new(3), TestMoveCmd.new(3)])], 1)),
       branch.call(TestCmd.new(209, [5, through_route([3, 3])], 1))].each_with_index do |list, i|
        assert_empty FX.long_pushes(event(61, 2, 1, list)), "list #{i}"
      end
    end
  end

  test "is no long push when it goes whichever way the player faces, someone walking off in a scene" do
    on_grid(["#####", "#@..#", "#####"]) do
      assert_empty FX.long_pushes(event(61, 2, 1, [route_cmd([3, 3], 0)]))
    end
  end

  test "leaves alone an event with no graphic, on the action button, or that a script pushes" do
    on_grid(["#####", "#@..#", "#####"]) do
      list = [TestCmd.new(111, [6, -1, RIGHT], 0), route_cmd([3, 3], 1), TestCmd.new(412, [], 0)]
      assert_empty FX.long_pushes(event(61, 2, 1, list, :sprite => ""))
      assert_empty FX.long_pushes(event(62, 2, 1, list, :trigger => 0))
      scripted = [TestCmd.new(355, ["pbPushThisBoulder"], 0)] + list
      assert_empty FX.long_pushes(event(63, 2, 1, scripted))
    end
  end

  test "takes both touches and a graphic drawn from the tileset" do
    on_grid(["#####", "#@..#", "#####"]) do
      list = [TestCmd.new(111, [6, -1, RIGHT], 0), route_cmd([3, 3], 1), TestCmd.new(412, [], 0)]
      assert_equal({ RIGHT => [2, 0, false, true] }, FX.long_pushes(event(61, 2, 1, list, :trigger => 2)))
      assert_empty FX.long_pushes(event(62, 2, 1, list, :trigger => 3))
      drawn = event(63, 2, 1, list, :sprite => "")
      drawn.tile_id = 404
      assert_equal [RIGHT], FX.long_pushes(drawn).keys
    end
  end

  test "is gone by the page its second switch opens or one it can be walked through, not by one whose conditions do not all hold" do
    on_grid(["#####", "#@..#", "#####"]) do
      set = TestCmd.new(121, [133, 135, 0], 1)
      list = [TestCmd.new(111, [6, -1, RIGHT], 0), route_cmd([3, 3], 1), set, TestCmd.new(412, [], 0)]
      gone = event(61, 2, 1, list)
      gone.instance_variable_get(:@event).pages.push(TestPage.new(:condition => { :switch2_valid => true, :switch2_id => 135 }))
      assert_equal({ RIGHT => [2, 0, true, false] }, FX.long_pushes(gone))
      through = event(64, 2, 1, list)
      through.instance_variable_get(:@event).pages.push(TestPage.new(:sprite => "crystal", :through => true,
                                                                     :condition => { :switch1_valid => true, :switch1_id => 134 }))
      assert_equal({ RIGHT => [2, 0, true, false] }, FX.long_pushes(through))
      off = event(62, 2, 1, list)
      off.instance_variable_get(:@event).pages.push(TestPage.new(:condition => { :switch1_valid => true, :switch1_id => 133,
                                                                                  :self_switch_valid => true, :self_switch_ch => "B" }))
      off.instance_variable_get(:@event).pages.push(TestPage.new(:condition => { :switch1_valid => true, :switch1_id => 200 }))
      assert_equal({ RIGHT => [2, 0, false, false] }, FX.long_pushes(off))
      turned_off = event(63, 2, 1, [TestCmd.new(111, [6, -1, RIGHT], 0), route_cmd([3, 3], 1), TestCmd.new(121, [133, 133, 1], 1),
                                    TestCmd.new(123, ["A", 1], 1), TestCmd.new(412, [], 0)])
      turned_off.instance_variable_get(:@event).pages.push(TestPage.new(:condition => { :switch1_valid => true, :switch1_id => 133 }))
      turned_off.instance_variable_get(:@event).pages.push(TestPage.new(:condition => { :self_switch_valid => true, :self_switch_ch => "A" }))
      assert_equal({ RIGHT => [2, 0, false, false] }, FX.long_pushes(turned_off), "turning them off opens nothing")
    end
  end

  test "carries a piece into a box its push lands in, through the wall between" do
    on_grid(["#########", "#@..#...#", "######.##", "#########"]) do
      crystal(RIGHT, [3, 3, 3], 3, 1)
      route, gate = carry_route([6, 1, 6, 1])
      assert_equal [[6], 3, 1], [route.to_a, gate[:x], gate[:y]]
    end
  end

  test "carries a piece along a route that turns" do
    on_grid(["#########", "#@..#...#", "######.##", "#########"]) do
      crystal(RIGHT, [3, 3, 3, 1], 3, 1, :after => [:switch, 133, "crystal"])
      route, gate = carry_route([5, 2, 7, 2])
      assert_equal [[6], 3, 1], [route.to_a, gate[:x], gate[:y]]
    end
  end

  test "carries a piece nowhere but where its push lands, and not where the push leaves it gone" do
    on_grid(["#########", "#@......#", "#########"]) do
      crystal(RIGHT, [3, 3, 3], 3, 1, :after => [:switch, 133, "crystal"])
      assert_nil carry_route([5, 1, 5, 1]), "short of where it lands"
      assert_nil carry_route([7, 1, 7, 1]), "past where it lands"
      assert carry_route([6, 1, 6, 1])
      crystal(RIGHT, [3, 3, 3], 3, 1, :after => [:switch, 133, ""])
      assert_nil carry_route([6, 1, 6, 1]), "gone"
      assert_equal PokeAccess::Routes::FAR, rock_goal([6, 1, 6, 1]).bound(0, 0, []), "no search for one that goes"
    end
  end

  test "carries a piece as far as pushes that spend nothing take it, each from where the last left it" do
    on_grid(["#########", "#@......#", "#########"]) do
      crystal(RIGHT, [3, 3], 2, 1)
      route, gate = carry_route([6, 1, 6, 1])
      assert_equal [[], 2], [route.to_a, gate[:x]]
      assert_nil carry_route([5, 1, 5, 1]), "its pushes go two tiles at a time"
    end
  end

  test "estimates a long push as the one push it is, from the tile it starts on unless it spends nothing" do
    price = 1 + PokeAccess::Pathfinder::GATE_COST
    on_grid(["###########", "#@........#", "#.........#", "###########"]) do
      crystal(RIGHT, [3, 3, 3], 2, 1, :after => [:switch, 133, "crystal"])
      assert_equal price, rock_goal([5, 1, 5, 1]).bound(0, 0, [])
      assert_equal PokeAccess::Routes::FAR, rock_goal([4, 1, 4, 1]).bound(0, 0, []), "no steps of one tile that way"
      assert_equal PokeAccess::Routes::FAR, rock_goal([8, 1, 8, 1]).bound(0, 0, []), "spent after the first"
      assert_equal PokeAccess::Routes::FAR, rock_goal([2, 2, 2, 2]).bound(0, 0, []), "its page has no way down"
      crystal(RIGHT, [3, 3, 3], 2, 1)
      assert_equal 2 * price, rock_goal([8, 1, 8, 1]).bound(0, 0, [])
      key = PokeAccess::Routes.pkey(2, 1)
      assert_equal price, rock_goal([8, 1, 8, 1]).bound(0, 0, [[key, 5, 1]])
    end
  end

  test "gives no estimate to follow for a push with nowhere for the player to stand behind it" do
    on_grid(["########", "#......#", "#@.....#", "########"]) do
      crystal(RIGHT, [3, 3, 3], 1, 1, :after => [:switch, 133, "crystal"])
      assert_equal PokeAccess::Routes::FAR, rock_goal([4, 1, 4, 1]).bound(0, 0, [])
    end
  end

  test "makes a push that sets something the last it gives a piece, whichever came before it" do
    price = 1 + PokeAccess::Pathfinder::GATE_COST
    on_grid(["##########", "#........#", "#@.......#", "#........#", "#........#", "##########"]) do
      event(61, 3, 2, facing_list(RIGHT, [3, 3], nil) + facing_list(DOWN, [1, 1], TestCmd.new(121, [133, 133, 0], 1)),
            :after => [:switch, 133, "crystal"])
      assert_equal 2 * price, rock_goal([5, 4, 5, 4]).bound(0, 0, []), "right from where it starts, then down"
      route, gate = carry_route([5, 4, 5, 4])
      assert_equal [[6], 3, 2], [route.to_a, gate[:x], gate[:y]], "and not down first, which would spend it"
    end
    on_grid(["##########", "#@.......#", "#.#......#", "#........#", "#........#", "##########"]) do
      event(61, 3, 2, facing_list(RIGHT, [3, 3], nil) + facing_list(DOWN, [1, 1], TestCmd.new(121, [133, 133, 0], 1)),
            :after => [:switch, 133, "crystal"])
      assert_nil carry_route([5, 4, 5, 4]), "no standing left of it, and nothing after the push down"
    end
  end

  test "counts the steps of one tile a piece also takes" do
    price = 1 + PokeAccess::Pathfinder::GATE_COST
    on_grid(["##########", "#........#", "#@.......#", "#........#", "##########"]) do
      step = TestCmd.new(209, [0, TestMoveRoute.new([TestMoveCmd.new(1), TestMoveCmd.new(0)])], 1)
      list = facing_list(RIGHT, [3, 3], TestCmd.new(121, [133, 133, 0], 1)) +
             [TestCmd.new(111, [6, -1, DOWN], 0), step, TestCmd.new(412, [], 0)]
      steppable(event(61, 3, 2, list, :after => [:switch, 133, "crystal"]))
      assert_equal 2 * price, rock_goal([5, 3, 5, 3]).bound(0, 0, []), "a step down, then the push"
      route, gate = carry_route([5, 3, 5, 3])
      assert_equal [[6, 6, 8], 3, 2], [route.to_a.sort, gate[:x], gate[:y]], "from above it"
      assert_equal PokeAccess::Routes::FAR, rock_goal([5, 2, 5, 2]).bound(0, 0, [[PokeAccess::Routes.pkey(3, 2), 5, 3]]), "no way up"
    end
  end

  test "counts one push for any distance where the field was cut" do
    price = 1 + PokeAccess::Pathfinder::GATE_COST
    on_grid(["###########", "#@........#", "#.........#", "###########"]) do
      crystal(RIGHT, [3, 3, 3], 2, 1)
      with_field_cap(0) { assert_equal price, rock_goal([8, 1, 8, 1]).bound(0, 0, []) }
    end
  end

  test "tells a spent boulder from one that may still move, the same tile for both" do
    pushes = PokeAccess::Routes::Pushes
    on_grid(["###########", "#@........#", "#.........#", "###########"]) do
      crystal(RIGHT, [3, 3], 2, 1)
      key = PokeAccess::Routes.pkey(2, 1)
      dir = PokeAccess::Routes::DIR_OF[RIGHT]
      assert pushes.pushes?(4, 1, dir, key, [[key, 5, 1, false]], FX.boulder_index)
      refute pushes.pushes?(4, 1, dir, key, [[key, 5, 1, true]], FX.boulder_index)
      assert_equal 1 + PokeAccess::Pathfinder::GATE_COST, rock_goal([7, 1, 7, 1]).bound(0, 0, [[key, 5, 1, false]])
      assert_equal PokeAccess::Routes::FAR, rock_goal([7, 1, 7, 1]).bound(0, 0, [[key, 5, 1, true]]), "it goes no further"
      assert_equal 0, rock_goal([5, 1, 5, 1]).bound(0, 0, [[key, 5, 1, true]]), "spent inside the box is there"
      refute_equal pushes.pack([4, 1, [[key, 5, 1, false]], 0]), pushes.pack([4, 1, [[key, 5, 1, true]], 0])
      assert_equal [[key, 5, 1, true]], pushes.moved_to([[key, 2, 1, false]], key, 5, 1, true)
    end
  end

  test "plans the carry up to its push with the assist on" do
    PokeAccess::Config.puzzle_assist = true
    on_grid(["#########", "#@..#...#", "#########"]) do
      ev = crystal(RIGHT, [3, 3, 3], 3, 1)
      plan = PokeAccess::Routes::Planner.carry(ev, [6, 1, 6, 1])
      assert_equal [:assisted, [6], :field, [3, 1]],
                   [plan.kind, plan.route.to_a, plan.gate[:kind], [plan.gate[:x], plan.gate[:y]]]
    end
  ensure
    PokeAccess::Routes::Planner.forget
  end

  test "looks at more states than a search on foot may examine, by effort" do
    was = PokeAccess::Config.astar_max
    on_grid(["##########", "#@.......#", "#####.####", "##########"]) do
      crystal(RIGHT, [3, 3, 3, 3], 3, 1)
      PokeAccess::Config.astar_max = 3
      assert_equal [[RIGHT], 3], push_route(5, 2).then { |route, gate| [route.to_a, gate[:x]] }
      PokeAccess::Config.astar_max = 1
      assert_nil push_route(5, 2), "even four times one is too few"
    end
  ensure
    PokeAccess::Config.astar_max = was
  end

  test "keeps what its clock cut, for a question asked again from that tile not to hold the game again" do
    with_seconds(-1) do
      room_behind_a_crystal do
        first = PokeAccess::Routes::Planner.plan(8, 4, true)
        assert_equal :cut, first.kind
        assert first.stats.equal?(PokeAccess::Routes::Planner.plan(8, 4, true).stats), "the plan kept, not made again"
      end
    end
    with_seconds(60) do
      room_behind_a_crystal do
        assert_equal :none, PokeAccess::Routes::Planner.plan(8, 4, true).kind
      end
    end
  end

  test "sounds as something to push on the radar" do
    on_grid(["#####", "#@..#", "#####"]) do
      list = [TestCmd.new(111, [6, -1, RIGHT], 0), route_cmd([3, 3], 1), TestCmd.new(412, [], 0)]
      assert PokeAccess::Sound::Scene.rock?(event(61, 2, 1, list))
    end
  end

  private

  def rocks
    FX.boulder_index.values.map { |info| info[0].id }
  end

  # A room with a way out a crystal only goes along, to rest on the far tile: enough states to reach the clock's first look, and no
  # way to find, though there is one with the crystal gone.
  def room_behind_a_crystal
    on_grid(["##########", "#@.....###", "#......###", "#......###", "#........#", "##########"]) do
      PokeAccess::Routes::Planner.forget
      crystal(RIGHT, [3, 3], 6, 4)
      yield
    end
  ensure
    PokeAccess::Routes::Planner.forget
  end

  # Runs the block with the push search's clock set to seconds.
  def with_seconds(seconds)
    pushes = PokeAccess::Routes::Pushes
    was = pushes::SECONDS
    pushes.send(:remove_const, :SECONDS)
    pushes.const_set(:SECONDS, seconds)
    yield
  ensure
    pushes.send(:remove_const, :SECONDS)
    pushes.const_set(:SECONDS, was)
  end

  def push_route(x, y)
    PokeAccess::Pathfinder.invalidate_cache(true)
    PokeAccess::Routes::Pushes.route(PokeAccess::Routes::Goal.onto(x, y))
  end

  # The goal to take event 61 into box, from where it stands.
  def rock_goal(box)
    ev = $game_map.events[61]
    key = PokeAccess::Routes.pkey(ev.x, ev.y)
    PokeAccess::Pathfinder.invalidate_cache(true)
    PokeAccess::Routes::Pushes::RockGoal.new(key, ev.x, ev.y, box, FX.boulder_index[key])
  end

  def carry_route(box)
    PokeAccess::Routes::Pushes.route(rock_goal(box))
  end

  # Lets event ev take steps of one tile as the game asks them.
  def steppable(ev)
    def ev.passableStrict?(x, y, d)
      return true if through
      !$game_map.blocked?(x + (d == 6 ? 1 : (d == 4 ? -1 : 0)), y + (d == 2 ? 1 : (d == 8 ? -1 : 0)))
    end
    ev
  end

  # A branch of a page on the player facing facing, sending the event along codes and running set if given.
  def facing_list(facing, codes, set)
    [TestCmd.new(111, [6, -1, facing], 0), route_cmd(codes, 1), set, TestCmd.new(412, [], 0)].compact
  end

  # Runs the block with the cap on a boulder's field set to n.
  def with_field_cap(n)
    goal = PokeAccess::Routes::Pushes::RockGoal
    was = goal::FIELD_CAP
    goal.send(:remove_const, :FIELD_CAP)
    goal.const_set(:FIELD_CAP, n)
    yield
  ensure
    goal.send(:remove_const, :FIELD_CAP)
    goal.const_set(:FIELD_CAP, was)
  end

  # A Set Move Route on the event itself with Through on over the given move codes.
  def route_cmd(codes, indent)
    TestCmd.new(209, [0, through_route(codes)], indent)
  end

  def through_route(codes)
    TestMoveRoute.new(([37] + codes + [38]).map { |c| TestMoveCmd.new(c) })
  end

  # An event pushed only when the player faces facing, with the given route; :after [kind, id, sprite] adds the page the
  # push opens, by a switch (:switch) or a self switch (:self).
  def crystal(facing, codes, x, y, opts = {})
    set = []
    set = [opts[:after][0] == :switch ? TestCmd.new(121, [opts[:after][1], opts[:after][1], 0], 1) : TestCmd.new(123, [opts[:after][1], 0], 1)] if opts[:after]
    event(61, x, y, [TestCmd.new(111, [6, -1, facing], 0), route_cmd(codes, 1)] + set + [TestCmd.new(412, [], 0)], opts)
  end

  def event(id, x, y, list, opts = {})
    pages = [TestPage.new(:trigger => opts.fetch(:trigger, 1), :sprite => opts.fetch(:sprite, "crystal"), :list => list + [TestCmd.new(0, [])])]
    if opts[:after]
      kind, key, sprite = opts[:after]
      cond = kind == :switch ? { :switch1_valid => true, :switch1_id => key } : { :self_switch_valid => true, :self_switch_ch => key }
      pages.push(TestPage.new(:trigger => 0, :sprite => sprite, :condition => cond))
    end
    ev = TestGameEvent.new(:id => id, :x => x, :y => y, :name => "EV#{id}", :pages => pages)
    ev.blocking = true
    $game_map.events[id] = ev
    World.next_frame
    ev
  end

  def on_grid(rows)
    $game_map.load_grid(rows)
    PokeAccess::Pathfinder.invalidate_cache(true)
    yield
  ensure
    World.clear_events
    $game_map.clear_grid
  end
end
