# The Erebus Gym mirror rooms (games/insurgence/lasers.rb): each mirror by its number in reading order, the sides its
# turn joins (variable 144) and whether the beam passes it (variable 145), the room's count after a turn, the beam's
# tiles kept out of the lists, and with the puzzle assist the beam's path, the turns that light every receiver and the
# next mirror to set. The profile file loads once here, after the game's mirror turn it hooks.

# The game's mirror turn (pbChangeMirror), reduced to the quarter turn it leaves in variable 144.
def pbChangeMirror(id)
  $game_variables[144][id] = ($game_variables[144][id] + 1) % 4
end

lasers_path = File.join(Harness::ROOT, "games", "insurgence", "lasers.rb")
eval(Harness.source(lasers_path), TOPLEVEL_BINDING, lasers_path)

class InsurgenceLasersTest < PokeAccessTest
  Lasers = PokeAccess::InsurgenceLasers

  test "lists the room's mirrors in reading order, leaving out the one map 543 keeps away from the room" do
    gym_room
    World.event(:id => 11, :name => "c", :x => 1, :y => 9, :sprite => "")
    assert_equal [1, 2, 6], Lasers.mirrors.map { |e| e.id }
    assert_equal [true, false], [Lasers.room_mirror?(ev(2)), Lasers.room_mirror?(ev(11))], "mirror 2, and the one away"
  end

  test "a mirror is said by the sides its turn joins, the turn counted in quarters" do
    gym_room
    $game_variables[145][6] = false
    { 0 => :ins_mirror_tl, 1 => :ins_mirror_tr, 2 => :ins_mirror_br, 3 => :ins_mirror_bl, 5 => :ins_mirror_tr,
      nil => :ins_mirror_tl }.each do |turn, sides|
      $game_variables[144][6] = turn
      assert_equal t(:ins_mirror, :n => 6, :sides => t(sides)), Lasers.mirror_line(ev(6)), "at turn #{turn.inspect}"
    end
  end

  test "before the game keeps any turns, every mirror stands at its first" do
    gym_room
    $game_variables[144] = nil
    assert_equal t(:ins_mirror, :n => 1, :sides => t(:ins_mirror_tl)), Lasers.mirror_line(ev(1))
  end

  test "a mirror's number is its place in the room's reading order, not its id" do
    gym_room
    [[20, 4], [5, 7]].each do |id, number|
      World.event(:id => id, :name => "c", :x => 30 + id, :y => 5, :sprite => "")
      assert_equal t(:ins_mirror, :n => number, :sides => t(:ins_mirror_tl)), Lasers.mirror_line(ev(id)), "mirror #{id}"
    end
  end

  test "a mirror the beam passes says so" do
    gym_room
    assert_equal "#{t(:ins_mirror, :n => 2, :sides => t(:ins_mirror_tl))}, #{t(:ins_mirror_lit)}",
                 Lasers.mirror_line(ev(2))
  end

  test "the room's line counts the mirrors on the beam and the receivers it reaches" do
    gym_room
    assert_equal room_line(2, 3, 0), Lasers.status_line(Lasers.room), "the receiver dark"
    $game_variables[145][211] = true
    assert_equal room_line(2, 3, 1), Lasers.status_line(Lasers.room), "the receiver reached"
  end

  test "a mirror turned in the game is said with the room, interrupting" do
    gym_room
    pbChangeMirror(6)
    mirror = "#{t(:ins_mirror, :n => 6, :sides => t(:ins_mirror_bl))}, #{t(:ins_mirror_lit)}"
    assert_equal [["#{mirror}. #{room_line(2, 3, 0)}", true]], SpeakCapture.log
  end

  test "turning what is no mirror of the room says nothing" do
    [[543, 40, "a track tile"], [543, 11, "the mirror away from the room"],
     [5, 6, "a mirror off the mirror rooms"]].each do |map, id, what|
      gym_room
      World.event(:id => 11, :name => "c", :x => 1, :y => 9, :sprite => "")
      $game_map.map_id = map
      SpeakCapture.clear
      pbChangeMirror(id)
      assert_nothing_spoken what
    end
  end

  test "the info key says the mirror in front of the player, else the room" do
    gym_room
    assert_equal t(:ins_mirror, :n => 6, :sides => t(:ins_mirror_br)) + ", #{t(:ins_mirror_lit)}",
                 facing(12, 23, 2) { Lasers.info_line },
                 "facing mirror 6"
    assert_equal room_line(2, 3, 0), facing(12, 23, 8) { Lasers.info_line }, "facing none"
  end

  test "with the assist on, the info key still says the mirror in front alone, its verdict being the hint's" do
    path_room
    PokeAccess::Config.puzzle_assist = true
    assert_equal t(:ins_mirror, :n => 2, :sides => t(:ins_mirror_tl)), facing(12, 17, 8) { Lasers.info_line }
  end

  test "off the mirror rooms the info key has nothing to say" do
    gym_room
    $game_map.map_id = 5
    assert_equal "", facing(12, 23, 2) { Lasers.info_line }
  end

  test "the beam's lit track stays out of the lists; the receiver, the mirrors and every other map keep theirs" do
    gym_room
    { 40 => true, 211 => false, 1 => false }.each do |id, hidden|
      assert_equal hidden, PokeAccess::Locator.hidden?(ev(id)), "event #{id}"
    end
    $game_map.map_id = 5
    assert_equal false, PokeAccess::Locator.hidden?(ev(40)), "a track tile off the mirror rooms"
  end

  test "in the mirror rooms a mirror is named as it stands and filed among the objects" do
    gym_room
    assert_equal "#{t(:ins_mirror, :n => 6, :sides => t(:ins_mirror_br))}, #{t(:ins_mirror_lit)}",
                 PokeAccess::Locator.ruled_name(ev(6))
    assert_equal :objects, PokeAccess::Locator.ruled_category(ev(6))
  end

  test "the mirror map 543 keeps away from the room is neither named nor filed as one" do
    gym_room
    World.event(:id => 11, :name => "c", :x => 1, :y => 9, :sprite => "")
    assert_equal [nil, nil], [PokeAccess::Locator.ruled_name(ev(11)), PokeAccess::Locator.ruled_category(ev(11))]
  end

  test "a room is solved once every receiver has opened its door" do
    [[543, [], false], [543, [515], true], [542, [517], false], [542, [516], false], [542, [516, 517], true],
     [5, [515, 516, 517], false]].each do |map, on, solved|
      $game_switches.clear
      on.each { |sw| $game_switches[sw] = true }
      $game_map.map_id = map
      assert_equal solved, Lasers.solved?, "map #{map} with switches #{on.inspect}"
    end
  end

  test "a beam is traced as the game draws it, and lost where nothing stands" do
    path_room
    assert_equal [:end, [[2, 3]], [40, 2]],
                 Lasers.trace(Lasers.tile_events, [12, 14], Lasers.current_turns(Lasers.room))
  end

  test "each turn joins two sides: a beam coming in by one leaves by the other, and one coming in by another is cut" do
    { [0, 2] => 3, [0, 1] => 0, [0, 0] => nil, [0, 3] => nil,
      [1, 2] => 1, [1, 3] => 0, [1, 0] => nil, [1, 1] => nil,
      [2, 0] => 1, [2, 3] => 2, [2, 2] => nil, [2, 1] => nil,
      [3, 0] => 3, [3, 1] => 2, [3, 2] => nil, [3, 3] => nil }.each do |(turn, heading), leaves|
      assert_equal [2, leaves], bounce(turn, heading), "turn #{turn}, the beam heading #{heading}"
    end
  end

  test "a beam is cut at a mirror whose turn does not join the side it comes in by, the mirror left dark" do
    path_room
    assert_equal [:cut, [[2, nil]], [40]], Lasers.trace(Lasers.tile_events, [12, 14], { 2 => 2 })
  end

  test "a beam that comes back on itself is taken for a loop" do
    loop_room
    assert_equal :loop, Lasers.trace(Lasers.tile_events, [12, 14], { 2 => 1, 4 => 0, 6 => 3, 8 => 2 })[0]
  end

  test "a mirror the given turns leave out stops the trace there, with the side the beam comes in by" do
    path_room
    assert_equal [:open, [], [40, 2], 2, 0], Lasers.trace(Lasers.tile_events, [12, 14], {})
  end

  test "an id past the count of events is never looked up, as in the game" do
    path_room
    World.event(:id => 300, :name => "c", :x => 30, :y => 30, :sprite => "")
    assert_nil Lasers.tile_events[[30, 30]]
  end

  test "the game's look-up passes over a gap in the map's event ids" do
    $game_map.map_id = 543
    [[1, 12, 15], [3, 12, 16], [7, 50, 50], [8, 51, 50]].each do |id, x, y|
      World.event(:id => id, :name => "laser", :x => x, :y => y, :sprite => "")
    end
    assert_equal({ [12, 15] => 1, [12, 16] => 3 }, Lasers.tile_events.map { |xy, e| [xy, e.id] }.to_h)
  end

  test "the turns that light every receiver are found from where the mirrors stand" do
    path_room
    assert_equal({ 2 => 1, 3 => 3 }, Lasers.solution(Lasers.room), "from turns 0 and 0")
    $game_variables[144][2] = 2
    $game_variables[144][3] = 1
    assert_equal({ 2 => 1, 3 => 3 }, Lasers.solution(Lasers.room), "from turns 2 and 1")
  end

  test "with the assist, the info key tells the beam's path and the first wrong mirror it meets" do
    path_room
    PokeAccess::Config.puzzle_assist = true
    lost = "#{t(:ins_laser_start, :dir => t(:ins_laser_to_down))}; " \
           "#{t(:ins_laser_hop, :n => 2, :dir => t(:ins_laser_to_left))}; #{t(:ins_laser_end)}"
    assert_equal "#{lost}. #{todo_line(2, :ins_mirror_tr, 1)}", facing(9, 9, 2) { Lasers.assist_line }
  end

  test "with the assist, a beam cut at a mirror is said to be cut there" do
    path_room
    PokeAccess::Config.puzzle_assist = true
    $game_variables[144][2] = 2
    cut = "#{t(:ins_laser_start, :dir => t(:ins_laser_to_down))}; #{t(:ins_laser_cut, :n => 2)}"
    assert_equal "#{cut}. #{todo_line(2, :ins_mirror_tr, 3)}", facing(9, 9, 2) { Lasers.assist_line }
  end

  test "with the assist and every mirror set right, the beam reaches the receiver" do
    path_room
    PokeAccess::Config.puzzle_assist = true
    $game_variables[144][2] = 1
    $game_variables[144][3] = 3
    reached = "#{t(:ins_laser_start, :dir => t(:ins_laser_to_down))}; " \
              "#{t(:ins_laser_hop, :n => 2, :dir => t(:ins_laser_to_right))}; " \
              "#{t(:ins_laser_hop, :n => 3, :dir => t(:ins_laser_to_down))}; #{t(:ins_laser_reach)}"
    assert_equal "#{reached}. #{t(:ins_laser_ready)}", facing(9, 9, 2) { Lasers.assist_line }
  end

  test "with the assist, a room no turns can solve is said to have none" do
    path_room
    PokeAccess::Config.puzzle_assist = true
    $game_map.events.delete(211)
    lost = "#{t(:ins_laser_start, :dir => t(:ins_laser_to_down))}; " \
           "#{t(:ins_laser_hop, :n => 2, :dir => t(:ins_laser_to_left))}; #{t(:ins_laser_end)}"
    assert_equal "#{lost}. #{t(:ins_laser_none)}", facing(9, 9, 2) { Lasers.assist_line }
  end

  test "with the assist, facing a mirror the info key gives its verdict" do
    path_room
    PokeAccess::Config.puzzle_assist = true
    assert_equal goal_line(:ins_mirror_tr, 1), facing(12, 17, 8) { Lasers.assist_line }, "set wrong"
    $game_variables[144][2] = 1
    assert_equal t(:ins_laser_ok), facing(12, 17, 8) { Lasers.assist_line }, "set right"
  end

  test "with the assist, a mirror's verdict counts the quarter turns it still needs, clockwise as the game turns it" do
    path_room
    PokeAccess::Config.puzzle_assist = true
    $game_variables[144][2] = 1
    counts = (0..2).map do |turn|
      $game_variables[144][3] = turn
      Lasers.verdict_of(3)
    end
    assert_equal [3, 2, 1].map { |n| goal_line(:ins_mirror_bl, n) }, counts
  end

  test "with the assist, a mirror turned in the game gives its verdict too" do
    path_room
    PokeAccess::Config.puzzle_assist = true
    $game_variables[144][2] = 1
    $game_variables[144][3] = 3
    pbChangeMirror(3)
    mirror = "#{t(:ins_mirror, :n => 3, :sides => t(:ins_mirror_tl))}, #{goal_line(:ins_mirror_bl, 3)}"
    assert_equal [["#{mirror}. #{room_line(0, 16, 0)}", true]], SpeakCapture.log
  end

  test "with the assist, a mirror turned in the game that the beams never meet gives no verdict" do
    path_room
    PokeAccess::Config.puzzle_assist = true
    pbChangeMirror(1)
    assert_equal [["#{t(:ins_mirror, :n => 1, :sides => t(:ins_mirror_tr))}. #{room_line(0, 16, 0)}", true]],
                 SpeakCapture.log
  end

  test "without the assist, a mirror turned in the game gives no verdict" do
    path_room
    $game_variables[144][3] = 3
    pbChangeMirror(3)
    assert_equal [["#{t(:ins_mirror, :n => 3, :sides => t(:ins_mirror_tl))}. #{room_line(0, 16, 0)}", true]],
                 SpeakCapture.log
  end

  test "without the assist the info key has no path to tell" do
    path_room
    assert_equal "", facing(9, 9, 2) { Lasers.assist_line }
  end

  test "the puzzle's spots: where the beam starts, the receiver, and each mirror named as it stands" do
    gym_room
    spots = Lasers.spots(543)
    assert_equal [{ :at => [12, 14], :label => :ins_laser_emitter }, { :event => 211, :label => :ins_laser_receiver }],
                 spots.first(2)
    assert_equal [1, 2, 3, 20, 21, 6, 5, 19, 8, 9, 7, 15, 12, 13, 14, 16], spots.drop(2).map { |s| s[:event] }
    labels = spots.drop(2).map { |s| [s[:event], s[:label].call] }.to_h
    assert_equal [t(:ins_mirror, :n => 1, :sides => t(:ins_mirror_tr)), ""], [labels[1], labels[3]],
                 "mirror 1 as it stands, and mirror 3, absent from this part of the map, unnamed"
  end

  test "map 542's spots: its two beams' starts, its two receivers and its twelve mirrors in reading order" do
    spots = Lasers.spots(542)
    assert_equal [{ :at => [12, 10], :label => :ins_laser_emitter }, { :at => [14, 26], :label => :ins_laser_emitter },
                  { :event => 100, :label => :ins_laser_receiver }, { :event => 99, :label => :ins_laser_receiver }],
                 spots.first(4)
    assert_equal [43, 16, 19, 24, 40, 15, 21, 22, 41, 42, 38, 39], spots.drop(4).map { |s| s[:event] }
  end

  private

  def t(key, vars = {})
    PokeAccess::I18n.t(key, vars)
  end

  def ev(id)
    $game_map.events[id]
  end

  # The assist's verdict on a mirror set wrong: the sides it should join and the quarter turns it still needs.
  def goal_line(sides, turns)
    "#{t(:ins_laser_goal, :sides => t(sides))}, #{t(:ins_laser_turns, :n => turns)}"
  end

  # The assist's next mirror to set: its number, the sides it should join and the quarter turns it still needs.
  def todo_line(n, sides, turns)
    "#{t(:ins_laser_todo, :n => n, :sides => t(sides))}, #{t(:ins_laser_turns, :n => turns)}"
  end

  # The room's line: the mirrors on the beam out of those standing, and the receiver reached or not.
  def room_line(lit, mirrors, reached)
    "#{t(:ins_laser_mirrors, :n => mirrors, :lit => lit)}. #{t(:ins_laser_receivers, :n => 1, :lit => reached)}"
  end

  # The block's value with the player at (x, y) facing dir (2 down, 8 up), their facing put back after.
  def facing(x, y, dir)
    was = $game_player.direction
    $game_player.x = x
    $game_player.y = y
    $game_player.direction = dir
    yield
  ensure
    $game_player.direction = was
  end

  # Part of map 543 as the game lays it out: mirrors 1 (6,18), 2 (12,18) and 6 (12,24) at turns 1, 0 and 2, the last
  # two on the beam, a lit track tile (12,20), the receiver 211 (24,15) and a trainer, as variables 144 and 145 keep
  # them.
  def gym_room
    $game_map.map_id = 543
    $game_map.events.clear
    [[1, "c", 6, 18, "mirror_1"], [2, "c", 12, 18, "mirror_0_active"], [6, "c", 12, 24, "mirror_2_active"],
     [40, "laser", 12, 20, "laser_0"], [211, "laser", 24, 15, ""],
     [229, "Trainer(3)", 3, 3, "trchar010"]].each do |id, name, x, y, sprite|
      World.event(:id => id, :name => name, :x => x, :y => y, :sprite => sprite)
    end
    turns = Array.new(221, 0)
    turns[1] = 1
    turns[6] = 2
    lit = Array.new(221, false)
    lit[2] = lit[6] = lit[40] = true
    $game_variables[144] = turns
    $game_variables[145] = lit
  end

  # A small room on map 543's ids: the beam leaves (12,14) heading down over a track tile to mirror 2, right over
  # another to mirror 3, and down over a third to receiver 211, when mirror 2 joins top and right (turn 1) and mirror 3
  # bottom and left (turn 3); both stand at turn 0. The other ids up to 212 stand far off, as the map's other events
  # do, so the game's look-up (ids below the count of events) reaches the receiver.
  def path_room
    $game_map.map_id = 543
    $game_map.events.clear
    [[40, "laser", 12, 15], [2, "c", 12, 16], [41, "laser", 13, 16], [3, "c", 14, 16], [42, "laser", 14, 17],
     [211, "laser", 14, 18]].each do |id, name, x, y|
      World.event(:id => id, :name => name, :x => x, :y => y, :sprite => "")
    end
    (1..212).each { |id| World.event(:id => id, :x => 100 + id, :y => 100, :sprite => "") unless $game_map.events[id] }
    $game_variables[144] = Array.new(221, 0)
    $game_variables[145] = Array.new(221, false)
  end

  # The hop of mirror 2, at turn, for a beam from (12,15) that reaches it heading `heading` (0 up, 1 right, 2 down,
  # 3 left): [2, the way it leaves], [2, nil] where it is cut, nil where the beam never reaches it. Mirrors 1 and 3,
  # at turns that join what they must, bring the beam round to it (else they stand far off), and event 99 too, so the
  # game's look-up reaches them all.
  def bounce(turn, heading)
    $game_map.map_id = 543
    $game_map.events.clear
    lead = { 2 => [], 1 => [[1, 12, 16, 1]], 3 => [[1, 12, 16, 0]], 0 => [[1, 12, 16, 1], [3, 13, 16, 0]] }[heading]
    x, y = { 2 => [12, 16], 1 => [13, 16], 3 => [11, 16], 0 => [13, 15] }[heading]
    turns = { 2 => turn }
    lead.each do |id, lx, ly, lead_turn|
      World.event(:id => id, :name => "c", :x => lx, :y => ly, :sprite => "")
      turns[id] = lead_turn
    end
    [1, 3, 99].each do |id|
      World.event(:id => id, :name => "laser", :x => 200 + id, :y => 200, :sprite => "") unless turns[id]
    end
    World.event(:id => 2, :name => "c", :x => x, :y => y, :sprite => "")
    Lasers.trace(Lasers.tile_events, [12, 15], turns)[1].assoc(2)
  end

  # Four mirrors around a square, each passing the beam on to the next, so a beam from (12,14) heading down goes round
  # for ever when mirror 2 joins top and right, 4 left and top, 6 bottom and left, and 8 right and bottom; event 9
  # stands far off, so the game's look-up reaches them all.
  def loop_room
    $game_map.map_id = 543
    $game_map.events.clear
    [[1, "laser", 12, 15], [2, "c", 12, 16], [3, "laser", 13, 16], [4, "c", 14, 16], [5, "laser", 14, 15],
     [6, "c", 14, 14], [7, "laser", 13, 14], [8, "c", 12, 14], [9, "laser", 100, 100]].each do |id, name, x, y|
      World.event(:id => id, :name => name, :x => x, :y => y, :sprite => "")
    end
  end
end
