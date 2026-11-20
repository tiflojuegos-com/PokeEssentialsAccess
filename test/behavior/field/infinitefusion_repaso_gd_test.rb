# Pokemon Infinite Fusion's puzzles as the review of version 6.9.3 left them (games/infinitefusion/puzzles/), over events
# shaped like the game's: the Ice/Steel chamber's order in var 1122, Ecruteak's checkpoints, Mahogany's still goalie and
# referee, the Saffron Nightclub's dancer, whose own name is the game's quest mark, and the observatory's telescope in the
# dark. What is heard without the puzzle
# assist is what the room shows; the answers come with it. Gamedata pass.
class InfinitefusionRepasoGdTest < PokeAccessTest
  MAPS = [813, 648, 647, 114, 828]
  SWITCHES = [15, 43, 384, 520, 701, 705, 932, 938, 1121, 1132]
  VARS = [1, 336, 1122]
  TEMPLATES = {
    "if_jo_checkpoint" => "checkpoint", "if_jo_checkpoint_return" => "checkpoint return",
    "if_jo_checkpoint_saved" => "checkpoint saved", "if_jo_checkpoint_back" => "checkpoint back",
    "if_jo_checkpoint_leg" => "back to checkpoint", "if_jo_puck_panel" => "puck panel", "if_jo_referee" => "referee",
    "if_jo_referee_back" => "referee back", "if_jo_mahogany_first_hit" => "first hit",
    "if_jo_mahogany_again_hit" => "again hit", "if_jo_mahogany_down_hit" => "down hit",
    "if_jo_mahogany_wall_hit" => "wall hit", "if_jo_mahogany_goalie_hit" => "goalie hit",
    "if_jo_mahogany_goal_hit" => "goal hit", "if_jo_mahogany_reset" => "reset", "ifq_dance_copycat" => "copycat girl",
    "ifo_telescope_dark" => "telescope dark"
  }

  class << self
    attr_accessor :declared
  end

  def setup
    super
    @defs = mechanics.instance_variable_get(:@defs).dup
    @map = $game_map.map_id
    @selfs = $game_self_switches
    @x = $game_player.x
    @y = $game_player.y
    table = PokeAccess::I18n.table(PokeAccess::I18n::REFERENCE)
    @stubbed = TEMPLATES.keys.reject { |key| table.key?(key) }
    @stubbed.each { |key| table[key] = TEMPLATES[key] }
  end

  def teardown
    World.clear_events
    SWITCHES.each { |i| $game_switches[i] = false }
    VARS.each { |i| $game_variables[i] = 0 }
    $game_self_switches = @selfs
    $game_player.x = @x
    $game_player.y = @y
    mechanics.instance_variable_set(:@defs, @defs)
    $game_map.map_id = @map
    PokeAccess::Config.puzzle_assist = false
    mechanics.forget
    PokeAccess::Caches.reset_all
    table = PokeAccess::I18n.table(PokeAccess::I18n::REFERENCE)
    @stubbed.each { |key| table.delete(key) }
    super
  end

  test "the Ice/Steel chamber counts the plates from var 1122 and leaves the general var 1 alone" do
    on_map(813)
    put(87, 65, 25, :tile_id => 862)
    PokeAccess::Config.puzzle_assist = true
    frame { stand(65, 27); $game_variables[1122] = "" }
    refute_includes frame { $game_variables[1] = "ssB" }, plates(3)
    assert_includes frame { $game_variables[1122] = "ss" }, plates(2)
  end

  test "Ecruteak's checkpoints are named, keep walks off and say why the player lands beside the entrance and back" do
    on_map(648)
    checkpoint(220, 1, 19)
    checkpoint(219, 16, 22)
    names = listed.map { |_x, _y, n| n }
    assert_includes names, t(:if_jo_checkpoint)
    assert_includes names, t(:if_jo_checkpoint_return)
    avoids = Harness.declared(648)[:avoids]
    [220, 219].each { |id| assert(avoids.any? { |a| mechanics.picks?(a, @events[id]) }, "EV#{id} kept off") }
    gone = @events[219]
    gone.tile_id = 0
    gone.through = true
    frame
    fire(@events[220])
    assert_equal t(:if_jo_checkpoint_saved), PokeAccess::Puzzles.sent_back_line([1, 19, 648], [16, 22, 648])
    said = frame { $game_switches[1132] = true; stand(16, 22); gone.tile_id = 1240; gone.through = false }
    8.times { said.concat(frame) }
    assert_equal [], said
    fire(@events[219])
    assert_equal t(:if_jo_checkpoint_back), PokeAccess::Puzzles.sent_back_line([16, 22, 648], [1, 19, 648])
  end

  test "Ecruteak's way to Morty takes the tile beside the entrance back to the kept checkpoint, with the assist alone" do
    on_map(648)
    checkpoint(220, 7, 24)
    checkpoint(219, 16, 22)
    put(1, 7, 25, :tile_id => 1241, :name => "skull1")
    stand(16, 22)
    assert_nil PokeAccess::IFEcruteak.hint
    $game_switches[1132] = true
    $game_variables[336] = [7, 24]
    legs = ["1 #{t(:dir_right)}", "1 #{t(:dir_left)}", t(:if_jo_checkpoint_leg), "2 #{t(:dir_down)}"].join(", ")
    way = PokeAccess.sentences([t(:ifx2_route, :legs => legs, :more => ""), t(:ifx2_rhythm)])
    assert_equal way, PokeAccess::IFEcruteak.hint
    refute_includes info_key.to_s, way
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, way
    stand(7, 24)
    assert_equal PokeAccess.sentences([t(:ifx2_route, :legs => "2 #{t(:dir_down)}", :more => ""), t(:ifx2_rhythm)]),
                 PokeAccess::IFEcruteak.hint
  end

  test "Mahogany names the panel, puck, still goalie and referee, and says the referee bringing the puck back" do
    on_map(647)
    rink
    frame
    targets = listed
    [[14, 24, t(:if_jo_puck_panel)], [25, 14, t(:if_jo_goalie)], [14, 8, t(:if_jo_referee)]].each do |tg|
      assert_includes targets, tg
    end
    assert_equal 1, targets.count { |x, y, _n| [x, y] == [14, 20] }
    assert_equal t(:if_jo_puck), PokeAccess::Locator.target_name(@events[2])
    assert_equal [t(:if_jo_referee_back)], frame { $game_switches[1121] = true }
  end

  test "Mahogany's assist gives the next hit from where the puck lies, and nothing without it" do
    on_map(647)
    rink
    stand(14, 21)
    frame
    refute_includes info_key.to_s, t(:if_jo_mahogany_first_hit)
    PokeAccess::Config.puzzle_assist = true
    { [14, 20, 14, 21] => :if_jo_mahogany_first_hit, [14, 13, 14, 21] => :if_jo_mahogany_again_hit,
      [14, 20, 14, 14] => :if_jo_mahogany_down_hit, [14, 23, 13, 23] => :if_jo_mahogany_wall_hit,
      [25, 23, 25, 24] => :if_jo_mahogany_goalie_hit, [25, 15, 24, 15] => :if_jo_mahogany_goal_hit,
      [20, 9, 21, 9] => :if_jo_mahogany_reset }.each do |(px, py, sx, sy), key|
      @events[2].x = px
      @events[2].y = py
      stand(sx, sy)
      assert_includes info_key, t(key), key.to_s
    end
  end

  test "the Saffron Nightclub's dancer is named, not read as the game's quest mark" do
    on_map(114)
    put(7, 7, 6, :sprite => "trchar001", :name => "questNPC(\"saffron_field_1\")")
    assert_equal t(:ifq_dance_copycat), PokeAccess::Locator.target_name(@events[7])
  end

  test "the observatory warns with the assist alone that a telescope used at night in the darkness locks the menu" do
    on_map(828)
    put(9, 9, 2, :list => [TestCmd.new(101, ["Take a look through the telescope?"]), TestCmd.new(0, [])])
    [15, 701, 705].each { |i| $game_switches[i] = true }
    frame
    refute_includes frame { fire(@events[9]) }, t(:ifo_telescope_dark)
    PokeAccess::Config.puzzle_assist = true
    assert_includes frame { fire(@events[9]) }, t(:ifo_telescope_dark)
    $game_switches[705] = false
    refute_includes frame { fire(@events[9]) }, t(:ifo_telescope_dark)
  end

  private

  def t(*args); PokeAccess::I18n.t(*args); end

  def mechanics; PokeAccess::World::Mechanics; end

  def plates(n); t(:puzzle_progress, :label => t(:ifp_plates_order), :n => n, :of => 7); end

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

  def stand(x, y)
    $game_player.x = x
    $game_player.y = y
  end

  # A checkpoint as the game draws it: a touch tile that sends the player off.
  def checkpoint(id, x, y)
    put(id, x, y, :trigger => 1, :tile_id => 1240, :name => "Checkpoint",
                  :list => [TestCmd.new(121, [1132, 1132, 0]), TestCmd.new(201, [0, 648, 16, 22, 4, 0]), TestCmd.new(0, [])])
  end

  # Mahogany's panel, puck, goalie and referee where version 6.9.3 puts them.
  def rink
    put(1, 14, 24, :list => [TestCmd.new(355, ["$scene.reset_map(true)"]), TestCmd.new(0, [])])
    put(2, 14, 20, :sprite => "BW153")
    put(15, 25, 14, :sprite => "hockeyGoaler")
    put(20, 14, 8, :sprite => "BW165")
  end

  def put(id, x, y, opts = {})
    page = TestPage.new(:trigger => opts.fetch(:trigger, 0), :sprite => opts.fetch(:sprite, ""),
                        :list => opts.fetch(:list, [TestCmd.new(101, ["..."]), TestCmd.new(0, [])]))
    ev = TestGameEvent.new(:id => id, :x => x, :y => y, :name => opts.fetch(:name, "EV#{id}"), :tile_id => opts.fetch(:tile_id, 0), :pages => [page])
    $game_map.events[id] = ev
    World.next_frame
    @events[id] = ev
  end

  def fire(ev)
    PokeAccess::Puzzles::Auto.fired($game_system.map_interpreter, PokeAccess.ivar(ev, :@list), ev.id)
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
