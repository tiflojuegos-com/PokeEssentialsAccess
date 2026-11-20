# Pokemon Eternal Emerald's puzzles on the shipped profile: the statues of Mossdeep Gym, the pads of Mauville Gym, the
# cracked ice of Sootopolis Gym, the hidden holes of Lavaridge Gym and the panels of Team Aqua's hideout, and the side
# sites' switches, each as heard with the puzzle assist and without it.
class EmeraldPuzzlesTest < PokeAccessTest
  def setup
    super
    @self_switches = $game_self_switches
    $game_self_switches = {}
  end

  def teardown
    $game_self_switches = @self_switches
    super
  end

  test "Mossdeep Gym names its statues and switches, and the assist counts the steps each switch still needs" do
    on_mossdeep
    assert_includes names, t(:em_statue)
    assert_equal 3, names.count(t(:em_statue_switch)), "the hidden switch is listed with the assist alone"
    refute_includes info_key.to_s, t(:em_mossdeep_press_hint, :n => 2, :place => "2 #{t(:dir_right)}")
    PokeAccess::Config.puzzle_assist = true
    assert_equal 3, names.count(t(:em_statue_switch))
    assert_includes names, "Interruptor escondido: no lo pises, sus estatuas cierran el paso", "a trap while its statues leave the way open"
    assert_equal [:em_mossdeep_press_hint, { :n => 2, :place => "2 #{t(:dir_right)}" }], mossdeep.press_hint(51)
    hint = t(:em_mossdeep_press_hint, :n => 2, :place => "2 #{t(:dir_right)}")
    assert_match(/2 .*\.\z/, hint, "the line names the count and ends whole")
    assert_includes info_key, hint
    layout(51, 2)
    assert_equal [:em_mossdeep_press_hint, { :n => 3, :place => "6 #{t(:dir_left)}, 29 #{t(:dir_up)}" }], mossdeep.press_hint(45)
    layout(45, 3)
    assert_includes info_key, "Las estatuas dejan el paso libre: las placas llevan hasta Tate y Liza."
    layout(38, 1)
    $game_variables[62] = 1
    $game_self_switches[[452, 38, "A"]] = true
    assert_equal [:em_mossdeep_press_hint, { :n => 1, :place => "13 #{t(:dir_left)}, 24 #{t(:dir_up)}" }], mossdeep.hidden_hint,
                 "one step on, in step, the hidden switch's statues reopen the way"
    assert_includes info_key, "Pisa 1 vez el interruptor de 13 izquierda, 24 arriba.", "one step on they shut it"
    refute_includes info_key, "Las estatuas dejan el paso libre"
    $game_variables[62] = 2
    assert_equal 1, mossdeep.hidden_steps, "after the gym's door its turn runs out of step, and still one step reopens"
    $game_variables[62] = -2
    assert_equal [:em_mossdeep_hidden_reset, { :place => "13 #{t(:dir_left)}, 24 #{t(:dir_up)}" }], mossdeep.hidden_hint,
                 "with no page left the door is the way back"
    assert_equal :em_mossdeep_hidden, mossdeep.hidden_label
    layout(38, 2)
    refute_includes info_key.to_s, "Interruptor escondido"
    move(48, 1, 1)
    assert_equal :em_mossdeep_reset_hint, mossdeep.press_hint(51), "statues out of every layout ask to start over"
    $game_switches[10] = true
    assert_nil PokeAccess::Puzzles.info_line
  end

  test "Mauville Gym's second room points to each pad in turn and drops a pad's name once it is down" do
    on_map(184)
    { 1 => [14, 43], 10 => [5, 38], 22 => [13, 34] }.each { |id, (x, y)| place(id, x, y, [], :trigger => 1, :tile_id => 443) }
    assert_equal 3, names.count(t(:em_mauville_pad))
    PokeAccess::Config.puzzle_assist = true
    assert_equal [:em_mauville_next, { :place => "5 #{t(:dir_right)}, 3 #{t(:dir_down)}" }], mauville.next_pad
    $game_switches[153] = true
    assert_equal [:em_mauville_next, { :place => "4 #{t(:dir_left)}, 2 #{t(:dir_up)}" }], mauville.next_pad
    assert_equal 2, names.count(t(:em_mauville_pad))
    $game_switches[154] = true
    $game_switches[155] = true
    assert_nil mauville.next_pad
    assert_nil PokeAccess::Puzzles.info_line
  end

  test "Sootopolis Gym follows the order the player takes on each floor and asks to start over off every order" do
    on_map(581)
    ICE.each { |id, (x, y)| place(id, x, y, [], :trigger => 1, :tile_id => 459) }
    $game_player.x = 8
    $game_player.y = 20
    PokeAccess::Config.puzzle_assist = true
    assert_equal [8, 19], soot.next_tile(0)
    crack(9)
    assert_equal [7, 19], soot.next_tile(0)
    crack(16)
    assert_nil soot.next_tile(0), "a tile out of the only order"
    assert_equal :em_soot_restart_hint, soot.hint(0)
    assert_includes info_key, "rompe una baldosa pisada para caer al sótano"
    $game_variables[141] = 7
    crack(14)
    crack(29)
    assert_equal [10, 14], soot.next_tile(1), "the east-first order of the second floor"
    assert_equal [:em_soot_next_hint, { :place => "2 #{t(:dir_right)}, 6 #{t(:dir_up)}" }], soot.hint(1)
    $game_variables[142] = 19
    assert_equal [8, 9], soot.next_tile(2)
  end

  test "Lavaridge Gym and Aqua's hideout list the right way and leave the rest out, with the assist alone" do
    on_map(237)
    { 3 => [10, 25], 7 => [4, 30], 8 => [2, 32], 11 => [2, 20] }.each do |id, (x, y)|
      place(id, x, y, [TestCmd.new(201, [0, 236, 1, 1, 2, 0])], :trigger => 1)
    end
    stand(3, 26)
    assert_equal 11, lava.right(237), "one vent per tile, the one that leads on"
    refute PokeAccess::Puzzles.hidden_event?($game_map.events[7]), "nothing hidden without the assist"
    PokeAccess::Config.puzzle_assist = true
    assert PokeAccess::Puzzles.hidden_event?($game_map.events[7])
    refute PokeAccess::Puzzles.hidden_event?($game_map.events[11])
    assert_equal 1, names.count(t(:puzzle_right_way)), "a single right way listed"
    stand(10, 25)
    assert_equal 7, lava.right(237), "not the vent back to the middle"
    stand(4, 31)
    assert_equal 7, lava.right(237)
    on_map(236)
    stand(7, 21)
    assert_equal 15, lava.right(236), "the vent from (4,31) lands here, and this hole leads on to (3,26), whose way is 11"
    stand(18, 19)
    assert_equal :walk, lava.right(236)
    on_map(388)
    stand(45, 10)
    assert_equal 14, aqua.right(388)
    stand(45, 14)
    assert_equal 19, aqua.right(388), "panel 14 lands here and this tile points on, not back"
    $game_switches[264] = true
    assert_nil PokeAccess::Puzzles.info_line
  end

  test "the swamp's buttons and the plant's count go with the assist, the seals and the Regi door's party for all" do
    on_map(791)
    { 87 => [100, 4], 88 => [39, 8], 94 => [44, 35] }.each { |id, (x, y)| place(id, x, y, [TestCmd.new(101, ["?"])]) }
    refute_includes names, t(:em_swamp_button)
    PokeAccess::Config.puzzle_assist = true
    assert_equal 3, names.count(t(:em_swamp_button))
    $game_self_switches[[791, 88, "A"]] = true
    assert_equal 2, names.count(t(:em_swamp_button))
    on_map(530)
    [1, 2, 12, 40].each_with_index { |id, i| place(id, 10 + i, 10, [], :tile_id => 1589) }
    assert_equal 4, names.count(t(:em_seal))
    $game_switches[1287] = true
    assert_includes tick.map(&:first), t(:em_seals_open)
    on_map(475)
    PokeAccess::Config.puzzle_assist = true
    assert_equal :em_sealed_hint, story.sealed_hint, "a party the test has not set is not ready"
    assert_includes info_key, t(:em_sealed_hint)
    on_map(842)
    place(22, 95, 9, [TestCmd.new(201, [0, 841, 102, 17, 2, 0])], :tile_id => 2248)
    assert_equal :em_wall_button, PokeAccess::EmWallButtons.label($game_map.events[22]),
                 "a wall button that shows its far wall is named as a button, not as the way it takes"
    assert_equal t(:em_wall_button), PokeAccess::Locator.target_name($game_map.events[22])
    $game_map.map_id = 812
    assert_equal :em_lever, PokeAccess::EmWallButtons.label($game_map.events[22].tap { |ev| ev.id = 3 })
    $game_map.map_id = 841
    assert_nil PokeAccess::EmWallButtons.label($game_map.events[22].tap { |ev| ev.id = 3 })
  end

  test "Baobab Lab's assist names the next can of the plan by the switches on, and the way once the doors allow it" do
    on_map(536)
    $game_player.x = 46
    $game_player.y = 42
    PokeAccess::Config.puzzle_assist = true
    assert_equal [:em_baobab_press, { :place => "19 #{t(:dir_left)}, 6 #{t(:dir_up)}" }], baobab.hint
    $game_switches[245] = true
    assert_equal 9, baobab.next_step
    $game_switches[246] = true
    assert_equal 21, baobab.next_step
    [245, 246].each { |s| $game_switches[s] = false }
    $game_switches[249] = true
    assert_equal :em_baobab_walk, baobab.hint
    assert_includes info_key, t(:em_baobab_walk)
    $game_self_switches[[536, 39, "A"]] = true
    assert_equal [:em_baobab_restore, { :place => "19 #{t(:dir_left)}, 6 #{t(:dir_up)}" }], baobab.restore_hint
    $game_switches[245] = true
    assert_equal [:em_baobab_restore, { :place => "18 #{t(:dir_left)}, 13 #{t(:dir_up)}" }], baobab.restore_hint
    $game_switches[246] = true
    assert_nil PokeAccess::Puzzles.info_line
  end

  test "a Baobab can warns with the assist alone, before it is pressed, of the story it would undo elsewhere" do
    on_map(536)
    baobab::CANS.each { |id, (x, y)| place(id, x, y, [TestCmd.new(101, ["?"])]) }
    [245, 246].each { |s| $game_switches[s] = true }
    tick
    assert_empty use(22), "nothing without the assist"
    PokeAccess::Config.puzzle_assist = true
    assert_equal [t(:em_baobab_undo_both)], use(22)
    assert_equal [t(:em_baobab_undo_grunts)], use(8)
    assert_empty use(9), "a can that turns neither off says nothing"
    $game_switches[246] = false
    assert_empty use(8), "nothing to undo once that flag is already off"
    assert_equal [t(:em_baobab_undo_kecleon)], use(21)
    assert_match(/Devon Scope\.\z/, t(:em_baobab_undo_kecleon), "the warning ends whole")
  end

  test "the Trick House points to each switch, the scroll and the door, and room 7 follows its statues" do
    on_map(222)
    PokeAccess::Config.puzzle_assist = true
    $game_player.x = 13
    $game_player.y = 14
    assert_equal [:em_trick_next, { :place => "1 #{t(:dir_up)}" }], trick.hint(222)
    [172, 173, 174, 179].each { |s| $game_switches[s] = true }
    assert_equal :em_trick_scroll_hint, trick.hint(222)[0]
    $game_switches[175] = true
    assert_equal :em_trick_door_hint, trick.hint(222)[0]
    on_map(314)
    trick::LAYOUTS7.each_value { |lays| lays[0].each { |id, (x, y)| place(id, x, y, [], :tile_id => 527) } }
    assert_equal 7, trick.next7
    trick::LAYOUTS7[7][1].each { |id, (x, y)| move(id, x, y) }
    assert_equal 5, trick.next7
    { 5 => 2, 9 => 1, 11 => 1 }.each { |tr, n| trick::LAYOUTS7[tr][n].each { |id, (x, y)| move(id, x, y) } }
    assert_equal :done, trick.next7
    $game_switches[1147] = true
    assert_equal 11, trick.next7, "after the scroll the door's presses begin"
    on_map(314)
    trick::LAYOUTS7.each_value { |lays| lays[0].each { |id, (x, y)| place(id, x, y, [], :tile_id => 527) } }
    stand(9, 23)
    PokeAccess::Config.puzzle_assist = true
    assert_equal [:em_trick_next, { :place => "7 #{t(:dir_right)}, 2 #{t(:dir_up)}" }], trick.hint7, "in step on a fresh visit"
    $game_self_switches[[314, 5, "A"]] = true
    $game_variables[181] = 0
    assert_equal [:em_trick7_finish, { :n => 3, :place => "1 #{t(:dir_left)}, 7 #{t(:dir_up)}" }], trick.hint7,
                 "a trigger left after one step turns out of step: three more finish its turn"
    $game_self_switches[[314, 5, "A"]] = false
    move(6, 11, 19)
    assert_equal :em_trick7_reenter, trick.hint7, "no half turn left, statues off their places: come back in"
  end

  test "Seafoam tracks each boulder to its hole and says it falls; the Sky Base points to seed and soil in turn" do
    on_map(725)
    place(4, 27, 15, [TestCmd.new(355, ["pbPushThisBoulder"])], :trigger => 1, :sprite => "Object boulder")
    refute_includes tick.map(&:first), t(:em_seafoam_fell)
    $game_switches[650] = true
    assert_includes tick.map(&:first), t(:em_seafoam_fell)
    on_map(566)
    $game_player.x = 21
    $game_player.y = 50
    PokeAccess::Config.puzzle_assist = true
    assert_equal [:em_sky_seed_hint, { :place => "3 #{t(:dir_down)}" }], sky.hint(566)
    $game_switches[514] = true
    assert_equal [:em_sky_plant_hint, { :place => "11 #{t(:dir_left)}, 4 #{t(:dir_up)}" }], sky.hint(566)
    $game_switches[515] = true
    assert_equal :em_sky_seed_hint, sky.hint(566)[0]
  end

  private

  def baobab; PokeAccess::EmBaobab; end
  def lava; PokeAccess::EmLavaridge; end
  def aqua; PokeAccess::EmAquaHideout; end

  # Puts the player on (x, y).
  def stand(x, y)
    $game_player.x = x
    $game_player.y = y
    World.next_frame
  end
  def trick; PokeAccess::EmTrickHouse; end
  def sky; PokeAccess::EmSkyBase; end

  ICE = { 9 => [8, 19], 12 => [7, 19], 13 => [7, 18], 15 => [8, 18], 16 => [9, 18], 17 => [9, 17], 18 => [8, 17],
          14 => [8, 14], 19 => [7, 14], 29 => [9, 14], 30 => [10, 14], 28 => [9, 13] }

  def mossdeep; PokeAccess::EmMossdeep; end
  def mauville; PokeAccess::EmMauville; end
  def soot; PokeAccess::EmSootopolis; end
  def story; PokeAccess::EmStorySwitches; end

  # The lines said as the player uses event id.
  def use(id)
    tick
    PokeAccess::World::Mechanics.used($game_map.events[id])
    tick.map(&:first)
  end

  # The spoken text of an i18n key.
  def t(key, vars = {})
    PokeAccess::I18n.t(key, vars)
  end

  # Declares the shipped puzzles and puts the player on map with every flag of these puzzles off.
  def on_map(map)
    Harness.load_puzzles("emerald")
    PokeAccess::Puzzles.instance_variable_set(:@told, {})
    PokeAccess::Config.puzzle_assist = false
    $game_map.map_id = map
    $game_map.events.clear
    ([7, 10, 11, 151, 152, 153, 154, 155, 172, 173, 174, 175, 177, 179, 264, 777, 778, 1075, 1147, 1287] + (245..250).to_a +
     (514..521).to_a + (648..655).to_a).each { |s| $game_switches[s] = false }
    [141, 142, 143, 152, 176, 243].each { |v| $game_variables[v] = 0 }
    $game_player.x = 9
    $game_player.y = 40
    World.next_frame
  end

  # Mossdeep Gym as the player enters it: statues where the map draws them, the switches and the player at the door.
  def on_mossdeep
    on_map(452)
    mossdeep::LAYOUTS.each_value { |lays| lays[0].each { |id, (x, y)| place(id, x, y, [], :tile_id => 462) } }
    [[17, 5, 8], [23, 4, 18], [24, 5, 18], [34, 4, 8], [35, 9, 7], [36, 11, 8]].each { |id, x, y| place(id, x, y, [], :tile_id => 462) }
    { 51 => [16, 34], 45 => [8, 5], 25 => [2, 18], 38 => [1, 10] }.each do |id, (x, y)|
      place(id, x, y, [TestCmd.new(209, [40, nil])], :trigger => 1)
    end
    $game_player.x = 14
    $game_player.y = 34
  end

  # Puts group's statues in its layout n.
  def layout(group, n)
    mossdeep::LAYOUTS[group][n].each { |id, (x, y)| move(id, x, y) }
  end

  # Cracks the Sootopolis tile id: its self switch A.
  def crack(id)
    $game_self_switches[[581, id, "A"]] = true
    World.next_frame
  end

  # An event at (x, y) whose live page runs list, placed on the map.
  def place(id, x, y, list, opts = {})
    page = TestPage.new(:trigger => opts.fetch(:trigger, 0), :sprite => opts.fetch(:sprite, ""), :list => list)
    ev = TestGameEvent.new(:id => id, :x => x, :y => y, :pages => [page], :active_page => page,
                           :tile_id => opts.fetch(:tile_id, 0))
    $game_map.events[id] = ev
    World.next_frame
    ev
  end

  # Moves event id to (x, y).
  def move(id, x, y)
    ev = $game_map.events[id]
    ev.x = x
    ev.y = y
    World.next_frame
  end

  # The names the puzzles category lists now.
  def names
    PokeAccess::Puzzles.category_targets.map { |x| x.respond_to?(:key) ? x.name : PokeAccess::Locator.target_name(x) }
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
