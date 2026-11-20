# Pokemon Infinite Fusion's Johto puzzles that stand in the story's way (games/infinitefusion/puzzles/): Azalea's webs, Whitney's
# counts, Violet's wind and sand, the Slowpoke Well, Rocket's choice of passage, Blackthorn's holes, Mahogany's rink, the
# Burned Tower and Ecruteak's platforms, on the shipped profile over events shaped like the game's. Gamedata pass.
class InfinitefusionJohtoPuzzlesGdTest < PokeAccessTest
  MAPS = [337, 524, 363, 340, 449, 455, 456, 377, 426, 647, 697, 704, 611, 696, 648]
  SWITCHES = [38, 39, 40, 43, 145, 147, 357, 360, 361, 362, 383, 384, 520]
  VARS = [5, 135, 136, 137, 149, 150, 158]
  FALLS = [[704, 697], [697, 611], [611, 696]]
  WEBS = { 9 => "A", 14 => "B", 10 => "C", 15 => "D", 13 => "E", 16 => "F", 19 => "G", 17 => "H" }

  class << self
    attr_accessor :declared
  end

  def setup
    super
    @defs = mechanics.instance_variable_get(:@defs).dup
    @map = $game_map.map_id
    @selfs = $game_self_switches
  end

  def teardown
    World.clear_events
    VARS.each { |i| $game_variables[i] = 0 }
    SWITCHES.each { |i| $game_switches[i] = false }
    $game_self_switches = @selfs
    mechanics.instance_variable_set(:@defs, @defs)
    $game_map.map_id = @map
    PokeAccess::Config.puzzle_assist = false
    mechanics.forget
    PokeAccess::Caches.reset_all
    super
  end

  test "Azalea's webs are plain without the assist and by letter with it, and the round is counted with it alone" do
    on_map(337)
    WEBS.each_with_index do |(id, _l), i|
      put(id, 5 + i, 14, :list => [TestCmd.new(355, ["pbSet(5, pbGet(5).to_s + \"A\")"]), TestCmd.new(0, [])])
    end
    $game_variables[136] = "CAB"
    assert_equal [t(:if_jo_azalea_rule)], frame
    assert_equal [t(:if_jo_web_plain)] * 8, listed.map { |_x, _y, n| n }
    assert_equal [], frame { $game_variables[137] = 1; $game_variables[5] = "C" }
    refute_includes info_key, "C, A, B"
    PokeAccess::Config.puzzle_assist = true
    assert_equal WEBS.values.map { |l| t(:if_jo_web, :letter => l) }.sort, listed.map { |_x, _y, n| n }.sort
    assert_includes info_key, t(:if_jo_azalea_order, :order => "C, A, B")
    assert_equal [progress(2, 3)], frame { $game_variables[137] = 2; $game_variables[5] = "CA" }
    assert_equal [PokeAccess.sentences([t(:puzzle_reset), progress(0, 3)])], frame { $game_variables[137] = 0; $game_variables[5] = "" }
  end

  test "Azalea's second round opens with its order, Kurt's talk leaves the count alone and two rounds end the puzzle" do
    on_map(337)
    $game_variables[136] = "CAB"
    frame
    PokeAccess::Config.puzzle_assist = true
    $game_variables[137] = 3
    $game_variables[5] = "CAB"
    assert_equal [progress(3, 3)], frame
    assert_equal [t(:if_jo_azalea_order, :order => "C, A, B, E, D")], frame { $game_variables[136] = "CABED"; $game_variables[5] = "" }
    assert_equal [], frame { $game_variables[5] = "Bug" }, "the type name Kurt writes into the entered code"
    assert_equal [progress(1, 5)], frame { $game_variables[137] = 1; $game_variables[5] = "C" }
    assert_includes info_key, t(:if_jo_azalea_order, :order => "C, A, B, E, D")
    $game_variables[135] = 2
    assert_equal [], frame { $game_variables[136] = "CABEDFGH" }
    refute_includes info_key, "C, A, B, E, D"
    on_map(337)
    assert_equal [], frame
  end

  test "Whitney's Pokemon are never listed, her rule is said until she is beaten and a wrong count is only a battle" do
    on_map(524)
    put(14, 5, 42, :sprite => "174_0", :name => "pk1")
    put(17, 4, 42, :sprite => "173_0", :name => "pk2")
    assert_equal [t(:if_jo_whitney_rule)], frame
    assert_empty listed
    refute_includes info_key, t(:if_jo_whitney_hint)
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, t(:if_jo_whitney_hint)
    on_map(524)
    $game_switches[38] = true
    assert_equal [], frame
  end

  test "Violet's fall from the sand is said as one, the soft wind as it starts and the rule until Falkner is beaten" do
    on_map(363)
    assert_equal [t(:if_jo_violet_rule)], frame
    assert_equal t(:if_jo_violet_fall), PokeAccess::Puzzles.sent_back_line([20, 8, 363], [6, 8, 363])
    assert_nil PokeAccess::Puzzles.sent_back_line([5, 8, 363], [6, 8, 363])
    assert_equal ["#{t(:if_jo_wind)}: #{t(:if_jo_wind_on)}"], frame { $game_switches[357] = true }
    on_map(363)
    $game_switches[40] = true
    assert_equal [], frame
  end

  test "the Slowpoke Well names its Slowpoke and Shellders, counts the freed ones and gives the hole with the assist" do
    on_map(340)
    [6, 7, 10, 13].each_with_index { |id, i| put(id, 25 + i, 15, :sprite => "079s", :name => "StrengthBoulder", :list => [TestCmd.new(355, ["pbPushThisBoulder"]), TestCmd.new(0, [])]) }
    [5, 9, 11, 12].each_with_index { |id, i| put(id, 15 + i % 2, 13 + i / 2, :sprite => "090") }
    frame
    names = listed.map { |_x, _y, n| n }
    assert_equal 4, names.count(t(:if_jo_slowpoke))
    assert_equal 4, names.count(t(:if_jo_shellder))
    assert_equal [progress(1, 4, :if_jo_shellders)], frame { $game_variables[158] = 1 }
    assert_empty spots
    PokeAccess::Config.puzzle_assist = true
    assert_equal [[16, 14]], spots
    $game_variables[158] = 0
    assert_equal [[17, 14]], spots
  end

  test "Rocket's strips are listed on each side only while Erika asks for the choice" do
    on_map(449)
    put(9, 14, 6, :trigger => 1, :list => choice_list)
    put(11, 6, 6, :trigger => 1, :list => choice_list)
    frame
    assert_empty listed
    $game_switches[145] = true
    assert_equal [[6, 6, t(:if_jo_rocket_left)], [14, 6, t(:if_jo_rocket_right)]], listed
    $game_switches[147] = true
    assert_empty listed
    assert_nil PokeAccess::Sound::Scene.family_of($game_map.events[9])
  end

  test "Blackthorn's holes are listed as drops, a filled one goes down to the bridge, and the rule is said once" do
    on_map(426)
    assert_equal [t(:if_jo_blackthorn_rule)], frame
    assert_equal [[7, 9, t(:if_jo_hole)], [13, 5, t(:if_jo_hole)], [13, 12, t(:if_jo_hole)]], listed
    assert_equal [progress(1, 3, :if_jo_holes_filled)], frame { $game_switches[360] = true }
    assert_equal [[7, 9, t(:if_jo_hole_down)], [13, 5, t(:if_jo_hole)], [13, 12, t(:if_jo_hole)]], listed
    assert_equal [progress(2, 3, :if_jo_holes_filled)], frame { $game_switches[362] = true }
    assert_equal [[7, 9, t(:if_jo_hole_down)], [13, 5, t(:if_jo_hole_down)], [13, 12, t(:if_jo_hole)]], listed
    refute_includes info_key, t(:if_jo_blackthorn_hint)
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, t(:if_jo_blackthorn_hint)
    on_map(426)
    assert_equal [], frame
  end

  test "Blackthorn's east part lists its own three holes and says nothing on arriving" do
    on_map(377)
    assert_equal [], frame
    assert_equal [[42, 9, t(:if_jo_hole)], [48, 5, t(:if_jo_hole)], [48, 12, t(:if_jo_hole)]], listed
    frame { $game_switches[361] = true }
    assert_equal [[42, 9, t(:if_jo_hole)], [48, 5, t(:if_jo_hole)], [48, 12, t(:if_jo_hole_down)]], listed
  end

  test "Mahogany's puck, goal and goalie are named, the puck's slide followed and the goal said once" do
    on_map(647)
    put(2, 14, 20, :sprite => "BW153")
    put(11, 28, 16, :tile_id => 3136)
    put(15, 25, 14, :sprite => "hockeyGoaler")
    frame
    assert_equal [[14, 20, "EV2"], [25, 14, t(:if_jo_goalie)], [28, 16, t(:if_jo_goal_post)]], listed
    $game_map.events[2].x = 20
    out = frame
    assert_equal 1, out.length
    assert_includes out[0], t(:if_jo_puck)
    refute_includes info_key, t(:if_jo_mahogany_reset)
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, t(:if_jo_mahogany_reset)
    PokeAccess::Config.puzzle_assist = false
    assert_equal [t(:if_jo_goal_scored)], frame { $game_switches[384] = true }
  end

  test "the Burned Tower names its gaps and says the gym opening" do
    on_map(697)
    put(11, 21, 8, :trigger => 1)
    put(13, 23, 5, :trigger => 1)
    assert_equal [t(:if_jo_tower_rule, :item => PokeAccess::Data.item_name(:WAILMERPAIL).to_s)], frame
    assert_equal [[21, 8, t(:if_jo_gap)], [23, 5, t(:if_jo_gap)]], listed
    assert_equal ["#{t(:if_jo_ecruteak_gym)}: #{t(:if_jo_gym_open)}"], frame { $game_switches[383] = true }
  end

  test "the Burned Tower says a fall only where the sand landed the player, never on the stairs" do
    FALLS.each do |from, to|
      on_map(to)
      frame
      drop_vars(to, 18, 13)
      stand(18, 13)
      assert_equal t(:if_jo_tower_fall), PokeAccess::Puzzles.sent_back_line([18, 13, from], [18, 13, to], :map), "#{from} to #{to}"
      stand(9, 7)
      assert_nil PokeAccess::Puzzles.sent_back_line([9, 6, from], [9, 7, to], :map), "stairs #{from} to #{to}"
      drop_vars(from, 18, 13)
      stand(18, 13)
      assert_nil PokeAccess::Puzzles.sent_back_line([18, 12, from], [18, 13, to], :map), "stale variables #{from} to #{to}"
    end
  end

  test "the Burned Tower's moving ghosts are declared on both floors" do
    declare_puzzles
    assert_equal [4, 6, 7, 8], ghosts(697)
    assert_equal [1, 3, 4, 8, 9, 10], ghosts(704)
  end

  test "Ecruteak's platforms are listed while drawn, the shortcut is said when it sets and the rule stops with Morty beaten" do
    on_map(648)
    put(1, 17, 20, :tile_id => 1241, :name => "skull1")
    put(2, 18, 20, :tile_id => 1240, :name => "skull2")
    assert_equal [t(:if_jo_ecruteak_rule)], frame
    assert_equal 2, listed.length
    assert_equal [t(:if_jo_skull)], listed.map { |_x, _y, n| n }.uniq
    assert_equal ["#{t(:if_jo_shortcut)}: #{t(:if_jo_shortcut_on)}"], frame { $game_switches[520] = true }
    on_map(648)
    $game_switches[43] = true
    assert_equal [], frame
  end

  private

  def t(*args); PokeAccess::I18n.t(*args); end

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
    @events = {}
    PokeAccess::Caches.reset_all
    mechanics.forget
  end

  def drop_vars(map, x, y)
    $game_variables[5] = map
    $game_variables[149] = x
    $game_variables[150] = y
  end

  def stand(x, y)
    $game_player.x = x
    $game_player.y = y
  end

  def ghosts(map); Harness.declared(map)[:obstacles].map { |o| o[:events].keys }.flatten.sort; end

  def put(id, x, y, opts = {})
    page = TestPage.new(:trigger => opts.fetch(:trigger, 0), :sprite => opts.fetch(:sprite, ""),
                        :list => opts.fetch(:list, [TestCmd.new(101, ["..."]), TestCmd.new(0, [])]))
    ev = TestGameEvent.new(:id => id, :x => x, :y => y, :name => opts.fetch(:name, "EV#{id}"), :tile_id => opts.fetch(:tile_id, 0), :pages => [page])
    $game_map.events[id] = ev
    World.next_frame
    @events[id] = ev
  end

  def choice_list
    [TestCmd.new(101, ["Going that way?"]), TestCmd.new(102, [%w[Yes No], 2]), TestCmd.new(402, [0, "Yes"]),
     TestCmd.new(121, [147, 147, 0], 1), TestCmd.new(404)]
  end

  def progress(n, of, label = :if_jo_webs); t(:puzzle_progress, :label => t(label), :n => n, :of => of); end

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

  def spots; listed.select { |_x, _y, n| n == t(:if_jo_slowpoke_goal) }.map { |x, y, _n| [x, y] }; end
end
