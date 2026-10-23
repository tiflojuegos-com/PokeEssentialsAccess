# The step guide (Ctrl+I) says the route a leg at a time, each when new and none while it shortens, in Routes::Text's
# words for routes and forced moves, sharing arrival and dead end with the cane; a search cut short is not no route.
class StepGuideTest < PokeAccessTest
  T = PokeAccess::I18n
  Text = PokeAccess::Routes::Text
  G = PokeAccess::Guide
  # A corridor that turns once: the player at its left end, off the diagonal, the target (event 1) below its far end.
  CORNER = ["##########",
            "##########",
            "#@.......#",
            "########.#",
            "########T#",
            "##########"]
  # An open room two rows deep, the player at the left of its lower row.
  OPEN = ["#####################",
          "#...................#",
          "#@..................#",
          "#####################"]
  # A cut tree, cleared with Cut, and a boulder, pushed.
  TREE = { :kind => :field, :label => :loc_cut_tree, :move => :CUT, :x => 4, :y => 1 }
  BOULDER = { :kind => :field, :label => :loc_strength_boulder, :move => nil, :x => 4, :y => 1 }

  test "splits a route into its runs of one direction" do
    { [4, 8, 8, 8, 8, 8, 8] => [[4, 1, false], [8, 6, false]],
      [6, 6, 6] => [[6, 3, false]],
      [6, 2, 6, 2] => [[6, 1, false], [2, 1, false], [6, 1, false], [2, 1, false]],
      [] => [],
      nil => [] }.each { |path, want| assert_equal want, Text.legs(path), "for #{path.inspect}" }
  end

  test "ends a leg on each transfer of the route, none left over when the route ends on one" do
    { [[8, 8, 8, 8, 6, 6], [2]] => [[8, 3, true], [8, 1, false], [6, 2, false]],
      [[8, 8, 8], [2]] => [[8, 3, true]],
      [[6, 6, 6, 6], [0, 2]] => [[6, 1, true], [6, 2, true], [6, 1, false]] }.each do |(dirs, warps), want|
      assert_equal want, Text.legs(route(dirs, warps)), "for #{dirs.inspect} with transfers after #{warps.inspect}"
    end
  end

  test "takes the transfers given over the route's own" do
    assert_equal [[6, 2, true], [6, 2, false]], Text.legs(route([6, 6, 6, 6], [0]), [1])
  end

  test "runs on across a transfer at brief verbosity" do
    r = route([8, 8, 8, 8, 6, 6], [2])
    assert_equal [[[8, 4, false], [6, 2, false]], [[8, 3, true], [8, 1, false], [6, 2, false]]],
                 vb_levels { Text.legs(r) }.values_at(0, 1)
  end

  test "says a leg as its count and direction, held or ending on a transfer" do
    plain = leg_text(6, :dir_up)
    held = T.t(:loc_leg_held, :leg => plain)
    { [false, false] => plain, [true, false] => held, [false, true] => T.t(:loc_leg_transfer, :leg => plain),
      [true, true] => T.t(:loc_leg_transfer, :leg => held) }.each do |(hold, transfer), want|
      assert_equal want, Text.leg(8, 6, hold, transfer), "held #{hold}, transfer #{transfer}"
    end
  end

  test "says a leg plain by default, neither held nor ending on a transfer" do
    assert_equal leg_text(6, :dir_up), Text.leg(8, 6)
  end

  test "says a route as its legs joined, and an empty one as standing next to the target" do
    { [4, 8, 8, 8, 8, 8, 8] => "#{leg_text(1, :dir_left)}, #{leg_text(6, :dir_up)}",
      route([8, 8, 8, 8, 6, 6], [2]) => [T.t(:loc_leg_transfer, :leg => leg_text(3, :dir_up)), leg_text(1, :dir_up),
                                         leg_text(2, :dir_right)].join(", "),
      [] => T.t(:loc_next_to) }.each { |path, want| assert_equal want, Text.steps(path), "for #{path.inspect}" }
  end

  test "says where a forced move left the player, its rows before its columns" do
    both = T.t(:list_and, :rest => T.t(:moved_up, :n => 1), :last => T.t(:moved_right, :n => 2))
    { [0, -3] => T.t(:moved_up, :n => 3), [0, 2] => T.t(:moved_down, :n => 2), [-4, 0] => T.t(:moved_left, :n => 4),
      [2, -1] => both }.each do |(dx, dy), dirs|
      assert_equal T.t(:loc_moved, :dirs => dirs), Text.moved(dx, dy), "moved #{dx}, #{dy}"
    end
  end

  test "says the way a forced move went leg by leg, as a slide or a move" do
    three = T.t(:list_and, :rest => "#{leg_text(4, :dir_up)}, #{leg_text(3, :dir_right)}",
                           :last => leg_text(2, :dir_down))
    assert_equal [T.t(:loc_slid, :legs => three), T.t(:loc_moved_path, :legs => leg_text(1, :dir_left))],
                 [Text.moved_path([8, 8, 8, 8, 6, 6, 6, 2, 2], true), Text.moved_path([4], false)]
  end

  test "says why there is no route: none found, a search cut short, or a target out of range" do
    assert_equal [T.t(:loc_no_route), T.t(:loc_route_gave_up), T.t(:loc_route_far)],
                 [Text.none(:none), Text.none(:cut), Text.none(:far)]
  end

  test "adds to a listed target how far it is, what is in its way, or why there is no route" do
    rock = World.event(:id => 31, :name => "Pedrusco", :x => 4, :y => 1)
    lever = World.event(:id => 32, :name => "Interruptor", :x => 5, :y => 1)
    with_move_id(:CUT, 15) do
      { plan(:walk, [6, 6, 8]) => ", " + T.t(:loc_steps, :n => 3),
        plan(:walk, [6]) => ", " + T.t(:loc_steps, :n => 1),
        plan(:walk, []) => "",
        plan(:assisted, [6], TREE) => ", " + T.t(:loc_gate_route, :what => T.t(:loc_cut_tree), :move => "Mov15"),
        plan(:assisted, [6], BOULDER) => ", " + T.t(:loc_gate_route_push, :what => T.t(:loc_big_rock)),
        plan(:assisted, [6], BOULDER.merge(:ev => rock)) => ", " + T.t(:loc_gate_route_push, :what => "Pedrusco"),
        plan(:assisted, [6], { :kind => :control, :label => :loc_lever, :ev => lever }) =>
          ", " + T.t(:loc_control_route, :what => T.t(:loc_lever)),
        plan(:surf, [6]) => ", " + T.t(:loc_surf_route),
        plan(:cut) => ", " + T.t(:loc_route_gave_up),
        plan(:far) => ", " + T.t(:loc_route_far),
        plan(:none) => ", " + T.t(:loc_no_route) }.each do |p, want|
        assert_equal want, Text.listing(p), "for a #{p.kind} plan of #{p.route.inspect}"
      end
    end
  end

  test "says on the info key the steps, up to what an assisted route leads to, which way to surf, or why there " \
       "is none" do
    steps = "#{leg_text(2, :dir_right)}, #{leg_text(1, :dir_up)}"
    here = Text.surf_hold(nil)
    { plan(:walk, [6, 6, 8]) => T.t(:loc_route, :steps => steps),
      plan(:walk, []) => T.t(:loc_route, :steps => T.t(:loc_next_to)),
      plan(:assisted, [6, 6, 8], TREE) => T.t(:loc_route_gate, :what => T.t(:loc_cut_tree), :steps => steps),
      plan(:assisted, [6, 6, 8], { :kind => :act, :face => 8 }) => T.t(:loc_route_gate, :what => T.t(:loc_act_spot),
                                                                       :steps => steps),
      plan(:assisted, [6, 6, 8], { :kind => :dismount, :face => 6 }) =>
        T.t(:loc_route_gate, :what => T.t(:loc_dismount_spot), :steps => steps),
      plan(:surf, [6, 6, 8]) => T.t(:loc_route, :steps => "#{steps}, #{T.t(:loc_surf_way, :toward => here)}"),
      plan(:surf, []) => T.t(:loc_route, :steps => here),
      plan(:cut) => T.t(:loc_route, :steps => T.t(:loc_route_gave_up)),
      plan(:far) => T.t(:loc_route, :steps => T.t(:loc_route_far)),
      plan(:none) => T.t(:loc_route_none) }.each do |p, want|
      assert_equal want, Text.line(p), "for a #{p.kind} plan of #{p.route.inspect} (#{p.gate.inspect})"
    end
  end

  test "tells a plan's search by what answered, the tiles it examined and its time" do
    stats = { :algo => :astar, :expanded => 12, :cuts => 0, :ms => 3.2 }
    { plan(:walk, [6], nil, stats) => T.t(:route_stats, :algo => T.t(:algo_astar), :n => 12, :ms => "3,2"),
      plan(:cut, nil, nil, stats.merge(:cuts => 1)) => T.t(:route_stats_cut, :algo => T.t(:algo_astar), :n => 12,
                                                          :ms => "3,2"),
      plan(:walk, [6], nil, stats.merge(:algo => :flood)) => T.t(:route_stats, :algo => T.t(:algo_dijkstra), :n => 12,
                                                                 :ms => "3,2"),
      plan(:walk, [6], nil, stats.merge(:expanded => 1, :ms => 0.4)) => T.t(:route_stats, :algo => T.t(:algo_astar),
                                                                           :n => 1, :ms => "0,4") }.each do |p, want|
      assert_equal want, Text.stats(p), "for #{p.kind} with #{p.stats.inspect}"
    end
  end

  test "tells nothing of a plan no search was made for" do
    assert_equal [nil, nil], [Text.stats(plan(:cut, nil, nil, { :algo => nil })), Text.stats(plan(:none))]
  end

  test "says the first leg on the first frame, queued behind what was being said" do
    hpa_fresh_grid(CORNER)
    with_guide_state do |loc|
      steps_aim(loc, $game_map.events[1])
      walk_to(loc, 1, 2)
      assert_equal [[leg_text(7, :dir_right), false]], SpeakCapture.log
    end
  end

  test "holds its tongue while a leg shortens, and says it longer, cutting itself, on a step back" do
    hpa_fresh_grid(CORNER)
    with_guide_state do |loc|
      steps_aim(loc, $game_map.events[1])
      walk_to(loc, 1, 2)
      said = [[2, 2], [1, 2], [2, 2], [3, 2], [2, 2]].map { |x, y| heard(loc, x, y) }
      assert_equal [[], [[leg_text(7, :dir_right), true]], [], [], [[leg_text(6, :dir_right), true]]], said
    end
  end

  test "queues a longer leg behind a line said since the last one" do
    hpa_fresh_grid(CORNER)
    with_guide_state do |loc|
      steps_aim(loc, $game_map.events[1])
      walk_to(loc, 1, 2)
      walk_to(loc, 2, 2)
      PokeAccess.speak("otra cosa", false)
      walk_to(loc, 1, 2)
      assert_equal [[leg_text(7, :dir_right), false]], SpeakCapture.log
    end
  end

  test "says the new direction where the way turns, and arriving beside the target ends the guide" do
    hpa_fresh_grid(CORNER)
    with_guide_state do |loc|
      steps_aim(loc, $game_map.events[1])
      (1..7).each { |x| walk_to(loc, x, 2) }
      turn = heard(loc, 8, 2)
      arrival = heard(loc, 8, 3)
      assert_equal [[[leg_text(1, :dir_down), true]], [[T.t(:loc_arrived), true]], false],
                   [turn, arrival, G.on?(:steps)]
    end
  end

  test "plans the route again at once when a page turned on its way changes it" do
    hpa_fresh_grid(["##########",
                    "#@......T#",
                    "#........#",
                    "##########"])
    with_guide_state do |loc|
      with_clock do |_pass|
        target = $game_map.events[1]
        floor = World.touch(:id => 81, :x => 5, :y => 1, :list => [TestCmd.new(355, ["pbSEPlay('Crack')"])])
        PokeAccess::Pathfinder.invalidate_cache(true)
        steps_aim(loc, target)
        walk_to(loc, 1, 1)
        before = traced(1, 1, 0, G.remaining).map { |p| p.tile }
        walk_to(loc, 2, 1)
        hole = TestPage.new(:trigger => 1, :sprite => "",
                            :list => [TestCmd.new(201, [0, $game_map.map_id, 1, 2]), TestCmd.new(0, [])])
        [:@active, :@page].each { |iv| floor.instance_variable_set(iv, hole) }
        floor.instance_variable_set(:@list, hole.list)
        walk_to(loc, 3, 1)
        after = traced(3, 1, 0, G.remaining)
        assert_equal [true, false, true],
                     [before.include?([5, 1]), after.any? { |p| p.tile == [5, 1] },
                      [[7, 1], [8, 2]].include?(after.last.tile)],
                     "over the floor at first, round the hole the next frame with the clock standing, still beside it"
      end
    end
  end

  test "says the arrival once for the cane and the step guide, turning both off" do
    hpa_fresh_grid(["#####",
                    "#@.T#",
                    "#####"])
    with_guide_state do |loc|
      steps_aim(loc, $game_map.events[1])
      G.switch(:cane, true)
      walk_to(loc, 2, 1)
      assert_equal [[[T.t(:loc_arrived), true]], false, false], [SpeakCapture.log, G.on?(:cane), G.on?(:steps)]
    end
  end

  test "arriving on a map-edge exit's tile, the guide says which way to step off the map and ends" do
    hpa_fresh_grid(["#####",
                    "#@..#",
                    "#####"])
    with_guide_state do |loc|
      loc.instance_variable_set(:@conn_edges, 3 => [[3, 1, 6]])
      steps_aim(loc, loc::SurfaceTarget.new(3, 1, "salida a Ruta 3", nil, 3))
      walk_to(loc, 1, 1)
      walk_to(loc, 2, 1)
      arrival = walk_to(loc, 3, 1)
      way = T.t(:loc_exit_out, :out => T.t(:loc_out_right))
      assert_equal [[T.t(:loc_arrived_exit, :exit => way)], false], [arrival, G.on?(:steps)]
    end
  ensure
    PokeAccess::Locator.instance_variable_set(:@conn_edges, nil)
  end

  test "says a dead end once for the cane and the step guide, both staying on" do
    hpa_fresh_grid(["#####",
                    "#@#T#",
                    "#####"])
    with_guide_state do |loc|
      steps_aim(loc, $game_map.events[1])
      G.switch(:cane, true)
      first = walk_to(loc, 1, 1)
      again = walk_to(loc, 1, 1)
      assert_equal [[T.t(:loc_no_route)], [], true, true], [first, again, G.on?(:cane), G.on?(:steps)]
    end
  end

  test "says the dead end of each new target with no way" do
    hpa_fresh_grid(["#########",
                    "#@..#...#",
                    "#########"])
    with_guide_state do |loc|
      steps_aim(loc, loc::SurfaceTarget.new(6, 1, "cofre", :spot))
      first = walk_to(loc, 1, 1)
      loc.instance_variable_set(:@target, loc::SurfaceTarget.new(7, 1, "caja", :spot))
      assert_equal [[T.t(:loc_no_route)], [T.t(:loc_no_route)]], [first, walk_to(loc, 1, 1)]
    end
  end

  test "says the dead end again each time the way is lost, not only the first" do
    hpa_fresh_grid(["#########",
                    "#@...#..#",
                    "#########"])
    with_guide_state do |loc|
      with_clock do |pass|
        person = World.event(:id => 9, :x => 7, :y => 1)
        steps_aim(loc, person)
        said = [7, 4, 7].map do |x|
          person.x = x
          pass.call(G::RECHECK_SEC)
          walk_to(loc, 1, 1)
        end
        assert_equal [[T.t(:loc_no_route)], [leg_text(2, :dir_right)], [T.t(:loc_no_route)]], said
      end
    end
  end

  test "held on the shore, says once where to surf, plans nothing more, and says it again for a new target" do
    with_guide_state do |loc|
      with_tile_world(["##########",
                       "#@...~~..#",
                       "##########"]) do
        with_clock do |pass|
          count_plans do |n|
            steps_aim(loc, loc::SurfaceTarget.new(8, 1, "cofre", :spot))
            set_off = walk_to(loc, 1, 1)
            ashore = heard(loc, 4, 1)
            pass.call(G::RECHECK_SEC)
            waiting = [heard(loc, 4, 1), n[0]]
            loc.instance_variable_set(:@target, loc::SurfaceTarget.new(7, 1, "caja", :spot))
            again = heard(loc, 4, 1)
            surf = [[T.t(:loc_surf_toward, :dir => T.t(:toward_right)), false]]
            assert_equal [[leg_text(3, :dir_right)], surf, [[], 1], surf, true],
                         [set_off, ashore, waiting, again, G.on?(:steps)]
          end
        end
      end
    end
  end

  test "turned off and on again on the shore, the step guide says again where to surf" do
    with_guide_state do |loc|
      with_tile_world(["##########",
                       "#@...~~..#",
                       "##########"]) do
        steps_aim(loc, loc::SurfaceTarget.new(8, 1, "cofre", :spot))
        walk_to(loc, 1, 1)
        heard(loc, 4, 1)
        2.times { G.toggle(:steps) }
        assert_equal [[T.t(:loc_surf_toward, :dir => T.t(:toward_right)), false]], heard(loc, 4, 1)
      end
    end
  end

  test "toggling a guide names the target it leads to, and toggling it again turns it off" do
    hpa_fresh_grid(["#####",
                    "#@.T#",
                    "#####"])
    with_guide_state do |loc|
      target = $game_map.events[1]
      loc.instance_variable_set(:@target, target)
      { :cane => [:loc_guide_to, :loc_guide_off], :steps => [:loc_steps_to, :loc_steps_off] }.each do |kind, (on, off)|
        SpeakCapture.clear
        G.toggle(kind)
        started = [SpeakCapture.log.dup, G.on?(kind)]
        SpeakCapture.clear
        G.toggle(kind)
        assert_equal [[[T.t(on, :name => "npc"), true]], true, [[T.t(off), true]], false],
                     started + [SpeakCapture.log.dup, G.on?(kind)], "the #{kind}"
      end
    end
  end

  test "toggling a guide with nothing selected selects the target on the map and names it" do
    hpa_fresh_grid(["#####",
                    "#@.T#",
                    "#####"])
    with_guide_state do |loc|
      loc.instance_variable_set(:@target, nil)
      G.toggle(:steps)
      assert_equal [[[T.t(:loc_steps_to, :name => "npc"), true]], true, $game_map.events[1]],
                   [SpeakCapture.log, G.on?(:steps), loc.target]
    end
  end

  test "toggling a guide with nothing selected on a map with no target says so and turns nothing on" do
    hpa_fresh_grid(["#####",
                    "#@..#",
                    "#####"])
    with_guide_state do |_loc|
      G.toggle(:steps)
      assert_equal [[[T.t(:loc_nothing_selected), true]], false], [SpeakCapture.log, G.on?]
    end
  end

  test "tells each guide on alone, and a guide on while either is" do
    { [] => [false, false, false], [:cane] => [true, false, true], [:steps] => [false, true, true],
      [:cane, :steps] => [true, true, true] }.each do |kinds, want|
      G.stop
      kinds.each { |k| G.switch(k, true) }
      assert_equal want, [G.on?(:cane), G.on?(:steps), G.on?], "with #{kinds.inspect} on"
    end
  ensure
    G.stop
  end

  test "arms a guide in silence as a target is chosen while its setting is on" do
    hpa_fresh_grid(["#####",
                    "#@.T#",
                    "#####"])
    with_guide_state do |loc|
      { :cane => :auto_guide=, :steps => :auto_steps= }.each do |kind, setting|
        G.stop
        PokeAccess::Config.send(setting, false)
        loc.instance_variable_set(:@target, $game_map.events[1])
        G.arm(kind)
        off = G.on?(kind)
        PokeAccess::Config.send(setting, true)
        G.arm(kind)
        on = G.on?(kind)
        loc.instance_variable_set(:@target, nil)
        G.stop
        G.arm(kind)
        assert_equal [false, true, false, []], [off, on, G.on?(kind), SpeakCapture.lines], "the #{kind}"
      end
    end
  end

  test "armed again, the step guide says its first leg afresh" do
    hpa_fresh_grid(CORNER)
    with_guide_state do |loc|
      PokeAccess::Config.auto_steps = true
      steps_aim(loc, $game_map.events[1])
      walk_to(loc, 1, 2)
      G.arm(:steps)
      assert_equal [leg_text(7, :dir_right)], walk_to(loc, 1, 2)
    end
  end

  test "a target gone from the map stops both guides, saying it was lost" do
    hpa_fresh_grid(CORNER)
    with_guide_state do |loc|
      steps_aim(loc, $game_map.events[1])
      G.switch(:cane, true)
      walk_to(loc, 1, 2)
      $game_map.events.delete(1)
      World.next_frame
      walk_to(loc, 2, 2)
      assert_equal [[[T.t(:loc_target_lost), true]], false], [SpeakCapture.log, G.on?]
    end
  end

  test "says a target beyond the search's reach is out of range, not that there is no way" do
    hpa_fresh_grid(["######",
                    "#@..T#",
                    "######"])
    PokeAccess::Config.route_reach = 2
    with_guide_state do |loc|
      steps_aim(loc, $game_map.events[1])
      walk_to(loc, 1, 1)
      assert_equal [[T.t(:loc_route_far), false]], SpeakCapture.log
    end
  end

  test "searches again for a target out of range only CUT_TILES tiles from where it was told, or CUT_SEC later" do
    hpa_fresh_grid(OPEN)
    PokeAccess::Config.route_reach = 2
    with_guide_state do |loc|
      with_clock do |pass|
        count_plans do |n|
          steps_aim(loc, loc::SurfaceTarget.new(19, 1, "cofre", :spot))
          walk_to(loc, 1, 2)
          told = [n[0], SpeakCapture.lines]
          (2..7).each { |x| walk_to(loc, x, 2) }
          walk_to(loc, 7, 1)
          near = n[0]
          walk_to(loc, 8, 1)
          far = n[0]
          pass.call(G::CUT_SEC / 2)
          walk_to(loc, 9, 1)
          soon = n[0]
          pass.call(G::CUT_SEC / 2)
          walk_to(loc, 10, 1)
          assert_equal [[1, [T.t(:loc_route_far)]], 1, 2, 2, 3, []],
                       [told, near, far, soon, n[0], SpeakCapture.lines],
                       "planned once, again eight tiles on, then again a second later, said only the first time"
        end
      end
    end
  end

  test "searches again at once for a target it gave up on when the regions are dropped" do
    hpa_fresh_grid(OPEN)
    PokeAccess::Config.route_reach = 2
    with_guide_state do |loc|
      with_clock do |_pass|
        count_plans do |n|
          steps_aim(loc, loc::SurfaceTarget.new(19, 1, "cofre", :spot))
          walk_to(loc, 1, 2)
          walk_to(loc, 2, 2)
          kept = n[0]
          PokeAccess::Routes::Regions.forget
          walk_to(loc, 3, 2)
          assert_equal [1, 2], [kept, n[0]]
        end
      end
    end
  end

  test "stops a walk to a target beyond the search's reach short, searching nothing" do
    hpa_fresh_grid(["#######",
                    "#@....#",
                    "#######"])
    PokeAccess::Config.route_reach = 3
    assert_equal [:cut, nil, nil, 1], walk_cut(5, 1)
  end

  test "past the node budget takes the way of the regions walked on, which answer the next search outright" do
    hpa_fresh_grid(["#######",
                    "#@....#",
                    "#######"])
    PokeAccess::Config.astar_max = 1
    assert_equal [[:found, [6, 6, 6], :regions, 1], [:found, [6, 6, 6], :regions, 0]], [walk_cut(5, 1), walk_cut(5, 1)]
  end

  test "with A*, past the node budget takes the flood's own way, the flood kept answering the next search outright" do
    hpa_fresh_grid(["#######",
                    "#@....#",
                    "#######"])
    PokeAccess::Config.path_algorithm = :astar
    PokeAccess::Config.astar_max = 1
    assert_equal [[:found, [6, 6, 6], :flood, 1], [:found, [6, 6, 6], :flood, 0]], [walk_cut(5, 1), walk_cut(5, 1)]
  end

  private

  # A leg as the guide says it: count, then direction.
  def leg_text(n, dir_key)
    T.t(:loc_leg, :n => n, :dir => T.t(dir_key))
  end

  # What one map frame of the guides with the player on (x, y) said, as [text, interrupt] pairs.
  def heard(loc, x, y)
    walk_to(loc, x, y)
    SpeakCapture.log.dup
  end

  # A route of the given presses with its transfers after the presses warps names.
  def route(dirs, warps)
    r = PokeAccess::Pathfinder::Route.new(dirs)
    r.warps = warps
    r
  end

  # A plan as the planner hands it out.
  def plan(kind, route = nil, gate = nil, stats = nil)
    PokeAccess::Routes::Plan.new(kind, route, gate, stats)
  end

  # The walk to act on (x, y) as one search operation makes it: [status, presses, what answered, searches cut short].
  def walk_cut(x, y)
    PokeAccess::Pathfinder.searching do |limits|
      w = PokeAccess::Routes::Planner.walk(x, y)
      [w.status, w.route && w.route.to_a, w.algo, limits.cuts]
    end
  end

  # Runs the block with PokeAccess.clock standing still, yielding a lambda that moves it on by the seconds given.
  def with_clock
    now = [100.0]
    real = PokeAccess.method(:clock)
    PokeAccess.define_singleton_method(:clock) { now[0] }
    yield lambda { |secs| now[0] += secs }
  ensure
    PokeAccess.define_singleton_method(:clock, real)
  end

  # Runs the block with the game numbering move as id (its PBMoves constant), which the gen-6 stub names "Mov<id>";
  # PBMoves as it was after.
  def with_move_id(move, id)
    had = PBMoves.const_defined?(move, false) ? [PBMoves.send(:remove_const, move)] : nil
    PBMoves.const_set(move, id)
    yield
  ensure
    PBMoves.send(:remove_const, move) if PBMoves.const_defined?(move, false)
    PBMoves.const_set(move, had[0]) if had
  end

  # Runs the block counting the plans the guide asks the locator for, yielding the count as a one-element array.
  def count_plans
    n = [0]
    real = PokeAccess::Locator.method(:route_plan)
    PokeAccess::Locator.define_singleton_method(:route_plan) { |t| n[0] += 1; real.call(t) }
    yield n
  ensure
    PokeAccess::Locator.define_singleton_method(:route_plan, real)
  end
end
