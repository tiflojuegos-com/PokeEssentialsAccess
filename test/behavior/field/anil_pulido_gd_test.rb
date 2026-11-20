# Anil's optional puzzles (games/anil/puzzles/): Route 8's graveyard, the Rocket lab's switches, the Lost Cave's exits and
# Silph Co.'s pads, on the shipped profile over events shaped like the game's. What a sighted player sees is said without
# the puzzle assist; the order, the right exits and the pads that lead on come with it. Gamedata pass.
class AnilPulidoGdTest < PokeAccessTest
  MAPS = [71, 179, 200, 100, 101, 102]

  class << self
    attr_accessor :declared
  end

  def setup
    super
    @defs = mechanics.instance_variable_get(:@defs).dup
    @map = $game_map.map_id
    @selfs = $game_self_switches
    @player = [$game_player.x, $game_player.y]
  end

  def teardown
    World.clear_events
    [176, 182].each { |i| $game_variables[i] = 0 }
    [115, 119, 197, 198, 255, 328, 329].each { |i| $game_switches[i] = false }
    $game_self_switches = @selfs
    $game_player.x, $game_player.y = @player
    mechanics.instance_variable_set(:@defs, @defs)
    $game_map.map_id = @map
    PokeAccess::Config.puzzle_assist = false
    mechanics.forget
    PokeAccess::Caches.reset_all
    super
  end

  test "the graveyard's tombs take their number once the picture is seen, and the order counts with the assist" do
    assert_equal :anil_graveyard_picture, PokeAccess::PictureCues::TEXTS["mapaCemen"]
    on_map(71)
    { 17 => [27, 8], 18 => [34, 9], 20 => [35, 9], 34 => [28, 14] }.each { |id, (x, y)| tomb(id, x, y) }
    frame
    assert_equal [[27, 8, t(:anil_tomb)], [28, 14, t(:anil_tomb)], [34, 9, t(:anil_tomb)]], listed
    assert_empty frame { $game_variables[176] = 1 }
    $game_switches[115] = true
    assert_equal [[27, 8, marked(1)], [28, 14, marked(3)], [34, 9, marked(2)]], listed
    PokeAccess::Config.puzzle_assist = true
    assert_equal [tombs(2)], frame { $game_variables[176] = 2 }
    refute_empty frame { $game_variables[176] = 0 }
    assert_equal [t(:anil_graveyard_item)], frame { $game_switches[119] = true }
    refute PokeAccess::Puzzles.active?
  end

  test "the Rocket lab's two switches are named and counted until the barrier is off" do
    on_map(179)
    [[15, 8], [16, 16]].each { |id, x| put(id, x, 9, :list => [TestCmd.new(101, ["..."]), TestCmd.new(0, [])]) }
    frame
    assert_equal [[8, 9, t(:anil_lab_switch)], [16, 9, t(:anil_lab_switch)]], listed
    assert_equal [switches(1)], frame { $game_switches[328] = true }
    $game_switches[329] = true
    refute PokeAccess::Puzzles.active?
  end

  test "the Lost Cave says a wrong exit sends back, and the assist names each room's exit that leads on" do
    on_map(200)
    arrow(6, 19, 12, 4, 36)
    arrow(20, 3, 12, 11, 6)
    arrow(7, 11, 43, 11, 55)
    stand(11, 10)
    frame
    assert_empty right_ways
    fire(@events[20])
    assert_equal t(:anil_cave_sent_back), PokeAccess::Puzzles.sent_back_line([4, 12, 200], [11, 6, 200])
    PokeAccess::Config.puzzle_assist = true
    assert_equal [[19, 12]], right_ways
    assert_equal [t(:anil_cave_hint, :dir => t(:dir_s))], frame { stand(4, 36) }
    assert_equal [[11, 43]], right_ways
    $game_switches[255] = true
    refute PokeAccess::Puzzles.active?
  end

  test "Silph's pads are named, and with the assist and both cards those that lead to the president stand out" do
    on_map(101)
    pad(42, 69, 20, 102, 60, 8)
    pad(37, 57, 8, 101, 73, 48)
    frame
    assert_equal [[57, 8, t(:anil_pad)], [69, 20, t(:anil_pad)]], listed
    fire(@events[37])
    assert_equal t(:anil_pad_sent), PokeAccess::Puzzles.sent_back_line([57, 9, 101], [73, 48, 101])
    assert_equal t(:anil_pad_sent), PokeAccess::Puzzles.sent_back_line([28, 49, 100], [25, 54, 101], :map)
    assert_nil PokeAccess::Puzzles.sent_back_line([36, 7, 100], [37, 4, 101], :map)
    PokeAccess::Config.puzzle_assist = true
    assert_equal [[57, 8, t(:anil_pad)], [69, 20, t(:anil_pad)]], listed
    [197, 198].each { |s| $game_switches[s] = true }
    assert_equal [[57, 8, t(:anil_pad)], [69, 20, t(:anil_silph_pad_towards)]], listed
    $game_variables[182] = 9
    refute PokeAccess::Puzzles.active?
  end

  private

  # The spoken text of an i18n key.
  def t(*args); PokeAccess::I18n.t(*args); end

  # The mechanics registry.
  def mechanics; PokeAccess::World::Mechanics; end

  # A tomb's name once its number is known.
  def marked(n); t(:anil_tomb_marked, :n => n); end

  # The graveyard's count of tombs read in order, as said.
  def tombs(n); t(:puzzle_progress, :label => t(:anil_tombs_read), :n => n, :of => 3); end

  # The lab's count of switches turned off, as said.
  def switches(n); t(:puzzle_progress, :label => t(:anil_lab_switches), :n => n, :of => 2); end

  # Declares the profile's puzzles on their maps, loading its files once per process.
  def declare_puzzles
    self.class.declared ||= begin
      Harness.load_puzzles("anil")
      all = mechanics.instance_variable_get(:@defs)
      MAPS.map { |map| [map, all[map]] }
    end
    defs = mechanics.instance_variable_get(:@defs)
    self.class.declared.each { |map, list| defs[map] = list }
  end

  # Puts the player on map with nothing placed, the assist off and the mechanics forgotten.
  def on_map(map)
    declare_puzzles
    PokeAccess::Config.puzzle_assist = false
    World.clear_events
    $game_self_switches = {}
    $game_map.map_id = map
    @events = {}
    PokeAccess::Caches.reset_all
    mechanics.forget
  end

  # Moves the player onto a tile.
  def stand(x, y)
    $game_player.x = x
    $game_player.y = y
  end

  # An event on the map with one page of the trigger, sprite and commands of opts.
  def put(id, x, y, opts = {})
    page = TestPage.new(:trigger => opts.fetch(:trigger, 0), :sprite => opts.fetch(:sprite, ""),
                        :list => opts.fetch(:list, [TestCmd.new(101, ["..."]), TestCmd.new(0, [])]))
    ev = TestGameEvent.new(:id => id, :x => x, :y => y, :pages => [page])
    $game_map.events[id] = ev
    World.next_frame
    @events[id] = ev
  end

  # A tomb with no sprite and no text that moves V176 on.
  def tomb(id, x, y)
    put(id, x, y, :list => [TestCmd.new(122, [176, 176, 1, 0, 1]), TestCmd.new(0, [])])
  end

  # An exit arrow touched to move the player to a tile of the same map.
  def arrow(id, x, y, tx, ty)
    put(id, x, y, :trigger => 1, :sprite => "FlechaSalida", :list => [TestCmd.new(201, [0, 200, tx, ty, 8, 0]), TestCmd.new(0, [])])
  end

  # A pad with no sprite touched to move the player to a tile of a map.
  def pad(id, x, y, map, tx, ty)
    put(id, x, y, :trigger => 1, :list => [TestCmd.new(201, [0, map, tx, ty, 8, 0]), TestCmd.new(0, [])])
  end

  # What the player's use of an event does, as the interpreter's setup tells it.
  def fire(ev)
    PokeAccess::Puzzles::Auto.fired($game_system.map_interpreter, PokeAccess.ivar(ev, :@list), ev.id)
  end

  # What the puzzles say on the next map frame, after the block.
  def frame
    SpeakCapture.clear
    yield if block_given?
    PokeAccess::Puzzles.tick
    SpeakCapture.lines
  end

  # The puzzles category as [x, y, name], in reading order of the tiles.
  def listed
    PokeAccess::Puzzles.category_targets.map { |tg| [tg.x, tg.y, tg.name] }.sort_by { |x, y, _n| [x, y] }
  end

  # The tiles listed as the right way.
  def right_ways
    listed.select { |_x, _y, name| name == t(:puzzle_right_way) }.map { |x, y, _name| [x, y] }
  end
end
