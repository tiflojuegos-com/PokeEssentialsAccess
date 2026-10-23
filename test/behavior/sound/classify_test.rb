# The cue an event pings with (Sound::Scene.family_of): none if hidden, else the first reading that fits, from the
# player's tag down to a person or an object; the desk exception, the sonar_only_locatable filter and the census.
class ClassifyTest < PokeAccessTest
  Scene = PokeAccess::Sound::Scene
  Locator = PokeAccess::Locator
  Tags = PokeAccess::Tags
  # The cue a player's category tag gives an event: a category with no cue of its own (signs) gives none.
  TAG_FAMILIES = { :exits => :door, :people => :npc, :objects => :object, :signs => nil }

  test "a transfer drawn with no warp word is a door" do
    { "" => "no sprite", "boy" => "an ordinary sprite", "springboard" => "a sprite with no warp word in it",
      "HOOPA" => "the character, not its ring" }.each_with_index do |(sprite, what), i|
      assert_equal :door, Scene.family_of(transfer(i + 1, sprite)), what
    end
  end

  test "a transfer drawn as a warp pad is a teleporter" do
    ["portal", "Npc-Hoopa Rings", "vortex", "Umbral", "AnilloHoopaGrande"].each_with_index do |sprite, i|
      assert_equal :teleporter, Scene.family_of(transfer(i + 1, sprite)), "drawn as #{sprite}"
    end
  end

  test "a game's own pad sprite is a door until its profile registers it, a teleporter after" do
    with_list_kept(Locator::TELEPORTERS) do
      light = transfer(1, "lucecita")
      assert_equal :door, Scene.family_of(light), "unregistered"
      Locator.register_teleporter(/\Alucecita\z/i)
      assert_equal :teleporter, Scene.family_of(light), "registered from the profile"
    end
  end

  test "a lever pings as a control, and a chest as an object, open as well" do
    lever = World.event(:kind => :lever, :id => 1, :x => 6, :y => 5)
    pages = [TestPage.new(:sprite => "Cofre", :list => [TestCmd.new(355, ["pbReceiveItem(:POTION)"]), TestCmd.new(123, ["A", 0])]),
             TestPage.new(:sprite => "Cofre", :pattern => 1, :condition => { :self_switch_valid => true, :self_switch_ch => "A" })]
    chest = place(TestGameEvent.new(:id => 2, :x => 7, :y => 5, :pages => pages, :active_page => pages[1]))
    with_toggles_read { assert_equal [:control, :object], [Scene.family_of(lever), Scene.family_of(chest)] }
  end

  test "a trainer is a person" do
    assert_equal :npc, Scene.family_of(World.event(:kind => :trainer, :id => 1, :x => 6, :y => 5))
  end

  test "a sprite that talks back is a person" do
    page = TestPage.new(:trigger => 0, :sprite => "hiker", :list => [TestCmd.new(101, ["Hola"])])
    assert_equal :npc, Scene.family_of(place(TestGameEvent.new(:id => 1, :x => 6, :y => 5, :pages => [page])))
  end

  test "a sprite that answers nothing makes no sound" do
    page = TestPage.new(:trigger => 0, :sprite => "hiker")
    assert_nil Scene.family_of(place(TestGameEvent.new(:id => 1, :x => 6, :y => 5, :pages => [page])))
  end

  test "a person drawn with an object sprite is an object, a person sprite stays a person" do
    { "objeto3" => :object, "Object tree 1" => :object, "trainer_POKEMONTRAINER_Red" => :npc,
      "Collector_object" => :npc }.each_with_index do |(sprite, family), i|
      assert_equal family, Scene.family_of(drawn(:trainer, i + 1, sprite)), "drawn as #{sprite}"
    end
  end

  test "the locator files Essentials' English Object sprites under objects too" do
    assert_equal :objects, Locator.event_category(drawn(:trainer, 1, "Object tree 1"))
  end

  test "a bare sign makes no sound" do
    assert_nil Scene.family_of(World.event(:kind => :sign, :id => 1, :x => 4, :y => 6))
  end

  test "an event whose sprite name cannot be read makes no sound" do
    ev = World.event(:kind => :trainer, :id => 1, :x => 6, :y => 5)
    def ev.character_name; raise IOError, "sprite unreadable"; end
    assert_nil Scene.family_of(ev)
  end

  test "a player's category tag decides the cue over every automatic reading" do
    with_tags do
      person = World.event(:kind => :trainer, :id => 1, :x => 6, :y => 5)
      door = World.event(:kind => :door, :id => 2, :x => 7, :y => 5)
      TAG_FAMILIES.each do |category, family|
        [person, door].each do |ev|
          Tags.set_category($game_map.map_id, ev.id, category)
          assert_family family, ev, "#{ev.name} tagged #{category}"
        end
      end
    end
  end

  test "a hidden event makes no sound whatever its tag, while its neighbour keeps sounding" do
    with_tags do
      person = World.event(:kind => :trainer, :id => 1, :x => 6, :y => 5)
      gate = World.event(:kind => :door, :id => 2, :x => 7, :y => 5)
      door = World.event(:kind => :door, :id => 3, :x => 8, :y => 5)
      Tags.set_hidden($game_map.map_id, 1, true)
      Tags.set_category($game_map.map_id, 2, :exits)
      Tags.set_hidden($game_map.map_id, 2, true)
      assert_nil Scene.family_of(person), "a hidden person"
      assert_nil Scene.family_of(gate), "a hidden door, though tagged as an exit"
      assert_equal :door, Scene.family_of(door), "the untagged door beside them"
    end
  end

  test "on a puzzle's map a moving obstacle is a trap and a still one a hazard, whatever their sprites" do
    mover, rock = puzzle_obstacles
    declare_puzzle
    assert_equal [:trap, :hazard], [Scene.family_of(mover), Scene.family_of(rock)]
  end

  test "a puzzle's control is a control even when it also transfers the player" do
    crank = crank_event
    declare_puzzle
    assert_equal :control, Scene.family_of(crank)
  end

  test "off a puzzle's map the obstacles' sprites are people and the crank a door" do
    mover, rock = puzzle_obstacles
    crank = crank_event
    assert_equal [:npc, :npc, :door], [mover, rock, crank].map { |ev| Scene.family_of(ev) }
  end

  test "a player's tag outranks the puzzle piece an event is" do
    with_tags do
      mover, _rock = puzzle_obstacles
      declare_puzzle
      Tags.set_category($game_map.map_id, mover.id, :objects)
      assert_equal :object, Scene.family_of(mover)
    end
  end

  test "a sprite a profile registers as a hazard is a hazard, a person until then" do
    with_list_kept(Locator::HAZARDS) do
      beam = drawn(:trainer, 1, "laser_rojo")
      assert_equal :npc, Scene.family_of(beam), "unregistered"
      Locator.register_hazard(/laser/i, :loc_hazard_test)
      assert_equal :hazard, Scene.family_of(beam), "registered"
    end
  end

  test "a registered hazard drawn on a transfer is a hazard, not a door" do
    with_list_kept(Locator::HAZARDS) do
      Locator.register_hazard(/laser/i, :loc_hazard_test)
      assert_equal :hazard, Scene.family_of(transfer(1, "laser_puerta"))
    end
  end

  test "a boulder the player can push pings as a push, the same sprite with nothing to do none" do
    rock = World.event(:id => 1, :x => 6, :y => 5, :name => "Boulder", :sprite => "boulder")
    pebble = World.event(:id => 2, :x => 7, :y => 5, :name => "Stone", :sprite => "boulder")
    assert_equal :push, Scene.family_of(rock), "a strength boulder"
    assert_nil Scene.family_of(pebble), "a boulder sprite that cannot be pushed and does nothing"
  end

  test "a boulder the world has no record of yet is no push" do
    page = TestPage.new(:sprite => "boulder")
    assert_nil Scene.family_of(TestGameEvent.new(:id => 9, :x => 9, :y => 5, :name => "Boulder", :pages => [page]))
  end

  test "an invisible touch tile that steps the player is a conveyor, whichever way" do
    { 1 => "down", 2 => "left", 3 => "right", 4 => "up" }.each do |code, way|
      belt = place(walking_tile(code, "", World.move_player([code, 0])))
      with_push_tiles_read { assert_equal :belt, Scene.family_of(belt), way }
    end
  end

  test "an invisible touch tile that only turns the player or steps it diagonally is no conveyor" do
    { 16 => "a turn to face down", 5 => "a step down and to the left" }.each do |code, move|
      tile = place(walking_tile(code, "", World.move_player([code, 0])))
      with_push_tiles_read { assert_nil Scene.family_of(tile), move }
    end
  end

  test "a tile that steps the player is no conveyor drawn with a sprite or set off by the action button" do
    tiles = { "drawn as a boy" => ["boy", 1], "set off by the action button" => ["", 0] }
    tiles.each_with_index do |(what, (sprite, trigger)), i|
      tile = place(walking_tile(i + 1, sprite, World.move_player([1, 0]), trigger))
      with_push_tiles_read { assert_nil Scene.family_of(tile), what }
    end
  end

  test "an invisible touch tile that walks itself is no conveyor" do
    route = TestCmd.new(209, [0, TestMoveRoute.new([TestMoveCmd.new(1), TestMoveCmd.new(0)])])
    walker = place(walking_tile(1, "", route))
    with_push_tiles_read { assert_nil Scene.family_of(walker), "it would boing on every step" }
  end

  test "a service desk is heard through a wall up to the desk range" do
    PokeAccess::Config.audio3d_desk_range = 2
    nurse = drawn(:trainer, 1, "nurse")
    { 1 => true, 2 => true, 3 => false }.each do |tiles, heard|
      assert_equal heard, Scene.desk_bypass?(nurse, tiles), "#{tiles} tiles away"
    end
  end

  test "an ordinary person is never heard through a wall" do
    assert_equal false, Scene.desk_bypass?(World.event(:kind => :trainer, :id => 1, :x => 7, :y => 5), 1)
  end

  test "a desk range of 0 turns the desk exception off" do
    PokeAccess::Config.audio3d_desk_range = 0
    assert_equal false, Scene.desk_bypass?(drawn(:trainer, 1, "nurse"), 1)
  end

  test "with the locatable filter off, a tile-drawn touch event the keys never list pings as an object" do
    touch = tile_touch(1)
    assert_equal false, Locator.in_category?(touch, :all), "the keys never list it"
    assert_equal :object, Scene.family_of(touch)
  end

  test "with the locatable filter on, a tile-drawn touch event the keys never list goes quiet" do
    PokeAccess::Config.sonar_only_locatable = true
    assert_nil Scene.family_of(tile_touch(1))
  end

  test "with the locatable filter on, what the keys reach still pings" do
    PokeAccess::Config.sonar_only_locatable = true
    door = World.event(:kind => :door, :id => 2, :x => 7, :y => 5)
    person = World.event(:kind => :trainer, :id => 3, :x => 8, :y => 5)
    assert_equal [:door, :npc], [Scene.family_of(door), Scene.family_of(person)]
  end

  test "the census counts what pings and how much of it the keys cannot reach" do
    census_map
    assert_equal "3 pingan, 1 fuera del localizador", Scene.census
  end

  test "the census counts as if the filter were off, and leaves the player's filter on" do
    census_map
    PokeAccess::Config.sonar_only_locatable = true
    assert_equal "3 pingan, 1 fuera del localizador", Scene.census
    assert_equal true, PokeAccess::Config.sonar_only_locatable, "the filter is left as the player set it"
  end

  test "the census with no map says so" do
    map = $game_map
    $game_map = nil
    assert_equal "sin mapa", Scene.census
  ensure
    $game_map = map
  end

  test "a census the engine cannot answer reads as a question mark" do
    def $game_map.events; raise IOError, "map unreadable"; end
    assert_equal "?", Scene.census
  ensure
    $game_map.singleton_class.send(:remove_method, :events)
  end

  private

  # Asserts the cue ev pings with: expected, or none when it is nil.
  def assert_family(expected, ev, msg = nil)
    got = Scene.family_of(ev)
    expected.nil? ? assert_nil(got, msg) : assert_equal(expected, got, msg)
  end

  # Puts a hand-built event on the map, seen from the next frame on.
  def place(ev)
    $game_map.events[ev.id] = ev
    World.next_frame
    ev
  end

  # A World.event of kind, its sprite then drawn as sprite.
  def drawn(kind, id, sprite)
    ev = World.event(:kind => kind, :id => id, :x => id + 3, :y => 5)
    ev.character_name = sprite
    ev
  end

  # A player-touch transfer (201) drawn as sprite.
  def transfer(id, sprite)
    drawn(:door, id, sprite)
  end

  # A touch event drawn with a map tile and no sprite, showing a text.
  def tile_touch(id)
    page = TestPage.new(:trigger => 1, :sprite => "", :list => [TestCmd.new(101, ["Hola"])])
    place(TestGameEvent.new(:id => id, :x => 6, :y => 5, :tile_id => 384, :pages => [page]))
  end

  # An event set off by trigger (the player's touch by default), drawn as sprite, whose only command is the Set Move
  # Route given, before the list's end.
  def walking_tile(id, sprite, route, trigger = 1)
    page = TestPage.new(:trigger => trigger, :sprite => sprite, :list => [route, TestCmd.new(0, [])])
    TestGameEvent.new(:id => id, :x => 6, :y => 6, :pages => [page])
  end

  # The census's map: a tile-drawn touch event out of the keys' reach, a door and a person in it, and a sign that
  # does not ping.
  def census_map
    tile_touch(1)
    World.event(:kind => :door, :id => 2, :x => 7, :y => 5)
    World.event(:kind => :trainer, :id => 3, :x => 8, :y => 5)
    World.event(:kind => :sign, :id => 4, :x => 9, :y => 5)
  end

  # A shark that moves and a giant rock, as a ship puzzle's obstacles are drawn.
  def puzzle_obstacles
    [drawn(:trainer, 1, "sharpedo"), drawn(:trainer, 2, "roca_gigante")]
  end

  # The ship puzzle's crank: it turns variable 132 and transfers the player.
  def crank_event
    page = TestPage.new(:trigger => 0, :sprite => "", :list => [TestCmd.new(122, [132, 132, 0, 0, 1]),
                                                                TestCmd.new(201, [0, 5, 1, 1])])
    place(TestGameEvent.new(:id => 3, :x => 8, :y => 5, :pages => [page]))
  end

  # Declares the ship puzzle on this map: variable 132 watched, its controls found, the shark a mover and the rock a
  # wall.
  def declare_puzzle
    PokeAccess::World::Mechanics.declare($game_map.map_id, :kind => :state,
      :watch => [{ :var => 132, :label => :ship_crank_red }], :controls => true,
      :obstacles => [{ :match => /sharpedo/i, :kind => :mover }, { :match => /roca/i, :kind => :wall }])
  end

  # Runs the block with the player's tags empty, and empties them again after.
  def with_tags
    wipe_tags
    yield
  ensure
    wipe_tags
  end

  # Deletes the tags files and forgets the store.
  def wipe_tags
    [Tags::FILE, Tags::IMPORT].each { |f| File.delete(f) if File.exist?(f) }
    Tags.reload!
  end

  # Runs the block and gives the list (a registry a profile adds to) back its entries after.
  def with_list_kept(list)
    saved = list.dup
    yield
  ensure
    list.replace(saved)
  end

  # Runs the block with the locator's two-state toggles read afresh from the map's events, and read again from an
  # empty map after, so none outlives the test.
  def with_toggles_read
    Locator.refresh_lever_cache
    yield
  ensure
    World.clear_events
    Locator.refresh_lever_cache
  end

  # Runs the block with the push tiles read afresh from the map's events, and the locator's cache of them put back
  # after.
  def with_push_tiles_read
    saved = [:@push_map, :@push_ids].map { |k| Locator.instance_variable_get(k) }
    Locator.refresh_push_cache
    yield
  ensure
    [:@push_map, :@push_ids].each_with_index { |k, i| Locator.instance_variable_set(k, saved[i]) }
  end
end
