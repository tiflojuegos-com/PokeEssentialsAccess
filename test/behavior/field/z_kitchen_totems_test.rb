# Pokemon Z's Bastión-Cocina (map 115) and the Bosque Errante's totems on the shipped profile: the kitchen's chart, box and
# pot listed room by room, with the recipe's answer for the assist alone; the totems listed until touched and counted aloud,
# their events having no graphic, name or text.
class ZKitchenTotemsTest < PokeAccessTest
  KITCHEN = 115
  { :CHERIBERRY => 201, :ORANBERRY => 202, :CHESTOBERRY => 203, :SITRUSBERRY => 204, :LUMBERRY => 205 }.each do |name, id|
    PBItems.const_set(name, id) unless PBItems.const_defined?(name)
  end
  CHERI = "Item201"
  ORAN = "Item202"
  CHESTO = "Item203"
  SITRUS = "Item204"
  LUM = "Item205"

  test "lists each room's chart, box and pot as its turn comes, and none once the menu is cooked" do
    { [] => [[5, 4], [26, 9], [8, 6]], [198] => [[49, 5], [47, 21], [52, 7]], [198, 199] => [[15, 47], [5, 47], [20, 35]] }.each do |on, at|
      in_kitchen(on)
      assert_equal [spot(at[0], :z_kitchen_chart), spot(at[1], :z_kitchen_box), spot(at[2], :z_kitchen_pot)],
                   PokeAccess::Puzzles.category_targets, "switches #{on.inspect}"
    end
    in_kitchen([198, 199, 201])
    assert_empty PokeAccess::Puzzles.category_targets
    refute PokeAccess::Puzzles.active?
  end

  test "says on the info key the dish and, once one is taken, the berries in hand; nothing over the game's own lines" do
    in_kitchen([198])
    tick
    assert_equal t(:z_kitchen_dish, :n => 2), info_key
    $game_variables[96] = 1
    assert_equal [], tick
    assert_equal "#{t(:z_kitchen_dish, :n => 2)}. #{t(:puzzle_progress, :label => t(:z_kitchen_berries), :n => 1, :of => 2)}", info_key
    $game_switches[199] = true
    assert_equal [], tick, "a new room's dish opens quietly"
  end

  test "gives each recipe's right berries by the game's own names, to the assist alone" do
    answers = { [] => [[CHERI, SITRUS], [ORAN, CHESTO], [ORAN, SITRUS]],
                [198] => [[CHERI, CHESTO], [ORAN, SITRUS], [CHERI, SITRUS]],
                [198, 199] => [[ORAN, LUM], [SITRUS, LUM], [CHERI, LUM]] }
    answers.each do |on, pairs|
      pairs.each_with_index do |(a, b), recipe|
        in_kitchen(on)
        $game_variables[98] = recipe
        hint = t(:z_kitchen_hint, :a => a, :b => b)
        refute_includes info_key, hint
        PokeAccess::Config.puzzle_assist = true
        assert_includes info_key, hint, "room #{on.inspect}, recipe #{recipe}"
      end
    end
  end

  test "lists a map's totems still to touch, and only them" do
    in_forest(32)
    place(9, 14, 14, [TestCmd.new(122, [])])
    place(10, 16, 15, [TestCmd.new(0, [])])
    place(11, 17, 14, [TestCmd.new(122, [])])
    assert_equal [totem(9, 14, 14), totem(11, 17, 14)], PokeAccess::Puzzles.category_targets
  end

  test "lists the totems of every map the forest has them on, fifteen in all" do
    maps = { 32 => [9, 10, 11], 353 => [11, 12, 13], 365 => [9], 366 => [12, 13, 14], 368 => [16, 17, 18], 371 => [14, 15] }
    assert_equal 15, maps.values.flatten.length
    maps.each do |map, ids|
      in_forest(map)
      ids.each_with_index { |id, i| place(id, i, 1, [TestCmd.new(122, [])]) }
      assert_equal ids.each_with_index.map { |id, i| totem(id, i, 1) }, PokeAccess::Puzzles.category_targets, "map #{map}"
    end
  end

  test "says the count as a totem wakes, on the info key once one has, and stops at the fifteenth" do
    in_forest(32)
    tick
    assert_equal "", PokeAccess::Puzzles.info_line.to_s, "no count before the first"
    $game_variables[220] = 1
    assert_equal [[count(1), false]], tick
    assert_equal count(1), info_key
    $game_variables[220] = 15
    assert_equal [], tick, "the game's own line says the last"
    assert_empty PokeAccess::Puzzles.category_targets
  end

  private

  # The spoken text of an i18n key.
  def t(key, vars = {})
    PokeAccess::I18n.t(key, vars)
  end

  # Declares the shipped puzzles as the harness loads the profile.
  def load_profile
    Harness.load_puzzles("pokemon_z")
    PokeAccess::Config.puzzle_assist = false
  end

  # The player in the kitchen with the room switches in on turned on, its events in place, no berry in hand.
  def in_kitchen(on)
    load_profile
    $game_map.map_id = KITCHEN
    [198, 199, 201].each { |s| $game_switches[s] = on.include?(s) }
    $game_variables[96] = 0
    $game_variables[98] = 0
    { 28 => [26, 9], 31 => [8, 6], 33 => [47, 21], 36 => [52, 7], 39 => [5, 47], 40 => [20, 35] }.each do |id, at|
      place(id, at[0], at[1], [TestCmd.new(101, ["!"])])
    end
    World.next_frame
  end

  # The player on a forest map, no totem touched yet.
  def in_forest(map)
    load_profile
    $game_map.map_id = map
    $game_variables[220] = 0
    World.next_frame
  end

  # An event at (x, y) whose live page runs list, placed on the map.
  def place(id, x, y, list)
    page = TestPage.new(:trigger => 0, :sprite => "", :list => list)
    ev = TestGameEvent.new(:id => id, :x => x, :y => y, :pages => [page], :active_page => page)
    $game_map.events[id] = ev
    World.next_frame
    ev
  end

  # A named point, as the locator lists it.
  def spot(at, key)
    PokeAccess::Locator::SurfaceTarget.new(at[0], at[1], t(key), :puzzle_spot, nil)
  end

  # A totem still to touch, as the locator lists it.
  def totem(id, x, y)
    PokeAccess::Locator::SurfaceTarget.new(x, y, t(:z_forest_totem), :puzzle_hidden, id)
  end

  # The totem count at n, as said.
  def count(n)
    t(:puzzle_progress, :label => t(:z_forest_totems), :n => n, :of => 15)
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
