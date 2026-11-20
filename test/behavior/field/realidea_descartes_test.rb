# Realidea's second pass over its discards (games/realidea/puzzles/daruma_rooms.rb): the Daruma rooms, where Darmanitan
# are pushed onto tiles of light. The free tiles of light are listed and the Darmanitan on one are counted, with no help.
class RealideaDescartesTest < PokeAccessTest
  ROOM = 386

  def setup
    super
    Harness.load_puzzles("realidea")
    @map = $game_map.map_id
  end

  def teardown
    $game_map.singleton_class.send(:remove_method, :terrain_tag) if @tagged
    World.clear_events
    $game_switches[500] = false
    $game_map.map_id = @map
    PokeAccess::World::Mechanics.forget
    PokeAccess::Caches.reset_all
    super
  end

  test "the free tiles of light are listed and the Darmanitan on one counted until the room is done" do
    on_map(ROOM)
    goals = PokeAccess::RealideaDaruma::ROOMS[ROOM][1]
    lay_goals(goals)
    first = daruma(1, 14, 14)
    daruma(4, 15, 15)
    frame
    assert_equal goals - [[15, 15]], listed.map { |x, y, _n| [x, y] }
    assert listed.all? { |_x, _y, name| name == t(:rea_daruma_goal) }
    assert_equal [t(:puzzle_progress, :label => t(:rea_daruma_lit), :n => 2, :of => 9)], frame { first.x = 15; first.y = 14 }
    assert_equal goals - [[15, 14], [15, 15]], listed.map { |x, y, _n| [x, y] }
    $game_switches[500] = true
    refute PokeAccess::Puzzles.active?
  end

  private

  def t(key, vars = {})
    PokeAccess::I18n.t(key, vars)
  end

  def on_map(map)
    PokeAccess::Config.puzzle_assist = false
    World.clear_events
    $game_map.map_id = map
    PokeAccess::Caches.reset_all
    PokeAccess::World::Mechanics.forget
  end

  # Gives the tiles of light their terrain tag, and none elsewhere.
  def lay_goals(goals)
    @tagged = true
    $game_map.define_singleton_method(:terrain_tag) { |x, y, *_rest| goals.include?([x, y]) ? 43 : 0 }
  end

  # A Darmanitan of the room on a tile.
  def daruma(id, x, y)
    page = TestPage.new(:trigger => 2, :sprite => "Darmanitan", :list => [TestCmd.new(0, [])])
    ev = TestGameEvent.new(:id => id, :x => x, :y => y, :name => "daruma", :pages => [page], :active_page => page)
    $game_map.events[id] = ev
    World.next_frame
    ev
  end

  def frame
    SpeakCapture.clear
    yield if block_given?
    PokeAccess::Puzzles.tick
    SpeakCapture.lines
  end

  def listed
    PokeAccess::Puzzles.category_targets.select { |tg| tg.name == t(:rea_daruma_goal) }
                       .map { |tg| [tg.x, tg.y, tg.name] }.sort_by { |x, y, _n| [x, y] }
  end
end
