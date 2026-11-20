# Awakening's shrine and tower puzzles on the shipped profile: the turning statues and their plan, the statues pushed
# onto marks, the light currents, the arrow mazes, the lights of the Gates of Hell and the floor of the Empyrean's
# floor 16. What a sighted player sees goes without the assist; the answer, with it.
class AwakeningPuzzlesTest < PokeAccessTest
  # Each turning room's statues as the maps place them: [id, x, y, facing].
  CROSS_336 = [[2, 9, 11, 8], [3, 5, 15, 4], [4, 13, 15, 6], [5, 9, 19, 4]]
  ROOMS = {
    336 => [CROSS_336, 2],
    339 => [[[2, 13, 15, 8], [3, 9, 19, 8], [4, 9, 11, 6], [5, 5, 15, 4]], 4],
    515 => [CROSS_336, 2],
    374 => [[[3, 17, 10, 2], [4, 13, 14, 4], [5, 9, 10, 4], [6, 13, 6, 8]], 8],
    376 => [[[4, 17, 10, 2], [5, 13, 14, 6], [6, 9, 10, 2], [7, 13, 6, 4]], 2],
    343 => [[[1, 7, 7, 8], [2, 4, 7, 2], [3, 10, 7, 2], [6, 8, 28, 8], [7, 10, 26, 8], [8, 5, 28, 8], [9, 6, 26, 2],
             [10, 11, 28, 2]], 2]
  }

  test "every turning room's plan, used as said, leaves all its statues facing the room's way" do
    ROOMS.each do |map, (statues, goal)|
      on_map(map)
      turns = PokeAccess::AwakeningTurns
      statues.each { |id, x, y, d| statue(id, x, y, d) }
      steps = turns.plan(map, turns.facings(map))
      refute_nil steps, "map #{map} has a plan"
      steps.each { |id, n| n.times { use(map, id) } }
      assert_equal [goal], turns.facings(map).values.uniq, "map #{map}"
    end
  end

  # One use per room as its .rxdata turns it: [map, statue used, [[number, facing after], ...]], numbers in reading order.
  USES = [[336, 3, [[2, 2], [3, 8], [4, 2]]], [339, 2, [[3, 4], [4, 4]]], [515, 2, [[1, 4], [2, 2]]],
          [374, 4, [[2, 2], [4, 2]]], [376, 7, [[1, 2], [4, 8]]], [343, 8, [[4, 8], [6, 2]]]]

  test "a use of each turning room says the facings the game's own move routes leave" do
    faces = { 2 => "{face_south}", 4 => "{face_west}", 6 => "{face_east}", 8 => "{face_north}" }
    keyed do
      USES.each do |map, id, turned|
        on_map(map)
        ROOMS[map][0].each { |sid, x, y, d| statue(sid, x, y, d) }
        expected = turned.map { |n, d| "{awk_statue_n n=#{n}}: #{faces[d]}" }
        assert_equal PokeAccess.sentences(expected), PokeAccess::AwakeningTurns.after_use(map, id), "map #{map}"
      end
    end
  end

  test "using a statue says its line once, with nothing more from the core while no wall changes" do
    on_map(336)
    CROSS_336.each { |id, x, y, d| statue(id, x, y, d) }
    tick
    PokeAccess::Puzzles::Auto.fired($game_system.map_interpreter, PokeAccess.ivar($game_map.events[3], :@list), 3)
    said = (1..8).map { tick }.flatten(1).map { |line, _| line }
    assert_equal [PokeAccess::AwakeningTurns.after_use(336, 3)], said
  end

  test "the Wind shrine's slabs count as solved by either self switch of the parallel check" do
    keyed do
      on_map(287)
      assert_equal 11, listed.count("{awk_floor_mark}")
      $game_self_switches[[287, 17, "B"]] = true
      assert PokeAccess::AwakeningMarks.won?(287)
      assert_equal 0, listed.count("{awk_floor_mark}")
    end
  end

  test "the wind symbols are listed by their tiles without the wind magic, and their way with the assist" do
    keyed do
      on_map(287)
      assert_equal 4, listed.count("{awk_wind_symbol}")
      PokeAccess::Config.puzzle_assist = true
      assert_equal ["{awk_wind_symbol_way dir={face_north}}"] * 2 + ["{awk_wind_symbol_way dir={face_south}}"] * 2,
                   listed.grep(/awk_wind_symbol/).sort
      on_map(275)
      PokeAccess::Config.puzzle_assist = true
      assert_equal ["{awk_wind_symbol_way dir={face_east}}", "{awk_wind_symbol_way dir={face_west}}"],
                   listed.grep(/awk_wind_symbol/).sort
    end
  end

  test "Combretum's hints wait for the mountain to open" do
    on_map(47)
    PokeAccess::Config.puzzle_assist = true
    $game_variables[130] = 3
    refute_includes info_key.to_s, t(:awk_comb_lever_hint)
    $game_variables[130] = 4
    assert_includes info_key, t(:awk_comb_lever_hint)
  end

  test "using a statue of the west room says where each statue it turns faces, and the uses left with the assist" do
    on_map(336)
    CROSS_336.each { |id, x, y, d| statue(id, x, y, d) }
    said = PokeAccess::AwakeningTurns.after_use(336, 3)
    assert_equal PokeAccess.sentences(["#{t(:awk_statue_n, :n => 2)}: #{t(:face_south)}",
                                       "#{t(:awk_statue_n, :n => 3)}: #{t(:face_north)}",
                                       "#{t(:awk_statue_n, :n => 4)}: #{t(:face_south)}"]), said
    PokeAccess::Config.puzzle_assist = true
    plan = t(:awk_turn_plan, :list => "#{t(:awk_turn_times, :name => t(:awk_statue_n, :n => 2), :n => 3)}, " \
                                       "#{t(:awk_turn_times, :name => t(:awk_statue_n, :n => 4), :n => 2)}")
    assert_includes info_key, plan
    assert_includes PokeAccess::AwakeningTurns.after_use(336, 3),
                    t(:awk_turn_plan, :list => "#{t(:awk_turn_times, :name => t(:awk_statue_n, :n => 2), :n => 2)}, " \
                                               "#{t(:awk_turn_times, :name => t(:awk_statue_n, :n => 4), :n => 2)}")
  end

  test "the west room's info key gives the facings alone without the assist, and nothing once the way is open" do
    on_map(336)
    CROSS_336.each { |id, x, y, d| statue(id, x, y, d) }
    line = info_key
    assert_includes line, "#{t(:awk_statue_n, :n => 1)}: #{t(:face_north)}"
    refute_includes line, t(:awk_turn_plan, :list => "").sub(/\.\z/, "")
    $game_switches[209] = true
    assert_nil PokeAccess::AwakeningTurns.after_use(336, 3)
    refute PokeAccess::Puzzles.active?
  end

  test "the Water shrine's statues are named, their marks listed, and with the assist each goes to its own mark" do
    on_map(219)
    [[7, 27, 32], [8, 35, 32], [9, 35, 30], [10, 27, 30]].each { |id, x, y| statue(id, x, y, 2, "Tetas estatua") }
    names = listed
    assert_equal 4, names.count(t(:awk_floor_mark))
    assert_includes names, t(:awk_statue_n, :n => 4)
    refute_includes info_key.to_s, t(:awk_mark_hint, :name => t(:awk_statue_n, :n => 1), :x => 29, :y => 34)
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, t(:awk_mark_hint, :name => t(:awk_statue_n, :n => 1), :x => 29, :y => 34)
    move(7, 29, 34)
    assert_includes info_key, t(:awk_mark_hint, :name => t(:awk_statue_n, :n => 2), :x => 33, :y => 34)
    $game_self_switches[[219, 11, "A"]] = true
    refute PokeAccess::Puzzles.active?
  end

  test "the Wind shrine's first two slabs take each other's mark once the player starts them that way" do
    on_map(287)
    [[1, 48, 7], [2, 50, 8], [3, 52, 8], [4, 54, 7], [5, 51, 10]].each { |id, x, y| statue(id, x, y, 2, "baldosa viento 1") }
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, t(:awk_mark_hint, :name => t(:awk_slab_n, :n => 1), :x => 51, :y => 20)
    move(2, 51, 20)
    assert_includes info_key, t(:awk_mark_hint, :name => t(:awk_slab_n, :n => 1), :x => 56, :y => 12)
  end

  test "a light current out with its way open says how to light it again, with the assist alone" do
    on_map(220)
    $game_self_switches[[219, 2, "A"]] = true
    go(34, 10)
    World.next_frame
    assert PokeAccess::AwakeningLight.out?
    refute_includes info_key.to_s, t(:awk_light_relight)
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, t(:awk_light_relight)
    $game_switches[115] = true
    assert PokeAccess::AwakeningLight.lit?
    refute PokeAccess::AwakeningLight.out?
    $game_self_switches[[220, 1, "A"]] = true
    refute PokeAccess::AwakeningLight.lit?
  end

  test "an arrow of the mazes is said as drawn, and the blue ones' way on is the other way, with the assist alone" do
    on_map(341)
    orange = statue(7, 7, 27, 4, "Flechas")
    blue = statue(12, 7, 7, 6, "Flechas")
    blue.instance_variable_set(:@original_pattern, 1)
    assert_equal t(:awk_arrow, :color => t(:awk_arrow_orange), :dir => t(:face_east)), PokeAccess::AwakeningArrows.label(orange)
    assert_equal t(:awk_arrow, :color => t(:awk_arrow_blue), :dir => t(:face_south)), PokeAccess::AwakeningArrows.label(blue)
    PokeAccess::Config.puzzle_assist = true
    assert_equal PokeAccess.sentences([t(:awk_arrow, :color => t(:awk_arrow_blue), :dir => t(:face_south)),
                                       t(:awk_arrow_way, :dir => t(:face_north))]), PokeAccess::AwakeningArrows.label(blue)
  end

  test "a fall in the Fire shrine's first maze says it, and walking out the maze's way in says nothing" do
    on_map(324)
    assert_equal t(:awk_maze_fall), PokeAccess::Puzzles.sent_back_line([3, 28, 334], [30, 39, 324], :map)
    assert_equal t(:awk_maze_fall), PokeAccess::Puzzles.sent_back_line([52, 13, 334], [30, 39, 324], :map)
    assert_nil PokeAccess::Puzzles.sent_back_line([8, 4, 334], [30, 39, 324], :map)
  end

  test "the Gates of Hell give the next light by the riddle's order, and a lost round, with the assist alone" do
    on_map(555)
    $game_variables[385] = 0
    $game_variables[386] = 0
    refute_includes info_key.to_s, t(:awk_purg_next, :name => t(:awk_purg_light_ne))
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, t(:awk_purg_next, :name => t(:awk_purg_light_ne))
    $game_variables[385] = 2
    $game_variables[386] = 3
    assert_includes info_key, t(:awk_purg_next, :name => t(:awk_purg_light_nw))
    $game_variables[386] = 2
    assert_includes info_key, t(:awk_purg_lost)
    $game_switches[710] = true
    refute PokeAccess::Puzzles.active?
  end

  test "floor 16 of the Empyrean says how to start over after a tile off the way, with the assist alone" do
    on_map(482)
    $game_switches[448] = true
    refute_includes info_key.to_s, t(:awk_p16_failed)
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, t(:awk_p16_failed)
    $game_switches[449] = true
    refute PokeAccess::Puzzles.active?
  end

  test "Combretum's lever room says the step on the way to the inscriptions, with the assist alone" do
    on_map(47)
    $game_variables[130] = 5
    refute_includes info_key.to_s, t(:awk_comb_lever_hint)
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, t(:awk_comb_lever_hint)
    $game_switches[71] = true
    assert_includes info_key, t(:awk_comb_glow_far)
    $game_switches[78] = true
    assert_includes info_key, t(:awk_comb_exit_hint)
    $game_variables[130] = 6
    refute_includes info_key.to_s, t(:awk_comb_exit_hint)
  end

  test "the torches floor of Combretum says where the inscriptions are and how to cross back east" do
    on_map(46)
    $game_variables[130] = 5
    PokeAccess::Config.puzzle_assist = true
    go(7, 10)
    assert_includes info_key, t(:awk_comb_west_hint)
    $game_switches[78] = true
    assert_includes info_key, t(:awk_comb_back_hint)
    go(30, 15)
    assert_includes info_key, t(:awk_comb_east_hint)
  end

  test "the mines name their lit grapple rocks, and the throw tiles with the assist while the grapple is held" do
    on_map(136)
    rock = TestPage.new(:trigger => 0, :sprite => "Brillo", :list => [TestCmd.new(0, [])])
    $game_map.events[9] = TestGameEvent.new(:id => 9, :x => 14, :y => 49, :name => "Roca 3", :pages => [rock], :active_page => rock)
    throw = TestPage.new(:trigger => 1, :sprite => "", :list => [TestCmd.new(111, []), TestCmd.new(0, [])])
    $game_map.events[13] = TestGameEvent.new(:id => 13, :x => 16, :y => 49, :pages => [throw], :active_page => throw)
    World.next_frame
    assert_includes listed, t(:awk_hook_rock)
    PokeAccess::Config.puzzle_assist = true
    refute_includes listed, t(:awk_hook_throw, :dir => t(:face_east))
    grapple = PokeAccess::AwakeningGrapple
    class << grapple
      alias_method :held_before_test, :held?
      def held?; true; end
    end
    World.next_frame
    assert_includes listed, t(:awk_hook_throw, :dir => t(:face_east))
  ensure
    if defined?(grapple) && grapple
      class << grapple
        alias_method :held?, :held_before_test
      end
    end
  end

  def teardown
    $game_self_switches = @selfs_before if defined?(@selfs_before)
    super
  end

  private

  def t(key, vars = nil)
    PokeAccess::I18n.t(key, vars)
  end

  # Runs the block with I18n.t answering each key and its values as "{key name=value ...}", so what the puzzles say is
  # compared by its keys and values rather than by the text of a language.
  def keyed
    i18n = PokeAccess::I18n.singleton_class
    i18n.send(:alias_method, :awk_kept_t, :t)
    i18n.send(:define_method, :t) do |key, vars = nil|
      parts = [key.to_s] + (vars || {}).map { |k, v| "#{k}=#{v}" }.sort
      "{#{parts.join(' ')}}"
    end
    yield
  ensure
    i18n.send(:alias_method, :t, :awk_kept_t)
    i18n.send(:remove_method, :awk_kept_t)
  end

  def on_map(map)
    Harness.load_puzzles("awakening")
    PokeAccess::Config.puzzle_assist = false
    $game_map.map_id = map
    $game_map.events.clear
    [71, 78, 115, 209, 212, 432, 448, 449, 710].each { |s| $game_switches[s] = false }
    @selfs_before = $game_self_switches unless defined?(@selfs_before)
    $game_self_switches = {}
    go(1, 1)
    World.next_frame
  end

  def statue(id, x, y, dir, sprite = "Tetas estatua")
    page = TestPage.new(:trigger => 0, :sprite => sprite, :list => [TestCmd.new(209, []), TestCmd.new(0, [])])
    ev = TestGameEvent.new(:id => id, :x => x, :y => y, :pages => [page], :active_page => page)
    ev.direction = dir
    $game_map.events[id] = ev
    World.next_frame
    ev
  end

  def go(x, y)
    $game_player.x = x
    $game_player.y = y
  end

  def move(id, x, y)
    ev = $game_map.events[id]
    ev.x = x
    ev.y = y
    World.next_frame
  end

  def use(map, id)
    q, links, = PokeAccess::AwakeningTurns::ROOMS[map]
    links[id].each do |t|
      ev = $game_map.events[t]
      ev.direction = PokeAccess::AwakeningTurns.turn(ev.direction, q)
    end
  end

  def tick
    SpeakCapture.clear
    PokeAccess::Puzzles.tick
    SpeakCapture.log.dup
  end

  def listed
    PokeAccess::Puzzles.category_targets.map { |tg| tg.name }
  end

  def info_key
    PokeAccess::Info.map_text
  end
end
