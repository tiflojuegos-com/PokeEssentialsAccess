# Tanda 2, wave 3 additions on Pokemon Infinite Fusion's shipped profile: the assist's way through Silph Co. to the
# president's office (Card Key, rescued workers, the employee who shuts the corridor on 7F, the 3F pad), over events
# shaped like the game's. Gamedata pass.
class InfiniteFusionExt1PuzzlesGdTest < PokeAccessTest
  TEMPLATES = { "ifx_silph_hint_workers" => "workers rescued %{n}" }
  MAPS = [212, 661, 665]
  SWITCHES = [228, 582]

  class << self
    attr_accessor :declared
  end

  class FakeBag
    attr_accessor :cardkey

    def pbQuantity(item)
      item == :CARDKEY && cardkey ? 1 : 0
    end
  end

  def setup
    super
    @defs = mechanics.instance_variable_get(:@defs).dup
    @map = $game_map.map_id
    @selfs = $game_self_switches
    @bag = $PokemonBag
    @x = $game_player.x
    @y = $game_player.y
    stub_missing_keys
    $PokemonBag = FakeBag.new
  end

  def teardown
    drop_stubbed_keys
    World.clear_events
    SWITCHES.each { |i| $game_switches[i] = false }
    $game_variables[229] = 0
    $game_self_switches = @selfs
    $PokemonBag = @bag
    $game_player.x = @x
    $game_player.y = @y
    mechanics.instance_variable_set(:@defs, @defs)
    $game_map.map_id = @map
    PokeAccess::Config.puzzle_assist = false
    mechanics.forget
    PokeAccess::Caches.reset_all
    super
  end

  test "Silph Co. says nothing of the way to the office without the assist" do
    on_map(212)
    refute_includes info_key.to_s, t(:ifx_silph_hint_key)
    refute_includes info_key.to_s, t(:ifx_silph_hint_to_floor)
  end

  test "the assist asks for the Card Key and the workers first, counting the rescued ones" do
    on_map(212)
    PokeAccess::Config.puzzle_assist = true
    assert_equal PokeAccess.sentences([t(:ifx_silph_hint_key), t(:ifx_silph_hint_workers, :n => 0)]), info_key
    $game_variables[229] = 2
    assert_includes info_key, t(:ifx_silph_hint_workers, :n => 2)
    $PokemonBag.cardkey = true
    assert_equal t(:ifx_silph_hint_workers, :n => 2), info_key
  end

  test "with the key and three workers the assist sends to 3F from anywhere but 3F and the 7F corridor" do
    on_map(212)
    PokeAccess::Config.puzzle_assist = true
    $PokemonBag.cardkey = true
    $game_variables[229] = 3
    assert_equal t(:ifx_silph_hint_to_floor), info_key
    on_map(665)
    PokeAccess::Config.puzzle_assist = true
    $PokemonBag.cardkey = true
    $game_variables[229] = 3
    stand(12, 10)
    assert_equal t(:ifx_silph_hint_to_floor), info_key
  end

  test "on 3F the assist names the pad and the Card Key door only while it is shut" do
    on_map(661)
    PokeAccess::Config.puzzle_assist = true
    $PokemonBag.cardkey = true
    $game_variables[229] = 5
    assert_equal PokeAccess.sentences([t(:ifx_silph_hint_pad_floor), t(:ifx_silph_hint_door)]), info_key
    $game_switches[582] = true
    assert_equal t(:ifx_silph_hint_pad_floor), info_key
  end

  test "in the 7F corridor the assist says to talk to the employee and, once he has moved, where the pad is" do
    on_map(665)
    PokeAccess::Config.puzzle_assist = true
    $PokemonBag.cardkey = true
    $game_variables[229] = 3
    stand(3, 5)
    assert_equal t(:ifx_silph_hint_talk), info_key
    $game_self_switches[[665, 35, "A"]] = true
    assert_equal t(:ifx_silph_hint_pad), info_key
    stand(12, 10)
    assert_equal t(:ifx_silph_hint_to_floor), info_key
  end

  test "once the employee has moved the key and the workers no longer matter, and Giovanni leaving ends it all" do
    on_map(212)
    PokeAccess::Config.puzzle_assist = true
    $game_self_switches[[665, 35, "A"]] = true
    assert_equal t(:ifx_silph_hint_to_floor), info_key
    $game_switches[228] = true
    refute_includes info_key.to_s, t(:ifx_silph_hint_to_floor)
  end

  test "the employee is named and listed only while he shuts the corridor, and the pad is named" do
    on_map(665)
    put(35, 2, 8, :name => "lapras guy", :sprite => "BW066")
    put(4, 4, 8, :name => "P", :tile_id => 0)
    assert_equal [35], PokeAccess::Puzzles.category_targets.map(&:ref)
    assert_equal t(:ifx_silph_guard), PokeAccess::Puzzles.category_targets[0].name
    $game_self_switches[[665, 35, "A"]] = true
    assert_equal [4], PokeAccess::Puzzles.category_targets.map(&:ref)
    assert_equal t(:ifx_silph_office_pad), PokeAccess::Puzzles.category_targets[0].name
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
      Harness.load_puzzles("infinitefusion")
      defs = mechanics.instance_variable_get(:@defs)
      all = {}
      MAPS.each { |map| all[map] = defs[map] }
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
    $game_variables[229] = 0
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

  def info_key; PokeAccess::Info.map_text; end
end
