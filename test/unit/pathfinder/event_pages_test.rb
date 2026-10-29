# EventPages walks a touch event's page per facing as the interpreter would, without running it: the player's moves,
# branches, transfers, ramps, talk, lasting changes and the script conditions it reads; the rest stops it as unknown.
class EventPagesTest < PokeAccessTest
  EP = PokeAccess::EventPages
  SC = PokeAccess::EventPages::ScriptCondition
  # A common event as $data_common_events holds it: its command list.
  CommonEvent = Struct.new(:list)

  test "a plain carry walks its steps and nothing else" do
    want = EP::Outcome.new([-2, -1], [[-1, 0, 4], [-2, 0, 4], [-2, -1, 8]], nil, nil, false, false, false, false, false,
                           false, false, false, false, false)
    assert_equal want, walk([World.move_player([2, 2, 4])], 2)
  end

  test "each step moves the player its way and turns them to face it" do
    { 1 => [0, 1, 2], 2 => [-1, 0, 4], 3 => [1, 0, 6], 4 => [0, -1, 8] }.each do |code, step|
      assert_equal [step], walk([World.move_player([code])], 8).path, "move code #{code}"
    end
  end

  test "a diagonal step moves both ways and turns the player as RMXP turns them" do
    {
      [5, 2] => [-1, 1, 2], [5, 4] => [-1, 1, 4], [5, 6] => [-1, 1, 4], [5, 8] => [-1, 1, 2],
      [6, 2] => [1, 1, 2], [6, 4] => [1, 1, 6], [6, 6] => [1, 1, 6], [6, 8] => [1, 1, 2],
      [7, 2] => [-1, -1, 8], [7, 4] => [-1, -1, 4], [7, 6] => [-1, -1, 4], [7, 8] => [-1, -1, 8],
      [8, 2] => [1, -1, 8], [8, 4] => [1, -1, 6], [8, 6] => [1, -1, 6], [8, 8] => [1, -1, 8]
    }.each do |(code, face), step|
      assert_equal [step], walk([World.move_player([code])], face).path, "move code #{code} facing #{face}"
    end
  end

  test "an unconditional move is the same whichever way the player faces" do
    [2, 4, 6, 8].each { |face| assert_equal [0, 2], moved([1, 1], face), "facing #{face}" }
  end

  test "forward and backward steps follow the facing, a turn before them included" do
    {
      [[12, 12], 6] => [2, 0], [[12, 12], 8] => [0, -2], [[13], 6] => [-1, 0],
      [[16, 12], 8] => [0, 1], [[17, 12], 2] => [-1, 0], [[18, 13], 2] => [-1, 0], [[19, 12], 6] => [0, -1]
    }.each { |(codes, face), move| assert_equal move, moved(codes, face), "#{codes.inspect} facing #{face}" }
  end

  test "a quarter turn right or left, or a half turn, turns the facing as RMXP turns it" do
    {
      20 => { 2 => [-1, 0], 4 => [0, -1], 6 => [0, 1], 8 => [1, 0] },
      21 => { 2 => [1, 0], 4 => [0, 1], 6 => [0, -1], 8 => [-1, 0] },
      22 => { 2 => [0, -1], 4 => [1, 0], 6 => [-1, 0], 8 => [0, 1] }
    }.each do |code, by_face|
      by_face.each { |face, move| assert_equal move, moved([code, 12], face), "turn code #{code} facing #{face}" }
    end
  end

  test "with the facing fixed, steps, turns and jumps keep it until it is let go" do
    {
      [35, 4, 12] => [1, -1], [35, 20, 12] => [1, 0], [35, 19, 12] => [1, 0], [35, 5, 12] => [0, 1],
      [35, [14, [0, -2]], 12] => [1, -2], [35, 23, 12] => [1, 0], [35, 36, 4, 12] => [0, -2]
    }.each { |codes, move| assert_equal move, moved(codes, 6), "#{codes.inspect} facing right" }
  end

  test "a jump moves by its offsets, says it was a jump, and turns toward its longer leg" do
    { [0, 2] => 2, [-2, 1] => 4, [3, 0] => 6, [0, -1] => 8, [1, -1] => 8, [-1, 1] => 2 }.each do |offset, face|
      o = walk([World.move_player([[14, offset]])], 6)
      assert_equal [offset, [offset + [face]], true], [o.move, o.path, o.jump], "a jump by #{offset.inspect}"
    end
  end

  test "a jump in place is no jump" do
    o = walk([World.move_player([[14, [0, 0]]])], 2)
    assert_equal [nil, [], false], [o.move, o.path, o.jump]
  end

  test "a step taken with Through on is marked as one" do
    { [37, 4, 38] => true, [4] => false, [37, 38, 4] => false, [4, 37] => false }.each do |codes, through|
      assert_equal through, walk([World.move_player(codes)], 2).through, codes.inspect
    end
  end

  test "a move whose end cannot be known stops the walk as unknown" do
    [[9], [10], [11], [23, 12], [24, 13], [24, 20], [[45, ["moveto(3, 4)"]]], [[45, ["move_down"]]],
     [[45, ["jump(1, 0)"]]], [[45, ["@y = 3"]]]].each do |codes|
      assert_equal true, walk([World.move_player(codes)], 2).unknown, codes.inspect
    end
  end

  test "a facing no step goes by stops a forward step as unknown" do
    assert_equal true, walk([World.move_player([12])], 0).unknown
  end

  test "a move route script that moves no one is walked past" do
    o = walk([World.move_player([[45, ["pbSEPlay('Door')"]], 4])], 2)
    assert_equal [[0, -1], false], [o.move, o.unknown]
  end

  test "a malformed move command is passed over, and a route with no list moves no one" do
    route = TestMoveRoute.new([nil, TestMoveCmd.new(4)])
    assert_equal [0, -1], walk([TestCmd.new(209, [-1, route])], 2).move
    o = walk([TestCmd.new(209, [-1, nil])], 2)
    assert_equal [nil, false], [o.move, o.unknown]
  end

  test "a move route set on another character leaves the player where they stand" do
    [0, 3].each do |who|
      o = walk([TestCmd.new(209, [who, TestMoveRoute.new([TestMoveCmd.new(4)])])], 2)
      assert_equal [nil, false], [o.move, o.unknown], "a route on character #{who}"
    end
  end

  test "each facing branch keeps its own move, the else answering the rest" do
    list = [World.if_facing(4), World.move_player([2, 2, 4], 1), World.else_, World.move_player([3, 3, 1], 1), World.end_]
    { 4 => [-2, -1], 6 => [2, 1], 2 => [2, 1], 8 => [2, 1] }.each do |face, move|
      assert_equal move, walk(list, face).move, "facing #{face}"
    end
  end

  test "a switch branch runs while the switch is as it asks" do
    $game_switches[41] = false
    assert_equal [false, true], [ran?([0, 41, 0]), ran?([0, 41, 1])], "switch off"
    $game_switches[41] = true
    assert_equal [true, false], [ran?([0, 41, 0]), ran?([0, 41, 1])], "switch on"
  end

  test "a branch on a variable runs as it compares with a number, at each operator's edge" do
    $game_variables[42] = 3
    {
      [0, 3] => true, [0, 2] => false, [1, 3] => true, [1, 4] => false, [2, 3] => true, [2, 2] => false,
      [3, 3] => false, [3, 2] => true, [4, 3] => false, [4, 4] => true, [5, 3] => false, [5, 2] => true
    }.each { |(op, n), runs| assert_equal runs, ran?([1, 42, 0, n, op]), "variable 3, operator #{op}, #{n}" }
  end

  test "a branch on a variable runs as it compares with another variable" do
    $game_variables[42] = 3
    $game_variables[43] = 3
    assert_equal [true, false], [ran?([1, 42, 1, 43, 0]), ran?([1, 42, 1, 43, 4])], "3 and 3"
    $game_variables[43] = 4
    assert_equal [false, true], [ran?([1, 42, 1, 43, 0]), ran?([1, 42, 1, 43, 4])], "3 and 4"
  end

  test "a variable that holds no number, or an operator RMXP has not, is no answer" do
    $game_variables[42] = "tres"
    assert_nil ran?([1, 42, 0, 3, 0]), "a word"
    $game_variables[42] = 3
    assert_nil ran?([1, 42, 0, 3, 6]), "operator 6"
  end

  test "a self switch branch reads the event's own self switch on this map" do
    with_self_switches([1, 90, "A"] => true) do
      assert_equal [true, false, false], [ran?([2, "A", 0]), ran?([2, "A", 1]), ran?([2, "B", 0])]
    end
  end

  test "a facing branch on the event or another character reads their live facing" do
    other = World.event(:id => 7, :x => 2, :y => 2)
    other.direction = 4
    ev = page(branch([6, 0, 8]))
    ev.direction = 8
    assert_equal [0, 1], EP.outcome(ev, 2).move, "the event's own facing"
    assert_equal [true, false], [ran?([6, 7, 4]), ran?([6, 7, 6])], "another character's"
    assert_nil ran?([6, 8, 4]), "a character the map does not have"
  end

  test "a button branch is the direction walked" do
    assert_equal [true, false], [ran?([11, 8], 8), ran?([11, 8], 2)]
  end

  test "a move behind a button branch is marked as needing that key held, one without it is not" do
    stair = [World.if_facing(4), TestCmd.new(111, [11, 4], 1), World.move_player([37, 5, 38], 2), World.end_(1),
             World.end_]
    o = walk(stair, 4)
    assert_equal [[-1, 1], true], [o.move, o.pressed]
    assert_equal [nil, false], [walk(stair, 6).move, walk(stair, 6).pressed]
    assert_equal false, walk([World.move_player([5])], 4).pressed
  end

  test "a branch on what the walk cannot read is no answer" do
    assert_nil ran?([4, 1, 0, 0])
  end

  test "a condition on where the player stands reads the tile the page fires from" do
    list = [TestCmd.new(111, [12, "$game_player.x == 12"]), World.move_player([2, 2, 1], 1), World.end_,
            TestCmd.new(111, [12, "$game_player.x == 13"]), World.move_player([1, 2, 2, 2], 1), World.end_]
    assert_equal [-2, 1], walk(list, 8, [12, 8]).move, "from x 12"
    assert_equal [-3, 1], walk(list, 8, [13, 8]).move, "from x 13"
    assert_equal true, walk(list, 8).unknown, "not told where, it is unknown rather than guessed"
  end

  test "a move before a condition counts toward where the player stands" do
    { [1, "$game_player.y == 9", 3] => [1, 1], [3, "$game_player.x == 6", 1] => [1, 1] }.each do |(first, cond, more), move|
      list = [World.move_player([first]), TestCmd.new(111, [12, cond]), World.move_player([more], 1), World.end_]
      assert_equal move, walk(list, 2, [5, 8]).move, "from (5, 8), move #{first}, then #{cond}"
    end
  end

  test "a page with a script condition, or calling a common event with one, is walked tile by tile" do
    scripted = [TestCmd.new(111, [12, "$game_switches[3]"]), World.end_]
    with_common_events(1 => scripted, 2 => [World.move_player([1])]) do
      {
        scripted => true, [World.move_player([1])] => false, [TestCmd.new(111, [0, 3, 0]), World.end_] => false,
        [TestCmd.new(117, [1])] => true, [TestCmd.new(117, [2])] => false, [TestCmd.new(117, [9])] => false
      }.each { |list, tiled| assert_equal tiled, EP.varies_by_tile?(list), list.map { |c| c.code }.inspect }
    end
  end

  test "a script condition is looked for three common events deep, and a common event calling itself ends there" do
    chain = { 1 => [TestCmd.new(117, [2])], 2 => [TestCmd.new(117, [3])], 3 => [TestCmd.new(117, [4])],
              4 => [TestCmd.new(111, [12, "$game_switches[3]"]), World.end_] }
    with_common_events(chain) do
      assert_equal [true, false], [EP.varies_by_tile?([TestCmd.new(117, [2])]), EP.varies_by_tile?([TestCmd.new(117, [1])])]
    end
    with_common_events(1 => [TestCmd.new(117, [1])]) { assert_equal false, EP.varies_by_tile?([TestCmd.new(117, [1])]) }
  end

  test "common events calling common events are followed three deep" do
    chain = { 12 => [TestCmd.new(117, [13])], 13 => [TestCmd.new(117, [14])], 14 => [TestCmd.new(117, [15])],
              15 => [World.move_player([1])] }
    with_common_events(chain) do
      assert_equal [0, 1], walk([TestCmd.new(117, [13])], 2).move, "three deep"
      assert_equal true, walk([TestCmd.new(117, [12])], 2).unknown, "four deep"
    end
  end

  test "a common event the page calls is walked in place, and Exit Event Processing there ends only it" do
    with_common_events(1 => [World.move_player([5]), TestCmd.new(115, []), World.move_player([1])]) do
      assert_equal [0, 1], walk([TestCmd.new(117, [1]), World.move_player([3])], 2).move
    end
  end

  test "Exit Event Processing on the page ends the walk" do
    assert_equal [0, -1], walk([World.move_player([4]), TestCmd.new(115, []), World.move_player([1])], 2).move
  end

  test "a transfer in a common event the page calls ends the page's walk" do
    with_common_events(1 => [TestCmd.new(201, [0, 9, 1, 1])]) do
      o = walk([TestCmd.new(117, [1]), World.move_player([4])], 2)
      assert_equal [[9, 1, 1], nil], [o.transfer, o.move]
    end
  end

  test "a walk stopped inside a common event goes no further on the page" do
    with_common_events(1 => [TestCmd.new(103, [])]) do
      o = walk([TestCmd.new(117, [1]), TestCmd.new(201, [0, 9, 1, 1])], 2)
      assert_equal [true, nil], [o.unknown, o.transfer]
    end
  end

  test "a common event an engine's data provider keeps, with no $data_common_events, is walked in place" do
    kept = Object.new
    table = { 1 => CommonEvent.new([World.move_player([1])]) }
    kept.define_singleton_method(:common_events) { table }
    with_common_events({}) do
      $data_common_events = nil
      Harness.with_provider(kept) { assert_equal [0, 1], walk([TestCmd.new(117, [1])], 2).move }
    end
  end

  test "a common event the game does not have is unknown" do
    assert_equal true, walk([TestCmd.new(117, [9])], 2).unknown, "no common events at all"
    with_common_events(1 => [World.move_player([1])]) do
      assert_equal true, walk([TestCmd.new(117, [9])], 2).unknown, "not that one"
    end
  end

  test "a transfer ends the walk where it lands, written out or read from the variables it names" do
    o = walk([TestCmd.new(201, [0, 12, 3, 4]), World.move_player([4])], 2)
    assert_equal [[12, 3, 4], nil], [o.transfer, o.move], "written out, and nothing after it is walked"
    $game_variables[31] = 8
    $game_variables[32] = 2
    $game_variables[33] = 6
    assert_equal [8, 2, 6], walk([TestCmd.new(201, [1, 31, 32, 33])], 2).transfer, "by variables"
  end

  test "a transfer whose map cannot be read is unknown, a transfer lying there" do
    $game_variables[34] = 0
    [[1, 34, 32, 33], [2, 12, 3, 4]].each do |pars|
      o = walk([TestCmd.new(201, pars)], 2)
      assert_equal [nil, true, true], [o.transfer, o.unknown, o.maybe_transfer], pars.inspect
    end
  end

  test "a transfer written as a script lands on what it names" do
    assert_equal [12, 7, 9], walk([TestCmd.new(355, ["pbTransferWithTransition(12,7,9,nil)"])], 2).transfer
    ids = [TestCmd.new(355, ["$game_temp.player_new_map_id = 4"]), TestCmd.new(655, ["$game_temp.player_new_x = 3"]),
           TestCmd.new(655, ["$game_temp.player_new_y = 8"])]
    assert_equal [4, 3, 8], walk(ids, 2).transfer, "a new position written out over several lines"
  end

  test "a bridge ramp's script sets the bridge's height" do
    { "pbBridgeOn" => 2, "pbBridgeOn(3)" => 3, "pbBridgeOn( 1 )" => 1, "pbBridgeOff" => 0, "puentedemierda" => :toggle }
      .each { |script, height| assert_equal height, walk([TestCmd.new(355, [script])], 2).bridge, script }
    assert_nil walk([TestCmd.new(355, ["pbSEPlay('Door')"])], 2).bridge, "a script that is no ramp"
  end

  test "the last ramp of a page sets the height, a later script that is none keeps it" do
    on = TestCmd.new(355, ["pbBridgeOn"])
    assert_equal 0, walk([on, TestCmd.new(355, ["pbBridgeOff"])], 2).bridge
    assert_equal 2, walk([on, TestCmd.new(355, ["pbSEPlay('Door')"])], 2).bridge
  end

  test "a cutscene talks, and a battle is told as one" do
    {
      [TestCmd.new(101, ["¡Espera!"])] => [true, false], [TestCmd.new(301, [0, 1])] => [true, true],
      [TestCmd.new(355, ["pbTrainerBattle(:HIKER)"])] => [true, true],
      [TestCmd.new(355, ["pbWildBattle(:ONIX, 20)"])] => [true, true],
      [TestCmd.new(355, ["pbMessage(_INTL(\"Hola\"))"])] => [true, false], [World.move_player([1])] => [false, false]
    }.each { |list, said| assert_equal said, [walk(list, 2).talks, walk(list, 2).battle], list.map { |c| c.code }.inspect }
  end

  test "a page that talks still carries" do
    o = walk([TestCmd.new(101, ["¡Espera!"]), World.move_player([4])], 2)
    assert_equal [[0, -1], true, false], [o.move, o.talks, o.changes]
  end

  test "what a page sets that stays is a change, a comparison is not" do
    [121, 122, 123, 125, 126, 127, 128, 129].each do |code|
      assert_equal true, walk([TestCmd.new(code, [])], 2).changes, "command #{code}"
    end
    ["pbSetSelfSwitch(1, 'A', true)", "$game_switches[3] = true", "$game_variables[2]=5", "pbReceiveItem(:POTION)",
     "pbItemBall(:POTION)", "pbAddPokemon(:PIKACHU, 5)"].each do |script|
      assert_equal true, walk([TestCmd.new(355, [script])], 2).changes, script
    end
    ["$game_switches[3] == true", "pbSEPlay('Door')"].each do |script|
      assert_equal false, walk([TestCmd.new(355, [script])], 2).changes, script
    end
  end

  test "a page that waits for its move to end says so" do
    move = World.move_player([2])
    wait = TestCmd.new(210, [])
    { [move, wait] => true, [wait, move] => false, [move] => false }.each do |list, waits|
      assert_equal waits, walk(list, 2).waits, list.map { |c| c.code }.inspect
    end
  end

  test "a command whose way cannot be told stops the walk, noting whether a transfer lies past it" do
    [103, 112, 113, 118, 119, 413].each do |code|
      o = walk([TestCmd.new(code, []), World.move_player([1]), TestCmd.new(201, [0, 7, 3, 4])], 2)
      assert_equal [true, true, nil], [o.unknown, o.maybe_transfer, o.move], "command #{code}, a transfer past it"
      assert_equal false, walk([TestCmd.new(code, [])], 2).maybe_transfer, "command #{code}, none past it"
    end
    o = walk([TestCmd.new(112, []), TestCmd.new(355, ["pbTransferWithTransition(12,7,9,nil)"])], 2)
    assert_equal true, o.maybe_transfer, "a transfer written as a script past it"
  end

  test "a choice stops a touch, and a walk answering yes runs the first option's branch alone" do
    list = [TestCmd.new(102, [["Sí", "No"], 2]), TestCmd.new(402, [0, "Sí"]), World.move_player([4], 1),
            TestCmd.new(402, [1, "No"]), World.move_player([1], 1), TestCmd.new(403, []), World.move_player([2], 1),
            TestCmd.new(404, [])]
    assert_equal true, EP.outcome(page(list), 2).unknown, "as a touch, the walk unless told"
    o = walk(list, 2, nil, true)
    assert_equal [[0, -1], true], [o.move, o.talks], "answered yes"
  end

  test "a choice that stops a touch notes a transfer past it" do
    o = walk([TestCmd.new(102, [["Sí", "No"], 2]), TestCmd.new(201, [0, 7, 3, 4])], 2)
    assert_equal [true, true, nil], [o.unknown, o.maybe_transfer, o.transfer]
  end

  test "a page started with the action button is walked answering yes" do
    climb = [TestCmd.new(101, ["¿Quieres escalar?"]), TestCmd.new(102, [["Sí", "No"], 2]), TestCmd.new(402, [0, "Sí"]),
             World.move_player([37, 4, 4, 4, 38], 1), TestCmd.new(402, [1, "No"]), TestCmd.new(404, [])]
    o = walk(climb, 8, nil, true)
    assert_equal [[0, -3], true, true, false], [o.move, o.through, o.talks, o.changes]
  end

  test "a question kept in a variable is answered with its first option, and keeping it is no change" do
    asked = [TestCmd.new(355, ['$game_variables[5] = pbMessageBlack(_INTL("¿Trepar?"),[_INTL("Sí"),_INTL("No")],2)']),
             TestCmd.new(111, [1, 5, 0, 0, 0]), World.move_player([4, 4], 1), World.end_]
    $game_variables[5] = 1
    o = walk(asked, 8, nil, true)
    assert_equal [[0, -2], false], [o.move, o.changes], "answered yes"
    o = walk(asked, 8)
    assert_equal [nil, true], [o.move, o.changes], "as a touch the variable is read as it stands, and setting it changes"
  end

  test "a confirmation is accepted only by a walk that answers" do
    confirm = [TestCmd.new(111, [12, 'pbConfirmMessage(_INTL("¿Seguro? (sí)"))']), World.move_player([1], 1), World.end_]
    assert_equal [0, 1], walk(confirm, 2, nil, true).move
    assert_equal true, walk(confirm, 2).unknown
  end

  test "a branch a held direction key opens marks the walk as held" do
    floor = World.cracked_floor(999)
    $PokemonGlobal.bicycle = true
    o = walk(floor, 6)
    assert_equal [true, nil], [o.held, o.transfer], "on the bike the floor bears the player while the key is held"
    $PokemonGlobal.bicycle = false
    o = walk(floor, 6)
    assert_equal [false, [999, 3, 10]], [o.held, o.transfer], "on foot it gives way"
  end

  test "a key that reads as held marks nothing unless the page goes that way because of it" do
    {
      "Input.press?(Input::UP) && false" => [8, nil],
      "!Input.press?(Input::UP)" => [2, [0, 1]]
    }.each do |script, (face, move)|
      o = walk([TestCmd.new(111, [12, script]), World.move_player([1], 1), World.end_], face)
      assert_equal [false, move], [o.held, o.move], script
    end
  end

  test "what a touch event does, read from a switch, is read again once the switch changes" do
    hpa_fresh_grid(["#######", "#@....#", "#######"])
    pad = [TestCmd.new(111, [0, 41, 0]), TestCmd.new(201, [0, $game_map.map_id, 1, 1], 1), World.end_]
    World.touch(:id => 2, :x => 4, :y => 1, :list => pad)
    assert_nil PokeAccess::Routes::Effects.touch_at(4, 1, 6, true), "with the switch off, the pad does nothing"
    World.next_frame
    assert_nil PokeAccess::Routes::Effects.touch_at(4, 1, 6, true), "nor a frame later with the switch as it was"
    $game_switches[41] = true
    World.next_frame
    assert_equal [:warp, 1, 1], PokeAccess::Routes::Effects.touch_at(4, 1, 6, true), "on, it takes the player away"
  end

  test "an event with no command list has no outcome" do
    ev = TestGameEvent.new(:id => 95, :pages => [TestPage.new(:list => nil)])
    assert_nil EP.outcome(ev, 2)
  end

  test "a page of more commands than the walk takes is unknown" do
    assert_equal false, walk([TestCmd.new(108, ["."])] * 1999, 2).unknown, "2000 with the end"
    assert_equal true, walk([TestCmd.new(108, ["."])] * 2000, 2).unknown, "2001"
  end

  test "a script condition reads switches, negation, parentheses and the words for and, or and not" do
    $game_switches[43] = true
    {
      "$game_switches[43]" => true, "!$game_switches[43]" => false, "not $game_switches[44]" => true,
      "$game_switches[44] || ($game_switches[43] && true)" => true, "$game_switches[43] and $game_switches[44]" => false,
      "$game_switches[44] or $game_switches[43]" => true, "(($game_switches[43]))" => true, "true" => true,
      "false" => false, "nil" => false
    }.each { |src, want| assert_equal want, evaluate(src), src }
  end

  test "a script condition reads the vehicle the player is on" do
    $PokemonGlobal.bicycle = true
    assert_equal [true, false, false],
                 [evaluate("$PokemonGlobal.bicycle"), evaluate("$PokemonGlobal.surfing"), evaluate("$PokemonGlobal.diving")]
    $PokemonGlobal.bicycle = false
    $PokemonGlobal.surfing = true
    $PokemonGlobal.diving = true
    assert_equal [false, true, true],
                 [evaluate("$PokemonGlobal.bicycle"), evaluate("$PokemonGlobal.surfing"), evaluate("$PokemonGlobal.diving")]
  end

  test "numbers compare with each operator" do
    { "3 >= 2" => true, "3 > 3" => false, "3 <= 3" => true, "3 < 3" => false, "3 == 3" => true, "3 != 3" => false,
      "-1 < 0" => true }.each { |src, want| assert_equal want, evaluate(src), src }
  end

  test "== and != compare any two values, the order comparisons only numbers" do
    { "$PokemonGlobal.bicycle == false" => true, "$PokemonGlobal.bicycle != false" => false, "true == true" => true,
      "true >= false" => nil }.each { |src, want| assert_answer want, evaluate(src), src }
  end

  test "a call it does not know is no answer, unless a known side settles it" do
    $game_switches[43] = true
    {
      "pbCallSomething(1)" => nil, "!pbSomething" => nil, "$player.difficulty_mode >= 1" => nil,
      "$game_switches[44] && !$game_player.bike_hops" => false, "$game_switches[43] && !$game_player.bike_hops" => nil,
      "pbSomething(2) && $game_switches[44]" => false, "$game_switches[43] || pbSomething(2)" => true,
      "pbSomething(2) || $game_switches[43]" => true, "$game_switches[44] || pbSomething(2)" => nil
    }.each { |src, want| assert_answer want, evaluate(src), src }
  end

  test "a condition outside the grammar is no answer" do
    $game_switches[43] = true
    ["$game_switches[43] &&", "$game_switches[43] ||", "$game_switches[44] &&", "(", "( $game_switches[43]", ")",
     "== 1", "3 >=", "", "   ", "$game_switches[43] $game_switches[44]", "\"a\" == \"a\"", "&& $game_switches[43])",
     "( $game_switches[43] $game_switches[44]", "( true ("].each do |src|
      assert_nil evaluate(src), src.inspect
    end
  end

  test "a held direction key is the facing walked" do
    { "UP" => 8, "DOWN" => 2, "LEFT" => 4, "RIGHT" => 6 }.each do |key, face|
      src = "Input.press?(Input::#{key})"
      assert_equal [true, false], [evaluate(src, :face => face), evaluate(src, :face => 10 - face)], src
    end
  end

  test "the player's place is where the walk stands them, unknown when the walk does not know it" do
    assert_equal true, evaluate("$game_player.x == 4 && $game_player.y > 6", :pos => [4, 7])
    assert_equal true, evaluate("get_character(-1).y == 7", :pos => [4, 7]), "as the interpreter's get_character(-1)"
    assert_nil evaluate("$game_player.x == 4")
    assert_nil evaluate("$game_player.x_offset == 4", :pos => [4, 7]), "a longer name only starts like it"
  end

  test "the event's own place is the interpreter's get_character(0), and no other character's is known" do
    assert_equal true, evaluate("get_character(0).x == 5 && get_character(0).y == 3", :self => [5, 3])
    assert_nil evaluate("get_character(0).x == 5"), "unknown when not given"
    assert_nil evaluate("get_character(4).x == 5", :self => [5, 3]), "another character"
  end

  test "the player faces the way walked and is never mid-step" do
    facing = "$game_player.direction == 6"
    assert_equal [true, false], [evaluate(facing, :face => 6), evaluate(facing)]
    assert_equal true, evaluate("!$game_player.moving?")
  end

  test "a script condition reads a variable by index or with pbGet, the walk's own answers first" do
    $game_variables[45] = 3
    assert_equal [true, true], [evaluate("pbGet(45) == 3"), evaluate("$game_variables[45] > 2")]
    assert_equal [true, true], [evaluate("$game_variables[45] == 0", :vars => { 45 => 0 }),
                                evaluate("pbGet( 45 ) == 0", :vars => { 45 => 0 })]
  end

  test "a script condition reads the map the walk is on and the maps the player has been to" do
    $game_map.map_id = 12
    assert_equal [true, false], [evaluate("$game_map.map_id == 12"), evaluate("$game_map.map_id == 13")]
    assert_nil evaluate("$PokemonGlobal.visitedMaps[12]"), "with no visits to read"
    with_visited(12 => true) do
      assert_equal [true, false], [evaluate("$PokemonGlobal.visitedMaps[12]"), evaluate("$PokemonGlobal.visitedMaps[13]")]
    end
  end

  test "with no bag the count of an item is not guessed" do
    with_bags(nil, nil) do
      assert_nil PokeAccess::Engine.bag_quantity(:POTION)
      assert_nil evaluate("$bag.has?(:POTION)")
      assert_equal false, evaluate("$game_switches[44] && $bag.has?(:POTION)"), "unless the rest settles it"
    end
  end

  test "a modern bag is counted with quantity" do
    modern = Object.new
    def modern.quantity(item); item == :POTION ? 2 : 0; end
    with_bags(modern, nil) do
      assert_equal 2, PokeAccess::Engine.bag_quantity(:POTION)
      assert_equal [true, false, true, false],
                   [evaluate("$bag.has?(:POTION)"), evaluate("$bag.has?(:ETHER)"), evaluate("$bag.quantity(:POTION) >= 2"),
                    evaluate("$bag.quantity(:POTION) > 2")]
    end
  end

  test "a gen-6 bag is counted with pbQuantity, through the gen-6 spellings too" do
    old = Object.new
    def old.pbQuantity(item); item == :POTION ? 3 : 0; end
    with_bags(nil, old) do
      assert_equal 3, PokeAccess::Engine.bag_quantity(:POTION)
      assert_equal [true, true, false],
                   [evaluate("$PokemonBag.pbQuantity(PBItems::POTION) > 2"), evaluate("$PokemonBag.pbHasItem?(:POTION)"),
                    evaluate("$PokemonBag.pbHasItem?(PBItems::ETHER)")]
    end
  end

  test "a question put to the player is answered by a walk that says yes, the condition going on after it" do
    $game_switches[43] = true
    {
      'pbConfirmMessage(_INTL("¿Seguro? (sí)"))' => true,
      'pbConfirmMessage(_INTL("¿Seguro?")) && $game_switches[44]' => false,
      'Kernel.pbConfirmMessage("a ) b") && $game_switches[43]' => true,
      'pbConfirmMessage("dice \"sí (o no\"")' => true,
      'pbShowCommands(nil, [_INTL("Sí"), _INTL("No")]) == 0' => true,
      'pbMessage(_INTL("¿Ir?"), [_INTL("Sí"), _INTL("No")]) == 1' => false,
      'pbConfirmMessage(_INTL("abierto")' => nil
    }.each { |src, want| assert_answer want, evaluate(src, :act => true), src }
    assert_nil evaluate('pbConfirmMessage(_INTL("¿Seguro?"))'), "a walk that does not answer has no answer"
  end

  test "a game's own call is answered by the reader it registers, the reading lasting until an event's end" do
    with_atom(/\Amy_own_check\b/, lambda { |_m, c| c[:face] == 8 }) do
      assert_equal [true, false], [evaluate("my_own_check", :face => 8), evaluate("my_own_check")]
      _v, deps = PokeAccess::World::Flags.reading { evaluate("my_own_check") }
      assert_equal [[:volatile]], deps.map { |k, _v| k }
    end
  end

  test "a game's own staircase test is read with where the event and the player stand" do
    with_royal_stairs do
      step = [TestCmd.new(111, [12, "escalera_pos_arriba(2)"]), World.move_player([6], 1), World.end_]
      {
        [6, 4] => [1, 1], [6, 3] => [1, 1], [6, 2] => nil, [5, 4] => nil
      }.each { |at, move| assert_answer move, walk(step, 6, at).move, "from #{at.inspect}" }
      tall = [TestCmd.new(111, [12, "escalera_pos_arriba(3)"]), World.move_player([6], 1), World.end_]
      assert_equal [1, 1], walk(tall, 6, [6, 2]).move, "three rows above on a stair of size 3"
    end
  end

  private

  # assert_equal, or assert_nil when the expected value is nil (minitest refuses assert_equal nil).
  def assert_answer(want, got, msg)
    want.nil? ? assert_nil(got, msg) : assert_equal(want, got, msg)
  end

  # A touch event at (5, 5) running list, placed on the map.
  def page(list, id = 90)
    World.touch(:id => id, :x => 5, :y => 5, :list => list)
  end

  # The outcome of touching a page running list with the player facing face (see EventPages.outcome).
  def walk(list, face, at = nil, act = false)
    EP.outcome(page(list), face, at, act)
  end

  # The net move of a Set Move Route on the player walking codes, from facing face.
  def moved(codes, face)
    walk([World.move_player(codes)], face).move
  end

  # A conditional branch on pars (the 111 command's parameters) that moves the player down, and its end.
  def branch(pars)
    [TestCmd.new(111, pars), World.move_player([1], 1), World.end_]
  end

  # Whether the branch on pars runs its move: nil when the walk cannot tell.
  def ran?(pars, face = 2)
    o = walk(branch(pars), face)
    o.unknown ? nil : !o.move.nil?
  end

  # ScriptCondition.evaluate in the context ctx, facing down unless it says.
  def evaluate(src, ctx = {})
    SC.evaluate(src, { :face => 2 }.merge(ctx))
  end

  # Runs the block with $data_common_events holding lists: { id => command list }.
  def with_common_events(lists)
    had = $data_common_events
    $data_common_events = Hash[lists.map { |id, list| [id, CommonEvent.new(list)] }]
    yield
  ensure
    $data_common_events = had
  end

  # Runs the block with $game_self_switches holding switches: { [map, event, letter] => on }.
  def with_self_switches(switches)
    had = $game_self_switches
    $game_self_switches = switches
    yield
  ensure
    $game_self_switches = had
  end

  # Runs the block with $PokemonGlobal.visitedMaps answering maps.
  def with_visited(maps)
    $PokemonGlobal.define_singleton_method(:visitedMaps) { maps }
    yield
  ensure
    $PokemonGlobal.singleton_class.send(:remove_method, :visitedMaps)
  end

  # Runs the block with $bag (the modern bag) and $PokemonBag (gen-6's) set.
  def with_bags(modern, old)
    had = [$bag, $PokemonBag]
    $bag = modern
    $PokemonBag = old
    yield
  ensure
    $bag, $PokemonBag = had
  end

  # Runs the block with a game's own script call registered as pattern, answered by reader, taking it back after.
  def with_atom(pattern, reader)
    had = (SC.instance_variable_get(:@extra) || []).dup
    SC.register_atom(pattern, &reader)
    yield
  ensure
    SC.instance_variable_set(:@extra, had)
  end

  # Runs the block with Royal's staircase tests registered from its profile file, as the loader reads it; the
  # profile list, the profile name and the registered calls are put back after.
  def with_royal_stairs
    game = PokeAccess::Game
    profiles = game.profiles.dup
    name = game.instance_variable_get(:@profile_name)
    extra = (SC.instance_variable_get(:@extra) || []).dup
    path = File.join(Harness::ROOT, "games", "royal_common", "stairs.rb")
    eval(Harness.source(path), TOPLEVEL_BINDING, path)
    yield
  ensure
    game.profiles.replace(profiles)
    game.instance_variable_set(:@profile_name, name)
    SC.instance_variable_set(:@extra, extra)
  end
end
