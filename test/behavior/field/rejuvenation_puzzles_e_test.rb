# Pokemon Rejuvenation's puzzles of part E (games/rejuvenation/puzzles/): Chrysalis' summoning board, its labyrinth and
# the servant's maids, West Gearen's pipes and Darchlight Manor's doll. Without the assist, what the screen shows; with
# it, the way.
class RejuvenationPuzzlesETest < PokeAccessTest
  SWITCHES = [802, 803, 974, 994, 1028, 1139]
  VARS = [316, 363, 514, 679, 680, 969]
  DIRS = { 2 => [0, 1], 4 => [-1, 0], 6 => [1, 0], 8 => [0, -1] }

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

  test "each board plan moves every pin by zero, one or two tiles the way pressed, and ends on the phase's two marks" do
    pins = PokeAccess::RejuvPins
    ends = { 0 => [85, 25, 91, 25], 2 => [83, 27, 93, 23], 4 => [85, 23, 95, 27] }
    starts = { 0 => [[83, 29, 93, 29]], 2 => [[81, 27, 95, 29], [81, 27, 85, 23]], 4 => [[89, 25, 87, 29]] }
    starts.each do |stage, list|
      list.each do |s|
        presses = 0
        seen = [s]
        while (d = pins::PLANS[stage][s]) && presses < 10
          nxt = ([ends[stage]] + pins::PLANS[stage].keys).find { |k| !seen.include?(k) && moved_by?(s, k, d) }
          assert nxt, "stage #{stage}: nothing follows #{s.inspect} pressing #{d}"
          seen << nxt
          s = nxt
          presses += 1
        end
        assert_equal ends[stage], s
        assert_includes [5, 6, 7], presses
      end
      assert_equal pins::MARKS[stage].flatten, ends[stage]
    end
  end

  test "the board says where each pin stands as it opens and after each press, and the assist the next press" do
    pins = PokeAccess::RejuvPins
    board_at([83, 29], [93, 29])
    lines = said { pins.poll }
    assert_equal ["{rje_pins_far dist=2 {dir_right}, 4 {dir_up} mark={rje_pins_west} n=1}. " \
                  "{rje_pins_far dist=2 {dir_left}, 4 {dir_up} mark={rje_pins_east} n=2}"], lines
    assert_empty said { pins.poll }
    PokeAccess::Config.puzzle_assist = true
    move_pins([83, 25], [91, 25])
    assert_includes said { pins.poll }.join, "{rje_pins_next dir={dir_left}}"
    move_pins([85, 25], [91, 25])
    lines = said { pins.poll }.join
    assert_includes lines, "{rje_pins_on mark={rje_pins_west} n=1}"
    assert_includes lines, "{rje_pins_reset key="
    $game_map.events[36].define_singleton_method(:moving?) { true }
    move_pins([83, 29], [93, 29])
    assert_empty said { pins.poll }
    $game_switches[802] = false
    assert_nil pins.line
  end

  test "the board's phases go by variable 680, and the board stops talking once switch 803 ends it" do
    pins = PokeAccess::RejuvPins
    board_at([81, 27], [85, 23])
    $game_variables[680] = 2
    PokeAccess::Config.puzzle_assist = true
    assert_includes pins.line, "{rje_pins_next dir={dir_down}}"
    $game_variables[680] = 3
    assert_nil pins.line
    $game_variables[680] = 4
    $game_switches[803] = true
    assert_nil pins.line
  end

  test "the labyrinth's exit is listed until it is crossed, and its rule is the assist's" do
    on_map(391, 30, 50)
    place(19, 30, 16, "EV019", 1)
    assert_includes listed_names, "{rje_maze_exit}"
    refute_includes info_key, "rje_maze_hint"
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, "{rje_maze_hint}"
    $game_variables[679] = 3
    refute_includes listed_names, "{rje_maze_exit}"
    refute_includes info_key, "rje_maze_hint"
  end

  test "the maids are counted by their own self switches, named with the assist alone, and the sofa servant is not" do
    maids = PokeAccess::RejuvMaids
    on_map(391, 80, 45)
    $game_switches[994] = true
    $game_variables[363] = 1
    yara = place(54, 80, 41, "EV054", 0, "NPC 31")
    assert_equal 0, maids.beaten
    refute_includes listed_names, "{rje_maids_maid}"
    PokeAccess::Config.puzzle_assist = true
    assert maids.waiting?(yara)
    assert_includes listed_names, "{rje_maids_maid}"
    $game_self_switches[[391, 54, "A"]] = true
    $game_self_switches[[390, 42, "A"]] = true
    $game_variables[363] = 5
    assert_equal 2, maids.beaten
    refute maids.waiting?(yara)
    assert_nil PokeAccess::Puzzles.piece_name(yara)
    on_map(392, 20, 20)
    $game_switches[994] = true
    refute maids.waiting?(place(54, 20, 18, "EV054", 0, "NPC 31"))
  end

  test "each map names its own maids alone: Indriad, the sofa servant and the board's mark are never a maid" do
    maid = "{rje_maids_maid}"
    expect = { 390 => { 42 => maid }, 391 => { 42 => nil, 53 => maid, 54 => maid }, 392 => { 42 => nil, 53 => nil, 54 => nil } }
    expect.each do |map, events|
      on_map(map, 50, 50)
      $game_switches[994] = true
      PokeAccess::Config.puzzle_assist = true
      placed = events.keys.map { |id| [id, place(id, 40 + id % 10, 40 + id / 10, "EV0#{id}", 0, "NPC 31")] }
      placed.each do |id, ev|
        assert_equal events[id].to_s, PokeAccess::Puzzles.piece_name(ev).to_s, "map #{map}, event #{id}"
      end
      PokeAccess::Config.puzzle_assist = false
      placed.each { |id, ev| assert_nil PokeAccess::Puzzles.piece_name(ev), "map #{map}, event #{id} without the assist" }
    end
  end

  test "the pipes' plan carries each pipe from its start to the tile the terminals check" do
    pipes = PokeAccess::RejuvPipes
    pos = {}
    pipes::START.each { |id, xy| pos[id] = xy.dup }
    pipes::PLAN.each do |id, dir|
      pos[id] = [pos[id][0] + DIRS[dir][0], pos[id][1] + DIRS[dir][1]]
    end
    assert_equal pipes::GOALS, pos
    assert_equal [21, 138], pipes.stand(0)
    assert_equal [22, 129], pipes.stand(10)
  end

  test "the pipes' assist asks for the Muk first, then each push, the water and the terminal" do
    pipes = PokeAccess::RejuvPipes
    on_map(415, 24, 141)
    pipes::START.each { |id, (x, y)| place(id, x, y, "Pipe", 0, "sewerpipe") }
    assert_equal :muk, pipes.step
    [131, 132, 133].each { |id| $game_self_switches[[415, id, "A"]] = true }
    assert_equal 0, pipes.step
    assert_equal [:rje_pipes_push, { :n => 1, :dir => "{face_south}", :from => "{face_north}" }], pipes.push_line(0)
    $game_map.events[98].x = 20
    assert_equal :reset, pipes.step
    pipes::GOALS.each { |id, (x, y)| $game_map.events[id].x = x; $game_map.events[id].y = y }
    assert_equal :terminal, pipes.step
    $game_variables[969] = 1
    assert_equal :rje_pipes_water, pipes.terminal_line
    $game_self_switches[[415, 134, "A"]] = true
    assert_nil pipes.step
  end

  test "the Zorua room's plan pushes each statue from its tile into its own, the player standing behind it" do
    zorua = PokeAccess::RejuvZorua
    zorua.forget
    pos = {}
    zorua::START.each { |id, xy| pos[id] = xy.dup }
    zorua::PLAN.each_with_index do |(id, dir, from), i|
      assert_equal i, zorua.index_for(zorua::STATUES.map { |s| pos[s] })
      assert_equal [pos[id][0] - DIRS[dir][0], pos[id][1] - DIRS[dir][1]], from
      pos[id] = [pos[id][0] + DIRS[dir][0], pos[id][1] + DIRS[dir][1]]
      refute_includes pos.reject { |k, _| k == id }.values, pos[id]
    end
    assert_equal zorua::GOALS, pos
  end

  test "the Zorua room says each push with the assist alone, and the way back once off the plan" do
    zorua = PokeAccess::RejuvZorua
    zorua.forget
    on_map(107, 18, 72)
    $game_variables[514] = 6
    zorua::START.each { |id, (x, y)| place(id, x, y, id == 39 ? "Sableye 2" : "Statue", 0, "Weight_4") }
    refute_includes info_key, "rj_garufa_push"
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, "{rj_garufa_push dir={face_south} from={face_north} name=Sableye}"
    assert_equal zorua::PLAN[0][2], zorua.push_from
    $game_map.events[48].x = 3
    assert_equal :reset, zorua.next_push
    $game_switches[1028] = true
    assert_nil zorua.next_push
  end

  test "Darchlight's doll chain lists its next step with the assist, and the gate out once it moves to the grounds" do
    dm = PokeAccess::RejuvDarchlight
    on_map(112, 20, 20)
    place(14, 44, 26, "EV014")
    place(83, 22, 43, "EV083")
    $game_variables[316] = 7
    assert_includes listed_names, "{rje_dm_portrait}"
    refute_includes info_key, "rje_dm_h_"
    refute_includes listed_names, "{rje_dm_next}"
    PokeAccess::Config.puzzle_assist = true
    assert_includes listed_names, "{rje_dm_next}"
    assert_equal [44, 26], dm.next_tile
    assert_equal :rje_dm_h_portrait, dm.hint
    assert_includes info_key, "{rje_dm_h_portrait}"
    $game_variables[316] = 14
    assert_equal [22, 43], dm.next_tile
    assert_equal :rje_dm_h_out, dm.hint
    $game_variables[316] = 16
    assert_nil dm.next_tile
    assert_nil dm.hint
  end

  private

  # True when each pin of state a reaches state b moving 0, 1 or 2 tiles in direction d.
  def moved_by?(a, b, d)
    dx, dy = DIRS[d]
    [0, 2].all? do |i|
      (0..2).any? { |k| a[i] + dx * k == b[i] && a[i + 1] + dy * k == b[i + 1] }
    end && a != b
  end

  def board_at(a, b)
    on_map(391, 88, 33)
    PokeAccess::RejuvPins.poll
    $game_switches[802] = true
    place(36, a[0], a[1], "HazPin", 2, "object_pin_1")
    place(37, b[0], b[1], "AngiePin", 2, "object_pin_1")
    [36, 37].each { |id| $game_map.events[id].define_singleton_method(:moving?) { false } }
  end

  def move_pins(a, b)
    $game_map.events[36].x, $game_map.events[36].y = a
    $game_map.events[37].x, $game_map.events[37].y = b
  end

  def said
    SpeakCapture.clear
    yield
    SpeakCapture.lines
  end

  def listed_names
    PokeAccess::Puzzles.category_targets.map do |tg|
      tg.is_a?(PokeAccess::Locator::SurfaceTarget) ? tg.name.to_s : PokeAccess::Puzzles.piece_name(tg)
    end
  end

  # Makes I18n.t answer each key and its values as "{key name=value ...}", so what the puzzles say is compared by its
  # keys and values rather than by the text of a language.
  def keyed
    i18n = PokeAccess::I18n.singleton_class
    i18n.send(:alias_method, :rje_kept_t, :t)
    i18n.send(:define_method, :t) do |key, vars = nil|
      parts = [key.to_s] + (vars || {}).map { |k, v| "#{k}=#{v}" }.sort
      "{#{parts.join(' ')}}"
    end
  end

  # Gives I18n.t back its own body.
  def unkeyed
    i18n = PokeAccess::I18n.singleton_class
    i18n.send(:alias_method, :t, :rje_kept_t)
    i18n.send(:remove_method, :rje_kept_t)
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

  def info_key
    PokeAccess::Info.map_text.to_s
  end
end
