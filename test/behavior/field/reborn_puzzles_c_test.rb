# Pokemon Reborn's puzzles of part C (games/reborn/puzzles/): Agate's tuners, Victory Road's plates, falling traps, Ruby
# Room and crystal lock, Yureyu's monitors and the doors of Castle at Wit's End. Without the assist, what the screen
# shows; with it, the way.
class RebornPuzzlesCTest < PokeAccessTest
  SWITCHES = [1022, 1101, 1108, 1118, 1119, 1120, 1121, 1124, 1155, 1156, 1244, 2226]
  VARS = [104, 362, 441, 442, 443, 444, 445, 446, 447, 448, 475, 506, 507, 508, 509, 510, 511, 512, 513, 514, 515]

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
    PokeAccess::RebornVrTraps.forget
    PokeAccess::World::Mechanics.forget
    PokeAccess::Caches.reset_all
    unkeyed
    super
  end

  test "Agate's tuners say the note of their place, and the assist sets them to the guitarist's riff" do
    on_map(739, 13, 45)
    tuners = (23..30).map { |id| place(id, 14, 45 - (id - 23) * 4, "Tuner #{id - 22}") }
    assert_equal "{rbc_agate_tuner n=1 note={rbc_note_low_g}}", PokeAccess::Puzzles.piece_name(tuners[0])
    tuners[0].x = 17
    assert_equal "{rbc_agate_tuner n=1 note={rbc_note_c}}", PokeAccess::Puzzles.piece_name(tuners[0])
    tuners[0].x = 14
    refute_includes info_key, "rbc_agate_push"
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, "{rbc_agate_push_right count=3 n=1 note={rbc_note_c}}"
    riff = [3, 5, 7, 2, 2, 0, 1, 1]
    tuners.each_with_index do |ev, k|
      ev.x = 14 + riff[k]
      $game_variables[441 + k] = riff[k]
    end
    assert_includes info_key, "{rbc_agate_climb}"
    $game_variables[446] = 4
    assert_includes info_key, "{rbc_agate_resync n=6 note={rbc_note_low_g}}"
    tuners[1].x = 21
    assert_includes info_key, "{rbc_agate_push_left count=2 n=2 note={rbc_note_e}}"
    $game_switches[1022] = true
    refute_includes info_key, "rbc_agate_"
  end

  test "Victory Road's plates are listed while they wait, and the assist tracks the nearest due boulder" do
    plates = PokeAccess::RebornVrPlates
    on_map(784, 41, 40)
    place(68, 40, 37, "Boulder")
    place(71, 56, 56, "Boulder")
    assert_includes listed, [44, 37, "{rbc_vr_plate}"]
    assert_nil plates.current
    PokeAccess::Config.puzzle_assist = true
    assert_equal 68, plates.current[0]
    assert_includes info_key, "{rbc_vr_plates_hint}"
    $game_player.y = 53
    assert_equal 68, plates.current[0]
    $game_switches[1101] = true
    World.next_frame
    assert_equal 71, plates.current[0]
    refute_includes listed, [44, 37, "{rbc_vr_plate}"]
    on_map(787, 48, 60)
    place(65, 48, 51, "Boulder")
    refute plates.due?(plates::ATRIUM2[0])
  end

  test "Fern's arrow target is said as it lands at the player's feet, and not with blindstep or while it waits" do
    traps = PokeAccess::RebornVrTraps
    on_map(787, 40, 50)
    $game_variables[475] = 123
    target = place(76, 1, 0, "Arrow Target-bottom")
    assert_empty spoken { traps.tick }
    target.x = 40
    target.y = 50
    assert_equal ["{rbc_vr_arrow_mark}"], spoken { traps.tick }
    assert_empty spoken { traps.tick }
    target.x = 1
    target.y = 0
    traps.tick
    $game_switches[2226] = true
    target.x = 40
    target.y = 50
    assert_empty spoken { traps.tick }
    $game_switches[2226] = false
    target.x = 1
    target.y = 0
    traps.tick
    PokeAccess::Config.puzzle_assist = true
    target.x = 40
    target.y = 50
    assert_equal ["{rbc_vr_arrow_mark}. {rb3_dodge_tile}"], spoken { traps.tick }, "the dodge, with the assist alone"
  end

  test "The ice's shadow is said as it lands a tile below the player, and the assist tells to step two tiles away" do
    traps = PokeAccess::RebornVrTraps
    on_map(784, 30, 40)
    $game_variables[475] = 110
    shadow = place(112, 1, 0, "Ice Target-bottom")
    assert_empty spoken { traps.tick }
    shadow.x = 30
    shadow.y = 41
    assert_equal ["{rbc_vr_ice_mark}"], spoken { traps.tick }
    shadow.x = 1
    shadow.y = 0
    traps.tick
    PokeAccess::Config.puzzle_assist = true
    shadow.x = 30
    shadow.y = 41
    assert_equal ["{rbc_vr_ice_mark}. {rb3_dodge_ice}"], spoken { traps.tick }
    $game_variables[475] = 114
    shadow.x = 1
    traps.tick
    shadow.x = 30
    assert_empty spoken { traps.tick }, "from 114 the controller drops nothing"
  end

  test "The crystal lock names each slot by its star, and the assist gives the code drawn for the file" do
    lock = PokeAccess::RebornVrLock
    on_map(796, 24, 23)
    slot = place(31, 24, 22, "Slot 3")
    assert_equal "{rbc_lock_slot n=3 star={rbc_star_none}}", PokeAccess::Puzzles.piece_name(slot)
    $game_variables[515] = 4
    assert_equal "{rbc_lock_slot n=3 star={rbc_star_amethyst}}", PokeAccess::Puzzles.piece_name(slot)
    assert_nil lock.code
    [1, 2, 3, 4, 1, 2, 3].each_with_index { |v, k| $game_variables[506 + k] = v }
    refute_includes info_key, "rbc_lock_code"
    PokeAccess::Config.puzzle_assist = true
    code = "{rbc_star_ruby}, {rbc_star_sapphire}, {rbc_star_emerald}, {rbc_star_amethyst}, {rbc_star_ruby}, " \
           "{rbc_star_sapphire}, {rbc_star_emerald}"
    assert_includes info_key, "{rbc_lock_code code=#{code}}"
    $game_switches[1244] = true
    refute_includes info_key, "rbc_lock_code"
  end

  test "Yureyu's monitors say whether they are on, counted in the info key, until the story variable reaches 32" do
    on_map(198, 13, 5)
    monitor = place(7, 13, 4, "EV007")
    assert_equal "{rbc_yureyu_monitor}", PokeAccess::Puzzles.piece_name(monitor)
    $game_self_switches[[198, 7, "A"]] = true
    assert_equal "{rbc_yureyu_monitor_on}", PokeAccess::Puzzles.piece_name(monitor)
    $game_variables[104] = 29
    assert_includes info_key, "rbc_yureyu_monitors"
    refute_includes info_key, "rbc_yureyu_hint"
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, "{rbc_yureyu_hint}"
    $game_variables[104] = 32
    refute_includes info_key, "rbc_yureyu_"
  end

  test "Castle at Wit's End names the shut doors by Taka's variable, and the assist the doors on the way" do
    on_map(698, 9, 13)
    left = place(24, 4, 11, "EV024")
    right = place(30, 14, 11, "EV030")
    assert_equal "{rbc_castle_door_locked}", PokeAccess::Puzzles.piece_name(right)
    refute_equal "{rbc_castle_door_way}", PokeAccess::Puzzles.piece_name(left)
    PokeAccess::Config.puzzle_assist = true
    assert_equal "{rbc_castle_door_way}", PokeAccess::Puzzles.piece_name(left)
    assert_includes info_key, "{rbc_castle_hint_left}"
    $game_variables[362] = 2
    assert_equal "{rbc_castle_door_locked}", PokeAccess::Puzzles.piece_name(left)
    assert_equal "{rbc_castle_door_way}", PokeAccess::Puzzles.piece_name(right)
    assert_includes info_key, "{rbc_castle_hint_right}"
  end

  test "Castle at Wit's End leads on to the knight's hall, its far doors off the way, where the ambush's hint answers" do
    on_map(698, 38, 84)
    PokeAccess::Config.puzzle_assist = true
    far_left = place(58, 29, 84, "EV058", 1)
    far_right = place(60, 41, 85, "EV060", 1)
    refute_equal "{rbc_castle_door_way}", PokeAccess::Puzzles.piece_name(far_left), "the knight's column keeps it off"
    assert_includes info_key, "{rbk_castle_ambush_hint}"
    refute_includes info_key, "rbc_castle_hint_left", "two hints there, one of them to the hole out of reach"
    $game_variables[362] = 2
    refute_equal "{rbc_castle_door_way}", PokeAccess::Puzzles.piece_name(far_right)
    refute_includes info_key, "rbc_castle_hint_right"
    top = place(28, 13, 10, "EV028")
    assert_equal "{rbc_castle_door_locked}", PokeAccess::Puzzles.piece_name(top), "from 1 its second page says Locked"
    $game_player.x, $game_player.y = 9, 13
    assert_includes info_key, "{rbc_castle_hint_right}"
    refute_includes info_key, "rbk_castle_ambush_hint"
  end

  private

  # Makes I18n.t answer each key and its values as "{key name=value ...}", so what the puzzles say is compared by its
  # keys and values rather than by the text of a language.
  def keyed
    i18n = PokeAccess::I18n.singleton_class
    i18n.send(:alias_method, :rbc_kept_t, :t)
    i18n.send(:define_method, :t) do |key, vars = nil|
      parts = [key.to_s] + (vars || {}).map { |k, v| "#{k}=#{v}" }.sort
      "{#{parts.join(' ')}}"
    end
  end

  # Gives I18n.t back its own body.
  def unkeyed
    i18n = PokeAccess::I18n.singleton_class
    i18n.send(:alias_method, :t, :rbc_kept_t)
    i18n.send(:remove_method, :rbc_kept_t)
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
    PokeAccess::RebornVrPlates.forget
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

  def spoken
    SpeakCapture.clear
    yield
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
