# Pokemon Z's puzzles from the review on the shipped profile: the hidden books of the old library (map 39), the dark maze
# of the second gym (69), the type tiles of the first (20), the thresholds of the sixth (146), the Ditto of Le Chonk (116),
# Regirock's stone (303) and the platform of Fort Leviatán (125). What a sighted player sees goes without the assist, the
# way on with it.
class PokemonZRepasoTest < PokeAccessTest
  TYPES = { :POISON => 3, :WATER => 11, :FLYING => 2, :BUG => 6, :ROCK => 5, :PSYCHIC => 14, :GHOST => 7,
            :DRAGON => 16, :FAIRY => 18 }

  test "the library's books are named and listed by their room only while the lens shows them, and said as pushed" do
    library
    assert_empty targets, "drawn only through the lens"
    assert_equal t(:loc_lens), PokeAccess::Locator.target_name($game_map.events[55])
    assert_nil PokeAccess::Puzzles.info_line
    with_lens do
      assert_empty targets, "the lens too far from every book"
      stand(5, 9)
      assert_equal [[55, t(:z_library_book_west)]], named(targets)
      assert_equal t(:z_library_book_west), PokeAccess::Locator.target_name($game_map.events[55])
      stand(35, 7)
      assert_equal [[56, t(:z_library_book_centre)]], named(targets)
      assert_nil PokeAccess::Puzzles.info_line
    end
    tick
    $game_switches[102] = true
    assert_equal [["#{t(:z_library_book_centre)}: #{t(:z_arma_book_pushed)}", false]], tick
  end

  test "with the assist, the library lists every book, and its hint counts the books still to push, then the door" do
    library
    assist_on
    assert_equal [55, 56, 57], targets.map { |s| s.ref }
    still = t(:z_arma_book_still)
    assert_includes info_key, "#{t(:z_library_book_west)}: #{still}. #{t(:z_library_book_centre)}: #{still}. " \
                              "#{t(:z_library_book_ne)}: #{still}"
    $game_switches[101] = true
    places = [t(:z_library_at_centre), t(:z_library_at_ne)].join("; ")
    assert_includes info_key, t(:z_library_books_hint, :n => 2, :books => places)
    $game_switches[102] = true
    assert_includes info_key, t(:z_library_books_hint, :n => 1, :books => t(:z_library_at_ne))
    [103, 104].each { |s| $game_switches[s] = true }
    assert_includes info_key, t(:z_library_door)
  end

  test "the library leaves the info key once the player is past the door or on the next map's scene" do
    library
    assist_on
    [101, 102, 103, 104].each { |s| $game_switches[s] = true }
    stand(73, 28)
    refute PokeAccess::Puzzles.active?, "in the room past the door"
    stand(41, 7)
    assert PokeAccess::Puzzles.active?
    $game_variables[75] = 1
    refute PokeAccess::Puzzles.active?
  end

  test "the dark gym says the corridor on to the lift from each room on the way, with the assist alone" do
    on_map(69)
    $game_switches[94] = false
    [[4, 35, 70], [52, 39, 61], [17, 50, 58], [18, 35, 32], [3, 5, 21]].each do |id, x, y|
      place(id, x, y, [TestCmd.new(111, [6, -1, 8]), TestCmd.new(0, [])], :trigger => 1)
    end
    stand(35, 80)
    assert_equal [[t(:z_gym2_rule), false]], tick, "the rule on arriving, with no assist"
    assert_equal [], tick
    assert_empty targets
    assist_on
    stand(35, 67)
    assert_equal [], tick, "a corridor between rooms"
    { [35, 80] => [:z_gym2_up, 4, 35, 70], [35, 61] => [:z_gym2_right, 52, 39, 61],
      [50, 61] => [:z_gym2_tunnel, 17, 50, 58], [35, 35] => [:z_gym2_tunnel, 18, 35, 32],
      [5, 22] => [:z_gym2_lift, 3, 5, 21] }.each do |(x, y), (key, id, ex, ey)|
      stand(x, y)
      assert_equal [[t(key), false]], tick, "standing on #{x},#{y}"
      assert_equal [hidden(id, ex, ey, :puzzle_right_way)], targets, "standing on #{x},#{y}"
    end
  end

  test "the dark gym says nothing of the rooms a tunnel carries the player across, and the room it lands in" do
    on_map(69)
    $game_switches[94] = false
    place(45, 31, 9, [TestCmd.new(111, [6, -1, 4]), TestCmd.new(0, [])], :trigger => 1)
    assist_on
    stand(35, 35)
    tick
    carried do
      stand(35, 22)
      assert_equal [], tick, "crossing the room the tunnel passes"
      stand(35, 11)
      assert_equal [], tick
    end
    assert_equal [[t(:z_gym2_left), false]], tick
  end

  test "the dark gym goes quiet once the lift has been taken" do
    on_map(69)
    assist_on
    stand(35, 80)
    tick
    $game_switches[94] = true
    stand(50, 61)
    assert_equal [], tick
    assert_nil PokeAccess::Puzzles.info_line
  ensure
    $game_switches[94] = false
  end

  test "names the first gym's tiles by the game's type while their musketeer waits, the right one with the assist" do
    with_types do
      on_map(20)
      [[11, 6], [13, 9], [12, 12]].each { |id, x| place(id, x, 24, [TestCmd.new(101, ["?"])], :trigger => 1) }
      [84, 85, 86].each { |s| $game_switches[s] = false }
      World.next_frame
      want = [[11, tile(:z_gym1_tile, :POISON)], [13, tile(:z_gym1_tile, :FLYING)], [12, tile(:z_gym1_tile, :WATER)]]
      assert_equal want, named(targets)
      assist_on
      assert_equal tile(:z_gym1_tile_right, :FLYING), PokeAccess::Locator.target_name($game_map.events[13])
      assert_equal tile(:z_gym1_tile, :WATER), PokeAccess::Locator.target_name($game_map.events[12])
      $game_switches[84] = true
      assert_empty targets, "the musketeer has fought"
    end
  ensure
    $game_switches[84] = false
  end

  test "names the sixth gym's thresholds by their side" do
    on_map(146)
    [[5, 29, 43], [12, 35, 41], [14, 41, 43], [11, 56, 27]].each do |id, x, y|
      place(id, x, y, [TestCmd.new(201, [0, 146, 35, 51])], :trigger => 1)
    end
    { 5 => :z_gym6_left, 12 => :z_gym6_centre, 14 => :z_gym6_right, 11 => :z_gym6_left }.each do |id, key|
      assert_equal t(key), PokeAccess::Locator.target_name($game_map.events[id]), "event #{id}"
    end
  end

  test "the Ditto of Le Chonk goes by the diners' name until asked for, then as the odd one, the impostor with the assist" do
    on_map(116)
    place(14, 48, 12, [TestCmd.new(101, ["!"])], :sprite => "burguesow")
    ditto = place(32, 24, 18, [TestCmd.new(101, ["..."])], :sprite => "burguesDitto")
    $game_switches[261] = false
    $game_variables[125] = 0
    diner = PokeAccess::Locator.target_name($game_map.events[14])
    assert_equal diner, PokeAccess::Locator.target_name(ditto)
    assert_empty targets
    assist_on
    assert_equal diner, PokeAccess::Locator.target_name(ditto), "not asked for yet"
    PokeAccess::Config.puzzle_assist = false
    $game_switches[261] = true
    assert_equal t(:z_chonk_odd), PokeAccess::Locator.target_name(ditto)
    assert_equal [[32, t(:z_chonk_odd)]], named(targets)
    assist_on
    assert_equal t(:z_chonk_ditto), PokeAccess::Locator.target_name(ditto)
    assert_equal [[32, t(:z_chonk_ditto)]], named(targets)
    $game_variables[125] = 1
    assert_equal diner, PokeAccess::Locator.target_name(ditto), "unmasked"
    assert_empty targets
  ensure
    $game_switches[261] = false
    $game_variables[125] = 0
  end

  test "Regirock's stone is named, and with the assist the info key in its room says to press it" do
    on_map(303)
    place(48, 82, 16, [TestCmd.new(121, [564, 564, 0])])
    $game_switches[564] = false
    World.next_frame
    assert_equal t(:z_regirock_stone), PokeAccess::Locator.target_name($game_map.events[48])
    stand(80, 15)
    assert_nil PokeAccess::Puzzles.info_line
    assist_on
    assert_includes info_key, t(:z_regirock_hint)
    stand(20, 40)
    assert_nil PokeAccess::Puzzles.info_line, "elsewhere in the cave"
    stand(80, 15)
    $game_switches[564] = true
    assert_nil PokeAccess::Puzzles.info_line
  ensure
    $game_switches[564] = false
  end

  test "Fort Leviatán lists the platform while the lens opens its false wall, and with the assist that it takes the lens" do
    on_map(125)
    [[29, 5, 46], [30, 6, 46], [31, 7, 46], [32, 7, 47], [33, 6, 47], [34, 5, 47], [35, 5, 45], [36, 6, 45],
     [37, 7, 45]].each { |id, x, y| place(id, x, y, [], :name => "#EOT HIDE") }
    stand(6, 49)
    assert_empty targets, "a wall to the eye"
    assert_equal [false] * 9, (29..37).map { |id| PokeAccess::Locator.hidden?($game_map.events[id]) }
    with_lens { assert_equal [spot(6, 46, :z_fort_platform)], targets }
    stand(6, 52)
    with_lens { assert_empty targets, "the false wall out of the lens's reach" }
    assist_on
    lens = t(:z_fort_platform_lens, :item => PokeAccess::World::Lens.item_name)
    assert_equal [PokeAccess::Locator::SurfaceTarget.new(6, 46, lens, :puzzle_cell, nil)], targets
    stand(6, 49)
    with_lens { assert_equal [spot(6, 46, :z_fort_platform)], targets }
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
    World.next_frame
  end

  # Map 39 with its three book events and the tiles the lens shows above them, nothing pushed, the player in the west room.
  def library
    on_map(39)
    [[55, 5, 8, 101], [56, 35, 5, 102], [57, 72, 5, 103]].each do |id, x, y, switch|
      place(id, x, y, [TestCmd.new(121, [switch, switch, 0])], :name => "#EOT SHOW")
    end
    [[54, 5, 7], [41, 35, 4], [53, 72, 4]].each { |id, x, y| place(id, x, y, [], :name => "#EOT SHOW") }
    [101, 102, 103, 104].each { |s| $game_switches[s] = false }
    $game_variables[75] = 0
    stand(10, 15)
  end

  # The puzzle assist on.
  def assist_on
    PokeAccess::Config.puzzle_assist = true
  end

  # The player moved to (x, y), as a warp would.
  def stand(x, y)
    $game_player.x = x
    $game_player.y = y
    World.next_frame
  end

  # An event at (x, y) whose live page runs list, placed on the map: opts take its :sprite, :name and :trigger.
  def place(id, x, y, list, opts = {})
    page = TestPage.new(:trigger => opts.fetch(:trigger, 0), :sprite => opts.fetch(:sprite, ""), :list => list)
    ev = TestGameEvent.new(:id => id, :x => x, :y => y, :pages => [page], :active_page => page,
                           :name => opts.fetch(:name, "EV#{id}"))
    $game_map.events[id] = ev
    World.next_frame
    ev
  end

  # Runs the block with the Lens of Truth in use, as the game's map scene counts its frames down.
  def with_lens
    was = $scene
    scene = Scene_Map.new
    scene.define_singleton_method(:eye_of_truth_time) { 300 }
    $scene = scene
    World.next_frame
    yield
  ensure
    $scene = was
    World.next_frame
  end

  # Runs the block with the player carried by a move route, as a pass's page does.
  def carried
    class << $game_player; def move_route_forcing; true; end; end
    yield
  ensure
    class << $game_player; remove_method :move_route_forcing; end
  end

  # Runs the block with the game's type constants defined, as the game's compiled data defines them.
  def with_types
    TYPES.each { |name, id| PBTypes.const_set(name, id) unless PBTypes.const_defined?(name) }
    yield
  ensure
    TYPES.each_key { |name| PBTypes.send(:remove_const, name) if PBTypes.const_defined?(name) }
  end

  # A first-gym tile's name for a type.
  def tile(key, type)
    t(key, :type => PokeAccess::Data.type_name(TYPES[type]))
  end

  # Targets as [event, name].
  def named(list)
    list.map { |s| [s.ref, s.name] }
  end

  # A named point to stand on, as the locator lists it.
  def spot(x, y, key)
    PokeAccess::Locator::SurfaceTarget.new(x, y, t(key), :puzzle_cell, nil)
  end

  # A hidden event still to find, as the locator lists it.
  def hidden(id, x, y, key)
    PokeAccess::Locator::SurfaceTarget.new(x, y, t(key), :puzzle_hidden, id)
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
