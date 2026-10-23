# What the soundscape reads around the player (Sound::Scene): the nearest emitters of each kind a scan keeps, the edge
# exits, the distance to a wall on each side, the nearest water and the events that walk, on the world's probe.
class SceneTest < PokeAccessTest
  Scene = PokeAccess::Sound::Scene
  Config = PokeAccess::Config
  # A sea with land at its west end, walls along both sides.
  SEA = ["##########",
         "#..~~~~~~#",
         "##########"]
  # A coast running north to south, the land west of the water.
  COAST = ["#####",
           "#..~#",
           "#..~#",
           "#####"]

  test "keeps the three nearest emitters of a kind, nearest first" do
    [[6, 5, "ana"], [7, 5, "bea"], [8, 5, "cid"], [9, 5, "dan"]].each_with_index do |(x, y, s), i|
      person(i + 1, x, y, s)
    end
    Scene.scan(5, 5)
    assert_equal [[6, 5], [7, 5], [8, 5]], heard(:npc)
  end

  test "merges the touching tiles of one structure into its tile nearest the player" do
    [[2, 5], [1, 5], [0, 6], [5, 3]].each_with_index { |(x, y), i| door(i + 1, x, y) }
    Scene.scan(5, 5)
    assert_equal [[5, 3], [2, 5]], heard(:door), "the lone door, then the structure that touches side and corner"
  end

  test "reads an emitter at the sonar's range and none past it" do
    door(1, 5, 12)
    { 7 => [[5, 12]], 6 => [] }.each do |range, want|
      Config.audio3d_range = range
      Scene.scan(5, 5)
      assert_equal want, heard(:door), "seven tiles away with a range of #{range}"
    end
  end

  test "drops an emitter behind a wall in hide mode only" do
    $game_map.load_grid(["#########", "#@..#...#", "#########"])
    person(1, 3, 1, "ana")
    person(2, 6, 1, "bea")
    { :occlude => [[3, 1], [6, 1]], :hear => [[3, 1], [6, 1]], :hide => [[3, 1]] }.each do |mode, want|
      Config.audio3d_occlusion = mode
      Scene.scan(1, 1)
      assert_equal want, heard(:npc), "in #{mode} mode"
    end
  end

  test "hides in hide mode a person behind a wall on any side, and hears her in the open" do
    sides = {
      "east" => [["######", "#@.#.#", "######"], ["######", "#@...#", "######"], [4, 1]],
      "west" => [["######", "#.#.@#", "######"], ["######", "#...@#", "######"], [1, 1]],
      "north" => [["###", "#.#", "###", "#.#", "#@#", "###"], ["###", "#.#", "#.#", "#.#", "#@#", "###"], [1, 1]],
      "south" => [["###", "#@#", "#.#", "###", "#.#", "###"], ["###", "#@#", "#.#", "#.#", "#.#", "###"], [1, 4]]
    }
    sides.each do |side, (walled, open, at)|
      assert_equal [[], [at]], [walled, open].map { |rows| heard_on(rows, at) }, "a person to the #{side}"
    end
  end

  test "hears a service desk's clerk across her counter within the desk range, never the shopper behind her" do
    $game_map.load_grid(["######", "#@C..#", "######"])
    person(1, 3, 1, "nurse")
    person(2, 4, 1, "boy")
    { 2 => [[3, 1]], 1 => [], 0 => [] }.each do |range, want|
      Config.audio3d_desk_range = range
      Scene.scan(1, 1)
      assert_equal want, heard(:npc), "the clerk two tiles away with a desk range of #{range}"
    end
  end

  test "pings an edge exit from its nearest border tile a step off the map is open from" do
    $game_map.block_step(7, 0, 8)
    with_edges(3 => [[5, 0, 8], [6, 0, 8], [7, 0, 8]]) do
      Scene.scan(10, 5)
      assert_equal [[6, 0]], heard(:exit), "the nearest tile shut, the next one"
    end
  end

  test "pings an edge exit only from a border tile the player can step onto, a wall there passed over" do
    [[5, 1, 8], [4, 0, 6], [6, 0, 4]].each { |x, y, d| $game_map.block_step(x, y, d) }
    with_edges(3 => [[5, 0, 8], [9, 0, 8]]) do
      [:hide, :hear].each do |mode|
        Config.audio3d_occlusion = mode
        Scene.scan(5, 3)
        assert_equal [[9, 0]], heard(:exit), "in #{mode} mode"
      end
    end
  end

  test "pings each destination's edge exit once, nearest first, within the sonar's range" do
    with_edges(3 => [[5, 0, 8], [6, 0, 8]], 4 => [[19, 10, 6], [19, 11, 6]]) do
      { 9 => [[6, 0]], 14 => [[6, 0], [19, 10]] }.each do |range, want|
        Config.audio3d_range = range
        Scene.scan(10, 5)
        assert_equal want, heard(:exit), "with a range of #{range}"
      end
    end
  end

  test "keeps apart two edge exits side by side that lead to different maps" do
    with_edges(3 => [[6, 0, 8]], 5 => [[7, 0, 8]]) do
      Scene.scan(10, 5)
      assert_equal [[7, 0], [6, 0]], heard(:exit)
    end
  end

  test "passes over in hide mode an edge exit out of the player's sight" do
    $game_map.block_step(10, 5, 8)
    with_edges(3 => [[6, 0, 8]]) do
      { :hide => [], :hear => [[6, 0]] }.each do |mode, want|
        Config.audio3d_occlusion = mode
        Scene.scan(10, 5)
        assert_equal want, heard(:exit), "in #{mode} mode"
      end
    end
  end

  test "reads a person as a person when one of the event's other readings fails" do
    person(1, 6, 5, "ana")
    [[PokeAccess::Locator, :push_tile?], [PokeAccess::Locator, :teleporter_event?],
     [PokeAccess::World::Events, :record_of]].each do |mod, name|
      failing(mod, name) { Scene.scan(5, 5) }
      assert_equal [[6, 5]], heard(:npc), "with #{mod}.#{name} failing"
    end
  end

  test "reads the people around when the map's connections cannot be read" do
    person(1, 6, 5, "ana")
    failing(PokeAccess::Locator, :connection_edges) { Scene.scan(5, 5) }
    assert_equal [[[6, 5]], []], [heard(:npc), heard(:exit)]
  end

  test "pings an edge exit with the exit sound" do
    with_sound_engine do |dll|
      with_soundscape do |sch|
        with_edges(3 => [[6, 0, 8]]) do
          Scene.scan(10, 5)
          sch.ping(10.0)
          assert_equal [[:exit, 6, 0, 85]], dll.played
        end
      end
    end
  end

  test "places the water on the nearest water tile, and keeps it as the water read" do
    $game_map.set_terrain(8, 5, 7)
    $game_map.set_terrain(5, 3, 7)
    assert_equal [[5, 3], [5, 3]], [Scene.read_water(5, 5), Scene.water], "the nearer of two shores"
  end

  test "finds water at the sonar's range, and none past it" do
    $game_map.set_terrain(15, 5, 7)
    Config.audio3d_range = 10
    assert_equal [15, 5], Scene.read_water(5, 5), "ten tiles away with a range of ten"
    Config.audio3d_range = 9
    assert_nil Scene.read_water(5, 5), "with a range of nine"
    assert_nil Scene.water, "which leaves no water read"
  end

  test "counts every kind of water as water, a waterfall's included, and no other surface" do
    water = [[6, 5]]
    { 7 => water, 6 => water, 5 => water, 8 => water, 9 => water, 10 => [], 12 => [], 16 => [] }.each do |tag, want|
      $game_map.clear_grid
      $game_map.set_terrain(6, 5, tag)
      assert_equal want, [Scene.read_water(5, 5)].compact, "terrain tag #{tag} beside the player"
    end
  end

  test "finds the water the player stands on" do
    $game_map.set_terrain(0, 5, 7)
    assert_equal [0, 5], Scene.read_water(0, 5)
  end

  test "afloat reads as the shore the nearest land a step from the water reaches, none past the sonar's range" do
    $game_map.load_grid(SEA)
    $PokemonGlobal.surfing = true
    assert_equal [[2, 1], [2, 1]], [Scene.read_shore(7, 1), Scene.shore], "five tiles west, not the walls beside"
    Config.audio3d_range = 4
    assert_nil Scene.read_shore(7, 1), "with a range of four"
    assert_nil Scene.shore, "which leaves no shore read"
  end

  test "afloat reads no shore where the step from the water onto the land is shut" do
    $game_map.load_grid(SEA)
    $game_map.block_step(3, 1, 4)
    $PokemonGlobal.surfing = true
    assert_nil Scene.read_shore(7, 1), "the land past it no water touches"
  end

  test "reads no shore on land, the water still read" do
    $game_map.load_grid(SEA)
    assert_equal [nil, [3, 1]], [Scene.read_shore(2, 1), Scene.read_water(2, 1)]
  end

  test "afloat reads no shore on a bridge the player surfs under, the land past it read" do
    $game_map.load_grid(SEA)
    $game_map.place_bridge(5, 1)
    $PokemonGlobal.surfing = true
    assert_equal [2, 1], Scene.read_shore(7, 1), "the land five tiles west, not the bridge two tiles off"
  end

  test "afloat reads no shore past the map's edge where the sea goes on, the land on the map read" do
    (12..19).each { |x| (0..19).each { |y| $game_map.set_terrain(x, y, 7) } }
    $PokemonGlobal.surfing = true
    assert_equal [11, 10], Scene.read_shore(17, 10), "the land six tiles west, not the next map's sea three tiles east"
  end

  test "reads no shore on the land a dismount's jump lands on, though the game has them surfing until it lands" do
    $game_map.load_grid(COAST)
    $PokemonGlobal.surfing = true
    assert_equal [2, 1], Scene.read_shore(3, 1), "afloat beside the land"
    assert_nil Scene.read_shore(2, 1), "on the land, as v21's jumpForward leaves them for the jump"
  end

  test "reads the distance to the nearest wall on each side, none past the wall range" do
    $game_map.load_grid(["######", "#....#", "#....#", "#....#", "#.@..#", "#....#", "######"])
    Scene.read_walls(2, 4)
    assert_equal({ :wind_n => nil, :wind_e => 3, :wind_s => 2, :wind_w => 2 }, Scene.walls)
  end

  test "reads a step the engine fails to answer as open" do
    $game_map.load_grid(["#########", "#@..#...#", "#########"])
    person(1, 6, 1, "bea")
    failing_steps { read_around(1, 1) }
    assert_equal [[[6, 1]], { :wind_n => nil, :wind_e => nil, :wind_s => nil, :wind_w => nil }],
                 [heard(:npc), Scene.walls],
                 "the person behind the wall is heard and no wall is felt"
  end

  test "watches the events that walk, wherever they stand" do
    person(1, 6, 5, "ana", 1)
    person(2, 7, 5, "bea")
    person(3, 30, 5, "cid", 2)
    Scene.scan(5, 5)
    assert_equal [[1, 6, 5], [3, 30, 5]], Scene.watched.map { |ev, x, y| [ev.id, x, y] }
  end

  test "reports a change only for a walker whose step starts or ends within the sonar's range" do
    Config.audio3d_range = 6
    near = person(1, 6, 5, "ana", 1)
    edge = person(2, 11, 5, "bea", 1)
    far = person(3, 30, 5, "cid", 1)
    still = person(4, 7, 5, "dan")
    { "nobody moving" => [nil, nil, false],
      "a walker moving far out of range" => [far, [29, 5], false],
      "a walker stopping a tile past the range" => [far, [12, 5], false],
      "a person who does not walk" => [still, [7, 6], false],
      "a walker changing tile in range" => [near, [5, 8], true],
      "a walker leaving the range" => [near, [5, 19], true],
      "a walker leaving from the range's edge" => [edge, [12, 5], true],
      "a walker coming to the range's edge" => [far, [10, 4], true] }.each do |what, (ev, to, want)|
      assert_equal want, moved_after(ev, to), what
    end
  end

  test "finds at the next scan each walker where she went" do
    Config.audio3d_range = 6
    she = person(1, 6, 5, "ana", 1)
    he = person(2, 30, 5, "cid", 1)
    person(3, 7, 5, "bea")
    moves = { [she, 5, 8] => [[7, 5], [5, 8]], [she, 5, 19] => [[7, 5]], [he, 9, 5] => [[6, 5], [7, 5], [9, 5]] }
    moves.each do |(ev, x, y), want|
      back = [ev.x, ev.y]
      Scene.scan(5, 5)
      ev.x, ev.y = x, y
      Scene.scan(5, 5)
      assert_equal [want, false], [heard(:npc), Scene.moved?(5, 5)], "event #{ev.id} gone to (#{x}, #{y})"
      ev.x, ev.y = back
    end
  end

  test "pings a puzzle's moving obstacle as a trap, and watches it though its own page stands still" do
    shark = person(4, 4, 5, "sharpedo")
    person(1, 6, 5, "ana")
    PokeAccess::World::Mechanics.declare($game_map.map_id, :kind => :state,
                                         :obstacles => [{ :match => /sharpedo/i, :kind => :mover }])
    Scene.scan(5, 5)
    assert_equal [[[4, 5]], [[6, 5]], [4]], [heard(:trap), heard(:npc), Scene.watched.map { |ev, _x, _y| ev.id }],
                 "the obstacle a trap, the person beside it a person"
    shark.x = 3
    assert_equal true, Scene.moved?(5, 5), "another event moving it is a reason to read again"
  end

  test "leaves a puzzle's still obstacle unwatched" do
    person(4, 4, 5, "spikes")
    PokeAccess::World::Mechanics.declare($game_map.map_id, :kind => :state, :obstacles => [{ :match => /spikes/i }])
    Scene.scan(5, 5)
    assert_equal [[[4, 5]], []], [heard(:hazard), Scene.watched]
  end

  test "drops what it read of the last map on a map change" do
    person(1, 6, 5, "ana", 1)
    $game_map.set_terrain(7, 5, 7)
    $game_map.block_step(5, 5, 4)
    read_around(5, 5)
    Scene.read_water(5, 5)
    read = [heard(:npc), Scene.walls[:wind_w], Scene.water, Scene.watched.length]
    PokeAccess::Caches.reset_all
    assert_equal [[[6, 5]], 1, [7, 5], 1], read, "the last map's emitter, wall, water and walker"
    assert_equal [{}, {}, nil, []], [Scene.emitters, Scene.walls, Scene.water, Scene.watched]
  end

  test "keeps the booted engine and its channels through a map change" do
    with_sound_engine do
      pa = PokeAccess::Sound::Pa3d
      chans = pa.channels.dup
      PokeAccess::Caches.reset_all
      assert_equal [true, chans], [pa.ready?, pa.channels]
    end
  end

  test "reads the scene again on the first frame after a map change" do
    with_trainer do
      with_sound_engine do
        with_soundscape do |sch|
          ana = person(1, 6, 5, "ana")
          sch.tick
          PokeAccess::Caches.reset_all
          ana.x = 7
          sch.tick
          assert_equal [[7, 5]], heard(:npc)
        end
      end
    end
  end

  test "finds the same emitters and walls with the probe's answers kept as with none kept" do
    sonar_corridor
    unkept = on_stair { read_around(1, 1) }
    want = [[[4, 1], [6, 1], [6, 2]], { :wind_n => 1, :wind_e => nil, :wind_s => 2, :wind_w => 1 }]
    assert_equal [want, want], [unkept, read_around(1, 1)]
  end

  test "asks the engine each step once, fewer questions than the rays ask with nothing kept" do
    sonar_corridor
    unkept = on_stair { steps_asked { read_around(1, 1) } }
    kept = steps_asked { read_around(1, 1) }
    assert_equal kept.uniq, kept, "each step once"
    assert_operator kept.length, :<, unkept.length, "the rays share their first steps"
  end

  test "sees a rock pushed onto the rays between two frames" do
    sonar_corridor
    rock = rock_at(10, 2)
    before = read_around(1, 1)[0]
    rock.x, rock.y = 3, 1
    World.next_frame
    assert_equal [[[4, 1], [6, 1], [6, 2]], []], [before, read_around(1, 1)[0]], "everyone behind it goes quiet"
  end

  test "asks again only the steps into and out of the tiles a pushed rock left and took" do
    sonar_corridor
    rock = rock_at(10, 2)
    read_around(1, 1)
    rock.x, rock.y = 3, 1
    World.next_frame
    asked = steps_asked { read_around(1, 1) }
    moved = [[10, 2], [3, 1]]
    far = asked.reject do |x, y, d|
      dx, dy = PokeAccess::DIR_DELTA[d]
      moved.include?([x, y]) || moved.include?([x + dx, y + dy])
    end
    assert_includes asked, [2, 1, 6], "the step into the tile the rock took is asked again"
    assert_equal [], far, "and no step away from both tiles"
  end

  private

  # A person (a trainer event) at (x, y) with a sprite of her own; move_type 1 or 2 makes her page walk her about.
  def person(id, x, y, sprite, move_type = 0)
    ev = World.event(:kind => :trainer, :id => id, :x => x, :y => y)
    ev.character_name = sprite
    ev.instance_variable_get(:@page).move_type = move_type
    ev
  end

  # A warp door (a touch event with a transfer and no sprite) at (x, y).
  def door(id, x, y)
    World.event(:kind => :door, :id => id, :x => x, :y => y)
  end

  # A blocking event with no graphic, standing on (x, y) as a rock does.
  def rock_at(x, y)
    rock = World.event(:id => 9, :x => x, :y => y)
    rock.character_name = ""
    rock.blocking = true
    rock
  end

  # The tiles of a kind the last scan kept, nearest first ([] for none).
  def heard(kind)
    Scene.emitters[kind] || []
  end

  # The people a scan from the player's tile hears on a grid, a person standing at (x, y).
  def heard_on(rows, at)
    $game_map.load_grid(rows)
    person(1, at[0], at[1], "ana")
    Scene.scan($game_player.x, $game_player.y)
    heard(:npc)
  end

  # The frame's reading from (x, y): the people kept and the walls, as [people, walls].
  def read_around(x, y)
    Scene.scan(x, y)
    Scene.read_walls(x, y)
    [heard(:npc), Scene.walls.dup]
  end

  # Whether moved? reports a change once ev (nil for none) went to `to` after a scan from (5, 5); ev is put back.
  def moved_after(ev, to)
    Scene.scan(5, 5)
    return Scene.moved?(5, 5) unless ev
    back = [ev.x, ev.y]
    ev.x, ev.y = to
    Scene.moved?(5, 5)
  ensure
    ev.x, ev.y = back if ev && back
  end

  # Five people east of the player in a two-row corridor: their rays share their first steps.
  def sonar_corridor
    $game_map.load_grid(["############",
                         "#@.........#",
                         "#..........#",
                         "############"])
    [[4, 1, "ana"], [6, 1, "bea"], [8, 1, "cid"], [6, 2, "dan"], [9, 2, "eva"]].each_with_index do |(x, y, s), i|
      person(i + 1, x, y, s)
    end
  end

  # Runs the block with the map's border leading off as edges says ({ destination => [[x, y, way out], ...] }).
  def with_edges(edges)
    loc = PokeAccess::Locator
    saved = [:@conn_edges, :@conn_targets_mid].map { |k| loc.instance_variable_get(k) }
    loc.instance_variable_set(:@conn_targets_mid, $game_map.map_id)
    loc.instance_variable_set(:@conn_edges, edges)
    yield
  ensure
    loc.instance_variable_set(:@conn_edges, saved[0])
    loc.instance_variable_set(:@conn_targets_mid, saved[1])
  end

  # The steps the block asks the engine's passable?, in order, as [x, y, direction].
  def steps_asked
    asked = []
    real = $game_player.method(:passable?)
    $game_player.define_singleton_method(:passable?) { |x, y, d| asked.push([x, y, d]); real.call(x, y, d) }
    yield
    asked
  ensure
    $game_player.singleton_class.send(:remove_method, :passable?)
  end

  # Runs the block with every step the engine is asked failing with an error.
  def failing_steps
    $game_player.define_singleton_method(:passable?) { |*_a| raise "the engine fails" }
    yield
  ensure
    $game_player.singleton_class.send(:remove_method, :passable?)
  end

  # The block's value with the player partway up a side stair, where the probe keeps no answer.
  def on_stair
    def $game_player.on_middle_of_stair?; true; end
    World.next_frame
    yield
  ensure
    $game_player.singleton_class.send(:remove_method, :on_middle_of_stair?)
    World.next_frame
  end

  # Runs the block with a module's method failing with an error.
  def failing(mod, name)
    real = mod.method(name)
    mod.define_singleton_method(name) { |*_a| raise "#{name} fails" }
    yield
  ensure
    mod.define_singleton_method(name, real)
  end

  # Runs the block with a trainer, without whom the frame holds the soundscape.
  def with_trainer
    was = $Trainer
    $Trainer = Object.new
    yield
  ensure
    $Trainer = was
  end
end
