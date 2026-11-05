# Pokemon Africanvs' story-blocking puzzles on the shipped profile (games/africanus/puzzles): the gyms of Tarraco,
# Cartago Nova, Gades, Siracusa, Siga and Cirta and the six tests of Cartago's harbour; what each says with no help and
# what the assist adds.
class AfricanvsPuzzlesTest < PokeAccessTest
  SWITCHES = (143..144).to_a + (204..208).to_a + [118, 187, 211, 212, 237, 238, 292, 293, 294, 295, 296, 297, 298, 374, 375, 376,
                                                    377, 378, 379, 380, 381, 382, 383, 67, 69, 288]
  VARIABLES = [56, 57, 58, 64, 65, 98, 99, 100, 101, 102, 103, 104, 32, 55, 91]

  test "Tarraco numbers its six levers, says which one is on and, with the assist, the next of the chain" do
    on_map(112)
    { 110 => [40, 35], 112 => [20, 24], 113 => [38, 13], 115 => [18, 8], 117 => [46, 3], 120 => [8, 8] }.each do |id, (x, y)|
      place(id, x, y, [TestCmd.new(101, ["lever"])], "palancas")
    end
    expected = [[8, 8, 2], [18, 8, 3], [20, 24, 5], [38, 13, 4], [40, 35, 6], [46, 3, 1]]
    assert_equal expected.map { |x, y, n| [x, y, t(:af_tarraco_lever, :n => n)] }, listed
    frame
    assert_equal [t(:af_tarraco_on, :n => 6)], frame { $game_switches[205] = true }
    assert_equal [t(:af_tarraco_off)], frame { $game_switches[205] = false }
    PokeAccess::Config.puzzle_assist = true
    assert_equal ["#{t(:af_tarraco_on, :n => 5)}. #{t(:af_tarraco_next, :n => 4)}"], frame { $game_switches[204] = true }
    assert_includes info_key, t(:af_tarraco_next, :n => 4)
    assert_equal ["#{t(:af_tarraco_on, :n => 1)}. #{t(:af_tarraco_leader)}"],
                 frame { $game_switches[204] = false; $game_switches[206] = $game_switches[208] = true }
    PokeAccess::Config.puzzle_assist = false
    refute_includes info_key, t(:af_tarraco_leader)
    assert_includes info_key, t(:af_tarraco_rule)
  end

  test "Cartago Nova lists the torches left to light, counts them and says when the barrier goes" do
    on_map(117)
    place(4, 2, 27, [TestCmd.new(101, ["lit"])], "000")
    place(1, 41, 18, [TestCmd.new(101, ["lit"])], "000")
    barrier = tile(2, 11, 8, 2758)
    assert_equal [[2, 27, t(:af_torch)], [41, 18, t(:af_torch)]], listed
    assert_equal t(:af_torch_barrier), PokeAccess::Puzzles.piece_name(barrier)
    frame
    assert_equal [t(:puzzle_progress, :label => t(:af_torches), :n => 1, :of => 2)], frame { $game_switches[143] = true }
    $game_self_switches[[117, 4, "A"]] = true
    assert_equal [[41, 18, t(:af_torch)]], listed
    assert_equal [t(:puzzle_progress, :label => t(:af_torches), :n => 2, :of => 2), t(:af_torch_open)],
                 frame { $game_switches[144] = true }
    $game_self_switches[[117, 1, "A"]] = true
    assert_empty listed
    $game_switches[143] = $game_switches[144] = false
    refute_includes info_key, t(:af_torch_hint)
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, t(:af_torch_hint)
  end

  test "Gades names its turning statues by who they are, says the facing with the answer for the assist alone, and why a Rampardos sent the player back" do
    on_map(270)
    machop = place(20, 11, 6, [TestCmd.new(101, ["turn"])], "066")
    far_machop = place(18, 21, 22, [TestCmd.new(101, ["turn"])], "066")
    trap = place(31, 9, 7, [TestCmd.new(201, [0, 270, 18, 32, 8, 0])], "409")
    frame
    assert_equal ["#{t(:af_gades_machop)}: #{t(:face_east)}"], frame { machop.direction = 6 }
    PokeAccess::Config.puzzle_assist = true
    assert_equal ["#{t(:af_gades_machop)}: #{t(:face_south)}. #{t(:statue_goal, :dir => t(:face_east))}"],
                 frame { machop.direction = 2 }
    assert_equal ["#{t(:af_gades_machop)}: #{t(:face_east)}. #{t(:statue_ok)}"], frame { machop.direction = 6 }
    assert_equal ["#{t(:af_gades_machop)}: #{t(:face_east)}. #{t(:statue_goal, :dir => t(:face_west))}"],
                 frame { far_machop.direction = 6 }
    PokeAccess::Config.puzzle_assist = false
    assert_nil PokeAccess::Puzzles.sent_back_line([9, 7, 270], [18, 32, 270])
    fire(trap)
    assert_equal t(:af_gades_rampardos), PokeAccess::Puzzles.sent_back_line([9, 7, 270], [18, 32, 270])
    assert_equal [t(:af_gades_open)], frame { $game_switches[187] = true }
  end

  test "Gades names the four Unown that spell the number, west to east, and the entry gives the answer to the assist" do
    on_map(270)
    { 12 => [4, 14, "201_12", "M"], 13 => [10, 1, "201_3", "D"], 15 => [27, 1, "201_8", "I"], 14 => [33, 14, "201_23", "X"] }.each do |id, (x, y, sprite, _)|
      place(id, x, y, [TestCmd.new(101, ["letter"])], sprite)
    end
    expected = [[4, 14, "M"], [10, 1, "D"], [27, 1, "I"], [33, 14, "X"]]
    assert_equal expected.map { |x, y, letter| [x, y, t(:af_gades_letter, :letter => letter)] }, listed
  end

  test "Siracusa names the smelters, the dumps and the Bronzors, says the ingots it holds and the recipe of the door pending with the assist" do
    on_map(214)
    { 8 => [15, 23], 14 => [4, 14], 15 => [15, 14], 16 => [26, 23], 17 => [22, 14], 18 => [33, 23], 12 => [31, 10],
      13 => [10, 25], 2 => [28, 21], 1 => [12, 13] }.each do |id, (x, y)|
      place(id, x, y, [TestCmd.new(101, ["?"])])
    end
    assert_equal [[4, 14, :af_forge_gold], [10, 25, :af_forge_dump], [12, 13, :af_bronzor_west], [15, 14, :af_forge_silver],
                  [15, 23, :af_forge_gold], [22, 14, :af_forge_copper], [26, 23, :af_forge_silver], [28, 21, :af_bronzor_east],
                  [31, 10, :af_forge_dump], [33, 23, :af_forge_copper]].map { |x, y, k| [x, y, t(k)] }, listed
    frame
    plate = place(22, 30, 17, [TestCmd.new(122, [56, 58, 0, 0, 0])])
    assert_equal [], frame { fire(plate) }, "no ingots to lose"
    $game_variables[56] = 1
    frame
    assert_equal [t(:af_forge_empties)], frame { fire(plate) }
    $game_variables[56] = 0
    frame
    assert_includes info_key, t(:af_forge_east)
    assert_equal [t(:puzzle_value, :label => t(:af_ingot_copper), :v => 1)], frame { $game_variables[58] = 1 }
    refute_includes info_key, t(:af_forge_east_hint)
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, t(:af_forge_east_hint)
    assert_equal ["#{t(:af_forge_west)}. #{t(:af_forge_west_hint)}"], frame { $game_switches[211] = true }
    assert_equal [], frame { $game_switches[212] = true }
    assert_nil PokeAccess::Puzzles.info_line
  end

  test "Siga names the palms, the vats by colour and the two patches of thorns, says what is carried and which potion clears which" do
    on_map(7)
    place(2, 16, 22, [TestCmd.new(101, ["sap"])], "000")
    place(19, 13, 33, [TestCmd.new(101, ["vat"])], "000")
    twin = place(20, 14, 33, [TestCmd.new(101, ["vat"])], "000")
    place(21, 25, 33, [TestCmd.new(101, ["vat"])], "000")
    first = tile(27, 17, 29, 2503)
    second = tile(32, 21, 17, 2502)
    assert_equal [[13, 33, t(:af_vat_green)], [16, 22, t(:af_sap_palm)], [25, 33, t(:af_vat_red)]], listed
    assert_equal true, PokeAccess::Locator.hidden?(twin)
    assert_equal t(:af_thorns_first), PokeAccess::Puzzles.piece_name(first)
    assert_equal t(:af_thorns_second), PokeAccess::Puzzles.piece_name(second)
    frame
    assert_equal ["#{t(:af_sap)}: #{t(:af_yes)}"], frame { $game_variables[64] = 1 }
    assert_equal ["#{t(:af_potion)}: #{t(:af_yes)}"], frame { $game_variables[65] = 1 }
    assert_equal ["#{t(:af_sap)}: #{t(:af_no)}", "#{t(:af_potion)}: #{t(:af_no)}"],
                 frame { $game_variables[64] = $game_variables[65] = 0 }
    assert_includes info_key, t(:af_siga_first)
    refute_includes info_key, t(:af_siga_first_hint)
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, t(:af_siga_first_hint)
    assert_equal [t(:puzzle_progress, :label => t(:af_thorns_cleared), :n => 1, :of => 2),
                  "#{t(:af_siga_second)}. #{t(:af_siga_second_hint)}"], frame { $game_switches[237] = true }
  end

  test "Cirta lists its plates and stops with the assist alone, says each plate as it is stepped on, and tells the next stage" do
    on_map(307)
    { 25 => [20, 21], 29 => [20, 30], 21 => [1, 10], 31 => [28, 8], 30 => [28, 29] }.each do |id, (x, y)|
      place(id, x, y, [TestCmd.new(121, [377, 377, 0]), TestCmd.new(0, [])])
    end
    place(53, 12, 39, [TestCmd.new(101, ["lever"])], "palancas")
    stops = { 39 => [13, 9], 38 => [18, 9], 34 => [19, 9], 35 => [27, 9], 40 => [8, 11], 32 => [2, 12], 23 => [9, 20], 19 => [11, 20],
              22 => [19, 20], 16 => [2, 23], 24 => [2, 25], 26 => [18, 28], 20 => [27, 28], 12 => [9, 29] }
    stops.each { |id, (x, y)| place(id, x, y, [TestCmd.new(355, ["ride"])]) }
    assert_equal [[12, 39, t(:af_mudsdale_lever)]], listed
    frame
    assert_equal ["#{t(:af_plate_yellow)}: #{t(:af_plate_on)}"], frame { $game_switches[379] = true }
    assert_equal ["#{t(:af_plate_yellow)}: #{t(:af_plate_off)}"], frame { $game_switches[379] = false }
    PokeAccess::Config.puzzle_assist = true
    by_place = stops.values.sort_by { |x, y| [y, x] }
    expected = (by_place.each_with_index.map { |(x, y), i| [x, y, t(:af_stop, :n => i + 1)] } +
                [[1, 10, t(:af_plate_yellow)], [12, 39, t(:af_mudsdale_lever)], [20, 21, t(:af_plate_blue)], [20, 30, t(:af_plate_green)],
                 [28, 8, t(:af_plate_cyan)], [28, 29, t(:af_plate_pink)]]).sort_by { |x, y, _n| [x, y] }
    assert_equal expected, listed
    assert_includes info_key, t(:af_cirta_stage1)
    assert_equal ["#{t(:af_plate_blue)}: #{t(:af_plate_on)}", t(:af_cirta_stage2)], frame { $game_switches[377] = true }
    assert_equal ["#{t(:af_plate_green)}: #{t(:af_plate_on)}", t(:af_cirta_stage3)], frame { $game_switches[378] = true }
    assert_equal ["#{t(:af_plate_blue)}: #{t(:af_plate_off)}", t(:af_cirta_stage4)], frame { $game_switches[377] = false }
    assert_equal ["#{t(:af_plate_pink)}: #{t(:af_plate_on)}", t(:af_cirta_reset)], frame { $game_switches[381] = true }
    PokeAccess::Config.puzzle_assist = false
    assert_equal ["#{t(:af_plate_pink)}: #{t(:af_plate_off)}"], frame { $game_switches[381] = false }
    assert_includes info_key, t(:af_cirta_rule)
    refute_includes info_key, t(:af_cirta_stage4)
  end

  test "Cirta's mosaics say which picture they ask for, count and say when the sword shows" do
    on_map(307)
    mosaic = place(58, 35, 24, [TestCmd.new(355, ["pbTilePuzzle(2, 'Aerodactyl')"])], "000")
    other = place(59, 43, 24, [TestCmd.new(355, ["pbTilePuzzle(2, 'Hooh')"])], "000")
    frame
    assert_equal [t(:af_mosaic, :name => "Aerodactyl")], frame { fire(mosaic) }
    assert_equal [t(:af_mosaic, :name => "Ho-Oh")], frame { fire(other) }
    assert_equal [t(:puzzle_progress, :label => t(:af_mosaics), :n => 1, :of => 2)], frame { $game_switches[374] = true }
    assert_equal [t(:af_sword_appeared)], frame { $game_switches[376] = true }
  end

  test "the harbour counts its six tests on every map of it and, with the assist, names the ones left" do
    on_map(59)
    assert_includes info_key, t(:af_port_tests, :n => 0)
    refute_includes info_key, t(:af_tests_missing, :list => "")
    $game_switches[293] = true
    $game_variables[99] = 3
    assert_includes info_key, t(:af_port_tests, :n => 2)
    PokeAccess::Config.puzzle_assist = true
    left = [:af_test_boxes, :af_test_pulse, :af_test_knots, :af_test_tavern].map { |k| t(k) }.join(", ")
    assert_includes info_key, t(:af_tests_missing, :list => left)
    [258, 259, 260].each do |map|
      on_map(map)
      $game_variables[98] = 4
      assert_includes info_key, t(:af_port_tests, :n => 1)
    end
    on_map(59)
    $game_switches[298] = true
    refute_includes info_key.to_s, t(:af_port_tests, :n => 0)
  end

  test "the harbour's box is named and tracked, with the assist how far it is from the door" do
    on_map(59)
    box = place(1, 16, 41, [TestCmd.new(209, [-1, nil])], "Cajas")
    assert_includes listed, [16, 41, t(:af_box)]
    assert_equal t(:af_box), PokeAccess::Puzzles.piece_name(box)
    assert_includes info_key, t(:af_box_title)
    assert_includes info_key, t(:af_port_rule)
    refute_includes info_key, t(:af_box_hint)
    PokeAccess::Config.puzzle_assist = true
    away = PokeAccess::Puzzles.goal_offset([13, 29, 13, 29], [16, 41])
    assert_includes info_key, t(:puzzle_track_goal, :label => t(:af_box), :dist => away, :goal => t(:af_box_goal))
    assert_includes info_key, t(:af_box_hint)
    assert_includes PokeAccess::Puzzles.category_targets.map { |tg| [tg.x, tg.y, tg.name] }, [13, 29, t(:af_box_goal)]
  end

  test "the tavern names the berry points and the barman, says the berries carried, the drink ready and the customers served" do
    on_map(59)
    { 30 => [12, 5, "Tamate"], 32 => [29, 5, "Peragu"], 34 => [24, 9, "Aranja"] }.each do |id, (x, y, kind)|
      place(id, x, y, [TestCmd.new(101, ["berry"])], "000")
    end
    place(28, 40, 24, [TestCmd.new(101, ["hi"])], "HGSScartago_010")
    twin = place(29, 39, 24, [TestCmd.new(101, ["hi"])], "000")
    names = [[12, 5, t(:af_berry, :kind => "Tamate")], [24, 9, t(:af_berry, :kind => "Aranja")],
             [29, 5, t(:af_berry, :kind => "Peragu")], [40, 24, t(:af_barman)]]
    assert_equal names, listed.select { |x, y, n| n != t(:af_box) }
    assert_equal true, PokeAccess::Locator.hidden?(twin)
    frame
    assert_equal ["#{t(:af_berries, :kind => "Tamate")}: 1"], frame { $game_variables[101] = 1 }
    assert_equal ["#{t(:af_berries, :kind => "Aranja")}: 2"], frame { $game_variables[102] = 2 }
    assert_equal [t(:af_beer_ready)], frame { $game_switches[295] = true }
    assert_equal [t(:af_wine_ready)], frame { $game_switches[296] = true }
    assert_equal [t(:puzzle_progress, :label => t(:af_customers), :n => 1, :of => 3)], frame { $game_variables[100] = 1 }
    $game_switches[294] = true
    refute_includes info_key, t(:af_tavern_hint)
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, t(:af_tavern_hint)
  end

  test "the five boxes are named by colour; the one to place next and the order are for the assist alone" do
    on_map(259)
    start = { 2 => [3, 10], 3 => [12, 10], 4 => [6, 10], 5 => [9, 10], 6 => [15, 10] }
    boxes = {}
    start.each { |id, (x, y)| boxes[id] = place(id, x, y, [TestCmd.new(209, [-1, nil])], "Cajas") }
    place(1, 17, 7, [TestCmd.new(101, ["lever"])], "palancas")
    (7..11).each { |id| tile(id, 3 + 3 * (id - 7), 3, 3157) }
    named = { 2 => :af_box_green, 3 => :af_box_blue, 4 => :af_box_red, 5 => :af_box_yellow, 6 => :af_box_purple }
    named.each { |id, key| assert_equal t(key), PokeAccess::Puzzles.piece_name(boxes[id]) }
    assert_equal t(:af_symbol, :n => 3), PokeAccess::Puzzles.piece_name($game_map.events[9])
    frame
    refute_includes info_key.to_s, t(:af_boxes_title)
    refute_includes info_key.to_s, t(:af_box_yellow)
    assert_equal [], frame { boxes[5].x = 3; boxes[5].y = 5 }
    PokeAccess::Config.puzzle_assist = true
    green = t(:puzzle_track_goal, :label => t(:af_box_green), :dist => PokeAccess::Puzzles.goal_offset([6, 5, 6, 5], [3, 10]),
              :goal => t(:af_box_goal))
    yellow = t(:puzzle_track_goal, :label => t(:af_box_yellow), :dist => PokeAccess::Puzzles.goal_offset([3, 5, 3, 5], [3, 5]),
               :goal => t(:af_box_goal))
    assert_includes info_key, green
    assert_includes info_key, t(:af_boxes_hint)
    refute_includes info_key, yellow
    assert_equal [t(:puzzle_progress, :label => t(:af_boxes_placed), :n => 2, :of => 5)], frame { boxes[2].x = 6; boxes[2].y = 5 }
  end

  test "the shipyard names each knot as cut or not, counts them and names the posts that fall with them" do
    on_map(258)
    knots = [[4, 9, 10], [5, 18, 10], [24, 9, 24], [25, 18, 24]].map { |id, x, y| tile(id, x, y, 3156) }
    post = tile(2, 9, 11, 3164)
    assert_equal [t(:af_knot)] * 4, knots.map { |k| PokeAccess::Puzzles.piece_name(k) }
    assert_equal t(:af_posts), PokeAccess::Puzzles.piece_name(post)
    frame
    $game_self_switches[[258, 4, "A"]] = true
    assert_equal [t(:af_knot_cut), t(:af_knot), t(:af_knot), t(:af_knot)], knots.map { |k| PokeAccess::Puzzles.piece_name(k) }
    assert_equal [t(:puzzle_progress, :label => t(:af_knots), :n => 1, :of => 4)], frame { $game_variables[98] = 1 }
    assert_includes info_key, t(:af_knots_rule)
  end

  test "the copper conductors are named and counted, three in all" do
    on_map(260)
    { 2 => [34, 24], 3 => [15, 26], 4 => [34, 4] }.each { |id, (x, y)| place(id, x, y, [TestCmd.new(101, ["conductor"])], "protacasco") }
    assert_equal [[15, 26], [34, 4], [34, 24]].map { |x, y| [x, y, t(:af_conductor)] }, listed
    frame
    assert_equal [t(:puzzle_progress, :label => t(:af_conductors), :n => 1, :of => 3)], frame { $game_variables[99] = 1 }
    assert_includes info_key, t(:af_conductors_rule)
    frame { $game_variables[99] = 3 }
    assert_equal t(:af_port_tests, :n => 1), PokeAccess::Puzzles.info_line
  end

  test "Massilia names the shields and swords of a room's rack until its weapon is taken" do
    on_map(89)
    { 1 => [16, 28], 2 => [17, 28], 20 => [21, 21] }.each { |id, (x, y)| place(id, x, y, [TestCmd.new(101, ["rack"])], "000") }
    { 3 => [18, 28], 4 => [19, 28], 15 => [23, 21] }.each { |id, (x, y)| place(id, x, y, [TestCmd.new(101, ["rack"])], "000") }
    frame
    shield = t(:af_shield)
    sword = t(:af_sword)
    assert_equal [[16, 28, shield], [17, 28, shield], [18, 28, sword], [19, 28, sword], [21, 21, shield], [23, 21, sword]], listed
    $game_switches[67] = true
    frame
    assert_equal [[21, 21, shield], [23, 21, sword]], listed
    $game_switches[69] = true
    frame
    assert_empty listed
  end

  test "Siracusa names the four actors that left the stage and, with the assist, counts them as they are found" do
    on_map(185)
    { 81 => [12, 39], 82 => [18, 66], 83 => [45, 35], 84 => [17, 38] }.each { |id, (x, y)| place(id, x, y, [TestCmd.new(101, ["actor"])], "actor") }
    $game_switches[288] = true
    frame
    assert_equal [[12, 39], [17, 38], [18, 66], [45, 35]].map { |x, y| [x, y, t(:af_actor)] }, listed
    assert_empty frame { $game_variables[91] = 1 }
    refute_includes info_key, t(:af_actors)
    PokeAccess::Config.puzzle_assist = true
    assert_equal [t(:puzzle_progress, :label => t(:af_actors), :n => 2, :of => 4)], frame { $game_variables[91] = 2 }
    assert_includes info_key, t(:puzzle_progress, :label => t(:af_actors), :n => 2, :of => 4)
    $game_variables[55] = 4
    refute PokeAccess::Puzzles.active?
  end

  test "Tarraco says its rule on arriving until the leader's medal is won, then neither it nor the info key" do
    assert_equal [t(:af_tarraco_rule)], arrival(112)
    refute_nil PokeAccess::Puzzles.info_line
    assert_empty arrival(112) { $game_switches[118] = true }
    assert_nil PokeAccess::Puzzles.info_line
  end

  test "Siracusa's forge says its rule on arriving until both doors are open, then neither it nor the info key" do
    assert_equal [t(:af_forge_rule)], arrival(214) { $game_switches[211] = true }
    refute_nil PokeAccess::Puzzles.info_line
    assert_empty arrival(214) { $game_switches[211] = $game_switches[212] = true }
    assert_nil PokeAccess::Puzzles.info_line
  end

  test "Siga says its rule on arriving until both patches of thorns are gone, then neither it nor the info key" do
    assert_equal [t(:af_siga_rule)], arrival(7) { $game_switches[237] = true }
    refute_nil PokeAccess::Puzzles.info_line
    assert_empty arrival(7) { $game_switches[237] = $game_switches[238] = true }
    assert_nil PokeAccess::Puzzles.info_line
  end

  test "Cirta's plates say their rule on arriving until both swords are taken, whichever comes first, and the mosaics go on counting" do
    assert_equal [t(:af_cirta_rule)], arrival(307)
    refute_nil PokeAccess::Puzzles.info_line
    assert_equal [t(:af_cirta_rule)], arrival(307) { $game_switches[382] = true }
    assert_equal [t(:af_cirta_rule)], arrival(307) { $game_switches[383] = true }
    assert_includes info_key, t(:puzzle_progress, :label => t(:af_mosaics), :n => 0, :of => 2)
    refute_includes info_key, t(:af_cirta_rule)
    assert_empty arrival(307) { $game_switches[382] = $game_switches[383] = true }
    assert_nil PokeAccess::Puzzles.info_line
  end

  test "the harbour says its rule on arriving until the north door is open, then neither it nor its tests on the info key" do
    assert_equal [t(:af_port_rule)], arrival(59)
    assert_empty arrival(59) { $game_switches[298] = true }
    assert_nil PokeAccess::Puzzles.info_line
  end

  test "the trigger of Iol's scene is no mechanism, with the assist or without it" do
    on_map(236)
    PokeAccess::Config.puzzle_assist = true
    drawn = TestPage.new(:trigger => 0, :sprite => "cultistaOW", :list => [TestCmd.new(0, [])],
                         :condition => { :switch1_valid => true, :switch1_id => 241 })
    $game_map.events[27] = TestGameEvent.new(:id => 27, :x => 42, :y => 13, :pages => [drawn], :active_page => drawn)
    trigger = place(26, 41, 20, [TestCmd.new(207, [27, 18]), TestCmd.new(121, [241, 241, 0]), TestCmd.new(0, [])])
    PokeAccess::World::Events.sync(true)
    assert_empty PokeAccess::Puzzles::Auto.targets
    refute PokeAccess::World::Events.record_of(trigger).nil?
    assert_nil PokeAccess::World::Events.facet(PokeAccess::World::Events.record_of(trigger), :auto_control)
  end

  private

  def t(key, vars = {})
    PokeAccess::I18n.t(key, vars)
  end

  def arrival(map)
    on_map(map)
    yield if block_given?
    PokeAccess::Puzzles.instance_variable_set(:@told, nil)
    frame
  end

  def on_map(map)
    Harness.load_puzzles("africanus")
    PokeAccess::Config.puzzle_assist = false
    World.clear_events
    $game_self_switches = {}
    SWITCHES.each { |s| $game_switches[s] = false }
    VARIABLES.each { |v| $game_variables[v] = 0 }
    $game_map.map_id = map
    $game_player.x = 5
    $game_player.y = 5
    PokeAccess::Caches.reset_all
    PokeAccess::World::Mechanics.forget
    World.next_frame
  end

  def place(id, x, y, list, sprite = "")
    page = TestPage.new(:trigger => 0, :sprite => sprite, :list => list)
    ev = TestGameEvent.new(:id => id, :x => x, :y => y, :pages => [page], :active_page => page)
    $game_map.events[id] = ev
    World.next_frame
    ev
  end

  def tile(id, x, y, tile_id)
    page = TestPage.new(:trigger => 0, :sprite => "", :list => [TestCmd.new(0, [])])
    ev = TestGameEvent.new(:id => id, :x => x, :y => y, :tile_id => tile_id, :pages => [page])
    $game_map.events[id] = ev
    World.next_frame
    ev
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

  def info_key
    PokeAccess::Info.map_text
  end

  def listed
    PokeAccess::Puzzles.category_targets.select { |tg| tg.is_a?(PokeAccess::Locator::SurfaceTarget) }
                       .map { |tg| [tg.x, tg.y, tg.name] }.sort_by { |r| [r[0], r[1]] }
  end
end
