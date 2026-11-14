# Pokemon Z's story puzzles on the shipped profile: the Cueva Refulgente's crystals, Chateau Lanto's mirrors, Fort Leviatán's
# cell, the Luminalia chair, the Torre Oscura, the Romantis keep, the Arma Definitiva, the Maraña Oscura, the way through
# the Bosque Errante, the Bastión Fractal, the Cueva Talasia, the Pokéball factory and the Antigua Forja. What the eye sees
# goes by name on its own; the answers wait for the assist.
class ZStoryPuzzlesTest < PokeAccessTest
  # A bag that holds the given items, each once.
  class HeldBag
    def initialize(items); @items = items; end
    def pbQuantity(item); @items.include?(item) ? 1 : 0; end
  end

  def setup
    super
    @kept = [$game_self_switches, $bag, $PokemonBag]
    $game_self_switches = {}
    $bag = nil
    $PokemonBag = HeldBag.new([])
  end

  def teardown
    $game_self_switches, $bag, $PokemonBag = @kept
  end

  test "names a crystal on any map, among the objects and never the people" do
    [51, 78].each do |map|
      on_map(map)
      crystal = place(27, 11, 24, [TestCmd.new(111, [6, -1, 2])], :sprite => "rocaElectrica", :trigger => 1)
      assert_equal t(:z_crystal), PokeAccess::Locator.target_name(crystal), "map #{map}"
      assert PokeAccess::Locator.in_category?(crystal, :objects)
      refute PokeAccess::Locator.in_category?(crystal, :people)
    end
  end

  test "keeps out of the lists and the sonar the crystals the player walks through" do
    [51, 78, 198, 80].each do |map|
      on_map(map)
      decor = place(32, 15, 30, [], :sprite => "rocaElectrica", :through => true)
      assert PokeAccess::Locator.hidden?(decor), "map #{map}"
      refute_includes PokeAccess::Locator.candidates(:objects), decor
      assert_nil PokeAccess::Sound::Scene.family_of(decor)
    end
  end

  test "lists the crystals still to move, and takes one away as its page empties" do
    on_map(51)
    crystals_on_51
    assert_equal [hidden(27, 11, 24, :z_crystal), hidden(29, 21, 29, :z_crystal), hidden(31, 33, 67, :z_crystal)], targets
    place(29, 18, 29, [TestCmd.new(0, [])], :sprite => "rocaElectrica")
    $game_switches[134] = true
    assert_equal [hidden(27, 11, 24, :z_crystal), hidden(31, 33, 67, :z_crystal)], targets
    assert_equal t(:z_crystal), PokeAccess::Locator.target_name($game_map.events[29]), "still a crystal, drawn where it went"
  end

  test "tells the crystals' rule on arrival and on the info key, while one can still move" do
    on_map(51)
    crystals_on_51
    assert_equal [[t(:z_crystal_rule), false]], tick
    assert_equal [], tick, "once"
    assert_equal t(:z_crystal_rule), info_key
    [133, 134, 135].each { |s| $game_switches[s] = true }
    on_map(51)
    assert_equal [], tick, "nothing left to move"
    assert_nil PokeAccess::Puzzles.info_line
  end

  test "says which way the nearest crystal still to move gives, to the assist alone" do
    on_map(78)
    stand(40, 18)
    refute_includes info_key, t(:z_crystal_down)
    assist_on
    assert_includes info_key, t(:z_crystal_down)
    stand(38, 64)
    assert_includes info_key, t(:z_crystal_right)
    $game_switches[137] = true
    assert_includes info_key, t(:z_crystal_down), "the other one, now the only one"
    on_map(51)
    assist_on
    stand(22, 29)
    assert_includes info_key, t(:z_crystal_left)
  end

  test "says each mirror's way as a spot and in the exits, the same on all three of a map" do
    { 88 => [[2, 18, 19], :z_lanto_mirror_alt], 94 => [[9, 10, 11], :z_lanto_mirror_real] }.each do |map, (ids, key)|
      on_map(map)
      mirrors = ids.each_with_index.map { |id, i| place(id, 30 + i, 15, [TestCmd.new(201, [0, map, 1, 1])]) }
      assert_equal mirrors.map { |m| spot(m.x, m.y, key, m.id) }, targets, "map #{map}"
      mirrors.each { |m| assert_equal t(key), PokeAccess::Locator.target_name(m), "map #{map}, event #{m.id}" }
    end
  end

  test "tells the grey maps for what they are on arrival and on the info key, before and after the chalice" do
    [92, 94, 95].each do |map|
      on_map(map)
      assert_equal [[t(:z_lanto_alt), false]], tick, "map #{map}"
      assert_equal t(:z_lanto_alt), info_key, "map #{map}"
      $game_self_switches[[86, 12, "A"]] = true
      assert_equal t(:z_lanto_alt), info_key, "map #{map}, the chalice filled"
    end
  end

  test "leaves the info key alone on the real maps without the assist" do
    [86, 88].each do |map|
      on_map(map)
      assert_equal [], tick
      assert_equal "", PokeAccess::Puzzles.info_line.to_s, "map #{map}"
    end
  end

  test "gives the way to the wine and then to the chalice from each part of each map" do
    { [86, 44, 16] => [:z_lanto_step_wine, :z_lanto_step_here],
      [86, 3, 5] => [:z_lanto_step_up_right, :z_lanto_step_up_right],
      [86, 10, 20] => [:z_lanto_step_up_right, :z_lanto_step_up_right],
      [86, 30, 21] => [:z_lanto_step_low_left, :z_lanto_step_chalice],
      [88, 60, 10] => [:z_lanto_step_here, :z_lanto_step_here],
      [88, 50, 19] => [:z_lanto_step_right, :z_lanto_step_mirror_north],
      [88, 14, 31] => [:z_lanto_step_mirror_center, :z_lanto_step_low_left],
      [88, 57, 34] => [:z_lanto_step_mirror_center, :z_lanto_step_low_left],
      [92, 44, 16] => [:z_lanto_step_here, :z_lanto_step_here],
      [92, 40, 8] => [:z_lanto_step_up_left, :z_lanto_step_up_right],
      [92, 30, 46] => [:z_lanto_step_low_left, :z_lanto_step_low_left],
      [94, 60, 19] => [:z_lanto_step_mirror_north, :z_lanto_step_up_right],
      [94, 33, 16] => [:z_lanto_step_up_left, :z_lanto_step_mirror_center],
      [95, 24, 10] => [:z_lanto_step_door, :z_lanto_step_door] }.each do |(map, x, y), (to_wine, to_chalice)|
      on_map(map)
      stand(x, y)
      wine = t(:z_lanto_to_wine, :step => t(to_wine))
      refute_includes info_key, wine
      assist_on
      assert_includes info_key, wine, "map #{map} at (#{x}, #{y})"
      $game_self_switches[[86, 18, "A"]] = true
      assert_includes info_key, t(:z_lanto_to_chalice, :step => t(to_chalice)), "map #{map} at (#{x}, #{y}), the wine taken"
      $game_self_switches[[86, 12, "A"]] = true
      refute_includes info_key, t(:z_lanto_to_chalice, :step => t(to_chalice)), "map #{map} at (#{x}, #{y}), the wine poured"
    end
  end

  test "lists the chalice until it is filled" do
    on_map(86)
    chalice = place(12, 30, 20, [TestCmd.new(101, ["!"])], :sprite => "flecha")
    assert_equal [spot(30, 20, :z_lanto_chalice, 12)], targets
    assert_equal t(:z_lanto_chalice), PokeAccess::Locator.target_name(chalice)
    $game_self_switches[[86, 12, "A"]] = true
    assert_empty targets
  end

  test "lists the hidden button by its name until it is pressed, its editor name never said" do
    on_map(109)
    $game_variables[89] = 6
    button = place(2, 26, 10, [TestCmd.new(101, ["..."])], :name => "boton(2,1)")
    assert_equal [spot(26, 10, :z_lanto_button, 2)], targets
    assert_equal t(:z_lanto_button), PokeAccess::Locator.target_name(button)
    assert_equal "", PokeAccess::Puzzles.info_line.to_s
    assist_on
    assert_equal t(:z_lanto_button_hint), info_key
    $game_variables[89] = 10
    assert_empty targets
    stand(24, 11)
    assert_equal t(:z_lanto_to_wine, :step => t(:z_lanto_step_door)), info_key, "the entrance it opened"
  end

  test "says the lever and what it does to the spikes, which stop being a wall once lowered" do
    on_map(109)
    lever, spikes = lever_and_spikes
    assert_equal [control(31, 4, 37, :z_lanto_lever), spikes], targets
    assert_equal t(:z_spikes), PokeAccess::Locator.target_name(spikes)
    assert_equal :hazard, PokeAccess::Sound::Scene.family_of(spikes)
    tick
    $game_switches[160] = true
    show_page(lever, 1)
    show_page(spikes, 1)
    changes = t(:ctrl_group, :what => t(:z_spikes), :changes => t(:ctrl_quit, :n => 1))
    assert_equal [["#{t(:z_lanto_lever)}: #{t(:z_lanto_lever_on)}. #{changes}", false]], tick
    assert_empty targets
    assert PokeAccess::Locator.hidden?(spikes)
    assert_nil PokeAccess::Sound::Scene.family_of(spikes)
    stand(12, 39)
    assert_equal [], tick, "nothing beside the player any more"
  end

  test "says beside the raised spikes what they are, and what the lever is for to the assist alone" do
    on_map(109)
    lever_and_spikes
    stand(3, 35)
    assert_equal "", PokeAccess::Puzzles.info_line.to_s
    assist_on
    assert_equal t(:z_lanto_lever_hint), info_key
    $game_switches[160] = true
    assert_equal "", PokeAccess::Puzzles.info_line.to_s, "its work done"
    $game_switches[160] = false
    stand(12, 39)
    assert_equal [[t(:z_lanto_lever_hint), false], ["#{t(:z_spikes)}, #{t(:side_right)}", false]], tick
  end

  test "keeps the player's reflection out of the lists of the mirror rooms" do
    [[88, 4, "chico0Ref"], [94, 15, "chica2Ref"], [468, 18, "trchar000_5"], [473, 12, "trchar001_5"]].each do |map, id, sprite|
      on_map(map)
      reflection = place(id, 0, 19, [], :sprite => sprite, :name => "ref/noShadow/")
      assert PokeAccess::Locator.hidden?(reflection), "map #{map}"
      refute_includes PokeAccess::Locator.candidates(:people), reflection
    end
  end

  test "says what the cell's table and lever did, each listed by its name" do
    on_map(126)
    table = place(2, 35, 22, [TestCmd.new(121, [265, 265, 0])])
    place(14, 5, 24, [TestCmd.new(121, [266, 266, 0])], :sprite => "palancas")
    assert_equal [spot(35, 22, :z_fort_table, 2), spot(5, 24, :z_fort_lever, 14)], targets
    assert_equal t(:z_fort_table), PokeAccess::Locator.target_name(table)
    tick
    assert_equal "#{t(:z_fort_table)}: #{t(:z_fort_still)}. #{t(:z_fort_cell)}: #{t(:z_fort_closed)}", info_key
    $game_switches[265] = true
    assert_equal [["#{t(:z_fort_table)}: #{t(:z_fort_moved)}", false]], tick
    assert_equal [spot(35, 22, :z_fort_way_out, 2), spot(5, 24, :z_fort_lever, 14)], targets
    assert_equal t(:z_fort_way_out), PokeAccess::Locator.target_name(table)
    refute_includes info_key, t(:z_fort_hint)
    assist_on
    assert_includes info_key, t(:z_fort_hint)
    $game_switches[266] = true
    assert_equal [["#{t(:z_fort_cell)}: #{t(:z_fort_open)}", false]], tick
    refute PokeAccess::Puzzles.active?, "both done: the info key goes back to its usual job"
  end

  test "lists the middle chair while the talisman is in the bag, its use to the assist alone" do
    on_map(190)
    place(94, 74, 25, [TestCmd.new(111, [12, "x"])])
    assert_empty targets, "no talisman"
    assert_equal "", PokeAccess::Puzzles.info_line.to_s
    $PokemonBag = HeldBag.new([:TALISMANMALVO])
    assert_equal [spot(74, 25, :z_chair, 94)], targets
    assert_equal [], tick
    assert_equal "", PokeAccess::Puzzles.info_line.to_s
    assist_on
    assert_equal t(:z_chair_hint), info_key
    $game_switches[412] = true
    assert_empty targets, "the talisman shining"
  end

  test "calls the Hypno statues by name as walls, among the objects, on every map they stand" do
    [262, 263, 264, 476].each do |map|
      on_map(map)
      statue = place(25, 63, 22, [], :sprite => "estatuasHypno")
      assert_equal t(:z_tower_statue), PokeAccess::Locator.target_name(statue), "map #{map}"
      assert PokeAccess::Locator.in_category?(statue, :objects)
      refute PokeAccess::Locator.in_category?(statue, :people)
      assert_equal :hazard, PokeAccess::Sound::Scene.family_of(statue), "a wall's sound, not a person's"
      stand(63, 23)
      tick
      assert_includes targets, statue
    end
  end

  test "says as the player comes beside a statue which side it is on" do
    on_map(263)
    place(25, 8, 10, [], :sprite => "estatuasHypno")
    stand(8, 11)
    assert_equal [["#{t(:z_tower_statue)}, #{t(:side_up)}", false]], tick
  end

  test "says the purple lever as it is pulled and lists it until then" do
    on_map(263)
    lever = place(1, 15, 20, [TestCmd.new(121, [455, 455, 0])], :sprite => "palancas", :pattern => 2,
                  :extra => TestPage.new(:sprite => "palancas", :pattern => 1,
                                         :condition => { :switch1_valid => true, :switch1_id => 455 }))
    on_map(263)
    assert_equal [control(1, 15, 20, :z_tower_lever)], targets
    tick
    $game_switches[455] = true
    show_page(lever, 1)
    assert_equal [["#{t(:z_tower_lever)}: #{t(:z_tower_lever_on)}", false]], tick
    assert_empty targets
  end

  test "tells the statues' rule on arrival at the tower's first map alone" do
    on_map(264)
    assert_equal [[t(:z_tower_rule), false]], tick
    on_map(262)
    assert_equal [], tick
    $game_switches[462] = true
    on_map(264)
    assert_equal [], tick, "Lanto met: the player knows the tower by now"
    assert_equal "", PokeAccess::Puzzles.info_line.to_s, "and the info key goes back to its usual job"
    $game_switches[462] = false
    $game_switches[468] = true
    on_map(264)
    assert_equal [], tick, "the statues gone for good"
  end

  test "keeps to one step coming from the north into 264's south-east room, up to its sensor" do
    [[461], [459, 461]].each do |on|
      on_map(264)
      [458, 459, 460, 461].each { |s| $game_switches[s] = on.include?(s) }
      stand(63, 21)
      assist_on
      assert_equal [[t(:z_tower_rule), false], [t(:z_tower_sensor_far), false]], tick, "with #{on.inspect}"
      stand(63, 23)
      assert_equal [], tick
      stand(63, 24)
      assert_equal [], tick, "on the sensor, its event yet to run"
      $game_switches[459] = false
      $game_switches[461] = false
      $game_switches[460] = true
      assert_equal [[t(:z_tower_se_back), false]], tick, "the sensor run"
      stand(63, 25)
      assert_equal [], tick
    end
  end

  test "gives the next step on the tower's floors for each state of its switches" do
    tower_steps.each do |map, x, y, on, key|
      on_map(map)
      stand(x, y)
      [458, 459, 460, 461, 462, 463, 468].each { |s| $game_switches[s] = on.include?(s) }
      assist_on
      assert_includes info_key.to_s, t(key), "map #{map} at (#{x}, #{y}) with #{on.inspect}"
    end
  end

  test "names the tower's jukebox, which core would read as a sign" do
    on_map(262)
    jukebox = place(18, 57, 19, [TestCmd.new(101, ["..."])], :sprite => "flecha")
    assert_equal t(:z_tower_jukebox_name), PokeAccess::Locator.target_name(jukebox)
  end

  test "keeps the tower's steps to the assist, and drops them once the statues are gone for good" do
    on_map(262)
    stand(50, 20)
    $game_switches[461] = true
    assert_equal "", PokeAccess::Puzzles.info_line.to_s
    assist_on
    assert_equal t(:z_tower_e_tp), info_key
    $game_switches[468] = true
    assert_equal "", PokeAccess::Puzzles.info_line.to_s
  end

  test "says the step as it changes with the assist, and nothing without it" do
    on_map(264)
    stand(64, 27)
    $game_switches[458] = true
    $game_switches[461] = true
    tick
    $game_switches[461] = false
    $game_switches[460] = true
    assert_equal [], tick
    $game_switches[461] = true
    $game_switches[460] = false
    assert_equal [], tick
    assist_on
    tick
    $game_switches[461] = false
    $game_switches[460] = true
    assert_equal [[t(:z_tower_se_back), false]], tick
  end

  test "tells which room of the warp floor the player is in as it changes, from the map's parts" do
    on_map(265)
    stand(3, 22)
    $game_variables[185] = 0
    assert_equal [[t(:z_tower_doors_rule), false]], tick, "on arrival, its rule alone"
    assert_equal "#{t(:z_tower_room_a)}. #{t(:z_tower_doors_rule)}", info_key
    stand(26, 22)
    assert_equal [], tick, "within the same room"
    $game_variables[185] = 3
    assert_equal [], tick, "the third exit, the warp still to come"
    stand(38, 3)
    assert_equal [[t(:z_tower_room_b), false]], tick
    assert_equal "#{t(:z_tower_room_b)}. #{t(:z_tower_doors_rule)}", info_key
    stand(3, 49)
    assert_equal [[t(:z_tower_room_c), false]], tick
    stand(44, 35)
    assert_equal [], tick, "Pistia's cell is no room of the puzzle"
    refute PokeAccess::Puzzles.active?
  end

  test "counts the first room's exits and gives each room's way out, to the assist alone" do
    on_map(265)
    stand(3, 22)
    $game_variables[185] = 0
    tick
    $game_variables[185] = 1
    assert_equal [], tick, "no count without the assist"
    assert_equal "#{t(:z_tower_room_a)}. #{t(:z_tower_doors_rule)}", info_key
    assist_on
    $game_variables[185] = 2
    count = t(:puzzle_progress, :label => t(:z_tower_count), :n => 2, :of => 3)
    assert_equal [[count, false]], tick
    assert_equal "#{t(:z_tower_room_a)}. #{count}. #{t(:z_tower_a_hint)} #{t(:z_tower_doors_rule)}", info_key
    $game_variables[185] = 4
    assert_equal "#{t(:z_tower_room_a)}. #{t(:z_tower_a_reset)} #{t(:z_tower_doors_rule)}", info_key, "past the count"
    stand(38, 3)
    assert_equal [["#{t(:z_tower_room_b)}. #{t(:z_tower_b_hint)}", false]], tick
    stand(3, 49)
    assert_equal [["#{t(:z_tower_room_c)}. #{t(:z_tower_c_hint)}", false]], tick
  end

  test "lists each room's door to take, to the assist alone" do
    on_map(265)
    [[4, 3, 23], [5, 26, 23], [6, 38, 2], [7, 62, 2], [11, 14, 49]].each do |id, x, y|
      place(id, x, y, [TestCmd.new(201, [0, 265, 1, 1])], :trigger => 1, :name => "size(2,1)")
    end
    $game_variables[185] = 0
    stand(3, 22)
    assert_empty targets
    assist_on
    assert_equal [hidden(4, 3, 23, :puzzle_right_way)], targets
    $game_variables[185] = 3
    assert_equal [hidden(5, 26, 23, :puzzle_right_way)], targets, "past the count, the door that sets it back"
    stand(50, 18)
    assert_equal [hidden(6, 38, 2, :puzzle_right_way), hidden(7, 62, 2, :puzzle_right_way)], targets
    stand(10, 40)
    assert_equal [hidden(11, 14, 49, :puzzle_right_way)], targets
  end

  test "lists the purple symbol from its switch until the leader's room opens, by its name only then" do
    on_map(277)
    symbol = place(4, 13, 29, [TestCmd.new(201, [0, 276, 5, 43])], :sprite => "brujita")
    assert_empty targets
    refute_equal t(:z_romantis_symbol), PokeAccess::Locator.target_name(symbol)
    $game_switches[479] = true
    assert_equal [spot(13, 29, :z_romantis_symbol, 4)], targets
    assert_equal t(:z_romantis_symbol), PokeAccess::Locator.target_name(symbol)
    $game_switches[493] = true
    assert_empty targets
  end

  test "says on landing in each room of the keep which tile goes on, to the assist alone" do
    rooms = [[9, 43, 3, :z_romantis_1], [46, 24, 17, :z_romantis_2], [46, 41, 20, :z_romantis_3],
    [4, 27, 6, :z_romantis_4],
             [46, 11, 13, :z_romantis_5], [4, 11, 9, :z_romantis_side_tm], [27, 11, 10, :z_romantis_side_west]]
    on_map(276)
    stand(25, 39)
    rooms.each { |r| place(r[2], 1, r[2], [TestCmd.new(201, [0, 276, 1, 1])], :trigger => 1) }
    assert_equal [[t(:z_romantis_rule), false]], tick, "the rule, on arrival"
    rooms.each do |x, y, _event, _key|
      stand(x, y)
      assert_equal [], tick
      assert_empty targets, "nothing listed without the assist"
    end
    assist_on
    stand(25, 39)
    tick
    rooms.each do |x, y, event, key|
      stand(x, y)
      assert_equal [[t(key), false]], tick, "room of event #{event}"
      assert_equal [hidden(event, 1, event, :puzzle_right_way)], targets
      stand(25, 39)
      tick
    end
  end

  test "says on landing in each of the palace's rows which of its three tiles goes on" do
    rows = [[21, 43, 2, :z_ultimate_right], [23, 30, 4, :z_ultimate_center], [21, 22, 6, :z_ultimate_left],
            [17, 13, 8, :z_ultimate_right], [38, 8, 11, :z_ultimate_back]]
    on_map(476)
    stand(40, 1)
    rows.each { |r| place(r[2], 1, r[2], [TestCmd.new(201, [0, 476, 1, 1])], :trigger => 1) }
    assist_on
    tick
    rows.each do |x, y, event, key|
      stand(x, y)
      assert_equal [[t(key), false]], tick, "row of event #{event}"
      assert_equal [hidden(event, 1, event, :puzzle_right_way)], targets
    end
    PokeAccess::Config.puzzle_assist = false
    assert_empty targets
    stand(21, 43)
    assert_equal [], tick
  end

  test "follows the asylum's two rounds by its switches, in words for the assist alone" do
    asylum_tiles
    stand(40, 20)
    assert_equal [], tick
    assert_equal "", PokeAccess::Puzzles.info_line.to_s
    $game_switches[790] = true
    assert_equal [], tick
    assert_empty targets
    $game_switches[790] = false
    assist_on
    tick
    assert_equal t(:z_asylum_1), info_key
    stand(53, 38)
    $game_switches[790] = true
    assert_equal [[t(:z_asylum_2), false]], tick, "crossed the south corridor"
    assert_equal [hidden(18, 76, 18, :puzzle_right_way)], targets
    stand(76, 18)
    assert_equal [], tick, "onto the east tile"
    $game_switches[791] = true
    assert_equal [], tick, "its scene, which sets the switch first"
    stand(58, 19)
    $game_switches[790] = false
    assert_equal [[t(:z_asylum_3), false]], tick, "landed in the alcove, the other switch cleared on landing"
    assert_equal [], tick
    assert_empty targets
    stand(58, 21)
    $game_switches[789] = true
    assert_equal [[t(:z_asylum_4), false]], tick, "out of the alcove by its south"
    assert_equal [hidden(20, 73, 39, :puzzle_right_way)], targets
    stand(63, 25)
    $game_switches[789] = false
    assert_equal [[t(:z_asylum_3), false]], tick, "back east along the central corridor"
  end

  test "says nothing through the scene of the south-east tile, whichever phase its switch would open" do
    [false, true].each do |east_open|
      asylum_tiles
      assist_on
      $game_switches[789] = true
      $game_switches[790] = east_open
      $game_switches[791] = true
      stand(72, 39)
      tick
      stand(73, 39)
      assert_equal [], tick, "onto it"
      $game_switches[791] = false
      assert_equal [], tick, "791 off before its animation and its fade"
      assert_equal [], tick
      assert_empty targets
    end
  end

  test "says nothing through the scene of the alcove's tile, and the east part's way only on landing" do
    [false, true].each do |east_open|
      asylum_tiles
      assist_on
      $game_switches[789] = false
      $game_switches[790] = east_open
      $game_switches[791] = true
      stand(58, 19)
      tick
      stand(58, 20)
      assert_equal [], tick, "onto it"
      $game_switches[791] = false
      assert_equal [], tick, "791 off before its animation"
      stand(76, 19)
      assert_equal [[t(:z_asylum_east), false]], tick, "landed"
    end
  end

  test "sends a player back from map 474 to the corner's tile, one step away, and not around the asylum" do
    [false, true].each do |east_open|
      asylum_tiles
      $game_switches[789] = true
      $game_switches[790] = east_open
      $game_switches[791] = false
      stand(72, 39)
      assert_equal [], tick, "no spoiler without the assist"
      assert_empty targets
      on_map(476)
      assist_on
      stand(72, 39)
      assert_equal [[t(:z_asylum_out), false]], tick, "on landing"
      assert_equal t(:z_asylum_out), info_key
      place(20, 73, 39, [TestCmd.new(201, [0, 474, 58, 22])], :trigger => 1)
      assert_equal [hidden(20, 73, 39, :puzzle_right_way)], targets
      stand(60, 38)
      assert_equal [], tick, "the same way from all the south corridor"
      assert_equal t(:z_asylum_out), info_key
      stand(63, 25)
      $game_switches[789] = false
      assert_includes [t(:z_asylum_1), t(:z_asylum_2)], tick[0][0], "x 63 of the central corridor closes it again"
    end
  end

  test "keeps the corner's tile as the way when (66,32) clears 791 with 789 still on" do
    asylum_tiles
    assist_on
    $game_switches[789] = true
    $game_switches[791] = true
    stand(66, 31)
    tick
    stand(66, 32)
    $game_switches[791] = false
    assert_equal [[t(:z_asylum_out), false]], tick
  end

  test "sends a player the alcove's tile threw behind the east wall to the tile that leads out" do
    on_map(476)
    place(18, 76, 18, [TestCmd.new(201, [0, 476, 58, 19])], :trigger => 1)
    assist_on
    [[76, 19], [69, 24], [68, 24], [70, 26]].each do |x, y|
      stand(x, y)
      assert_equal t(:z_asylum_east), info_key, "at (#{x}, #{y})"
      assert_equal [hidden(18, 76, 18, :puzzle_right_way)], targets
    end
    [[66, 24], [67, 25], [68, 26]].each do |x, y|
      stand(x, y)
      assert_equal t(:z_asylum_1), info_key, "at (#{x}, #{y}), this side of the wall"
    end
  end

  test "names the Maraña's ropes and cobwebs, which core would call another part of it" do
    [[387, 4, :z_tangle_rope_down], [387, 5, :z_tangle_rope_up], [387, 11, :z_tangle_web], [388, 4, :z_tangle_rope_up],
     [388, 5, :z_tangle_rope_down], [388, 7, :z_tangle_web], [384, 1, :z_tangle_rope_down]].each do |map, id, key|
      on_map(map)
      exit_event = place(id, 3, 3, [TestCmd.new(201, [0, map, 1, 1])], :trigger => 1)
      assert_equal t(key), PokeAccess::Locator.target_name(exit_event), "map #{map}, event #{id}"
      assert PokeAccess::Locator.in_category?(exit_event, :exits)
    end
  end

  test "says from each part of the Maraña which rope or cobweb goes on, the wrong ones' rope back too" do
    [[387, 10, 25, 4, :z_tangle_1], [387, 8, 8, 4, :z_tangle_1], [387, 45, 24, 11, :z_tangle_2],
     [387, 4, 48, 15, :z_tangle_3], [387, 29, 54, 18, :z_tangle_4], [387, 33, 6, 3, :z_tangle_detour],
     [387, 38, 8, 6, :z_tangle_platform], [387, 38, 10, 6, :z_tangle_platform], [387, 30, 39, 9, :z_tangle_detour],
     [388, 21, 27, 7, :z_tangle_5], [388, 48, 20, 4, :z_tangle_6], [388, 4, 33, 1, :z_tangle_detour],
     [388, 30, 8, 2, :z_tangle_platform], [388, 45, 33, 6, :z_tangle_detour]].each do |map, x, y, event, key|
      on_map(map)
      place(event, 1, event, [TestCmd.new(201, [0, map, 1, 1])], :trigger => 1)
      stand(x, y)
      assert_equal "", PokeAccess::Puzzles.info_line.to_s, "map #{map} at (#{x}, #{y})"
      assert_empty targets
      assist_on
      assert_equal t(key), info_key, "map #{map} at (#{x}, #{y})"
      assert_equal [hidden(event, 1, event, :puzzle_right_way)], targets
    end
  end

  test "gives no way through the forest's first map while the old man still turns the player back" do
    on_map(355)
    $game_switches[622] = false
    stand(1, 12)
    PokeAccess::Config.puzzle_assist = true
    refute_includes info_key.to_s, t(:z_forest_e)
    $game_switches[622] = true
    assert_includes info_key, t(:z_forest_e)
  end

  test "gives the way to Villa Pokémon from each part of the forest, to the assist alone, the totems still counted" do
    [[355, 1, 12, :z_forest_e], [353, 1, 10, :z_forest_s], [353, 1, 25, :z_forest_w], [32, 9, 1, :z_forest_e],
     [365, 1, 13, :z_forest_n], [366, 1, 14, :z_forest_w], [366, 38, 26, :z_forest_se], [367, 13, 1, :z_forest_s],
     [367, 39, 1, :z_forest_n], [368, 23, 32, :z_forest_se], [368, 40, 2, :z_forest_n], [368, 1, 26, :z_forest_w],
     [369, 24, 20, :z_forest_e], [370, 3, 14, :z_forest_w], [370, 38, 14, :z_forest_e], [371, 19, 1, :z_forest_se],
     [371, 33, 13, :z_forest_e], [372, 11, 1, :z_forest_n], [372, 40, 30, :z_forest_e]].each do |map, x, y, key|
      on_map(map)
      $game_switches[622] = true
      $game_variables[220] = 2
      stand(x, y)
      count = t(:puzzle_progress, :label => t(:z_forest_totems), :n => 2, :of => 15)
      assert_equal count, info_key, "map #{map} at (#{x}, #{y})"
      assist_on
      assert_equal "#{count}. #{t(key)}", info_key, "map #{map} at (#{x}, #{y})"
      $game_variables[220] = 15
      said = info_key
      shaymin = [:z_forest_shaymin_way, :z_forest_shaymin_here, :z_forest_shaymin_367, :z_forest_shaymin_371]
      shaymin = shaymin.map { |k| t(k) }
      assert said == t(key) || shaymin.include?(said), "map #{map} at (#{x}, #{y}), all the totems awake: #{said}"
    end
  end

  test "points at Shaymin from map 368 and on its own map once the totems are awake, until it was met" do
    on_map(368)
    stand(23, 32)
    $game_variables[220] = 14
    assist_on
    assert_includes info_key, t(:z_forest_se)
    $game_variables[220] = 15
    assert_equal t(:z_forest_shaymin_way), info_key
    stand(40, 2)
    assert_equal t(:z_forest_n), info_key, "the other part of the map has its own way"
    on_map(366)
    assist_on
    stand(1, 14)
    $game_variables[220] = 15
    assert_equal t(:z_forest_shaymin_here), info_key
    $game_self_switches[[366, 15, "A"]] = true
    assert_equal t(:z_forest_w), info_key
  end

  test "points back to Shaymin from the maps past its turn, once the totems are awake" do
    [[367, 13, 1, :z_forest_s, :z_forest_shaymin_367],
     [371, 19, 1, :z_forest_se, :z_forest_shaymin_371]].each do |map, x, y, way, both|
      on_map(map)
      stand(x, y)
      assist_on
      $game_variables[220] = 14
      assert_includes info_key, t(way)
      $game_variables[220] = 15
      assert_equal t(both), info_key, "map #{map}"
    end
  end

  test "says the open phase's hint on coming onto a map, queued after its rule, to the assist alone and never its title" do
    on_map(265)
    stand(3, 22)
    $game_variables[185] = 0
    assert_equal [[t(:z_tower_doors_rule), false]], tick, "without the assist, the rule alone"
    on_map(265)
    assist_on
    stand(3, 22)
    assert_equal [[t(:z_tower_doors_rule), false], [t(:z_tower_a_hint), false]], tick
    assert_equal [], tick, "once"
    stand(26, 22)
    assert_equal [], tick, "and not again within the map"
  end

  test "says on coming onto a map the hint of a quiet phase too, and nothing for one with no hint" do
    on_map(365)
    assist_on
    stand(1, 13)
    assert_equal [[t(:z_forest_n), false]], tick
    assert_equal [], tick
    on_map(123)
    assist_on
    $game_switches[226] = true
    $game_switches[227] = true
    assert_equal [], tick, "the riddle's return phase holds no hint"
  end

  test "says the library's hidden books as they are pushed and takes the beams away with the second" do
    beams = library
    assert_equal [control(10, 32, 20, :z_arma_book_e), control(11, 20, 13, :z_arma_book_nw)], targets.first(2)
    assert_equal t(:z_arma_book_nw), PokeAccess::Locator.target_name($game_map.events[11])
    tick
    still = "#{t(:z_arma_book_nw)}: #{t(:z_arma_book_still)}. #{t(:z_arma_book_e)}: #{t(:z_arma_book_still)}"
    assert_equal still, info_key
    refute_includes info_key, t(:z_arma_books_hint)
    assist_on
    assert_includes info_key, t(:z_arma_books_hint)
    PokeAccess::Config.puzzle_assist = false
    $game_switches[788] = true
    assert_equal [["#{t(:z_arma_book_nw)}: #{t(:z_arma_book_pushed)}", false]], tick
    $game_switches[787] = true
    beams.each { |ev| show_page(ev, 1) }
    gone = t(:ctrl_group, :what => t(:z_arma_beams), :changes => t(:ctrl_quit, :n => 2))
    assert_equal [["#{t(:z_arma_book_e)}: #{t(:z_arma_book_pushed)}. #{gone}", false]], tick
    refute PokeAccess::Puzzles.active?, "both pushed: the info key goes back to its usual job"
  end

  test "names the mirrors of map 473 by the dimension they lead to, listed with no assist, and says where they land" do
    on_map(473)
    [[38, 7, 5, 56, 6], [64, 22, 42, 71, 43], [39, 56, 5, 7, 6], [65, 71, 42, 22, 43]].each do |id, x, y, tx, ty|
      place(id, x, y, [TestCmd.new(201, [0, 473, tx, ty])], :trigger => 1)
    end
    on_map(473)
    expected = [spot(7, 5, :z_lanto_mirror_alt, 38), spot(22, 42, :z_lanto_mirror_alt, 64), spot(56, 5, :z_lanto_mirror_real, 39),
                spot(71, 42, :z_lanto_mirror_real, 65)]
    stand(37, 8)
    assert_equal expected, targets
    assert_equal t(:z_lanto_mirror_alt), PokeAccess::Locator.target_name($game_map.events[38])
    assert_equal t(:z_lanto_mirror_real), PokeAccess::Locator.target_name($game_map.events[65])
    assert_equal [], tick, "the real half on arrival"
    assert_equal "", PokeAccess::Puzzles.info_line.to_s
    assert_equal [[t(:z_lanto_alt), false]], teleported(7, 5, 56, 6)
    assert_equal t(:z_lanto_alt), info_key, "the grey half"
    assert_equal [[t(:z_arma_real), false]], teleported(71, 42, 22, 43)
    assert_equal "", PokeAccess::Puzzles.info_line.to_s
  end

  test "gives the way on from each part of map 473, to the assist alone" do
    [[37, 8, 38, :z_arma_mirror_nw], [5, 12, 38, :z_arma_mirror_nw], [56, 6, 5, :z_arma_band_n], [72, 31, 9, :z_arma_band_se],
     [86, 40, 65, :z_arma_mirror_w], [22, 43, 10, :z_arma_band_ne], [34, 31, 3, :z_arma_lift], [9, 35, 3, :z_arma_lift],
     [21, 3, 4, :z_arma_side], [18, 7, 4, :z_arma_side]].each do |x, y, event, key|
      on_map(473)
      place(event, 1, 1, [TestCmd.new(201, [0, 473, 1, 1])], :trigger => 1)
      stand(x, y)
      refute_includes info_key.to_s, t(key)
      assist_on
      assert_includes info_key, t(key), "at (#{x}, #{y})"
      assert_includes targets, hidden(event, 1, 1, :puzzle_right_way)
    end
  end

  test "gives the way on from each part of map 477, to the assist alone" do
    [[7, 6, 6, :z_arma_web_e], [21, 15, 6, :z_arma_web_e], [30, 8, 6, :z_arma_web_s], [50, 20, 6, :z_arma_web_here],
     [55, 26, 6, :z_arma_web_w], [12, 61, 12, :z_arma_door_ledge], [24, 40, 12, :z_arma_door_ledge],
     [14, 50, 12, :z_arma_door_south], [45, 50, 7, :z_arma_web_flower], [23, 67, 12, :z_arma_door_ledge], [29, 60, 12, :z_arma_door_here],
     [38, 47, 11, :z_arma_door_ne], [44, 62, 11, :z_arma_door_ne], [48, 41, 7, :z_arma_web_flower],
     [56, 55, 7, :z_arma_web_flower]].each do |x, y, event, key|
      on_map(477)
      place(event, 1, 1, [TestCmd.new(201, [0, 477, 1, 1])], :trigger => 1)
      stand(x, y)
      assert_equal "", PokeAccess::Puzzles.info_line.to_s
      assert_empty targets
      assist_on
      assert_equal t(key), info_key, "at (#{x}, #{y})"
      assert_equal [hidden(event, 1, 1, :puzzle_right_way)], targets
    end
  end

  test "names the cobwebs of the third vine, and tells the factory's pushing floor with its one exit" do
    on_map(477)
    web = place(6, 51, 14, [TestCmd.new(201, [0, 470, 24, 33])], :trigger => 1)
    assert_equal t(:z_tangle_web), PokeAccess::Locator.target_name(web)
    on_map(470)
    exit_web = place(1, 37, 30, [TestCmd.new(201, [0, 477, 48, 41])], :trigger => 1)
    assert_equal t(:z_tangle_web), PokeAccess::Locator.target_name(exit_web)
    stand(24, 33)
    assert_equal [[t(:z_arma_push_rule), false]], tick
    assert_equal t(:z_arma_push_rule), info_key
    assert_empty targets
    on_map(470)
    assist_on
    assert_equal [[t(:z_arma_push_rule), false], [t(:z_arma_push_hint), false]], tick
    assert_equal [hidden(1, 37, 30, :puzzle_right_way)], targets
  end

  test "names the Arma's thorns and marker flowers by what they are, objects and not people" do
    [["espinasArma", :z_arma_thorns], ["floresIndicadores", :z_arma_flower_mark]].each do |sprite, key|
      on_map(471)
      ev = place(38, 42, 20, [], :sprite => sprite)
      assert_equal t(key), PokeAccess::Locator.target_name(ev)
      assert PokeAccess::Locator.in_category?(ev, :objects)
    end
  end

  test "says around each tile of the ice floor what is free and what is broken, with no assist" do
    on_map(321)
    stand(7, 19)
    tick
    stand(7, 18)
    free = PokeAccess::Routes::Text.and_list([t(:side_left), t(:side_right), t(:side_up)])
    assert_equal [[t(:z_ice_free, :list => free), false]], tick, "the first tile, all whole"
    break_ice(7, 18)
    stand(6, 18)
    free = PokeAccess::Routes::Text.and_list([t(:side_left)])
    assert_equal [["#{t(:z_ice_free, :list => free)}. #{t(:z_ice_broken, :list => t(:side_right))}", false]], tick
    break_ice(5, 18)
    break_ice(6, 18)
    stand(7, 19)
    assert_includes info_key, t(:z_ice_rule), "before the floor, its rule"
  end

  test "counts the tiles on the info key, and keeps the next step to the assist" do
    on_map(321)
    stand(6, 18)
    break_ice(7, 18)
    $game_variables[204] = 1
    count = t(:puzzle_progress, :label => t(:z_ice_count), :n => 1, :of => 38)
    assert_includes info_key, count
    refute_includes info_key, t(:z_ice_next, :dir => t(:side_left))
    assist_on
    assert_includes info_key, t(:z_ice_next, :dir => t(:side_left))
  end

  test "leads the assist across the whole ice floor, ending under the rock" do
    on_map(321)
    assist_on
    stand(7, 19)
    tick
    x = 7
    y = 18
    1.upto(38) do |n|
      stand(x, y)
      said = tick[0][0]
      break_ice(x, y)
      $game_variables[204] = n
      if n == 38
        assert_includes said, t(:z_ice_done)
      else
        side = PokeAccess::Puzzles::SIDES.find { |_dx, _dy, key| said.include?(t(:z_ice_next, :dir => t(key))) }
        refute_nil side, "tile #{n}, at (#{x}, #{y}): #{said}"
        x += side[0]
        y += side[1]
      end
    end
    assert_equal [7, 15], [x, y]
    assert_includes info_key, t(:z_ice_free, :list => t(:side_up)), "the rock gone: the way out, the only free side"
  end

  test "walks the ice floor by a known way through, and says when a round can no longer be finished" do
    on_map(321)
    assist_on
    tick
    x = 7
    y = 18
    "LLULDLLUUURDRRURDRDRDRUURDRDRUUULLLLL".split("").each do |c|
      break_ice(x, y)
      x += c == "L" ? -1 : (c == "R" ? 1 : 0)
      y += c == "U" ? -1 : (c == "D" ? 1 : 0)
      stand(x, y)
      refute_includes info_key, t(:z_ice_lost), "at (#{x}, #{y})"
    end
    assert_equal [7, 15], [x, y]
    $game_self_switches.clear
    break_ice(7, 18)
    stand(8, 18)
    assert_includes info_key, t(:z_ice_lost), "no way through starts to the right"
    $game_self_switches.clear
    break_ice(7, 15)
    stand(6, 15)
    assert_includes info_key, t(:z_ice_lost), "the tile under the rock trodden too soon"
  end

  test "says nothing as the player steps on a broken tile, and tells the fall in place of a bare teleport" do
    on_map(321)
    assist_on
    stand(7, 19)
    tick
    break_ice(6, 18)
    moving_player do
      stand(6, 18)
      assert_equal [], tick
    end
    assert_equal [[t(:z_ice_fell), false]], teleported(6, 18, 59, 39)
    assert_equal [], tick, "the fall's own line says the way back"
    assert_includes info_key, t(:z_fractal_back), "the room it lands in"
    on_map(321)
    plain = PokeAccess::Locator.teleport_line(10, 10, 20, 20)
    assert_equal [[plain, false]], teleported(10, 10, 20, 20), "any other teleport"
  end

  test "calls a broken ice tile so, where a transfer would make it a passage" do
    on_map(321)
    tile = place(22, 7, 18, [TestCmd.new(201, [0, 321, 59, 39])], :trigger => 1)
    refute_equal t(:z_ice_tile_broken), PokeAccess::Locator.target_name(tile)
    break_ice(7, 18)
    assert_equal t(:z_ice_tile_broken), PokeAccess::Locator.target_name(tile)
  end

  test "retires the ice floor once crossed" do
    on_map(321)
    stand(6, 18)
    refute_equal "", PokeAccess::Puzzles.info_line.to_s
    $game_switches[541] = true
    assert_equal "", PokeAccess::Puzzles.info_line.to_s
  end

  test "lists the buttons still to tread on, says each press and, with the assist, the next" do
    on_map(321)
    [[71, 19, 42], [72, 40, 42], [87, 35, 24], [94, 24, 24], [62, 29, 6], [41, 52, 43]].each do |id, x, y|
      place(id, x, y, [TestCmd.new(121, [569, 569, 0])], :trigger => 1)
    end
    stand(29, 55)
    tick
    assert_equal [spot(19, 42, :z_fractal_button, 71), spot(40, 42, :z_fractal_button, 72), spot(35, 24, :z_fractal_button, 87),
                  spot(24, 24, :z_fractal_button, 94)], targets
    assert_equal "", PokeAccess::Puzzles.info_line.to_s
    assist_on
    assert_equal t(:z_fractal_go1), info_key
    assert_includes targets, hidden(71, 19, 42, :puzzle_right_way)
    tick
    $game_switches[569] = true
    assert_equal [["#{t(:z_fractal_mid)}: #{t(:z_fractal_open)}", false], [t(:z_fractal_go2), false]], tick
    refute_includes targets, spot(19, 42, :z_fractal_button, 71)
    assert_includes targets, hidden(72, 40, 42, :puzzle_right_way)
    $game_switches[571] = true
    $game_switches[569] = false
    assert_equal [["#{t(:z_fractal_mid)}: #{t(:z_fractal_shut)}", false],
                  ["#{t(:z_fractal_low)}: #{t(:z_fractal_low_on)}", false], [t(:z_fractal_go3), false]], tick
    $game_switches[577] = true
    $game_switches[569] = true
    assert_equal [["#{t(:z_fractal_mid)}: #{t(:z_fractal_open)}", false],
                  ["#{t(:z_fractal_high)}: #{t(:z_fractal_high_on)}", false], [t(:z_fractal_go4), false]], tick
    assert_includes targets, hidden(94, 24, 24, :puzzle_right_way)
    $game_switches[576] = true
    assert_equal [["#{t(:z_fractal_north)}: #{t(:z_fractal_north_on)}", false], [t(:z_fractal_go5), false]], tick
    assert_equal [hidden(62, 29, 6, :puzzle_right_way)], targets
    $game_variables[209] = 10
    assert_empty targets, "the bastion beaten"
  end

  test "calls the frozen soldiers so while frozen" do
    on_map(321)
    soldier = place(63, 29, 24, [TestCmd.new(101, ["..."])], :sprite => "soldadosCongelados")
    assert_equal t(:z_fractal_soldier), PokeAccess::Locator.target_name(soldier)
    $game_self_switches[[321, 63, "A"]] = true
    refute_equal t(:z_fractal_soldier), PokeAccess::Locator.target_name(soldier)
  end

  test "tells the clock of rocks on arrival, each room's rocks with no assist and its door with it" do
    rooms = [[11, 17, 3, 2, :z_talasia_e], [11, 30, 6, 10, :z_talasia_s], [11, 54, 6, 14, :z_talasia_s],
             [37, 6, 12, 15, :z_talasia_n], [37, 41, 3, 22, :z_talasia_e], [30, 60, 3, 23, :z_talasia_e],
             [56, 12, 6, 27, :z_talasia_s], [63, 30, 9, 31, :z_talasia_w]]
    on_map(433)
    stand(11, 17)
    assert_equal [[t(:z_talasia_rule), false], [t(:z_talasia_rocks, :n => 3), false]], tick
    assert_equal "#{t(:z_talasia_rocks, :n => 3)}. #{t(:z_talasia_rule)}", info_key
    rooms.drop(1).each do |x, y, rocks, _door, _key|
      stand(x, y)
      assert_equal [[t(:z_talasia_rocks, :n => rocks), false]], tick, "room at (#{x}, #{y})"
      assert_empty targets
    end
    on_map(433)
    assist_on
    rooms.each do |x, y, rocks, door, key|
      place(door, 1, 1, [TestCmd.new(201, [0, 433, 1, 1])], :trigger => 1)
      stand(x, y)
      assert_includes info_key, t(key)
      assert_includes info_key, t(:z_talasia_rocks, :n => rocks)
      assert_equal [hidden(door, 1, 1, :puzzle_right_way)], targets
    end
  end

  test "points at Mew in the last room until it is met" do
    on_map(433)
    place(4, 63, 55, [TestCmd.new(101, ["..."])], :sprite => "151")
    assist_on
    stand(67, 65)
    assert_equal "#{t(:z_talasia_mew)} #{t(:z_talasia_rule)}", info_key
    assert_equal [hidden(4, 63, 55, :puzzle_right_way)], targets
    $game_self_switches[[433, 4, "A"]] = true
    assert_empty targets
    refute PokeAccess::Puzzles.active?, "the info key goes back to its usual job"
  end

  test "says a wrong door that lands on or beside itself, which no teleport reading can tell from a step" do
    temp = Struct.new(:player_new_map_id, :player_new_x, :player_new_y).new(433, 11, 29)
    kept = $game_temp
    $game_temp = temp
    on_map(433)
    tick
    SpeakCapture.clear
    [[11, 29, 11, 29], [71, 36, 70, 36]].each do |x, y, tx, ty|
      stand(x, y)
      temp.player_new_x = tx
      temp.player_new_y = ty
      Scene_Map.new.transfer_player
      assert_equal [[t(:z_talasia_wrong), false]], SpeakCapture.log.uniq, "door at (#{x}, #{y}); on_map stacks the hook"
      SpeakCapture.clear
    end
    stand(36, 18)
    temp.player_new_x = 37
    temp.player_new_y = 17
    Scene_Map.new.transfer_player
    assert_empty SpeakCapture.log, "two tiles or more are the teleport reading's"
    stand(11, 29)
    temp.player_new_map_id = 434
    temp.player_new_x = 11
    temp.player_new_y = 29
    Scene_Map.new.transfer_player
    assert_empty SpeakCapture.log, "a door off the map"
  ensure
    $game_temp = kept
  end

  test "says a wrong door of the cave for what it was, and the room after a right one" do
    on_map(433)
    assert_equal [[t(:z_talasia_wrong), false]], teleported(11, 5, 11, 17), "back within the same room"
    assert_equal [[t(:z_talasia_wrong), false]], teleported(45, 12, 37, 17)
    assert_equal [[t(:z_talasia_wrong), false]], teleported(37, 53, 37, 41), "the sixth room's lead to the fifth"
    plain = PokeAccess::Locator.teleport_line(11 - 19, 29 - 12, 11, 29)
    assert_equal [[plain, false]], teleported(19, 12, 11, 29), "the right door"
  end

  test "names the cave's doors by their own side, whatever they lead to" do
    on_map(433)
    [[6, :z_talasia_door_n], [10, :z_talasia_door_s], [2, :z_talasia_door_e], [3, :z_talasia_door_w],
     [31, :z_talasia_door_w]].each do |id, key|
      door = place(id, 3, 3, [TestCmd.new(201, [0, 433, 11, 29])], :trigger => 1)
      assert_equal t(key), PokeAccess::Locator.target_name(door), "event #{id}"
    end
  end

  test "lists the factory's levers by their place and says what each turned, on and off" do
    levers = factory_levers
    assert_equal [control(12, 2, 12, :z_factory_lever_nw), control(20, 22, 24, :z_factory_lever_mid),
                  control(33, 32, 9, :z_factory_lever_ne)], targets.first(3)
    tick
    $game_switches[484] = true
    assert_equal [["#{t(:z_factory_lever_nw)}: #{t(:z_factory_lever_nw_on)}", false]], tick
    $game_switches[485] = true
    assert_equal [["#{t(:z_factory_lever_mid)}: #{t(:z_factory_lever_mid_on)}", false]], tick
    $game_switches[488] = true
    assert_equal [["#{t(:z_factory_lever_ne)}: #{t(:z_factory_lever_ne_on)}", false]], tick
    $game_switches[484] = false
    assert_equal [["#{t(:z_factory_lever_nw)}: #{t(:z_factory_lever_off)}", false]], tick
    assert_equal 3, levers.length
    assert_equal "", PokeAccess::Puzzles.info_line.to_s
  end

  test "ends the factory's way once the scene past its door has been played" do
    [[235, 19, 39, 12], [236, 3, 27, 6]].each do |map, x, y, event|
      on_map(map)
      place(event, 1, 1, [TestCmd.new(201, [0, map, 1, 1])], :trigger => 1)
      assist_on
      stand(x, y)
      assert_includes targets, hidden(event, 1, 1, :puzzle_right_way), "map #{map} before the scene"
      assert_equal t(map == 235 ? :z_factory_go_nw : :z_factory_down_e), PokeAccess::Puzzles.info_line.to_s
      $game_switches[491] = true
      refute_includes targets, hidden(event, 1, 1, :puzzle_right_way), "map #{map} after the scene"
      assert_equal "", PokeAccess::Puzzles.info_line.to_s, "map #{map}: the info key goes back to its usual job"
      $game_switches[491] = false
    end
  end

  test "gives the factory's way in the guide's order from each part of its floors, to the assist alone" do
    [[235, 19, 39, [], 12, :z_factory_go_nw], [235, 3, 12, [484], 34, :z_factory_lift], [235, 19, 39, [484], 6, :z_factory_up_sw],
     [235, 36, 23, [484], 20, :z_factory_go_mid], [235, 22, 25, [484, 485], 6, :z_factory_up_sw],
     [235, 36, 23, [484, 485], 7, :z_factory_up_e], [235, 21, 6, [484, 485], 33, :z_factory_go_ne],
     [235, 32, 10, [484, 485, 488], 9, :z_factory_door], [235, 8, 9, [484, 485, 488], 9, :z_factory_door],
     [235, 19, 39, [484, 485, 488], 6, :z_factory_up_sw], [236, 3, 27, [484], 6, :z_factory_down_e],
     [236, 3, 27, [484, 485], 7, :z_factory_down_n]].each do |map, x, y, on, event, key|
      on_map(map)
      [484, 485, 488].each { |s| $game_switches[s] = on.include?(s) }
      place(event, 1, 1, [TestCmd.new(201, [0, map, 1, 1])], :trigger => 1)
      stand(x, y)
      assert_equal "", PokeAccess::Puzzles.info_line.to_s, "map #{map} at (#{x}, #{y})"
      assist_on
      assert_equal t(key), info_key, "map #{map} at (#{x}, #{y}) with #{on.inspect}"
      assert_includes targets, hidden(event, 1, 1, :puzzle_right_way)
    end
  end

  test "says each crystal of the forge as its scene lights it, its memory's switch long on" do
    on_map(318)
    $game_switches[546] = true
    assert_equal [], tick
    assert_equal "#{t(:z_forge_left)}: #{t(:z_forge_unlit)}. #{t(:z_forge_right)}: #{t(:z_forge_unlit)}", info_key
    refute_includes info_key, t(:z_forge_hint)
    $game_self_switches[[318, 69, "A"]] = true
    assert_equal [], tick, "its first frame, the light still rising"
    $game_self_switches[[318, 69, "C"]] = true
    assert_equal [["#{t(:z_forge_left)}: #{t(:z_forge_lit)}", false]], tick
    assist_on
    assert_includes info_key, t(:z_forge_hint)
    PokeAccess::Config.puzzle_assist = false
    $game_self_switches[[318, 70, "C"]] = true
    assert_equal [["#{t(:z_forge_right)}: #{t(:z_forge_lit)}", false]], tick
    refute PokeAccess::Puzzles.active?, "both lit: the info key goes back to its usual job"
    on_map(318)
    $game_self_switches[[318, 69, "C"]] = true
    $game_self_switches[[318, 70, "C"]] = true
    assert_equal [], tick, "lit before the player came"
  end

  test "the tower's warp floor says its rule on arrival until Hibis is beaten, not merely asked for time, then neither it nor its rooms" do
    on_map(265)
    $game_switches[468] = true
    stand(3, 22)
    assert_equal [[t(:z_tower_doors_rule), false]], tick, "asked for time: the doors are still ahead"
    refute_nil PokeAccess::Puzzles.info_line
    on_map(265)
    $game_switches[470] = true
    stand(3, 22)
    assert_equal [], tick
    assert_nil PokeAccess::Puzzles.info_line
  end

  test "the Romantis keep says its rule on arrival and its rooms on the info key until the leader is beaten, then neither" do
    on_map(276)
    stand(25, 39)
    assert_equal [[t(:z_romantis_rule), false]], tick
    assist_on
    stand(9, 43)
    refute_nil PokeAccess::Puzzles.info_line
    on_map(276)
    $game_switches[493] = true
    assist_on
    stand(25, 39)
    assert_equal [], tick
    stand(9, 43)
    assert_nil PokeAccess::Puzzles.info_line
  end

  test "the cave of Talasia says its rule and the rocks of its rooms until Mew is met, then neither" do
    on_map(433)
    stand(11, 17)
    assert_equal [[t(:z_talasia_rule), false], [t(:z_talasia_rocks, :n => 3), false]], tick
    refute_nil PokeAccess::Puzzles.info_line
    on_map(433)
    $game_self_switches[[433, 4, "A"]] = true
    stand(11, 17)
    assert_equal [], tick
    assert_nil PokeAccess::Puzzles.info_line
  end

  private

  # The spoken text of an i18n key.
  def t(key, vars = {})
    PokeAccess::I18n.t(key, vars)
  end

  # Declares the shipped puzzles as the harness loads the profile and puts the player on map, the assist off.
  def on_map(map)
    Harness.load_puzzles("pokemon_z")
    PokeAccess::Config.puzzle_assist = false
    $game_map.map_id = map
    $game_self_switches.clear
    $game_variables[220] = 0
    $game_variables[89] = 0
    World.next_frame
  end

  # The player moved to (x, y), as a warp would.
  def stand(x, y)
    $game_player.x = x
    $game_player.y = y
    World.next_frame
  end

  # The puzzle assist on.
  def assist_on
    PokeAccess::Config.puzzle_assist = true
  end

  # An event at (x, y) whose live page runs list, placed on the map: opts take its :sprite, :name, :trigger, :through and
  # :pattern, and :extra, a second page kept for show_page.
  def place(id, x, y, list, opts = {})
    page = TestPage.new(:trigger => opts.fetch(:trigger, 0), :sprite => opts.fetch(:sprite, ""), :list => list,
                        :through => opts.fetch(:through, false), :pattern => opts.fetch(:pattern, 0))
    pages = opts[:extra] ? [page, opts[:extra]] : [page]
    ev = TestGameEvent.new(:id => id, :x => x, :y => y, :pages => pages, :active_page => page,
                           :name => opts.fetch(:name, "EV#{id}"))
    $game_map.events[id] = ev
    World.next_frame
    ev
  end

  # An event showing one of its pages, by index, as the engine would on a switch.
  def show_page(ev, i)
    page = ev.instance_variable_get(:@event).pages[i]
    ev.instance_variable_set(:@active, page)
    ev.instance_variable_set(:@list, page.list)
    ev.character_name = page.graphic.character_name
    ev.through = page.through
    World.next_frame
  end

  # What the map frame's teleport check says when the player, seen on (x, y), is next seen on (tx, ty) of the map.
  def teleported(x, y, tx, ty)
    stand(x, y)
    PokeAccess::Locator.announce_internal_teleport
    SpeakCapture.clear
    stand(tx, ty)
    PokeAccess::Locator.announce_internal_teleport
    SpeakCapture.log.dup
  end

  # Runs the block with the player between two tiles, as during a step.
  def moving_player
    class << $game_player; def moving?; true; end; end
    yield
  ensure
    class << $game_player; remove_method :moving?; end
  end

  # The ice tile at (x, y) broken, as treading it leaves it: its self switch A, by the events the map holds there.
  def break_ice(x, y)
    rows = { 15 => [[2, 1], [3, 2], [5, 6], [6, 7], [7, 8], [8, 9], [9, 35], [10, 36], [11, 37], [12, 38]],
             16 => [[2, 3], [3, 14], [4, 13], [5, 12], [6, 11], [7, 10], [9, 27], [10, 28], [12, 34]],
             17 => [[2, 4], [4, 15], [5, 19], [7, 20], [8, 25], [9, 24], [10, 29], [11, 30], [12, 33]],
             18 => [[2, 5], [3, 17], [4, 16], [5, 18], [6, 21], [7, 22], [8, 23], [9, 26], [11, 31], [12, 32]] }
    $game_self_switches[[321, rows[y].assoc(x)[1], "A"]] = true
  end

  # Map 476 with the asylum's three tiles placed, its switches off and the assist off.
  def asylum_tiles
    on_map(476)
    [[18, 76, 18, 58, 19], [19, 58, 20, 76, 19], [20, 73, 39, 72, 39]].each do |id, x, y, tx, ty|
      place(id, x, y, [TestCmd.new(201, [0, 476, tx, ty])], :trigger => 1)
    end
    [789, 790, 791].each { |s| $game_switches[s] = false }
    World.next_frame
  end

  # Map 472 with its two hidden books and two of its beams, declared again now that they stand; answers the beams.
  def library
    on_map(472)
    place(10, 32, 20, [TestCmd.new(121, [787, 787, 0])], :name => "#EOT SHOW")
    place(11, 20, 13, [TestCmd.new(121, [788, 788, 0])], :name => "#EOT SHOW")
    both = { :switch1_valid => true, :switch1_id => 787, :switch2_valid => true, :switch2_id => 788 }
    beams = [[12, 27, 37], [13, 28, 37]].map do |id, x, y|
      place(id, x, y, [], :sprite => "rayosBarrera", :extra => TestPage.new(:condition => both))
    end
    on_map(472)
    stand(22, 15)
    beams
  end

  # Map 235 with its three levers, declared again now that they stand; answers them.
  def factory_levers
    on_map(235)
    levers = [[12, 2, 12, 484], [20, 22, 24, 485], [33, 32, 9, 488]].map do |id, x, y, switch|
      place(id, x, y, [TestCmd.new(121, [switch, switch, 0])], :sprite => "palancas")
    end
    on_map(235)
    levers
  end

  # The three crystals of map 51, each touch page still to run.
  def crystals_on_51
    [[27, 11, 24], [29, 21, 29], [31, 33, 67]].each do |id, x, y|
      place(id, x, y, [TestCmd.new(121, [133, 133, 0])], :sprite => "rocaElectrica", :trigger => 1)
    end
  end

  # Map 109's lever and spikes, as [lever, spikes], declared again now that they stand.
  def lever_and_spikes
    on_second = { :switch1_valid => true, :switch1_id => 160 }
    lever = place(31, 4, 37, [TestCmd.new(121, [160, 160, 0])], :sprite => "palancas", :pattern => 2,
                  :extra => TestPage.new(:sprite => "palancas", :pattern => 1, :condition => on_second))
    spikes = place(32, 13, 39, [], :sprite => "pinchos", :pattern => 2,
                   :extra => TestPage.new(:sprite => "pinchos", :pattern => 2, :through => true, :condition => on_second))
    on_map(109)
    $game_variables[89] = 10
    [lever, spikes]
  end

  # What the tower's steps should be: [map, x, y, switches on, the step].
  def tower_steps
    [[262, 50, 20, [458, 461], :z_tower_e_tp], [262, 50, 20, [459, 461], :z_tower_e_tp],
     [262, 50, 20, [458, 460], :z_tower_e_down], [262, 50, 20, [460], :z_tower_e_down],
     [262, 50, 20, [460, 462], :z_tower_jukebox], [262, 50, 20, [461, 462, 463], :z_tower_north_door],
     [262, 20, 15, [458, 461], :z_tower_w_tp], [262, 20, 15, [459, 461], :z_tower_w_tp],
     [262, 5, 8, [459, 461], :z_tower_pocket], [262, 20, 15, [460], :z_tower_lanto],
     [262, 32, 15, [460], :z_tower_pocket], [262, 20, 15, [461, 462], :z_tower_w_east],
     [262, 32, 15, [460, 462], :z_tower_w_east], [262, 20, 15, [460, 462], :z_tower_w_down],
     [262, 20, 15, [459, 460, 462], :z_tower_w_tp],
     [263, 60, 28, [458, 461], :z_tower_rooms], [263, 20, 20, [458, 461], :z_tower_door_nw],
     [263, 20, 20, [459, 460], :z_tower_door_nw], [263, 20, 20, [461, 462], :z_tower_doors_up],
     [263, 18, 4, [458, 461], :z_tower_pocket], [263, 18, 5, [458, 461], :z_tower_pocket],
     [263, 15, 5, [458, 461], :z_tower_door_nw], [263, 16, 5, [458, 461, 462], :z_tower_doors_up],
     [263, 47, 7, [458, 461], :z_tower_room_tp], [263, 47, 7, [459, 461], :z_tower_rooms],
     [264, 63, 23, [458, 460], :z_tower_se_back], [264, 63, 23, [458, 461], :z_tower_sensor],
     [264, 63, 23, [461], :z_tower_sensor_far], [264, 63, 23, [459, 461], :z_tower_sensor_far],
     [264, 39, 30, [461], :z_tower_up], [264, 37, 28, [461], :z_tower_up], [264, 43, 29, [461], :z_tower_up],
     [264, 43, 27, [461], :z_tower_sensor_far],
     [264, 63, 24, [461], :z_tower_sensor_far], [264, 63, 24, [460], :z_tower_se_back],
     [264, 63, 23, [460], :z_tower_west_door], [264, 64, 27, [458, 461], :z_tower_sensor],
     [264, 3, 16, [460], :z_tower_west_tile], [264, 3, 16, [458, 460], :z_tower_west_tile],
     [264, 3, 16, [459, 460], :z_tower_up], [264, 3, 16, [461], :z_tower_up],
     [264, 3, 16, [460, 462], :z_tower_east_door],
     [264, 59, 9, [458, 461], :z_tower_up], [264, 59, 9, [461], :z_tower_sensor_far],
     [264, 10, 5, [461], :z_tower_up], [264, 64, 27, [458, 460], :z_tower_se_back],
     [264, 59, 9, [460], :z_tower_west_door], [264, 10, 5, [460], :z_tower_up],
     [264, 20, 10, [459, 461], :z_tower_pocket], [264, 22, 25, [459, 460], :z_tower_pocket],
     [264, 64, 27, [458, 461, 462], :z_tower_se_back], [264, 64, 27, [461, 462], :z_tower_up],
     [264, 59, 9, [460, 462], :z_tower_up], [264, 10, 5, [461, 462], :z_tower_east_door],
     [264, 10, 5, [459, 461, 462], :z_tower_up]]
  end

  # A named point, as the locator lists it.
  def spot(x, y, key, ref = nil)
    PokeAccess::Locator::SurfaceTarget.new(x, y, t(key), :puzzle_spot, ref)
  end

  # A hidden event still to find, as the locator lists it.
  def hidden(id, x, y, key)
    PokeAccess::Locator::SurfaceTarget.new(x, y, t(key), :puzzle_hidden, id)
  end

  # A control, as the locator lists it.
  def control(id, x, y, key)
    PokeAccess::Locator::SurfaceTarget.new(x, y, t(key), :puzzle_control, id)
  end

  # The locator's puzzles category now.
  def targets
    PokeAccess::Puzzles.category_targets
  end

  # One frame of the puzzle: what it said.
  def tick
    SpeakCapture.clear
    PokeAccess::Puzzles.tick
    SpeakCapture.log.dup
  end

  # What the info key says on the map now.
  def info_key
    PokeAccess::Info.map_text
  end
end
