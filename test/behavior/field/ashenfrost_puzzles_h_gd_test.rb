# Pokemon Ashen Frost's puzzles of part H (games/ashenfrost/puzzles/): the ice tiles stepped on once, the prison's coloured
# spikes, the haunted penthouse, Monty's apartment, the landlady's smells, the Flores piano and library, the spikes of the
# Amontillado Factory and the City Square Sewers, and the words the passCheck entries ask for. Without the assist, what the
# screen shows; with it, the way. I18n.t answers by key and values, so each line is checked by both.
class AshenfrostPuzzlesHTest < PokeAccessTest
  SWITCHES = [71, 260, 261, 326, 327, 328, 329]
  VARIABLES = [37, 59, 144, 170, 186, 229]

  def setup
    super
    keyed
    declare
    @at = [$game_player.x, $game_player.y]
    @map = $game_map.map_id
    @selfs = $game_self_switches
  end

  def teardown
    World.clear_events
    SWITCHES.each { |s| $game_switches[s] = false }
    VARIABLES.each { |v| $game_variables[v] = 0 }
    $game_self_switches = @selfs
    $game_player.x, $game_player.y = @at
    $game_map.map_id = @map
    PokeAccess::Config.puzzle_assist = false
    PokeAccess::Puzzles::Answers.forget
    PokeAccess::World::Mechanics.forget
    PokeAccess::Caches.reset_all
    unkeyed
    super
  end

  test "every order of the ice rooms steps on each tile once, from a tile beside the way in" do
    PokeAccess::AshenIceTiles::ROOMS.each do |map, room|
      room[:orders].each do |order|
        assert_equal room[:total], order.uniq.size, "map #{map}: one step on each tile"
        assert_equal room[:ids].size, order.size, "map #{map}"
      end
    end
    cave = PokeAccess::AshenIceTiles::ROOMS[559][:orders]
    assert cave.all? { |o| o.each_cons(2).all? { |a, b| (a[0] - b[0]).abs + (a[1] - b[1]).abs == 1 } }
    assert_equal [[8, 14], [10, 14], [12, 14], [14, 14]], cave.map { |o| o[0] }, "the row above the cave's floor"
    tunnel = PokeAccess::AshenIceTiles::ROOMS[581][:orders][0]
    gaps = tunnel.each_cons(2).reject { |a, b| (a[0] - b[0]).abs + (a[1] - b[1]).abs == 1 }
    assert_equal [[[12, 39], [13, 38]]], gaps, "the one walk off the ice, by the floor at (13,39)"
  end

  test "the cave's ice says its rule by the tiles, and the assist follows the order the cracked tiles begin" do
    ice = PokeAccess::AshenIceTiles
    on_map(559) { ice::ROOMS[559][:orders][0].each_with_index { |(x, y), i| place(i + 1, x, y, [TestCmd.new(0, [])], :trigger => 1) } }
    player_at(8, 18)
    refute_includes tick, key_line(:afh_ice_rule)
    player_at(12, 16)
    assert_includes tick, key_line(:afh_ice_rule), "as the player comes up to the tiles"
    assert_equal [8, 14], ice.next_tile(559)
    crack(1)
    assert_equal [8, 13], ice.next_tile(559)
    crack(6)
    assert_nil ice.next_tile(559), "a tile out of every order"
    assert_equal :afh_ice_restart, ice.hint(559)
    $game_self_switches = {}
    crack(29)
    assert_equal [9, 14], ice.next_tile(559), "the order that starts at (10,14)"
    PokeAccess::Config.puzzle_assist = true
    player_at(10, 15)
    assert_includes info_key, key_line(:afh_ice_next, :place => PokeAccess::Puzzles.offset_phrase(-1, -1))
    $game_variables[170] = 38
    assert ice.done?(559)
    refute_includes info_key, key_line(:afh_ice_rule)
  end

  test "the prison's switches are named by colour, and the assist reads the option toward red and blue down" do
    prison = PokeAccess::AshenPrison
    on_map(746) do
      place(71, 13, 26, text, :name => "Red Switch")
      place(12, 3, 35, text, :name => "Red Spikes")
      place(81, 35, 48, text, :name => "Final Switch")
    end
    assert_equal key_line(:afh_prison_switch_red), PokeAccess::Puzzles.piece_name($game_map.events[71])
    assert_equal key_line(:afh_prison_final), PokeAccess::Puzzles.piece_name($game_map.events[81])
    assert_equal key_line(:afh_prison_spikes_red_up), PokeAccess::Puzzles.piece_name($game_map.events[12])
    assert_equal({ :switch => 326, :to => true }, prison.right_branch, "red first")
    $game_switches[326] = true
    assert_equal key_line(:afh_prison_spikes_red_down), PokeAccess::Puzzles.piece_name($game_map.events[12])
    assert_equal({ :switch => 328, :to => true }, prison.right_branch, "then blue, with green up")
    $game_switches[327] = true
    $game_switches[328] = true
    refute prison.open?, "green down closes the column"
    $game_switches[327] = false
    assert prison.open?
    assert_nil prison.right_branch
    PokeAccess::Config.puzzle_assist = true
    tick
    assert_includes info_key, key_line(:afh_prison_hint_open)
    assert_includes tick { $game_switches[327] = true }, key_line(:afh_prison_hint), "green down closes the column again"
    assert_includes tick { $game_switches[327] = false }, key_line(:afh_prison_hint_open), "and green up opens it"
    $game_switches[329] = true
    assert prison.done?
  end

  test "the tunnel's ice says both moves of its one step off the ice, in their order, until the player stands on the floor" do
    order = PokeAccess::AshenIceTiles::ROOMS[581][:orders][0]
    on_map(581) { order.each_with_index { |(x, y), i| place(10 + i, x, y, [TestCmd.new(0, [])], :trigger => 1) } }
    (0..order.index([12, 39])).each { |i| crack(10 + i) }
    PokeAccess::Config.puzzle_assist = true
    player_at(12, 39)
    step = PokeAccess::Puzzles
    assert_includes info_key, key_line(:afh_ice_via, :first => step.offset_phrase(1, 0), :then => step.offset_phrase(0, -1))
    player_at(13, 39)
    assert_includes info_key, key_line(:afh_ice_next, :place => step.offset_phrase(0, -1))
  end

  test "the penthouse names the haunted object with the assist alone, on its map and at its count" do
    on_map(94) do
      place(3, 17, 7, text, :name => "Book")
      place(4, 4, 6, text, :name => "Present")
    end
    $game_variables[37] = 2
    refute_includes listed.map { |_x, _y, name| name }, key_line(:afh_ghost_haunted)
    PokeAccess::Config.puzzle_assist = true
    assert_includes listed, [17, 7, key_line(:afh_ghost_haunted)]
    refute_includes listed, [4, 6, key_line(:afh_ghost_haunted)]
    assert_includes info_key, key_line(:afh_ghost_book_small)
    $game_variables[37] = 4
    assert_includes listed, [4, 6, key_line(:afh_ghost_haunted)]
    assert_includes info_key, key_line(:afh_ghost_present)
    $game_map.map_id = 93
    refute_includes listed, [4, 6, key_line(:afh_ghost_haunted)], "event 4 of the hall is another event"
    $game_variables[37] = 6
    assert_nil PokeAccess::AshenPenthouse.hint
  end

  test "Monty's apartment counts what was looked at with the assist, held at seven, and lists the bin with it" do
    on_map(214) do
      place(3, 8, 11, text, :name => "HiddenItem")
      place(4, 13, 1, text, :name => "Board")
    end
    assert_equal key_line(:afh_monty_board), PokeAccess::Puzzles.piece_name($game_map.events[4])
    refute_includes listed, [8, 11, key_line(:afh_monty_bin)]
    PokeAccess::Config.puzzle_assist = true
    assert_includes listed, [8, 11, key_line(:afh_monty_bin)]
    $game_self_switches[[214, 3, "A"]] = true
    refute_includes listed, [8, 11, key_line(:afh_monty_bin)]
    $game_variables[59] = 8
    assert_equal 7, PokeAccess::AshenMonty.seen
  end

  test "the landlady's smells are named by colour while Truffles plays, and the assist points at the cup" do
    on_map(212) { place(11, 2, 27, text, :name => "HiddenItem", :sprite => "HiddenItem_Smell_Red") }
    assert_nil PokeAccess::AshenRealEstate.label($game_map.events[11])
    $game_switches[71] = true
    assert_equal :afh_scent_red, PokeAccess::AshenRealEstate.label($game_map.events[11])
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, key_line(:afh_scent_hint)
    $game_self_switches[[212, 11, "A"]] = true
    refute_includes info_key.to_s, key_line(:afh_scent_hint)
  end

  test "the Flores piano leaves song six, the green book's, to the ocarina, and the library says how to face each Rotom" do
    on_map(651) do
      place(15, 44, 5, [TestCmd.new(102, [["Try song.", "Nope!"], 2]), TestCmd.new(0, [])], :name => "Piano")
      place(3, 41, 6, text, :name => "Orange Book")
      place(4, 49, 6, text, :name => "Green Book")
    end
    assert_equal key_line(:afh_book_yellow), PokeAccess::Puzzles.piece_name($game_map.events[3])
    assert_equal key_line(:afh_book_green), PokeAccess::Puzzles.piece_name($game_map.events[4])
    assert_equal [], tick { fire($game_map.events[15]) }
    PokeAccess::Config.puzzle_assist = true
    assert_equal [], tick { fire($game_map.events[15]) }, "assist_answers.rb says the melody as the ocarina opens"
    $game_variables[229] = 2
    assert_includes info_key, key_line(:afh_rotom_from_right)
    $game_variables[229] = 4
    assert_includes info_key, key_line(:afh_rotom_from_above)
    $game_switches[261] = true
    refute_includes info_key.to_s, key_line(:afh_rotom_from_above)
  end

  test "the factory's ground floor and the City Square Sewers name their switches, and each spike as it stands" do
    on_map(561) { [20, 21, 22, 23, 24].each { |id| place(id, id, 16, text) } }
    named = lambda { |id| PokeAccess::Puzzles.piece_name($game_map.events[id]) }
    assert_equal [key_line(:afh_switch)] * 2, [20, 22].map { |id| named.call(id) }
    assert_equal [key_line(:afh_spikes)] * 3, [21, 23, 24].map { |id| named.call(id) }
    $game_self_switches[[561, 21, "A"]] = true
    assert_equal key_line(:afh_spikes_down), named.call(21)
    assert_equal key_line(:afh_spikes), named.call(23)
    on_map(786) { (10..13).each { |id| place(id, id == 13 ? 9 : 11, id == 13 ? 10 : id + 2, text) } }
    assert_equal key_line(:afh_switch), named.call(13)
    assert_equal [key_line(:afh_spikes)] * 3, (10..12).map { |id| named.call(id) }
    (10..12).each { |id| $game_self_switches[[786, id, "A"]] = true }
    assert_equal [key_line(:afh_spikes_down)] * 3, (10..12).map { |id| named.call(id) }
  end

  test "the people of Northallow, Spadina's, Beacon Alleyway and the Mossy Monument leave their passCheck word to the entry" do
    PokeAccess::Config.puzzle_assist = true
    [[711, 17], [194, 16], [608, 26], [793, 5]].each do |map, id|
      on_map(map) { place(id, 10, 10, [TestCmd.new(101, ["..."]), TestCmd.new(0, [])]) }
      assert_equal [], tick { fire($game_map.events[id]) }, "map #{map}: assist_answers.rb says it as the entry opens"
    end
  end

  # An i18n key and its values as the keyed I18n.t answers them: "{key name=value ...}", the names sorted.
  def key_line(key, vars = nil)
    parts = [key.to_s] + (vars || {}).map { |k, v| "#{k}=#{v}" }.sort
    "{#{parts.join(' ')}}"
  end

  # Makes I18n.t answer as key_line, so what the puzzles say is compared by its keys and values, not a language's text.
  def keyed
    i18n = PokeAccess::I18n.singleton_class
    i18n.send(:alias_method, :afh_kept_t, :t)
    i18n.send(:define_method, :t) do |key, vars = nil|
      parts = [key.to_s] + (vars || {}).map { |k, v| "#{k}=#{v}" }.sort
      "{#{parts.join(' ')}}"
    end
  end

  # Gives I18n.t back its own body.
  def unkeyed
    i18n = PokeAccess::I18n.singleton_class
    i18n.send(:alias_method, :t, :afh_kept_t)
    i18n.send(:remove_method, :afh_kept_t)
  end

  def declare
    was = $VERBOSE
    $VERBOSE = nil
    Harness.load_puzzles("ashenfrost")
  ensure
    $VERBOSE = was
  end

  def on_map(map)
    declare
    PokeAccess::Config.puzzle_assist = false
    World.clear_events
    SWITCHES.each { |s| $game_switches[s] = false }
    VARIABLES.each { |v| $game_variables[v] = 0 }
    $game_self_switches = {}
    PokeAccess::Puzzles::Auto.forget
    $game_map.map_id = map
    PokeAccess::Caches.reset_all
    PokeAccess::World::Mechanics.forget
    yield if block_given?
    World.next_frame
  end

  def place(id, x, y, list, opts = {})
    page = TestPage.new(:trigger => opts.fetch(:trigger, 0), :sprite => opts.fetch(:sprite, ""), :list => list)
    ev = TestGameEvent.new(:id => id, :x => x, :y => y, :pages => [page], :active_page => page,
                           :name => opts.fetch(:name, "EV#{id}"))
    $game_map.events[id] = ev
    World.next_frame
    ev
  end

  def text
    [TestCmd.new(101, ["..."]), TestCmd.new(0, [])]
  end

  def crack(id)
    $game_self_switches[[$game_map.map_id, id, "A"]] = true
  end

  def player_at(x, y)
    $game_player.x = x
    $game_player.y = y
  end

  def tick
    SpeakCapture.clear
    yield if block_given?
    PokeAccess::Puzzles.tick
    SpeakCapture.log.dup.map { |line| line[0] }
  end

  def info_key
    PokeAccess::Info.map_text
  end

  def fire(ev)
    PokeAccess::Puzzles::Auto.fired($game_system.map_interpreter, PokeAccess.ivar(ev, :@list), ev.id)
  end

  def listed
    PokeAccess::Puzzles.category_targets.map { |tg| [tg.x, tg.y, tg.name] }
  end
end
