# The puzzles of Realidea that block its story (games/realidea/puzzles/*): what each says by itself and, apart, with the
# puzzle assist, on events laid out as the maps of the game lay them.
class RealideaPuzzlesTest < PokeAccessTest
  ZONES = %w[quartz_gym agate_gym berilo_basement metis_labs decidueye_hideout abandoned_mansion route17_lab power_plant
             electruby_cave anatasa_gym]
  TEMPLATES = {
    "rea_quartz_jet_on" => "jet on %{colour}", "rea_quartz_jet_off" => "jet off %{colour}",
    "rea_quartz_tile_on" => "tile on %{colour} %{way}", "rea_quartz_tile_off" => "tile off %{colour}",
    "rea_agate_start" => "start %{where}", "rea_agate_next" => "route %{legs}", "rea_berilo_sentinel" => "sentinel %{dir}",
    "rea_agate_around" => "%{sides}. whites %{n}", "rea_decoy_type" => "type %{type}",
    "rea_mansion_pot" => "pot %{n}", "rea_decoy_answer" => "decoy %{type}",
    "rea_quartz_step_on" => "turn on %{colour} at %{where}", "rea_quartz_step_off" => "turn off %{colour} at %{where}",
    "rea_quartz_step_cross" => "cross %{colours} %{dir} at %{where}"
  }
  SWITCHES = (292..294).to_a + (171..174).to_a + (125..127).to_a + (240..247).to_a + [6, 63, 422, 428, 436, 438, 439, 440, 441]
  ENDINGS = {
    116 => [:rea_quartz_rule, lambda { $game_switches[6] = true }],
    28 => [:rea_berilo_rule, lambda { $game_switches[63] = true }],
    36 => [:rea_decidueye_rule, lambda { $game_switches[127] = true }],
    18 => [:rea_metis_rule, lambda { $game_self_switches[[18, 12, "A"]] = true }],
    202 => [:rea_mansion_rule, lambda { $game_self_switches[[202, 34, "A"]] = true }],
    46 => [:rea_plant_rule, lambda { [2, 6, 7, 11, 14].each { |id| $game_self_switches[[46, id, "A"]] = true } }],
    309 => [:rea_decoy_rule, lambda { $game_self_switches[[309, 1, "C"]] = true }],
    311 => [:rea_shapes_rule, lambda { $game_switches[428] = true }]
  }
  VARIABLES = [34, 64, 67, 115, 148, 179]

  def setup
    super
    load_zones
    inject_texts
  end

  def teardown
    @floor_methods.each { |m| $game_map.singleton_class.send(:remove_method, m) } if @floor_methods
    @floor_methods = nil
    World.clear_events
    mechanics.forget
    PokeAccess::Config.puzzle_assist = false
    SWITCHES.each { |i| $game_switches[i] = false }
    VARIABLES.each { |i| $game_variables[i] = 0 }
    $game_self_switches = @was_selfs if @was_selfs
    $game_map.map_id = @was_map if @was_map
    super
  end

  test "the water gym names its jets and tiles by colour and state and counts the colours on" do
    on_map(116)
    jet = place(3, 31, 23, :sprite => "chorro4")
    tile = place(4, 31, 20, :tile_id => 454)
    assert_equal t(:rea_quartz_jet_off, :colour => t(:rea_colour_red)), name_of(jet)
    $game_switches[171] = true
    assert_equal t(:rea_quartz_jet_on, :colour => t(:rea_colour_red)), name_of(jet)
    assert_equal t(:rea_quartz_tile_on, :colour => t(:rea_colour_red), :way => t(:rea_quartz_way_vertical)), name_of(tile)
    $game_switches[172] = true
    assert_equal t(:rea_quartz_tile_on, :colour => t(:rea_colour_yellow), :way => t(:rea_quartz_way_vertical)),
                 name_of(place(10, 18, 13, :tile_id => 454))
    sideways = name_of(place(25, 15, 18, :tile_id => 454))
    assert_equal t(:rea_quartz_tile_on, :colour => t(:rea_colour_yellow), :way => t(:rea_quartz_way_sideways)), sideways
    frame
    assert_equal [t(:puzzle_progress, :label => t(:rea_quartz_colours), :n => 2, :of => 2)], frame { $game_variables[64] = 2 }
    assert_equal [], frame { $game_variables[64] = 0 }, "the autorun that clears the colours on every entry says nothing"
    step(1, 1)
    refute_includes PokeAccess::Puzzles.info_line, t(:rea_quartz_hint)
    PokeAccess::Config.puzzle_assist = true
    assert_includes PokeAccess::Puzzles.info_line, t(:rea_quartz_hint), "out of every part there is no step to say"
  end

  test "with the assist the water gym says the next step from where the player stands and the colours on" do
    on_map(116)
    PokeAccess::Config.puzzle_assist = true
    red = t(:rea_colour_red)
    step(20, 37)
    assert_includes PokeAccess::Puzzles.info_line, t(:rea_quartz_step_on, :colour => red, :where => "7 #{t(:dir_right)}, 9 #{t(:dir_up)}")
    $game_switches[171] = true
    place(7, 31, 22)
    step(31, 25)
    assert_includes PokeAccess::Puzzles.info_line,
                    t(:rea_quartz_step_cross, :colours => red, :dir => t(:face_north), :where => "3 #{t(:dir_up)}")
    step(31, 21)
    assert_includes PokeAccess::Puzzles.info_line, t(:rea_quartz_transit)
    step(18, 8)
    refute_includes PokeAccess::Puzzles.info_line, t(:rea_quartz_hint)
    off = PokeAccess::RealideaQuartz.pull_text(:west, [:pull, 172, false], [12, 34])
    assert_equal t(:rea_quartz_step_off, :colour => t(:rea_colour_yellow), :where => "1 #{t(:dir_right)}, 1 #{t(:dir_down)}"), off
  end

  test "the plan of the water gym reaches the leader with the 10 levers the search over the map found" do
    quartz = PokeAccess::RealideaQuartz
    region = :start
    on = []
    pulls = []
    40.times do
      step = quartz.plan(region, on)
      break if step == :done
      if step[0] == :pull
        pulls.push(step[1])
        on = step[2] ? (on + [step[1]]).sort : (on - [step[1]])
      else
        region = step[2] ? quartz::BRIDGES[step[1]][:a] : quartz::BRIDGES[step[1]][:b]
      end
    end
    assert_equal :done, quartz.plan(region, on)
    assert_equal :leader, region
    assert_equal 10, pulls.length
    assert_equal [171, 173, 171, 174, 173, 172, 172, 171, 174, 172], pulls
  end

  test "the Decoy sheet and the gang boss say with the assist the option that sets their self switch A" do
    [[309, 1], [36, 28]].each do |map, id|
      on_map(map)
      spec = mechanics.instance_variable_get(:@defs)[map][0][1]
      rule = spec[:choices].find { |c| c[:events][id] }
      assert_equal({ :self => "A" }, rule[:takes], "event #{id} of map #{map}")
    end
  end

  test "each tile room keeps a route over every white tile, and the info key says what lies around the player" do
    PokeAccess::RealideaAgate::ROUTES.each do |_map, route|
      tiles = PokeAccess::RealideaAgate.tiles(route)
      assert_equal route[:total], tiles.length
      assert_equal tiles.length, tiles.uniq.length
    end
    on_map(118)
    tiles = PokeAccess::RealideaAgate.tiles(PokeAccess::RealideaAgate::ROUTES[118])
    lay_floor(tiles)
    black = []
    word = lambda { |x, y| black.include?([x, y]) ? :rea_agate_black : (tiles.include?([x, y]) ? :rea_agate_white : :rea_agate_out) }
    around = lambda do |x, y|
      sides = PokeAccess::Puzzles::SIDES.map { |dx, dy, key| "#{t(key)}: #{t(word.call(x + dx, y + dy))}" }
      t(:rea_agate_around, :sides => sides.join(", "), :n => tiles.length - black.length)
    end
    step(10, 15)
    assert_includes PokeAccess::Puzzles.info_line, around.call(10, 15)
    assert_includes PokeAccess::Puzzles.info_line, t(:rea_agate_white), "the first tile is white, up from here"
    refute_includes PokeAccess::Puzzles.info_line, t(:rea_agate_start, :where => "1 #{t(:dir_up)}")
    black.concat(tiles[0, 3])
    black.each_with_index { |(x, y), i| place(100 + i, x, y, :tile_id => 392) }
    step(*tiles[2])
    assert_includes PokeAccess::Puzzles.info_line, around.call(*tiles[2])
    assert_includes PokeAccess::Puzzles.info_line, t(:rea_agate_black), "the two tiles behind are black"
    step(1, 1)
    assert_includes PokeAccess::Puzzles.info_line, around.call(1, 1)
  end

  test "the tile rooms say with the assist where to begin and the next legs, and nothing once the door is open" do
    on_map(118)
    tiles = PokeAccess::RealideaAgate.tiles(PokeAccess::RealideaAgate::ROUTES[118])
    lay_floor(tiles)
    PokeAccess::Config.puzzle_assist = true
    step(10, 16)
    assert_includes PokeAccess::Puzzles.info_line, t(:rea_agate_start, :where => "2 #{t(:dir_up)}")
    $game_variables[67] = 3
    step(*tiles[2])
    legs = ["1 #{t(:dir_right)}", "2 #{t(:dir_up)}", "1 #{t(:dir_left)}", "2 #{t(:dir_up)}", "1 #{t(:dir_right)}", "2 #{t(:dir_up)}"]
    assert_includes PokeAccess::Puzzles.info_line, t(:rea_agate_next, :legs => legs.join(", "))
    $game_variables[67] = 55
    assert_includes PokeAccess::Puzzles.info_line, t(:rea_agate_done)
    $game_variables[67] = 0
    $game_self_switches[[118, 4, "A"]] = true
    assert_equal "", PokeAccess::RealideaAgate.hint, "a room that is done has nothing to begin"
    assert_nil PokeAccess::Puzzles.info_line
  end

  test "the basement names each sentinel by where it faces, counts the levers and says why the player is sent back" do
    on_map(28)
    seen = place(9, 3, 28, :name => "Trainer(3)", :direction => 4)
    assert_equal t(:rea_berilo_sentinel, :dir => t(:dir_left)), name_of(seen)
    seen.direction = 2
    assert_equal t(:rea_berilo_sentinel, :dir => t(:dir_down)), name_of(seen)
    assert_equal t(:rea_berilo_twig), name_of(place(25, 15, 28))
    frame
    assert_equal [t(:puzzle_progress, :label => t(:rea_levers_pulled), :n => 1, :of => 6)], frame { $game_variables[34] = 1 }
    assert_nil PokeAccess::Puzzles.sent_back_line([3, 28], [18, 48])
    fire(seen)
    assert_equal t(:rea_berilo_seen), PokeAccess::Puzzles.sent_back_line([3, 28], [18, 48])
  end

  test "the first floor levers count, say why they rose again and give the order with the assist" do
    on_map(18)
    assert_equal [t(:rea_metis_clue), t(:rea_metis_paper)], [name_of(place(8, 20, 36)), name_of(place(6, 4, 11, :sprite => "lucecita"))]
    frame
    pulled = lambda { |n| t(:puzzle_progress, :label => t(:rea_levers_pulled), :n => n, :of => 4) }
    assert_equal [pulled.call(3)], frame { $game_variables[115] = 3 }
    assert_equal [PokeAccess.sentences([t(:rea_metis_wrong), pulled.call(0)])], frame { $game_variables[115] = 0 }
    refute_includes PokeAccess::Puzzles.info_line, t(:rea_metis_hint)
    PokeAccess::Config.puzzle_assist = true
    assert_includes PokeAccess::Puzzles.info_line, t(:rea_metis_hint)
    PokeAccess::Config.puzzle_assist = false
    frame { $game_variables[115] = 4 }
    opened = frame do
      $game_self_switches[[18, 12, "A"]] = true
      $game_variables[115] = 0
    end
    assert_equal [PokeAccess.sentences([t(:rea_metis_opened), pulled.call(0)])], opened
    assert_nil PokeAccess::Puzzles.info_line, "the door is open: the levers have nothing left to say"
  end

  test "each puzzle says its rule on arriving and keeps its count on the info key until its end, then neither" do
    ENDINGS.each do |map, (rule, finish)|
      on_map(map)
      assert_equal [t(rule)], frame, "map #{map} before its end"
      refute_nil PokeAccess::Puzzles.info_line, "map #{map} before its end"
      on_map(map)
      finish.call
      assert_empty frame, "map #{map} after its end"
      assert_nil PokeAccess::Puzzles.info_line, "map #{map} after its end"
      SWITCHES.each { |i| $game_switches[i] = false }
    end
  end

  test "the power plant ends only with its fifth lever, and the symmetry room and the lab's sheet only with their last step" do
    on_map(46)
    [2, 6, 7, 11].each { |id| $game_self_switches[[46, id, "A"]] = true }
    assert_equal [t(:rea_plant_rule)], frame
    refute_nil PokeAccess::Puzzles.info_line
    on_map(202)
    (240..247).each { |i| $game_switches[i] = true }
    assert_equal [t(:rea_mansion_rule)], frame, "the details match but the game has not checked them yet"
    on_map(309)
    [["A"], ["A", "B"]].each do |letters|
      on_map(309)
      letters.each { |letter| $game_self_switches[[309, 1, letter]] = true }
      assert_equal [t(:rea_decoy_rule)], frame, "sheet answered up to #{letters.last}"
    end
  end

  test "the password door speaks of its rule only near it, with the sum for the assist, and the papers are named" do
    on_map(62)
    assert_equal t(:rea_metis_keypad), name_of(place(1, 9, 28, :sprite => "Puertita"))
    step(9, 30)
    assert_includes PokeAccess::Puzzles.info_line, t(:rea_metis_door_rule)
    refute_includes PokeAccess::Puzzles.info_line, t(:rea_metis_door_hint)
    PokeAccess::Config.puzzle_assist = true
    assert_includes PokeAccess::Puzzles.info_line, t(:rea_metis_door_hint)
    step(40, 5)
    assert_nil PokeAccess::Puzzles.info_line
    [[133, 32], [56, 7]].each do |map, id|
      on_map(map)
      assert_equal t(:rea_metis_paper), name_of(place(id, 5, 5, :sprite => "lucecita"))
    end
  end

  test "the gang boss is named, the passwords counted and, with the assist, the one he asks for said as he is spoken to" do
    on_map(36)
    boss = place(28, 38, 5, :sprite => "BandecidueyesJefe")
    assert_equal [t(:rea_decidueye_boss), t(:rea_decidueye_member)], [name_of(boss), name_of(place(19, 21, 11, :sprite => "Bandecidueyes"))]
    frame
    assert_equal [t(:puzzle_progress, :label => t(:rea_decidueye_passwords), :n => 1, :of => 3)], frame { $game_switches[125] = true }
    assert_equal [], frame { mechanics.used(boss) }
    PokeAccess::Config.puzzle_assist = true
    assert_equal [], frame { mechanics.used(boss) }
    [["A", "Mapa"], ["B", "Secreto"], ["C", "Muerte"]].each do |letter, word|
      $game_self_switches[[36, 28, letter]] = true
      assert_equal [t(:puzzle_answer, :a => word)], frame { mechanics.used(boss) }, word
    end
    frame { $game_switches[127] = true }
    assert_equal [], frame { mechanics.used(boss) }
  end

  test "the symmetry room names both sides by state, counts the matched details for the assist and gives the steps" do
    on_map(202)
    right = place(7, 20, 4)
    pot = place(31, 25, 13)
    assert_equal [t(:rea_mansion_picture_off), t(:rea_mansion_picture_on), t(:rea_mansion_pot, :n => 5)],
                 [name_of(right), name_of(place(13, 7, 4)), name_of(pot)]
    assert_equal [t(:rea_mansion_bin_papers), t(:rea_mansion_bin)], [name_of(place(1, 17, 12)), name_of(place(2, 15, 12))]
    $game_switches[240] = true
    $game_switches[244] = true
    assert_equal [t(:rea_mansion_picture_on), t(:rea_mansion_pot, :n => 4)], [name_of(right), name_of(pot)]
    frame
    assert_equal [], frame { $game_switches[241] = true }
    PokeAccess::Config.puzzle_assist = true
    assert_equal [t(:puzzle_progress, :label => t(:rea_mansion_details), :n => 3, :of => 7)], frame { $game_switches[242] = true }
    assert_includes PokeAccess::Puzzles.info_line, t(:rea_mansion_hint)
  end

  test "the data sheet is named and counted, and the assist reads the whole answer with the current type" do
    on_map(309)
    sheet = place(1, 15, 5, :sprite => "lucecita")
    assert_equal t(:rea_decoy_sheet), name_of(sheet)
    frame
    assert_equal [t(:puzzle_progress, :label => t(:rea_decoy_data), :n => 1, :of => 3)], frame { $game_self_switches[[309, 1, "A"]] = true }
    PokeAccess::RealideaLab.define_singleton_method(:decoy_type) { "Fuego" }
    assert_equal [], frame { mechanics.used(sheet) }
    PokeAccess::Config.puzzle_assist = true
    assert_equal [], frame { mechanics.used(sheet) }, "before the Decoy is fought the sheet asks nothing"
    $game_switches[422] = true
    assert_equal [t(:puzzle_answer, :a => t(:rea_decoy_answer, :type => "Fuego"))], frame { mechanics.used(sheet) }
    frame { $game_self_switches[[309, 1, "B"]] = true }
    assert_equal [t(:puzzle_answer, :a => t(:rea_decoy_type, :type => "Fuego"))], frame { mechanics.used(sheet) }, "only the type is left"
    frame { $game_self_switches[[309, 1, "C"]] = true }
    assert_equal [], frame { mechanics.used(sheet) }, "a sheet that is done asks nothing"
    frame { $game_self_switches[[309, 1, "C"]] = false }
    PokeAccess::RealideaLab.define_singleton_method(:decoy_type) { "" }
    assert_equal [], frame { mechanics.used(sheet) }
  end

  test "the figures are named by shape, the examined ones counted and the terminal answer follows its stage with the assist" do
    on_map(311)
    terminal = place(14, 19, 5, :sprite => "lucecita")
    assert_equal [t(:rea_shape_circle), t(:rea_shape_square), t(:rea_shapes_terminal)],
                 [name_of(place(15, 6, 8)), name_of(place(17, 51, 51)), name_of(terminal)]
    frame
    assert_equal [t(:puzzle_progress, :label => t(:rea_shapes_count), :n => 1, :of => 5)], frame { $game_switches[436] = true }
    assert_equal [], frame { mechanics.used(terminal) }
    PokeAccess::Config.puzzle_assist = true
    words = %w[Circulo Cuadrado Triangulo Rombo]
    words.each_with_index do |word, stage|
      $game_variables[179] = stage
      assert_equal [t(:puzzle_answer, :a => words[stage..-1].join(", "))], frame { mechanics.used(terminal) }, word
    end
    $game_switches[428] = true
    assert_equal [], frame { mechanics.used(terminal) }
  end

  test "the power plant names levers and gates by state and counts the gates opened" do
    on_map(46)
    lever = place(2, 23, 33, :sprite => "Palancas")
    gate = place(8, 10, 32, :sprite => "Verjas", :name => "BARRERA2 /noShadow/")
    assert_equal [t(:rea_plant_lever), t(:rea_plant_gate_closed)], [name_of(lever), name_of(gate)]
    frame
    opened = frame do
      $game_self_switches[[46, 2, "A"]] = true
      $game_self_switches[[46, 8, "A"]] = true
    end
    assert_equal [t(:puzzle_progress, :label => t(:rea_plant_gates), :n => 1, :of => 5)], opened
    assert_equal [t(:rea_plant_lever_done), t(:rea_plant_gate_open)], [name_of(lever), name_of(gate)]
  end

  test "the red crystals are named by whether they were pushed, and the info key gives the rule and, with the assist, which to push" do
    on_map(155)
    crystal = place(2, 21, 7, :sprite => "cristalrojo")
    assert_equal t(:rea_crystal), name_of(crystal)
    frame
    assert_equal [], frame { $game_self_switches[[155, 2, "A"]] = true }, "no count: not all four are to be pushed"
    assert_equal t(:rea_crystal_spent), name_of(crystal)
    assert_includes PokeAccess::Puzzles.info_line, t(:rea_crystal_rule)
    refute_includes PokeAccess::Puzzles.info_line, t(:rea_crystal_hint)
    PokeAccess::Config.puzzle_assist = true
    assert_includes PokeAccess::Puzzles.info_line, t(:rea_crystal_hint)
  end

  test "the decoration boxes of the Anatasa gym are named by their state and counted with the assist alone" do
    on_map(238)
    { 6 => [5, 38], 9 => [42, 5], 10 => [71, 39] }.each { |id, (x, y)| place(id, x, y, :sprite => "lucecita") }
    frame
    assert_equal [t(:rea_deco_box)] * 3, [6, 9, 10].map { |id| name_of($game_map.events[id]) }
    $game_switches[292] = true
    assert_equal [t(:rea_deco_box_done), t(:rea_deco_box), t(:rea_deco_box)], [6, 9, 10].map { |id| name_of($game_map.events[id]) }
    assert_equal [], frame, "no count without the assist"
    PokeAccess::Config.puzzle_assist = true
    assert_equal [t(:puzzle_progress, :label => t(:rea_deco_count), :n => 2, :of => 3)], frame { $game_switches[293] = true }
    assert_includes PokeAccess::Puzzles.info_line.to_s, t(:puzzle_progress, :label => t(:rea_deco_count), :n => 2, :of => 3)
  end

  private

  def t(key, vars = {})
    PokeAccess::I18n.t(key, vars)
  end

  def mechanics
    PokeAccess::World::Mechanics
  end

  # Declares the puzzles of the zones again, from their source, for a test whose reset dropped them; the constants they
  # set again are the same, so the warning for it is left out.
  def load_zones
    was = $VERBOSE
    $VERBOSE = nil
    ZONES.each do |zone|
      path = File.join(Harness::ROOT, "games", "realidea", "puzzles", "#{zone}.rb")
      eval(Harness.source(path), TOPLEVEL_BINDING, path)
    end
  ensure
    $VERBOSE = was
  end

  # Puts the player on a map of the game with nothing declared by other tests in the way and its switches and
  # self switches clear.
  def on_map(map)
    @was_selfs ||= $game_self_switches
    @was_map ||= $game_map.map_id
    $game_self_switches = {}
    $game_map.map_id = map
    PokeAccess::Config.puzzle_assist = false
    PokeAccess::Caches.reset_all
    mechanics.forget
    World.clear_events
    inject_texts
  end

  # The texts of the keys that take values, as the test knows them, in the language in use and the reference one: the
  # lines of the language files may be older or newer, and what is compared is what the code passes to them.
  def inject_texts
    [PokeAccess::I18n::REFERENCE, PokeAccess::I18n.lang].uniq.each do |code|
      table = PokeAccess::I18n.table(code)
      TEMPLATES.each { |key, text| table[key] = text }
    end
  end

  # Gives the map the white floor of a tile room: terrain 24 on the tiles and none elsewhere.
  def lay_floor(whites, width = 20, height = 20)
    @floor_methods = [:terrain_tag, :width, :height]
    $game_map.define_singleton_method(:terrain_tag) { |x, y, *_rest| whites.include?([x, y]) ? 24 : 0 }
    $game_map.define_singleton_method(:width) { width }
    $game_map.define_singleton_method(:height) { height }
  end

  # An event of the map on (x, y) whose page does something, drawn with a sheet or a tile or not at all.
  def place(id, x, y, opts = {})
    page = TestPage.new(:trigger => 0, :sprite => opts.fetch(:sprite, ""), :direction => opts.fetch(:direction, 2),
                        :list => [TestCmd.new(101, ["text"]), TestCmd.new(0, [])])
    ev = TestGameEvent.new(:id => id, :x => x, :y => y, :name => opts.fetch(:name, "EV#{id}"), :tile_id => opts.fetch(:tile_id, 0),
                           :pages => [page])
    ev.direction = opts[:direction] if opts[:direction]
    $game_map.events[id] = ev
    World.next_frame
    ev
  end

  def name_of(ev)
    PokeAccess::Puzzles.piece_name(ev)
  end

  def step(x, y)
    $game_player.x = x
    $game_player.y = y
  end

  # The player's use of an event, as the interpreter's setup tells it.
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
end
