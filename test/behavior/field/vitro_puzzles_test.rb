# GS Vitro's gym puzzles on the shipped profile: the wheel of Cianwood, the webs and levers of Azalea, the blocks of Olivine, the ice
# and pads of Mahogany and the boulder of Blackthorn. What a sighted player sees goes without the assist; the steps, with it.
class VitroPuzzlesTest < PokeAccessTest
  STEPS = [[9, 35, false, false, [:left, :up]], [9, 20, false, false, [:center, :up]], [9, 20, true, false, [:center, :up]],
           [9, 20, false, true, :blue], [9, 20, true, true, :blue], [3, 8, false, false, :blue],
           [3, 8, false, true, [:left, :down]], [3, 19, false, true, :red], [3, 19, true, true, [:left, :up]],
           [15, 8, false, true, [:right, :down]], [15, 8, true, true, [:right, :down]], [3, 23, true, false, [:left, :down]],
           [15, 23, false, true, [:right, :down]]]
  ZONES = [[9, 45, :start], [11, 25, :chamber], [4, 27, :chamber], [11, 30, :chamber], [4, 35, :lower], [3, 39, :lower],
           [18, 36, :lower], [19, 39, :lower], [11, 17, :lower]]

  test "Cianwood lists the wheel and the waterfall, and says the gate as the wheel flips it" do
    on_map(47)
    place(2, 9, 6, [TestCmd.new(101, ["wheel"])], "Gym_Gear")
    place(4, 13, 17, [TestCmd.new(122, [])], "Gym_cascada")
    assert_equal [t(:vitro_cianwood_wheel), t(:vitro_cianwood_waterfall)].sort, listed
    tick
    $game_switches[95] = true
    assert_equal [[gate(:vitro_cianwood_closed), false]], tick
    $game_switches[95] = false
    assert_equal [[gate(:vitro_cianwood_open), false]], tick
  end

  test "Cianwood gives the gate and the rule on the info key, the answer with the assist alone, and nothing after the badge" do
    on_map(47)
    tick
    refute PokeAccess::Puzzles::Auto.on_here?, "the gate line is the only news of the wheel"
    assert_includes info_key, gate(:vitro_cianwood_open)
    assert_includes info_key, t(:vitro_cianwood_rule)
    refute_includes info_key, t(:vitro_cianwood_hint)
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, t(:vitro_cianwood_hint)
    $game_switches[8] = true
    refute PokeAccess::Puzzles.active?
  end

  test "Azalea names each web by its column and way and each lever by its colour" do
    on_map(57)
    [[2, 4, 30], [10, 9, 17], [18, 14, 11]].each { |id, x, y| place(id, x, y, [TestCmd.new(122, [])], "gym_spider") }
    [[7, 11, 19], [13, 2, 18]].each { |id, x, y| place(id, x, y, [TestCmd.new(101, ["lever"])], "Palanca") }
    names = [web_name(:left, :up), web_name(:center, :up), web_name(:right, :down), t(:vitro_azalea_lever_blue), t(:vitro_azalea_lever_red)]
    assert_equal names.sort, listed
  end

  test "Azalea says each lever as it is pulled and put back" do
    on_map(57)
    tick
    $game_switches[79] = true
    assert_equal [[lever(:blue, true), false]], tick
    $game_switches[78] = true
    assert_equal [[lever(:red, true), false]], tick
    $game_switches[79] = false
    assert_equal [[lever(:blue, false), false]], tick
  end

  test "a web of Azalea says at its end the platform it left the player on, and between platforms how far it went" do
    on_map(57)
    web = place(2, 4, 30, [TestCmd.new(209, [-1, nil]), TestCmd.new(0, [])])
    PokeAccess::Puzzles.tick
    fire(web)
    $game_player.x = 9
    $game_player.y = 20
    assert_equal t(:vitro_azalea_landed, :at => t(:vitro_azalea_at_center)), forced_line
    $game_player.x = 3
    $game_player.y = 8
    assert_equal t(:vitro_azalea_landed, :at => t(:vitro_azalea_at_top_left)), forced_line
    $game_player.x = 6
    $game_player.y = 28
    assert_nil forced_line, "between platforms"
    fire(place(13, 3, 19, [TestCmd.new(121, [78, 78, 0]), TestCmd.new(0, [])]))
    $game_player.x = 9
    $game_player.y = 20
    assert_nil forced_line, "not after a web"
  end

  test "Azalea gives no step without the assist, and with it the next one from each platform as the levers stand" do
    on_map(57)
    stand(9, 35, false, false)
    refute_includes info_key, t(:vitro_azalea_next, :what => web_name(:left, :up))
    PokeAccess::Config.puzzle_assist = true
    STEPS.each do |x, y, red, blue, what|
      stand(x, y, red, blue)
      name = what.is_a?(Array) ? web_name(what[0], what[1]) : t("vitro_azalea_lever_#{what}".to_sym)
      assert_includes info_key, t(:vitro_azalea_next, :what => name), "at #{x},#{y} red #{red} blue #{blue}"
    end
  end

  test "Azalea says where Anton is, gives no step between the platforms, and goes quiet with the badge" do
    on_map(57)
    PokeAccess::Config.puzzle_assist = true
    stand(9, 8, false, false)
    assert_includes info_key, t(:vitro_azalea_goal)
    stand(9, 13, false, false)
    refute_includes info_key, t(:vitro_azalea_goal)
    refute_includes info_key, t(:vitro_azalea_next, :what => web_name(:left, :up))
    $game_switches[5] = true
    refute PokeAccess::Puzzles.active?
  end

  test "Olivine lists the buttons, the single-use one named so with the assist and only while unused" do
    on_map(97)
    [1, 12, 13, 14, 21, 30].each_with_index { |id, i| place(id, 2 + i, 24, [TestCmd.new(101, ["button"])], "Gym_block") }
    assert_equal [t(:vitro_olivine_button)] * 6, listed
    PokeAccess::Config.puzzle_assist = true
    assert_equal ([t(:vitro_olivine_button)] * 5 + [t(:vitro_olivine_button_once)]).sort, listed
    $game_switches[136] = true
    assert_equal [t(:vitro_olivine_button)] * 5, listed
  end

  test "Olivine says the blocks as a button flips them, with the next step alone when the assist is on" do
    on_map(97)
    go(9, 45)
    tick
    $game_switches[135] = true
    assert_equal [[t(:vitro_olivine_down), false]], tick
    PokeAccess::Config.puzzle_assist = true
    $game_switches[135] = false
    go(11, 25)
    assert_equal [["#{t(:vitro_olivine_up)}. #{t(:vitro_olivine_chamber_hint)}", false]], tick
  end

  test "Olivine gives the step of each stage: the first button, raising the blocks again, the chamber, then the free way" do
    on_map(97)
    PokeAccess::Config.puzzle_assist = true
    [[false, false, 9, 45, :up, :start], [true, false, 9, 45, :down, :raise], [false, false, 11, 25, :up, :chamber],
     [false, true, 9, 45, :up, :lower], [true, true, 11, 20, :down, :free]].each do |down, spent, x, y, state, hint|
      $game_switches[135] = down
      $game_switches[136] = spent
      go(x, y)
      assert_includes info_key, t("vitro_olivine_#{state}".to_sym), "stage #{hint}"
      assert_includes info_key, t("vitro_olivine_#{hint}_hint".to_sym), "stage #{hint}"
    end
    PokeAccess::Config.puzzle_assist = false
    refute_includes info_key, t(:vitro_olivine_free_hint)
    $game_switches[9] = true
    refute PokeAccess::Puzzles.active?
  end

  test "Olivine gives the step of the zone the player is in with the blocks raised, and says nothing crossing its edge" do
    on_map(97)
    PokeAccess::Config.puzzle_assist = true
    ZONES.each do |x, y, hint|
      go(x, y)
      assert_includes info_key, t("vitro_olivine_#{hint}_hint".to_sym), "at #{x},#{y}"
    end
    go(3, 38)
    tick
    go(3, 39)
    assert_equal [], tick
    go(18, 38)
    assert_equal [], tick
  end

  test "Mahogany lists the pads, says where each sent the player, and gives the ice rule with the way on only with the assist" do
    on_map(75)
    place(4, 7, 2, [TestCmd.new(122, [])])
    place(5, 25, 23, [TestCmd.new(122, [])])
    assert_equal [t(:vitro_mahogany_pad)] * 2, listed
    PokeAccess::Puzzles::Auto.instance_variable_set(:@last_used, 4)
    assert_equal t(:vitro_mahogany_to_south), PokeAccess::Puzzles.sent_back_line([7, 2, 75], [25, 22, 75])
    PokeAccess::Puzzles::Auto.instance_variable_set(:@last_used, 5)
    assert_equal t(:vitro_mahogany_to_north), PokeAccess::Puzzles.sent_back_line([25, 23, 75], [7, 2, 75])
    assert_nil PokeAccess::Puzzles.sent_back_line([25, 23, 75], [25, 22, 75])
    tick
    assert_includes info_key, t(:vitro_mahogany_ice)
    assert_includes info_key, t(:vitro_mahogany_rule)
    refute_includes info_key, t(:vitro_mahogany_hint)
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, t(:vitro_mahogany_hint)
    $game_switches[10] = true
    refute PokeAccess::Puzzles.active?
  end

  test "Blackthorn tracks the boulder to its hole, with the assist how far it is, and stops once a hole is filled" do
    on_map(86)
    boulder = place(12, 28, 10, [TestCmd.new(355, ["pbPushThisBoulder"])], "Object boulder")
    tick
    assert_includes info_key, t(:vitro_blackthorn_title)
    refute_includes info_key, t(:vitro_blackthorn_hint)
    PokeAccess::Config.puzzle_assist = true
    away = PokeAccess::Puzzles.goal_offset([28, 12, 28, 12], [28, 10])
    assert_includes info_key, t(:puzzle_track_goal, :label => t(:vitro_blackthorn_rock), :dist => away, :goal => t(:vitro_blackthorn_hole))
    assert_includes info_key, t(:vitro_blackthorn_hint)
    boulder.y = 11
    tick
    $game_switches[89] = true
    tick
    refute_includes info_key.to_s, t(:vitro_blackthorn_title)
  end

  test "Blackthorn keeps the rock count with one rock fallen and goes quiet with the badge, not at three" do
    on_map(86)
    tick
    $game_switches[89] = true
    tick
    assert_includes info_key, t(:vitro_rocks_fallen, :n => 1, :of => 3)
    assert PokeAccess::Puzzles.active?
    $game_switches[11] = true
    refute PokeAccess::Puzzles.active?
  end

  private

  def t(key, vars = {})
    PokeAccess::I18n.t(key, vars)
  end

  def forced_line
    PokeAccess::Puzzles.sent_back_line([4, 31, 57], [$game_player.x, $game_player.y, 57], :forced)
  end

  def fire(ev)
    PokeAccess::Puzzles::Auto.fired($game_system.map_interpreter, PokeAccess.ivar(ev, :@list), ev.id)
  end

  def on_map(map)
    Harness.load_puzzles("vitro")
    PokeAccess::Config.puzzle_assist = false
    $game_map.map_id = map
    [5, 8, 9, 10, 11, 78, 79, 89, 90, 95, 135, 136].each { |s| $game_switches[s] = false }
    go(1, 1)
    World.next_frame
  end

  def place(id, x, y, list, sprite = "")
    page = TestPage.new(:trigger => 0, :sprite => sprite, :list => list)
    ev = TestGameEvent.new(:id => id, :x => x, :y => y, :pages => [page], :active_page => page)
    $game_map.events[id] = ev
    World.next_frame
    ev
  end

  def go(x, y)
    $game_player.x = x
    $game_player.y = y
  end

  def stand(x, y, red, blue)
    go(x, y)
    $game_switches[78] = red
    $game_switches[79] = blue
  end

  def listed
    PokeAccess::Puzzles.category_targets.map { |tg| tg.name }.sort
  end

  def gate(state)
    "#{t(:vitro_cianwood_gate)}: #{t(state)}"
  end

  def lever(color, on)
    "#{t("vitro_azalea_lever_#{color}".to_sym)}: #{t(on ? :vitro_azalea_lever_on : :vitro_azalea_lever_off)}"
  end

  def web_name(col, way)
    t(:vitro_azalea_web, :col => t("vitro_azalea_col_#{col}".to_sym), :dir => t("vitro_azalea_dir_#{way}".to_sym))
  end

  def tick
    SpeakCapture.clear
    PokeAccess::Puzzles.tick
    SpeakCapture.log.dup
  end

  def info_key
    PokeAccess::Info.map_text
  end
end
