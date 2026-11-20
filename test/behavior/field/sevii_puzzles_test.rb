# Sevii's puzzles on the shipped profile: the prison cell and the Rattata chase of the Rocket HQ, the spin floors, the
# Lost Cave, the Regi chambers and the crystals of Meteor Falls. What a sighted player sees goes without the assist; the
# answer, with it.
class SeviiPuzzlesTest < PokeAccessTest
  def hq
    PokeAccess::SeviiRocketHq
  end

  test "the cell gives each step with the assist alone, in the order its switches open" do
    on_map(199)
    keyed do
      refute_includes info_key, "{sevii_cell_flush_hint}"
      PokeAccess::Config.puzzle_assist = true
      assert_includes info_key, "{sevii_cell_flush_hint}"
      $game_switches[81] = true
      assert_includes info_key, "{sevii_cell_nap_hint}"
      $game_switches[82] = true
      $game_switches[83] = true
      assert_includes info_key, "{sevii_cell_guard_hint}"
      $game_self_switches[[199, 5, "A"]] = true
      assert_includes info_key, "{sevii_cell_crack_hint}"
      refute_includes info_key, "{sevii_cell_guard_hint}"
    end
  end

  test "the chase says where the rat runs to by its corner" do
    on_map(328)
    $game_variables[58] = 1
    tick
    keyed do
      $game_variables[58] = 2
      assert_equal [["{sevii_rat}: {sevii_rat_top}", false]], tick
      $game_variables[58] = 10
      assert_equal [["{sevii_rat}: {sevii_rat_cornered}", false]], tick
    end
  end

  test "the chase plan corners the rat in ten tiles when EV23 sends it up, and goes on when it sends it down" do
    Harness.load_puzzles("sevii")
    assert_equal 7, hq::NEXT_TILE[[8, 5, true, true]]
    seen = []
    state = [1, 1, false, false]
    10.times do
      tile = hq::NEXT_TILE[state]
      seen.push(tile)
      r, p, a, b = state
      state = case tile
              when 5 then [2, 1, a, b]
              when 20 then p == 1 ? [3, 2, a, b] : [1, 2, a, b]
              when 12 then [6, 3, a, b]
              when 25 then [3, 6, true, b]
              when 13 then [2, 3, a, b]
              when 10 then b ? [10, 10, a, b] : [5, 1, a, true]
              when 23 then [2, 5, a, b]
              when 15 then [1, 2, a, b]
              else flunk("no plan for #{state.inspect}")
              end
    end
    assert_equal [5, 20, 12, 25, 13, 20, 10, 23, 15, 10], seen
    assert_equal 10, state[0]
  end

  test "the chase lists the next tile with the assist alone, and the catch once cornered" do
    on_map(328)
    hq::TILES.each { |id| place(id, id, 1, [TestCmd.new(0, [])]) }
    $game_variables[58] = 6
    $game_variables[59] = 3
    assert_equal :sevii_chase_tile_hint, hq.chase_hint
    keyed do
      refute_includes listed, "{sevii_chase_tile}"
      PokeAccess::Config.puzzle_assist = true
      assert_equal ["{sevii_chase_tile}"], listed.select { |n| n == "{sevii_chase_tile}" }
    end
    assert_equal 25, hq.next_tile
    $game_variables[58] = 10
    assert_equal :sevii_chase_catch_hint, hq.chase_hint
    assert_nil hq.next_tile
  end

  test "a spin turns at each arrow, rides over the walls in its way and stops on the stop tile" do
    Harness.load_puzzles("sevii")
    spin = PokeAccess::SeviiSpin
    on_map(202)
    $game_map.load_grid(["........", "....#...", "........", "......#.", "........", "........"])
    { [3, 1] => 22, [6, 1] => 21, [6, 4] => 23, [2, 4] => 24 }.each { |(x, y), tag| $game_map.set_terrain(x, y, tag) }
    assert $game_map.blocked?(4, 1), "a wall on the first leg"
    assert $game_map.blocked?(6, 3), "a wall on the second leg"
    assert_equal [2, 4], spin.spin(3, 1)
    $game_map.set_terrain(2, 4, 0)
    assert_equal false, spin.spin(3, 1), "a spin that leaves the map never stops"
  ensure
    $game_map.clear_grid
  end

  test "the free camera names each arrow of a spin floor with its way and its stop tile, on the floors alone" do
    on_map(202)
    { [3, 1] => 22, [6, 1] => 21, [2, 4] => 24 }.each { |(x, y), tag| $game_map.set_terrain(x, y, tag) }
    t = PokeAccess::I18n
    said = lambda { |x, y| PokeAccess::CameraText.parts(x, y) }
    assert_equal [[t.t(:sevii_spin_arrow, :dir => t.t(:dir_right))], [t.t(:sevii_spin_arrow, :dir => t.t(:dir_down))],
                  [t.t(:sevii_spin_stop)], []], [said[3, 1], said[6, 1], said[2, 4], said[4, 1]]
    on_map(1)
    assert_equal [], said[3, 1], "a map with no spin floor"
  ensure
    $game_map.clear_grid
  end

  test "the Lost Cave says the rocks drawn in the room, and the exit they point to with the assist" do
    on_map(105)
    cave = PokeAccess::SeviiLostCave
    assert_equal [:sevii_lost_rocks, { :n => 9 }], cave.arrival
    exit_west = place(2, 2, 6, [TestCmd.new(0, [])])
    keyed do
      assert_equal [:sevii_lost_hint, { :n => 9, :side => "{sevii_lost_west}" }], cave.hint
      assert_equal [:sevii_lost_exit, { :side => "{sevii_lost_west}" }], cave.exit_name(exit_west)
    end
    $game_map.map_id = 106
    assert_equal :sevii_lost_no_rocks, cave.arrival
    assert_equal :sevii_lost_dead_end, cave.hint
  end

  test "Registeel's next panel follows the book order and a wrong one asks to leave the room" do
    Harness.load_puzzles("sevii")
    regis = PokeAccess::SeviiRegis
    $game_variables[49] = 2
    $game_variables[50] = 2
    assert_equal 1, regis.next_panel
    $game_variables[49] = 3
    $game_variables[50] = 0
    assert_nil regis.next_panel
  end

  test "the crystals' hint gives the touches each one still needs, wrapping past 7" do
    Harness.load_puzzles("sevii")
    falls = PokeAccess::SeviiMeteorFalls
    falls::CRYSTALS.each_value { |var, _c, want| $game_variables[var] = want }
    assert_equal :sevii_crystals_set, falls.hint
    $game_variables[74] = 1
    $game_variables[77] = 2
    keyed do
      want = "{sevii_crystal_touches crystal={sevii_crystal_red} n=2}, {sevii_crystal_touches crystal={sevii_crystal_grey} n=6}"
      assert_equal [:sevii_crystals_hint, { :list => want }], falls.hint
    end
  end

  test "Fortree's plan picks the turn by the doors and the region the player walks in, whatever order turned them" do
    on_map(385)
    fortree = PokeAccess::SeviiFortree
    doors = lambda { |list| list.each_with_index { |v, i| $game_variables[63 + i] = v } }
    doors.call([0, 0, 0, 1, 0, 0, 0, 0])
    $game_player.x = 15
    $game_player.y = 25
    keyed { assert_equal [:sevii_fortree_hint, { :dir => "{sevii_dir_left}" }], fortree.hint }
    assert_equal [7, 4], fortree.next_turn
    doors.call([1, 0, 2, 1, 0, 1, 0, 1])
    $game_player.x = 9
    $game_player.y = 14
    assert_equal 10, fortree.next_turn[0]
    $game_player.x = 4
    $game_player.y = 9
    assert_equal [19, 8], fortree.next_turn
    keyed { assert_equal [:sevii_fortree_hint, { :dir => "{sevii_dir_up}" }], fortree.hint }
    doors.call([0, 0, 0, 0, 0, 0, 0, 0])
    $game_player.x = 15
    $game_player.y = 25
    assert_equal [7, 4], fortree.next_turn, "doors turned back past the entrance's state"
    assert fortree::TABLE.size > 13, "every reachable door state, not the twelve turns of one order"
    assert fortree::TABLE.values.flatten(1).none? { |row| row[1] == false }, "no state the gym can reach is a dead end"
    $game_variables[63] = 9
    assert_equal :sevii_fortree_off_plan, fortree.hint
  end

  test "Sootopolis gives the next ice tile from the tiles cracked and the one stood on, whatever way was taken" do
    on_map(284)
    soot = PokeAccess::SeviiSootopolis
    { 6 => [12, 22], 7 => [13, 22], 8 => [13, 21], 9 => [12, 21], 10 => [11, 21], 11 => [11, 20], 12 => [12, 20] }.each do |id, (x, y)|
      place(id, x, y, [TestCmd.new(0, [])])
    end
    crack = lambda do |ids, at|
      (6..12).each { |ev| $game_self_switches[[284, ev, "A"]] = ids.include?(ev) }
      $game_variables[55] = ids.length
      ev = $game_map.events[at]
      $game_player.x = ev.x
      $game_player.y = ev.y
    end
    $game_player.x = 12
    $game_player.y = 23
    assert_equal 6, soot.next_tile
    crack.call([6, 7], 7)
    assert_equal 8, soot.next_tile
    assert_equal :sevii_soot_hint, soot.hint
    crack.call([6, 7, 8, 9, 12], 12)
    assert_equal 11, soot.next_tile, "the other order round the field"
    crack.call([6, 9], 9)
    assert_nil soot.next_tile, "up from the start, the tiles on the right can no longer all be crossed"
    assert_equal :sevii_soot_off_path, soot.hint
    (6..12).each { |ev| $game_self_switches[[284, ev, "B"]] = true }
    $game_variables[55] = 7
    assert_equal 13, soot.next_tile
  end

  test "the Altering Cave hint gives the next push of the plan, then the press into the hole" do
    on_map(256)
    cave = PokeAccess::SeviiAlteringCave
    $game_variables[53] = 2
    rock = place(10, 22, 29, [TestCmd.new(0, [])])
    other = place(11, 24, 28, [TestCmd.new(0, [])])
    keyed do
      assert_equal [:sevii_altering_push, { :side => "{sevii_side_above}", :dir => "{sevii_dir_down}", :n => 1 }], cave.lower_hint
      rock.y = 30
      assert_equal [:sevii_altering_press, { :dir => "{sevii_dir_left}" }], cave.lower_hint
      $game_self_switches[[256, 8, "A"]] = true
      $game_self_switches[[256, 10, "A"]] = true
      other.y = 20
      assert_equal [:sevii_altering_push, { :side => "{sevii_side_below}", :dir => "{sevii_dir_up}", :n => 3 }], cave.lower_hint
    end
    other.x = 30
    assert_equal :sevii_altering_off_plan, cave.lower_hint
  end

  # Runs the block with I18n.t answering each key and its values as "{key name=value ...}", so what the puzzles say is
  # compared by its keys and values rather than by the text of a language.
  def keyed
    i18n = PokeAccess::I18n.singleton_class
    i18n.send(:alias_method, :sevii_kept_t, :t)
    i18n.send(:define_method, :t) do |key, vars = nil|
      parts = [key.to_s] + (vars || {}).map { |k, v| "#{k}=#{v}" }.sort
      "{#{parts.join(' ')}}"
    end
    yield
  ensure
    i18n.send(:alias_method, :t, :sevii_kept_t)
    i18n.send(:remove_method, :sevii_kept_t)
  end

  def on_map(map)
    Harness.load_puzzles("sevii")
    PokeAccess::Config.puzzle_assist = false
    $game_map.map_id = map
    [81, 82, 83, 84, 139, 140, 122].each { |s| $game_switches[s] = false }
    [58, 59].each { |v| $game_variables[v] = 0 }
    $game_self_switches = {}
    $game_player.x = 1
    $game_player.y = 1
    World.next_frame
  end

  def place(id, x, y, list, sprite = "")
    page = TestPage.new(:trigger => 0, :sprite => sprite, :list => list)
    ev = TestGameEvent.new(:id => id, :x => x, :y => y, :pages => [page], :active_page => page)
    $game_map.events[id] = ev
    World.next_frame
    ev
  end

  def listed
    PokeAccess::Puzzles.category_targets.map { |tg| tg.name }.sort
  end

  def tick
    SpeakCapture.clear
    PokeAccess::Puzzles.tick
    SpeakCapture.log.dup
  end

  def info_key
    PokeAccess::Info.map_text
  end
end
