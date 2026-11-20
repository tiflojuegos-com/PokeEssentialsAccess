# Infinite Fusion Kanto's story puzzles on the shipped profile: Vermilion's trash cans, Celadon's sewers, Silph Co.'s card
# doors, Saffron's pads, the Mansion's gates, Cinnabar's quiz, Mt. Ember's barrier, Fuchsia's walls, Viridian's arrows and
# Victory Road's boulder tiles. What a sighted player sees is heard unassisted; the answers only with the assist.
class InfiniteFusionPuzzlesGdTest < PokeAccessTest
  test "Vermilion names the trash cans by row and column and marks the one with the button for the assist alone" do
    on_map(24)
    text_events(17..33, 24)
    $game_variables[36] = 19
    names = PokeAccess::Puzzles.category_targets.sort_by(&:ref).map(&:name)
    assert_equal 17, names.length
    assert_equal t(:ifk_vm_can, :row => 1, :col => 2), names.first
    assert_equal t(:ifk_vm_can, :row => 3, :col => 6), names.last
    PokeAccess::Config.puzzle_assist = true
    marked = PokeAccess::Puzzles.category_targets.select { |target| target.name == t(:ifk_vm_can_button, :row => 1, :col => 4) }
    assert_equal [19], marked.map(&:ref)
  end

  test "Vermilion counts the locks in the info key and says when the draw has no solution" do
    on_map(24)
    text_events(17..33, 24)
    $game_variables[36] = 20
    $game_switches[90] = true
    line = PokeAccess::Puzzles.info_line
    assert_includes line, t(:ifk_vm_locks)
    refute_includes line, t(:ifk_vm_hint)
    PokeAccess::Config.puzzle_assist = true
    assert_includes PokeAccess::Puzzles.info_line, t(:ifk_vm_hint)
    $game_variables[36] = 16
    assert_includes PokeAccess::Puzzles.info_line, t(:ifk_vm_dead)
    $game_variables[36] = 34
    assert_includes PokeAccess::Puzzles.info_line, t(:ifk_vm_dead)
  end

  test "Vermilion stops listing the cans once the stairs are down" do
    on_map(24)
    text_events(17..33, 24)
    $game_switches[91] = true
    $game_self_switches[[24, 35, "A"]] = true
    assert_empty PokeAccess::Puzzles.category_targets
    assert_nil PokeAccess::Puzzles.info_line
  end

  test "the sewers name both dry approaches and hide the helper sensors, with either assist setting" do
    on_map(431)
    dry_events
    [false, true].each do |assist|
      PokeAccess::Config.puzzle_assist = assist
      targets = PokeAccess::Puzzles.category_targets
      assert_equal [3, 16], targets.map(&:ref).sort
      assert_equal [t(:ifk_sw_approach1), t(:ifk_sw_approach2)], targets.sort_by(&:ref).map(&:name)
      assert targets.all? { |target| PokeAccess::Puzzles.onto?(target) }
    end
    [2, 4, 5, 11, 13, 17].each { |id| assert_nil PokeAccess::Sound::Scene.family_of($game_map.events[id]), "helper #{id}" }
  end

  test "a plank that drops is said, the water level is left to the game's own line and kept for the info key" do
    on_map(431)
    dry_events
    tick
    $game_switches[130] = true
    assert_equal [], tick
    $game_switches[127] = true
    approach(3, 12, 21, 127, true)
    said = tick
    assert_includes said.map { |line, _| line }.join(" "), t(:puzzle_value, :label => t(:ifk_sw_plank1), :v => t(:ifk_sw_lowered))
    assert_equal [16], PokeAccess::Puzzles.category_targets.map(&:ref)
    line = PokeAccess::Puzzles.info_line
    assert_includes line, t(:puzzle_value, :label => t(:ifk_sw_water), :v => t(:ifk_sw_flooded))
    assert_includes line, t(:puzzle_value, :label => t(:ifk_sw_plank2), :v => t(:ifk_sw_raised))
  end

  test "the sewers' hint is for the assist alone" do
    on_map(447)
    World.event(:id => 1, :kind => :sign)
    refute_includes PokeAccess::Puzzles.info_line, t(:ifk_sw_hint)
    PokeAccess::Config.puzzle_assist = true
    assert_includes PokeAccess::Puzzles.info_line, t(:ifk_sw_hint)
  end

  test "the flooded sewers list a plank until it is lowered, then its crossing" do
    on_map(446)
    $game_switches[130] = true
    static_plank(9, 10, 21)
    static_plank(6, 18, 31)
    targets = PokeAccess::Puzzles.category_targets
    assert_equal [t(:ifk_sw_plank1), t(:ifk_sw_plank2)], targets.sort_by(&:x).map(&:name)
    $game_switches[127] = true
    World.next_frame
    first = PokeAccess::Puzzles.category_targets.find { |target| target.x == 10 }
    assert_equal t(:ifk_sw_cross1), first.name
    assert PokeAccess::Puzzles.onto?(first)
  end

  test "a control room names the water console and tells its two exits apart" do
    [447, 448].each do |map|
      on_map(map)
      World.event(:id => 1, :kind => :sign, :x => 9, :y => 5)
      $game_map.events[1].instance_variable_get(:@list).push(TestCmd.new(121, [130, 130, 0]))
      west = World.event(:id => 2, :kind => :door, :x => 3, :y => 5)
      east = World.event(:id => 3, :kind => :door, :x => 15, :y => 5)
      assert_equal [1], PokeAccess::Puzzles.category_targets.map(&:ref)
      assert_equal t(:ifk_sw_control), PokeAccess::Puzzles.piece_name($game_map.events[1])
      assert_equal t(:ifk_sw_west_exit), PokeAccess::Puzzles.piece_name(west)
      assert_equal t(:ifk_sw_east_exit), PokeAccess::Puzzles.piece_name(east)
    end
  end

  test "Silph Co. lists a card door while closed and no longer once open" do
    on_map(660)
    door(10, 8, 9, 536)
    door(11, 9, 9, 536)
    assert_equal [10, 11], PokeAccess::Puzzles.category_targets.map(&:ref).sort
    assert_equal [t(:ifk_silph_door)], PokeAccess::Puzzles.category_targets.map(&:name).uniq
    door(10, 8, 9, 536, true)
    door(11, 9, 9, 536, true)
    assert_empty PokeAccess::Puzzles.category_targets
  end

  test "Saffron's right way is listed with the assist alone and stops after Sabrina" do
    on_map(152)
    [[60, 12, 14], [62, 6, 15], [16, 19, 15], [46, 20, 3], [2, 3, 13]].each do |id, x, y|
      World.touch(:id => id, :x => x, :y => y, :list => [TestCmd.new(201, [0, 152, 3, 3])])
    end
    assert_empty PokeAccess::Puzzles.category_targets.select { |target| target.name == t(:puzzle_right_way) }
    PokeAccess::Config.puzzle_assist = true
    way = PokeAccess::Puzzles.category_targets.select { |target| target.name == t(:puzzle_right_way) }
    assert_equal [16, 46, 60, 62], way.map(&:ref).sort
    $game_switches[9] = true
    assert_empty PokeAccess::Puzzles.category_targets.select { |target| target.name == t(:puzzle_right_way) }
  end

  test "the Mansion's secret switch says its state and the gates it flips" do
    on_map(187)
    gate(1, 18, 10, 2696, 285)
    secret = World.event(:id => 9, :kind => :sign, :x => 25, :y => 30)
    secret.instance_variable_get(:@list).push(TestCmd.new(121, [285, 285, 0]))
    World.next_frame
    tick
    switches = PokeAccess::Puzzles.category_targets.select { |target| target.is_a?(PokeAccess::Locator::SurfaceTarget) }
    assert_equal [9], switches.map(&:ref)
    assert_equal t(:ifk_mn_switch), switches.first.name
    $game_switches[285] = true
    gate(1, 18, 10, 2696, 285, true)
    said = tick.map { |line, _| line }.join(" ")
    assert_includes said, t(:ifk_mn_switch) + ": " + t(:ifk_mn_on)
  end

  test "the Mansion's locked gate of the last floor is named as a gate like the others" do
    on_map(187)
    gate(1, 18, 10, 2696, 285)
    gate(2, 23, 9, 2669, 285)
    assert_equal t(:ifk_mn_gate), PokeAccess::Puzzles.piece_name($game_map.events[2])
    assert_equal PokeAccess::Puzzles.piece_name($game_map.events[1]), PokeAccess::Puzzles.piece_name($game_map.events[2])
  end

  test "the Mansion's gates all carry the gate tiles of the four floors" do
    [173, 174, 181, 187].each do |map|
      on_map(map)
      tiles = Harness.declared(map)[:obstacles].map { |obstacle| obstacle[:tile] }
      assert_equal [2668, 2669, 2670, 2692, 2696], tiles.sort, "map #{map}"
      assert_equal [:ifk_mn_gate], Harness.declared(map)[:obstacles].map { |obstacle| obstacle[:label] }.uniq
    end
  end

  test "the Cinnabar quiz names its six questions, the two tiles of each computer, and each says its right option with the assist" do
    on_map(221)
    computers = { 1 => [17, 32, 13, 34, 33], 2 => [18, 20, 7, 35, 19], 3 => [28, 14, 13, 36, 13], 4 => [30, 14, 19, 37, 13],
                  5 => [31, 8, 19], 6 => [38, 4, 13, 39, 3] }
    computers.each do |_n, (first, x, y, second, other_x)|
      text_event(first, x, y)
      text_event(second, other_x, y) if second
    end
    names = PokeAccess::Puzzles.category_targets.map(&:name)
    assert_equal 11, names.length
    assert_equal (1..6).map { |n| t(:ifk_cg_question, :n => n) }, names.uniq.sort_by { |name| name[/\d+/].to_i }
    computers.each do |n, ids|
      [ids[0], ids[3]].compact.each do |id|
        assert_equal t(:ifk_cg_question, :n => n), PokeAccess::Puzzles.piece_name($game_map.events[id]), "event #{id}"
      end
    end
  end

  test "the Cinnabar right option is the one whose branch counts the answer, said with the assist alone" do
    on_map(221)
    kept = []
    [17, 34, 18, 35, 28, 36, 30, 37, 31, 38, 39].each_with_index do |id, i|
      text_event(id, 3 + i, 5)
      word = QUIZ_WORDS[i % 4]
      menu = quiz_menu(i % 4)
      int = quiz_interpreter(id, menu)
      kept.push(menu)
      assert_equal word, PokeAccess::Puzzles::Answers.right_option(int, menu, 0), "event #{id}"
      PokeAccess::Config.puzzle_assist = false
      PokeAccess::Puzzles::Answers.forget
      SpeakCapture.clear
      PokeAccess::Puzzles::Answers.say(int, 0)
      assert_empty SpeakCapture.log, "event #{id} unassisted"
      PokeAccess::Config.puzzle_assist = true
      PokeAccess::Puzzles::Answers.say(int, 0)
      assert_equal [t(:puzzle_answer, :a => word)], SpeakCapture.log.map { |line, _| line }, "event #{id} assisted"
    end
    text_event(1, 40, 5)
    other = quiz_menu(1)
    assert_nil PokeAccess::Puzzles::Answers.right_option(quiz_interpreter(1, other), other, 0), "an event of no computer"
  end

  test "Mt. Ember says nothing of the barrier, out of sight from the switch's room, and its hint follows the switch with the assist" do
    on_map(756)
    World.event(:id => 3, :kind => :sign, :x => 12, :y => 7)
    $game_map.events[3].instance_variable_get(:@list).push(TestCmd.new(121, [641, 641, 0]))
    World.next_frame
    tick
    assert_equal [t(:ifk_em_switch)], PokeAccess::Puzzles.category_targets.map(&:name)
    [false, true].each do |assist|
      PokeAccess::Config.puzzle_assist = assist
      $game_switches[641] = true
      assert_empty tick, "switch on, assist #{assist}"
      $game_switches[641] = false
      assert_empty tick, "switch off, assist #{assist}"
    end
    PokeAccess::Config.puzzle_assist = false
    [true, false].each do |on|
      $game_switches[641] = on
      assert_equal "", PokeAccess::Puzzles.info_line.to_s
    end
    PokeAccess::Config.puzzle_assist = true
    tick
    assert_includes PokeAccess::Puzzles.info_line.to_s, t(:ifk_em_press)
    $game_switches[641] = true
    tick
    assert_includes PokeAccess::Puzzles.info_line.to_s, t(:ifk_em_leave)
  end

  test "Fuchsia tells of its invisible walls on arriving, and no more once Koga is beaten" do
    on_map(479)
    assert_includes tick.map { |line, _| line }, t(:ifk_fg_rule)
    on_map(479)
    $game_switches[8] = true
    refute_includes tick.map { |line, _| line }, t(:ifk_fg_rule)
  end

  test "the sewers tell the water rule on arriving until the hideout is done" do
    [431, 446].each do |map|
      on_map(map)
      assert_includes tick.map { |line, _| line }, t(:ifk_sw_rule), "map #{map}"
      on_map(map)
      $game_switches[148] = true
      refute_includes tick.map { |line, _| line }, t(:ifk_sw_rule), "map #{map} after the hideout"
    end
  end

  test "Viridian tells its arrows' rule on arriving until Giovanni is beaten" do
    on_map(85)
    assert_includes tick.map { |line, _| line }, t(:ifk_va_rule)
    on_map(85)
    $game_switches[11] = true
    refute_includes tick.map { |line, _| line }, t(:ifk_va_rule)
  end

  test "Viridian names each arrow by where it slides, says it when stepped on and keeps routes off them" do
    on_map(85)
    arrows = { :left => [8, 9, 36], :right => [5, 13, 14], :up => [6, 10, 11], :down => [7, 12, 16, 17, 41, 42] }
    arrows.each { |_way, ids| ids.each { |id| text_event(id, 4 + id % 30, 10 + id / 30) } }
    avoids = Harness.declared(85)[:avoids]
    arrows.each do |way, ids|
      ids.each do |id|
        event = $game_map.events[id]
        assert_equal t("ifk_va_arrow_#{way}".to_sym), PokeAccess::Puzzles.piece_name(event), "event #{id}"
        assert avoids.any? { |what| PokeAccess::World::Mechanics.picks?(what, event) }, "event #{id} kept off"
        PokeAccess::World::Mechanics.used(event)
        said = PokeAccess::World::Mechanics.drain.map { |_spec, change| change }
        assert_equal [[:use, "ifk_va_slide_#{way}".to_sym]], said.map { |change| [change[0], change[1][:label]] }, "event #{id} on use"
      end
    end
    assert_equal arrows.values.flatten.sort, avoids.map(&:keys).flatten.sort
    text_event(1, 3, 3)
    refute avoids.any? { |what| PokeAccess::World::Mechanics.picks?(what, $game_map.events[1]) }
  end

  test "Victory Road says each boulder tile and lists the marker; the hints are for the assist alone" do
    { 304 => [3, 308, :ifk_vr_hint_304], 306 => [9, 309, :ifk_vr_hint_306], 307 => [8, 312, :ifk_vr_hint_307] }.each do |map, (marker, switch, hint)|
      on_map(map)
      page = TestPage.new(:list => [TestCmd.new(0, [])], :through => true)
      $game_map.events[marker] = TestGameEvent.new(:id => marker, :x => 7, :y => 7, :tile_id => 1027, :pages => [page])
      World.next_frame
      tick
      assert_includes PokeAccess::Puzzles.category_targets.map(&:name), t(:ifk_vr_target)
      $game_switches[switch] = true
      assert_includes tick.map { |line, _| line }.join(" "), t(:ifk_vr_pressed)
      refute_includes PokeAccess::Puzzles.info_line.to_s, t(hint)
      PokeAccess::Config.puzzle_assist = true
      assert_includes PokeAccess::Puzzles.info_line, t(hint)
    end
  end

  private

  QUIZ_WORDS = %w[Alpha Beta Gamma Delta]

  def t(key, vars = {}); PokeAccess::I18n.t(key, vars); end

  def quiz_menu(right)
    list = [TestCmd.new(102, [QUIZ_WORDS, 1], 0)]
    QUIZ_WORDS.each_with_index do |word, i|
      list.push(TestCmd.new(402, [i, word], 0))
      list.push(TestCmd.new(122, [117, 117, 1, 0, 1], 1)) if i == right
      list.push(TestCmd.new(0, [], 1))
    end
    list.push(TestCmd.new(404, [], 0))
    list
  end

  def quiz_interpreter(event_id, list)
    int = Object.new
    int.instance_variable_set(:@event_id, event_id)
    int.instance_variable_set(:@list, list)
    int.instance_variable_set(:@index, 0)
    int
  end

  def on_map(map)
    Harness.load_puzzles("infinitefusion")
    World.clear_events
    $game_map.map_id = map
    $game_map.width = 50
    $game_map.height = 50
    ((24..24).to_a + [8, 9, 11, 90, 91, 127, 128, 129, 130, 148, 285, 308, 309, 310, 311, 312, 536, 641]).each { |s| $game_switches[s] = false }
    [36, 117].each { |v| $game_variables[v] = 0 }
    $game_self_switches = {} if $game_self_switches.nil?
    $game_self_switches.clear
    PokeAccess::Config.puzzle_assist = false
    PokeAccess::World::Mechanics.forget
    PokeAccess::Puzzles::Auto.forget
    World.next_frame
  end

  def tick
    SpeakCapture.clear
    PokeAccess::Puzzles.tick
    SpeakCapture.log.dup
  end

  def text_event(id, x, y)
    page = TestPage.new(:trigger => 0, :list => [TestCmd.new(101, ["Hi"]), TestCmd.new(0, [])])
    $game_map.events[id] = TestGameEvent.new(:id => id, :x => x, :y => y, :pages => [page], :active_page => page)
    World.next_frame
  end

  def text_events(ids, map)
    ids.each { |id| text_event(id, 4 + id % 12, 10 + id / 12) }
  end

  def door(id, x, y, flag, open = false)
    closed = TestPage.new(:trigger => 0, :tile_id => 2318, :list => [TestCmd.new(121, [flag, flag, 0]), TestCmd.new(0, [])])
    done = TestPage.new(:trigger => 0, :condition => { :switch1_valid => true, :switch1_id => flag }, :list => [TestCmd.new(0, [])])
    $game_map.events[id] = TestGameEvent.new(:id => id, :x => x, :y => y, :pages => [closed, done],
                                             :active_page => open ? done : closed, :tile_id => 2318)
    World.next_frame
  end

  def gate(id, x, y, tile, flag, open = false)
    shut = TestPage.new(:trigger => 0, :list => [TestCmd.new(101, ["It's locked..."]), TestCmd.new(0, [])])
    $game_map.events[id] = TestGameEvent.new(:id => id, :x => x, :y => y, :pages => [shut], :active_page => shut,
                                             :tile_id => open ? 0 : tile)
    World.next_frame
  end

  def approach(id, x, y, flag, done = false)
    pages = [TestPage.new(:trigger => 1, :list => [TestCmd.new(121, [128, 128, 0]), TestCmd.new(0, [])]),
             TestPage.new(:condition => { :switch1_valid => true, :switch1_id => flag }, :list => [TestCmd.new(0, [])])]
    $game_map.events[id] = TestGameEvent.new(:id => id, :x => x, :y => y, :pages => pages, :active_page => pages[done ? 1 : 0])
    World.next_frame
  end

  def static_plank(id, x, y)
    page = TestPage.new(:list => [TestCmd.new(0, [])], :through => true)
    $game_map.events[id] = TestGameEvent.new(:id => id, :x => x, :y => y, :tile_id => 414, :pages => [page])
    World.next_frame
  end

  def dry_events
    approach(3, 12, 21, 127)
    approach(16, 20, 31, 129)
    [[4, 12, 20], [5, 12, 22], [11, 12, 18], [17, 21, 31]].each do |id, x, y|
      World.touch(:id => id, :x => x, :y => y, :list => [TestCmd.new(121, [128, 128, id == 11 || id == 17 ? 1 : 0])])
    end
    [[2, 10, 21, 127], [13, 18, 31, 129]].each do |id, x, y, flag|
      pages = [TestPage.new(:trigger => 2, :list => [TestCmd.new(0, [])]),
               TestPage.new(:trigger => 2, :condition => { :switch1_valid => true, :switch1_id => 128 },
                 :list => [TestCmd.new(121, [flag, flag, 0]), TestCmd.new(121, [128, 128, 1]), TestCmd.new(0, [])])]
      $game_map.events[id] = TestGameEvent.new(:id => id, :x => x, :y => y, :pages => pages, :tile_id => 414)
    end
    World.next_frame
  end
end
