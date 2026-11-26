# The Seafloor of Realidea (games/realidea/puzzles/seafloor.rb): currents no one sees push the player through the rock.
# The walks meet them as plain ground without the puzzle assist and ride them with it; each push is told by the way it
# goes, the see-through events stay out of the lists, and with the assist each stretch of map 274 points at its good
# current, the four in turn, then at the exit.
class RealideaSeafloorTest < PokeAccessTest
  Effects = PokeAccess::Routes::Effects
  # Two rooms a wall apart, the player in the top one; a current on the left wall of its second row looks right.
  ROOMS = ["#########",
           "#@......#",
           "#.......#",
           "#########",
           "#.......#",
           "#.......#",
           "#########"]

  def setup
    super
    Harness.load_puzzles("realidea")
    @was_selfs = $game_self_switches
    @was_map = $game_map.map_id
    $game_self_switches = {}
    $game_map.map_id = sea::MAP
    PokeAccess::Caches.reset_all
    World.clear_events
  end

  def teardown
    PokeAccess::Config.set(:puzzle_assist, false)
    World.clear_events
    $game_map.clear_grid
    PokeAccess::World::Mechanics.forget
    $game_self_switches = @was_selfs
    $game_map.map_id = @was_map
    super
  end

  test "the walks meet a current as plain ground without the assist and ride it with it" do
    $game_map.load_grid(ROOMS)
    current(18, 0, 2, 6)
    PokeAccess::Pathfinder.invalidate_cache(true)
    off = [Effects.touch_index[PokeAccess::Routes.pkey(2, 2)], PokeAccess::Routes::Planner.walk(4, 5, true).status]
    PokeAccess::Config.set(:puzzle_assist, true)
    World.next_frame
    on = Effects.touch_index[PokeAccess::Routes.pkey(2, 2)]
    assert_equal [nil, :exhausted], off
    assert_equal [:carry, 0, 2], on[1][2][0, 3]
    assert_equal :found, PokeAccess::Routes::Planner.walk(4, 5, true).status
  end

  test "each push is told by the way the current pushes, on both maps" do
    down = current(18, 8, 22, 6)
    up = current(13, 30, 25, 6)
    said = [down, up].map do |ev|
      fire(ev)
      PokeAccess::Puzzles.sent_back_line([ev.x + 1, ev.y, sea::MAP], [ev.x + 1, ev.y, sea::MAP], :forced)
    end
    assert_equal [t(:rea_sea_pushed, :dir => t(:toward_down)), t(:rea_sea_pushed, :dir => t(:toward_up))], said
    World.clear_events
    PokeAccess::World::Mechanics.forget
    $game_map.map_id = 275
    PokeAccess::Caches.reset_all
    aside = current(2, 23, 37, 6)
    fire(aside)
    assert_equal t(:rea_sea_pushed, :dir => t(:toward_down)), PokeAccess::Puzzles.sent_back_line([24, 37, 275], [24, 38, 275], :forced)
  end

  test "the see-through events stay out of the lists" do
    hidden = current(19, 44, 41, 6)
    shown = current(17, 49, 28, 6)
    def shown.opacity; 255; end
    assert_equal [true, false], [hidden, shown].map { |ev| PokeAccess::Puzzles.hidden_event?(ev) }
  end

  test "each stretch is told apart, where the good currents leave the player and where the traps do" do
    { [51, 12] => 5, [11, 24] => 3, [33, 23] => 2, [50, 30] => 1, [47, 43] => 4, [47, 19] => 5, [40, 27] => 2,
      [6, 39] => 0, [8, 35] => 3, [25, 35] => 3, [0, 43] => 4 }.each do |(x, y), zone|
      step(x, y)
      assert_equal zone, sea.zone, "(#{x}, #{y})"
    end
  end

  test "with the assist each stretch points at its good current, the four in turn, then at the exit" do
    [[18, 8, 22, 6], [13, 30, 25, 6], [17, 49, 28, 6], [19, 44, 41, 6], [15, 6, 37, 6]].each { |c| current(*c) }
    step(51, 12)
    assert_nil spot_names
    PokeAccess::Config.set(:puzzle_assist, true)
    assert_equal [[8, 22, t(:rea_sea_good, :step => 1)]], spot_names
    assert_includes PokeAccess::Puzzles.info_line.to_s, t(:rea_sea_hint, :step => 1, :dir => t(:toward_down))
    step(33, 23)
    assert_equal [[49, 28, t(:rea_sea_good, :step => 3)]], spot_names
    step(6, 39)
    assert_equal [[6, 37, t(:rea_sea_way_back)]], spot_names
    step(10, 45)
    assert_nil spot_names
    assert_includes PokeAccess::Puzzles.info_line.to_s, t(:rea_sea_hint_exit)
  end

  private

  def t(key, vars = {}); PokeAccess::I18n.t(key, vars); end

  # The puzzle's module, loaded with the profile's puzzles.
  def sea; PokeAccess::RealideaSeafloor; end

  def step(x, y)
    $game_player.x = x
    $game_player.y = y
  end

  # A current of the map as the game lays it, event id on (x,y) facing d, drawn see-through: it pushes the player two
  # tiles the way the puzzle's table says once they stand ahead of it, and its autorun page turns its self switch off.
  def current(id, x, y, d)
    way = sea::CURRENTS[$game_map.map_id][id]
    code = { 2 => 1, 4 => 2, 6 => 3, 8 => 4 }[way]
    ahead = { 2 => "$game_player.y>#{y}", 4 => "$game_player.x<#{x}", 6 => "$game_player.x>#{x}", 8 => "$game_player.y<#{y}" }
    list = [TestCmd.new(111, [12, ahead[d]]), World.move_player([37, code, code, 38, 0], 1), TestCmd.new(0, [], 1),
            TestCmd.new(412, []), TestCmd.new(123, ["A", 0]), TestCmd.new(0, [])]
    pages = [TestPage.new(:trigger => 2, :sprite => "Shota", :direction => d, :through => true, :list => list),
             TestPage.new(:trigger => 3, :condition => { :self_switch_valid => true, :self_switch_ch => "A" },
                          :list => [TestCmd.new(123, ["A", 1]), TestCmd.new(0, [])])]
    ev = TestGameEvent.new(:id => id, :x => x, :y => y, :name => "Trainer(4)", :pages => pages)
    ev.direction = d
    ev.through = true
    def ev.opacity; 0; end
    $game_map.events[id] = ev
    World.next_frame
    ev
  end

  # The player's use of an event, as the map's interpreter starts its page, the map's change read first.
  def fire(ev)
    PokeAccess::World::Mechanics.instances
    PokeAccess::Puzzles::Auto.fired($game_system.map_interpreter, PokeAccess.ivar(ev, :@list), ev.id)
  end

  # The assist's spots of the stretch the player stands in, as [x, y, name], nil for none.
  def spot_names
    out = PokeAccess::Puzzles.category_targets.select { |tg| tg.is_a?(PokeAccess::Locator::SurfaceTarget) }
    out = out.map { |tg| [tg.x, tg.y, PokeAccess::Locator.target_name(tg)] }
    out.empty? ? nil : out
  end
end
