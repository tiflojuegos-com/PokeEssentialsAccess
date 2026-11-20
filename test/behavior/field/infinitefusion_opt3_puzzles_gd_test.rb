# Pokemon Infinite Fusion's optional puzzles of the third batch (games/infinitefusion/puzzles/): the Rocket Warehouse's switch,
# Kindle Road's large boulder, Ilex Forest's clearing, the Moonlit Forest's sheep, the cyberspace
# Porygon, the Saffron Nightclub's dance, the nest hats, the Ruby Chamber's stairs and Sky Pillar's cracked tiles, on the shipped profile over events shaped like the game's. Gamedata pass.
class InfinitefusionOpt3PuzzlesGdTest < PokeAccessTest
  MAPS = [625, 559, 266, 824, 423, 114, 78, 445, 95, 491, 827, 444, 569, 634, 639, 683, 680, 684]
  SWITCHES = [415, 451, 1020, 1021, 112, 938, 932, 893, 1030, 522, 572, 573]
  VARIABLES = [54, 105, 104, 278, 284]

  class << self
    attr_accessor :declared
  end

  def setup
    super
    @defs = mechanics.instance_variable_get(:@defs).dup
    @map = $game_map.map_id
    @selfs = $game_self_switches
    Object.send(:define_method, :hasHat?) { |id| ($ifq_hats || []).include?(id) }
  end

  def teardown
    World.clear_events
    $ifq_hats = nil
    Object.send(:remove_method, :hasHat?)
    VARIABLES.each { |i| $game_variables[i] = 0 }
    SWITCHES.each { |i| $game_switches[i] = false }
    $game_self_switches = @selfs
    mechanics.instance_variable_set(:@defs, @defs)
    $game_map.map_id = @map
    PokeAccess::Config.puzzle_assist = false
    mechanics.forget
    PokeAccess::Caches.reset_all
    super
  end

  test "the warehouse's switch and doors are named, the doors' state is told and the hint is for the assist" do
    on_map(625)
    put(8, 26, 2, :list => choice_list)
    put(4, 16, 9, :tile_id => 1172)
    put(7, 17, 9, :tile_id => 1173)
    assert_equal [t(:ifq_wh_door), t(:ifq_wh_door), t(:ifq_wh_switch)].sort, listed.map { |_x, _y, n| n }.sort
    assert_includes frame { $game_switches[415] = true }.join(" "), t(:ifq_wh_open)
    refute_includes info_key, t(:ifq_wh_hint)
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, t(:ifq_wh_hint)
  end

  test "the large boulder is one object beside its trainer, and the piece to push is told with the assist" do
    on_map(559)
    [[1, 16, 35], [2, 15, 35], [3, 14, 35], [4, 14, 34], [5, 15, 34], [6, 16, 34]].each { |id, x, y| put(id, x, y, :tile_id => 2845) }
    put(23, 17, 35, :sprite => "BW (43)")
    names = listed.map { |_x, _y, n| n }
    assert_equal [t(:ifq_boulder), t(:ifq_boulder_guy)].sort, names.sort
    refute_includes info_key, t(:ifq_boulder_hint)
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, t(:ifq_boulder_hint)
    assert_includes listed.map { |_x, _y, n| n }, t(:ifq_boulder_push)
    $game_switches[451] = true
    refute_includes info_key, t(:ifq_boulder_hint)
  end

  test "Ilex Forest's clearing tells its rule and the scare, and the wait between steps only with the assist" do
    on_map(266)
    put(32, 50, 15, :sprite => "172_0")
    assert_equal [t(:ifq_ilex_sleeper)], listed.map { |_x, _y, n| n }
    refute_includes info_key, t(:ifq_ilex_hint)
    assert_includes frame { $game_switches[1020] = true }, t(:ifq_ilex_rule)
    refute_includes info_key, t(:ifq_ilex_hint)
    assert_includes frame { $game_switches[1021] = true }, t(:ifq_ilex_spooked)
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, t(:ifq_ilex_hint)
  end

  test "the sheep are named by their real graphic and the counts are said with the assist, by the page's own variable" do
    on_map(824)
    put(13, 25, 39, :sprite => "179_0")
    put(16, 28, 41, :sprite => "179s_0")
    put(33, 26, 41, :sprite => "180_0")
    counter = put(36, 8, 24, :sprite => "096")
    species = lambda { |n| PokeAccess::Data.species_name(n) }
    assert_equal [species.call(180), species.call(179), species.call(179)].sort, listed.map { |_x, _y, n| n }.sort.first(3)
    $game_variables[278] = 14
    $game_variables[284] = 4
    assert_equal [], frame { fire(counter) }
    PokeAccess::Config.puzzle_assist = true
    assert_equal [t(:puzzle_answer, :a => "14")], frame { fire(counter) }
    $game_self_switches[[824, 32, "A"]] = true
    asker = put(32, 47, 42, :sprite => "096")
    assert_equal [t(:puzzle_answer, :a => "4")], frame { fire(asker) }
  end

  test "the cyberspace's Porygon rule and jumps are told, the way out is named and the talks to make are counted from where it is" do
    on_map(423)
    put(6, 17, 19)
    assert_equal [t(:ifq_porygon_rule)], frame
    assert_equal [t(:ifq_cyber_exit)], listed.map { |_x, _y, n| n }
    assert_includes frame { $game_variables[54] = 3 }.join(" "), t(:ifq_porygon_jumped)
    assert_includes frame { $game_variables[54] = 0 }.join(" "), t(:ifq_porygon_home)
    refute_match(/porygon \d+:/, info_key)
    PokeAccess::Config.puzzle_assist = true
    $game_variables[54] = 0
    assert_includes info_key, t(:ifq_porygon_hint, :n => 7, :ways => %w[right left down left left down down].map { |w| t("ifq_face_#{w}".to_sym) }.join(", "))
    $game_variables[54] = 12
    assert_includes info_key, t(:ifq_porygon_hint, :n => 1, :ways => t(:ifq_face_down))
    $game_switches[112] = true
    refute_includes info_key, "porygon"
  end

  test "the dance tiles are named and the round's moves are said with the assist, by the round in variable 105" do
    on_map(114)
    [[10, 10, 6], [11, 10, 7], [12, 11, 6], [13, 9, 6], [14, 10, 5]].each { |id, x, y| put(id, x, y, :tile_id => 403) }
    $game_switches[935] = true
    $game_switches[937] = true
    $game_switches[932] = true
    assert_equal [t(:ifq_dance_center), t(:ifq_dance_tile_down), t(:ifq_dance_tile_right), t(:ifq_dance_tile_left),
                  t(:ifq_dance_tile_up)].sort, listed.map { |_x, _y, n| n }.sort
    refute_match(/round \d:/, info_key)
    PokeAccess::Config.puzzle_assist = true
    moves = lambda { |*ways| ways.map { |w| t("ifq_face_#{w}".to_sym) }.join(", ") }
    assert_equal t(:ifq_dance_hint, :round => 1, :moves => moves.call(:down, :left, :down, :left)), info_key
    $game_variables[105] = 1
    assert_equal t(:ifq_dance_hint, :round => 2, :moves => moves.call(:up, :left, :down, :left, :down)), info_key
    $game_variables[105] = 2
    assert_equal t(:ifq_dance_hint, :round => 3, :moves => moves.call(:left, :right, :down, :right, :down)), info_key
  end

  test "the dancer's turns are told at its \"Got it?\" without the assist, by the round" do
    on_map(114)
    put(7, 10, 4, :sprite => "dancer")
    put(10, 10, 6, :tile_id => 403)
    $game_switches[932] = true
    shown = lambda do |round|
      $game_variables[105] = round
      list = [TestCmd.new(101, ["Try this!"]), TestCmd.new(101, ["Got it? Okay, your turn!"]), TestCmd.new(0, [])]
      PokeAccess.take_tail
      PokeAccess::Puzzles::Reach.before_text(page_at(list, 1, 10))
      PokeAccess.take_tail
    end
    moves = lambda { |*ways| ways.map { |w| t("ifq_face_#{w}".to_sym) }.join(", ") }
    assert_equal t(:ifq_dance_shown, :moves => moves.call(:down, :left, :down, :left)), shown.call(0)
    assert_equal t(:ifq_dance_shown, :moves => moves.call(:up, :left, :down, :left, :down)), shown.call(1)
    assert_equal t(:ifq_dance_shown, :moves => moves.call(:left, :right, :down, :right, :down)), shown.call(2)
  end

  test "a nest's Pokemon is told as it comes near and flees, and the way to wake it only with the assist" do
    on_map(78)
    put(10, 10, 3, :sprite => "")
    assert_equal [], frame
    assert_includes frame { put(10, 10, 3, :sprite => "pidgey-flying") }.join(" "), t(:ifq_nest_here)
    assert_includes frame { put(10, 10, 3, :sprite => "") }.join(" "), t(:ifq_nest_fled)
    refute_includes info_key, t(:ifq_nest_hint_still)
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, t(:ifq_nest_hint_still)
    on_map(95)
    [81, 82, 83, 86, 87].each_with_index { |id, i| put(id, 36 + i, 20) }
    assert_equal [], listed
    PokeAccess::Config.puzzle_assist = true
    assert_equal [t(:ifq_nest_square)] * 5, listed.map { |_x, _y, n| n }
    assert_includes info_key, t(:ifq_nest_hint_squares)
    $ifq_hats = %w[eevee]
    refute_includes info_key, t(:ifq_nest_hint_squares)
  end

  test "Route 15's Goomy nest is told as it comes near, with its own hint north of row 20, until its hat is owned" do
    on_map(444)
    put(29, 15, 18, :sprite => "")
    assert_equal [], frame
    assert_includes frame { put(29, 11, 18, :sprite => "GOOMY") }.join(" "), t(:ifq_nest_here)
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, t(:ifq_nest_hint_north)
    refute_includes info_key, t(:ifq_nest_hint_still)
    $ifq_hats = %w[headgoomy]
    refute_includes info_key, t(:ifq_nest_hint_north)
  end

  test "Viridian's hint is only for a visit where a Pikachu is drawn, and no nest says anything once its hats are owned" do
    on_map(491)
    PokeAccess::Config.puzzle_assist = true
    refute_includes info_key, t(:ifq_nest_hint_still)
    put(58, 4, 18, :sprite => "")
    assert_includes info_key, t(:ifq_nest_hint_still)
    put(59, 4, 19, :sprite => "")
    $ifq_hats = %w[pikhatchum]
    assert_includes info_key, t(:ifq_nest_hint_still)
    $ifq_hats = %w[pikhatchum pikhatchuf]
    refute_includes info_key, t(:ifq_nest_hint_still)
    $ifq_hats = %w[pikhatchum]
    $game_map.events.delete(59)
    World.next_frame
    refute_includes info_key, t(:ifq_nest_hint_still)
    on_map(78)
    PokeAccess::Config.puzzle_assist = true
    put(10, 10, 3, :sprite => "")
    $ifq_hats = []
    assert_includes info_key, t(:ifq_nest_hint_still)
    $ifq_hats = %w[pidgey]
    refute_includes info_key, t(:ifq_nest_hint_still)
  end

  test "the Ruby Chamber's stairs are named by where they lead" do
    on_map(569)
    put(5, 12, 4)
    put(12, 12, 9)
    assert_equal [t(:ifq_stairs_down), t(:ifq_stairs_up)].sort, listed.map { |_x, _y, n| n }.sort
  end

  test "the Ruby Chamber says with the assist alone what the stairs down need, then which lead to the ruby, and no more once it is thrown" do
    on_map(569)
    put(5, 12, 4)
    put(62, 16, 14, :sprite => "BW021")
    refute_includes info_key, t(:ifq_ruby_cream)
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, t(:ifq_ruby_cream)
    refute_includes info_key, t(:ifq_ruby_way)
    $game_switches[573] = true
    assert_includes info_key, t(:ifq_ruby_way)
    refute_includes info_key, t(:ifq_ruby_cream)
    bag = $PokemonBag
    $PokemonBag = Struct.new(:ruby) { def pbQuantity(item); item == :RUBY ? ruby : 0; end }.new(1)
    refute_includes info_key, t(:ifq_ruby_way)
    assert_includes info_key, t(:ifq_ruby_lava)
    $PokemonBag = bag
    $game_switches[572] = true
    refute_includes info_key, t(:ifq_ruby_way)
  end

  test "Sky Pillar's cracked tiles are traps with the rule on arriving" do
    on_map(639)
    put(4, 4, 7, :sprite => "BW154")
    assert_equal [t(:ifq_sky_rule)], frame
    assert_equal [], listed
    assert_equal [:mover], Harness.declared(639)[:obstacles].map { |o| o[:kind] }
    refute_empty Harness.declared(639)[:avoids]
    ev = $game_map.events[4]
    assert PokeAccess::World::Mechanics.picks?(Harness.declared(639)[:avoids].first, ev)
  end

  test "the Deep Sea's rooms tell what they are once, and what the assist leaves out" do
    on_map(683)
    assert_equal [t(:ifq_deep_rule)], frame
    on_map(683)
    assert_equal [], frame
    on_map(680)
    PokeAccess::Config.puzzle_assist = true
    assert_equal [t(:ifq_deep_assist)], frame
  end

  test "the Deep Sea's exits that get no nearer come back to the lists once the sapphire is taken" do
    on_map(680)
    put(4, 4, 4)
    ev = $game_map.events[4]
    assert_equal false, PokeAccess::Locator.hidden?(ev)
    PokeAccess::Config.puzzle_assist = true
    assert_equal true, PokeAccess::Locator.hidden?(ev)
    $game_switches[522] = true
    assert_equal false, PokeAccess::Locator.hidden?(ev)
  end

  test "the Deep Sea's rooms say nothing on arriving once the sapphire is taken" do
    $game_switches[522] = true
    on_map(684)
    PokeAccess::Config.puzzle_assist = true
    assert_equal [], frame
  end

  private

  def t(key, vars = nil); PokeAccess::I18n.t(key, vars); end

  def mechanics; PokeAccess::World::Mechanics; end

  def declare_puzzles
    self.class.declared ||= begin
      Harness.load_puzzles("infinitefusion")
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
    $game_map.map_id = map
    PokeAccess::Caches.reset_all
    mechanics.forget
  end

  def put(id, x, y, opts = {})
    page = TestPage.new(:trigger => opts.fetch(:trigger, 0), :sprite => opts.fetch(:sprite, ""),
                        :list => opts.fetch(:list, [TestCmd.new(101, ["..."]), TestCmd.new(0, [])]),
                        :condition => opts.fetch(:condition, {}))
    ev = TestGameEvent.new(:id => id, :x => x, :y => y, :name => opts.fetch(:name, "EV#{id}"), :tile_id => opts.fetch(:tile_id, 0), :pages => [page])
    $game_map.events[id] = ev
    World.next_frame
    ev
  end

  def choice_list
    [TestCmd.new(101, ["Press it?"]), TestCmd.new(102, [%w[Yes No], 2]), TestCmd.new(402, [0, "Yes"]), TestCmd.new(404)]
  end

  def fire(ev)
    PokeAccess::Puzzles::Auto.fired($game_system.map_interpreter, PokeAccess.ivar(ev, :@list), ev.id)
  end

  def page_at(list, i, id)
    int = Object.new
    { :@list => list, :@index => i, :@event_id => id, :@branch => { 0 => nil } }.each { |k, v| int.instance_variable_set(k, v) }
    int
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
