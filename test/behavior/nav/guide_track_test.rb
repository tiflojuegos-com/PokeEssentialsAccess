# The guides follow their route by the states it passes (Guide.track) as the player walks, strays or changes map and as
# the way changes; Control.motion tells how the player moves, and ForcedMove where a forced move left them.
class GuideTrackTest < PokeAccessTest
  G = PokeAccess::Guide
  T = PokeAccess::I18n
  FM = PokeAccess::ForcedMove
  # A room two rows deep with the player at the left of its lower row.
  ROOM = ['##########',
          '#........#',
          '#@.......#',
          '##########']
  # A corridor with the player at its left end.
  CORRIDOR = ['##########',
              '#@.......#',
              '##########']
  # Two rooms a wall keeps apart, the player in the left one; the right one is entered at (5,2).
  APART = ['########',
           '#@..#..#',
           '#...#.##',
           '########']
  # A corridor from the player at (1,1) that turns down at (5,1) toward a spot at (5,3).
  TURN = ['#######',
          '#@....#',
          '#####.#',
          '#####.#',
          '#######']
  # A corridor from the player at (1,1) to water at (5,1) and (6,1), its shore at (4,1), dry ground past it.
  SHORE = ['##########',
           '#@...~~..#',
           '##########']

  test "plans the way on the first frame, and nothing more while the player walks along it" do
    hpa_fresh_grid(ROOM)
    guided do |loc, _pass|
      steps_aim(loc, loc::SurfaceTarget.new(8, 2, "cofre", :spot))
      count_plans do |n|
        said = [[1, 2], [2, 2], [3, 2]].map { |x, y| walk_to(loc, x, y) }
        assert_equal [[[leg(6, :dir_right)], [], []], 1], [said, n[0]], "the leg once, then shortening in silence"
      end
    end
  end

  test "a step back along the way plans nothing and says the leg grown back" do
    hpa_fresh_grid(ROOM)
    guided do |loc, _pass|
      steps_aim(loc, loc::SurfaceTarget.new(8, 2, "cofre", :spot))
      count_plans do |n|
        [[1, 2], [2, 2], [3, 2]].each { |x, y| walk_to(loc, x, y) }
        assert_equal [[leg(5, :dir_right)], 1], [walk_to(loc, 2, 2), n[0]]
      end
    end
  end

  test "back on the shore after a step back along the way, the guide says again where to surf" do
    guided do |loc, _pass|
      with_tile_world(SHORE) do
        steps_aim(loc, loc::SurfaceTarget.new(8, 1, "cofre", :spot))
        walk_to(loc, 1, 1)
        ashore = walk_to(loc, 4, 1)
        walk_to(loc, 3, 1)
        surf = [T.t(:loc_surf_toward, :dir => T.t(:toward_right))]
        assert_equal [surf, surf], [ashore, walk_to(loc, 4, 1)], "on the shore, then on it again"
      end
    end
  end

  test "a step off the way plans at once" do
    hpa_fresh_grid(ROOM)
    guided do |loc, _pass|
      steps_aim(loc, loc::SurfaceTarget.new(8, 2, "cofre", :spot))
      count_plans do |n|
        walk_to(loc, 1, 2)
        walk_to(loc, 2, 2)
        walk_to(loc, 2, 1)
        assert_equal 2, n[0]
      end
    end
  end

  test "a state on the way but for its bridge level counts within two presses of where the player was" do
    hpa_fresh_grid(CORRIDOR)
    guided do |loc, _pass|
      steps_aim(loc, loc::SurfaceTarget.new(8, 1, "cofre", :spot))
      count_plans do |n|
        walk_to(loc, 1, 1)
        walk_to(loc, 2, 1)
        $PokemonGlobal.bridge = 1
        walk_to(loc, 4, 1)
        near = n[0]
        walk_to(loc, 7, 1)
        assert_equal [1, 2], [near, n[0]], "two presses on, then three"
      end
    end
  end

  test "an event's change that leaves the way open plans nothing" do
    hpa_fresh_grid(CORRIDOR)
    guided do |loc, _pass|
      steps_aim(loc, loc::SurfaceTarget.new(8, 1, "cofre", :spot))
      count_plans do |n|
        walk_to(loc, 1, 1)
        PokeAccess::Pathfinder.invalidate_cache
        walk_to(loc, 1, 1)
        assert_equal 1, n[0]
      end
    end
  end

  test "half a second on, with the way still open, its checks plan nothing" do
    hpa_fresh_grid(TURN)
    guided do |loc, pass|
      steps_aim(loc, loc::SurfaceTarget.new(5, 3, "cofre", :spot))
      count_plans do |n|
        (1..4).each { |x| walk_to(loc, x, 1) }
        pass.call(0.5)
        walk_to(loc, 4, 1)
        assert_equal 1, n[0], "checked a step before the turn"
      end
    end
  end

  test "the next step closed is found half a second on, and planned around" do
    hpa_fresh_grid(ROOM)
    guided do |loc, pass|
      steps_aim(loc, loc::SurfaceTarget.new(8, 2, "cofre", :spot))
      count_plans do |n|
        walk_to(loc, 1, 2)
        $game_map.block_step(1, 2, 6)
        walk_to(loc, 1, 2)
        at_once = n[0]
        pass.call(0.5)
        walk_to(loc, 1, 2)
        assert_equal [1, 2], [at_once, n[0]]
      end
    end
  end

  test "a step closed up to sixteen presses ahead is found half a second on, one further is not" do
    long = ['#' * 24, '#@' + '.' * 21 + '#', '#' * 24]
    { 16 => 2, 17 => 1 }.each do |press, want|
      hpa_fresh_grid(long)
      guided do |loc, pass|
        steps_aim(loc, loc::SurfaceTarget.new(23, 1, "cofre", :spot))
        count_plans do |n|
          walk_to(loc, 1, 1)
          $game_map.block_step(press, 1, 6)
          pass.call(0.5)
          walk_to(loc, 1, 1)
          assert_equal want, n[0], "press #{press} closed"
        end
      end
    end
  end

  test "the way past a pad says the transfer between its legs" do
    hpa_fresh_grid(['#########',
                    '#@..#...#',
                    '#########'])
    guided do |loc, _pass|
      pad_and_target
      plan = loc.route_plan($game_map.events[61])
      steps = "#{T.t(:loc_leg_transfer, :leg => leg(2, :dir_right))}, #{leg(1, :dir_right)}"
      assert_equal [[6, 6, 6], [1], T.t(:loc_route, :steps => steps)],
                   [plan.route, plan.route.warps, PokeAccess::Routes::Text.line(plan)]
    end
  end

  test "the step guide's first leg ends on the transfer, then shortens in silence" do
    hpa_fresh_grid(['#########',
                    '#@..#...#',
                    '#########'])
    guided do |loc, _pass|
      steps_aim(loc, pad_and_target)
      assert_equal [[T.t(:loc_leg_transfer, :leg => leg(2, :dir_right))], []], [walk_to(loc, 1, 1), walk_to(loc, 2, 1)]
    end
  end

  test "landing past the pad, the leg there is said with no new search and the guide still on" do
    hpa_fresh_grid(['#########',
                    '#@..#...#',
                    '#########'])
    guided do |loc, _pass|
      steps_aim(loc, pad_and_target)
      walk_to(loc, 1, 1)
      walk_to(loc, 2, 1)
      count_plans do |n|
        assert_equal [[leg(1, :dir_right)], 0, true], [walk_to(loc, 5, 1), n[0], G.on?(:steps)]
      end
    end
  end

  test "a target with no way is not searched for again while the player walks about its region" do
    hpa_fresh_grid(APART)
    guided do |loc, _pass|
      steps_aim(loc, World.event(:id => 62, :x => 6, :y => 1))
      count_plans do |n|
        first = walk_to(loc, 1, 1)
        [[2, 1], [2, 2], [3, 2]].each { |x, y| walk_to(loc, x, y) }
        assert_equal [[T.t(:loc_no_route)], 1], [first, n[0]]
      end
    end
  end

  test "an event's end has a target with no way planned for again, the player standing still" do
    hpa_fresh_grid(APART)
    guided do |loc, _pass|
      steps_aim(loc, World.event(:id => 62, :x => 6, :y => 1))
      count_plans do |n|
        walk_to(loc, 1, 1)
        G.event_ended
        assert_equal [[], 2], [walk_to(loc, 1, 1), n[0]], "planned again, the no way already said"
      end
    end
  end

  test "an event's end has a target with no way planned for again at the next step about its region" do
    hpa_fresh_grid(APART)
    guided do |loc, _pass|
      steps_aim(loc, World.event(:id => 62, :x => 6, :y => 1))
      count_plans do |n|
        walk_to(loc, 1, 1)
        G.event_ended
        assert_equal [[], 2], [walk_to(loc, 2, 1), n[0]], "planned again, the no way already said"
      end
    end
  end

  test "once the regions are made anew, the next step searches for a target with no way again" do
    hpa_fresh_grid(APART)
    guided do |loc, _pass|
      steps_aim(loc, World.event(:id => 62, :x => 6, :y => 1))
      count_plans do |n|
        walk_to(loc, 1, 1)
        PokeAccess::Routes::Regions.forget
        walk_to(loc, 2, 1)
        assert_equal 2, n[0]
      end
    end
  end

  test "taken into the target's region, the guide searches again and finds the way" do
    hpa_fresh_grid(APART)
    guided do |loc, _pass|
      steps_aim(loc, World.event(:id => 62, :x => 6, :y => 1))
      count_plans do |n|
        walk_to(loc, 1, 1)
        assert_equal [[leg(1, :dir_up)], 2], [walk_to(loc, 5, 2), n[0]]
      end
    end
  end

  test "a target out of range is not tried again within eight tiles of where it was told, and is at eight" do
    hpa_fresh_grid(['#' * 30, '#@' + '.' * 27 + '#', '#' * 30])
    PokeAccess::Config.route_reach = 10
    guided do |loc, _pass|
      steps_aim(loc, World.event(:id => 64, :x => 25, :y => 1))
      count_plans do |n|
        first = walk_to(loc, 1, 1)
        (2..8).each { |x| walk_to(loc, x, 1) }
        within = n[0]
        walk_to(loc, 9, 1)
        assert_equal [[T.t(:loc_route_far)], 1, 2], [first, within, n[0]]
      end
    end
  end

  test "a search cut short is tried again at the player's first step a second on" do
    hpa_fresh_grid(['#' * 30, '#@' + '.' * 27 + '#', '#' * 30])
    PokeAccess::Config.route_reach = 10
    guided do |loc, pass|
      steps_aim(loc, World.event(:id => 64, :x => 25, :y => 1))
      count_plans do |n|
        walk_to(loc, 1, 1)
        pass.call(0.99)
        walk_to(loc, 2, 1)
        within = n[0]
        pass.call(0.02)
        walk_to(loc, 3, 1)
        assert_equal [1, 2], [within, n[0]]
      end
    end
  end

  test "a search cut short is tried again a second on with the player standing still, and the way found is said" do
    hpa_fresh_grid(CORRIDOR)
    guided do |loc, pass|
      steps_aim(loc, World.event(:id => 62, :x => 6, :y => 1))
      cut_first(loc) do |n|
        first = walk_to(loc, 1, 1)
        pass.call(0.6)
        within = [walk_to(loc, 1, 1), n[0]]
        pass.call(0.6)
        assert_equal [[T.t(:loc_route_gave_up)], [[], 1], [leg(4, :dir_right)], 2],
                     [first, within, walk_to(loc, 1, 1), n[0]]
      end
    end
  end

  test "a target with no way just selected, its line ending with that, is not told it again by the guide" do
    hpa_fresh_grid(APART)
    guided do |loc, _pass|
      G.stop
      guide_frame
      loc.instance_variable_set(:@target, World.event(:id => 62, :x => 6, :y => 1))
      PokeAccess.speak("npc, 1 de 1, 5 derecha, #{T.t(:loc_no_route)}", true)
      G.switch(:steps, true)
      assert_equal [], walk_to(loc, 1, 1)
    end
  end

  test "arriving in the frame a forced move's notice was said, the arrival is queued after it" do
    hpa_fresh_grid(CORRIDOR)
    guided do |loc, _pass|
      steps_aim(loc, World.event(:id => 62, :x => 6, :y => 1))
      walk_to(loc, 1, 1)
      SpeakCapture.clear
      PokeAccess.speak(moved(:moved_right, 4), false)
      $game_player.x = 5
      guide_frame
      assert_equal [[moved(:moved_right, 4), false], [T.t(:loc_arrived), false]], SpeakCapture.log
    end
  end

  test "a new target's first leg is said even the same way and shorter" do
    hpa_fresh_grid(CORRIDOR)
    guided do |loc, _pass|
      steps_aim(loc, loc::SurfaceTarget.new(8, 1, "lejos", :spot))
      far = walk_to(loc, 1, 1)
      loc.instance_variable_set(:@target, loc::SurfaceTarget.new(4, 1, "cerca", :spot))
      assert_equal [[leg(6, :dir_right)], [leg(2, :dir_right)]], [far, walk_to(loc, 1, 1)]
    end
  end

  test "a target that steps right after the plan is not planned for at once" do
    hpa_fresh_grid(CORRIDOR)
    guided do |loc, _pass|
      walker = World.event(:id => 63, :x => 6, :y => 1)
      steps_aim(loc, walker)
      count_plans do |n|
        walk_to(loc, 1, 1)
        walker.x = 7
        walk_to(loc, 1, 1)
        assert_equal 1, n[0]
      end
    end
  end

  test "half a second after the plan, a target that moved is planned for again" do
    hpa_fresh_grid(CORRIDOR)
    guided do |loc, pass|
      walker = World.event(:id => 63, :x => 6, :y => 1)
      steps_aim(loc, walker)
      count_plans do |n|
        walk_to(loc, 1, 1)
        walker.x = 7
        pass.call(0.5)
        walk_to(loc, 1, 1)
        assert_equal 2, n[0]
      end
    end
  end

  test "where the way to where the target was runs out, it plans at once and says no arrival" do
    hpa_fresh_grid(CORRIDOR)
    guided do |loc, _pass|
      walker = World.event(:id => 63, :x => 6, :y => 1)
      steps_aim(loc, walker)
      count_plans do |n|
        walk_to(loc, 1, 1)
        walker.x = 8
        assert_equal [[], 2], [walk_to(loc, 5, 1), n[0]]
      end
    end
  end

  test "where the way turns the cane chimes at once toward the turn, though not within its gap of the last chime" do
    hpa_fresh_grid(TURN)
    guided do |loc, pass|
      with_cue_log do |log|
        guide_aim(loc, loc::SurfaceTarget.new(5, 3, "cofre", :spot))
        walk_to(loc, 1, 1)
        pass.call(0.05)
        walk_to(loc, 5, 1)
        too_soon = log.length
        pass.call(0.11)
        walk_to(loc, 5, 1)
        assert_equal [1, ["pa_guide_c", 70]], [too_soon, [cue_name(log.last), log.last[2]]], "then down, at once"
      end
    end
  end

  test "along the way, inside its interval, the cane waits" do
    hpa_fresh_grid(TURN)
    guided do |loc, pass|
      with_cue_log do |log|
        guide_aim(loc, loc::SurfaceTarget.new(5, 3, "cofre", :spot))
        walk_to(loc, 1, 1)
        pass.call(0.2)
        walk_to(loc, 3, 1)
        assert_equal 1, log.length
      end
    end
  end

  test "a jump is a leg of its own, said where it takes off, cutting the leg before it, with its sound toward it" do
    jump_shaft
    guided do |loc, _pass|
      steps_aim(loc, loc::SurfaceTarget.new(1, 6, "cofre", :spot))
      with_cue_log do |log|
        start = walk_to(loc, 1, 1)
        sounds = heard(log)
        walk_to(loc, 1, 2)
        assert_equal [[leg(1, :dir_down)], [], [[jump(:dir_down), true]], [["pa_jump_c", 70, 70]]],
                     [start, sounds, SpeakCapture.log, heard(log)]
      end
    end
  end

  test "a jump is said once, and the leg past it where it lands" do
    jump_shaft
    guided do |loc, _pass|
      steps_aim(loc, loc::SurfaceTarget.new(1, 6, "cofre", :spot))
      with_cue_log do |log|
        walk_to(loc, 1, 1)
        walk_to(loc, 1, 2)
        again = walk_to(loc, 1, 2)
        assert_equal [[], [leg(1, :dir_down)], 1], [again, walk_to(loc, 1, 4), log.length]
      end
    end
  end

  test "a jump right ahead as the guide starts is its first leg, said on its first frame, cutting nothing before it" do
    jump_shaft
    guided do |loc, _pass|
      steps_aim(loc, loc::SurfaceTarget.new(1, 6, "cofre", :spot))
      walk_to(loc, 1, 2)
      assert_equal [[jump(:dir_down), false]], SpeakCapture.log
    end
  end

  test "at a corner where the way hops a ledge, the guide says the jump and then the presses past it, as the route key" do
    hpa_fresh_grid(['######', '#@...#', '####.#', '####.#', '####.#', '####.#', '######'])
    $game_map.place_ledge(4, 2, 2)
    PokeAccess::Pathfinder.invalidate_cache(true)
    guided do |loc, _pass|
      steps_aim(loc, loc::SurfaceTarget.new(4, 5, "cofre", :spot))
      said = [[1, 1], [2, 1], [3, 1], [4, 1], [4, 3], [4, 4]].map { |x, y| walk_to(loc, x, y) }
      assert_equal [[leg(3, :dir_right)], [], [], [jump(:dir_down)], [leg(1, :dir_down)], [T.t(:loc_arrived)]], said
    end
  end

  test "on ice the guide names the slide as a leg of its own between the steps, as the route key" do
    hpa_fresh_grid(['########', '#@.....#', '########'])
    [3, 4].each { |x| $game_map.set_terrain(x, 1, 12) }
    PokeAccess::Pathfinder.invalidate_cache(true)
    guided do |loc, _pass|
      steps_aim(loc, loc::SurfaceTarget.new(7, 1, "cofre", :spot))
      said = [[1, 1], [2, 1], [5, 1]].map { |x, y| walk_to(loc, x, y) }
      slide = T.t(:loc_slide_leg, :dir => T.t(:dir_right))
      assert_equal [[leg(1, :dir_right)], [slide], [leg(1, :dir_right)]], said
    end
  ensure
    $game_map.clear_ledges
  end

  test "a map change turns both guides off, saying only the new map's name" do
    hpa_fresh_grid(CORRIDOR)
    guided do |loc, _pass|
      { 35 => "Mapa 35", 40 => "Mapa 40" }.each do |mid, name|
        steps_aim(loc, loc::SurfaceTarget.new(4, 1, "cofre", :spot))
        G.switch(:cane, true)
        walk_to(loc, 1, 1)
        SpeakCapture.clear
        $game_map.map_id = mid
        loc.announce_map_change
        assert_equal [[[name, false]], false], [SpeakCapture.log, G.on?], "into map #{mid}"
      end
    end
  end

  test "the player's motion ranks a forced move over a slide, a slide over a jump, a jump over a step" do
    { [] => :still, [:moving] => :moving, [:moving, :jumping] => :jumping, [:jumping, :sliding] => :sliding,
      [:moving, :ice] => :sliding, [:jumping, :sliding, :forced] => :forced }.each do |flags, want|
      assert_equal want, motion_with(flags), flags.inspect
    end
  end

  test "with no player, the motion is standing still" do
    was = $game_player
    begin
      $game_player = nil
      got = PokeAccess::Control.motion
    ensure
      $game_player = was
    end
    assert_equal :still, got
  end

  test "once control is back, a forced move says how far it took the player from where it began" do
    with_forced_moves do
      stand(2, 5)
      carry([[2, 4], [2, 3], [2, 2], [3, 2], [4, 2]])
      dirs = T.t(:list_and, :rest => T.t(:moved_up, :n => 3), :last => T.t(:moved_right, :n => 2))
      assert_equal [[T.t(:loc_moved, :dirs => dirs), false]], release
    end
  end

  test "a forced move waits for a message holding the player to close" do
    with_forced_moves do
      stand(2, 5)
      carry([[2, 4], [2, 3]])
      $game_player.move_route_forcing = false
      held = nil
      begin
        $game_temp.message_window_showing = true
        SpeakCapture.clear
        FM.tick
        held = SpeakCapture.lines.dup
      ensure
        $game_temp.message_window_showing = nil
      end
      assert_equal [[], [[moved(:moved_up, 2), false]]], [held, release]
    end
  end

  test "the info key keeps the way a forced move went, leg by leg, while the player stands where it ended" do
    with_forced_moves do
      stand(2, 5)
      carry([[2, 4], [2, 3], [2, 2], [3, 2], [4, 2]])
      release
      legs = T.t(:list_and, :rest => leg(3, :dir_up), :last => leg(2, :dir_right))
      assert_equal T.t(:loc_moved_path, :legs => legs), FM.line
    end
  end

  test "walking off drops the forced move's way: back on that tile, the info key has it no more" do
    with_forced_moves do
      stand(2, 5)
      carry([[2, 4], [2, 3]])
      release
      stand(3, 3)
      off = FM.line
      stand(2, 3)
      assert_equal [nil, nil], [off, FM.line]
    end
  end

  test "a slide says so on the info key" do
    with_forced_moves do
      stand(2, 2)
      $PokemonGlobal.sliding = true
      carry([[2, 3], [2, 4], [3, 4]], false)
      $PokemonGlobal.sliding = false
      said = release
      dirs = T.t(:list_and, :rest => T.t(:moved_down, :n => 2), :last => T.t(:moved_right, :n => 1))
      legs = T.t(:list_and, :rest => leg(2, :dir_down), :last => leg(1, :dir_right))
      assert_equal [[[T.t(:loc_moved, :dirs => dirs), false]], T.t(:loc_slid, :legs => legs)], [said, FM.line]
    end
  end

  test "a spin tile's spin is a forced move: once it stops, how far it took the player is said" do
    with_forced_moves do
      with_global_flag(:spinning) do |set|
        stand(1, 1)
        set.call(true)
        carry([[2, 1], [3, 1], [4, 1], [5, 1], [5, 2], [5, 3], [5, 4]], false)
        set.call(false)
        dirs = T.t(:list_and, :rest => T.t(:moved_down, :n => 3), :last => T.t(:moved_right, :n => 4))
        assert_equal [[T.t(:loc_moved, :dirs => dirs), false]], release
      end
    end
  end

  test "Advanced Items' rock climb is a forced move: once it ends, how far it took the player is said" do
    with_forced_moves do
      with_global_flag(:forced_rockclimb?) do |set|
        stand(2, 5)
        set.call(true)
        carry([[2, 4], [2, 3], [2, 2], [2, 1]], false)
        set.call(false)
        assert_equal [[moved(:moved_up, 4), false]], release
      end
    end
  end

  test "while a plugin carries the player along, a spin or a rock climb, the guides wait" do
    [:spinning, :forced_rockclimb?].each do |flag|
      with_global_flag(flag) do |set|
        set.call(true)
        assert_equal true, PokeAccess::Control.carried?, flag.to_s
      end
    end
  end

  test "a forced move after a slide is told as a move, not a slide" do
    with_forced_moves do
      stand(2, 2)
      $PokemonGlobal.sliding = true
      carry([[2, 3]], false)
      $PokemonGlobal.sliding = false
      release
      carry([[2, 4]])
      release
      assert_equal T.t(:loc_moved_path, :legs => leg(1, :dir_down)), FM.line
    end
  end

  test "a forced move that ends where it began says nothing and keeps no way" do
    with_forced_moves do
      stand(2, 5)
      carry([[2, 4], [2, 5]])
      assert_equal [[], nil], [release, FM.line]
    end
  end

  test "a hop of two tiles in one frame counts in the forced move" do
    with_forced_moves do
      stand(2, 5)
      carry([[2, 3]])
      assert_equal [[[moved(:moved_up, 2), false]], T.t(:loc_moved_path, :legs => leg(2, :dir_up))], [release, FM.line]
    end
  end

  test "a move of three tiles in one frame, no jump, starts the forced move afresh where it landed" do
    with_forced_moves do
      stand(2, 5)
      carry([[2, 4], [4, 3], [4, 2]])
      assert_equal [[moved(:moved_up, 1), false]], release
    end
  end

  test "a forced jump of three tiles, which lands in one frame, counts in the forced move with the steps after it" do
    with_forced_moves do
      stand(2, 5)
      begin
        $game_player.jumping = true
        carry([[5, 5]])
      ensure
        $game_player.jumping = false
      end
      carry([[6, 5], [7, 5]])
      assert_equal [[[moved(:moved_right, 5), false]], T.t(:loc_moved_path, :legs => leg(5, :dir_right))],
                   [release, FM.line]
    end
  end

  test "a run the engine walks in one update, as down a waterfall, is a forced move told once the player stands" do
    with_forced_moves do
      said = drawn_run([9, 2], [9, 7])
      assert_equal [[[moved(:moved_down, 5), false]], T.t(:loc_moved_path, :legs => leg(5, :dir_down))],
                   [said, FM.line]
    end
  end

  test "a transfer within the map, the drawn player landing with it, is no forced move" do
    with_forced_moves do
      said = drawn_run([9, 2], [9, 7], true)
      side = PokeAccess::Locator.cardinal_of(9, 7)
      told = moved(:moved_down, 5)
      told += "; " + T.t(:loc_teleport_zone, :zone => T.t(side)) if side
      assert_equal [[[told, false]], nil], [said, FM.line]
    end
  end

  test "walking off where a forced move ended and back, the info key has its way no more" do
    with_forced_moves do
      stand(2, 5)
      carry([[2, 4], [2, 3]])
      release
      stand(3, 3)
      stand(2, 3)
      assert_nil FM.line
    end
  end

  test "a forced move off where the last one ended and back says nothing and drops the last one's way" do
    with_forced_moves do
      stand(2, 5)
      carry([[2, 4], [2, 3]])
      release
      carry([[3, 3], [2, 3]])
      assert_equal [[], nil], [release, FM.line]
    end
  end

  test "a step onto ice with the way on from it closed is the player's own: no slide, nothing said" do
    hpa_fresh_grid(CORRIDOR)
    with_forced_moves do
      $game_map.set_terrain(2, 1, 12)
      $game_map.block_step(2, 1, 6)
      $game_player.direction = 6
      stand(1, 1)
      motion = mid_step { stand(2, 1); PokeAccess::Control.motion }
      assert_equal [:moving, [], nil], [motion, release, FM.line]
    end
  end

  test "a step onto ice with the way on from it open starts a slide" do
    hpa_fresh_grid(CORRIDOR)
    with_forced_moves do
      $game_map.set_terrain(2, 1, 12)
      $game_player.direction = 6
      stand(1, 1)
      assert_equal :sliding, mid_step { stand(2, 1); PokeAccess::Control.motion }
    end
  end

  test "while the engine carries the player on by itself (v21's forced movement: a waterfall), the guides wait" do
    hpa_fresh_grid(ROOM)
    guided do |loc, _pass|
      steps_aim(loc, loc::SurfaceTarget.new(8, 2, "cofre", :spot))
      count_plans do |n|
        walk_to(loc, 1, 2)
        said = engine_carrying { walk_to(loc, 2, 1) }
        assert_equal [[], 1], [said, n[0]]
      end
    end
  end

  test "partway up a side stair, where the engine's answers cannot be kept, the guides wait" do
    hpa_fresh_grid(ROOM)
    guided do |loc, _pass|
      steps_aim(loc, loc::SurfaceTarget.new(8, 2, "cofre", :spot))
      count_plans do |n|
        walk_to(loc, 1, 2)
        said = mid_stair { walk_to(loc, 2, 1) }
        assert_equal [[], 1], [said, n[0]]
      end
    end
  end

  test "a route laid where a dropped one was is read afresh, though Ruby hands it the dropped one's object id" do
    hpa_fresh_grid(CORRIDOR)
    guided do |loc, pass|
      walker = World.event(:id => 63, :x => 6, :y => 1)
      guide_aim(loc, walker)
      walk_to(loc, 1, 1)
      old_id = G.instance_variable_get(:@plan).route.object_id
      walker.x = 8
      pass.call(0.5)
      real = loc.method(:route_plan)
      loc.define_singleton_method(:route_plan) do |t|
        made = real.call(t)
        made.route.define_singleton_method(:object_id) { old_id } if made.route
        made
      end
      begin
        walk_to(loc, 1, 1)
      ensure
        loc.define_singleton_method(:route_plan, real)
      end
      assert_equal G.instance_variable_get(:@plan).route.to_a, G.remaining.to_a
    end
  end

  test "a map change partway starts the forced move afresh on the new map" do
    with_forced_moves do
      stand(2, 5)
      carry([[2, 4]])
      begin
        $game_map.map_id = 2
        carry([[7, 7], [7, 6]])
        said = release
      ensure
        $game_map.map_id = 1
      end
      assert_equal [[moved(:moved_up, 1), false]], said
    end
  end

  test "a forced move that ends on another map says nothing" do
    with_forced_moves do
      stand(2, 5)
      carry([[2, 4], [2, 3]])
      begin
        $game_map.map_id = 2
        $game_player.x = 6
        $game_player.y = 6
        said = release
      ensure
        $game_map.map_id = 1
      end
      assert_equal [], said
    end
  end

  test "with no player, a frame does nothing and the info key has nothing" do
    with_forced_moves do
      stand(2, 5)
      carry([[2, 4]])
      release
      was = $game_player
      begin
        $game_player = nil
        SpeakCapture.clear
        FM.tick
        got = [SpeakCapture.lines, FM.line]
      ensure
        $game_player = was
      end
      assert_equal [[], nil], got
    end
  end

  test "a reset drops the way kept for the info key" do
    with_forced_moves do
      stand(2, 5)
      carry([[2, 4]])
      release
      FM.reset
      assert_nil FM.line
    end
  end

  test "a reset forgets where the player stood: a forced move from its first frame counts from there" do
    with_forced_moves do
      stand(2, 5)
      FM.reset
      carry([[2, 4], [2, 3]])
      assert_equal [[moved(:moved_up, 1), false]], release
    end
  end

  private

  # Runs the block in with_guide_state with the clock stopped (with_clock), yielding the locator and the clock's lambda.
  def guided
    with_guide_state { |loc| with_clock { |pass| yield loc, pass } }
  end

  # Runs the block with PokeAccess.clock standing still, yielding a lambda that moves it on by the seconds given.
  def with_clock
    now = [1000.0]
    real = PokeAccess.method(:clock)
    PokeAccess.define_singleton_method(:clock) { now[0] }
    yield lambda { |secs| now[0] += secs }
  ensure
    PokeAccess.define_singleton_method(:clock, real)
  end

  # Counts the plans made (Routes::Planner.plan) while the block runs, yielded as a one-element array.
  def count_plans
    pl = PokeAccess::Routes::Planner
    real = pl.method(:plan)
    n = [0]
    pl.define_singleton_method(:plan) { |*a| n[0] += 1; real.call(*a) }
    yield n
  ensure
    pl.define_singleton_method(:plan, real)
  end

  # Runs the block with the locator's first route plan a search cut short, yielding the count of plans asked for.
  def cut_first(loc)
    real = loc.method(:route_plan)
    n = [0]
    loc.define_singleton_method(:route_plan) do |t|
      n[0] += 1
      n[0] == 1 ? PokeAccess::Routes::Plan.new(:cut, nil, nil, {}, nil) : real.call(t)
    end
    yield n
  ensure
    loc.define_singleton_method(:route_plan, real)
  end

  # The step guide's leg of n presses toward the direction named by dir_key.
  def leg(n, dir_key)
    T.t(:loc_leg, :n => n, :dir => T.t(dir_key))
  end

  # The jump toward the direction named by dir_key.
  def jump(dir_key)
    T.t(:loc_jump, :dir => T.t(dir_key))
  end

  # The cues logged by with_cue_log as [file, volume, pitch].
  def heard(log)
    log.map { |e| [cue_name(e), e[1], e[2]] }
  end

  # A transfer pad at (3,1) landing on (5,1), and the target at (7,1) past it.
  def pad_and_target
    World.touch(:id => 60, :x => 3, :y => 1, :list => [TestCmd.new(201, [0, $game_map.map_id, 5, 1])])
    target = World.event(:id => 61, :x => 7, :y => 1)
    PokeAccess::Pathfinder.invalidate_cache(true)
    target
  end

  # A shaft down from the player at (1,1), with a ledge at (1,3) hopped downward onto (1,4).
  def jump_shaft
    hpa_fresh_grid(['###',
                    '#@#',
                    '#.#',
                    '#.#',
                    '#.#',
                    '#.#',
                    '#.#',
                    '###'])
    $game_map.place_ledge(1, 3, 2)
    PokeAccess::Pathfinder.invalidate_cache(true)
  end

  # Control.motion with the player moving as flags say (:moving, :jumping, :sliding, :ice underfoot while moving,
  # :forced by a move route), each put back after.
  def motion_with(flags)
    p = $game_player
    def p.moving?; true; end if flags.include?(:moving) || flags.include?(:ice)
    p.jumping = true if flags.include?(:jumping)
    $PokemonGlobal.sliding = true if flags.include?(:sliding)
    $game_map.set_terrain(p.x, p.y, 12) if flags.include?(:ice)
    if flags.include?(:forced)
      class << p; attr_accessor :move_route_forcing; end
      p.move_route_forcing = true
    end
    PokeAccess::Control.motion
  ensure
    p.jumping = false
    $PokemonGlobal.sliding = false
    $game_map.clear_ledges
    p.singleton_class.send(:remove_method, :moving?) if p.singleton_methods.include?(:moving?)
    drop_forcing(p)
  end

  # Runs the block with the player able to be driven by a move route (move_route_forcing), as the engine's player is;
  # the flags and the forced move's state are dropped after.
  def with_forced_moves
    class << $game_player; attr_accessor :move_route_forcing; end
    FM.reset
    yield
  ensure
    $PokemonGlobal.sliding = false
    drop_forcing($game_player)
    FM.reset
  end

  # Takes the move_route_forcing accessor and the flag it set off the player, so no later test finds it driven.
  def drop_forcing(p)
    [:move_route_forcing, :move_route_forcing=].each do |m|
      p.singleton_class.send(:remove_method, m) if p.singleton_methods.include?(m)
    end
    p.send(:remove_instance_variable, :@move_route_forcing) if p.instance_variable_defined?(:@move_route_forcing)
  end

  # Puts the player on (x, y) with control and runs one frame of the forced move.
  def stand(x, y)
    $game_player.x = x
    $game_player.y = y
    FM.tick
  end

  # Moves the player through tiles, one frame of the forced move each, with the move route driving it unless forced is
  # false.
  def carry(tiles, forced = true)
    $game_player.move_route_forcing = forced
    tiles.each do |x, y|
      $game_player.x = x
      $game_player.y = y
      FM.tick
    end
  end

  # Hands control back and runs one frame of the forced move, returning what it said as [text, interrupt] pairs.
  def release
    $game_player.move_route_forcing = false
    SpeakCapture.clear
    FM.tick
    SpeakCapture.log.dup
  end

  # Runs whole map frames (Frame.run) as the engine moves the player from tile a to tile b in one update, the drawn
  # player then walking after it a quarter tile a frame until it stands there, or landing with it (transfer); returns
  # what was said from that update on, as [text, interrupt] pairs.
  def drawn_run(a, b, transfer = false)
    p = $game_player
    at = [a[0] * 128, a[1] * 128]
    class << p; attr_accessor :pa_drawn; end
    p.pa_drawn = at
    def p.real_x; pa_drawn[0]; end
    def p.real_y; pa_drawn[1]; end
    def p.moving?; pa_drawn != [x * 128, y * 128]; end
    p.x, p.y = a
    2.times { PokeAccess::Frame.run }
    SpeakCapture.clear
    p.x, p.y = b
    p.pa_drawn = [b[0] * 128, b[1] * 128] if transfer
    PokeAccess::Frame.run
    toward = lambda { |v, t| v < t ? [v + 32, t].min : [v - 32, t].max }
    while p.moving?
      p.pa_drawn = [toward.call(p.pa_drawn[0], b[0] * 128), toward.call(p.pa_drawn[1], b[1] * 128)]
      PokeAccess::Frame.run
    end
    PokeAccess::Frame.run
    SpeakCapture.log.dup
  ensure
    [:real_x, :real_y, :moving?, :pa_drawn, :pa_drawn=].each do |m|
      p.singleton_class.send(:remove_method, m) if p.singleton_methods.include?(m)
    end
  end

  # The forced move's notice for n tiles one way, the way named by key (:moved_up, :moved_right...).
  def moved(key, n)
    T.t(:loc_moved, :dirs => T.t(key, :n => n))
  end

  # Runs the block with the player partway through a step (moving?), put back after.
  def mid_step
    p = $game_player
    def p.moving?; true; end
    yield
  ensure
    p.singleton_class.send(:remove_method, :moving?) if p.singleton_methods.include?(:moving?)
  end

  # Runs the block with $PokemonGlobal answering name, a plugin's flag, as the yielded lambda sets it (off at first);
  # the reader goes after.
  def with_global_flag(name)
    g = $PokemonGlobal
    g.instance_variable_set(:@pa_flag, false)
    g.define_singleton_method(name) { @pa_flag }
    yield lambda { |on| g.instance_variable_set(:@pa_flag, on) }
  ensure
    g.singleton_class.send(:remove_method, name) if g.singleton_methods.include?(name)
    g.send(:remove_instance_variable, :@pa_flag) if g.instance_variable_defined?(:@pa_flag)
  end

  # Runs the block with v21's $PokemonGlobal.forced_movement? true, as a waterfall's descent has it, put back after.
  def engine_carrying
    g = $PokemonGlobal
    def g.forced_movement?; true; end
    yield
  ensure
    g.singleton_class.send(:remove_method, :forced_movement?) if g.singleton_methods.include?(:forced_movement?)
  end

  # Runs the block with the player partway up a side stair (Marin's on_middle_of_stair?), put back after.
  def mid_stair
    p = $game_player
    def p.on_middle_of_stair?; true; end
    yield
  ensure
    p.singleton_class.send(:remove_method, :on_middle_of_stair?) if p.singleton_methods.include?(:on_middle_of_stair?)
  end
end
