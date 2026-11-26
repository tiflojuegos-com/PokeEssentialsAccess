# Pokemon Rejuvenation's puzzles of part G (games/rejuvenation/puzzles/): Terajuma's plasma balls, Lost Castle's books,
# Mirage Woods, Ryland's fires, Celgearn's shock floors, Castle Zygara's switches, Aelita's illusions, the run from Angie
# and the S.S. Paradise's lasers. Without the assist, what the screen shows; with it, the way.
class RejuvenationPuzzlesGTest < PokeAccessTest
  SWITCHES = [1006, 1007, 1009, 1260, 1261, 1272, 1370, 1371, 1373, 1374, 1375, 1917]
  VARS = [28, 195, 311, 383, 482, 505, 772, 837]
  # Terajuma's second basement as the map lays it out: the rooms each ball's doorway joins, in
  # RejuvLighthousePlasma::ROOMS places (:goal, the Ampharos room), with the switch and the value that take it away; and
  # the room of each button.
  PLASMA_DOORS = [[0, 3, 1373, false], [0, 4, 1373, true], [0, 1, 1370, true], [1, 2, 1370, false],
                  [2, 4, 1371, false], [2, 5, 1374, true], [5, 8, 1374, true], [3, 6, 1370, true], [6, 7, 1371, true],
                  [8, :goal, 1375, true]]
  PLASMA_ROOMS = { 38 => 3, 39 => 6, 41 => 7, 43 => 1, 45 => 4, 47 => 8 }
  # What each button's page writes, and the tile it is drawn on.
  PLASMA_WRITES = { 38 => { 1370 => true, 1373 => false }, 39 => { 1371 => true, 1370 => false },
                    41 => { 1373 => true, 1370 => true }, 43 => { 1370 => false, 1371 => false },
                    45 => { 1370 => true, 1371 => true, 1373 => true, 1374 => true },
                    47 => { 1370 => true, 1371 => true, 1373 => true, 1374 => false, 1375 => true } }
  PLASMA_TILES = { 38 => [14, 49], 39 => [19, 49], 41 => [23, 49], 43 => [5, 61], 45 => [14, 53], 47 => [27, 61] }
  # A floor tile of each room, in ROOMS order.
  PLASMA_SPOTS = [[7, 47], [5, 61], [10, 60], [14, 49], [14, 53], [18, 60], [19, 49], [23, 49], [27, 61]]
  # Page 1 of event 23 of the Hidden Axis Lab (map 145) as [code, indent, parameters], read from the game's data, but
  # for its move routes, sounds, pictures and waits, its message continuations and the words after each speaker.
  DELPHA_ROWS = [
    [122, 0, [298, 298, 0, 0, 0]], [101, 0, ["AELITA:"]], [101, 0, ["DELPHA:"]], [101, 0, ["ADAM:"]],
    [101, 0, ["ERICK1:"]], [101, 0, ["..."]], [101, 0, ["ERICK2:"]], [101, 0, ["..."]], [101, 0, ["ERICK1:"]],
    [101, 0, ["ERICK2:"]], [101, 0, ["DELPHA:"]], [101, 0, ["..."]], [101, 0, ["..."]], [101, 0, ["ADAM:"]],
    [101, 0, ["AELITA:"]], [101, 0, ["AELITA:"]], [101, 0, ["AELITA1:"]], [101, 0, ["AELITA2:"]],
    [101, 0, ["AELITA1:"]], [101, 0, ["..."]], [101, 0, ["AELITA2:"]], [101, 0, ["..."]], [101, 0, ["AELITA1:"]],
    [101, 0, ["ADAM:"]], [101, 0, ["DELPHA:"]], [101, 0, ["..."]], [101, 0, ["ERICK 1/ERICK 2:"]],
    [101, 0, ["\\sh\\c[7]ERICK 1/ERICK 2:"]], [101, 0, ["DELPHA:"]], [101, 0, ["..."]], [118, 0, ["q"]],
    [101, 0, ["..."]], [102, 0, [["Erick 1", "Erick 2", "Choose an imposter!"], 0]], [402, 0, [0, "Erick 1"]],
    [118, 1, ["Erick1Q"]], [101, 1, ["ERICK1:"]], [101, 1, ["..."]],
    [102, 1, [["Favorite Character?", "Gym Field?", "Favorite Invention?", "None"], 4]],
    [402, 1, [0, "Favorite Character?"]], [101, 2, ["ERICK1:"]], [101, 2, ["..."]], [101, 2, ["..."]],
    [101, 2, ["..."]], [119, 2, ["Erick1Q"]], [0, 2, []], [402, 1, [1, "Gym Field?"]], [101, 2, ["ERICK1:"]],
    [101, 2, ["..."]], [119, 2, ["Erick1Q"]], [0, 2, []], [402, 1, [2, "Favorite Invention?"]], [101, 2, ["ERICK1:"]],
    [101, 2, ["..."]], [119, 2, ["Erick1Q"]], [0, 2, []], [402, 1, [3, "None"]], [119, 2, ["q"]], [0, 2, []],
    [404, 1, []], [0, 1, []], [402, 0, [1, "Erick 2"]], [118, 1, ["Erick2Q"]], [101, 1, ["ERICK2:"]],
    [102, 1, [["Favorite Character?", "Gym Field?", "Favorite Invention?", "None"], 4]],
    [402, 1, [0, "Favorite Character?"]], [101, 2, ["ERICK1:"]], [101, 2, ["..."]], [101, 2, ["..."]],
    [119, 2, ["Erick2Q"]], [0, 2, []], [402, 1, [1, "Gym Field?"]], [101, 2, ["ERICK1:"]], [119, 2, ["Erick2Q"]],
    [0, 2, []], [402, 1, [2, "Favorite Invention?"]], [101, 2, ["ERICK1:"]], [119, 2, ["Erick2Q"]], [0, 2, []],
    [402, 1, [3, "None"]], [119, 2, ["q"]], [0, 2, []], [404, 1, []], [0, 1, []], [402, 0, [2, "Choose an imposter!"]],
    [101, 1, ["DELPHA:"]], [102, 1, [["Erick 1", "Erick 2", "Rethink this..."], 2]], [402, 1, [0, "Erick 1"]],
    [101, 2, ["ADAM:"]], [101, 2, ["DELPHA:"]], [101, 2, ["..."]], [101, 2, ["ERICK1:"]], [101, 2, ["ERICK1:"]],
    [101, 2, ["\\sh\\c[7]ERICK:"]], [101, 2, ["ERICK?:"]], [101, 2, ["SEC DRONE:"]], [101, 2, ["..."]],
    [355, 2, ["pbFieldDamage"]], [355, 2, ["pbFieldDamage"]], [355, 2, ["pbFieldDamage"]], [101, 2, ["..."]],
    [122, 2, [482, 482, 2, 0, 4]], [101, 2, ["\\sh\\c[7]ERICK:"]], [101, 2, ["DELPHA:"]], [101, 2, ["ERICK:"]],
    [0, 2, []], [402, 1, [1, "Erick 2"]], [101, 2, ["ADAM:"]], [101, 2, ["DELPHA:"]], [101, 2, ["..."]],
    [101, 2, ["SEC DRONE:"]], [101, 2, ["ADAM:"]], [101, 2, ["SEC DRONE:"]], [122, 2, [482, 482, 1, 0, 6]],
    [101, 2, ["ERICK:"]], [0, 2, []], [402, 1, [2, "Rethink this..."]], [119, 2, ["q"]], [0, 2, []], [404, 1, []],
    [0, 1, []], [404, 0, []], [101, 0, ["ADAM:"]], [101, 0, ["..."]], [101, 0, ["AELITA2:"]], [101, 0, ["..."]],
    [101, 0, ["AELITA1:"]], [101, 0, ["..."]], [101, 0, ["AELITA2:"]], [101, 0, ["..."]], [101, 0, ["AELITA1:"]],
    [101, 0, ["DELPHA:"]], [102, 0, [["Aelita 1", "Aelita 2"], 0]], [402, 0, [0, "Aelita 1"]], [101, 1, ["DELPHA:"]],
    [101, 1, ["..."]], [101, 1, ["AELITA:"]], [101, 1, ["CLEAR:"]], [101, 1, ["..."]], [101, 1, ["..."]],
    [101, 1, ["..."]], [101, 1, ["AELITA:"]], [101, 1, ["..."]], [101, 1, ["CLEAR:"]], [0, 1, []],
    [402, 0, [1, "Aelita 2"]], [101, 1, ["DELPHA:"]], [101, 1, ["..."]], [101, 1, ["AELITA:"]],
    [122, 1, [383, 383, 2, 0, 4]], [101, 1, ["AELITA:"]], [355, 1, ["pbFieldDamage"]], [355, 1, ["pbFieldDamage"]],
    [355, 1, ["pbFieldDamage"]], [101, 1, ["..."]], [101, 1, ["CLEAR:"]], [101, 1, ["..."]], [101, 1, ["..."]],
    [102, 1, [["Aelita, I'm sorry...", "Could've been more clear!"], 0]], [402, 1, [0, "Aelita, I'm sorry..."]],
    [122, 2, [383, 383, 1, 0, 1]], [101, 2, ["AELITA:"]], [0, 2, []], [402, 1, [1, "Could've been more clear!"]],
    [122, 2, [383, 383, 2, 0, 2]], [101, 2, ["AELITA:"]], [0, 2, []], [404, 1, []], [0, 1, []], [404, 0, []],
    [101, 0, ["CLEAR:"]], [355, 0, ["pbCameraReset"]], [101, 0, ["DELPHA:"]], [101, 0, ["KIERAN:"]],
    [101, 0, ["CLEAR:"]], [101, 0, ["KIERAN:"]], [101, 0, ["DELPHA:"]], [101, 0, ["CLEAR:"]], [101, 0, ["..."]],
    [101, 0, ["..."]], [101, 0, ["NAGANADEL:"]], [101, 0, ["AELITA:"]], [111, 0, [1, 200, 0, 0, 0]],
    [122, 1, [704, 704, 0, 0, 2]], [0, 1, []], [411, 0, []], [111, 1, [1, 200, 0, 1, 0]],
    [122, 2, [704, 704, 0, 0, 1]], [0, 2, []], [411, 1, []], [111, 2, [1, 200, 0, 2, 0]],
    [122, 3, [704, 704, 0, 0, 3]], [0, 3, []], [412, 2, []], [0, 2, []], [412, 1, []], [0, 1, []], [412, 0, []],
    [111, 0, [12, "pbTrainerBattle(:UNKNOWN_2,\"Clear\",\"\",false,0,true)"]], [101, 1, ["AELITA:"]],
    [101, 1, ["..."]], [101, 1, ["..."]], [101, 1, ["CLEAR:"]], [101, 1, ["..."]], [101, 1, ["KIERAN:"]],
    [101, 1, ["AELITA:"]], [101, 1, ["CLEAR:"]], [101, 1, ["KIERAN:"]], [0, 1, []], [411, 0, []],
    [122, 1, [383, 383, 2, 0, 1]], [122, 1, [393, 393, 2, 0, 1]], [122, 1, [392, 392, 2, 0, 1]],
    [122, 1, [482, 482, 2, 0, 1]], [101, 1, ["CLEAR:"]], [101, 1, ["..."]], [101, 1, ["..."]], [101, 1, ["KIERAN:"]],
    [101, 1, ["AELITA:"]], [101, 1, ["CLEAR:"]], [101, 1, ["KIERAN:"]], [0, 1, []], [412, 0, []],
    [101, 0, ["AELITA:"]], [201, 0, [0, 151, 47, 10, 0, 1]], [122, 0, [646, 646, 0, 0, 75]], [0, 0, []]
  ]

  def setup
    super
    keyed
    Harness.load_puzzles("rejuvenation")
    @at = [$game_player.x, $game_player.y]
    @map = $game_map.map_id
    @selfs = $game_self_switches
  end

  def teardown
    World.clear_events
    SWITCHES.each { |s| $game_switches[s] = false }
    VARS.each { |v| $game_variables[v] = 0 }
    $game_self_switches = @selfs
    $game_player.x, $game_player.y = @at
    $game_map.map_id = @map
    PokeAccess::Config.puzzle_assist = false
    PokeAccess::Puzzles::Answers.forget
    PokeAccess::World::Mechanics.forget
    PokeAccess::Caches.reset_all
    unkeyed
    super
  end

  test "Terajuma's buttons, pressed as the assist names them from the arrival, open the Ampharos room in five" do
    lh = PokeAccess::RejuvLighthousePlasma
    on_map(120, 7, 47)
    $game_variables[311] = 6
    assert_equal [38, 43, 45, 43, 47], follow_plasma(lh)
    assert_equal :open, lh.next_step
    assert $game_switches[1375]
  end

  test "Terajuma's plan leads to the Ampharos room from each room and set a walk from the arrival reaches" do
    lh = PokeAccess::RejuvLighthousePlasma
    planned = []
    lh::PLAN.each { |bits, row| row.each_with_index { |step, r| planned.push([r, bits]) unless step.nil? } }
    assert_equal plasma_reached.sort, planned.sort
    planned.each do |r, bits|
      on_map(120, *PLASMA_SPOTS[r])
      $game_variables[311] = 6
      fewest = plasma_fewest(r, bits)
      plasma_set(bits)
      pressed = follow_plasma(lh)
      assert_equal :open, lh.next_step, "room #{r} with #{bits}, after #{pressed.inspect}"
      assert_equal fewest, pressed.size, "room #{r} with #{bits}: #{pressed.inspect}"
    end
    on_map(120, 7, 47)
    $game_variables[311] = 6
    PokeAccess::Config.puzzle_assist = true
    [1370, 1373].each { |s| $game_switches[s] = true }
    assert_includes info_key, "{rjg_lh_next n=4}", "the set button 41 leaves after all off"
    $game_switches[1371] = true
    $game_switches[1373] = false
    $game_switches[1374] = true
    assert_includes info_key, "{rjg_lh_next n=5}", "the set button 38 leaves after 45"
    on_map(120, 18, 60)
    $game_variables[311] = 6
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, "{rjg_lh_restart}", "a room no way reaches with the switches all off"
  end

  test "Terajuma's ball faded out on its page is left out of the lists, and with the assist named as a barrier" do
    on_map(120, 20, 48)
    $game_variables[311] = 6
    ball = place(33, 21, 47, "Eball3", 1, "anim_plasma")
    assert_equal "{rjg_lh_ball}", PokeAccess::Puzzles.piece_name(ball)
    assert_includes listed, [21, 47, "{rjg_lh_ball}"]
    refute PokeAccess::Locator.hidden?(ball)
    ball.define_singleton_method(:opacity) { 0 }
    assert PokeAccess::Locator.hidden?(ball)
    refute(listed.any? { |x, y, _name| [x, y] == [21, 47] })
    PokeAccess::Config.puzzle_assist = true
    refute PokeAccess::Locator.hidden?(ball)
    assert_equal "{rjg_lh_unseen}", PokeAccess::Puzzles.piece_name(ball)
    assert_includes listed, [21, 47, "{rjg_lh_unseen}"]
  end

  test "Terajuma's buttons and balls are named for anyone, and the next button is said with the assist alone" do
    on_map(120, 7, 47)
    $game_variables[311] = 6
    button = place(38, 14, 49, "EV038", 1)
    ball = place(32, 16, 47, "Ebal2", 1, "anim_plasma")
    assert_equal "{rjg_lh_button n=1}", PokeAccess::Puzzles.piece_name(button)
    assert_equal "{rjg_lh_ball}", PokeAccess::Puzzles.piece_name(ball)
    refute_includes info_key, "rjg_lh_next"
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, "{rjg_lh_next n=1}"
    $game_player.x, $game_player.y = [5, 60]
    assert_includes info_key, "{rjg_lh_next n=4}"
    $game_switches[1375] = true
    assert_includes info_key, "{rjg_lh_next n=4}", "the Ampharos room's ball gone, the balls before it still stand"
    [1370, 1371, 1373].each { |s| $game_switches[s] = true }
    $game_player.x, $game_player.y = [27, 60]
    assert_includes info_key, "{rjg_lh_open}"
    $game_variables[311] = 7
    refute_includes info_key, "rjg_lh_"
  end

  test "Mirage Woods' mirages are listed whole with the assist alone, and for anyone once they fade" do
    on_map(149, 23, 57)
    tree = place(1, 23, 56, "Mirage Tree", 1, "object_mirage")
    refute(listed.any? { |_x, _y, name| name.to_s.include?("rjg_mw_") })
    PokeAccess::Config.puzzle_assist = true
    assert_includes listed, [23, 56, "{rjg_mw_mirage}"]
    PokeAccess::Config.puzzle_assist = false
    tree.define_singleton_method(:opacity) { 100 }
    assert_includes listed, [23, 56, "{rjg_mw_faded}"]
  end

  test "Ryland's fires are named, and their count stops at the forty he asks for, with the assist alone" do
    fires = PokeAccess::RejuvRylandFires
    on_map(650, 30, 30)
    assert_equal "{rjg_fl_fire}", PokeAccess::Puzzles.piece_name(place(20, 31, 30, "fire", 1, "object_flames"))
    $game_variables[837] = 57
    assert_equal 40, fires.out
    refute_includes info_key, "rjg_fl_hint"
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, "{rjg_fl_hint}"
    $game_switches[1917] = true
    refute_includes info_key, "{rjg_fl_hint}"
  end

  test "Celgearn's shock floors are named for anyone, touching ones as one" do
    on_map(616, 20, 26)
    place(1, 19, 24, "Shock", 1)
    place(2, 18, 24, "Shock", 1)
    assert_equal 1, listed.count { |_x, _y, name| name == "{rjg_cm_shock}" }
  end

  test "Castle Zygara's switches say whether they are down, and the assist follows them" do
    on_map(603, 111, 90)
    blue = place(38, 111, 92, "Blue Switch", 1)
    green = place(42, 99, 92, "Blue Switch", 1)
    assert_equal "{rjg_cz_blue}", PokeAccess::Puzzles.piece_name(blue)
    refute_includes info_key, "rjg_cz_hint"
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, "{rjg_cz_hint_blue}"
    $game_switches[1260] = true
    assert_equal "{rjg_cz_blue_on}", PokeAccess::Puzzles.piece_name(blue)
    assert_includes info_key, "{rjg_cz_hint_green}"
    $game_switches[1260] = false
    $game_switches[1261] = true
    assert_equal "{rjg_cz_green_on}", PokeAccess::Puzzles.piece_name(green)
    assert_includes info_key, "{rjg_cz_hint_done}"
  end

  test "Delpha's impostors on the event's own page: Erick's said as his choice is picked, Aelita's as her menu opens" do
    on_map(145, 18, 24)
    place(23, 18, 24, "EV023", 1)
    list = DELPHA_ROWS.map { |code, indent, params| TestCmd.new(code, params, indent) }
    top = list.index { |c| c.code == 102 }
    pick = list.index { |c| c.code == 402 && c.indent == 0 && c.parameters == [2, "Choose an imposter!"] }
    ericks = list.index { |c| c.code == 102 && c.parameters[0].include?("Rethink this...") }
    aelitas = list.index { |c| c.code == 102 && c.parameters[0] == ["Aelita 1", "Aelita 2"] }
    assert_equal [], branch_lines(list, pick, 2)
    assert_nil menu_answer(list, aelitas - 1)
    PokeAccess::Config.puzzle_assist = true
    assert_equal ["{rjg_ax_erick}"], branch_lines(list, pick, 2)
    assert_equal [], branch_lines(list, top + 1, 0), "asking the first Erick questions"
    assert_nil menu_answer(list, top - 1), "who to ask: either Erick, or the choice"
    assert_nil menu_answer(list, ericks - 1), "both Ericks write his affection: the choice's line says it"
    assert_equal "{puzzle_answer a=Aelita 1}", menu_answer(list, aelitas - 1)
  end

  test "the run from Angie says its rule as it starts, and counts the target's hits up to three" do
    run = PokeAccess::RejuvAngieEscape
    on_map(346, 62, 40)
    refute_includes frame, "{rjg_an_escape}"
    assert_includes frame { $game_variables[772] = 1 }, "{rjg_an_escape}"
    $game_variables[505] = 5
    assert_equal 3, run.hits
    $game_variables[772] = 2
    assert_equal 0, run.hits
  end

  test "the S.S. Paradise's buttons are named by colour, and a laser leaves the list once its colour is on" do
    on_map(456, 16, 72)
    assert_equal "{rjg_sp_button_red}", PokeAccess::Puzzles.piece_name(place(70, 38, 13, "EV070", 1))
    place(73, 15, 70, "EV073", 1)
    place(74, 16, 70, "EV074", 1)
    assert_includes listed.map { |_x, _y, name| name }, "{rjg_sp_laser_red}"
    $game_switches[1006] = true
    refute_includes listed.map { |_x, _y, name| name }, "{rjg_sp_laser_red}"
  end

  test "Lost Castle's Dusclops has each of its five nested book codes said with the assist as it asks" do
    on_map(219, 10, 41)
    assert_equal "{rjg_lc_book}", PokeAccess::Puzzles.piece_name(place(41, 43, 47, "EV041"))
    list = dusclops_list
    int = Object.new
    { :@list => list, :@index => 0, :@event_id => 25 }.each { |k, v| int.instance_variable_set(k, v) }
    PokeAccess::Config.puzzle_assist = true
    said = [1, 5, 9, 13, 17].map do |i|
      int.instance_variable_set(:@index, i)
      PokeAccess::Puzzles::Answers.before_text(int)
      PokeAccess.take_tail
    end
    assert_equal [44, 6677, 3645, 9043, 7171].map { |n| "{puzzle_answer a=#{n}}" }, said
  end

  # Event 25's page as the game lays it out: each right code opens the next entry one level in.
  def dusclops_list
    list = []
    codes = [44, 6677, 3645, 9043, 7171]
    codes.each_with_index do |code, depth|
      list.push(TestCmd.new(101, ["DUSCLOPS: Provide the correct book code."], depth))
      list.push(TestCmd.new(101, ["\"Book #{depth}\""], depth))
      list.push(TestCmd.new(103, [28, 4], depth))
      list.push(TestCmd.new(111, [1, 28, 0, code, 0], depth))
    end
    list.push(TestCmd.new(122, [195, 195, 0, 0, 9], codes.length))
    codes.length.downto(1) do |depth|
      list.push(TestCmd.new(0, [], depth))
      list.push(TestCmd.new(411, [], depth - 1))
      list.push(TestCmd.new(101, ["DUSCLOPS: That is incorrect..."], depth))
      list.push(TestCmd.new(115, [], depth))
      list.push(TestCmd.new(0, [], depth))
      list.push(TestCmd.new(412, [], depth - 1))
    end
    list.push(TestCmd.new(0, [], 0))
    list
  end

  private

  # The rooms of Terajuma's second basement a walk reaches from room `from` (RejuvLighthousePlasma::ROOMS places, :goal
  # past the last ball) through the doorways whose ball is away under the live switches.
  def plasma_reach(from)
    seen = [from]
    queue = [from]
    until queue.empty?
      r = queue.shift
      PLASMA_DOORS.each do |a, b, s, open|
        next unless ($game_switches[s] ? true : false) == open
        [[a, b], [b, a]].each { |p, q| (seen.push(q) && queue.push(q)) if p == r && !seen.include?(q) }
      end
    end
    seen
  end

  # Sets Terajuma's five switches to a set written as 0 and 1.
  def plasma_set(bits)
    PokeAccess::RejuvLighthousePlasma::SWITCHES.each_with_index { |s, k| $game_switches[s] = bits[k, 1] == "1" }
  end

  # The [room, set] that each button a walk reaches from room under the set leaves the player in.
  def plasma_presses(room, bits)
    plasma_set(bits)
    rooms = plasma_reach(room)
    PLASMA_ROOMS.select { |_b, r| rooms.include?(r) }.map do |b, r|
      on = PokeAccess::RejuvLighthousePlasma::SWITCHES.map { |s| PLASMA_WRITES[b].fetch(s, $game_switches[s]) }
      [r, on.map { |v| v ? "1" : "0" }.join]
    end
  end

  # Every [room, set] a walk on Terajuma's second basement reaches from the arrival's room under any of the 32 sets,
  # pressing the buttons on the way.
  def plasma_reached
    seen = (0...32).map { |i| [0, format("%05b", i)] }
    queue = seen.dup
    until queue.empty?
      room, bits = queue.shift
      plasma_set(bits)
      after = plasma_reach(room).reject { |r| r == :goal }.map { |r| [r, bits] } + plasma_presses(room, bits)
      after.each { |n| (seen.push(n) && queue.push(n)) unless seen.include?(n) }
    end
    seen
  end

  # The fewest presses from room under the set until a walk reaches the Ampharos room, or nil past ten.
  def plasma_fewest(room, bits)
    layer = [[room, bits]]
    seen = layer.dup
    11.times do |n|
      return n if layer.any? { |r, b| plasma_set(b) && plasma_reach(r).include?(:goal) }
      layer = layer.map { |r, b| plasma_presses(r, b) }.flatten(1).uniq - seen
      seen.concat(layer)
    end
    nil
  end

  # Presses the buttons the assist names on Terajuma's second basement, each one walked to through open doorways,
  # standing on it and writing what its page writes, until the step is no button or ten are pressed; the buttons
  # pressed. An open way has to reach the Ampharos room.
  def follow_plasma(lh)
    pressed = []
    while (b = lh.next_step).is_a?(Integer) && pressed.size < 10
      assert_includes plasma_reach(lh.room), PLASMA_ROOMS[b], "button #{b} after #{pressed.inspect}"
      pressed.push(b)
      PLASMA_WRITES[b].each { |s, v| $game_switches[s] = v }
      $game_player.x, $game_player.y = PLASMA_TILES[b]
    end
    assert_includes plasma_reach(lh.room), :goal, "open after #{pressed.inspect}" if lh.next_step == :open
    pressed
  end

  # A map interpreter on event 23's page at command i, with the menu options taken so far by indent.
  def delpha_interpreter(list, i, branch = {})
    int = Object.new
    ivars = { :@list => list, :@index => i, :@event_id => 23, :@branch => branch }
    ivars.each { |k, v| int.instance_variable_set(k, v) }
    int
  end

  # What is said as the interpreter runs the When at list[i] with option n taken at its indent.
  def branch_lines(list, i, n)
    SpeakCapture.clear
    PokeAccess::Puzzles::Reach.before_when(delpha_interpreter(list, i, { list[i].indent => n }))
    SpeakCapture.lines
  end

  # What the assist says after the Show Text at list[i], for the menu that follows it.
  def menu_answer(list, i)
    PokeAccess::Puzzles::Answers.forget
    PokeAccess.take_tail
    PokeAccess::Puzzles::Answers.before_text(delpha_interpreter(list, i))
    PokeAccess.take_tail
  end

  # Makes I18n.t answer each key and its values as "{key name=value ...}", so what the puzzles say is compared by its
  # keys and values rather than by the text of a language.
  def keyed
    i18n = PokeAccess::I18n.singleton_class
    i18n.send(:alias_method, :rjg_kept_t, :t)
    i18n.send(:define_method, :t) do |key, vars = nil|
      parts = [key.to_s] + (vars || {}).map { |k, v| "#{k}=#{v}" }.sort
      "{#{parts.join(' ')}}"
    end
  end

  # Gives I18n.t back its own body.
  def unkeyed
    i18n = PokeAccess::I18n.singleton_class
    i18n.send(:alias_method, :t, :rjg_kept_t)
    i18n.send(:remove_method, :rjg_kept_t)
  end

  def on_map(map, x, y)
    PokeAccess::Config.puzzle_assist = false
    World.clear_events
    $game_self_switches = {}
    SWITCHES.each { |s| $game_switches[s] = false }
    VARS.each { |v| $game_variables[v] = 0 }
    $game_map.map_id = map
    $game_player.x = x
    $game_player.y = y
    PokeAccess::Caches.reset_all
    PokeAccess::World::Mechanics.forget
    World.next_frame
  end

  def place(id, x, y, name, trigger = 0, sprite = "")
    page = TestPage.new(:trigger => trigger, :sprite => sprite,
                        :list => [TestCmd.new(101, ["text"]), TestCmd.new(0, [])])
    ev = TestGameEvent.new(:id => id, :x => x, :y => y, :name => name, :pages => [page], :active_page => page)
    $game_map.events[id] = ev
    World.next_frame
    ev
  end

  def frame
    SpeakCapture.clear
    yield if block_given?
    World.next_frame
    PokeAccess::Puzzles.tick
    SpeakCapture.lines
  end

  def info_key
    PokeAccess::Info.map_text.to_s
  end

  def listed
    PokeAccess::Puzzles.category_targets.select { |tg| tg.is_a?(PokeAccess::Locator::SurfaceTarget) }
                       .map { |tg| [tg.x, tg.y, tg.name] }
  end
end
