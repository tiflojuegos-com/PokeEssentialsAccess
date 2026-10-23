# Realidea's beam rooms (games/realidea/lasers.rb) on boards transcribed from Map020 and Map191-193: the model against
# launchLaser's; what a turn, a shot, the info key, the assist and Bronzor say; how the locator names and files pieces.

# The game's laser system (0213 Sistema Laser), down to what the mod reads: rotateEvent turns an event a quarter, and
# launchLaser walks the beam from event id over steps + 1 moves (the map wrapping it round), turning it on every event of
# events it meets; each move ends on a frame of the map, in which its events take their turn (a wandering Bronzor steps
# on). True on reaching the receptor, false on reaching an edge, nil when its steps run out.
def rotateEvent(id)
  ev = $game_map.events[id]
  ev.direction = { 2 => 4, 4 => 8, 8 => 6, 6 => 2 }[ev.direction]
end

def launchLaser(id, laser_beam, receptor, events, steps)
  ev = $game_map.events
  direction = ev[id].direction
  x = ev[id].x
  y = ev[id].y
  (0..steps).each do
    x = (x + { 4 => -1, 6 => 1 }.fetch(direction, 0)) % $game_map.width
    y = (y + { 8 => -1, 2 => 1 }.fetch(direction, 0)) % $game_map.height
    events.each do |i|
      next unless x == ev[i].x && y == ev[i].y
      falling = ev[i].direction == 2 || ev[i].direction == 8
      direction = (falling ? { 2 => 6, 4 => 8, 6 => 2, 8 => 4 } : { 2 => 4, 4 => 2, 6 => 8, 8 => 6 })[direction]
    end
    ev.each_value { |e| e.update if e.respond_to?(:update) }
    return true if x == ev[receptor].x && y == ev[receptor].y
    return false if x == $game_map.width || x == 0 || y == $game_map.height || y == 0
  end
  nil
end

lasers = File.join(Harness::ROOT, "games", "realidea", "lasers.rb")
eval(Harness.source(lasers), TOPLEVEL_BINDING, lasers)

