# Pokemon Rejuvenation's puzzles finished in the second wrap-up (games/rejuvenation/puzzles/): Xenpurgis F1's room of the
# turning grunts, the coloured arrows of Aelita's Nightmare Realm and the Xen Battleship's buttons. Without the assist,
# what the screen shows; with it, the next step of the plan.
class RejuvenationPuzzlesRjrbTest < PokeAccessTest
  SWITCHES = [1362, 1363, 1364, 1365, 1894]
  VARS = [522, 684, 731]

  def setup
    super
    keyed
    Harness.load_puzzles("rejuvenation")
    @at = [$game_player.x, $game_player.y]
    @map = $game_map.map_id
    @selfs = $game_self_switches
    $game_self_switches = {}
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

  test "the grunts' room names each grunt by corner and facing, and says where a switch turns her" do
    room
    grunt = $game_map.events[80]
    assert_equal "{rjrb_xs_grunt corner={rjf_xp_corner_nw} dir={face_south} square={rjrb_xs_north}}",
                 PokeAccess::Puzzles.piece_name(grunt)
    assert_equal "{rjrb_xs_statue corner={rjf_xp_corner_se} square={rjrb_xs_south}}",
                 PokeAccess::Puzzles.piece_name($game_map.events[89])
    assert_equal "{rjrb_xs_switch_south}", PokeAccess::Puzzles.piece_name($game_map.events[149])
    sp = PokeAccess::RejuvXenpurgisSpinner
    assert_equal [:rjrb_xs_turned, { :square => "{rjrb_xs_north}", :corner => "{rjf_xp_corner_sw}",
                                     :dir => "{face_west}" }], sp.turned($game_map.events[88])
    assert_equal [:rjrb_xs_turned, { :square => "{rjrb_xs_south}", :corner => "{rjf_xp_corner_sw}",
                                     :dir => "{face_west}" }], sp.turned($game_map.events[149])
    refute_includes info_key, "rjrb_xs_hint"
  end

  test "the assist walks the grunts' room: turn the north square, beat its grunt, turn the south one, beat, turn, ball" do
    room
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, "{rjrb_xs_hint_north times={rjf_xp_once}}"
    assert_includes listed, [42, 77, "{rjrb_xs_spot_press}"]
    turn(80, [38, 77], 4)
    turn(87, [38, 76])
    assert_includes info_key, "{rjrb_xs_hint_fight_north}"
    assert_includes listed, [37, 77, "{rjrb_xs_spot_fight}"]
    beat(80, true)
    assert_includes info_key, "{rjrb_xs_hint_south times={rjf_xp_once}}"
    turn(87, [39, 76])
    assert_includes info_key, "{rjrb_xs_hint_north times={rjf_xp_once}}"
    turn(87, [38, 76])
    turn(81, [49, 83], 4)
    turn(89, [50, 82])
    turn(85, [50, 83])
    assert_includes info_key, "{rjrb_xs_hint_fight_south}"
    assert_includes listed, [48, 83, "{rjrb_xs_spot_fight}"]
    beat(81, false)
    assert_includes info_key, "{rjrb_xs_hint_south times={rjf_xp_once}}"
    turn(81, [50, 83], 8)
    turn(89, [49, 82])
    turn(85, [50, 82])
    assert_includes info_key, "{rjrb_xs_hint_ball}"
    $game_map.events[166].character_name = ""
    assert_includes info_key, "{rjrb_xs_hint_door}"
    $game_switches[1894] = true
    refute_includes info_key, "rjrb_xs_"
  end

  test "the Nightmare Realm's plan names known zones, and buttons that light another colour than the one lit" do
    nm = PokeAccess::RejuvNightmareArrows
    assert_equal nm::GOALS.keys.sort, nm::PLAN.keys.sort
    nm::PLAN.each do |step, rows|
      rows.each do |zone, by|
        assert nm::ZONES.key?(zone), "step #{step} names zone #{zone}"
        by.each do |col, button|
          assert nm::BUTTONS.key?(button), "step #{step}, zone #{zone}: #{button}"
          refute_equal col, nm::BUTTONS[button], "step #{step}, zone #{zone}"
        end
      end
    end
  end

  test "the Nightmare Realm says the colour a button lights, and the assist the next button or the next point" do
    on_map(33, 8, 62)
    $game_variables[684] = 62
    $game_switches[1362] = true
    button = place(27, 7, 68, [TestCmd.new(121, [1363, 1363, 0])], "", 1)
    place(19, 12, 40, [TestCmd.new(101, ["text"])], "", 1)
    nm = PokeAccess::RejuvNightmareArrows
    assert_equal [:rjrb_nm_lights, { :color => "{rjf_nm_green}" }], nm.lights(button)
    refute_includes info_key, "rjrb_nm_press"
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, "{rjrb_nm_press color={rjf_nm_green}}"
    assert_includes listed, [7, 68, "{rjrb_nm_spot_button}"]
    $game_switches[1362] = false
    $game_switches[1363] = true
    assert_nil nm.lights(button)
    assert_includes info_key, "{rjrb_nm_go color={rjf_nm_green}}"
    assert_includes listed, [12, 40, "{rjrb_nm_spot_goal}"]
    $game_variables[684] = 67
    refute_includes info_key, "rjrb_nm_"
  end

  test "sent back by Risa above the arrows, the assist takes the lift down, and the plan again below it" do
    on_map(33, 15, 15)
    $game_variables[684] = 62
    $game_switches[1362] = true
    place(14, 3, 13, [TestCmd.new(101, ["text"])], "object_spacedoor")
    place(27, 7, 68, [TestCmd.new(121, [1363, 1363, 0])], "", 1)
    nm = PokeAccess::RejuvNightmareArrows
    PokeAccess::Config.puzzle_assist = true
    assert_equal [:lift, 14], nm.advice
    assert_includes info_key, "{rjrc_nm_lift}"
    assert_includes listed, [3, 13, "{rjrc_nm_spot_lift}"]
    $game_player.x = 3
    $game_player.y = 30
    World.next_frame
    assert_equal [:press, 27], nm.advice, "zone 0, where the lift lets the player out"
    refute_includes info_key, "rjrc_nm_lift"
  end

  test "the crimson quartz's room leaves by its floor at 38,13, the hall's column at x 43 reads as the hall, and the lifts' loop says it is shut until step 66" do
    nm = PokeAccess::RejuvNightmareArrows
    on_map(33, 38, 10)
    $game_variables[684] = 62
    $game_switches[1364] = true
    PokeAccess::Config.puzzle_assist = true
    assert_equal [:floor, 68], nm.advice
    assert_includes info_key, "{rjrv3_nm_quartz_out}"
    refute_includes info_key, "rjrc_nm_lift"
    $game_player.x = 43
    $game_player.y = 46
    World.next_frame
    assert_equal [:press, 105], nm.advice
    $game_switches[1364] = false
    $game_switches[1363] = true
    [[66, 34], [61, 70], [80, 71], [102, 60], [100, 48]].each do |x, y|
      $game_player.x = x
      $game_player.y = y
      [62, 63, 64].each do |s|
        $game_variables[684] = s
        World.next_frame
        assert_equal [:shut, nil], nm.advice, "(#{x}, #{y}) at step #{s}"
      end
      $game_variables[684] = 66
      World.next_frame
      assert_equal [:go, 84], nm.advice, "(#{x}, #{y}) at step 66"
    end
    $game_variables[684] = 63
    World.next_frame
    assert_includes info_key, "{rjrv2_nm_shut}"
    refute_includes info_key, "rjrb_nm_go"
  end

  test "the Xen Battleship's assist gives the first button for Venam alone, then each point of the ship to its way out" do
    on_map(318, 30, 45)
    $game_variables[731] = 49
    place(31, 31, 41, [TestCmd.new(122, [522, 522, 0, 0, 1])])
    place(48, 38, 56, [TestCmd.new(122, [522, 522, 0, 0, 2])])
    place(81, 20, 70, [TestCmd.new(122, [522, 522, 0, 0, 3])])
    last = place(91, 8, 51, [TestCmd.new(122, [731, 731, 0, 0, 53])])
    place(75, 29, 51, [TestCmd.new(101, ["text"])], "", 1)
    place(6, 16, 17, [TestCmd.new(101, ["text"])], "", 1)
    place(90, 24, 62, [TestCmd.new(101, ["text"])], "", 1)
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, "{rjrb_sh_go}", "the first point is walked to with no button"
    assert_includes listed, [29, 51, "{rjrb_sh_spot_point}"]
    refute_includes info_key, "rjrb_sh_press"
    $game_variables[731] = 50
    assert_includes info_key, "{rjrb_sh_press n=1}", "Venam's waits behind the first stairs"
    assert_includes listed, [31, 41, "{rjf_xs_next}"]
    $game_variables[522] = 1
    assert_includes info_key, "{rjrb_sh_go}"
    assert_includes listed, [24, 62, "{rjrb_sh_spot_point}"]
    $game_variables[731] = 52
    assert_includes info_key, "{rjrb_sh_last}", "the fourth button, with the first alone pressed"
    $game_variables[731] = 50
    $game_variables[522] = 0
    assert_includes info_key, "{rjrb_sh_press n=1}", "a gate up puts the count back to 0"
    $game_variables[731] = 52
    assert_includes info_key, "{rjrb_sh_last}", "the fourth button, with none pressed"
    { "es" => /escalera/i, "en" => /stair/i }.each do |code, word|
      %w[rjrb_sh_go rjrb_sh_last].each { |key| refute_match(word, PokeAccess::I18n.table(code)[key].to_s, "#{code} #{key}") }
    end
    assert_equal "{rjf_xs_button}", PokeAccess::Puzzles.piece_name(last)
    $game_variables[731] = 54
    assert_includes info_key, "{rjrb_sh_exit}"
    assert_includes listed, [16, 17, "{rjrb_sh_spot_exit}"]
    assert_equal "{rjf_xs_button_on}", PokeAccess::Puzzles.piece_name(last)
    $game_variables[731] = 55
    refute_includes info_key, "rjrb_sh_"
  end

  # Room 5 of Xenpurgis F1 as the map starts it: both grunts facing down, the player at its arrival.
  def room
    on_map(646, 37, 85)
    place(80, 38, 76, [TestCmd.new(101, ["text"])], "trchar057", 2)
    place(87, 39, 76, [TestCmd.new(101, ["text"])], "object_statues_3")
    place(81, 49, 82, [TestCmd.new(101, ["text"])], "trchar057", 2)
    place(85, 49, 83, [TestCmd.new(101, ["text"])], "object_statues_3")
    place(89, 50, 83, [TestCmd.new(101, ["text"])], "object_statues_3")
    place(88, 42, 77, [TestCmd.new(101, ["text"])], "", 1)
    place(149, 46, 83, [TestCmd.new(101, ["text"])], "", 1)
    place(166, 49, 77, [TestCmd.new(101, ["text"])], "object_soulball_base")
    place(58, 49, 75, [TestCmd.new(101, ["text"])], "object_gate_3")
  end

  def turn(id, xy, dir = nil)
    ev = $game_map.events[id]
    ev.x, ev.y = xy
    ev.direction = dir if dir
  end

  def beat(id, gone)
    $game_self_switches[[646, id, "A"]] = true
    $game_map.events[id].character_name = "" if gone
  end

  def listed
    World.next_frame
    PokeAccess::Puzzles.category_targets.select { |tg| tg.is_a?(PokeAccess::Locator::SurfaceTarget) }
                       .map { |tg| [tg.x, tg.y, tg.name] }
  end

  def keyed
    i18n = PokeAccess::I18n.singleton_class
    i18n.send(:alias_method, :rjrb_kept_t, :t)
    i18n.send(:define_method, :t) do |key, vars = nil|
      parts = [key.to_s] + (vars || {}).map { |k, v| "#{k}=#{v}" }.sort
      "{#{parts.join(' ')}}"
    end
  end

  def unkeyed
    i18n = PokeAccess::I18n.singleton_class
    i18n.send(:alias_method, :t, :rjrb_kept_t)
    i18n.send(:remove_method, :rjrb_kept_t)
  end

  def on_map(map, x, y)
    World.clear_events
    $game_map.map_id = map
    $game_player.x = x
    $game_player.y = y
    PokeAccess::Caches.reset_all
    PokeAccess::World::Mechanics.forget
    World.next_frame
  end

  def place(id, x, y, list, sprite = "", trigger = 0)
    page = TestPage.new(:trigger => trigger, :sprite => sprite, :list => list + [TestCmd.new(0, [])])
    ev = TestGameEvent.new(:id => id, :x => x, :y => y, :name => "EV#{id}", :pages => [page], :active_page => page)
    $game_map.events[id] = ev
    World.next_frame
    ev
  end

  def info_key
    World.next_frame
    PokeAccess::Info.map_text.to_s
  end
end
