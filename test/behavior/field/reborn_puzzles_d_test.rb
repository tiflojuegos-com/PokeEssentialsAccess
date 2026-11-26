# Pokemon Reborn's optional puzzles of part D (games/reborn/puzzles/): Byxbysion's reactors, the Wasteland Wall's boulder
# hole, the Lost Railcave's doors, the Underroot's cages, Rhodochrine's hidden pits, the Mirage Tower's glass walls and
# Zeraora's pillars.
# Without the assist, what the screen shows; with it, the way.
class RebornPuzzlesDTest < PokeAccessTest
  SWITCHES = [97, 185, 186, 187, 188, 189, 190, 192, 1784, 1788, 1789]
  VARS = [78, 146, 147, 148, 378, 616]

  def setup
    super
    keyed
    Harness.load_puzzles("reborn")
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

  test "Byxbysion's reactors say whether they are lit, and the count and the grotto's door come with the assist" do
    on_map(209, 50, 10)
    reactor = place(149, 50, 9, "EV149")
    place(183, 75, 49, "EV183", 1)
    assert_equal "{rbd_bx_reactor_dark}", PokeAccess::Puzzles.piece_name(reactor)
    assert_includes frame { $game_switches[185] = true }, "{rbd_bx_reactor}: {rbd_bx_lit}"
    assert_equal "{rbd_bx_reactor_lit}", PokeAccess::Puzzles.piece_name(reactor)
    refute_includes info_key, "rbd_bx_"
    refute(listed.any? { |r| r[2] == "{rbd_bx_door}" })
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, "{rbd_bx_hint}"
    assert_includes info_key, "label={rbd_bx_count}"
    assert_includes info_key, "n=1"
    assert_includes listed, [75, 49, "{rbd_bx_door}"]
    [186, 187, 188, 189, 190].each { |s| $game_switches[s] = true }
    refute_includes info_key, "rbd_bx_"
  end

  test "the Wasteland Wall says the boulder's drop and the player's fall, and the pushes come with the assist" do
    on_map(212, 31, 12)
    hole = place(7, 44, 12, "EV007", 1)
    assert_equal "{rbd_ww_hole}", PokeAccess::Puzzles.piece_name(hole)
    refute_includes info_key, "rbd_ww_hint"
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, "{rbd_ww_hint_push}"
    assert_includes frame { $game_switches[192] = true }, "{rbd_ww_dropped}"
    lower = place(3, 44, 32, "Boulder", 1, "rockstrength2")
    assert_includes info_key, "{rbd_ww_hint_below}"
    fire(hole)
    assert_equal "{rbd_ww_fell}", PokeAccess::Puzzles.sent_back_line([44, 12, 212], [45, 32, 212])
    assert_nil PokeAccess::Puzzles.sent_back_line([30, 12, 212], [31, 12, 212])
    lower.x = 39
    assert_includes info_key, "{rbd_ww_hint_below}", "a boulder under the way out still blocks it"
    lower.x = 38
    refute_includes info_key, "rbd_ww_hint"
  end

  test "the Lost Railcave's assisted doors walk both ways out in ten, by the doors' own counting" do
    rc = PokeAccess::RebornRailcave
    sides = { "{rbd_rc_north}" => 1, "{rbd_rc_east}" => 2, "{rbd_rc_south}" => 3, "{rbd_rc_west}" => 4 }
    [[1, :west_room], [4, :east_room]].each do |first, goal|
      $game_variables[146] = 0
      door = first
      out = nil
      taken = 0
      while out.nil? && taken < 12
        taken += 1
        out = enter_railcave(door)
        door = sides.fetch(rc.hint[1][:side]) unless out
      end
      assert_equal goal, out
      assert_equal rc::STEPS, taken
    end
    $game_variables[146] = 3
    assert_equal :forest, enter_railcave(3), "a wrong south door starts over and leads out"
    assert_equal 0, $game_variables[146]
  end

  test "the Lost Railcave names its doors, says where the rails point, and the next door comes with the assist" do
    on_map(251, 14, 11)
    north = place(3, 14, 6, "EV003", 1)
    assert_equal "{rbd_rc_door side={rbd_rc_north}}", PokeAccess::Puzzles.piece_name(north)
    assert_includes frame { $game_variables[147] = 2 }, "{rbd_rc_rails side={rbd_rc_east}}"
    assert_includes info_key, "{rbd_rc_rails side={rbd_rc_east}}"
    assert_includes frame { $game_variables[148] = 4 }, "{rbd_rc_rocks side={rbd_rc_west}}"
    assert_includes info_key, "{rbd_rc_rocks side={rbd_rc_west}}"
    $game_variables[148] = 0
    assert_equal [], frame { $game_variables[146] = 1 }
    refute_includes info_key, "rbd_rc_hint"
    PokeAccess::Config.puzzle_assist = true
    assert_includes frame { $game_variables[146] = 2 }, "{rbd_rc_hint_next n=3 of=10 side={rbd_rc_east}}"
    $game_variables[146] = 0
    assert_includes info_key, "{rbd_rc_hint_start}"
    $game_variables[146] = -8
    assert_includes info_key, "{rbd_rc_hint_next n=9 of=10 side={rbd_rc_south}}"
  end

  test "the Underroot's levers and bars are named, the officer's lever with the assist, and a jungle fall is said" do
    on_map(153, 16, 24)
    $game_variables[78] = 1
    lever = place(2, 16, 23, "EV002", 0, "")
    bars = place(3, 18, 22, "EV003", 0, "")
    assert_equal "{rbd_ur_lever}", PokeAccess::Puzzles.piece_name(lever)
    assert_equal "{rbd_ur_bars}", PokeAccess::Puzzles.piece_name(bars)
    refute_includes info_key, "rbd_ur_hint"
    PokeAccess::Config.puzzle_assist = true
    assert_equal "{rbd_ur_lever_officer}", PokeAccess::Puzzles.piece_name(lever)
    assert_includes info_key, "{rbd_ur_hint}"
    $game_switches[97] = true
    assert_equal "{rbd_ur_lever}", PokeAccess::Puzzles.piece_name(lever)
    $game_self_switches[[153, 4, "A"]] = true
    refute_includes info_key, "rbd_ur_hint"
    assert_equal "{rbd_rj_fell}", PokeAccess::Puzzles.sent_back_line([138, 85, 150], [80, 72, 153], :map)
    assert_equal "{rbd_rj_fell}", PokeAccess::Puzzles.sent_back_line([75, 13, 150], [52, 5, 153], :map)
    assert_equal "{rbd_rj_fell}", PokeAccess::Puzzles.sent_back_line([41, 95, 150], [16, 73, 153], :map)
    assert_nil PokeAccess::Puzzles.sent_back_line([90, 22, 150], [60, 16, 153], :map)
  end

  test "Rhodochrine's pits stay unseen until they open, but the assist names them and the walks keep off them" do
    on_map(150, 137, 82)
    pit = place(61, 137, 84, "pit-bottom", 1)
    assert_equal true, PokeAccess::Locator.hidden?(pit)
    PokeAccess::Config.puzzle_assist = true
    assert_equal false, PokeAccess::Locator.hidden?(pit)
    assert_equal "{rbd_rj_hidden_pit}", PokeAccess::Puzzles.piece_name(pit)
    PokeAccess::Config.puzzle_assist = false
    $game_switches[1784] = true
    assert_equal false, PokeAccess::Locator.hidden?(pit)
    assert_equal "{rbd_rj_hole}", PokeAccess::Puzzles.piece_name(pit)
    refute PokeAccess::RebornJunglePits.open?(place(101, 75, 13, "pit-bottom", 1))
  end

  test "the Mirage Tower's glass walls are named as they stand, and the count to the hole comes with the assist" do
    on_map(668, 19, 15)
    glass = place(2, 19, 14, "Glass")
    assert_equal "{rbd_mt_mirror}", PokeAccess::Puzzles.piece_name(glass)
    $game_self_switches[[668, 2, "A"]] = true
    assert_equal "{rbd_mt_cracked}", PokeAccess::Puzzles.piece_name(glass)
    refute PokeAccess::RebornMirageGlass.listed?(glass)
    refute_includes info_key, "rbd_mt_"
    PokeAccess::Config.puzzle_assist = true
    $game_variables[378] = 17
    assert_includes info_key, "{rbd_mt_hint}"
    assert_includes info_key, "label={rbd_mt_count}"
    assert_includes info_key, "n=17"
    $game_self_switches[[668, 2, "B"]] = true
    assert_equal "{rbd_mt_hole}", PokeAccess::Puzzles.piece_name(glass)
    refute_includes info_key, "rbd_mt_"
  end

  test "Zeraora's pillars are named, and the next one and the way on after the first come with the assist" do
    on_map(847, 22, 15)
    $game_variables[616] = 5
    first = place(6, 22, 14, "EV006", 0, "electricrockpillar")
    second = place(7, 66, 21, "EV007", 0, "electricrockpillar")
    assert_equal "{rbd_ze_pillar}", PokeAccess::Puzzles.piece_name(first)
    refute_includes info_key, "rbd_ze_"
    PokeAccess::Config.puzzle_assist = true
    assert_equal "{rbd_ze_pillar_next}", PokeAccess::Puzzles.piece_name(first)
    assert_equal "{rbd_ze_pillar}", PokeAccess::Puzzles.piece_name(second)
    assert_includes info_key, "{rbd_ze_hint}"
    $game_variables[616] = 6
    assert_includes listed, [75, 26, "{rbd_ze_onward}"]
    $game_variables[616] = 8
    refute(listed.any? { |r| r[2] == "{rbd_ze_onward}" })
    assert_equal "{rbd_ze_pillar_next}", PokeAccess::Puzzles.piece_name(second)
    $game_variables[616] = 13
    refute_includes info_key, "rbd_ze_"
  end

  private

  # Makes I18n.t answer each key and its values as "{key name=value ...}", so what the puzzles say is compared by its
  # keys and values rather than by the text of a language.
  def keyed
    i18n = PokeAccess::I18n.singleton_class
    i18n.send(:alias_method, :rbd_kept_t, :t)
    i18n.send(:define_method, :t) do |key, vars = nil|
      parts = [key.to_s] + (vars || {}).map { |k, v| "#{k}=#{v}" }.sort
      "{#{parts.join(' ')}}"
    end
  end

  # Gives I18n.t back its own body.
  def unkeyed
    i18n = PokeAccess::I18n.singleton_class
    i18n.send(:alias_method, :t, :rbd_kept_t)
    i18n.send(:remove_method, :rbd_kept_t)
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

  # The doors the room's parallel process (event 5) sets for each count: variables 147 and 148.
  RAILCAVE = { 0 => [1, 4], 1 => [2, 0], 2 => [2, 0], 3 => [1, 0], 4 => [4, 0], 5 => [1, 0], 6 => [2, 0], 7 => [3, 0],
               8 => [2, 0], 9 => [1, 0], -1 => [0, 4], -2 => [0, 1], -3 => [0, 4], -4 => [0, 1], -5 => [0, 2],
               -6 => [0, 1], -7 => [0, 4], -8 => [0, 3], -9 => [0, 4] }

  # Walks through a Lost Railcave door as its event does (1 north, 2 east, 3 south, 4 west): the room left for, or nil
  # while still in the room.
  def enter_railcave(door)
    v = $game_variables[146]
    up, down = RAILCAVE.fetch(v)
    return :west_room if door == 1 && up == 1 && v == 9
    return :east_room if door == 4 && up != 4 && down == 4 && v == -9
    v = up == door ? v + 1 : (down == door ? v - 1 : 0)
    v = 0 if door == 3 && v != 8 && v != -9
    $game_variables[146] = v
    door == 3 && v == 0 ? :forest : nil
  end

  def fire(ev)
    PokeAccess::Puzzles::Auto.fired($game_system.map_interpreter, PokeAccess.ivar(ev, :@list), ev.id)
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
