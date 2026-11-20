# Keishou's story puzzles (games/keishou/puzzles/) on the shipped profile over events shaped like the game's: the gem sockets of
# Suna Beach, Nami's monkeys, the Kurai of Noyanagi, the carrot of Shimo Mountain, the graves of Kiri Forest, the door of the
# Coastal Cave, the volcano's steps and ice and the rocks of Sakyu's ruins. What is heard without the puzzle assist is the
# room and its state; the answers come with it. Gamedata pass.
class KeishouPuzzlesGdTest < PokeAccessTest
  MAPS = [82, 88, 92, 94, 101, 123, 136, 139, 155, 169, 183, 184, 190]
  VolcanoState = Struct.new(:stepsV)

  class << self
    attr_accessor :declared
  end

  def setup
    super
    Object.class_eval do
      private

      def pbInVolcano?; !$keishou_volcano.nil?; end

      def pbVolcanoState; $keishou_volcano; end
    end
    @defs = mechanics.instance_variable_get(:@defs).dup
    @map = $game_map.map_id
    @selfs = $game_self_switches
  end

  def teardown
    World.clear_events
    [35, 39, 42, 66].each { |i| $game_variables[i] = 0 }
    [76, 77].each { |i| $game_switches[i] = false }
    $game_self_switches = @selfs
    mechanics.instance_variable_set(:@defs, @defs)
    $game_map.map_id = @map
    PokeAccess::Config.puzzle_assist = false
    $keishou_volcano = nil
    [:pbInVolcano?, :pbVolcanoState].each { |m| Object.send(:remove_method, m) }
    mechanics.forget
    PokeAccess::Caches.reset_all
    super
  end

  test "the five sockets of Suna Beach are named, with the gem each takes only with the assist" do
    on_map(94)
    [[5, 41, 27], [6, 46, 31], [7, 44, 37], [8, 38, 37], [9, 36, 31]].each { |id, x, y| silent(id, x, y) }
    assert_equal [[36, 31, t(:ks_socket)], [38, 37, t(:ks_socket)], [41, 27, t(:ks_socket)], [44, 37, t(:ks_socket)],
                  [46, 31, t(:ks_socket)]], listed
    PokeAccess::Config.puzzle_assist = true
    assert_equal [[36, 31, socket(:green)], [38, 37, socket(:yellow)], [41, 27, socket(:blue)], [44, 37, socket(:purple)],
                  [46, 31, socket(:red)]], listed
  end

  test "Suna Beach counts the sockets only with the assist, since the game shows nothing of a wrong gem, and says nothing more once the gate is open" do
    on_map(94)
    silent(5, 41, 27)
    frame
    assert_equal [], frame { $game_variables[42] = 1 }
    refute_includes info_key.to_s, t(:ks_sockets_set)
    PokeAccess::Config.puzzle_assist = true
    assert_equal [progress(:ks_sockets_set, 2, 5)], frame { $game_variables[42] = 2 }
    assert_includes info_key, progress(:ks_sockets_set, 2, 5)
    PokeAccess::Config.puzzle_assist = false
    PokeAccess::Config.verbosity = :full
    on_map(94)
    assert_equal [t(:ks_sockets_rule)], frame
    $game_variables[42] = 5
    on_map(94)
    $game_variables[42] = 5
    assert_equal [], frame
  end

  test "the monkeys are counted as found from Nami's request, hinted with the assist, and the count stops with the shrine fight" do
    on_map(88)
    PokeAccess::Config.puzzle_assist = true
    assert_nil PokeAccess::Puzzles.info_line
    $game_self_switches[[88, 2, "A"]] = true
    assert_equal t(:ks_monkeys_hint, :list => [:ks_monkey_pansear, :ks_monkey_pansage, :ks_monkey_panpour].map { |k| t(k) }.join(", ")),
                 hint_text
    assert_includes info_key, hint_text
    $game_self_switches[[88, 19, "A"]] = true
    $game_self_switches[[384, 6, "A"]] = true
    assert_equal t(:ks_monkeys_hint, :list => t(:ks_monkey_pansage)), hint_text
    $game_self_switches[[101, 2, "A"]] = true
    assert_equal t(:ks_monkeys_done), hint_text
    assert_includes info_key, t(:ks_monkeys_done)
    PokeAccess::Config.puzzle_assist = false
    assert_equal [progress(:ks_monkeys, 1, 3)], frame { $game_variables[39] = 1 }
    assert_equal [progress(:ks_monkeys, 2, 3)], frame { $game_variables[39] = 2 }
    assert_includes info_key, progress(:ks_monkeys, 2, 3)
    on_map(92)
    $game_self_switches[[88, 2, "A"]] = true
    $game_variables[39] = 3
    assert_includes info_key, progress(:ks_monkeys, 3, 3)
    $game_self_switches[[92, 4, "B"]] = true
    assert_nil PokeAccess::Puzzles.info_line
  end

  test "the monkeys say nothing before Nami asks for them" do
    on_map(101)
    assert_nil PokeAccess::Puzzles.info_line
    assert_equal [], frame { $game_variables[39] = 0 }
    PokeAccess::Config.puzzle_assist = true
    assert_nil PokeAccess::Puzzles.info_line
  end

  test "the invisible monkey at the shrine door is named until it shows, then keeps its own name" do
    on_map(92)
    ev = silent(4, 14, 30)
    assert_equal [[14, 30, t(:ks_invisible_block)]], listed
    assert_equal t(:ks_invisible_block), PokeAccess::Puzzles.piece_name(ev)
    $game_self_switches[[92, 4, "A"]] = true
    assert_equal [], listed
    assert_nil PokeAccess::Puzzles.piece_name(ev)
    $game_self_switches[[92, 4, "B"]] = true
    assert_nil PokeAccess::Puzzles.piece_name(ev)
  end

  test "the Kurai of Noyanagi are named only with the assist, and keep their own name once they show" do
    on_map(82)
    evs = [[9, 18, 4], [12, 19, 19], [13, 36, 3]].map { |id, x, y| silent(id, x, y) }
    assert_equal [], listed
    assert_equal [t(:ks_kurai_rule)], frame { $game_variables[35] = 1 }
    assert_equal [], listed
    evs.each { |ev| assert_nil PokeAccess::Puzzles.piece_name(ev) }
    PokeAccess::Config.puzzle_assist = true
    assert_equal [[18, 4, t(:ks_kurai_hidden)], [19, 19, t(:ks_kurai_hidden)], [36, 3, t(:ks_kurai_hidden)]], listed
    evs.each { |ev| assert_equal t(:ks_kurai_hidden), PokeAccess::Puzzles.piece_name(ev) }
    $game_self_switches[[82, 12, "C"]] = true
    assert_equal [[18, 4, t(:ks_kurai_hidden)], [36, 3, t(:ks_kurai_hidden)]], listed
    assert_nil PokeAccess::Puzzles.piece_name(evs[1])
    $game_self_switches[[82, 12, "D"]] = true
    assert_nil PokeAccess::Puzzles.piece_name(evs[1])
  end

  test "the Kurai count is said once as it grows and once in the info key, and the hint is the assist's" do
    on_map(82)
    $game_variables[35] = 1
    frame
    PokeAccess::Config.puzzle_assist = false
    assert_equal [progress(:ks_kurai_found, 1, 3)], frame { $game_variables[35] = 2 }
    line = "#{t(:ks_kurai_rule)}. #{progress(:ks_kurai_found, 1, 3)}"
    assert_equal line, info_key
    PokeAccess::Config.puzzle_assist = true
    assert_equal "#{line}. #{t(:ks_kurai_hint)}", info_key
    assert_equal [progress(:ks_kurai_found, 3, 3)], frame { $game_variables[35] = 4 }
    assert_nil PokeAccess::Puzzles.info_line
  end

  test "the soil, the petal and the altar of Shimo Mountain are named, and the carrot's way, with its one-seed choice, is the assist's until the offering" do
    on_map(169)
    silent(2, 18, 14)
    silent(4, 20, 47)
    assert_equal [[18, 14, t(:ks_radiant_petal)], [20, 47, t(:ks_carrot_soil)]], listed
    refute_includes info_key.to_s, t(:ks_carrot_hint)
    PokeAccess::Config.puzzle_assist = true
    assert_equal t(:ks_carrot_hint), info_key
    PokeAccess::Config.puzzle_assist = false
    $game_self_switches[[169, 2, "A"]] = true
    $game_switches[77] = true
    assert_equal [], listed
    on_map(155)
    silent(4, 25, 22)
    assert_equal [[25, 22, t(:ks_carrot_altar)]], listed
    PokeAccess::Config.puzzle_assist = true
    assert_equal t(:ks_carrot_hint), info_key
    $game_self_switches[[155, 4, "A"]] = true
    assert_equal [], listed
    $game_self_switches[[155, 4, "C"]] = true
    assert_nil PokeAccess::Puzzles.info_line
    on_map(176)
    $game_self_switches[[155, 4, "C"]] = true
    assert_nil PokeAccess::Puzzles.info_line
  end

  test "Kiri Forest names its graves, the golden one only with the assist and the way down once open, and counts the plates of the Ancient Grave" do
    on_map(183)
    grave = silent(16, 14, 42)
    silent(18, 5, 36)
    assert_equal [[5, 36, t(:ks_grave)], [14, 42, t(:ks_grave)]], listed
    PokeAccess::Config.puzzle_assist = true
    assert_equal [[5, 36, t(:ks_grave)], [14, 42, t(:ks_grave_golden)]], listed
    $game_self_switches[[183, 16, "A"]] = true
    assert_equal [[5, 36, t(:ks_grave)], [14, 42, t(:ks_grave_descent)]], listed
    PokeAccess::Config.puzzle_assist = false
    assert_equal t(:ks_grave_descent), PokeAccess::Puzzles.piece_name(grave)
    on_map(190)
    silent(6, 20, 12)
    silent(7, 12, 20)
    silent(8, 16, 20)
    assert_equal [[12, 20, t(:ks_plate_socket)], [16, 20, t(:ks_plate_socket)], [20, 12, t(:ks_shield_socket)]], listed
    assert_equal [progress(:ks_plates_set, 1, 2)], frame { $game_variables[66] = 1 }
    assert_includes info_key, progress(:ks_plates_set, 1, 2)
    $game_self_switches[[190, 6, "A"]] = true
    assert_equal [[12, 20, t(:ks_plate_socket)], [16, 20, t(:ks_plate_socket)]], listed
  end

  test "the sealed door of the Coastal Cave says what opens it only with the assist, and each plate gives its Unown letters" do
    on_map(184)
    silent(9, 17, 7)
    [[21, 7, 46], [17, 8, 46], [22, 9, 46], [19, 25, 46], [18, 26, 46], [20, 27, 46]].each { |id, x, y| silent(id, x, y) }
    plates = [[7, 46, plate("AERO")], [8, 46, plate("AERO")], [9, 46, plate("AERO")], [25, 46, plate("DACT")],
              [26, 46, plate("DACT")], [27, 46, plate("DACT")]]
    assert_equal sorted(plates + [[17, 7, t(:ks_coast_door)]]), listed
    PokeAccess::Config.puzzle_assist = true
    assert_equal sorted(plates + [[17, 7, t(:ks_coast_door_key)]]), listed
    $game_self_switches[[184, 9, "A"]] = true
    assert_equal plates, listed
  end

  test "the volcano says its rule once, and the info key the steps left, warning of few with the assist" do
    on_map(123)
    $keishou_volcano = VolcanoState.new(80)
    PokeAccess::Config.verbosity = :full
    assert_equal [t(:ks_volcano_rule)], frame
    assert_equal "#{t(:ks_volcano_steps, :n => 80)}. #{t(:ks_volcano_rule)}", info_key
    $keishou_volcano.stepsV = 10
    assert_equal "#{t(:ks_volcano_steps, :n => 10)}. #{t(:ks_volcano_rule)}", info_key
    PokeAccess::Config.puzzle_assist = true
    assert_equal "#{t(:ks_volcano_steps, :n => 10)}. #{t(:ks_volcano_low)}. #{t(:ks_volcano_rule)}", info_key
    $keishou_volcano = nil
    assert_nil PokeAccess::Puzzles.info_line
  end

  test "a whole tile of Kazan's ice costs the routes more with the assist alone, and a cracked one nothing" do
    on_map(127)
    moves = PokeAccess::Routes::Moves
    got = without_terrain_rules do
      path = File.join(Harness::ROOT, "games", "keishou", "puzzles", "kazan_mountain.rb")
      verbose = $VERBOSE
      $VERBOSE = nil
      eval(Harness.source(path), TOPLEVEL_BINDING, path)
      $VERBOSE = verbose
      page = TestPage.new(:trigger => 1, :sprite => "", :through => true, :list => [TestCmd.new(123, ["A", 0])])
      $game_map.events[26] = TestGameEvent.new(:id => 26, :x => 3, :y => 1, :name => "Cracked ice", :pages => [page])
      World.next_frame
      PokeAccess::Pathfinder.invalidate_cache(true)
      seen = [moves.costed?, moves.tile_extra(3, 1)]
      PokeAccess::Config.set(:puzzle_assist, true)
      whole = [moves.costed?, moves.tile_extra(3, 1), moves.tile_extra(4, 1)]
      $game_self_switches[[127, 26, "A"]] = true
      World.next_frame
      [seen, whole, [moves.costed?, moves.tile_extra(3, 1)]]
    end
    assert_equal [[false, 0], [true, PokeAccess::KeishouVolcano::ICE_COST, 0], [true, 0]], got
  ensure
    PokeAccess::Config.set(:puzzle_assist, false)
    PokeAccess::Pathfinder.invalidate_cache(true)
  end

  test "Sakyu's ruins count their rocks home and list the sockets still empty" do
    on_map(136)
    socket = ruin_socket(25, 14, 16)
    refute PokeAccess::Locator.in_category?(socket, :all)
    assert_equal [[11, 13, t(:ks_ruin_socket)], [14, 16, t(:ks_ruin_socket)], [17, 13, t(:ks_ruin_socket)]], sockets
    $game_self_switches[[136, 20, "A"]] = true
    assert_equal [[14, 16, t(:ks_ruin_socket)], [17, 13, t(:ks_ruin_socket)]], sockets
    frame
    assert_equal [t(:puzzle_progress, :label => t(:ks_ruin_rocks), :n => 1, :of => 3)], frame { $game_variables[55] = 1 }
    on_map(139)
    assert_equal [[14, 10, t(:ks_ruin_socket)], [14, 16, t(:ks_ruin_socket)]], sockets
  end

  private

  # The spoken text of an i18n key.
  def t(*args); PokeAccess::I18n.t(*args); end

  # The mechanics registry.
  def mechanics; PokeAccess::World::Mechanics; end

  # Declares the profile's puzzles on their maps, loading its files once per process.
  def declare_puzzles
    self.class.declared ||= begin
      Harness.load_puzzles("keishou")
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
    $game_variables[35] = $game_variables[39] = $game_variables[42] = $game_variables[55] = $game_variables[66] = 0
    $game_map.map_id = map
    PokeAccess::Caches.reset_all
    mechanics.forget
  end

  # An event on the map: no graphic, a page that says something, as the game's controls are.
  def silent(id, x, y)
    page = TestPage.new(:trigger => 0, :sprite => "", :list => [TestCmd.new(101, ["..."]), TestCmd.new(0, [])])
    ev = TestGameEvent.new(:id => id, :x => x, :y => y, :name => "EV#{id}", :pages => [page])
    $game_map.events[id] = ev
    World.next_frame
    ev
  end

  # A socket of the ruins as the map draws it: a tile on an event named StrengthBoulder whose page has no command.
  def ruin_socket(id, x, y)
    page = TestPage.new(:trigger => 1, :through => true, :list => [TestCmd.new(0, [])])
    ev = TestGameEvent.new(:id => id, :x => x, :y => y, :name => "StrengthBoulder", :tile_id => 471, :pages => [page])
    $game_map.events[id] = ev
    World.next_frame
    ev
  end

  # A count as the mod says it.
  def progress(label, n, of); t(:puzzle_progress, :label => t(label), :n => n, :of => of); end

  # A stone plate as the mod names it, by its letters.
  def plate(letters); t(:ks_stone_plate, :letters => letters); end

  # Rows of [x, y, name] in the order the list gives them.
  def sorted(rows); rows.sort_by { |x, y, _n| [x, y] }; end

  # A gem socket as the assist names it, by colour.
  def socket(colour); t(:ks_socket_gem, :gem => t("ks_gem_#{colour}".to_sym)); end

  # The hint of the puzzle on the map, as the assist says it.
  def hint_text
    PokeAccess::Puzzles.label_of(mechanics.instances.first.spec[:hint])
  end

  # What the info key says on the map now.
  def info_key; PokeAccess::Info.map_text; end

  # What the puzzles say on the next map frame, after the block.
  def frame
    SpeakCapture.clear
    yield if block_given?
    PokeAccess::Puzzles.tick
    SpeakCapture.lines
  end

  # The ruins' sockets in the puzzles category, as listed.
  def sockets; listed.select { |_x, _y, n| n == t(:ks_ruin_socket) }; end

  # The puzzles category as [x, y, name as the locator says it], sorted.
  def listed
    PokeAccess::Puzzles.category_targets.map do |tg|
      name = tg.is_a?(PokeAccess::Locator::SurfaceTarget) ? tg.name : PokeAccess::Locator.target_name(tg)
      [tg.x, tg.y, name]
    end.sort_by { |x, y, _n| [x, y] }
  end
end
