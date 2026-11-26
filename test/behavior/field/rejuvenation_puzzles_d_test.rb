# Pokemon Rejuvenation's puzzles of part D (games/rejuvenation/puzzles/): East Gearen's gym, Tyluric Temple, Blacksteeple
# by night, the School of Nightmares, Bladestar's cameras, Nim's trees, Saki's statues, Fort Rystrine's Vileplume, and
# the game's own puzzle skip.
# Without the assist, what the screen shows; with it, the way.
class RejuvenationPuzzlesDTest < PokeAccessTest
  SWITCHES = [320, 772, 773, 774, 778, 1291, 1313, 1314, 1315, 1316]
  VARS = [36, 232, 294, 334, 502, 503, 504, 505, 506, 515, 589, 685, 703, 719]

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

  test "East Gearen's power switches say whether they are on, and the numbered tiles their number" do
    gym = PokeAccess::RejuvEastGearenGym
    on_map(484, 30, 30)
    power = place(91, 57, 16, "EV091")
    tile = place(37, 18, 20, "EV037")
    assert_equal "{rjd_eg_power_off}", PokeAccess::Puzzles.piece_name(power)
    assert_equal "{rjd_eg_tile n=3}", PokeAccess::Puzzles.piece_name(tile)
    $game_switches[773] = true
    assert_equal :rjd_eg_power_on, gym.power(power)
    $game_switches[772] = false
    assert_equal :rjd_eg_power_off, gym.power(place(90, 40, 6, "EV090"))
  end

  test "East Gearen's code walks the tiles' own counting to 8, and its next tile is said with the assist alone" do
    gym = PokeAccess::RejuvEastGearenGym
    steps = { 2 => { 0 => 1, 3 => 4, 7 => 8 }, 3 => { 1 => 2, 2 => 3, 5 => 6, 6 => 7 }, 4 => { 4 => 5 } }
    count = gym::CODE.inject(0) { |v, n| steps[n].fetch(v) }
    assert_equal 8, count
    on_map(484, 30, 30)
    refute_includes info_key, "rjd_eg_code_next"
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, "{rjd_eg_code_next n=2 step=1}"
    assert_includes info_key, "{rjd_eg_stage_hint}"
    $game_variables[334] = 4
    assert_includes info_key, "{rjd_eg_code_next n=4 step=5}"
    $game_switches[774] = true
    $game_switches[778] = true
    refute_includes info_key, "rjd_eg_"
  end

  test "Tyluric Temple's whirlwinds follow their pages to the end, and the assist names the next one" do
    temple = PokeAccess::RejuvTyluricTemple
    pages = { 64 => [[1, 2], [2, nil], [3, 1], [4, nil], [5, 6], [6, nil]], 65 => [[2, 3], [3, nil]],
              66 => [[2, 1], [3, 4], [4, nil]], 67 => [[4, 5], [5, nil], [6, 7], [7, nil]] }
    touch = lambda do |id, v|
      page = pages[id].select { |min, _to| v >= min }.last
      page && page[1]
    end
    v = 1
    while temple::ORDER[v]
      v = touch.call(temple::ORDER[v], v)
    end
    assert_equal 7, v
    on_map(179, 88, 47)
    $game_variables[719] = 5
    $game_variables[515] = 1
    assert_equal "{rjd_ty_whirl_ne}", PokeAccess::Puzzles.piece_name(place(66, 92, 55, "EV066"))
    refute_includes info_key, "rjd_ty_whirl_next"
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, "{rjd_ty_whirl_next name={rjd_ty_whirl_se}}"
    $game_variables[515] = 3
    assert_includes info_key, "{rjd_ty_whirl_next name={rjd_ty_whirl_ne}}"
  end

  test "Tyluric Temple's deflectors go by their place on the ball's way, and the assist names those to switch" do
    temple = PokeAccess::RejuvTyluricTemple
    on_map(179, 81, 27)
    $game_variables[719] = 6
    fourth = place(16, 80, 11, "Screen 3")
    assert_equal "{rjd_ty_deflector_off n=4}", PokeAccess::Puzzles.piece_name(fourth)
    $game_variables[505] = 1
    assert_equal [:rjd_ty_deflector_on, { :n => 4 }], temple.deflector(fourth)
    refute_includes info_key, "rjd_ty_deflect"
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, "{rjd_ty_deflect_hint list=1, 2, 3, 4, 5}"
    [502, 503, 504, 506].each { |var| $game_variables[var] = 1 }
    $game_variables[505] = 0
    assert_includes info_key, "{rjd_ty_deflect_go}"
    $game_variables[719] = 7
    refute_includes info_key, "rjd_ty_"
  end

  test "Blacksteeple's guards watch by night as the engine reads their names, Counter ones over what stands between" do
    on_map(438, 30, 40)
    $game_switches[1291] = true
    $game_variables[232] = 64
    trainer = place(73, 22, 32, "Trainer(3)", 2, "policeview")
    counter = place(36, 54, 37, "Counter(4)", 2, "policeview")
    seen = {}
    PokeAccess::Routes::Sight.watchers.each { |w| seen[w.rec.id] = [w.range, w.through ? true : false] }
    assert_equal [3, false], seen[73]
    assert_equal [4, true], seen[36]
    assert_equal "{rjd_bs_guard}", PokeAccess::Puzzles.piece_name(trainer)
    assert_equal "{rjd_bs_guard}", PokeAccess::Puzzles.piece_name(counter)
    assert PokeAccess::RejuvBlacksteepleNight.night?
    $game_variables[232] = 67
    refute PokeAccess::RejuvBlacksteepleNight.night?, "the stealth ends once Emma reaches the library"
  end

  test "Blacksteeple's robots and their panels are listed while they wait, and a robot counts once on its own panel" do
    night = PokeAccess::RejuvBlacksteepleNight
    on_map(443, 60, 70)
    $game_variables[232] = 36
    gold = place(35, 59, 66, "Bot1", 0, "trchar097")
    assert_equal "{rjd_bs_robot_gold}", PokeAccess::Puzzles.piece_name(gold)
    assert_includes listed, [78, 69, "{rjd_bs_panel_gold}"]
    assert_includes listed, [53, 76, "{rjd_bs_panel_green}"]
    refute night.placed?(35, [78, 69])
    gold.x = 78
    gold.y = 69
    assert night.placed?(35, [78, 69])
    $game_variables[232] = 39
    refute(listed.any? { |r| r[2] == "{rjd_bs_panel_gold}" }, "the panels leave the list once the cart has run")
  end

  test "Blacksteeple's floor plans point to the bookcase they lack with the assist alone" do
    on_map(443, 8, 16)
    $game_variables[232] = 67
    refute_includes info_key, "{rjd_bs_plans_hint}"
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, "{rjd_bs_plans_hint}"
    $game_variables[232] = 68
    refute_includes info_key, "{rjd_bs_plans_hint}"
  end

  test "the School of Nightmares' terminals say when delivered, and a crate room says its presses with the assist" do
    on_map(160, 10, 45)
    terminal = place(3, 9, 10, "EV003")
    place(12, 7, 42, "Moving Box", 0, "object_box")
    assert_equal "{rjd_sn_terminal}", PokeAccess::Puzzles.piece_name(terminal)
    refute_includes info_key, "rjd_sn_moves"
    PokeAccess::Config.puzzle_assist = true
    moves = "{rjd_sn_moves moves={dir_up}, {dir_right}, {dir_up}, {dir_right}, {dir_up}, {dir_left}, {dir_down}, " \
            "{dir_right}, {dir_down}, {dir_left}, {dir_down}, {dir_right}}"
    assert_includes frame, moves
    $game_switches[1313] = true
    assert_equal :rjd_sn_terminal_done, PokeAccess::RejuvSchoolOfNightmares.terminal(terminal)
    refute_includes info_key, "rjd_sn_moves"
  end

  test "Bladestar's screens name themselves, and the recording that moves the story on comes with the assist" do
    on_map(505, 37, 8)
    assert_equal "{rjd_bl_screens}", PokeAccess::Puzzles.piece_name(place(1, 37, 7, "Screen 2", 0, "object_monitor4"))
    $game_variables[294] = 20
    refute_includes info_key, "{rjd_bl_cameras_hint}"
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, "{rjd_bl_cameras_hint}"
    $game_variables[294] = 21
    refute_includes info_key, "{rjd_bl_cameras_hint}"
  end

  test "Nim's trees go by number until the fake one is found" do
    on_map(96, 14, 26)
    $game_variables[36] = 3
    place(3, 13, 24, "TREE 1", 0, "Object tree 1")
    place(10, 14, 24, "TREE 2", 0, "Object tree 1")
    assert_equal "{rjd_ad_tree n=3}", PokeAccess::Puzzles.piece_name(place(11, 15, 24, "EV011", 0, "Nim1_2"))
  end

  test "Saki's statues: the assist says the turn that counts, and on a turned one the reset only if it was wrong" do
    on_map(111, 57, 77)
    int = $game_system.map_interpreter
    kept = int.instance_variable_get(:@event_id)
    turn = [[TestCmd.new(123, ["A", 0], 1)], [TestCmd.new(122, [703, 703, 1, 0, 1], 1), TestCmd.new(123, ["A", 0], 1)],
            [TestCmd.new(123, ["A", 0], 1)], [TestCmd.new(123, ["A", 0], 1)]]
    reset = [[TestCmd.new(123, ["B", 1], 1), TestCmd.new(123, ["A", 1], 1)], []]
    assert_equal "South", option(int, 71, %w[North South East West], turn)
    $game_self_switches[[111, 71, "A"]] = true
    assert_equal "Yes", option(int, 71, %w[Yes No], reset), "a statue turned the wrong way is reset"
    $game_self_switches[[111, 71, "B"]] = true
    assert_nil option(int, 71, %w[Yes No], reset), "a statue turned the right way is left"
  ensure
    int.instance_variable_set(:@event_id, kept) if int
  end

  test "Fort Rystrine's Vileplume tiles are kept off with the assist alone and only while it mugs, and its mugging is said" do
    on_map(523, 50, 30)
    trap = place(24, 58, 27, "EV024", 1)
    other = place(30, 40, 30, "EV030", 1)
    tile = PokeAccess::Routes.pkey(trap.x, trap.y)
    refute PokeAccess::Routes::Controls.keep_off[tile], "unseen without the assist"
    PokeAccess::Config.puzzle_assist = true
    assert PokeAccess::Routes::Controls.keep_off[tile]
    refute PokeAccess::Routes::Controls.keep_off[PokeAccess::Routes.pkey(other.x, other.y)]
    fire(other)
    assert_nil PokeAccess::Puzzles.sent_back_line([58, 27, 523], [17, 37, 523])
    fire(trap)
    assert_equal "{rjd_fr_mugged}", PokeAccess::Puzzles.sent_back_line([58, 27, 523], [17, 37, 523])
    $game_variables[589] = 1
    refute PokeAccess::Routes::Controls.keep_off[tile], "with the serum on, the next tile scares it off"
  end

  test "the game's puzzle skip is named by its graphic wherever it stands" do
    rules = PokeAccess::Locator.instance_variable_get(:@rules)
    kept = rules[:name].dup
    eval(File.read(File.join(Harness::ROOT, "games/rejuvenation/opportunity_skip.rb")))
    skip = place(57, 87, 35, "EV057", 0, "object_opportunityskip")
    assert_equal "{rjd_opportunity_skip}", PokeAccess::Locator.ruled_name(skip)
    assert_nil PokeAccess::Locator.ruled_name(place(58, 88, 35, "EV058", 0, "object_monitor4"))
  ensure
    rules[:name] = kept if rules
  end

  private

  # Makes I18n.t answer each key and its values as "{key name=value ...}", so what the puzzles say is compared by its
  # keys and values rather than by the text of a language.
  def keyed
    i18n = PokeAccess::I18n.singleton_class
    i18n.send(:alias_method, :rjd_kept_t, :t)
    i18n.send(:define_method, :t) do |key, vars = nil|
      parts = [key.to_s] + (vars || {}).map { |k, v| "#{k}=#{v}" }.sort
      "{#{parts.join(' ')}}"
    end
  end

  # Gives I18n.t back its own body.
  def unkeyed
    i18n = PokeAccess::I18n.singleton_class
    i18n.send(:alias_method, :t, :rjd_kept_t)
    i18n.send(:remove_method, :rjd_kept_t)
  end

  def fire(ev)
    PokeAccess::Puzzles::Auto.fired($game_system.map_interpreter, PokeAccess.ivar(ev, :@list), ev.id)
  end

  # The option right_choice picks of a menu on event id, its page made of the options and each one's commands.
  def option(int, id, options, branches)
    list = [TestCmd.new(102, [options, 2], 0)]
    branches.each_with_index do |cmds, i|
      list.push(TestCmd.new(402, [i, options[i]], 0))
      list.concat(cmds)
      list.push(TestCmd.new(0, [], 1))
    end
    list.push(TestCmd.new(404, [], 0))
    page = TestPage.new(:trigger => 0, :sprite => "object_sakistatue", :list => list)
    $game_map.events[id] = TestGameEvent.new(:id => id, :x => 59, :y => 75, :pages => [page], :active_page => page)
    World.next_frame
    int.instance_variable_set(:@event_id, id)
    PokeAccess::Puzzles::Answers.right_option(int, list, 0)
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
