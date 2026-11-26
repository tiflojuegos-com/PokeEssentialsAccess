# Pokemon Rejuvenation's puzzles of part F (games/rejuvenation/puzzles/): the Wetlands Laboratory's floor arrows,
# Xenpurgis F1's trampolines, Karen's corridor in the Hidden Library and the coloured arrows of Aelita's Nightmare Realm.
# Without the assist, what the screen shows; with it, the way.
class RejuvenationPuzzlesFTest < PokeAccessTest
  SWITCHES = [1151, 1152, 1153, 1154, 1362, 1363, 1364, 1365]
  VARS = [96, 265, 522, 731]

  def setup
    super
    keyed
    Harness.load_puzzles("rejuvenation")
    @at = [$game_player.x, $game_player.y]
    @map = $game_map.map_id
  end

  def teardown
    World.clear_events
    SWITCHES.each { |s| $game_switches[s] = false }
    VARS.each { |v| $game_variables[v] = 0 }
    $game_player.x, $game_player.y = @at
    $game_map.map_id = @map
    PokeAccess::Config.puzzle_assist = false
    PokeAccess::World::Mechanics.forget
    PokeAccess::Caches.reset_all
    unkeyed
    super
  end

  test "the Wetlands arrows are named by the way their live page pushes, and the consoles by how they are used" do
    on_map(222, 45, 80)
    $game_variables[96] = 26
    arrow = place(19, 16, 40, [World.move_player([1])], "object_arrowtile")
    console = place(36, 14, 43, [TestCmd.new(121, [1152, 1152, 0])])
    assert_equal "{rjf_wl_arrow dir={face_south}}", PokeAccess::Puzzles.piece_name(arrow)
    assert_equal "{rjf_wl_console}", PokeAccess::Puzzles.piece_name(console)
    left = place(31, 82, 41, [World.move_player([[44, []], 2])], "object_arrowtile")
    assert_equal "{rjf_wl_arrow dir={face_west}}", PokeAccess::Puzzles.piece_name(left)
    assert_nil PokeAccess::RejuvFloorArrows.way(place(44, 80, 28, [TestCmd.new(101, ["text"])], "object_arrowtile"))
  end

  test "the Wetlands way is said by room with the assist alone, and stops once Nastasia's room is reached" do
    on_map(222, 45, 80)
    $game_variables[96] = 26
    refute_includes info_key, "rjf_wl_"
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, "{rjf_wl_hall_hint}"
    $game_player.x, $game_player.y = 15, 30
    World.next_frame
    assert_includes info_key, "{rjf_wl_west_hint}"
    $game_player.x, $game_player.y = 52, 55
    World.next_frame
    assert_includes info_key, "{rjf_wl_room2_hint}"
    $game_player.x, $game_player.y = 45, 60
    World.next_frame
    assert_includes info_key, "{rjf_wl_pool_hint}"
    $game_variables[96] = 28
    refute_includes info_key, "rjf_wl_"
  end

  test "Xenpurgis counts the presses each trampoline needs from where it stands, and says the way once both jump" do
    xp = PokeAccess::RejuvXenpurgisTrampolines
    on_map(646, 70, 89)
    green = place(142, 77, 82, [TestCmd.new(101, ["text"])], "", 1)
    blue = place(144, 76, 78, [TestCmd.new(101, ["text"])], "", 1)
    switch = place(145, 63, 89, [TestCmd.new(101, ["text"])], "", 1)
    assert_equal 0, xp.presses(142)
    assert_equal 2, xp.presses(144)
    assert_equal "{rjf_xp_blue_pad corner={rjf_xp_corner_se}}", PokeAccess::Puzzles.piece_name(blue)
    assert_equal [:rjf_xp_blue_moved, { :corner => "{rjf_xp_corner_ne}" }], xp.moved(switch)
    refute_includes info_key, "rjf_xp_hint"
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, "{rjf_xp_hint_blue times={rjf_xp_times n=2}}. {rjrv2_xp_cross}"
    refute_includes info_key, "rjf_xp_hint_green"
    assert_includes PokeAccess::Puzzles.piece_name(green), "{rjf_xp_pad_jumps}"
    blue.x, blue.y = 75, 78
    green.x, green.y = 77, 83
    assert_equal 1, xp.presses(142)
    assert_includes info_key, "{rjf_xp_hint_green times={rjf_xp_once}}. {rjrv2_xp_cross}"
    green.y = 82
    assert_includes info_key, "{rjf_xp_hint_go}"
    refute_includes info_key, "rjrv2_xp_cross"
  end

  test "Xenpurgis names the jumps back where the trampolines land, and the middle island's spikes while they are up" do
    on_map(646, 70, 89)
    east = place(20, 71, 77, [TestCmd.new(209, [-1, nil])], "", 1)
    south = place(191, 77, 78, [TestCmd.new(209, [-1, nil])], "", 1)
    assert_equal "{rjf_xp_jump dir={face_east}}", PokeAccess::Puzzles.piece_name(east)
    assert_equal "{rjf_xp_jump dir={face_south}}", PokeAccess::Puzzles.piece_name(south)
    down = place(205, 70, 83, [], "", 0)
    assert_nil PokeAccess::Puzzles.piece_name(down)
    on_map(646, 70, 89)
    up = place(205, 70, 83, [TestCmd.new(355, ["pbFieldDamage"])], "object_trap", 2)
    assert_equal "{rjrv2_xp_spikes}", PokeAccess::Puzzles.piece_name(up)
  end

  test "Karen's corridor says where the shooter stands, warns as it lines up, and gives each round's rule with the assist" do
    on_map(418, 104, 40)
    $game_variables[265] = 7
    shooter = place(101, 101, 26, [TestCmd.new(101, ["text"])], "Pkmn_Gigalith")
    assert_includes info_key, "{rjf_hl_shooter_west cols={rjf_hl_cols n=3}}"
    shooter.x = 103
    assert_includes info_key, "{rjf_hl_shooter_west cols={rjf_hl_one_col}}"
    refute_includes info_key, "rjf_hl_round1_hint"
    lines = frame { shooter.x = 104 }
    assert_includes lines.join(" "), "{rjf_hl_in_line}"
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, "{rjf_hl_round1_hint}"
    $game_variables[265] = 9
    refute_includes info_key, "rjf_hl_shooter"
    assert_includes info_key, "{rjf_hl_round3_hint}"
    $game_variables[265] = 10
    refute_includes info_key, "rjf_hl_"
  end

  test "the Nightmare Realm's buttons say their colour, and its arrows the way the lit colour pushes" do
    on_map(33, 12, 50)
    button = place(29, 17, 71, [TestCmd.new(121, [1362, 1362, 0])], "", 1)
    arrow = place(22, 12, 46, [World.move_player([[44, []], 4])], "", 1)
    assert_equal "{rjf_nm_button color={rjf_nm_yellow}}", PokeAccess::Puzzles.piece_name(button)
    assert_equal "{rjf_nm_arrow dir={face_north}}", PokeAccess::Puzzles.piece_name(arrow)
    refute_includes info_key, "rjf_nm_lit"
    $game_switches[1363] = true
    assert_includes info_key, "{rjf_nm_lit color={rjf_nm_green}}"
  end

  test "the Xen Battleship's buttons say whether they are pressed, and the assist lists the one due" do
    on_map(318, 30, 45)
    $game_variables[731] = 50
    first = place(31, 31, 41, [TestCmd.new(122, [522, 522, 0, 0, 1])])
    second = place(48, 38, 56, [TestCmd.new(122, [522, 522, 0, 0, 2])])
    assert_equal "{rjf_xs_button}", PokeAccess::Puzzles.piece_name(first)
    refute(listed.any? { |_x, _y, name| name.include?("rjf_xs_next") })
    PokeAccess::Config.puzzle_assist = true
    assert_includes listed, [31, 41, "{rjf_xs_next}"], "Venam's step waits behind the first button"
    $game_variables[522] = 1
    World.next_frame
    assert_equal "{rjf_xs_button_on}", PokeAccess::Puzzles.piece_name(first)
    refute(listed.any? { |_x, _y, name| name.include?("rjf_xs_next") }, "the second and third are not needed")
    assert_equal "{rjf_xs_button}", PokeAccess::Puzzles.piece_name(second)
  end

  def listed
    World.next_frame
    PokeAccess::Puzzles.category_targets.select { |tg| tg.is_a?(PokeAccess::Locator::SurfaceTarget) }
                       .map { |tg| [tg.x, tg.y, tg.name] }
  end

  def keyed
    i18n = PokeAccess::I18n.singleton_class
    i18n.send(:alias_method, :rjf_kept_t, :t)
    i18n.send(:define_method, :t) do |key, vars = nil|
      parts = [key.to_s] + (vars || {}).map { |k, v| "#{k}=#{v}" }.sort
      "{#{parts.join(' ')}}"
    end
  end

  def unkeyed
    i18n = PokeAccess::I18n.singleton_class
    i18n.send(:alias_method, :t, :rjf_kept_t)
    i18n.send(:remove_method, :rjf_kept_t)
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

  def frame
    SpeakCapture.clear
    yield if block_given?
    World.next_frame
    PokeAccess::Puzzles.tick
    SpeakCapture.lines
  end

  def info_key
    World.next_frame
    PokeAccess::Info.map_text.to_s
  end
end
