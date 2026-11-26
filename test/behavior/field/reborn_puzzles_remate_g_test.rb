# Pokemon Reborn's puzzles of the remate G (games/reborn/puzzles/): the Emerald Room's way to V521 at 8 with the
# assist, told by the phase the room is in, the live boulder tiles and the ground the player stands on; and what is said
# as an arrow falls with the assist.
class RebornPuzzlesRemateGTest < PokeAccessTest
  SWITCHES = [1230, 1231, 1232, 1233, 1234, 1235, 1236, 1237, 1238, 1240, 1241, 1242, 1257, 1258, 1259, 2131]

  def setup
    super
    keyed
    Harness.load_puzzles("reborn")
    @at = [$game_player.x, $game_player.y]
    @map = $game_map.map_id
    @v521 = $game_variables[521]
  end

  def teardown
    World.clear_events
    SWITCHES.each { |s| $game_switches[s] = false }
    $game_variables[521] = @v521
    $game_player.x, $game_player.y = @at
    $game_map.map_id = @map
    PokeAccess::Config.puzzle_assist = false
    PokeAccess::RebornVrGemRooms.forget
    PokeAccess::World::Mechanics.forget
    PokeAccess::Caches.reset_all
    unkeyed
    super
  end

  test "Off the arrival the plan climbs the first wall, then the second from the ledge, and only with the assist" do
    on_map(805, 64, 60, 0)
    plan = PokeAccess::RebornVrEmeraldPlan
    assert_equal [:climb, 41, [60, 64], 4, 1, nil, nil], plan.target
    refute_includes info_key, "rbg_plan_step"
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key,
                    "{rbg_plan_step n=1 total=97 what={rbrg_climb dir={face_west}} where=4 {dir_left}, 4 {dir_down}}"
    assert_includes listed, [60, 64, "{rbrg_climb dir={face_west}}"]
    walk_to(58, 64)
    assert_equal [:climb, 40, [51, 62], 4, 2, nil, nil], plan.target
    walk_to(49, 62)
    assert_equal [:crystal, 104, [49, 64], 6, 3, [48, 64], nil], plan.target
  end

  test "Each boulder's push is read off its live tile, with the pushes left and the step they make" do
    on_map(805, 26, 53, 2)
    plan = PokeAccess::RebornVrEmeraldPlan
    boulder = place(42, 26, 51, "Boulder")
    assert_equal [:push, 42, [26, 52], 8, 4, nil, 20], plan.target
    boulder.x = 28
    boulder.y = 40
    assert_equal [:push, 42, [28, 41], 8, 17, [27, 41], 7], plan.target
    PokeAccess::Config.puzzle_assist = true
    walk_to(28, 42)
    assert_includes info_key,
                    "{rbg_plan_step n=17 total=97 what={rbrg_push dir={face_north} left=7} where=1 {dir_up}}"
    boulder.x = 60
    boulder.y = 60
    assert_equal :reset, plan.target[0]
    assert_includes info_key, "{rbg_plan_off what={rbrg_reset} where="
    walk_to(58, 64)
    assert_equal [:reset, 42, [64, 59], 8, nil, nil, nil], plan.target, "the way out, not back in, from the ledge"
    boulder.x = 28
    boulder.y = 40
    walk_to(64, 60)
    assert_equal [:climb, 41, [60, 64], 4, nil, nil, nil], plan.target, "a climb out of its phase has no number"
    assert_includes info_key, "{rbg_plan_off what={rbrg_climb dir={face_west}} where="
  end

  test "The second boulder waits for its lever, and the plates stay done whatever the boulders do after" do
    on_map(805, 42, 52, 2)
    plan = PokeAccess::RebornVrEmeraldPlan
    $game_switches[1230] = true
    boulder = place(43, 26, 64, "Boulder")
    assert_equal [:lever, 57, [42, 49], 8, 24, nil, nil], plan.target
    $game_switches[1238] = true
    assert_equal [:push, 43, [25, 64], 6, 25, nil, 60], plan.target
    boulder.x = 44
    boulder.y = 39
    assert_equal [:push, 43, [44, 40], 8, 70, nil, 15], plan.target
    $game_switches[1231] = true
    assert_equal [:lever, 48, [32, 34], 8, 85, nil, nil], plan.target
  end

  test "Each crystal goes after its levers, then the bounce under it; a lever is asked back to how the plan needs it" do
    on_map(805, 30, 40, 2)
    plan = PokeAccess::RebornVrEmeraldPlan
    [1230, 1231, 1233, 1238].each { |s| $game_switches[s] = true }
    assert_equal [:crystal, 85, [28, 26], 6, 86, nil, nil], plan.target
    $game_switches[1240] = true
    assert_equal [:bounce, 28, [28, 26], nil, 87, nil, nil], plan.target
    $game_switches[1257] = true
    $game_variables[521] = 4
    assert_equal [:lever, 57, [42, 49], 8, 88, nil, nil], plan.target, "the gate lever back off"
    $game_switches[1238] = false
    assert_equal [:lever, 54, [50, 32], 8, 89, nil, nil], plan.target
    [1236, 1242, 1259].each { |s| $game_switches[s] = true }
    $game_variables[521] = 6
    assert_equal [:lever, 53, [48, 32], 2, 92, nil, nil], plan.target
    [1235, 1237, 1234, 1232].each { |s| $game_switches[s] = true }
    assert_equal [:crystal, 86, [37, 27], 4, 96, nil, nil], plan.target
    $game_variables[521] = 8
    assert_nil plan.target
    PokeAccess::Config.puzzle_assist = true
    refute_includes info_key, "rbg_plan"
  end

  test "With the assist an arrow under a lit crystal is waited for, and by a push it names the refuge" do
    rooms = PokeAccess::RebornVrGemRooms
    on_map(805, 28, 26, 2)
    [1230, 1231, 1233, 1238, 1240].each { |s| $game_switches[s] = true }
    arrow = place(102, 0, 1, "Arrow")
    PokeAccess::Config.puzzle_assist = true
    arrow.x = 28
    arrow.y = 22
    assert_equal ["{rbc2_emerald_arrow}. {rbrg_stay}"], spoken { rooms.tick }
    $game_switches[1257] = true
    arrow.x = 0
    arrow.y = 1
    rooms.tick
    arrow.x = 28
    arrow.y = 22
    assert_equal ["{rbc2_emerald_arrow}. {rb3_dodge_column}"], spoken { rooms.tick }, "a crystal bounces one arrow back"
    $game_switches[1257] = false
    assert PokeAccess::RebornVrEmeraldPlan.shielded?(28, 46)
    refute PokeAccess::RebornVrEmeraldPlan.shielded?(28, 47), "from 22 rows down the arrow falls past the blister first"
    on_map(805, 44, 47, 2)
    [1230, 1238].each { |s| $game_switches[s] = true }
    place(43, 44, 46, "Boulder")
    arrow = place(102, 0, 1, "Arrow")
    rooms.tick
    PokeAccess::Config.puzzle_assist = true
    arrow.x = 44
    arrow.y = 25
    assert_equal ["{rbc2_emerald_arrow}. {rbrg_refuge where=1 {dir_left}}"], spoken { rooms.tick }
    walk_to(44, 50)
    assert_equal "{rb3_dodge_column}", PokeAccess::RebornVrEmeraldPlan.dodge_line, "away from the step, no refuge"
  end

  test "A refuge a row up the column is named when reached in time, and where none is the step says so" do
    plan = PokeAccess::RebornVrEmeraldPlan
    on_map(805, 28, 42, 2)
    PokeAccess::Config.puzzle_assist = true
    place(42, 28, 40, "Boulder")
    assert_equal [:push, 42, [28, 41], 8, 17, [27, 41], 7], plan.target
    assert_equal "{rbrg_refuge where=1 {dir_left}, 1 {dir_up}}", plan.dodge_line, "the step's refuge, a row up, in time"
    walk_to(28, 41)
    assert_equal "{rbrg_refuge where=1 {dir_left}}", plan.dodge_line
    refute_includes info_key, "rbrg_hurry"
    on_map(805, 44, 40, 2)
    PokeAccess::Config.puzzle_assist = true
    [1230, 1238].each { |s| $game_switches[s] = true }
    place(43, 44, 39, "Boulder")
    assert_includes info_key, "what={rbrg_push dir={face_north} left=15} where={loc_here}}. {rbrg_hurry}"
    assert_equal "{rb3_dodge_column}", plan.dodge_line, "six rows down to the niche, too late"
  end

  test "The gates say whether they stand open and the plates are listed until pressed, with no assist" do
    on_map(805, 30, 45, 2)
    gate = place(60, 32, 44, "EV060")
    plate_gate = place(44, 30, 39, "EV044")
    assert_equal "{rbrg_gate_open}", PokeAccess::Puzzles.piece_name(gate)
    assert_equal "{rbrg_gate_closed}", PokeAccess::Puzzles.piece_name(plate_gate)
    $game_switches[1237] = true
    $game_switches[1230] = true
    assert_equal "{rbrg_gate_closed}", PokeAccess::Puzzles.piece_name(gate)
    assert_equal "{rbrg_gate_open}", PokeAccess::Puzzles.piece_name(plate_gate)
    $game_switches[1230] = false
    World.next_frame
    assert_includes listed, [28, 33, "{rbc_vr_plate}"]
    $game_switches[1230] = true
    World.next_frame
    refute(listed.any? { |t| t[0] == 28 && t[1] == 33 })
  end

  test "The plan's data numbers its steps in order and each push table leads its boulder onto its plate" do
    plan = PokeAccess::RebornVrEmeraldPlan
    numbers = plan::STEPS.map { |s| s[5] }
    assert_equal numbers.sort, numbers
    assert_equal plan::TOTAL, plan::STEPS.last[5]
    plan::BOULDERS.each do |id, (_flag, first, total)|
      table = plan::PUSHES[id]
      plate = { 42 => [28, 33], 43 => [47, 27] }[id]
      assert_equal total, table[{ 42 => 2651, 43 => 2664 }[id]][3], "boulder #{id} starts on its table"
      table.each_key do |tile|
        seen = 0
        at = [tile / 100, tile % 100]
        until at == plate
          row = table[at[0] * 100 + at[1]]
          assert row, "boulder #{id} off its table at #{at.inspect}"
          assert_equal row[3], table[tile][3] - seen, "pushes left from #{at.inspect}"
          d = { 2 => [0, 1], 4 => [-1, 0], 6 => [1, 0], 8 => [0, -1] }[row[0]]
          assert_equal [at[0] - d[0], at[1] - d[1]], [row[1], row[2]], "stands behind the boulder"
          at = [at[0] + d[0], at[1] + d[1]]
          seen += 1
        end
        assert_equal table[tile][3], seen
      end
      assert_equal first + total, plan::STEPS.find { |s| s[5] > first }[5]
    end
  end

  test "Every refuge is down the column, beside it or a row up, and reached before the arrow" do
    plan = PokeAccess::RebornVrEmeraldPlan
    refuges = plan::STEPS.select { |s| s[1] != :boulder && s[6] }.map { |s| [s[3], s[6]] }
    plan::PUSHES.each_value { |tb| tb.each_value { |r| refuges << [[r[1], r[2]], [r[4], r[5]]] if r[4] } }
    assert_operator refuges.size, :>, 80
    refuges.each do |(x, y), (rx, ry)|
      from = "refuge #{[rx, ry].inspect} from #{[x, y].inspect}"
      assert_operator ry, :>=, y - 1, "#{from} more than a row up the column"
      assert((rx - x).abs == 1 || (rx == x && ry >= plan::SAFE_ROW), "#{from} beside the column or below row 66")
      assert plan.in_time?(y, ry - y), "#{from} reached before the arrow"
    end
    refute plan.in_time?(28, 0), "six rows under the arrow's start leave no time"
    assert plan.in_time?(60, 3)
    refute plan.in_time?(43, 3), "three rows down from 43 leave 22 frames, the arrow placed a row below its start"
    assert plan.in_time?(40, -1), "a row up from 40 leaves 24 frames"
  end

  private

  # Makes I18n.t answer each key and its values as "{key name=value ...}", so what the puzzles say is compared by its
  # keys and values rather than by the text of a language.
  def keyed
    i18n = PokeAccess::I18n.singleton_class
    i18n.send(:alias_method, :rbrg_kept_t, :t)
    i18n.send(:define_method, :t) do |key, vars = nil|
      parts = [key.to_s] + (vars || {}).map { |k, v| "#{k}=#{v}" }.sort
      "{#{parts.join(' ')}}"
    end
  end

  # Gives I18n.t back its own body.
  def unkeyed
    i18n = PokeAccess::I18n.singleton_class
    i18n.send(:alias_method, :t, :rbrg_kept_t)
    i18n.send(:remove_method, :rbrg_kept_t)
  end

  def on_map(map, x, y, v521)
    PokeAccess::Config.puzzle_assist = false
    World.clear_events
    SWITCHES.each { |s| $game_switches[s] = false }
    $game_variables[521] = v521
    $game_map.map_id = map
    $game_player.x = x
    $game_player.y = y
    PokeAccess::RebornVrGemRooms.forget
    PokeAccess::Caches.reset_all
    PokeAccess::World::Mechanics.forget
    World.next_frame
    info_key
  end

  def walk_to(x, y)
    $game_player.x = x
    $game_player.y = y
    World.next_frame
  end

  def place(id, x, y, name, sprite = "")
    page = TestPage.new(:trigger => 0, :sprite => sprite, :list => [TestCmd.new(101, ["text"]), TestCmd.new(0, [])])
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
