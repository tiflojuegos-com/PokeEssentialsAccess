# Pokemon Rejuvenation's smaller puzzles of the rj2 review (games/rejuvenation/puzzles/): Jirukala's interface, the
# Phasial Cave's dark field, Route 1's Exploud, the Strange House's hook, the Growlithe and Espurr walks, the Wispy
# Ruins' boulder and Magrodar's night rocks and springs. Without the assist, what the screen shows; with it, the way.
class RejuvenationReviewRj2Test < PokeAccessTest
  SWITCHES = [93, 320, 347, 476]
  VARS = [28, 313, 532, 533, 538, 539, 588, 932]

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
    PokeAccess::Puzzles::Answers.forget
    PokeAccess::World::Mechanics.forget
    PokeAccess::Caches.reset_all
    unkeyed
    super
  end

  test "Jirukala's interface is listed until it opens, and the code its page compares is said with the assist alone" do
    on_map(211, 54, 36)
    list = [TestCmd.new(122, [28, 28, 0, 0, 0]), TestCmd.new(101, ["It's an interface. It looks like it's waiting"]),
            TestCmd.new(401, ["for an input..."]), TestCmd.new(103, [28, 4]), TestCmd.new(111, [1, 28, 0, 9867, 0]),
            TestCmd.new(101, ["OPEN."], 1), TestCmd.new(122, [313, 313, 0, 0, 4], 1), TestCmd.new(0, [], 1),
            TestCmd.new(411), TestCmd.new(101, ["ERROR! ERROR!"], 1), TestCmd.new(0, [], 1), TestCmd.new(412),
            TestCmd.new(0)]
    ev = place(34, 54, 35, "EV034", 0, "", list)
    assert_equal "{rj_jirukala_interface}", PokeAccess::Puzzles.piece_name(ev)
    assert_includes listed, [54, 35, "{rj_jirukala_interface}"]
    assert_nil answer_after(list, 1, 34)
    PokeAccess::Config.puzzle_assist = true
    assert_equal "{puzzle_answer a=9867}", answer_after(list, 1, 34)
    $game_variables[313] = 4
    refute(listed.any? { |_x, _y, name| name == "{rj_jirukala_interface}" })
  end

  test "the Phasial Cave tells its dark field with the assist, and the move to the dark cave to anyone" do
    on_map(116, 30, 30)
    refute_includes info_key, "rj_phasial"
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, "{rj_phasial_dark_hint}"
    on_map(570, 30, 30)
    assert_equal "{rj_phasial_turned_dark}", PokeAccess::Puzzles.sent_back_line([30, 30, 116], [30, 30, 570], :map)
    assert_nil PokeAccess::Puzzles.sent_back_line([30, 30, 97], [30, 30, 570], :map)
  end

  test "Route 1's Exploud is named and sees four tiles, and the assist tells what waking it brings" do
    on_map(5, 28, 33)
    exploud = place(29, 28, 28, "Trainer(4)", 2, "pkmn_exploud")
    assert_equal "{rj_exploud}", PokeAccess::Puzzles.piece_name(exploud)
    seen = {}
    PokeAccess::Routes::Sight.watchers.each { |w| seen[w.rec.id] = w.range }
    assert_equal 4, seen[29]
    refute_includes info_key, "rj_exploud_"
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, "{rj_exploud_hint}"
    $game_switches[93] = true
    assert_includes info_key, "{rj_exploud_awake_hint}"
  end

  test "the Strange House's hook is named by its live page, and the assist asks for the portrait while it waits" do
    on_map(560, 32, 15)
    hook = place(19, 32, 14, "EV019")
    assert_equal "{rj_hook}", PokeAccess::Puzzles.piece_name(hook)
    assert_includes listed, [32, 14, "{rj_hook}"]
    PokeAccess::Config.puzzle_assist = true
    refute_includes info_key, "{rj_hook_hint}"
    $game_variables[588] = 8
    assert_includes info_key, "{rj_hook_hint}"
    $game_variables[588] = 9
    assert_equal "{rj_hook_portrait}", PokeAccess::Puzzles.piece_name(hook)
    refute(listed.any? { |x, y, _name| [x, y] == [32, 14] })
    refute_includes info_key, "{rj_hook_hint}"
    $game_variables[932] = 9
    assert_equal "{rj_hook}", PokeAccess::Puzzles.piece_name(hook), "Venam takes the painting down: page 3"
    assert_includes info_key, "{rj_hook_hint}"
    $game_variables[932] = 11
    $game_variables[588] = 0
    assert_equal "{rj_hook_portrait}", PokeAccess::Puzzles.piece_name(hook), "page 4 draws it whatever 588 holds"
    refute_includes info_key, "{rj_hook_hint}"
  end

  test "Growlithe's friendship is counted with the assist up to a thousand, and a walk's end is said" do
    on_map(210, 49, 12)
    $game_variables[538] = 1200
    refute_includes info_key, "rj_growlithe"
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, "{puzzle_progress label={rj_growlithe_friendship} n=1000 of=1000}"
    edge = place(41, 49, 9, "EV041", 1)
    PokeAccess::Puzzles::Auto.fired($game_system.map_interpreter, PokeAccess.ivar(edge, :@list), edge.id)
    assert_equal "{rj_growlithe_walk_over}", PokeAccess::Puzzles.sent_back_line([49, 8, 210], [49, 9, 210])
    assert_nil PokeAccess::Puzzles.sent_back_line([49, 8, 210], [49, 12, 210])
    $game_variables[539] = 3
    refute_includes info_key, "rj_growlithe"
  end

  test "Espurr's friendship is counted with the assist alone, up to a thousand, until it joins" do
    on_map(95, 30, 30)
    $game_variables[532] = 640
    refute_includes info_key, "rj_espurr"
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, "{puzzle_progress label={rj_espurr_friendship} n=640 of=1000}"
    $game_variables[533] = 3
    refute_includes info_key, "rj_espurr"
  end

  test "the Wispy Ruins' boulder is followed, and with the assist to the tile that opens the door, until it opens" do
    on_map(489, 61, 62)
    place(79, 61, 61, "Boulder", 1, "Object boulder")
    assert_equal "{puzzle_track_rel dist=1 {dir_up} label={rjd_wr_boulder}}", info_key
    refute(listed.any? { |_x, _y, name| name == "{rjd_wr_goal}" })
    PokeAccess::Config.puzzle_assist = true
    assert_includes listed, [55, 56, "{rjd_wr_goal}"]
    assert_equal "{puzzle_track_goal dist=6 {dir_left}, 5 {dir_up} goal={rjd_wr_goal} label={rjd_wr_boulder}}", info_key
    $game_switches[320] = true
    refute_includes info_key, "rjd_wr_"
    refute(listed.any? { |_x, _y, name| name == "{rjd_wr_goal}" })
  end

  test "Magrodar's night rocks are named with the assist alone, and its springs while they still throw" do
    on_map(213, 46, 70)
    rock = place(1, 46, 68, "EV001", 0, "Object boulder")
    spring = place(6, 22, 47, "EV006", 1, "", nil, 1500)
    assert_nil PokeAccess::Puzzles.piece_name(rock)
    assert_equal "{rj_magrodar_spring}", PokeAccess::Puzzles.piece_name(spring)
    assert_includes listed, [22, 47, "{rj_magrodar_spring}"]
    refute_includes info_key, "rj_night_rock_hint"
    PokeAccess::Config.puzzle_assist = true
    assert_equal "{rj_night_rock}", PokeAccess::Puzzles.piece_name(rock)
    assert_includes listed, [46, 68, "{rj_night_rock}"]
    assert_includes info_key, "{rj_night_rock_hint}"
    $game_switches[476] = true
    refute(listed.any? { |_x, _y, name| name == "{rj_magrodar_spring}" })
  end

  private

  # Makes I18n.t answer each key and its values as "{key name=value ...}", so what the puzzles say is compared by its
  # keys and values rather than by the text of a language.
  def keyed
    i18n = PokeAccess::I18n.singleton_class
    i18n.send(:alias_method, :rj2_kept_t, :t)
    i18n.send(:define_method, :t) do |key, vars = nil|
      parts = [key.to_s] + (vars || {}).map { |k, v| "#{k}=#{v}" }.sort
      "{#{parts.join(' ')}}"
    end
  end

  # Gives I18n.t back its own body.
  def unkeyed
    i18n = PokeAccess::I18n.singleton_class
    i18n.send(:alias_method, :t, :rj2_kept_t)
    i18n.send(:remove_method, :rj2_kept_t)
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

  def place(id, x, y, name, trigger = 0, sprite = "", list = nil, tile = 0)
    page = TestPage.new(:trigger => trigger, :sprite => sprite,
                        :list => list || [TestCmd.new(101, ["text"]), TestCmd.new(0, [])])
    ev = TestGameEvent.new(:id => id, :x => x, :y => y, :name => name, :pages => [page], :active_page => page,
                           :tile_id => tile)
    $game_map.events[id] = ev
    World.next_frame
    ev
  end

  # What the assist says after the Show Text at list[i] of event id's page, for the menu or entry that follows it.
  def answer_after(list, i, id)
    int = Object.new
    { :@list => list, :@index => i, :@event_id => id }.each { |k, v| int.instance_variable_set(k, v) }
    PokeAccess::Puzzles::Answers.forget
    PokeAccess.take_tail
    PokeAccess::Puzzles::Answers.before_text(int)
    PokeAccess.take_tail
  end

  def info_key
    PokeAccess::Info.map_text.to_s
  end

  def listed
    PokeAccess::Puzzles.category_targets.select { |tg| tg.is_a?(PokeAccess::Locator::SurfaceTarget) }
                       .map { |tg| [tg.x, tg.y, tg.name] }
  end
end
