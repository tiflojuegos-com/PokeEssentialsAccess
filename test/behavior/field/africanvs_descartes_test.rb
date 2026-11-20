# Pokemon Africanvs' second pass over its discards (games/africanus/puzzles): the temple of Ibossim, whose wrong doors
# send the player back to the entrance. The send-back is said with no help; the door that leads on comes with the assist.
class AfricanvsDescartesTest < PokeAccessTest
  def setup
    super
    @defs = mechanics.instance_variable_get(:@defs).dup
    @map = $game_map.map_id
    @selfs = $game_self_switches
    @player = [$game_player.x, $game_player.y]
  end

  def teardown
    World.clear_events
    $game_switches[190] = false
    $game_self_switches = @selfs
    $game_player.x, $game_player.y = @player
    mechanics.instance_variable_set(:@defs, @defs)
    $game_map.map_id = @map
    PokeAccess::Config.puzzle_assist = false
    mechanics.forget
    PokeAccess::Caches.reset_all
    super
  end

  test "the temple says a wrong door sends back, and the assist names each room's door that leads on" do
    on_map(180)
    door(15, 2, 10, 6, 13)
    door(3, 11, 10, 30, 10)
    door(5, 33, 14, 6, 30)
    stand(6, 12)
    frame
    assert_empty right_ways
    fire(15)
    assert_equal t(:af_ibossim_sent_back), PokeAccess::Puzzles.sent_back_line([2, 10, 180], [6, 13, 180])
    PokeAccess::Config.puzzle_assist = true
    assert_equal [[11, 10]], right_ways
    assert_equal [t(:af_ibossim_hint, :dir => t(:dir_s))], frame { stand(30, 10) }
    assert_equal [[33, 14]], right_ways
    $game_switches[190] = true
    refute PokeAccess::Puzzles.active?
  end

  private

  # The spoken text of an i18n key.
  def t(key, vars = {})
    PokeAccess::I18n.t(key, vars)
  end

  # The mechanics registry.
  def mechanics; PokeAccess::World::Mechanics; end

  # Puts the player on map with the profile's puzzles declared, nothing placed and the assist off.
  def on_map(map)
    Harness.load_puzzles("africanus")
    PokeAccess::Config.puzzle_assist = false
    World.clear_events
    $game_self_switches = {}
    $game_map.map_id = map
    PokeAccess::Caches.reset_all
    PokeAccess::World::Mechanics.forget
    @events = {}
  end

  # Moves the player onto a tile.
  def stand(x, y)
    $game_player.x = x
    $game_player.y = y
  end

  # A door with no sprite touched to move the player to a tile of the temple.
  def door(id, x, y, tx, ty)
    page = TestPage.new(:trigger => 1, :sprite => "", :list => [TestCmd.new(201, [0, 180, tx, ty, 8, 0]), TestCmd.new(0, [])])
    ev = TestGameEvent.new(:id => id, :x => x, :y => y, :pages => [page])
    $game_map.events[id] = ev
    World.next_frame
    @events[id] = ev
  end

  # What the player's use of an event does, as the interpreter's setup tells it.
  def fire(id)
    PokeAccess::Puzzles::Auto.fired($game_system.map_interpreter, PokeAccess.ivar(@events[id], :@list), id)
  end

  # What the puzzles say on the next map frame, after the block.
  def frame
    SpeakCapture.clear
    yield if block_given?
    PokeAccess::Puzzles.tick
    SpeakCapture.lines
  end

  # The puzzles category as [x, y, name], sorted.
  def listed
    PokeAccess::Puzzles.category_targets.map { |tg| [tg.x, tg.y, tg.name] }.sort_by { |x, y, _n| [x, y] }
  end

  # The tiles listed as the right way.
  def right_ways
    listed.select { |_x, _y, name| name == t(:puzzle_right_way) }.map { |x, y, _name| [x, y] }
  end
end
