# Tanda 2, wave 3 additions on the shipped profiles over events shaped like the games': the assist's way to Morty through
# Pokemon Infinite Fusion's Ecruteak Gym platforms, and Dark Horizon's Shadow Lab doors that say where they lead. Gamedata pass.
class Ext2PuzzlesGdTest < PokeAccessTest
  TEMPLATES = { "ifx2_route" => "route %{legs}%{more}" }
  PROFILES = { "infinitefusion" => [648], "darkhorizon" => [101] }
  SWITCHES = [43, 143, 139, 520]

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
    stub_missing_keys
  end

  def teardown
    drop_stubbed_keys
    World.clear_events
    SWITCHES.each { |i| $game_switches[i] = false }
    $game_self_switches = @selfs
    $game_player.x = @x
    $game_player.y = @y
    mechanics.instance_variable_set(:@defs, @defs)
    $game_map.map_id = @map
    PokeAccess::Config.puzzle_assist = false
    mechanics.forget
    PokeAccess::Caches.reset_all
    super
  end

  test "Ecruteak's assist gives the way to Morty from where the player stands, with the rhythm only over blinking platforms" do
    on_map(648)
    [4, 5, 6].each_with_index { |x, i| put(10 + i, x, 25, :tile_id => 1241, :name => "skull1") }
    stand(4, 25)
    way = "#{t(:dir_right)}"
    refute_includes info_key.to_s, t(:ifx2_rhythm)
    PokeAccess::Config.puzzle_assist = true
    expected = PokeAccess.sentences([t(:ifx2_route, :legs => "2 #{way}, 1 #{t(:dir_down)}", :more => ""), t(:ifx2_rhythm)])
    assert_includes info_key, expected
    stand(6, 26)
    refute_includes info_key.to_s, t(:ifx2_route, :legs => "", :more => "")[0, 12]
    $game_switches[43] = true
    stand(4, 25)
    refute_includes info_key.to_s, t(:ifx2_rhythm)
  end

  test "Ecruteak's fixed shortcut platforms make a way with no rhythm once the shortcut is on, and none before" do
    on_map(648)
    ((12..16).map { |x| [x, 23] } + (24..26).map { |y| [12, y] } + (9..12).map { |x| [x, 27] }).each_with_index do |(x, y), i|
      put(30 + i, x, y, :tile_id => 1240, :name => "skull")
    end
    stand(17, 23)
    PokeAccess::Config.puzzle_assist = true
    refute_includes info_key.to_s, t(:ifx2_route, :legs => "", :more => "")[0, 12]
    $game_switches[520] = true
    legs = "5 #{t(:dir_left)}, 4 #{t(:dir_down)}, 4 #{t(:dir_left)}"
    assert_includes info_key, t(:ifx2_route, :legs => legs, :more => "")
    refute_includes info_key, t(:ifx2_rhythm)
  end

  test "a long way says its first six legs and that it goes on" do
    on_map(648)
    steps = [[16, 23], [16, 24], [15, 24], [15, 25], [14, 25], [14, 26], [13, 26], [13, 27], [12, 27], [11, 27], [10, 27], [9, 27]]
    steps.each_with_index { |(x, y), i| put(30 + i, x, y, :tile_id => 1240, :name => "skull") }
    $game_switches[520] = true
    stand(16, 23)
    PokeAccess::Config.puzzle_assist = true
    words = ["1 #{t(:dir_down)}", "1 #{t(:dir_left)}"] * 3
    assert_includes info_key, t(:ifx2_route, :legs => words.join(", "), :more => t(:ifx2_more))
  end

  test "the Shadow Lab's code doors say where they lead with the assist alone, as they are used" do
    on_map(101)
    door = put(43, 68, 6, :name => "EV43")
    assert_equal [], frame { fire(door) }
    PokeAccess::Config.puzzle_assist = true
    assert_includes frame { fire(door) }, t(:dh_x_lab_leads1)
  end

  private

  def t(*args); PokeAccess::I18n.t(*args); end

  def mechanics; PokeAccess::World::Mechanics; end

  def stub_missing_keys
    table = PokeAccess::I18n.table(PokeAccess::I18n::REFERENCE)
    @stubbed = TEMPLATES.keys.reject { |key| table.key?(key) }
    @stubbed.each { |key| table[key] = TEMPLATES[key] }
  end

  def drop_stubbed_keys
    table = PokeAccess::I18n.table(PokeAccess::I18n::REFERENCE)
    @stubbed.each { |key| table.delete(key) }
  end

  def declare_puzzles
    self.class.declared ||= begin
      all = {}
      PROFILES.each do |profile, maps|
        Harness.load_puzzles(profile)
        defs = mechanics.instance_variable_get(:@defs)
        maps.each { |map| all[map] = defs[map] }
      end
      all
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
    $game_map.map_id = map
    PokeAccess::Caches.reset_all
    mechanics.forget
  end

  def stand(x, y)
    $game_player.x = x
    $game_player.y = y
  end

  def put(id, x, y, opts = {})
    page = TestPage.new(:trigger => opts.fetch(:trigger, 0), :sprite => opts.fetch(:sprite, ""),
                        :list => [TestCmd.new(101, ["..."]), TestCmd.new(0, [])])
    ev = TestGameEvent.new(:id => id, :x => x, :y => y, :name => opts.fetch(:name, "EV#{id}"), :tile_id => opts.fetch(:tile_id, 0), :pages => [page])
    $game_map.events[id] = ev
    World.next_frame
    ev
  end

  def fire(ev)
    PokeAccess::Puzzles::Auto.fired($game_system.map_interpreter, PokeAccess.ivar(ev, :@list), ev.id)
  end

  def frame
    SpeakCapture.clear
    yield if block_given?
    PokeAccess::Puzzles.tick
    SpeakCapture.lines
  end

  def info_key; PokeAccess::Info.map_text; end
end
