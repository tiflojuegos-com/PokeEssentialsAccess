# Insurgence's puzzles found in the review (games/insurgence/puzzles/: league_pathway, samsara_cave, relic_song) on the
# shipped profile over events shaped like the game's: what a seeing player hears of the floor switch under the Giratina
# statue, the Pidgeotto statue with a button and the Relic Song notes, and what the puzzle assist adds.
class InsurgenceRepasoTest < PokeAccessTest
  MAPS = [771, 172, 174, 447, 455, 22, 400, 808]
  KEYS = %w[ins_league_statue_moved ins_league_switch ins_league_switch_hint ins_league_door_open ins_samsara_statue
            ins_samsara_statue_hint ins_samsara_rift_hint ins_samsara_entrance ins_o2_rift ins_relic_note ins_relic_room
            ins_relic_portal ins_relic_cave ins_relic_items]
  SWITCHES = [152, 591, 592, 629, 635]

  class << self
    attr_accessor :declared
  end

  def setup
    super
    @defs = mechanics.instance_variable_get(:@defs).dup
    @map = $game_map.map_id
    @selfs = $game_self_switches
    @at = [$game_player.x, $game_player.y]
    table = PokeAccess::I18n.table(PokeAccess::I18n.lang)
    KEYS.each { |k| table[k] ||= k }
    table["ins_relic_note_hint"] ||= "ins_relic_note_hint %{what}"
  end

  def teardown
    World.clear_events
    SWITCHES.each { |i| $game_switches[i] = false }
    $game_variables[142] = 0
    $game_player.x, $game_player.y = @at
    $game_self_switches = @selfs
    mechanics.instance_variable_set(:@defs, @defs)
    $game_map.map_id = @map
    PokeAccess::Config.puzzle_assist = false
    mechanics.forget
    PokeAccess::Puzzles::Auto.forget
    PokeAccess::Caches.reset_all
    super
  end

  test "the league hall says the statue moved once it is on screen, lists the switch once the four are beaten, then the door" do
    stand(20, 3)
    $game_variables[142] = 3
    on_map(771)
    assert_equal [], frame
    assert_equal [], listed
    $game_variables[142] = 4
    on_map(771)
    assert_equal [], frame, "back from the Elite Four at the north end the statue is off screen"
    assert_equal [[20, 17, t(:ins_league_switch)]], listed
    assert PokeAccess::Puzzles.onto?(PokeAccess::Puzzles.category_targets[0]), "the switch is stepped on"
    refute PokeAccess::Puzzles::Auto.on_here?
    stand(20, 10)
    assert_equal [], frame
    stand(20, 11)
    assert_equal [t(:ins_league_statue_moved)], frame, "said as the arch brings it on screen"
    stand(20, 16)
    assert_equal [], frame
    $game_switches[635] = true
    assert_equal [t(:ins_league_door_open)], frame
    assert_equal [], listed
    on_map(771)
    assert_equal [], frame, "the door open, coming back says nothing"
  end

  test "the league hall says the statue on arriving in sight of it, and the way to the Champion is the assist's alone" do
    $game_variables[142] = 4
    stand(15, 13)
    on_map(771)
    assert_equal [t(:ins_league_statue_moved)], frame
    stand(20, 3)
    on_map(771)
    PokeAccess::Config.puzzle_assist = true
    assert_equal [t(:ins_league_switch_hint)], frame, "off screen the assist says the way alone"
    assert_includes info_key.to_s, t(:ins_league_switch_hint)
    stand(20, 12)
    assert_equal ["#{t(:ins_league_statue_moved)}. #{t(:ins_league_switch_hint)}"], frame
    PokeAccess::Config.puzzle_assist = false
    refute_includes info_key.to_s, t(:ins_league_switch_hint)
  end

  test "the Pidgeotto statue with a button is named by its drawing, its entrance said, its Yes with the assist" do
    on_map(172)
    statue = event(3, 46, 39, [page("pidgeotto_right_button", 0, button_menu)])
    rift = event(17, 48, 39, [page("", 4, [TestCmd.new(108, ["Particle Engine Type"]), TestCmd.new(0, [])])])
    assert_equal [[46, 39, t(:ins_samsara_statue)]], listed, "the rift is not drawn before switch 152"
    $game_switches[152] = true
    assert_equal [[46, 39, t(:ins_samsara_statue)], [48, 39, t(:ins_o2_rift)]], listed
    PokeAccess::Config.puzzle_assist = true
    assert_equal [[46, 39, t(:ins_samsara_statue_hint)], [48, 39, t(:ins_samsara_rift_hint)]], listed
    assert_equal "Yes", right_option(statue)
    $game_self_switches[[172, rift.id, "A"]] = true
    assert_equal [[46, 39, t(:ins_samsara_statue_hint)]], listed
    PokeAccess::Config.puzzle_assist = false
    refute PokeAccess::Puzzles::Auto.on_here?
    assert_equal [], frame
    $game_switches[629] = true
    assert_equal [t(:ins_samsara_entrance)], frame
    assert_equal [], listed
  end

  test "a Relic Song note is listed while its first page is live, and the assist says the range and what it opens" do
    on_map(174)
    used = page("", 3, [TestCmd.new(201, [0, 787, 21, 25, 8, 0]), TestCmd.new(0, [])])
    note = event(46, 52, 16, [page("", 0, [TestCmd.new(0, [])]), used])
    assert PokeAccess::Puzzles::Auto.on_here?
    assert_equal [[52, 16, t(:ins_relic_note)]], listed
    PokeAccess::Config.puzzle_assist = true
    hint = t(:ins_relic_note_hint, :what => t(:ins_relic_room))
    assert_equal [[52, 16, hint]], listed
    $game_map.events[46] = TestGameEvent.new(:id => 46, :x => 52, :y => 16, :name => note.name,
                                             :pages => PokeAccess.ivar(note, :@event).pages, :active_page => used)
    assert_equal [], listed
  end

  test "the Relic Song notes keep the maps' other puzzles, the one that talks is named, and those whose work stays go" do
    on_map(455)
    event(50, 70, 38, [page("", 0, [TestCmd.new(0, [])])], "Music_Note_Relic")
    event(51, 24, 38, [page("", 0, [TestCmd.new(0, [])])], "Music_Note_Relic")
    event(18, 65, 22, [page("", 0, [TestCmd.new(101, ["..."]), TestCmd.new(0, [])])])
    names = listed.map { |_x, _y, n| n }
    assert_equal [t(:ins_relic_note), t(:ins_relic_note), t(:ins_o2_rod)].sort, names.sort
    on_map(447)
    event(14, 40, 61, [page("", 0, [TestCmd.new(101, ["It's an ancient, mystical rock."]), TestCmd.new(0, [])])])
    assert_equal [[40, 61, t(:ins_relic_note)]], listed
    [[22, 9, 29, 23, 591, :ins_relic_items], [400, 28, 30, 21, 592, :ins_relic_cave]].each do |map, id, x, y, done, opens|
      on_map(map)
      event(id, x, y, [page("", 0, [TestCmd.new(0, [])])], "Music_Note_Relic")
      PokeAccess::Config.puzzle_assist = true
      assert_equal [[x, y, t(:ins_relic_note_hint, :what => t(opens))]], listed
      $game_switches[done] = true
      assert_equal [], listed, "map #{map}: what it opened stays, though the note is back on its first page"
    end
    on_map(808)
    event(4, 60, 30, [page("", 0, [TestCmd.new(0, [])])], "Music_Note_Relic")
    PokeAccess::Config.puzzle_assist = true
    assert_equal [], listed, "the song never reaches map 808's note"
  end

  private

  def t(*args); PokeAccess::I18n.t(*args); end

  def mechanics; PokeAccess::World::Mechanics; end

  def stand(x, y)
    $game_player.x = x
    $game_player.y = y
  end

  def declare_puzzles
    self.class.declared ||= begin
      Harness.load_puzzles("insurgence")
      all = mechanics.instance_variable_get(:@defs)
      MAPS.map { |map| [map, all[map]] }
    end
    defs = mechanics.instance_variable_get(:@defs)
    self.class.declared.each { |map, list| defs[map] = list }
  end

  def on_map(map)
    declare_puzzles
    PokeAccess::Config.puzzle_assist = false
    World.clear_events
    $game_self_switches = {}
    $game_map.map_id = map
    PokeAccess::Caches.reset_all
    mechanics.forget
    PokeAccess::Puzzles::Auto.forget
  end

  def page(sprite, trigger, list)
    TestPage.new(:trigger => trigger, :sprite => sprite, :list => list)
  end

  def event(id, x, y, pages, name = "EV#{id}")
    ev = TestGameEvent.new(:id => id, :x => x, :y => y, :name => name, :pages => pages)
    $game_map.events[id] = ev
    World.next_frame
    ev
  end

  # The statue's page: its texts, then Yes turning switch 629 on and No doing nothing.
  def button_menu
    [TestCmd.new(101, ["There's a small button on it- would you like to press it?"]), TestCmd.new(102, [%w[Yes No], 2]),
     TestCmd.new(402, [0, "Yes"]), TestCmd.new(121, [629, 629, 0], 1), TestCmd.new(0, [], 1),
     TestCmd.new(402, [1, "No"]), TestCmd.new(0, [], 1), TestCmd.new(404, []), TestCmd.new(0, [])]
  end

  # The option the assist names of the event's menu, its page running on the map's interpreter.
  def right_option(ev)
    list = PokeAccess.ivar(ev, :@list)
    int = $game_system.map_interpreter
    was = PokeAccess.ivar(int, :@event_id)
    int.instance_variable_set(:@event_id, ev.id)
    PokeAccess::Puzzles::Answers.right_option(int, list, 1)
  ensure
    int.instance_variable_set(:@event_id, was) if int
  end

  def info_key; PokeAccess::Info.map_text; end

  def frame
    SpeakCapture.clear
    PokeAccess::Puzzles.tick
    SpeakCapture.lines
  end

  def listed
    PokeAccess::Puzzles.category_targets.map { |tg| [tg.x, tg.y, tg.is_a?(PokeAccess::Locator::SurfaceTarget) ? tg.name : PokeAccess::Locator.target_name(tg)] }.sort_by { |x, y, _n| [x, y] }
  end
end