class RealideaLasersTest < PokeAccessTest
  Lasers = PokeAccess::RealideaLasers
  # Each room as its map lays it out: the small crystal (event 3) [x, y, facing], the large one (event 1) [x, y], the
  # steps the game gives launchLaser, the mirrors id => [x, y, facing] as the room starts, and in the two rooms where
  # Bronzor (event 14) stands in for a prism once beaten, the gap it settles in.
  BOARDS = {
    20 => { :from => [8, 7, 6], :to => [17, 8], :steps => 20,
            :mirrors => { 4 => [11, 7, 4], 5 => [11, 11, 2], 6 => [17, 11, 8] } },
    191 => { :from => [8, 7, 8], :to => [17, 7], :steps => 38,
             :mirrors => { 18 => [13, 5, 4], 4 => [8, 5, 4], 15 => [10, 7, 4], 16 => [10, 10, 2], 5 => [13, 10, 2],
                           14 => [14, 5, 4], 19 => [15, 5, 2], 17 => [15, 7, 2], 20 => [17, 11, 2], 13 => [14, 11, 4] } },
    192 => { :from => [8, 7, 6], :to => [17, 8], :steps => 40, :gap => [11, 7],
             :mirrors => { 14 => [20, 16, 2], 5 => [11, 11, 2], 6 => [14, 11, 2], 15 => [14, 5, 2], 18 => [17, 12, 2],
                           16 => [9, 5, 2], 17 => [9, 12, 2] } },
    193 => { :from => [8, 7, 6], :to => [10, 4], :steps => 46, :gap => [10, 10],
             :mirrors => { 14 => [5, 16, 2], 5 => [18, 7, 2], 6 => [14, 12, 2], 15 => [14, 5, 2], 18 => [18, 12, 2],
                           16 => [17, 10, 2], 17 => [17, 5, 2] } }
  }
  # The shape every mirror of a room ends in once it is solved, Bronzor in its gap included.
  SOLVED = {
    20 => { 4 => :desc, 5 => :desc, 6 => :asc },
    191 => { 18 => :desc, 4 => :asc, 15 => :asc, 16 => :desc, 5 => :asc, 14 => :asc, 19 => :desc, 17 => :asc,
             20 => :asc, 13 => :desc },
    192 => { 14 => :desc, 5 => :desc, 6 => :asc, 15 => :desc, 18 => :asc, 16 => :asc, 17 => :desc },
    193 => { 14 => :desc, 5 => :desc, 6 => :desc, 15 => :asc, 18 => :asc, 16 => :asc, 17 => :desc }
  }
  # The shape a facing draws, and a facing that draws each shape.
  SHAPE_OF = { 2 => :desc, 8 => :desc, 4 => :asc, 6 => :asc }
  FACING = { :desc => 2, :asc => 4 }
  # The words for each shape.
  SHAPE_WORD = { :asc => :rea_laser_asc, :desc => :rea_laser_desc }
  # Each room's puzzle as the profile declared it on its map, kept before the first test clears the declarations.
  DECLARED = BOARDS.keys.map { |mid| [mid, PokeAccess::World::Mechanics.declared(mid)] }.to_h

  test "a mirror falls facing up or down and rises facing left or right" do
    SHAPE_OF.each { |dir, shape| assert_equal shape, Lasers.shape(dir), "facing #{dir}" }
  end

  test "traces each room as it starts to where its beam is lost" do
    [["room 20", model(20), [:lost, [[4, 8]], 8]],
     ["room 191", model(191), [:lost, [[4, 6], [18, 8]], 8]],
     ["room 192, Bronzor wandering", model(192), [:lost, [], 6]],
     ["room 192, Bronzor in its gap facing down", model(192, :gap => 2), [:lost, [[14, 2], [5, 6], [6, 2]], 2]],
     ["room 193, round the map's right edge", model(193), [:lost, [[5, 2], [18, 6]], 6]]].each do |what, board, want|
      assert_equal want, Lasers.trace(board), what
    end
  end

  test "the solution turns the beam through every mirror of each room onto the large crystal" do
    SOLVED.each do |mid, shapes|
      outcome, hops, _dir = Lasers.trace(model(mid, :shapes => shapes, :gap => 2))
      assert_equal [:hit, shapes.keys.sort], [outcome, hops.map { |id, _d| id }.sort], "room #{mid}"
    end
  end

  test "a room solved on its last allowed move stops short with one step less" do
    { 191 => 38, 193 => 46 }.each do |mid, steps|
      ends = [steps, steps - 1].map { |n| Lasers.trace(model(mid, :shapes => SOLVED[mid], :gap => 2, :steps => n))[0] }
      assert_equal [:hit, :stop], ends, "room #{mid} with #{steps} steps, then one less"
    end
  end

  test "a beam that runs out of steps stops where it is, short of the crystal" do
    assert_equal [:stop, [[4, 2], [5, 6], [6, 2]], 2], Lasers.trace(model(20, :shapes => { 4 => :desc }))
  end

  test "moves the beam on hand-made boards as launchLaser does" do
    [["lost on reaching the left edge", board([3, 5], 4, [9, 9]), [:lost, [], 4]],
     ["round the right edge and lost on the left", board([9, 5], 6, [3, 3]), [:lost, [], 6]],
     ["turned on row 1, not lost there", board([5, 5], 8, [9, 1], [[1, 5, 1, :asc]]), [:hit, [[1, 6]], 6]],
     ["turned on column 1, not lost there", board([5, 5], 4, [1, 9], [[1, 1, 5, :asc]]), [:hit, [[1, 2]], 2]],
     ["onto a crystal on row 0", board([5, 3], 8, [5, 0]), [:hit, [], 8]],
     ["by two mirrors on one tile, in order", board([2, 5], 6, [8, 5], [[1, 5, 5, :desc], [2, 5, 5, :desc]]),
      [:hit, [[1, 2], [2, 6]], 6]]].each do |what, b, want|
      assert_equal want, Lasers.trace(b), what
    end
  end

  test "turning a prism says the shape it turns to, interrupting" do
    in_room(20) { rotateEvent(4) }
    assert_equal [[prism(1, :desc), true]], SpeakCapture.log, "prism 1 turned from facing left to facing up"
  end

  test "with the assist, a turned prism also says whether it stands as the solution wants" do
    PokeAccess::Config.puzzle_assist = true
    in_room(20) do
      rotateEvent(4)
      rotateEvent(5)
    end
    assert_equal [[prism(1, :desc, t(:rea_laser_ok)), true],
                  [prism(2, :asc, t(:rea_laser_goal, :shape => shape_word(:desc))), true]], SpeakCapture.log
  end

  test "turning anything but a mirror of the room says nothing" do
    in_room(20) do
      Lasers.rotated(99)
      Lasers.rotated(3)
      $game_map.events.delete(6)
      Lasers.rotated(6)
    end
    Lasers.rotated(4)
    assert_nothing_spoken "an event of the room that is no mirror, a mirror whose event is gone, and one off the beam rooms"
  end

  test "numbers the prisms in reading order, row by row and left to right" do
    order = [4, 18, 14, 19, 15, 17, 16, 5, 13, 20]
    in_room(191) do
      want = order.each_with_index.map { |id, i| prism(i + 1, start_shape(191, id)) }
      assert_equal want, order.map { |id| PokeAccess::Locator.target_name($game_map.events[id]) }
    end
  end

  test "firing in each room as it starts says the path launchLaser's beam takes, interrupting" do
    { 20 => shot(start(:rea_laser_to_right), hop(1, :rea_laser_to_up), lost(:rea_laser_by_up)),
      191 => shot(start(:rea_laser_to_up), hop(1, :rea_laser_to_right), hop(2, :rea_laser_to_up), lost(:rea_laser_by_up)),
      192 => shot(start(:rea_laser_to_right), lost(:rea_laser_by_right)),
      193 => shot(start(:rea_laser_to_right), hop(3, :rea_laser_to_down), hop(6, :rea_laser_to_right), lost(:rea_laser_by_right))
    }.each do |mid, path|
      SpeakCapture.clear
      in_room(mid) { launchLaser(*launch(mid)) }
      assert_equal [[path, true]], SpeakCapture.log, "room #{mid}, with nothing more once the game answers as traced"
    end
  end

  test "firing in each solved room says just that the beam reaches the crystal" do
    PokeAccess::Config.puzzle_assist = true
    SOLVED.each do |mid, shapes|
      SpeakCapture.clear
      in_room(mid, shapes) do
        settle_bronzor(mid, FACING[shapes[14]]) if BOARDS[mid][:gap]
        launchLaser(*launch(mid))
      end
      assert_equal [[t(:rea_laser_hit), true]], SpeakCapture.log, "room #{mid}, with the assist on and nothing to turn"
    end
  end

  test "with the assist, a shot traced onto the crystal adds no hint while Bronzor, unbeaten, wanders in its gap" do
    PokeAccess::Config.puzzle_assist = true
    in_room(192, SOLVED[192]) do
      wander([11, 7], [11, 7])
      launchLaser(*launch(192))
    end
    assert_equal [[t(:rea_laser_hit), true]], SpeakCapture.log, "unbeaten, Bronzor still turns the beam where it stands"
  end

  test "a shot that runs out of steps says it stops short of the crystal" do
    in_room(20, 4 => :desc) { launchLaser(*launch(20)) }
    assert_equal [[shot(start(:rea_laser_to_right), hop(1, :rea_laser_to_down), hop(2, :rea_laser_to_right),
                        hop(3, :rea_laser_to_down), t(:rea_laser_stop)), true]],
                 SpeakCapture.log
  end

  test "a missed shot says the edge the beam leaves by, whichever way it heads" do
    [[{ 4 => :desc, 5 => :asc }, 20, [hop(1, :rea_laser_to_down), hop(2, :rea_laser_to_left), lost(:rea_laser_by_left)]],
     [{ 4 => :desc, 5 => :desc, 6 => :desc }, 40,
      [hop(1, :rea_laser_to_down), hop(2, :rea_laser_to_right), hop(3, :rea_laser_to_down), lost(:rea_laser_by_down)]]
    ].each do |shapes, steps, hops|
      SpeakCapture.clear
      in_room(20, shapes) { launchLaser(3, 10, 1, [4, 5, 6], steps) }
      assert_equal [[shot(start(:rea_laser_to_right), *hops), true]], SpeakCapture.log, "prisms #{shapes.inspect}"
    end
  end

  test "traces the shot from the very crystals, mirrors and steps the game passes" do
    in_room(20, SOLVED[20]) do
      $game_map.events[7] = piece(7, 11, 3, 2, "Cristal PequeA")
      [[[3, 10, 1, [4, 5], 20], shot(start(:rea_laser_to_right), hop(1, :rea_laser_to_down),
                                     hop(2, :rea_laser_to_right), t(:rea_laser_stop))],
       [[3, 10, 1, [4, 5, 6], 5], shot(start(:rea_laser_to_right), hop(1, :rea_laser_to_down), t(:rea_laser_stop))],
       [[7, 10, 1, [4, 5, 6], 20], shot(start(:rea_laser_to_down), hop(1, :rea_laser_to_right), lost(:rea_laser_by_right))],
       [[3, 10, 7, [4, 5, 6], 20], shot(start(:rea_laser_to_right), hop(1, :rea_laser_to_down),
                                        hop(2, :rea_laser_to_right), hop(3, :rea_laser_to_up), t(:rea_laser_stop))]
      ].each do |args, line|
        SpeakCapture.clear
        launchLaser(*args)
        assert_equal [[line, true]], SpeakCapture.log, "launchLaser#{args.inspect}"
      end
    end
  end

  test "a shot from crystals the room lacks says nothing" do
    in_room(20) do
      Lasers.firing([99, 10, 1, [4, 5, 6], 20])
      Lasers.firing([3, 10, 98, [4, 5, 6], 20])
    end
    assert_nothing_spoken
  end

  test "with the assist, a missed shot names the first wrong mirror the beam crosses" do
    PokeAccess::Config.puzzle_assist = true
    in_room(191, SOLVED[191].merge(14 => :desc, 5 => :desc)) { launchLaser(*launch(191)) }
    path = shot(start(:rea_laser_to_up), hop(1, :rea_laser_to_right), hop(2, :rea_laser_to_down),
                hop(8, :rea_laser_to_right), lost(:rea_laser_by_right))
    assert_equal [["#{path}. #{todo(8)}", true]], SpeakCapture.log, "prism 8, which the beam meets, not prism 3"
  end

  test "after the shot, says only the game's answer that differs from the one traced" do
    [[{}, false, []], [{}, true, [[t(:rea_laser_real_hit), false]]], [SOLVED[20], true, []],
     [SOLVED[20], false, [[t(:rea_laser_real_miss), false]]], [SOLVED[20], nil, [[t(:rea_laser_real_miss), false]]]
    ].each do |shapes, result, log|
      in_room(20, shapes) do
        Lasers.firing(launch(20))
        SpeakCapture.clear
        Lasers.fired(result)
      end
      assert_equal log, SpeakCapture.log, "a shot traced to #{shapes.empty? ? 'miss' : 'hit'}, the game answering #{result.inspect}"
    end
  end

  test "when Bronzor crosses the beam in flight, says after the traced path how the game's shot really ended" do
    into = [[shot(start(:rea_laser_to_right), lost(:rea_laser_by_right)), true], [t(:rea_laser_real_hit), false]]
    out = [[t(:rea_laser_hit), true], [t(:rea_laser_real_miss), false]]
    [[[20, 16], [11, 7], into, "into"], [[11, 7], [20, 16], out, "out of"]].each do |from, to, log, way|
      SpeakCapture.clear
      in_room(192, SOLVED[192]) do
        wander(from, to)
        launchLaser(*launch(192))
      end
      assert_equal log, SpeakCapture.log, "Bronzor, still wandering, stepping #{way} its gap on the shot's first frame"
    end
  end

  test "the game's answer to a shot it was not traced for says nothing" do
    in_room(20) { Lasers.fired(true) }
    assert_nothing_spoken
  end

  test "facing nothing of the room, the info key reads its prisms and the way the beam leaves" do
    in_room(20) do
      declare_room(20)
      stand(13, 21, 8)
      assert_equal board_line(3, :rea_laser_to_right), PokeAccess::Puzzles.info_line
    end
  end

  test "with the assist, the info key adds the prism to turn next" do
    PokeAccess::Config.puzzle_assist = true
    in_room(20) do
      declare_room(20)
      stand(13, 21, 8)
      assert_equal "#{board_line(3, :rea_laser_to_right)}. #{todo(1)}", PokeAccess::Puzzles.info_line
    end
  end

  test "after a shot, the info key adds the last shot to the room" do
    in_room(20) do
      Lasers.firing(launch(20))
      stand(13, 21, 8)
      last = shot(start(:rea_laser_to_right), hop(1, :rea_laser_to_up), lost(:rea_laser_by_up))
      assert_equal "#{board_line(3, :rea_laser_to_right)}. #{t(:rea_laser_last, :shot => last)}", Lasers.info_line
    end
  end

  test "facing a piece, the info key says what it is" do
    PokeAccess::Config.puzzle_assist = true
    in_room(20) do
      { [8, 7] => t(:rea_laser_emitter_dir, :dir => t(:rea_laser_to_right)), [17, 8] => t(:rea_laser_receiver),
        [17, 11] => prism(3, :desc) }.each do |(x, y), line|
        facing(x, y)
        assert_equal line, Lasers.info_line, "facing #{x}, #{y}"
      end
    end
  end

  test "facing Bronzor still wandering, the info key reads the room" do
    in_room(192) do
      facing(20, 16)
      assert_equal board_line(6, :rea_laser_to_right), Lasers.info_line
    end
  end

  test "with no small crystal on the map, the info key has the beam leave to the right" do
    in_room(191) do
      $game_map.events.delete(3)
      stand(13, 21, 8)
      assert_equal board_line(10, :rea_laser_to_right), Lasers.info_line
    end
  end

  test "facing a prism, the assist says whether it stands right" do
    PokeAccess::Config.puzzle_assist = true
    in_room(20, 5 => :desc) do
      { [11, 7] => t(:rea_laser_goal, :shape => shape_word(:desc)), [11, 11] => t(:rea_laser_ok) }.each do |(x, y), line|
        facing(x, y)
        assert_equal line, Lasers.assist_line, "facing #{x}, #{y}"
      end
    end
  end

  test "facing nothing, the assist names the first wrong prism in reading order, or the one the last shot met" do
    PokeAccess::Config.puzzle_assist = true
    in_room(191, SOLVED[191].merge(14 => :desc, 5 => :desc)) do
      stand(13, 21, 8)
      before = Lasers.assist_line
      Lasers.firing(launch(191))
      assert_equal [todo(3), todo(8)], [before, Lasers.assist_line]
    end
  end

  test "with every mirror right, the assist says all is set to fire" do
    PokeAccess::Config.puzzle_assist = true
    in_room(20, SOLVED[20]) do
      stand(13, 21, 8)
      assert_equal t(:rea_laser_ready), Lasers.assist_line
    end
  end

  test "in each solved room the assist finds every mirror right, Bronzor in its gap included" do
    PokeAccess::Config.puzzle_assist = true
    ok = ", #{t(:rea_laser_ok)}"
    SOLVED.each do |mid, shapes|
      in_room(mid, shapes) do
        settle_bronzor(mid, FACING[shapes[14]]) if BOARDS[mid][:gap]
        stand(13, 21, 8)
        wrong = shapes.keys.reject { |id| PokeAccess::Locator.target_name($game_map.events[id]).end_with?(ok) }
        assert_equal [[], t(:rea_laser_ready)], [wrong, Lasers.assist_line], "room #{mid}: the mirrors not right, and the assist"
      end
    end
  end

  test "a new map or a reload forgets the last shot and where Bronzor stood" do
    in_room(20) do
      Lasers.firing(launch(20))
      PokeAccess::Caches.reset_all
      stand(13, 21, 8)
      assert_equal board_line(3, :rea_laser_to_right), Lasers.info_line, "the room without its last shot"
    end
    in_room(192) do
      Input.update
      settle_bronzor(192, 4)
      PokeAccess::Caches.reset_all
      SpeakCapture.clear
      Input.update
      assert_nothing_spoken "Bronzor found settled is taken note of again"
    end
  end

  test "names each prism for the locator as it stands, with the assist's verdict" do
    PokeAccess::Config.puzzle_assist = true
    in_room(20) do
      assert_equal [prism(1, :asc, t(:rea_laser_goal, :shape => shape_word(:desc))),
                    prism(3, :desc, t(:rea_laser_goal, :shape => shape_word(:asc)))],
                   [4, 6].map { |id| PokeAccess::Locator.target_name($game_map.events[id]) }
    end
  end

  test "names both crystals and the parked beam in every beam room" do
    BOARDS.each_key do |mid|
      in_room(mid) do
        assert_equal [t(:rea_laser_emitter), t(:rea_laser_receiver), t(:rea_laser_beam)],
                     [3, 1, 10].map { |id| PokeAccess::Locator.target_name($game_map.events[id]) }, "room #{mid}"
      end
    end
  end

  test "a name the player gave a piece wins over the room's" do
    in_room(20) do
      begin
        PokeAccess::Tags.set(20, 3, "cristal rojo")
        assert_equal "cristal rojo", PokeAccess::Locator.target_name($game_map.events[3])
      ensure
        PokeAccess::Tags.delete(20, 3)
      end
    end
  end

  test "leaves the locator to name what is no piece of a beam room" do
    in_room(20) do
      $game_map.events[7] = piece(7, 2, 2, 2, "npc")
      surface = PokeAccess::Locator::SurfaceTarget.new(11, 7, "Prisma", :puzzle_spot, nil)
      assert_equal [nil, nil, nil], [Lasers.piece_name($game_map.events[7]), Lasers.piece_name(surface), Lasers.piece_name(Object.new)]
    end
    assert_nil Lasers.piece_name(piece(4, 11, 7, 4, "Prismas2")), "a mirror's id off the beam rooms"
  end

  test "lists both crystals and every prism in the puzzle category, each where and as it stands" do
    in_room(20) do
      declare_room(20)
      spots = PokeAccess::Puzzles.category_targets.map { |s| [s.name, s.x, s.y] }
      assert_equal [[t(:rea_laser_emitter), 8, 7], [t(:rea_laser_receiver), 17, 8], [prism(1, :asc), 11, 7],
                    [prism(2, :desc), 11, 11], [prism(3, :desc), 17, 11]], spots
    end
  end

  test "answers the info key until the small crystal turns to its spent page, the room solved" do
    in_room(20) do
      declare_room(20)
      before = PokeAccess::Puzzles.active?
      $game_self_switches[[20, 3, "A"]] = true
      assert_equal [true, false], [before, PokeAccess::Puzzles.active?]
    end
  end

  test "files the crystals and prisms with the objects, though their sprites are named" do
    in_room(20) do
      assert_equal [:objects] * 5, [3, 1, 4, 5, 6].map { |id| PokeAccess::Locator.event_category($game_map.events[id]) }
    end
  end

  test "leaves the parked beam out of the locator's lists" do
    in_room(20) do
      assert_equal [true, false, false], [10, 3, 4].map { |id| PokeAccess::Locator.hidden?($game_map.events[id]) }
    end
  end

  test "files the crystals and prisms as the room's pieces, Bronzor aside, and tells the beam apart" do
    in_room(192) do
      ev = $game_map.events
      assert_equal [true, true, true, true, true, true, true, true],
                   [3, 1, 5, 6, 15, 18, 16, 17].map { |id| Lasers.room_piece?(ev[id]) }, "both crystals and every prism"
      assert_equal [false, false, false], [Lasers.room_piece?(ev[14]), Lasers.room_piece?(ev[10]), Lasers.room_piece?(nil)],
                   "Bronzor, the beam, and no event at all"
      assert_equal [true, false, false], [Lasers.beam?(ev[10]), Lasers.beam?(ev[5]), Lasers.beam?(nil)], "the beam alone"
    end
  end

  test "while Bronzor wanders, turning it says nothing and the locator calls it by its species" do
    in_room(192) do
      Lasers.rotated(14)
      assert_nothing_spoken
      assert_equal PokeAccess::Data.species_name(436), PokeAccess::Locator.target_name($game_map.events[14])
    end
  end

  test "while Bronzor's gap is empty, the assist says to beat it first" do
    PokeAccess::Config.puzzle_assist = true
    in_room(192, SOLVED[192]) do
      stand(13, 21, 8)
      away = Lasers.assist_line
      facing(20, 16)
      missing = t(:rea_laser_missing, :name => PokeAccess::Data.species_name(436))
      assert_equal [missing, missing], [away, Lasers.assist_line], "facing nothing, and facing Bronzor"
    end
  end

  test "calls a Bronzor whose sprite names no species a mirror" do
    in_room(192) do
      $game_map.events[14].character_name = "actualizar"
      assert_equal t(:rea_laser_mirror), PokeAccess::Locator.target_name($game_map.events[14])
    end
  end

  test "says once where Bronzor settles and the shape it comes in with, after taking note of where it stood" do
    PokeAccess::Config.puzzle_assist = true
    in_room(192) do
      Input.update
      assert_nothing_spoken "arriving on the map only takes note"
      settle_bronzor(192, 4)
      Input.update
      Input.update
    end
    name = PokeAccess::Data.species_name(436)
    said = [t(:rea_laser_placed, :name => name), mirror(name, :asc), t(:rea_laser_placed_hint)].join(". ")
    assert_equal [[said, false]], SpeakCapture.log
  end

  test "without the assist, Bronzor's settling leaves the hint out" do
    in_room(193) do
      Input.update
      settle_bronzor(193, 2)
      Input.update
    end
    name = PokeAccess::Data.species_name(436)
    assert_equal [[[t(:rea_laser_placed, :name => name), mirror(name, :desc)].join(". "), false]], SpeakCapture.log
  end

  test "a Bronzor already settled as the room is entered is only taken note of" do
    in_room(192) do
      settle_bronzor(192, 4)
      Input.update
      Input.update
    end
    assert_nothing_spoken
  end

  test "Bronzor leaving its gap says nothing" do
    in_room(192) do
      settle_bronzor(192, 4)
      Input.update
      $game_self_switches[[192, 14, "B"]] = true
      Input.update
    end
    assert_nothing_spoken
  end

  test "settled in its gap, Bronzor turns like a prism" do
    PokeAccess::Config.puzzle_assist = true
    in_room(192) do
      settle_bronzor(192, 4)
      Lasers.rotated(14)
      facing(11, 7)
      assert_equal t(:rea_laser_goal, :shape => shape_word(:desc)), Lasers.assist_line, "the assist facing it"
    end
    name = PokeAccess::Data.species_name(436)
    assert_equal [["#{mirror(name, :asc)}, #{t(:rea_laser_goal, :shape => shape_word(:desc))}", true]], SpeakCapture.log
  end

  test "a Bronzor beaten but not yet in its gap turns with no verdict" do
    PokeAccess::Config.puzzle_assist = true
    in_room(192) do
      $game_self_switches[[192, 14, "A"]] = true
      rotateEvent(14)
    end
    assert_equal [[mirror(PokeAccess::Data.species_name(436), :asc), true]], SpeakCapture.log
  end

  test "settled but wrong, Bronzor is named by the assist among the mirrors to turn" do
    PokeAccess::Config.puzzle_assist = true
    in_room(192, SOLVED[192]) do
      settle_bronzor(192, 4)
      stand(13, 21, 8)
      assert_equal t(:rea_laser_todo, :list => PokeAccess::Data.species_name(436)), Lasers.assist_line
    end
  end

  test "outside the beam rooms every reader keeps quiet" do
    ev = piece(4, 11, 7, 4, "Prismas2")
    $game_map.events[4] = ev
    Lasers.rotated(4)
    Lasers.firing([3, 10, 1, [4], 20])
    Lasers.fired(true)
    Lasers.poll
    assert_nothing_spoken
    assert_equal ["", "", false, false, false], [Lasers.info_line, Lasers.assist_line, Lasers.solved?,
                                                 Lasers.room_piece?(ev), Lasers.beam?(piece(10, 0, 0, 2, "laser"))]
  end

  test "a broken event leaves the readers quiet rather than failing the room" do
    in_room(192) do
      broken = piece(5, 11, 11, 2, "Prismas2")
      def broken.direction; raise IOError, "the event is gone"; end
      $game_map.events[5] = broken
      Lasers.rotated(5)
      Lasers.firing(launch(192))
      Lasers.poll
      settle_bronzor(192, 4)
      def ($game_map.events[14]).character_name; raise IOError, "the sprite is gone"; end
      Lasers.poll
    end
    assert_nothing_spoken
  end

  private

  # The text of key in the running language.
  def t(key, vars = nil)
    PokeAccess::I18n.t(key, vars)
  end

  # A trace board of a room: its mirrors as the room starts, shapes overriding some; with :gap, Bronzor settled in its
  # gap facing that way instead of where it wanders; :steps overriding the room's.
  def model(mid, opts = {})
    b = BOARDS[mid]
    shapes = opts[:shapes] || {}
    mirrors = Lasers::ROOMS[mid][:mirrors].map do |id|
      x, y, dir = b[:mirrors][id]
      x, y, dir = b[:gap] + [opts[:gap]] if opts[:gap] && b[:gap] && id == 14
      [id, x, y, shapes[id] || SHAPE_OF[dir]]
    end
    { :w => 28, :h => 24, :from => b[:from][0, 2], :dir => b[:from][2], :to => b[:to],
      :steps => opts[:steps] || b[:steps], :mirrors => mirrors }
  end

  # A hand-made 12 x 12 trace board with 20 steps.
  def board(from, dir, to, mirrors = [])
    { :w => 12, :h => 12, :from => from, :dir => dir, :to => to, :steps => 20, :mirrors => mirrors }
  end

  # The shape a room's mirror starts in.
  def start_shape(mid, id)
    SHAPE_OF[BOARDS[mid][:mirrors][id][2]]
  end

  # A map event standing on (x, y) facing dir, wearing sprite.
  def piece(id, x, y, dir, sprite)
    ev = TestEvent.new(id, "EV#{id}", x, y)
    ev.direction = dir
    ev.character_name = sprite
    ev
  end

  # Runs the block with a room laid out on the map as events (the crystals, the beam, the prisms and Bronzor, sprite
  # 436), the mirrors turned to shapes where given, no self switch on and nothing kept from an earlier shot; the map,
  # the player and the self switches are put back afterwards.
  def in_room(mid, shapes = {})
    was = [$game_map.map_id, $game_map.width, $game_map.height, $game_player.x, $game_player.y,
           $game_player.direction, $game_self_switches]
    b = BOARDS[mid]
    $game_map.map_id = mid
    $game_map.width = 28
    $game_map.height = 24
    $game_map.events.clear
    $game_self_switches = {}
    ev = $game_map.events
    ev[3] = piece(3, b[:from][0], b[:from][1], b[:from][2], "Cristal PequeA")
    ev[1] = piece(1, b[:to][0], b[:to][1], 2, "Cristal Grande")
    ev[10] = piece(10, 0, 0, 2, "laser")
    b[:mirrors].each do |id, (x, y, dir)|
      bronzor = id == Lasers::ROOMS[mid][:bronzor]
      ev[id] = piece(id, x, y, (!bronzor && shapes[id]) ? FACING[shapes[id]] : dir, bronzor ? "436" : "Prismas2")
    end
    Lasers.reset
    yield
  ensure
    $game_map.map_id, $game_map.width, $game_map.height, $game_player.x, $game_player.y, $game_player.direction,
      $game_self_switches = was
    $game_map.events.clear
    Lasers.reset
  end

  # Declares the room's puzzle on its map again, as the profile does.
  def declare_room(mid)
    PokeAccess::World::Mechanics.declare(mid, DECLARED[mid])
  end

  # Bronzor beaten and settled in its gap, facing dir.
  def settle_bronzor(mid, dir)
    bronzor = $game_map.events[14]
    bronzor.x, bronzor.y = BOARDS[mid][:gap]
    bronzor.direction = dir
    $game_self_switches[[mid, 14, "A"]] = true
  end

  # Bronzor, still wandering, standing on from facing down, and on the map's next frame stepping onto to.
  def wander(from, to)
    bronzor = $game_map.events[14]
    bronzor.x, bronzor.y = from
    bronzor.direction = 2
    bronzor.define_singleton_method(:update) { self.x, self.y = to }
  end

  # Stands the player on (x, y) facing dir.
  def stand(x, y, dir)
    $game_player.x = x
    $game_player.y = y
    $game_player.direction = dir
  end

  # Stands the player just below (x, y), facing it.
  def facing(x, y)
    stand(x, y + 1, 8)
  end

  # launchLaser's arguments as the room's own event passes them.
  def launch(mid)
    [3, 10, 1, Lasers::ROOMS[mid][:mirrors], BOARDS[mid][:steps]]
  end

  # The words for a shape.
  def shape_word(shape)
    t(SHAPE_WORD[shape])
  end

  # A mirror called name in shape, with the assist's verdict after it when given.
  def mirror(name, shape, verdict = nil)
    line = t(:rea_laser_shape, :name => name, :shape => shape_word(shape))
    verdict ? "#{line}, #{verdict}" : line
  end

  # Prism n in shape, with the assist's verdict after it when given.
  def prism(n, shape, verdict = nil)
    mirror(t(:rea_laser_prism, :n => n), shape, verdict)
  end

  # The assist's call to turn prism n.
  def todo(n)
    t(:rea_laser_todo, :list => t(:rea_laser_prism, :n => n))
  end

  # The room's line: how many prisms, and the way the beam leaves.
  def board_line(prisms, heading)
    t(:rea_laser_board, :n => prisms, :dir => t(heading))
  end

  # The parts of a shot as it is said.
  def shot(*parts)
    parts.join("; ")
  end

  # A shot's start, heading as the key says.
  def start(heading)
    t(:rea_laser_start, :dir => t(heading))
  end

  # A shot turned by prism n, heading as the key says.
  def hop(n, heading)
    t(:rea_laser_hop, :name => t(:rea_laser_prism, :n => n), :dir => t(heading))
  end

  # A shot lost by the edge the key says.
  def lost(side)
    t(:rea_laser_lost, :side => t(side))
  end
end
