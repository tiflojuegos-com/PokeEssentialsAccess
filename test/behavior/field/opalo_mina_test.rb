# Opalo's Mina Turmalina with the puzzle assist: the next lever, cart or item of the way to the stairs down, by where the
# player stands, the switches and where the carts were left, and nothing of it without the assist.
class OpaloMinaTest < PokeAccessTest
  test "the way down is told step by step with the assist alone" do
    at(50, 15)
    refute_includes info_key.to_s, said(next_cart(35, 15, 4))
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, said(next_cart(35, 15, 4))
    assert_equal next_cart(35, 15, 4), hint
    at(14, 12, [664], 20 => [14, 13])
    assert_equal lever(20, 5), hint
    at(30, 25, [663, 664], 20 => [29, 25])
    assert_equal lever(30, 38), hint
    at(30, 25, [663, 664, 665], 20 => [29, 25])
    assert_equal next_cart(29, 25, 4), hint
    at(11, 35, [663, 664, 665, 666], 20 => [11, 34])
    assert_equal lever(8, 38), hint
    at(11, 35, [663, 664, 665, 666, 667], 20 => [11, 34])
    assert_equal next_cart(29, 50, 6), hint
  end

  test "a cart left where a sensor on the way sends it back is said where it will be boarded, and as such" do
    PokeAccess::Config.puzzle_assist = true
    at(14, 12, [663, 664], 20 => [14, 13])
    assert_equal next_cart(35, 15, 4, :op_mine_next_cart_back), hint
    at(40, 30, [663, 664, 665], 20 => [11, 34])
    assert_equal next_cart(29, 25, 4, :op_mine_next_cart_back), hint
    $game_map.events[20].x = 29
    $game_map.events[20].y = 25
    assert_equal next_cart(29, 25, 4), hint
  end

  test "a cart left on the far side of a one-way ledge is taken back round, not the lever behind it" do
    PokeAccess::Config.puzzle_assist = true
    at(12, 48, [663, 664, 665], 20 => [11, 34])
    assert_equal next_cart(29, 50, 6), hint
    at(38, 44, [663, 664, 665, 669], 20 => [29, 25], 50 => [38, 45])
    assert_equal next_cart(29, 25, 4), hint
  end

  test "the dynamite is fetched before the detonator, going back for it if it was left" do
    PokeAccess::Config.puzzle_assist = true
    at(46, 50, [663, 664, 665, 667, 669], 50 => [45, 50])
    assert_equal dynamite_line(:op_mine_next_item, :op_mine_next_pickup, 54, 40), hint
    with_dynamite do
      assert_equal next_cart(45, 57, 4), hint
      at(45, 70, [663, 664, 665, 667, 669, 672], 73 => [44, 70])
      assert_equal lever(52, 73), hint
      at(21, 61, [663, 664, 665, 667, 669, 670, 672], 73 => [21, 60])
      assert_equal dynamite_line(:op_mine_next_detonator, :op_mine_next_detonator_plain, 18, 61), hint
    end
    at(45, 70, [663, 664, 665, 667, 669, 672], 73 => [44, 70])
    assert_equal next_cart(44, 70, 4), hint
    at(21, 61, [663, 664, 665, 667, 669, 670, 672], 73 => [21, 60])
    assert_equal next_cart(21, 60, 8), hint
  end

  test "past the rubble the stairs are told, with what the mine keeps off the way until it is taken" do
    PokeAccess::Config.puzzle_assist = true
    at(8, 66, [671])
    line = info_key
    assert_includes line, t(:op_mine_next_stairs, :at => from(8, 65))
    assert_includes line, t(:op_mine_extra_start, :at => from(15, 73))
    assert_includes line, t(:op_mine_extra_water, :at => from(31, 67))
    $game_self_switches[[290, 7, "A"]] = true
    $game_self_switches[[290, 8, "A"]] = true
    assert_equal PokeAccess.sentences([t(:op_mine_next_stairs, :at => from(8, 65))]), hint
    at(57, 17, [671])
    assert_equal [:op_mine_next_return, { :at => from(59, 17) }], hint
  end

  test "a new step is said as it comes, and a ride does not go through the steps it crosses" do
    at(36, 15)
    PokeAccess::Config.puzzle_assist = true
    tick
    interpreter = $game_system.map_interpreter
    def interpreter.running?; true; end
    assert_equal [], tick { $game_player.x = 30; $game_player.y = 25 }
    def interpreter.running?; false; end
    assert_includes tick { $game_player.x = 14; $game_player.y = 12; $game_switches[664] = true }, said(lever(20, 5))
  end

  test "the step held through a ride is forgotten on leaving the map" do
    at(36, 15)
    PokeAccess::Config.puzzle_assist = true
    assert_equal next_cart(35, 15, 4), hint
    interpreter = $game_system.map_interpreter
    def interpreter.running?; true; end
    PokeAccess::World::Epoch.touch(:map)
    $game_player.x = 30
    $game_player.y = 25
    assert_equal lever(30, 38), hint
  ensure
    def interpreter.running?; false; end if interpreter
  end

  private

  CART_HOMES = { 20 => [35, 15], 42 => [29, 40], 50 => [29, 50], 73 => [45, 57] }

  def t(key, vars = nil); PokeAccess::I18n.t(key, vars); end

  def hint; PokeAccess::OpaloMineCarts.hint; end

  def said(line); PokeAccess::Puzzles.label_of(line); end

  def from(x, y); PokeAccess::Puzzles.offset_phrase(x - $game_player.x, y - $game_player.y); end

  def next_cart(x, y, dir, key = :op_mine_next_cart)
    [key, { :at => from(x, y), :dir => t(PokeAccess::OpaloMineCarts::DIRS[dir]) }]
  end

  def lever(x, y); [:op_mine_next_lever, { :at => from(x, y) }]; end

  # The dynamite's line, named as the game names it or plain when it gives no name.
  def dynamite_line(named, plain, x, y)
    item = PokeAccess::OpaloMineCarts.dynamite_name
    item.empty? ? [plain, { :at => from(x, y) }] : [named, { :at => from(x, y), :item => item }]
  end

  # Puts the player at (x, y) of the mine with only the given switches of it on, and the carts at home but for those
  # given as {id => [x, y]}, where a ride left them.
  def at(x, y, on = [], moved = {})
    assist = PokeAccess::Config.puzzle_assist
    Harness.load_puzzles("opalo")
    PokeAccess::Config.puzzle_assist = assist
    World.clear_events
    $game_map.map_id = 290
    $game_map.events.clear
    CART_HOMES.each do |id, home|
      cx, cy = moved[id] || home
      page = TestPage.new(:trigger => 0, :sprite => "vagon", :list => [TestCmd.new(0, [])])
      $game_map.events[id] = TestGameEvent.new(:id => id, :x => cx, :y => cy, :pages => [page], :active_page => page)
    end
    (663..672).each { |s| $game_switches[s] = on.include?(s) }
    $game_self_switches = {}
    $game_player.x = x
    $game_player.y = y
    PokeAccess::OpaloMineCarts.forget
    PokeAccess::Puzzles.instance_variable_set(:@told, {})
    PokeAccess::Puzzles::Auto.forget
    World.next_frame
  end

  # Runs the block with the bag holding the dynamite.
  def with_dynamite
    was = $PokemonBag
    $PokemonBag = Object.new
    $PokemonBag.define_singleton_method(:pbQuantity) { |it| it.to_s == "DINAMITA" ? 1 : 0 }
    yield
  ensure
    $PokemonBag = was
  end

  # What the puzzles say on the next map frame, after the block.
  def tick
    SpeakCapture.clear
    yield if block_given?
    PokeAccess::Puzzles.tick
    SpeakCapture.log.dup.map { |line| line[0] }
  end

  def info_key; PokeAccess::Info.map_text; end
end
