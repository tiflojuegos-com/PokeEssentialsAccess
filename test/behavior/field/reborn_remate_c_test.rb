# Pokemon Reborn's puzzles of the remate C (games/reborn/puzzles/): the psychic glass blocks of the Glass Workstation
# (maps 736 and 738), planned from the blocks' variables and where the player stands, and the Mirage Tower's twin pens,
# the live plan's hint on every floor and the postgame tower's pens (map 880), two of them as pushes kept as data.
class RebornRemateCTest < PokeAccessTest
  SWITCHES = [947, 953, 1429, 1760, 1761]
  VARS = [377, 422, 423, 424, 425, 426, 427, 428, 429, 430, 431, 646]

  def setup
    super
    keyed
    Harness.load_puzzles("reborn")
    @at = [$game_player.x, $game_player.y]
    @dir = $game_player.direction
    @map = $game_map.map_id
    @selfs = $game_self_switches
  end

  def teardown
    World.clear_events
    SWITCHES.each { |s| $game_switches[s] = false }
    VARS.each { |v| $game_variables[v] = 0 }
    $game_self_switches = @selfs
    $game_player.x, $game_player.y = @at
    $game_player.direction = @dir
    $game_map.map_id = @map
    PokeAccess::Config.puzzle_assist = false
    PokeAccess::World::Mechanics.forget
    PokeAccess::Caches.reset_all
    unkeyed
    super
  end

  test "TM29's room plans the five glass blocks left in order, each from its own side, only with the assist" do
    on_map(738, 13, 13)
    place(14, 15, 15, "GBS1Core", "text", "glass3")
    PokeAccess::Config.puzzle_assist = false
    refute(listed.any? { |t| t[0] == 14 && t[1] == 13 })
    refute_includes info_key, "rbrc_glass_step"
    assert_includes info_key, "{rbrc_glass_block n=1}: {rbrc_glass_home}"
    PokeAccess::Config.puzzle_assist = true
    assert_includes listed, [14, 13, "{rbrc_glass_spot dir={dir_left} n=1}"]
    assert_includes info_key, "{rbrc_glass_step dir={dir_left} face={dir_down} left=5 n=1 where=1 {dir_right}}"
    $game_variables[422] = 1
    World.next_frame
    assert_includes listed, [15, 14, "{rbrc_glass_spot dir={dir_left} n=2}"]
    assert_includes info_key, "{rbrc_glass_block n=1}: {rbrc_glass_left}"
    $game_player.x, $game_player.y = 15, 14
    assert_includes info_key, "{rbrc_glass_step_here dir={dir_left} face={dir_up} left=4 n=2}"
    $game_switches[1429] = true
    World.next_frame
    refute_includes info_key, "rbrc_glass_step"
  end

  test "The Master Ball's room picks the move by where the player stands, and tells when no way is left" do
    on_map(736, 12, 35)
    PokeAccess::Config.puzzle_assist = true
    [427, 429, 431].each { |v| $game_variables[v] = 1 }
    World.next_frame
    assert_includes listed, [12, 35, "{rbrc_glass_spot dir={dir_left} n=2}"]
    $game_player.x, $game_player.y = 13, 39
    assert_includes listed, [12, 39, "{rbrc_glass_spot dir={dir_up} n=4}"]
    assert_includes info_key, "left=1 n=4"
    $game_variables[427] = 0
    $game_variables[431] = 0
    $game_variables[428] = 2
    World.next_frame
    assert_includes info_key, "{rbrc_glass_stuck}"
    refute(listed.any? { |t| t[2].to_s.include?("rbrc_glass_spot") })
    $game_player.x, $game_player.y = 12, 53
    refute_includes info_key.to_s, "rbrc_glass"
  end

  test "Using a glass block says Espeon waits, and with the assist the planned key from the right side" do
    on_map(738, 14, 13)
    ev = place(16, 14, 14, "GBS1B", "text", "glass3")
    ge = PokeAccess::RebornGlassEspeon
    assert_nil ge.use_line(ev)
    $game_switches[947] = true
    assert_equal "{rbrc_glass_wait}", ge.use_line(ev)
    PokeAccess::Config.puzzle_assist = true
    $game_player.direction = 2
    assert_equal "{rbrc_glass_wait_key dir={dir_left}}", ge.use_line(ev)
    $game_player.direction = 6
    assert_equal "{rbrc_glass_wait}", ge.use_line(ev)
    other = place(20, 13, 13, "GBS2B", "text", "glass3")
    $game_player.direction = 2
    assert_equal "{rbrc_glass_wait}", ge.use_line(other)
  end

  test "Every Mirage Tower floor gives the live plan's hint, not a fixed one" do
    on_map(671, 8, 22)
    place(10, 7, 21, "Controller", "text", "")
    place(32, 20, 21, "Receiver", "text", "")
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, "{rbf_mirage_hint}"
    assert_includes listed, [12, 26, "{rbf_mirage_light}"]
  end

  test "The postgame tower's third pen steps through its kept pushes, and off them says how to start over" do
    on_map(880, 16, 88)
    place(149, 14, 87, "Controller3", "text", "mirageblock")
    twin = place(150, 27, 87, "Receiver3", "text", "mirageblock")
    refute_includes info_key, "rbrc_mirage"
    PokeAccess::Config.puzzle_assist = true
    assert_includes listed, [15, 87, "{rbrc_mirage_push dir={dir_left} what={rbf_mirage_control}}"]
    assert_includes info_key, "{rbrc_mirage_step n=1 total=17 what={rbrc_mirage_push dir={dir_left} what={rbf_mirage_control}} where=1 {dir_left}, 1 {dir_up}}"
    twin.x = 26
    World.next_frame
    assert_includes listed, [14, 86, "{rbrc_mirage_push dir={dir_down} what={rbf_mirage_control}}"]
    twin.x = 20
    World.next_frame
    assert_includes info_key, "{rbrc_mirage_off}"
    $game_variables[646] = 3
    World.next_frame
    refute_includes info_key.to_s, "rbrc_mirage"
  end

  test "The bonus pen's plan moves its circles the other way at each push and ends with a block on each" do
    pl = PokeAccess::RebornMirageTwins::PLANNED.find { |p| p[0] == :twin_blocks_bonus1 }
    dirs = { 2 => [0, 1], 4 => [-1, 0], 6 => [1, 0], 8 => [0, -1] }
    cur = pl[6]
    pl[7].each_with_index do |(block, d, from, after), i|
      dx, dy = dirs[d]
      pushed = cur[block == pl[1] ? 0 : 1]
      assert_equal [pushed[0] - dx, pushed[1] - dy], from, "push #{i + 1} is made from behind the block"
      2.times { |j| assert_includes [cur[j], [cur[j][0] + dx, cur[j][1] + dy]], after[j], "push #{i + 1}, block #{j}" }
      2.times { |j| assert_equal [cur[j + 2][0] - dx, cur[j + 2][1] - dy], after[j + 2], "push #{i + 1}, circle #{j}" }
      cur = after
    end
    assert_equal [cur[2], cur[3]], [cur[0], cur[1]], "each block ends on a circle, as switch 1760 asks"
  end

  test "The bonus pen's lights follow the circles, the pushes go inside its room alone, and off the plan it says so" do
    on_map(880, 62, 148)
    place(157, 62, 150, "Controller4", "text", "mirageblock")
    place(158, 71, 151, "Receiver4", "text", "mirageblock")
    circle = place(155, 62, 154, "CircleL")
    place(156, 71, 153, "CircleR")
    PokeAccess::Config.puzzle_assist = true
    assert_includes listed, [62, 149, "{rbrc_mirage_push dir={dir_down} what={rbf_mirage_control}}"]
    assert_includes listed, [62, 154, "{rbf_mirage_light}"]
    assert_includes info_key, "total=6"
    circle.y = 153
    World.next_frame
    assert_includes listed, [62, 153, "{rbf_mirage_light}"]
    assert_includes info_key, "{rbrc_mirage_off}", "a circle off the plan's tile is off the plan"
    $game_player.x, $game_player.y = 30, 120
    World.next_frame
    refute_includes info_key.to_s, "rbrc_mirage"
    $game_player.x, $game_player.y = 62, 148
    $game_switches[1760] = true
    World.next_frame
    refute(listed.any? { |t| t[2].to_s.include?("rbrc_mirage_push") })
  end

  test "The bonus pen's rule on arrival says the circles move the other way" do
    on_map(880, 62, 148)
    SpeakCapture.clear
    World.next_frame
    PokeAccess::Puzzles.tick
    assert_includes SpeakCapture.lines.join(" "), "{rb3_mirage_circles_rule}"
  end

  test "The bonus pen's last state says the way back when the switch is still off, never nothing" do
    pl = PokeAccess::RebornMirageTwins::PLANNED.find { |p| p[0] == :twin_blocks_bonus1 }
    on_map(880, 62, 148)
    last = pl[7][-1][3]
    [157, 158, 155, 156].each_with_index { |id, i| place(id, last[i][0], last[i][1], "EV#{id}", "text", "mirageblock") }
    PokeAccess::Config.puzzle_assist = true
    assert_equal "{rbrc_mirage_off}", PokeAccess::RebornMirageTwins.push_line(pl)
  end

  private

  def keyed
    i18n = PokeAccess::I18n.singleton_class
    i18n.send(:alias_method, :rbrc_kept_t, :t)
    i18n.send(:define_method, :t) do |key, vars = nil|
      parts = [key.to_s] + (vars || {}).map { |k, v| "#{k}=#{v}" }.sort
      "{#{parts.join(' ')}}"
    end
  end

  # Gives I18n.t back its own body.
  def unkeyed
    i18n = PokeAccess::I18n.singleton_class
    i18n.send(:alias_method, :t, :rbrc_kept_t)
    i18n.send(:remove_method, :rbrc_kept_t)
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

  def place(id, x, y, name, text = "text", sprite = "")
    page = TestPage.new(:trigger => 0, :sprite => sprite, :list => [TestCmd.new(101, [text]), TestCmd.new(0, [])])
    ev = TestGameEvent.new(:id => id, :x => x, :y => y, :name => name, :pages => [page], :active_page => page)
    $game_map.events[id] = ev
    World.next_frame
    ev
  end

  def info_key
    PokeAccess::Info.map_text.to_s
  end

  def listed
    PokeAccess::Puzzles.category_targets.select { |tg| tg.is_a?(PokeAccess::Locator::SurfaceTarget) }
                       .map { |tg| [tg.x, tg.y, tg.name] }
  end
end
