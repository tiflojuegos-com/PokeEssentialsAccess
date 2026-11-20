# Soulstones' puzzles on the shipped profile: the subway's track panels, Sleeper Spire's door switches and traps, the tile
# floors of Carleton, the Time Matrix, Genesis' code, the tomb's inscriptions, the Media HQ, Fhenzhu's boulders, Jenola's
# buttons, Beta Omicron's keys and gravestones, the sewers' step by step and the side quests, each as heard without the
# puzzle assist and with it. Labels are checked as the key and values they give.
class Soulstones1PuzzlesTest < PokeAccessTest
  # The tiles of map 117 in event order (events 2 to 26), the only way across.
  FLOOR117 = [[12, 12], [12, 11], [11, 11], [10, 11], [9, 11], [8, 11], [8, 10], [8, 9], [9, 9], [9, 10], [10, 10], [11, 10],
              [11, 9], [12, 9], [12, 10], [13, 10], [13, 11], [14, 11], [15, 11], [16, 11], [16, 10], [16, 9], [15, 9], [14, 9],
              [13, 9]]
  # The tiles of map 119 in event order (events 2 to 72), as the map has them.
  FLOOR119 = [[12, 18], [12, 17], [13, 17], [14, 17], [15, 17], [16, 17], [16, 16], [15, 16], [14, 16], [13, 16],
              [12, 16], [11, 16], [11, 17], [10, 17], [9, 17], [8, 17], [8, 16], [9, 16], [10, 16], [10, 15],
              [9, 15], [8, 15], [8, 14], [9, 14], [9, 13], [8, 13], [8, 12], [8, 11], [8, 10], [8, 9], [9, 9],
              [9, 10], [9, 11], [9, 12], [10, 12], [10, 11], [10, 10], [11, 10], [11, 11], [11, 12], [11, 13],
              [11, 14], [11, 15], [12, 15], [12, 14], [13, 14], [14, 14], [14, 15], [15, 15], [16, 15], [16, 14],
              [16, 13], [15, 13], [14, 13], [13, 13], [12, 13], [12, 12], [13, 12], [14, 12], [15, 12], [16, 12],
              [16, 11], [16, 10], [15, 10], [15, 9], [14, 9], [13, 9], [13, 10], [12, 10], [12, 9], [11, 9]]

  test "the subway numbers its panels in reading order and gives away the fakes with the assist alone" do
    on_map(396)
    sub = PokeAccess::SoulstonesSubway
    { 98 => [13, 14], 109 => [32, 14], 131 => [32, 25], 12 => [43, 76] }.each { |id, (x, y)| place(id, x, y, [TestCmd.new(122, [])]) }
    assert_equal [:ss1_subway_panel, { :n => 1 }], sub.label(ev(98))
    assert_equal [:ss1_subway_panel, { :n => 3 }], sub.label(ev(131)), "a fake one is a panel like the rest"
    assert_equal [:ss1_subway_panel, { :n => 13 }], sub.label(ev(12))
    PokeAccess::Config.puzzle_assist = true
    assert_equal [:ss1_subway_fake, { :n => 3 }], sub.label(ev(131))
    assert_equal [:ss1_subway_panel, { :n => 2 }], sub.label(ev(109))
    $game_variables[259] = 2
    assert_equal [:ss1_subway_moved, { :n => 2, :pos => 0 }], sub.press_line(ev(109)), "a lever of three positions goes round"
    assert_equal [:ss1_subway_moved, { :n => 1, :pos => 1 }], sub.press_line(ev(98))
    tick
    (251..264).each { |v| $game_variables[v] = 0 }
    assert_equal [], tick, "Cara's reset of every lever is told by her own words alone"
    $game_switches[177] = true
    assert_nil sub.press_line(ev(98)), "aboard, the panels no longer move"
  end

  test "the subway's assist counts the presses each true panel still needs, round its cycle, and sends to Cara once right" do
    on_map(396)
    sub = PokeAccess::SoulstonesSubway
    (251..264).each { |v| $game_variables[v] = 0 }
    assert_equal [[1, 1], [2, 2], [5, 1], [6, 2], [9, 1], [12, 1]], sub.presses
    assert_equal :ss1_subway_hint, sub.hint[0]
    $game_variables[256] = 1
    $game_variables[251] = 1
    assert_equal [[1, 1], [2, 2], [5, 1], [6, 1], [9, 1], [12, 1], [13, 1]], sub.presses, "a lever past its place goes on round"
    { 251 => 0, 252 => 0, 253 => 1, 254 => 0, 255 => 1, 256 => 2, 257 => 1, 258 => 1, 259 => 2 }.each { |v, n| $game_variables[v] = n }
    $game_variables[260] = 1
    assert_equal :ss1_subway_ready, sub.hint, "the fakes do not count"
    $game_switches[177] = true
    refute PokeAccess::Puzzles.active?
  end

  test "Sleeper Spire names its door switches by their number and says them as they flip" do
    on_map(44)
    place(10, 8, 8, [TestCmd.new(101, ["Activate?"])], :name => "Switch - Door 1")
    place(21, 22, 8, [TestCmd.new(101, ["Activate?"])], :name => "Switch - Door 2")
    assert_equal [:ss1_spire_switch, { :n => 2 }], PokeAccess::SoulstonesSpire.switch_label(ev(21))
    w = spec[:watch].find { |x| x[:switch] == 113 }
    assert_equal [[:ss1_spire_switch, { :n => 2 }], :ss1_spire_on], [w[:label], w[:on]]
    tick
    $game_switches[113] = true
    assert_equal 1, tick.length
  end

  test "Sleeper Spire's assist leads room by room up to the summit as the switches stand" do
    on_map(41)
    spire = PokeAccess::SoulstonesSpire
    [[41, 7, 36, {}, :ss1_spire_hint_trap, nil], [41, 12, 22, { 114 => true }, :ss1_spire_hint_story, 135],
     [41, 18, 11, { 114 => true, 121 => true }, :ss1_spire_hint_north, 3],
     [44, 19, 36, { 112 => true }, :ss1_spire_hint_off1, 10], [44, 19, 36, {}, :ss1_spire_hint_door9, 9],
     [44, 28, 36, {}, :ss1_spire_hint_side_room, nil], [46, 20, 10, {}, :ss1_spire_hint_on3, 10],
     [46, 20, 11, { 122 => true }, :ss1_spire_hint_door7, 7], [45, 19, 6, { 122 => true }, :ss1_spire_hint_on5, 33],
     [45, 19, 8, { 124 => true }, :ss1_spire_hint_door28, 28], [45, 19, 35, { 124 => true }, :ss1_spire_hint_maze, nil],
     [46, 39, 41, { 122 => true, 124 => true }, :ss1_spire_hint_summit, 1], [46, 5, 11, {}, :ss1_spire_hint_side_room, nil]
    ].each do |map, x, y, on, key, event|
      on_map(map)
      [112, 113, 114, 121, 122, 123, 124].each { |s| $game_switches[s] = on[s] || false }
      go(x, y)
      assert_equal key, spire.step, "map #{map} at #{x},#{y}"
      event ? assert_equal(event, spire.right_event, "at #{x},#{y}") : assert_nil(spire.right_event, "at #{x},#{y}")
    end
  end

  test "Sleeper Spire says a trap tile threw the player back, and only for the tiles of that floor" do
    on_map(41)
    trap = place(21, 5, 32, [TestCmd.new(201, [0, 41, 7, 33, 0, 0]), TestCmd.new(0, [])], :name => "Walking Puzzle 1",
                 :trigger => 1)
    tick
    PokeAccess::Puzzles::Auto.instance_variable_set(:@last_used, trap.id)
    assert_equal t(:ss1_spire_trap_back), PokeAccess::Puzzles.sent_back_line([5, 32, 41], [7, 33, 41])
    assert_nil PokeAccess::Puzzles.sent_back_line([5, 32, 41], [13, 20, 41]), "the start of another floor"
  end

  test "a Carleton floor points the assist at the next tile of its way, and says when the steps left it" do
    on_map(117)
    lab = PokeAccess::SoulstonesCarleton
    plan = lab::FLOORS[117][0]
    FLOOR117.each_with_index { |(x, y), i| place(plan[i], x, y, [TestCmd.new(0, [])], :trigger => 1) }
    go(12, 13)
    assert_equal 2, lab.next_tile(plan)
    step_on(117, [2, 3, 4])
    go(11, 11)
    assert_equal 5, lab.next_tile(plan)
    assert_equal :ss1_carleton_hint, lab.hint(plan)
    step_on(117, [9])
    assert_nil lab.next_tile(plan)
    assert_equal :ss1_carleton_off_plan, lab.hint(plan)
    step_on(117, plan)
    assert_equal :ss1_carleton_done, lab.hint(plan)
    $game_self_switches = {}
    step_on(117, [2, 3, 4])
    assert_empty right_way, "the way is the assist's"
    PokeAccess::Config.puzzle_assist = true
    assert_equal [[10, 11]], right_way
  end

  test "the floor below a Carleton room says the player fell, only when dropped from that room" do
    on_map(118)
    assert_equal t(:ss1_carleton_fell), PokeAccess::Puzzles.sent_back_line([9, 9, 117], [12, 10, 118], :map)
    assert_nil PokeAccess::Puzzles.sent_back_line([9, 9, 119], [12, 10, 118], :map)
  end

  test "a level of the Time Matrix counts the holograms touched, and goes quiet once its barrier lets the player by" do
    on_map(48)
    place(69, 30, 37, [TestCmd.new(101, ["..."])], :sprite => "object_holograms2", :trigger => 1)
    assert_equal t(:ss1_matrix_object), name_of(69)
    tick
    $game_self_switches[[48, 69, "A"]] = true
    assert_equal [t(:puzzle_progress, :label => t(:ss1_matrix_objects), :n => 1, :of => 5)], tick
    $game_variables[270] = 5
    refute PokeAccess::Puzzles.active?
  end

  test "Genesis keeps the digits the scientists gave, in their places, for the info key" do
    on_map(391)
    assert_nil PokeAccess::SoulstonesGenesis.info
    $game_self_switches[[391, 37, "A"]] = true
    $game_self_switches[[391, 35, "A"]] = true
    assert_equal [[1, 1], [4, 9]], PokeAccess::SoulstonesGenesis.heard
    refute_nil PokeAccess::SoulstonesGenesis.info
  end

  test "the tomb names its inscriptions, and the next one so with the assist alone, both last ones at seven" do
    on_map(275)
    [[5, 34, 45], [10, 15, 19], [11, 87, 3], [33, 108, 3]].each { |id, x, y| place(id, x, y, [TestCmd.new(101, ["..."])]) }
    $game_variables[147] = 1
    assert_equal t(:ss1_tomb_inscription), name_of(5)
    PokeAccess::Config.puzzle_assist = true
    assert_equal t(:ss1_tomb_next), name_of(5)
    assert_equal t(:ss1_tomb_inscription), name_of(10)
    $game_variables[147] = 7
    assert_equal [t(:ss1_tomb_next)] * 2, [name_of(11), name_of(33)]
    $game_self_switches[[275, 11, "A"]] = true
    assert_equal [33], PokeAccess::SoulstonesTomb.next_ids
  end

  test "the Media HQ's assist follows the chain, and its bookcase switch is named with the assist alone" do
    on_map(377)
    place(50, 33, 23, [TestCmd.new(101, ["Turn it on?"])], :trigger => 1)
    refute_equal t(:ss1_media_bookcase_switch), name_of(50)
    PokeAccess::Config.puzzle_assist = true
    assert_equal t(:ss1_media_bookcase_switch), name_of(50)
    media = PokeAccess::SoulstonesMediaHq
    $game_variables[230] = 4
    assert_equal :ss1_media_hint_employee, media.hint
    $game_variables[230] = 5
    assert_equal :ss1_media_hint_feeds, media.hint
    $game_switches[137] = true
    assert_equal :ss1_media_hint_terminal, media.hint
    assert_includes info_key, t(:ss1_media_hint_terminal)
    PokeAccess::Config.puzzle_assist = false
    refute_includes info_key, t(:ss1_media_hint_terminal)
  end

  test "Mt. Fhenzhu says a filled hole as a sighted player sees it, and gives the pushes of the boulders still out" do
    on_map(208)
    tick
    $game_switches[77] = true
    assert_equal [t(:ss1_fz_filled)], tick
    assert_equal PokeAccess.sentences([t(:ss1_fz_rock8), t(:ss1_fz_rock6)]), PokeAccess::SoulstonesFhenzhu.hint
    $game_switches[76] = $game_switches[78] = true
    assert_equal :ss1_fz_done, PokeAccess::SoulstonesFhenzhu.hint
  end

  test "Jenola names its buttons, drawn on the floor, and its assist follows the presses to the fossil from any state" do
    on_map(98)
    place(14, 27, 22, [TestCmd.new(355, ["pbSetSelfSwitch(13,'A',true)"])], :trigger => 1, :name => "Button2")
    assert_equal t(:ss1_jenola_button, :n => 2), name_of(14), "a sighted player sees the round buttons, the second one"
    jen = PokeAccess::SoulstonesJenola
    go(12, 22)
    assert_equal [:button, 0], jen.step
    assert_equal [:ss1_jenola_next, { :n => 1 }], jen.hint
    refute_includes info_key, t(:ss1_jenola_next, :n => 1)
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, t(:ss1_jenola_next, :n => 1)
    assert_equal [0, 1, 3, 2, 5, 1], follow_jenola(jen), "the fewest presses from the start"
    assert_equal [:done], jen.step
    assert_equal :ss1_jenola_done, jen.hint
    set_jenola(jen, [0, 2, 3, 5])
    refute_equal [:done], jen.step, "buttons 1, 3, 4 and 6 on but rock 7 still standing: no way to the fossil yet"
    follow_jenola(jen)
    assert_equal [:done], jen.step
    set_jenola(jen, [0, 1, 1, 0])
    follow_jenola(jen)
    assert_equal [:done], jen.step, "from a state off any plan too"
  end

  test "a Carleton floor of many ways follows the one the player walks, and asks to start over only when none is left" do
    on_map(119)
    lab = PokeAccess::SoulstonesCarleton
    plan = lab::FLOORS[119][0]
    FLOOR119.each_with_index { |(x, y), i| place(plan[i], x, y, [TestCmd.new(0, [])], :trigger => 1) }
    go(12, 19)
    assert_equal plan.first, lab.next_tile(plan), "the floor is entered by its first tile"
    step_on(119, [2, 3])
    go(12, 17)
    assert_equal 4, lab.next_tile(plan), "the event order while the player keeps to it"
    step_on(119, [14])
    go(11, 17)
    assert_equal 15, lab.next_tile(plan), "a step off the event order that leaves a way is followed"
    assert_equal :ss1_carleton_hint, lab.hint(plan)
    $game_self_switches = {}
    step_on(119, (2..6).to_a + [9])
    go(15, 16)
    assert_nil lab.next_tile(plan), "the tile in the corner is left with one way in"
    assert_equal :ss1_carleton_off_plan, lab.hint(plan)
  end

  test "Beta Omicron names its doors by number and points the assist at the next key as variable 178 grows" do
    on_map(11)
    place(12, 56, 22, [TestCmd.new(101, ["The number on the door is 321"])], :trigger => 1)
    bo = PokeAccess::SoulstonesBetaOmicron
    assert_equal [:ss1_bo_door, { :n => 321 }], bo.door_label(ev(12))
    [[1, 24], [4, 25], [5, 35], [6, 26], [7, 59], [8, 22]].each do |v, want|
      $game_variables[178] = v
      assert_equal want, bo.next_key, "at #{v}"
    end
    refute_includes info_key, t(:ss1_bo_keys_hint)
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, t(:ss1_bo_keys_hint)
  end

  test "the sewers name each panel by its pair of sectors and keep the lowered ones for the info key" do
    on_map(193)
    place(11, 25, 14, [TestCmd.new(101, ["Sector 1 Gates Lowered"])], :name => "Control Panel 1")
    sewers = PokeAccess::SoulstonesSewers
    assert_equal [:ss1_sewers_panel, { :a => 1, :b => 2 }], sewers.panel_label(ev(11))
    $game_switches[69] = true
    assert_equal [2, 4, 5, 8, 10], sewers.lowered
  end

  test "the sewers' step follows the gang members room by room and then the showdown, from where the player stands" do
    on_map(193)
    sewers = PokeAccess::SoulstonesSewers
    $game_variables[105] = 1
    go(5, 37)
    assert_equal [:press, 193, 11, 67], sewers.step
    assert_equal [:ss1_sewers_step_press, { :a => 1, :b => 2 }], sewers.hint
    $game_switches[67] = true
    assert_equal [:door, 193, 6], sewers.step
    go(70, 70)
    assert_nil sewers.step, "off every known region"
    assert_equal :ss1_sewers_step_lost, sewers.hint
  end

  test "following the sewers' step from the city beats all nine gang members and reaches the showdown" do
    on_map(193)
    sewers = PokeAccess::SoulstonesSewers
    $game_variables[105] = 1
    map, region, mask = 193, 2, 0
    steps = 0
    loop do
      act = sewers.plan(map, region, mask)
      refute_nil act, "a step from map #{map} region #{region}"
      break if act[0] == :goal
      case act[0]
      when :press
        mask ^= sewers.bit(act[3])
        region = sewers::ROOMS[map][3].find { |p| p[1] == act[2] }[0]
      when :door
        to = sewers::ROOMS[map][2].find { |d| d[1] == act[2] }[2]
        map, region, mask = to == :city ? [193, 2, 0] : [to[0], to[1], mask]
      when :thug
        $game_self_switches[[act[1], act[2], "A"]] = true
        $game_variables[105] += 1
        region = sewers::ROOMS[map][4].find { |r| r[1] == act[2] }[0]
      end
      steps += 1
      assert steps < 60, "the walk ends"
    end
    assert_equal 10, $game_variables[105]
    assert_equal [197, 15], [map, region]
  end

  test "Kakui Beach tells the Staryu's rule while their quest is under way, and names its clams by what they hold with the assist" do
    on_map(149)
    $game_variables[87] = 0
    refute_includes info_key, t(:ss1_staryu_rule)
    $game_variables[87] = 3
    assert_equal 1, info_key.scan(t(:ss1_staryu_rule)).length, "the rule once"
    $game_variables[87] = 7
    refute_includes info_key, t(:ss1_staryu_rule)
    place(27, 20, 12, [TestCmd.new(101, ["It's a clam"])])
    place(28, 17, 11, [TestCmd.new(101, ["It's a clam"])])
    $game_variables[89] = 1
    assert_equal [t(:ss1_clam)] * 2, [name_of(27), name_of(28)]
    PokeAccess::Config.puzzle_assist = true
    assert_equal [t(:ss1_clam_gem), t(:ss1_clam_pokemon)], [name_of(27), name_of(28)]
  end

  test "Route 110's trapped Lapras tell the side they are freed from with the assist alone" do
    on_map(234)
    place(7, 56, 16, [TestCmd.new(101, ["Lapras"])], :sprite => "pkmn_lapras", :name => "Trapped Lapras")
    $game_variables[120] = 2
    refute_equal t(:ss1_lapras_from_west), name_of(7)
    PokeAccess::Config.puzzle_assist = true
    assert_equal t(:ss1_lapras_from_west), name_of(7)
  end

  test "the gravestones of Beta Omicron and the shrubs of Rasha Prime count with the assist alone" do
    on_map(287)
    place(15, 10, 12, [TestCmd.new(101, ["Gravestone"])])
    assert_equal t(:ss1_phantom_grave), name_of(15)
    tick
    $game_variables[183] = 2
    assert_equal [], tick
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, t(:puzzle_progress, :label => t(:ss1_phantom_graves), :n => 2, :of => 5)
    on_map(494)
    place(4, 15, 30, [TestCmd.new(101, ["shrub"])])
    $game_variables[335] = 1
    assert_equal t(:ss1_sample_shrub), name_of(4)
    assert_includes listed, [15, 30]
    $game_self_switches[[494, 4, "A"]] = true
    refute_includes listed, [15, 30], "a shrub harvested drops out of the puzzles"
  end

  test "the Realm of Deception points the assist at the scene of the next branch, and says nothing of it without" do
    on_map(280)
    { 28 => [6, 7], 31 => [41, 3], 37 => [33, 42], 14 => [6, 40] }.each { |id, (x, y)| place(id, x, y, [TestCmd.new(101, ["..."])], :trigger => 1) }
    assert_empty right_way
    refute_includes info_key, t(:ss1_deception_hint)
    PokeAccess::Config.puzzle_assist = true
    [[0, [6, 7]], [1, [41, 3]], [2, [33, 42]]].each do |v, at|
      $game_variables[149] = v
      assert_equal [at], right_way, "at #{v}"
    end
    assert_includes info_key, t(:ss1_deception_hint)
    $game_variables[149] = 3
    refute_includes info_key, t(:ss1_deception_hint)
  end

  test "the Refugee Tunnels count the Joltik picked up with the assist alone" do
    on_map(15)
    $game_variables[194] = 4
    progress = t(:puzzle_progress, :label => t(:ss1_joltik), :n => 3, :of => 9)
    refute_includes info_key, progress
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, progress
    assert_includes info_key, t(:ss1_joltik_hint)
    $game_variables[194] = 11
    refute PokeAccess::Puzzles.active?
  end

  test "Agency Base Delta says the barrier as its panel flips it, and points the assist at the panel until it is off" do
    on_map(238)
    place(25, 47, 9, [TestCmd.new(101, ["Electric Barrier Disabled"])], :sprite => "")
    assert_equal t(:ss1_agency_barrier_panel), name_of(25)
    assert_empty right_way
    PokeAccess::Config.puzzle_assist = true
    assert_equal [[47, 9]], right_way
    assert_includes info_key, t(:ss1_agency_hint_barrier)
    tick
    $game_switches[272] = true
    assert_equal ["#{t(:ss1_agency_barrier)}: #{t(:ss1_agency_barrier_off)}"], tick
    assert_empty right_way
    assert_includes info_key, t(:ss1_agency_hint_north)
  end

  test "the power plant lists the terminals still waiting, never the one already set, and counts them with the assist" do
    on_map(401)
    place(33, 49, 4, [TestCmd.new(101, ["You place a set of explosives"])])
    place(32, 9, 11, [TestCmd.new(101, ["already has a set of explosives"])])
    assert_equal t(:ss1_plant_terminal), name_of(33)
    assert_equal t(:ss1_plant_terminal_set), name_of(32)
    assert_equal [[49, 4]], listed
    $game_self_switches[[401, 33, "A"]] = true
    assert_empty listed
    $game_variables[279] = 2
    progress = t(:puzzle_progress, :label => t(:ss1_plant_explosives), :n => 2, :of => 5)
    refute_includes info_key, progress
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, progress
  end

  test "the Ishizu temple lists its tablets while the translation lasts and counts them with the assist" do
    on_map(299)
    place(24, 29, 6, [TestCmd.new(101, ["tablet"])])
    assert_empty listed, "before the legend the tablets say nothing"
    $game_variables[320] = 3
    assert_equal t(:ss1_ishizu_tablet), name_of(24)
    assert_equal [[29, 6]], listed
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, t(:puzzle_progress, :label => t(:ss1_ishizu_tablets), :n => 2, :of => 5)
    $game_variables[320] = 6
    assert_empty listed
  end

  test "the Wailord's push answers the info key only while Ken's quest is on, with the way to the water for the assist" do
    on_map(234)
    place(2, 64, 65, [TestCmd.new(355, ["pbPushThisBoulder"])], :sprite => "pkmn_wailord", :trigger => 1)
    PokeAccess::Config.puzzle_assist = true
    refute_includes info_key, t(:ss1_wailord_hint), "before Ken asks"
    $game_self_switches[[234, 2, "A"]] = true
    tick
    assert_includes info_key, t(:ss1_wailord_hint)
    PokeAccess::Config.puzzle_assist = false
    refute_includes info_key, t(:ss1_wailord_hint)
    PokeAccess::Config.puzzle_assist = true
    $game_self_switches[[234, 2, "B"]] = true
    tick
    refute_includes info_key, t(:ss1_wailord_hint), "back in the sea"
  end

  private

  # Presses the buttons the assist names, standing on each, until the fossil is in reach; the buttons pressed.
  def follow_jenola(jen)
    out = []
    20.times do
      s = jen.step
      break if s.nil? || s == [:done]
      if s[0] == :pad
        $game_self_switches = {}
        go(*jen::PAD_AT)
        next
      end
      set_jenola(jen, [s[1]], false)
      out << s[1]
    end
    out
  end

  # Presses buttons in order as the game does, from all rocks standing when fresh, leaving the player on the last.
  def set_jenola(jen, presses, fresh = true)
    $game_self_switches = {} if fresh
    rocks, btns = jen.state
    presses.each { |i| rocks, btns = jen.press(rocks, btns, i) }
    jen::ROCKS.each_with_index { |id, i| $game_self_switches[[98, id, "A"]] = rocks & (1 << i) != 0 }
    jen::BUTTONS.each_with_index { |id, i| $game_self_switches[[98, id, "A"]] = btns & (1 << i) != 0 }
    go(*jen::BUTTON_AT[presses.last])
  end


  def t(key, vars = {})
    PokeAccess::I18n.t(key, vars)
  end

  def on_map(map)
    Harness.load_puzzles("soulstones1")
    PokeAccess::Config.puzzle_assist = false
    $game_map.map_id = map
    $game_map.events.clear
    $game_self_switches = {}
    [9, 67, 68, 69, 70, 72, 76, 77, 78, 112, 113, 114, 121, 122, 123, 124, 136, 137, 177, 272].each { |s| $game_switches[s] = false }
    [87, 89, 105, 120, 147, 149, 178, 183, 194, 230, 259, 270, 279, 320, 335].each { |v| $game_variables[v] = 0 }
    go(1, 1)
    World.next_frame
  end

  def place(id, x, y, list, opts = {})
    page = TestPage.new(:trigger => opts.fetch(:trigger, 0), :sprite => opts.fetch(:sprite, ""), :list => list)
    e = TestGameEvent.new(:id => id, :x => x, :y => y, :pages => [page], :active_page => page,
                          :name => opts.fetch(:name, "EV#{id}"))
    $game_map.events[id] = e
    World.next_frame
    e
  end

  def ev(id)
    $game_map.events[id]
  end

  def spec
    tick
    PokeAccess::World::Mechanics.instances.map { |i| i.spec }.find { |s| s[:watch] && !s[:watch].empty? }
  end

  def go(x, y)
    $game_player.x = x
    $game_player.y = y
  end

  def step_on(map, ids)
    ids.each { |id| $game_self_switches[[map, id, "A"]] = true }
    PokeAccess::Frame.instance_variable_set(:@serial, PokeAccess::Frame.serial + 1)
  end

  def name_of(id)
    PokeAccess::Locator.target_name($game_map.events[id])
  end

  def listed
    PokeAccess::Puzzles.category_targets.map { |tg| [tg.x, tg.y] }
  end

  def right_way
    PokeAccess::Puzzles.category_targets.select do |tg|
      name = tg.is_a?(PokeAccess::Locator::SurfaceTarget) ? tg.name : PokeAccess::Locator.target_name(tg)
      name == t(:puzzle_right_way)
    end.map { |tg| [tg.x, tg.y] }
  end

  def tick
    SpeakCapture.clear
    PokeAccess::Puzzles.tick
    SpeakCapture.log.map { |line, _interrupt| line }
  end

  def info_key
    PokeAccess::Info.map_text.to_s
  end
end
