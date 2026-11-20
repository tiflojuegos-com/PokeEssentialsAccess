# What the review of Fire Ash added (games/fireash): Twist Mountain's cave mouths, Galar's rune rock and Striaton's leaders, on
# the shipped profile over events shaped like the game's. Gamedata pass.
class FireashRepasoGdTest < PokeAccessTest
  MAPS = [397, 721, 722, 723, 724]
  ROOMS = ["##############",
           "#.....##.....#",
           "#.@...##.....#",
           "#.....##.....#",
           "##############"]

  class << self
    attr_accessor :declared
  end

  def setup
    super
    @defs = mechanics.instance_variable_get(:@defs).dup
    @map = $game_map.map_id
    @global = $PokemonGlobal
  end

  def teardown
    World.clear_events
    $PokemonGlobal = @global
    mechanics.instance_variable_set(:@defs, @defs)
    $game_map.map_id = @map
    PokeAccess::Config.puzzle_assist = false
    PokeAccess::Config.verbosity = :full
    PokeAccess::FireAshTwist.forget
    mechanics.forget
    PokeAccess::Caches.reset_all
    super
  end

  test "Twist Mountain says its rule once and, with the assist, the first mouth on the way the player can walk to" do
    in_rooms(723) do
      second_floor
      asked = count_asks do
        assert_equal [t(:fa_twist_rule)], frame
        refute_includes names, t(:puzzle_right_way)
        mechanics.forget
        assert_equal [], frame
      end
      assert_equal 0, asked, "without the assist nothing is searched"
      PokeAccess::Config.puzzle_assist = true
      asked = count_asks do
        assert_equal [[4, 1]], right_ways
        assert_includes info_key, t(:fa_twist_hint)
        $game_player.x = 3
        assert_equal [[4, 1]], right_ways
      end
      assert_equal 1, asked, "found once on arriving, kept while the player walks"
      $game_player.x = 9
      assert_equal [[10, 1]], right_ways
      $PokemonGlobal.visitedMaps[725] = true
      PokeAccess::FireAshTwist.forget
      assert_equal [], right_ways
      refute PokeAccess::Puzzles.active?
    end
  end

  test "Twist Mountain's hint comes with the assist on arriving, or as soon as the walk can tell the way" do
    in_rooms(723) do
      second_floor
      PokeAccess::Config.puzzle_assist = true
      assert_equal [t(:fa_twist_rule), t(:fa_twist_hint)], frame
      mechanics.forget
      PokeAccess::FireAshTwist.forget
      answers = [:unknown]
      count_asks(answers) do
        assert_equal [], frame
        assert_equal [t(:fa_twist_hint)], frame
        assert_equal [], frame
      end
    end
  end

  test "each map of Twist Mountain has its way and the rule" do
    { 721 => 19, 722 => 9, 724 => 13 }.each do |map, mouth|
      in_rooms(map) do
        pad(mouth, 4, 1, 725, [17, 51])
        assert_equal [t(:fa_twist_rule)], frame
        PokeAccess::Config.puzzle_assist = true
        assert_equal [[4, 1]], right_ways
      end
    end
  end

  test "Galar's rune rock is named for what it does and a walk keeps off it" do
    on_map(397)
    put(10, 21, 17, :trigger => 1, :name => "rune, size(2,2)",
        :list => [TestCmd.new(355, ["pbEvolvePokemonEvent(:YAMASK_1)"]), TestCmd.new(0, [])])
    assert_equal [[21, 17, t(:fa_o_rock_yamask)]], listed
    assert PokeAccess::Routes::Controls.keep_off[PokeAccess::Routes.pkey(21, 17)], "a walk keeps off the rune rock"
  end

  test "Striaton's leaders are named as their lines call them, not all three Cilan" do
    rules = PokeAccess::Locator.instance_variable_get(:@rules)[:name]
    kept = rules.length
    path = File.join(Harness::ROOT, "games", "fireash", "striaton_leaders.rb")
    eval(Harness.source(path), TOPLEVEL_BINDING, path)
    on_map(663)
    [[1, 17], [10, 14], [11, 20]].each { |id, x| put(id, x, 7, :name => "Cilan", :sprite => "trchar120") }
    assert_equal ["Cilan", t(:fa_chili), t(:fa_cress)], [1, 10, 11].map { |id| PokeAccess::Locator.target_name(@events[id]) }
  ensure
    rules.slice!(kept..-1) if rules && kept
  end

  private

  # The spoken text of an i18n key.
  def t(*args); PokeAccess::I18n.t(*args); end

  # The mechanics registry.
  def mechanics; PokeAccess::World::Mechanics; end

  # Declares the profile's puzzles on their maps, loading its files once per process.
  def declare_puzzles
    self.class.declared ||= begin
      Harness.load_puzzles("fireash")
      all = mechanics.instance_variable_get(:@defs)
      MAPS.map { |map| [map, all[map]] }
    end
    defs = mechanics.instance_variable_get(:@defs)
    self.class.declared.each { |map, list| defs[map] = list }
  end

  # Puts the player on map with nothing placed, the assist off, Icirrus City not reached and the mechanics forgotten.
  def on_map(map)
    declare_puzzles
    PokeAccess::Config.puzzle_assist = false
    World.clear_events
    $game_map.map_id = map
    $PokemonGlobal = Struct.new(:visitedMaps).new([])
    PokeAccess::Puzzles.instance_variable_set(:@told, {})
    PokeAccess::FireAshTwist.forget
    @events = {}
    PokeAccess::Caches.reset_all
    mechanics.forget
  end

  # Runs the block on map drawn as two rooms with no way between them, the player in the western one.
  def in_rooms(map)
    old_map = $game_map
    old_player = $game_player
    $game_map = TileWorld.new(ROOMS, map)
    $game_player = TileWorldPlayer.new(*$game_map.start)
    on_map(map)
    PokeAccess::Pathfinder.invalidate_cache(true)
    PokeAccess::World::Epoch.touch(:tiles)
    yield
  ensure
    $game_map = old_map
    $game_player = old_player
    PokeAccess::Pathfinder.invalidate_cache(true)
    PokeAccess::World::Epoch.touch(:tiles)
  end

  # An event on the map: one page with the trigger, sprite, name and commands of opts.
  def put(id, x, y, opts = {})
    page = TestPage.new(:trigger => opts.fetch(:trigger, 0), :sprite => opts.fetch(:sprite, ""),
                        :list => opts.fetch(:list, [TestCmd.new(101, ["..."]), TestCmd.new(0, [])]))
    ev = TestGameEvent.new(:id => id, :x => x, :y => y, :name => opts.fetch(:name, "EV#{id}"), :pages => [page])
    $game_map.events[id] = ev
    World.next_frame
    @events[id] = ev
  end

  # A cave mouth: a touch event that only transfers to the tile to of a map.
  def pad(id, x, y, map, to)
    put(id, x, y, :trigger => 1, :list => [TestCmd.new(201, [0, map, to[0], to[1], 8, 0]), TestCmd.new(0, [])])
  end

  # 2F's four mouths, two in each room: 12 and 10 in the western one, 9 and 7 in the eastern one.
  def second_floor
    pad(12, 4, 1, 722, [35, 20])
    pad(10, 1, 3, 721, [39, 27])
    pad(9, 10, 1, 721, [21, 34])
    pad(7, 12, 3, 721, [55, 49])
  end

  # How many times the block asks whether a mouth can be walked to; answers, while it lasts, gives the first replies.
  def count_asks(answers = [])
    twist = PokeAccess::FireAshTwist
    real = twist.method(:status)
    n = 0
    twist.define_singleton_method(:status) do |id|
      n += 1
      answers.empty? ? real.call(id) : answers.shift
    end
    yield
    n
  ensure
    twist.define_singleton_method(:status, real)
  end

  # What the puzzles say on the next map frame.
  def frame
    PokeAccess::Frame.instance_variable_set(:@serial, PokeAccess::Frame.serial + 1)
    SpeakCapture.clear
    PokeAccess::Puzzles.tick
    SpeakCapture.lines
  end

  # What the info key says on the map now.
  def info_key; PokeAccess::Info.map_text.to_s; end

  # The puzzles category as [x, y, name], sorted.
  def listed
    PokeAccess::Puzzles.category_targets.map { |tg| [tg.x, tg.y, tg.name] }.sort_by { |x, y, _n| [x, y] }
  end

  # The names in the puzzles category.
  def names; listed.map { |_x, _y, n| n }; end

  # Where the puzzles category lists the right way, after a map frame.
  def right_ways
    frame
    listed.select { |_x, _y, n| n == t(:puzzle_right_way) }.map { |x, y, _n| [x, y] }
  end
end
