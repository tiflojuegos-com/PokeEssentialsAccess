# Dark Horizon's puzzles as the review of its events left them (games/darkhorizon/puzzles/), over events shaped like the game's:
# the rock face with the Tyranitar head that hides the way into Obscura Lab, the crates over the storeroom's journal page in
# Mirage Mansion, the laser before the Shadow Lab's far door and the Gateon Port bridge pieces that only rearm the sensors.
# What is heard without the puzzle assist is what the room shows; the answers come with it. Gamedata pass.
class DarkhorizonRepasoGdTest < PokeAccessTest
  MAPS = [23, 105, 138, 151]
  SWITCHES = [117, 142, 181, 183, 186]
  BARE = 999
  TEMPLATES = { "dh_pz_tyranitar_wall" => "tyranitar wall", "dh_pz_tyranitar_hint" => "tyranitar hint",
                "dh_pz_tyranitar_hint_near" => "tyranitar hint near",
                "dh_pz_crates" => "crates", "dh_pz_storeroom_page" => "storeroom page" }

  class << self
    attr_accessor :declared
  end

  def setup
    super
    @defs = mechanics.instance_variable_get(:@defs).dup
    @map = $game_map.map_id
    @selfs = $game_self_switches
    @x = $game_player.x
    @y = $game_player.y
    table = PokeAccess::I18n.table(PokeAccess::I18n::REFERENCE)
    @stubbed = TEMPLATES.keys.reject { |key| table.key?(key) }
    @stubbed.each { |key| table[key] = TEMPLATES[key] }
  end

  def teardown
    World.clear_events
    SWITCHES.each { |i| $game_switches[i] = false }
    $game_variables[31] = 0
    $game_self_switches = @selfs
    $game_player.x = @x
    $game_player.y = @y
    mechanics.instance_variable_set(:@defs, @defs)
    $game_map.map_id = @map
    PokeAccess::Config.puzzle_assist = false
    mechanics.forget
    PokeAccess::Caches.reset_all
    table = PokeAccess::I18n.table(PokeAccess::I18n::REFERENCE)
    @stubbed.each { |key| table.delete(key) }
    super
  end

  test "the rock face is named by the carved head while shut and keeps its own name once open, and the way in comes with the assist" do
    on_map(23)
    stand(22, 45)
    wall = tyranitar_wall
    assert_equal [[57, 26, t(:dh_pz_tyranitar_wall)]], listed
    assert_equal [], frame
    refute PokeAccess::Puzzles.active?
    PokeAccess::Config.puzzle_assist = true
    assert_equal t(:dh_pz_tyranitar_hint), info_key
    $game_switches[117] = true
    assert_equal [], listed
    refute_includes info_key.to_s, t(:dh_pz_tyranitar_hint)
    refute_equal t(:dh_pz_tyranitar_wall), PokeAccess::Locator.target_name(wall)
  end

  test "arriving with the assist says the way across the cave on the west part, the wall itself on the east, nothing once open" do
    on_map(23)
    stand(22, 45)
    tyranitar_wall
    PokeAccess::Config.puzzle_assist = true
    assert_equal [t(:dh_pz_tyranitar_hint)], frame
    on_map(23)
    stand(51, 22)
    tyranitar_wall
    PokeAccess::Config.puzzle_assist = true
    assert_equal [t(:dh_pz_tyranitar_hint_near)], frame
    on_map(23)
    tyranitar_wall
    $game_switches[117] = true
    PokeAccess::Config.puzzle_assist = true
    assert_equal [], frame
  end

  test "the storeroom's page is listed once the crates are gone, and the crates are named as one while they stand" do
    on_map(151)
    event(15, 7, 10)
    event(16, 31, 5, :tile_id => 598)
    event(17, 31, 6, :tile_id => 598)
    event(19, 32, 5)
    shown = listed
    assert_equal [[7, 10, t(:dh_pz_journal_page)]], shown.select { |r| r[2] == t(:dh_pz_journal_page) }
    assert_equal 1, shown.count { |r| r[2] == t(:dh_pz_crates) }
    $game_variables[31] = 4
    assert_equal [[7, 10, t(:dh_pz_journal_page)], [32, 5, t(:dh_pz_journal_page)]], listed
  end

  test "the hint says the storeroom's page waits behind the crates only while they stand and it is unread" do
    on_map(151)
    event(15, 7, 10)
    PokeAccess::Config.puzzle_assist = true
    assert_includes hint_text, t(:dh_pz_storeroom_page)
    $game_variables[31] = 4
    refute_includes hint_text, t(:dh_pz_storeroom_page)
    $game_variables[31] = 3
    $game_self_switches[[151, 19, "A"]] = true
    refute_includes hint_text, t(:dh_pz_storeroom_page)
  end

  test "the laser before the Shadow Lab's far door is named until the fourth code is known" do
    on_map(105)
    event(26, 32, 6, :sprite => "VisualsInteriorBig8")
    assert_equal [[32, 6, t(:dh_pz_laser)]], listed.select { |r| r[1] == 6 }
    $game_switches[142] = true
    assert_equal [], listed.select { |r| r[1] == 6 }
  end

  test "the bridge pieces that only rearm the sensors are no mechanisms in Gateon Port, though elsewhere they would be" do
    on_map(BARE)
    bridge
    assert_includes listed.map { |r| [r[0], r[1]] }, [33, 19]
    on_map(138)
    bridge
    refute_includes listed.map { |r| [r[0], r[1]] }, [33, 19]
  end

  def t(*args); PokeAccess::I18n.t(*args); end

  def mechanics; PokeAccess::World::Mechanics; end

  def declare_puzzles
    self.class.declared ||= begin
      Harness.load_puzzles("darkhorizon")
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
    SWITCHES.each { |i| $game_switches[i] = false }
    $game_variables[31] = 0
    $game_map.map_id = map
    PokeAccess::Caches.reset_all
    mechanics.forget
  end

  def add(ev)
    $game_map.events[ev.id] = ev
    World.next_frame
    ev
  end

  def event(id, x, y, opts = {})
    page = TestPage.new(:trigger => 0, :sprite => opts.fetch(:sprite, ""), :list => [TestCmd.new(101, ["..."]), TestCmd.new(0, [])])
    add(TestGameEvent.new(:id => id, :x => x, :y => y, :tile_id => opts.fetch(:tile_id, 0), :pages => [page]))
  end

  def stand(x, y)
    $game_player.x = x
    $game_player.y = y
  end

  def tyranitar_wall
    list = [TestCmd.new(101, ["A Tyranitar head can be seen on this rock face!"]), TestCmd.new(101, ["\\PN searches the wall..."]),
            TestCmd.new(121, [117, 117, 0]), TestCmd.new(101, ["An entrance opens up!"]), TestCmd.new(0, [])]
    add(TestGameEvent.new(:id => 11, :x => 57, :y => 26, :name => "Door", :tile_id => 439, :pages => [TestPage.new(:list => list)]))
  end

  def bridge
    piece = TestPage.new(:trigger => 1, :through => true, :condition => { :switch1_valid => true, :switch1_id => 181 },
                         :list => [TestCmd.new(121, [183, 183, 1]), TestCmd.new(0, [])])
    sensor = [TestPage.new(:trigger => 1, :list => [TestCmd.new(121, [183, 183, 0]), TestCmd.new(0, [])]),
              TestPage.new(:condition => { :switch1_valid => true, :switch1_id => 183 })]
    $game_switches[181] = true
    add(TestGameEvent.new(:id => 71, :x => 34, :y => 19, :name => "size(2,2)", :pages => sensor))
    add(TestGameEvent.new(:id => 1, :x => 33, :y => 19, :name => "GateonPortBridge", :tile_id => 884, :pages => [piece]))
  end

  def hint_text; PokeAccess::Puzzles.label_of(mechanics.instances.first.spec[:hint]); end

  def info_key; PokeAccess::Info.map_text; end

  def frame
    SpeakCapture.clear
    PokeAccess::Puzzles.tick
    SpeakCapture.lines
  end

  def listed
    PokeAccess::Puzzles.category_targets.map do |tg|
      name = tg.is_a?(PokeAccess::Locator::SurfaceTarget) ? tg.name : PokeAccess::Locator.target_name(tg)
      [tg.x, tg.y, name]
    end.sort_by { |x, y, _n| [x, y] }
  end
end
