# The free camera's trail (Routes::Trail, Camera): its tiles as the player's presses, a ledge in one press, a wall gone
# round or the trail cut where no way round is, the way from off the trail, and the camera drawing, cutting, taking back
# and fixing it for the guides.
class TrailTest < PokeAccessTest
  Trail = PokeAccess::Routes::Trail
  Camera = PokeAccess::Camera
  T = PokeAccess::I18n
  # A room two rows deep, the player at its top left.
  ROOM = ['########',
          '#@.....#',
          '#......#',
          '########']
  # A wall at (3,1) the lower row goes round.
  WALLED = ['#######',
            '#@.#..#',
            '#.....#',
            '#######']
  # A wall at (3,1) with no way round it.
  SHUT = ['#######',
          '#@.#..#',
          '#######']
  # Water at (3,1) and (4,1) between two shores.
  SHORE = ['########',
           '#@.~~..#',
           '########']

  test "a trail the player can walk is pressed as the camera drew it" do
    hpa_fresh_grid(ROOM)
    conv = Trail.convert(row(1, 5, 1), [1, 1, 0])
    assert_equal [[6, 6, 6, 6], [], 4], [conv.route.to_a, conv.breaks, conv.reached]
  end

  test "a ledge hopped the trail's way is one press for its two tiles" do
    hpa_fresh_grid(ROOM)
    $game_map.place_ledge(3, 1, 6)
    PokeAccess::World.reset!
    conv = Trail.convert(row(1, 5, 1), [1, 1, 0])
    assert_equal [[6, 6, 6], 4], [conv.route.to_a, conv.reached]
    assert_equal [5, 1], traced(1, 1, 0, conv.route).last.tile
  ensure
    $game_map.clear_ledges
  end

  test "a wall on the trail is gone round by the shortest way to the next tile the player can stand on" do
    hpa_fresh_grid(WALLED)
    conv = Trail.convert(row(1, 5, 1), [1, 1, 0])
    b = conv.breaks[0]
    assert_equal [6, 1, 3, :detour, 4, 4], [conv.route.length, b.at, b.to, b.kind, b.presses, conv.reached]
    assert_equal [5, 1], traced(1, 1, 0, conv.route).last.tile
  end

  test "with no way round, the trail is cut where the player stops, and why" do
    hpa_fresh_grid(SHUT)
    conv = Trail.convert(row(1, 5, 1), [1, 1, 0])
    b = conv.breaks[0]
    assert_equal [[6], 1, nil, :blocked], [conv.route.to_a, b.at, b.to, b.kind]
  end

  test "from off the trail the way goes first to the tile of its progress; on it, from the player's own tile" do
    with_guide_state do
      hpa_fresh_grid(ROOM)
      tiles = row(1, 4, 1)
      $game_player.x = 1
      $game_player.y = 2
      off, p0 = Trail.plan(tiles, 0, :spec_off)
      $game_player.x = 3
      $game_player.y = 1
      on, p1 = Trail.plan(tiles, 0, :spec_on)
      assert_equal [[8, 6, 6, 6], 0, [6], 2], [off.route.to_a, p0, on.route.to_a, p1]
    end
  end

  test "a trail not begun leads first to its start, past a nearer tile of it, and counts from there once stood on" do
    with_guide_state do
      hpa_fresh_grid(ROOM)
      tiles = row(3, 6, 1)
      $game_player.x = 5
      $game_player.y = 2
      first, p0 = Trail.plan(tiles, nil, :spec_start)
      started, p1 = Trail.plan(tiles, 0, :spec_started)
      $game_player.x = 3
      $game_player.y = 1
      _on, p2 = Trail.plan(tiles, nil, :spec_begun)
      walked = [[5, 2]]
      first.route.to_a.each { |d| x, y = walked.last; walked << [x + { 4 => -1, 6 => 1 }.fetch(d, 0), y + { 2 => 1, 8 => -1 }.fetch(d, 0)] }
      assert_equal [3, 1], walked.find { |xy| xy[1] == 1 }, "the first trail tile it steps on is the start"
      assert_equal [6, 1], walked.last
      assert_equal [nil, [8, 6]], [p0, started.route.to_a]
      assert_equal [0, 0], [p1, p2]
    end
  end

  test "water on the trail with Surf known stops the walk on the shore to push off; with company barring it, cut there" do
    with_tile_world(SHORE) do
      pf = PokeAccess::Pathfinder
      with_singleton(PokeAccess::FieldMoves, :can?, proc { |_m| true }) do
        plan, _p = Trail.plan(row(1, 6, 1), 0, :spec_surf)
        barred = with_singleton(pf, :surf_with_company?, proc { false }) { Trail.convert(row(1, 6, 1), [1, 1, 0]) }
        unable = with_singleton(PokeAccess::FieldMoves, :can?, proc { |_m| false }) { Trail.convert(row(1, 6, 1), [1, 1, 0]) }
        assert_equal [:surf, [6], 6], [plan.kind, plan.route.to_a, plan.launch]
        assert_equal [[6], :company], [barred.route.to_a, barred.breaks[0].kind]
        assert_equal :blocked, unable.breaks[0].kind
      end
    end
  end

  test "ice on the trail is one press for the tiles it slides, and no way round ends on ice or a ledge" do
    hpa_fresh_grid(ROOM)
    (2..4).each { |x| $game_map.set_terrain(x, 1, 12) }
    $game_map.place_ledge(3, 2, 2)
    PokeAccess::World.reset!
    conv = Trail.convert(row(1, 6, 1), [1, 1, 0])
    assert_equal [6, 1], traced(1, 1, 0, conv.route).last.tile
    assert_operator conv.route.length, :<, 5, "the slide is pressed once"
    assert_equal [false, false, true], [Trail.stop?(3, 1), Trail.stop?(3, 2), Trail.stop?(6, 1)]
  ensure
    $game_map.clear_ledges
  end

  test "the progress follows the player along the trail, and a step off it goes back to the nearest point ahead" do
    with_trail_camera(['############',
                       '#@.........#',
                       '#..........#',
                       '############']) do
      loc = PokeAccess::Locator
      Camera.trail_toggle
      8.times { Camera.move(6, :step) }
      Camera.fix
      t = loc.target
      (2..6).each do |x|
        $game_player.x = x
        Camera.tick
      end
      progress = Camera.instance_variable_get(:@progress)
      $game_player.y = 2
      plan = loc.route_plan(t)
      assert_equal [5, [8, 6, 6, 6]], [progress, plan.route.to_a]
      $game_player.x = 8
      assert_equal [8, 6], loc.route_plan(t).route.to_a, "off the trail past the progress, back to the point nearest ahead"
    end
  end

  test "off the trail, the way back goes to the trail tile fewest presses away on foot, not the nearest through a wall" do
    with_guide_state do
      hpa_fresh_grid(['#########',
                      '#@......#',
                      '#.#####.#',
                      '#.#...#.#',
                      '#...#...#',
                      '#########'])
      tiles = row(1, 7, 1) + [[7, 2], [7, 3], [7, 4]]
      $game_player.x = 5
      $game_player.y = 3
      plan, _p = Trail.plan(tiles, 0, :spec_wall)
      assert_equal [9, [2, 6, 6]], [Trail.nearest_ahead(tiles, 0), plan.route.to_a]
    end
  end

  test "a trail drawn up a ramp keeps the bridge as the guide does, so the player on it stands on the trail" do
    with_trail_camera(ROOM) do
      Camera.instance_variable_set(:@level, 2)
      Camera.trail_toggle
      Camera.move(6, :step)
      tiles = Camera.instance_variable_get(:@trail)
      assert_equal [[1, 1, 1], [2, 1, 1]], tiles
      assert_equal 1, Camera.level
      assert_equal 1, Trail.index_of(tiles, [2, 1, 1])
      assert_equal 1, Trail.index_of([[1, 1, 2], [2, 1, 2]], [2, 1, 1]), "a raw ramp level on the trail still matches"
    end
  end

  test "a way round the regions rule out is not searched, and one cut short by the budget is said so and not kept" do
    hpa_fresh_grid(SHUT)
    searched = 0
    real = PokeAccess::Routes::Search.method(:fresh)
    conv = with_singleton(PokeAccess::Routes::Search, :fresh, proc { |*a| searched += 1; real.call(*a) }) do
      PokeAccess::Routes::Planner.reach(PokeAccess::Routes::Goal.onto(4, 1), true)
      Trail.convert(row(1, 5, 1), [1, 1, 0])
    end
    cut = PokeAccess::Routes::SearchResult.new(:cut, nil, 0, :astar)
    short = with_singleton(PokeAccess::Routes::Search, :fresh, proc { |*_a| cut }) do
      with_singleton(PokeAccess::Routes::Planner, :reach, proc { |*_a| [:yes, 0] }) do
        Trail.joined(nil, Trail.convert(row(1, 5, 1), [1, 1, 0]), 0)
      end
    end
    assert_equal [0, :blocked], [searched, conv.breaks[0].kind]
    assert_equal [:cut, true], [short.stats[:trail_cut], short.stats[:cut_short]]
    with_guide_state do
      kept = PokeAccess::Routes::Planner.instance_variable_get(:@plans).length
      PokeAccess::Routes::Planner.keep([:spec_short], short)
      assert_equal kept, PokeAccess::Routes::Planner.instance_variable_get(:@plans).length
    end
  end

  test "drawing over a tile at another bridge level does not cut the trail" do
    with_trail_camera(ROOM) do
      Camera.trail_toggle
      Camera.move(6, :step)
      Camera.instance_variable_set(:@level, 1)
      Camera.move(6, :step)
      Camera.move(4, :step)
      assert_equal [[1, 1, 0], [2, 1, 0], [3, 1, 1], [2, 1, 1]], Camera.instance_variable_get(:@trail)
    end
  end

  test "the A* from another tile than the player's finds that tile's way, and from the player's the same as without" do
    hpa_fresh_grid(ROOM)
    s = PokeAccess::Routes::Search
    goal = PokeAccess::Routes::Goal.onto(6, 2)
    mode = PokeAccess::Pathfinder.replay_mode
    own = PokeAccess::Pathfinder.searching { s.fresh(goal, mode) }
    same = PokeAccess::Pathfinder.searching { s.fresh(goal, mode, [1, 1, 0]) }
    other = PokeAccess::Pathfinder.searching { s.fresh(goal, mode, [5, 2, 0]) }
    assert_equal [own.route.to_a, [6]], [same.route.to_a, other.route.to_a]
  end

  test "drawing back over the trail cuts it there, and Backspace takes its last step back" do
    with_trail_camera(ROOM) do
      Camera.trail_toggle
      3.times { Camera.move(6, :step) }
      SpeakCapture.clear
      Camera.move(4, :step)
      cut = SpeakCapture.lines.last
      Camera.undo
      trail = Camera.instance_variable_get(:@trail)
      assert_match(/\A#{Regexp.escape(T.t(:cam_trail_cut, :n => 2))}/, cut)
      assert_equal [[[1, 1, 0], [2, 1, 0]], [2, 1]], [trail, Camera.focus]
    end
  end

  test "Enter fixes the trail: its legs, the player's presses and the way round said, the guides taken to its end" do
    with_trail_camera(WALLED) do
      loc = PokeAccess::Locator
      Camera.trail_toggle
      Camera.move(6, :step)
      Camera.move(6, :through)
      Camera.move(6, :step)
      Camera.move(6, :step)
      SpeakCapture.clear
      Camera.fix
      said = SpeakCapture.lines.last
      t = loc.target
      plan = loc.route_plan(t)
      assert_equal [false, :trail, [5, 1], 6], [Camera.active?, t.key, [t.x, t.y], plan.route.length]
      assert_includes said, T.t(:cam_trail_set, :legs => PokeAccess::Routes::Text.leg(6, 4))
      assert_includes said, T.t(:cam_trail_walk, :n => 6)
      assert_includes said, T.t(:cam_trail_detour)
      $game_player.x = 5
      assert_equal T.t(:cam_trail_end), loc.arrived_line(t)
    end
  end

  test "a trail cut short says where and why as the guides arrive there" do
    with_trail_camera(SHUT) do
      loc = PokeAccess::Locator
      Camera.trail_toggle
      Camera.move(6, :step)
      Camera.move(6, :through)
      Camera.move(6, :step)
      Camera.fix
      t = loc.target
      plan = loc.route_plan(t)
      $game_player.x = 2
      stop = loc.arrived_line(t)
      $game_player.x = 4
      at_end = loc.arrived_line(t)
      why = T.t(:cam_why_blocked)
      assert_equal [[6], T.t(:cam_trail_stop_here, :why => why), T.t(:cam_trail_end)], [plan.route.to_a, stop, at_end]
    end
  end

  private

  # The block's value with obj's singleton method meth answering as body does, the real one put back after.
  def with_singleton(obj, meth, body)
    real = obj.method(meth)
    obj.define_singleton_method(meth, &body)
    yield
  ensure
    obj.define_singleton_method(meth, real)
  end

  # The tiles of a row from x0 to x1 at y.
  def row(x0, x1, y)
    (x0..x1).map { |x| [x, y] }
  end

  # Runs the block with the camera open on the player of a grid map, the camera forgotten after.
  def with_trail_camera(rows)
    with_guide_state do
      hpa_fresh_grid(rows)
      Camera.reset
      Camera.open
      yield
    end
  ensure
    Camera.reset
  end
end
