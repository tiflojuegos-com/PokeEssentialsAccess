# Pokemon Rejuvenation's story puzzles, part A (games/rejuvenation/puzzles/): the sewer monitors, the Goldenwood
# briefcase, Chrysalis' passwords, the laboratory terminals, Wispy Chasm's Shuppet, Madelis' plates, the Backstage
# Theatre's torches, Wispy Tower's statue, Keta's stone, Blacksteeple's notes, the Three Trials' statues, Aquamarine's
# marks and the Kakori gym. Without the assist, what the screen shows; with it, the way.
class RejuvenationPuzzlesATest < PokeAccessTest
  SWITCHES = [476, 501, 669, 816, 951, 952, 953, 1039, 1040, 1041, 1042, 1437, 1558, 1559, 1560, 1561]
  VARS = [49, 96, 214, 232, 325, 359, 363, 370, 406, 525, 659, 682, 720, 721, 722]

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
    PokeAccess::World::Mechanics.forget
    PokeAccess::Caches.reset_all
    unkeyed
    super
  end

  test "the sewer monitors go by their number, and the assist says the next one: 3, 1 and 2 last" do
    on_map(55, 5, 44)
    $game_variables[659] = 16
    one = place(12, 2, 43, "EV012")
    place(11, 5, 40, "EV011")
    place(13, 8, 43, "EV013")
    refute(frame.any? { |l| l.include?("rj_sewer_next") }, "no order without the assist")
    assert_equal "{rj_sewer_monitor n=1}", PokeAccess::Puzzles.piece_name(one)
    PokeAccess::Config.puzzle_assist = true
    assert_includes frame, "{rj_sewer_next n=3}"
    $game_switches[951] = true
    assert_includes frame, "{rj_sewer_next n=1}"
    $game_switches[952] = true
    assert_includes frame, "{rj_sewer_next n=2}"
    $game_switches[951] = false
    $game_switches[952] = false
    $game_switches[953] = true
    assert_includes frame, "{rj_sewer_undo}"
    assert_equal 2, PokeAccess::RejuvSewers.next_monitor
  end

  test "the Goldenwood briefcase says 6489 with the assist while its page compares two codes" do
    on_map(50, 42, 40)
    briefcase = place(14, 42, 39, "Briefcase")
    refute_includes frame { fire(briefcase) }, "{puzzle_answer a=6489}"
    PokeAccess::Config.puzzle_assist = true
    assert_includes frame { fire(briefcase) }, "{puzzle_answer a=6489}"
    $game_self_switches[[50, 14, "A"]] = true
    refute_includes frame { fire(briefcase) }, "{puzzle_answer a=6489}", "the core says it once one code is left"
  end

  test "Chrysalis names its inscriptions and the panel until the hatch is open" do
    on_map(390, 31, 14)
    panel = place(40, 31, 13, "")
    note = place(41, 43, 110, "EV041")
    frame
    assert_equal "{rj_chrysalis_panel}", PokeAccess::Puzzles.piece_name(panel)
    assert_equal "{rj_chrysalis_inscription}", PokeAccess::Puzzles.piece_name(note)
    assert listed_event?(note)
    assert PokeAccess::RejuvChrysalis.shut?
    $game_variables[363] = 5
    frame
    refute PokeAccess::RejuvChrysalis.shut?
    refute listed_event?(note)
    on_map(391, 10, 39)
    first = place(3, 10, 38, "EV003")
    frame
    assert_equal "{rj_chrysalis_inscription}", PokeAccess::Puzzles.piece_name(first)
  end

  test "the laboratory names its two password terminals" do
    on_map(403, 45, 38)
    terminal = place(44, 64, 35, "EV044")
    frame
    assert_equal "{rj_lab_terminal}", PokeAccess::Puzzles.piece_name(terminal)
  end

  test "Wispy Chasm lists, with the assist alone, the tile that drives each Shuppet on, by where the player stands" do
    on_map(12, 18, 56)
    place(3, 19, 59, "Shuppet 1")
    frame
    assert_empty listed
    refute_equal "", info_key, "without the assist the info key is the map's own, not an empty puzzle line"
    PokeAccess::Config.puzzle_assist = true
    assert_equal [[18, 57, "{rj_chasm_step n=1}"]], listed
    shuppet = $game_map.events[3]
    shuppet.x = 18
    shuppet.y = 61
    assert_equal [[18, 59, "{rj_chasm_step n=1}"]], listed
    $game_player.x = 15
    $game_player.y = 65
    assert_equal [[16, 61, "{rj_chasm_step n=1}"]], listed, "from the low ledge the plan goes the other way"
    $game_switches[1039] = true
    assert_empty listed
    assert_includes info_key, "{rj_chasm_caught}"
  end

  test "Madelis' plates follow the seven steps, and off them the assist says how to start over" do
    lab = PokeAccess::RejuvMadelis
    on_map(124, 13, 27)
    $game_variables[214] = 1
    plate = place(54, 73, 11, "EV054")
    assert_equal 0, lab.step
    frame
    assert_includes info_key, "{rj_madelis_red}: {rj_madelis_unlit}, {rj_madelis_blue}: {rj_madelis_unlit}"
    $game_switches[1558] = true
    $game_self_switches[[124, 13, "B"]] = true
    assert_equal 1, lab.step
    assert_equal :rj_madelis_plate_red_yellow, lab.plate_label(plate)
    $game_switches[1558] = false
    $game_switches[1561] = true
    $game_self_switches[[124, 54, "B"]] = true
    assert_equal 2, lab.step
    assert_equal :rj_madelis_plate_grey, lab.plate_label(plate)
    $game_switches[1559] = true
    assert_nil lab.step
    PokeAccess::Config.puzzle_assist = true
    assert_includes frame, "{rj_madelis_reset_hint}"
    $game_switches[1559] = false
    assert_includes frame, "{rj_madelis_hint_plate name={rj_madelis_plate_green_blue} x=0 y=0}"
  end

  test "the theatre names its torches as they burn, says the chain starting over, and lists the right way" do
    on_map(401, 24, 57)
    torch = place(3, 26, 55, "EV003")
    torch.tile_id = 1812
    assert_equal :rj_theatre_torch_lit, PokeAccess::RejuvTheatre.torch_label(torch)
    torch.tile_id = 1811
    assert_equal :rj_theatre_torch_out, PokeAccess::RejuvTheatre.torch_label(torch)
    torch.tile_id = 0
    assert_nil PokeAccess::RejuvTheatre.torch_label(torch)
    door = place(8, 24, 56, "EV008")
    $game_variables[370] = 3
    frame
    $game_variables[370] = 0
    assert_includes frame, "{rj_theatre_start}"
    assert_empty listed
    PokeAccess::Config.puzzle_assist = true
    assert_equal [[door.x, door.y, "{puzzle_right_way}"]], listed
  end

  test "the theatre's walks keep off what sets the chain back from its value, and with the assist alone" do
    on_map(401, 30, 50)
    hex = place(21, 31, 28, "EV021", 1)
    plate = place(18, 33, 30, "EV018", 1)
    door = place(14, 37, 56, "EV014", 1)
    kept = lambda { |ev| PokeAccess::Routes::Controls.keep_off[PokeAccess::Routes.pkey(ev.x, ev.y)] ? true : false }
    assert_equal [false, false, false], [hex, plate, door].map { |ev| kept.call(ev) }, "nothing kept off unassisted"
    PokeAccess::Config.puzzle_assist = true
    assert_equal [true, false, true], [hex, plate, door].map { |ev| kept.call(ev) }
    $game_variables[370] = 7
    assert_equal [false, false, true], [hex, plate, door].map { |ev| kept.call(ev) }
    $game_variables[370] = 12
    assert_equal [false, false, false], [hex, plate, door].map { |ev| kept.call(ev) }
    assert_equal [[door.x, door.y, "{puzzle_right_way}"]], listed, "events 21 and 22 stand past the door at 12"
    $game_variables[370] = 14
    assert_equal [true, false, false], [hex, plate, door].map { |ev| kept.call(ev) }
  end

  test "Wispy Tower's statue is a statue, and the stairs with the assist" do
    on_map(73, 14, 45)
    statue = place(9, 14, 44, "EV009", 1)
    frame
    assert_equal "{rj_wispy_statue}", PokeAccess::Puzzles.piece_name(statue)
    PokeAccess::Config.puzzle_assist = true
    assert_equal "{rj_wispy_statue_stairs}", PokeAccess::Puzzles.piece_name(statue)
  end

  test "Keta's stone is named until the passage opens" do
    on_map(4, 30, 43)
    stone = place(56, 30, 42, "EV056")
    frame
    assert_equal "{rj_amethyst_stone}", PokeAccess::Puzzles.piece_name(stone)
    assert listed_event?(stone)
    $game_variables[49] = 2
    frame
    refute listed_event?(stone)
  end

  test "Blacksteeple's notes: the assist says the book, the green wall, the false wall, the candelabra and the bookcase" do
    on_map(443, 21, 13)
    place(71, 21, 12, "EV071")
    $game_variables[232] = 48
    frame
    PokeAccess::Config.puzzle_assist = true
    assert_includes frame, "{rj_bs_hint_book}"
    $game_variables[232] = 59
    assert_includes frame, "{rj_bs_hint_candelabra}"
    $game_variables[232] = 60
    assert_includes frame, "{rj_bs_hint_bookcase}"
    $game_variables[232] = 61
    refute(frame.any? { |l| l.include?("rj_bs_hint") })
    on_map(437, 19, 17)
    PokeAccess::Config.puzzle_assist = true
    place(3, 34, 47, "EV003")
    $game_variables[232] = 49
    frame
    $game_variables[232] = 51
    assert_includes frame, "{rj_bs_hint_false_wall}"
    assert_equal [[34, 47, "{puzzle_right_way}"]], listed
  end

  test "push legs: what is left from where the piece stands, and nothing off its path" do
    legs = PokeAccess::RejuvPushLegs
    path = [[4, 14], [2, 6]]
    assert_equal [[4, 14, 79, 68], [2, 6, 64, 67]], legs.left([78, 68], path, [78, 68])
    assert_equal [[4, 6, 71, 68], [2, 6, 64, 67]], legs.left([78, 68], path, [70, 68])
    assert_equal [[2, 4, 64, 69]], legs.left([78, 68], path, [64, 70])
    assert_equal [], legs.left([78, 68], path, [64, 74])
    assert_nil legs.left([78, 68], path, [70, 69])
  end

  test "the Three Trials say the statue's plate and pushes with the assist, and start over through Tangrowth" do
    on_map(397, 79, 68)
    $game_switches[669] = true
    $game_variables[682] = 1
    red = place(48, 78, 68, "TangPzzle R Stat")
    frame
    PokeAccess::Config.puzzle_assist = true
    lines = frame
    assert(lines.any? { |l| l.include?("{rj_push_goal goal={rj_trials_plate_red} name={rj_trials_statue_red} x=64 y=74}") })
    assert(lines.any? { |l| l.include?("{rj_push_leg dir={dir_left} n=14 x=79 y=68}") })
    red.x = 70
    red.y = 69
    assert_includes info_key, "{rj_trials_reset_hint}"
    $game_variables[682] = 3
    assert_includes frame, "{rj_trials_tangrowth_hint}"
  end

  test "Aquamarine counts the marks covered by any piece, and with the assist takes each piece to its own" do
    aqua = PokeAccess::RejuvAquamarine
    on_map(323, 49, 58)
    $game_variables[96] = 63
    stone = place(61, 49, 59, "Black Shard")
    frame
    assert_equal 0, aqua.covered
    stone.x = 50
    stone.y = 61
    assert_includes frame, "{puzzle_progress label={rj_aqua_covered} n=1 of=6}"
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, "{rj_aqua_reset_hint}"
    stone.x = 49
    stone.y = 60
    assert_includes info_key, "{rj_push_leg dir={dir_down} n=1 x=49 y=59}"
    $game_switches[1437] = true
    assert_empty listed
  end

  test "Kakori's grass course says, with the assist, where to walk into the next rock, and past the Pinsir once it is gone" do
    gym = PokeAccess::RejuvKakori
    on_map(65, 10, 64)
    place(5, 11, 64, "EV005")
    refute(frame.any? { |l| l.include?("rj_kakori_jump") }, "no way without the assist")
    PokeAccess::Config.puzzle_assist = true
    assert_includes frame, "{rj_kakori_jump dir={dir_right} lx=12 ly=64 x=10 y=64}"
    $game_switches[476] = true
    $game_player.x = 32
    $game_player.y = 52
    pinsir = place(61, 37, 53, "Pinsir")
    assert_equal 17, gym.grass_step
    pinsir.instance_variable_set(:@erased, true)
    assert_equal 18, gym.grass_step
    assert_equal [:rj_kakori_stairs, { :x => 35, :y => 54, :dir => "{dir_up}" }], gym.say(gym::COURSE1[18])
    $game_variables[720] = 4
    assert_nil gym.grass_step
    assert_includes frame, "{puzzle_progress label={rj_kakori_sigils} n=1 of=3}"
  end

  test "Kakori's fire course sends the player to the log first, then out and in by the other door" do
    gym = PokeAccess::RejuvKakori
    on_map(154, 25, 42)
    assert_equal 0, gym.fire_step
    $game_variables[406] = 1
    assert_equal 1, gym.fire_step
    assert_equal [:rj_kakori_door, { :x => 25, :y => 43, :dx => 6, :dy => 13 }], gym.say(gym::COURSE2[1])
    $game_player.x = 8
    $game_player.y = 40
    $game_switches[816] = true
    assert_equal 2, gym.fire_step
    $game_variables[721] = 1
    assert_nil gym.fire_step
  end

  private

  # Makes I18n.t answer each key and its values as "{key name=value ...}", so what the puzzles say is compared by its
  # keys and values rather than by the text of a language.
  def keyed
    i18n = PokeAccess::I18n.singleton_class
    i18n.send(:alias_method, :rja_kept_t, :t)
    i18n.send(:define_method, :t) do |key, vars = nil|
      parts = [key.to_s] + (vars || {}).map { |k, v| "#{k}=#{v}" }.sort
      "{#{parts.join(' ')}}"
    end
  end

  # Gives I18n.t back its own body.
  def unkeyed
    i18n = PokeAccess::I18n.singleton_class
    i18n.send(:alias_method, :t, :rja_kept_t)
    i18n.send(:remove_method, :rja_kept_t)
  end

  def fire(ev)
    PokeAccess::Puzzles::Auto.fired($game_system.map_interpreter, PokeAccess.ivar(ev, :@list), ev.id)
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

  def place(id, x, y, name, trigger = 0)
    page = TestPage.new(:trigger => trigger, :list => [TestCmd.new(101, ["text"]), TestCmd.new(0, [])])
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
                       .map { |tg| [tg.x, tg.y, tg.name] }.sort_by { |r| [r[0], r[1]] }
  end

  def listed_event?(ev)
    PokeAccess::Puzzles.category_targets.any? { |tg| tg.is_a?(PokeAccess::Locator::SurfaceTarget) && tg.ref == ev.id }
  end
end
