# Pokemon Infinite Fusion Hoenn's puzzles from the 1.3.2 review (games/infinitefusion_hoenn/puzzles/): Route 109's beach
# ball, Granite Cave's cracked floor, the nest hats of Routes 101, 102 and 115, Mauville Gym's starting layout and the
# Trick House garden with its code known on arriving, on the shipped profile over events shaped like the game's.
# Gamedata pass.
class InfinitefusionHoennRepasoGdTest < PokeAccessTest
  SWITCHES = [2139, 2140, 2154, 2012, 2025, 6, 2198]
  KIDS = [[39, 16], [40, 16], [41, 16]]
  KEYS = {
    "if_ho_ball_hint" => "[next %{kick} %{gait} %{n}]", "if_ho_ball_from_kids" => "[kids %{dist}]"
  }
  NAMES = %w[if_ho_ball if_ho_ball_burst if_ho_ball_popped if_ho_ball_rule if_ho_ball_kick_down if_ho_ball_kick_left if_ho_ball_kick_right
             if_ho_ball_kick_up if_ho_ball_walk if_ho_ball_run if_ho_ball_hint_none if_ho_crack if_ho_crack_rule
             if_ho_crack_hint if_ho_nest_hint_ralts if_ho_nest_hint_shiny if_jh_layout_start if_jh_layout_start_hint
             if_ho_garden_hint_door]

  def setup
    super
    @defs = mechanics.instance_variable_get(:@defs).dup
    @map = $game_map.map_id
    @selfs = $game_self_switches
    @size = [$game_map.width, $game_map.height]
    @at = [$game_player.x, $game_player.y]
    Object.send(:define_method, :hasHat?) { |id| ($ifh_hats || []).include?(id) }
    table = PokeAccess::I18n.table(PokeAccess::I18n::REFERENCE)
    texts = KEYS.dup
    NAMES.each { |k| texts[k] ||= "[#{k}]" }
    @stubbed = texts.keys.reject { |k| table.key?(k) || table.key?("#{k}.other") }
    @stubbed.each { |k| table[k] = texts[k] }
    PokeAccess::Puzzles.instance_variable_set(:@told, {})
  end

  def teardown
    World.clear_events
    $ifh_hats = nil
    Object.send(:remove_method, :hasHat?)
    SWITCHES.each { |i| $game_switches[i] = false }
    $game_self_switches = @selfs
    mechanics.instance_variable_set(:@defs, @defs)
    $game_map.map_id = @map
    $game_map.width, $game_map.height = @size
    $game_player.x, $game_player.y = @at
    PokeAccess::Config.puzzle_assist = false
    mechanics.forget
    PokeAccess::Caches.reset_all
    table = PokeAccess::I18n.table(PokeAccess::I18n::REFERENCE)
    @stubbed.each { |k| table.delete(k) }
    PokeAccess::Puzzles.instance_variable_set(:@told, {})
    super
  end

  test "a kick flies 2 tiles walking and 3 running, comes back off a wall, pops on a wild Pokemon and wins by the kids" do
    on_map(39)
    right = ball::DIRS[2]
    assert_equal [28, 5, false], ball.kick(26, 5, right, 3, [25, 5], beach)
    assert_equal [29, 5, false], ball.kick(26, 5, right, 4, [25, 5], beach)
    assert_equal [26, 5, false], ball.kick(26, 5, right, 4, [25, 5], beach([[29, 5]]))
    assert_nil ball.kick(26, 5, right, 3, [25, 5], beach([], [[28, 5]]))
    assert_equal [36, 16, false], ball.kick(36, 16, right, 4, [35, 16], beach([], [], KIDS))
    assert_equal [38, 16, true], ball.kick(36, 16, right, 3, [35, 16], beach([], [], KIDS))
  end

  test "the kick plan takes the fewest kicks, and finds none when every way pops the ball" do
    on_map(39)
    assert_equal [ball::DIRS[2], 3, 1], ball.plan(36, 16, beach([], [], KIDS))
    assert_equal [ball::DIRS[2], 4, 2], ball.plan(32, 16, beach([], [], KIDS))
    assert_nil ball.plan(32, 16, beach([], (0...60).to_a.product((0...30).to_a) - [[32, 16]], KIDS))
  end

  test "the kick reads the map as it stands: kids take no landing, a wild Pokemon with a page pops it, a walled-off tile is no place to kick from" do
    on_map(39)
    $game_map.width = 50
    $game_map.height = 30
    $game_player.x = 30
    $game_player.y = 20
    ev = put(4, 36, 16, :sprite => "beachball", :name => "ball /nofoot/", :trigger => 2)
    ev.blocking = true
    KIDS.each_with_index { |(x, y), i| put(56 + i, x, y, :sprite => "NPC_Hoenn_Tuber_M") }
    right = ball::DIRS[2]
    assert_equal [36, 16, false], ball.kick(36, 16, right, 4, [35, 16], ball.live_env(ev))
    assert_equal [38, 16, true], ball.kick(36, 16, right, 3, [35, 16], ball.live_env(ev))
    wild = put(65, 37, 16, :sprite => "000", :name => "OverworldPokemon")
    assert_nil ball.kick(36, 16, right, 3, [35, 16], ball.live_env(ev))
    wild.instance_variable_set(:@erased, true)
    assert_equal [38, 16, true], ball.kick(36, 16, right, 3, [35, 16], ball.live_env(ev))
    [[35, 15], [34, 16], [35, 17]].each_with_index { |(x, y), i| put(80 + i, x, y, :sprite => "rock").blocking = true }
    World.next_frame
    assert_equal :no, PokeAccess::Routes::Planner.reach(PokeAccess::Routes::Goal.onto(35, 16))[0]
    refute ball.stand?($game_map, 35, 16)
    assert ball.stand?($game_map, 36, 15)
    found = ball.plan(36, 16, ball.live_env(ev))
    refute_nil found
    refute_equal ball::DIRS[2], found[0]
  end

  test "the beach ball tells its rule during the quest, its pops and moves, and the next kick with the assist alone" do
    on_map(39)
    put(4, 26, 5, :sprite => "beachball", :name => "ball /nofoot/", :trigger => 2)
    assert_equal [], frame
    on_map(39)
    $game_switches[2139] = true
    put(4, 26, 5, :sprite => "beachball", :name => "ball /nofoot/", :trigger => 2)
    giver = put(57, 40, 16, :sprite => "beachball_special", :name => 'questNPC("rt109_beachballQuest")')
    assert_includes frame, t(:if_ho_ball_rule)
    assert_equal t(:if_ho_ball_burst), PokeAccess::Locator.target_name(giver)
    assert_includes frame { $game_self_switches[[39, 4, "A"]] = true }, t(:if_ho_ball_popped)
    assert_includes frame { $game_map.events[4].x = 36; $game_map.events[4].y = 16 }.join(" "), t(:if_ho_ball)
    assert_includes info_key, t(:if_ho_ball_from_kids, :dist => PokeAccess::Puzzles.offset_phrase(-4, 0))
    next_kick = t(:if_ho_ball_hint, :kick => t(:if_ho_ball_kick_right), :gait => t(:if_ho_ball_walk), :n => 1)
    with_env(beach([], [], KIDS)) { refute_includes info_key, next_kick }
    PokeAccess::Config.puzzle_assist = true
    with_env(beach([], [], KIDS)) { assert_includes info_key, next_kick }
    with_env(beach([], [[37, 16], [36, 17], [36, 15], [35, 16]], KIDS)) { assert_includes info_key, t(:if_ho_ball_hint_none) }
    $game_switches[2140] = true
    with_env(beach([], [], KIDS)) { refute_includes info_key, next_kick }
  end

  test "Granite Cave's cracked floor is one target, tells its rule on arriving and the way across with the assist" do
    on_map(34)
    [22, 23, 24].each { |x| hole(70 + x, x, 7) }
    assert_includes frame, t(:if_ho_crack_rule)
    on_map(34)
    [22, 23, 24].each { |x| hole(70 + x, x, 7) }
    refute_includes frame, t(:if_ho_crack_rule)
    assert_equal [t(:if_ho_crack)], listed.map { |_x, _y, n| n }
    refute_includes info_key, t(:if_ho_crack_hint)
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, t(:if_ho_crack_hint)
    $game_self_switches[[35, 4, "A"]] = true
    $game_self_switches[[35, 5, "A"]] = true
    refute_includes info_key, t(:if_ho_crack_hint)
  end

  test "Route 101's nest tells its Pokemon coming and fleeing, and the way to wake it with the assist once it can come" do
    on_map(5)
    put(24, 36, 21)
    assert_equal [], frame
    assert_includes frame { put(24, 32, 21, :sprite => "POKEMON_ZIGZAGOON") }.join(" "), t(:ifq_nest_here)
    assert_includes frame { put(24, 32, 21) }.join(" "), t(:ifq_nest_fled)
    PokeAccess::Config.puzzle_assist = true
    refute_includes info_key, t(:ifq_nest_hint_still)
    $game_switches[2012] = true
    assert_includes info_key, t(:ifq_nest_hint_still)
    $ifh_hats = %w[zigzaghat]
    refute_includes info_key, t(:ifq_nest_hint_still)
    on_map(65)
    put(30, 56, 84)
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, t(:ifq_nest_hint_still)
  end

  test "Route 102's hint is for the Ralts, then for the shiny one visit in twenty, and goes with Wally's catch or both hats" do
    on_map(10)
    put(22, 1, 1)
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, t(:if_ho_nest_hint_ralts)
    $ifh_hats = %w[ralts]
    $game_map.events.delete(22)
    World.next_frame
    assert_includes info_key, t(:if_ho_nest_hint_shiny)
    $game_switches[2025] = true
    refute_includes info_key, t(:if_ho_nest_hint_shiny)
    $game_switches[2025] = false
    $ifh_hats = %w[ralts raltsshiny]
    refute_includes info_key, t(:if_ho_nest_hint_shiny)
  end

  test "Mauville Gym's starting layout is its own, told by the info key with the dead blue switch for the assist" do
    on_map(102)
    { 8 => [10, 23], 20 => [13, 15], 18 => [14, 19], 21 => [20, 15] }.each do |id, (x, y)|
      put(id, x, y, :name => "switch size(1,2).sl forced_z=0", :sprite => "lighting_button", :trigger => 1)
    end
    $game_self_switches[[102, 8, "A"]] = true
    assert_equal [t(:if_jh_mauville_rule)], frame
    assert_includes info_key, t(:if_jh_layout_start)
    refute_includes info_key, t(:if_jh_layout_blue)
    refute_includes info_key, t(:if_jh_layout_start_hint)
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, t(:if_jh_layout_start_hint)
    PokeAccess::Config.puzzle_assist = false
    pressed = frame do
      $game_self_switches[[102, 14, "B"]] = true
      $game_self_switches[[102, 8, "A"]] = false
      $game_self_switches[[102, 18, "A"]] = true
    end
    assert_equal [t(:if_jh_layout_red)], pressed
  end

  test "the Trick House garden keeps its rule quiet and points at the door when the code is known on arriving" do
    on_map(108)
    PokeAccess::Config.puzzle_assist = true
    $game_switches[2154] = true
    refute_includes frame, t(:if_ho_garden_rule)
    assert_includes info_key, t(:if_ho_garden_hint_door)
    on_map(108)
    PokeAccess::Config.puzzle_assist = true
    $game_switches[2154] = false
    assert_includes frame, t(:if_ho_garden_rule)
    assert_includes info_key, t(:if_ho_garden_hint)
    refute_includes info_key, t(:if_ho_garden_hint_door)
  end

  private

  def t(key, vars = nil); PokeAccess::I18n.t(key, vars); end

  def mechanics; PokeAccess::World::Mechanics; end

  def ball; PokeAccess::HoennBeachBall; end

  def on_map(map)
    Harness.load_puzzles("infinitefusion_hoenn")
    PokeAccess::Config.puzzle_assist = false
    World.clear_events
    $game_self_switches = {}
    $game_map.map_id = map
    PokeAccess::Caches.reset_all
    mechanics.forget
  end

  def put(id, x, y, opts = {})
    page = TestPage.new(:trigger => opts.fetch(:trigger, 0), :sprite => opts.fetch(:sprite, ""),
                        :list => opts.fetch(:list, [TestCmd.new(0, [])]))
    ev = TestGameEvent.new(:id => id, :x => x, :y => y, :name => opts.fetch(:name, "EV#{id}"), :pages => [page])
    $game_map.events[id] = ev
    World.next_frame
    ev
  end

  def hole(id, x, y)
    put(id, x, y, :name => "hole.shadowless", :sprite => "floorHole", :trigger => 2,
                  :list => [TestCmd.new(355, ["floorHole(35)"]), TestCmd.new(0, [])])
  end

  # An open 60 by 30 beach for the kick: walls stop it and the player, wild tiles pop it, solid ones only take no landing.
  def beach(walls = [], wild = [], solid = [])
    inside = lambda { |x, y| x >= 0 && y >= 0 && x < 60 && y < 30 }
    { :open => lambda { |x, y, _d| inside.call(x, y) && !walls.include?([x, y]) },
      :lands => lambda { |x, y, kicker| [x, y] != kicker && inside.call(x, y) && !(walls + solid).include?([x, y]) },
      :pops => lambda { |x, y| wild.include?([x, y]) },
      :stand => lambda { |x, y| inside.call(x, y) && !(walls + solid).include?([x, y]) } }
  end

  def with_env(env)
    sc = class << ball; self; end
    sc.send(:alias_method, :ifh_live_env, :live_env)
    sc.send(:define_method, :live_env) { |_ev| env }
    yield
  ensure
    sc.send(:alias_method, :live_env, :ifh_live_env)
    sc.send(:remove_method, :ifh_live_env)
  end

  def frame
    SpeakCapture.clear
    yield if block_given?
    PokeAccess::Puzzles.tick
    SpeakCapture.lines
  end

  def info_key; PokeAccess::Info.map_text; end

  def listed
    PokeAccess::Puzzles.category_targets.map { |tg| [tg.x, tg.y, tg.name] }.sort_by { |x, y, _n| [x, y] }
  end
end
