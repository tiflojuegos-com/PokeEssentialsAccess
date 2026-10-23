# The region map's fly jump (TownMap): a provider picked by the scene's shape, a silent jump to the nearest flyable
# point that way; Armonia's jump in window squares over two panned maps, the player's mark kept on the head's map.
class TownMapTest < PokeAccessTest
  TM = PokeAccess::TownMap
  ARMONIA = File.join(Harness::ROOT, "games", "armonia", "fly_map.rb")
  CursorSprite = Struct.new(:x, :y)
  MapBitmap = Struct.new(:width, :height)
  MapSprite = Struct.new(:bitmap)

  # gen-6 vanilla and Arcky's plugin: the cursor in @mapX/@mapY, the points as raw rows in @map[2], the healing spot
  # of each point in spots (fly= gives each listed point one on map 1).
  class ClassicScene
    attr_accessor :mapX, :mapY, :spots

    def initialize(points, fly = [])
      @mapX = 0
      @mapY = 0
      @map = [nil, nil, points.map { |x, y| [x, y, "name", "desc", nil, nil, nil, nil] }]
      self.fly = fly
    end

    def fly=(list)
      @spots = {}
      list.each { |x, y| @spots[[x, y]] = [1, x, y] }
    end

    def pbGetHealingSpot(x, y); @spots[[x, y]]; end
  end

  # The classic scene as the screen draws it: its square size, the cursor sprite and the map's bitmap.
  class DrawnClassicScene < ClassicScene
    SQUAREWIDTH = 16
    SQUAREHEIGHT = 16
    attr_reader :sprites

    def initialize(points, fly = [])
      super
      @sprites = { "cursor" => CursorSprite.new(0, 0), "map" => MapSprite.new(MapBitmap.new(480, 320)) }
    end
  end

  # A classic scene whose pbGetHealingSpot takes the map data first, (map, x, y): each row carries its spot as
  # [x, y, name, desc, spot map, spot x, spot y].
  class MapFirstScene < ClassicScene
    def initialize(rows)
      super([])
      @map = [nil, nil, rows]
    end

    def pbGetHealingSpot(map, x, y)
      pt = map[2].find { |p| p[0] == x && p[1] == y }
      pt && pt[4] ? [pt[4], pt[5], pt[6]] : nil
    end
  end

  # The v21+ rework: the cursor in @map_x/@map_y, the points behind @map.point.
  class ReworkScene
    attr_accessor :map_x, :map_y, :sprites

    def initialize(points, fly = [])
      @map_x = 0
      @map_y = 0
      @map = Struct.new(:point).new(points.map { |x, y| [x, y, "name", "desc", nil, nil, nil, nil] })
      @fly = fly
    end

    def pbGetHealingSpot(x, y); @fly.include?([x, y]) ? [1, x, y] : nil; end
  end

  # The rework as the screen draws it: the cursor sprite, placed by the scene's own point-to-screen helpers.
  class PlacedReworkScene < ReworkScene
    def initialize(points, fly = [])
      super
      @sprites = { "cursor" => CursorSprite.new(0, 0) }
    end

    def point_x_to_screen_x(x); 24 + x * 16; end
    def point_y_to_screen_y(y); 40 + y * 16; end
  end

  # v20.1: the snake_case cursor over the old point Array in @map[2].
  class V20Scene < ReworkScene
    def initialize(points, fly = [])
      super
      @map = [nil, nil, points.map { |x, y| [x, y, "name", "desc", nil, nil, nil, nil] }]
    end
  end

  # A scene no built-in provider understands: its cursor is spot.
  class OddScene
    attr_accessor :spot
    def initialize(spot = [0, 0]); @spot = spot; end
  end

  # Armonia's region map cut down to what its jump reads: two maps side by side panned under a window of squares
  # (LEFT..RIGHT, TOP..BOTTOM), each map's places as rows [x, y, name, desc, spot map, spot x, spot y].
  class ArmoniaScene
    LEFT = 0
    RIGHT = 29
    TOP = 0
    BOTTOM = 19
    SQUAREWIDTH = 16
    SQUAREHEIGHT = 16
    attr_accessor :sprites

    def initialize(map1, map2)
      @map1 = map1
      @map2 = map2
      @map = map1
      @mapX = 0
      @mapY = 0
      @sprites = { "cursor" => CursorSprite.new(0, 0) }
      pan([0, 0], [30, 4])
    end

    # Pans the two maps as the screen scrolls them: [x, y] of map one, then of map two.
    def pan(one, two)
      @map1TransformX, @map1TransformY = one
      @map2TransformX, @map2TransformY = two
    end

    def transformX(x); x; end

    def pbGetHealingSpot(map, x, y)
      pt = map[2].find { |p| p[0] == x && p[1] == y }
      pt && pt[4] ? [pt[4], pt[5], pt[6]] : nil
    end
  end

  test "picks the provider by where the scene keeps its cursor" do
    shapes = { ClassicScene.new([]) => :classic, ReworkScene.new([]) => :ui_rework, V20Scene.new([]) => :ui_rework }
    shapes.each { |scene, name| assert_equal name, TM.provider_for(scene)[0], "for #{scene.class}" }
  end

  test "a scene no provider understands has no cursor, no points and is not moved" do
    scene = OddScene.new
    assert_nil TM.provider_for(scene), "no provider"
    assert_nil TM.cursor(scene), "no cursor"
    assert_equal [], TM.points(scene), "no points"
    assert_equal [], TM.fly_points(scene), "no flyable points"
    assert_equal false, TM.move(scene, 1, 1), "the move refused"
    assert_equal [0, 0], scene.spot, "and the scene left as it was"
  end

  test "the newest provider that handles a scene is the one used" do
    registering(*odd_provider(:spec_any, :handles => lambda { |_s| true })) do
      assert_equal :spec_any, TM.provider_for(ClassicScene.new([]))[0]
    end
  end

  test "a profile's provider works a scene the built-in ones do not understand" do
    registering(*odd_provider(:spec_odd, :points => lambda { |_s| [[7, 7]] })) do
      scene = OddScene.new
      assert_equal true, TM.move(scene, 8, 9), "the move goes through the profile's code"
      assert_equal [8, 9], scene.spot, "which really moved the scene's cursor"
      assert_equal [8, 9], TM.cursor(scene), "read back through it too"
      assert_equal [[7, 7]], TM.points(scene), "and the points are the profile's"
    end
  end

  test "passes over a provider whose shape check fails" do
    registering(*odd_provider(:spec_broken, :handles => lambda { |_s| raise "no shape" })) do
      assert_equal :classic, TM.provider_for(ClassicScene.new([]))[0]
    end
  end

  test "reads the cursor from the scene's own ivars" do
    classic = ClassicScene.new([])
    classic.mapX = 3
    classic.mapY = 4
    rework = ReworkScene.new([])
    rework.map_x = 2
    rework.map_y = 6
    assert_equal [[3, 4], [2, 6]], [TM.cursor(classic), TM.cursor(rework)]
  end

  test "moving the cursor writes the scene's own ivars and answers that it moved" do
    classic = ClassicScene.new([])
    rework = ReworkScene.new([])
    assert_equal [true, true], [TM.move(classic, 4, 7), TM.move(rework, 3, 6)], "both moved"
    assert_equal [4, 7], [classic.mapX, classic.mapY], "the classic cursor"
    assert_equal [3, 6], [rework.map_x, rework.map_y], "the rework's cursor"
  end

  test "places the classic cursor sprite where the screen draws that square" do
    scene = DrawnClassicScene.new([])
    TM.move(scene, 4, 7)
    cursor = scene.sprites["cursor"]
    assert_equal [72, 136], [cursor.x, cursor.y]
  end

  test "leaves the classic cursor sprite alone on a screen with no map drawn" do
    scene = DrawnClassicScene.new([])
    scene.sprites.delete("map")
    assert_equal true, TM.move(scene, 4, 7), "the cursor still moves"
    assert_equal [4, 7], [scene.mapX, scene.mapY], "in the scene's ivars"
    assert_equal [0, 0], [scene.sprites["cursor"].x, scene.sprites["cursor"].y], "the sprite left where it was"
  end

  test "places the rework's cursor sprite where the scene's own helpers put that point" do
    scene = PlacedReworkScene.new([])
    TM.move(scene, 3, 6)
    cursor = scene.sprites["cursor"]
    assert_equal [72, 136], [cursor.x, cursor.y]
  end

  test "leaves the rework's cursor sprite alone on a scene without point-to-screen helpers" do
    scene = ReworkScene.new([])
    scene.sprites = { "cursor" => CursorSprite.new(0, 0) }
    assert_equal true, TM.move(scene, 3, 6), "the cursor still moves"
    assert_equal [3, 6], [scene.map_x, scene.map_y], "in the scene's ivars"
    assert_equal [0, 0], [scene.sprites["cursor"].x, scene.sprites["cursor"].y], "the sprite left where it was"
  end

  test "answers that the cursor did not move when the provider's move fails" do
    registering(*odd_provider(:spec_stuck, :move => lambda { |_s, _x, _y| raise "stuck" })) do
      assert_equal false, TM.move(OddScene.new, 1, 1)
    end
  end

  test "lists the map's points from where each shape keeps them" do
    kept = { ClassicScene => [[1, 1], [5, 1]], ReworkScene => [[2, 2], [9, 2]], V20Scene => [[3, 3], [7, 3]] }
    kept.each { |klass, points| assert_equal points, TM.points(klass.new(points)), "for #{klass}" }
  end

  test "lists no points where a scene keeps no point list, or a provider's list fails" do
    [ClassicScene, ReworkScene].each do |klass|
      scene = klass.new([[2, 2]])
      scene.instance_variable_set(:@map, nil)
      assert_equal [], TM.points(scene), "a #{klass} with no map data"
    end
    { "raises" => lambda { |_s| raise "no points" }, "answers nil" => lambda { |_s| nil } }.each do |how, points|
      registering(*odd_provider(:spec_points, :points => points)) do
        assert_equal [], TM.points(OddScene.new), "a provider whose list #{how}"
      end
    end
  end

  test "offers the points the game gives a healing spot, where it keeps no record of visits" do
    scene = ClassicScene.new([[1, 1], [5, 1]], [[5, 1]])
    assert_equal [[5, 1]], TM.fly_points(scene)
  end

  test "offers only the healing spots on maps the player has visited" do
    scene = ClassicScene.new([[1, 1], [5, 1], [9, 1]])
    scene.spots = { [1, 1] => [11, 3, 4], [5, 1] => [12, 7, 8], [9, 1] => [13, 2, 2] }
    with_visited_maps(11 => true, 12 => false) do
      assert_equal [[1, 1]], TM.fly_points(scene)
    end
  end

  test "counts a healing spot as visited where the record of visits cannot tell" do
    unreadable = Object.new
    def unreadable.[](_id); raise "unreadable"; end
    cases = { "a spot with no map id" => [{}, :here], "a record that cannot be read" => [unreadable, [11, 3, 4]] }
    cases.each do |how, (record, spot)|
      scene = ClassicScene.new([[1, 1]])
      scene.spots = { [1, 1] => spot }
      with_visited_maps(record) do
        assert_equal [[1, 1]], TM.fly_points(scene), how
      end
    end
  end

  test "asks for the healing spot with the map data first where the game's method takes it" do
    scene = MapFirstScene.new([[5, 1, "Pueblo", "", 11, 5, 6], [8, 2, "Ruta", ""]])
    assert_equal [[5, 1]], TM.fly_points(scene)
  end

  test "leaves out a point whose healing spot cannot be read" do
    scene = ClassicScene.new([[1, 1], [5, 1]], [[1, 1], [5, 1]])
    def scene.pbGetHealingSpot(_x, _y); raise "no spot"; end
    assert_equal [], TM.fly_points(scene)
  end

  test "offers a provider's own flyable set over the healing spots" do
    registering(*own_set_provider(lambda { |_s| [[7, 7]] })) do
      assert_equal [[7, 7]], TM.fly_points(own_set_scene)
    end
  end

  test "falls back to the healing spots when a provider's own flyable set fails" do
    { "raises" => lambda { |_s| raise "no set" }, "answers nil" => lambda { |_s| nil } }.each do |how, flyable|
      registering(*own_set_provider(flyable)) do
        assert_equal [[5, 1]], TM.fly_points(own_set_scene), "when the set #{how}"
      end
    end
  end

  test "jumps to the nearest flyable point that way through the game's own cursor, saying nothing" do
    scene = ClassicScene.new([[1, 5], [8, 5], [6, 5]], [[1, 5], [8, 5]])
    TM.move(scene, 4, 5)
    opened(scene) do
      assert_equal true, TM.jump(scene, :right), "it moved"
      assert_equal [8, 5], [scene.mapX, scene.mapY], "the game's cursor, so confirming flies there"
      assert_nothing_spoken "the map's own loop announces the new square"
    end
  end

  test "says there is no flyable place that way and keeps the cursor" do
    scene = ClassicScene.new([[1, 5], [8, 5]], [[1, 5], [8, 5]])
    TM.move(scene, 8, 5)
    opened(scene) do
      assert_equal false, TM.jump(scene, :right), "it did not move"
      assert_equal [8, 5], [scene.mapX, scene.mapY], "the cursor stayed put"
      assert_equal [[PokeAccess::I18n.t(:tm_no_fly), true]], SpeakCapture.log, "and it said so, cutting in"
    end
  end

  test "keeps quiet and still when the profile turned the jump off" do
    scene = ClassicScene.new([[1, 5], [8, 5]], [[1, 5], [8, 5]])
    TM.move(scene, 4, 5)
    opened(scene) do
      with_jump_off do
        assert_equal false, TM.jump(scene, :right), "the jump refused"
        assert_equal [4, 5], [scene.mapX, scene.mapY], "the cursor left where it was"
        assert_nothing_spoken "no 'nothing that way' that would only confuse"
      end
    end
  end

  test "does not jump without a scene or a cursor it can read" do
    unreadable = OddScene.new
    def unreadable.spot; raise "unreadable"; end
    places = lambda { |_s| [[1, 1], [9, 9]] }
    registering(*odd_provider(:spec_cursor, :points => places, :flyable => places)) do
      { "no scene" => nil, "no x" => OddScene.new([nil, 3]), "no y" => OddScene.new([3, nil]),
        "a cursor that raises" => unreadable }.each do |how, scene|
        assert_equal false, TM.jump(scene, :right), how
        assert_nothing_spoken how
      end
    end
  end

  test "keeps the flyable list it took on the first jump while the map stays open" do
    scene = ClassicScene.new([[1, 5], [8, 5], [5, 5]], [[1, 5], [8, 5]])
    opened(scene) do
      TM.move(scene, 1, 5)
      TM.jump(scene, :right)
      scene.fly = [[1, 5], [8, 5], [5, 5]]
      TM.move(scene, 1, 5)
      TM.jump(scene, :right)
      assert_equal [8, 5], [scene.mapX, scene.mapY], "the middle place became flyable after, and is skipped"
    end
  end

  test "takes the flyable list afresh when the map opens again" do
    scene = ClassicScene.new([[1, 5], [8, 5], [5, 5]], [[1, 5], [8, 5]])
    opened(scene) { TM.jump(scene, :right) }
    scene.fly = [[1, 5], [8, 5], [5, 5]]
    opened(scene) do
      TM.move(scene, 1, 5)
      TM.jump(scene, :right)
      assert_equal [5, 5], [scene.mapX, scene.mapY]
    end
  end

  test "takes the flyable list afresh for a map opened over one never closed" do
    first = ClassicScene.new([[1, 5], [8, 5]], [[1, 5], [8, 5]])
    second = ClassicScene.new([[1, 5], [5, 5]], [[1, 5], [5, 5]])
    TM.opened(first)
    TM.jump(first, :right)
    opened(second) do
      TM.move(second, 1, 5)
      TM.jump(second, :right)
      assert_equal [5, 5], [second.mapX, second.mapY]
    end
  end

  test "asks a provider with its own flyable set at every jump, as its map may pan" do
    set = [[8, 5]]
    registering(*own_set_provider(lambda { |_s| set })) do
      scene = own_set_scene
      scene.spot = [1, 5]
      opened(scene) do
        TM.jump(scene, :right)
        set = [[4, 5], [8, 5]]
        scene.spot = [1, 5]
        TM.jump(scene, :right)
        assert_equal [4, 5], scene.spot
      end
    end
  end

  test "tracks the map scene from its opening until it closes" do
    scene = ClassicScene.new([])
    TM.opened(scene)
    assert_same scene, TM.open_scene, "open: the locator keys jump"
    TM.closed(scene)
    assert_nil TM.open_scene, "closed: the keys go back to the locator"
  end

  test "a map change gives back the keys a map left open was holding" do
    TM.opened(ClassicScene.new([]))
    PokeAccess::Events.emit(:map_changed)
    assert_nil TM.open_scene
  end

  test "while the map is open, each locator key jumps its own way" do
    { :prev => [2, 4], :next => [8, 4], :route => [5, 1], :where => [5, 5] }.each do |key, target|
      scene = keys_scene
      opened(scene) { pulse(key) }
      assert_equal target, [scene.mapX, scene.mapY], "for #{key}"
    end
  end

  test "the locator keys do not jump while no map is open" do
    scene = keys_scene
    pulse(:next)
    assert_equal [5, 4], [scene.mapX, scene.mapY], "the cursor stayed put"
    assert_nothing_spoken
  end

  test "the locator keys do not jump while the mod is off or the game is not in front" do
    { "the mod off" => { :enabled => lambda { false } },
      "the game not in front" => { :focused? => lambda { false } } }.each do |how, keys|
      scene = keys_scene
      opened(scene) { with_keys(keys) { pulse(:next) } }
      assert_equal [5, 4], [scene.mapX, scene.mapY], "with #{how}"
    end
  end

  test "the locator keys still jump when the mod cannot tell whether it is on or in front" do
    scene = keys_scene
    failing = lambda { raise "unknown" }
    opened(scene) { with_keys(:enabled => failing, :focused? => failing) { pulse(:next) } }
    assert_equal [8, 4], [scene.mapX, scene.mapY]
  end

  test "lands on the nearest point ahead in each direction" do
    points = [[2, 5], [8, 5], [5, 1], [5, 9], [5, 5], [9, 5], [5, 0]]
    { :left => [2, 5], :right => [8, 5], :up => [5, 1], :down => [5, 9] }.each do |dir, target|
      assert_equal target, TM.nearest(points, 5, 5, dir), "going #{dir}"
    end
  end

  test "prefers a nearer point a row off over a farther one in line" do
    ways = { :left => [[1, 5], [4, 8]], :right => [[8, 5], [6, 9]], :up => [[5, 1], [2, 4]], :down => [[5, 9], [8, 6]] }
    ways.each do |dir, points|
      assert_equal points[1], TM.nearest(points, 5, 5, dir), "going #{dir}"
    end
  end

  test "breaks a tie in distance toward the smaller drift sideways" do
    ways = { :left => [[4, 3], [4, 6]], :right => [[6, 3], [6, 6]], :up => [[3, 4], [6, 4]], :down => [[3, 6], [6, 6]] }
    ways.each do |dir, points|
      assert_equal points[1], TM.nearest(points, 5, 5, dir), "going #{dir}"
    end
  end

  test "keeps the first of two points as near and as far off the line" do
    assert_equal [6, 4], TM.nearest([[6, 4], [6, 6]], 5, 5, :right)
  end

  test "never lands on the point under the cursor or one behind it" do
    { :left => [6, 5], :right => [4, 5], :up => [5, 6], :down => [5, 4] }.each do |dir, behind|
      assert_nil TM.nearest([[5, 5], behind], 5, 5, dir), "going #{dir}"
    end
    assert_nil TM.nearest([], 5, 5, :up), "with no points at all"
  end

  test "finds no point in a direction it does not know" do
    assert_nil TM.nearest([[8, 5], [5, 8]], 5, 5, :sideways)
  end

  test "on Armonia's map, offers map one's places with a healing spot, and none of map two's past the window" do
    scene = armonia_scene
    assert_equal [[5, 5]], armonia.flyable(scene)
  end

  test "on Armonia's map, offers map two's place where the window shows it once panned" do
    scene = armonia_scene
    scene.pan([25, 0], [5, 4])
    assert_equal [[7, 7]], armonia.flyable(scene)
  end

  test "on Armonia's map, offers the places on the window's edges and none past them" do
    spot = [11, 1, 1]
    corners = ArmoniaScene.new([nil, nil, [[0, 0, "a", "", *spot], [29, 19, "b", "", *spot], [30, 5, "c", "", *spot],
                                           [5, 20, "d", "", *spot]]], [nil, nil, []])
    assert_equal [[0, 0], [29, 19]], armonia.flyable(corners), "the far edges"
    near = ArmoniaScene.new([nil, nil, [[1, 1, "a", "", *spot], [0, 1, "b", "", *spot], [1, 0, "c", "", *spot]]],
                            [nil, nil, []])
    near.pan([1, 1], [30, 4])
    assert_equal [[0, 0]], armonia.flyable(near), "the near edges"
  end

  test "on Armonia's map, a map not built yet leaves the other's places offered" do
    scene = armonia_scene
    scene.instance_variable_set(:@map2, nil)
    assert_equal [[5, 5]], armonia.flyable(scene)
  end

  test "on Armonia's map, a place it cannot read leaves nothing to offer rather than failing" do
    scene = ArmoniaScene.new([nil, nil, [[5, 5, "Pueblo", "", 11, 5, 6], [nil, 2, "Roto", "", 11, 1, 1]]],
                             [nil, nil, []])
    assert_equal [], armonia.flyable(scene)
  end

  test "on Armonia's map, leaves out a place on a map the player has not visited" do
    scene = armonia_scene
    with_visited_maps(12 => true) do
      assert_equal [], armonia.flyable(scene)
    end
  end

  test "on Armonia's map, landing on a place puts the cursor on that place's map, in window squares" do
    scene = armonia_scene
    scene.pan([25, 0], [5, 4])
    armonia.move(scene, 7, 7)
    assert_equal [1, 7, 7], [:@mapindex, :@mapX, :@mapY].map { |v| scene.instance_variable_get(v) },
                 "map two, square (7, 7)"
    assert_same scene.instance_variable_get(:@map2), scene.instance_variable_get(:@map), "map two shown"
    assert_equal [120, 136], [scene.sprites["cursor"].x, scene.sprites["cursor"].y],
                 "the sprite where the screen draws it"
  end

  test "on Armonia's map, landing on map one's place puts the cursor on map one" do
    scene = armonia_scene
    scene.instance_variable_set(:@map, scene.instance_variable_get(:@map2))
    armonia.move(scene, 5, 5)
    assert_equal 0, scene.instance_variable_get(:@mapindex), "map one's index"
    assert_same scene.instance_variable_get(:@map1), scene.instance_variable_get(:@map), "map one shown"
  end

  test "on Armonia's map, landing on a square with no place keeps the map shown" do
    scene = armonia_scene
    armonia.move(scene, 9, 5)
    assert_equal [nil, 9, 5], [:@mapindex, :@mapX, :@mapY].map { |v| scene.instance_variable_get(v) },
                 "no place there, though one shares its column and another its row"
    assert_same scene.instance_variable_get(:@map1), scene.instance_variable_get(:@map)
  end

  test "on Armonia's map, moves the cursor of a screen without a cursor sprite" do
    scene = armonia_scene
    scene.sprites = {}
    armonia.move(scene, 5, 5)
    assert_equal [5, 5], [scene.instance_variable_get(:@mapX), scene.instance_variable_get(:@mapY)]
  end

  test "Armonia's provider takes its scene and leaves to the core a scene with a map one of its own" do
    with_armonia_provider do
      other = ClassicScene.new([])
      other.instance_variable_set(:@map1, [nil, nil, []])
      assert_equal [:armonia, :classic], [TM.provider_for(armonia_scene)[0], TM.provider_for(other)[0]]
    end
  end

  test "on Armonia's map, the jump follows the window as it pans" do
    with_armonia_provider do
      scene = armonia_scene
      opened(scene) do
        TM.move(scene, 1, 5)
        assert_equal true, TM.jump(scene, :right), "a jump right from (1, 5)"
        assert_equal [5, 5], TM.cursor(scene), "lands on map one's place"
        scene.pan([25, 0], [5, 4])
        TM.move(scene, 1, 7)
        TM.jump(scene, :right)
        assert_equal [7, 7], TM.cursor(scene), "panned, on map two's place where the window shows it now"
      end
    end
  end

  test "on Armonia's map, the screen's build asks for its first square unheard" do
    with_armonia_profile do
      scene = armonia_region_scene
      scene.pbStartScene
      assert_nothing_spoken
      scene.pbEndScene
    end
  end

  test "on Armonia's map, the player's mark stays on the map the head is drawn on" do
    with_armonia_profile do
      scene = armonia_region_scene
      scene.pbStartScene
      wiel = scene.instance_variable_get(:@map1)
      east = scene.instance_variable_get(:@map2)
      heard = [[wiel, 5, 10], [east, 5, 9], [east, 5, 10], [wiel, 5, 9], [wiel, 5, 10]].map do |map, x, y|
        SpeakCapture.clear
        scene.instance_variable_set(:@map, map)
        scene.pbGetMapLocation(x, y)
        SpeakCapture.log.dup
      end
      scene.pbEndScene
      you = "Ciudad Wiel, #{PokeAccess::I18n.t(:rmap_you)}"
      want = [[[you, false]], [[square(5, 9), true]], [[square(5, 10), true]], [[square(5, 9), true]], [[you, true]]]
      assert_equal want, heard, "the loop's first square, the other map's at the same coordinates, and back on the head's"
    end
  end

  test "on Armonia's map, a map screen with no head kept marks the player's square as the core does" do
    with_armonia_profile do
      plain = Object.new
      plain.instance_variable_set(:@access_player_sq, [3, 4])
      marks = [[3, 4], [4, 3]].map { |x, y| PokeAccess::RegionMap.player_square?(plain, x, y) }
      assert_equal [true, false], marks
    end
  end

  test "Armonia's profile files no missing hook for a region map screen without pbStartScene" do
    hooked = PokemonRegionMapScene.instance_method(:pbStartScene)
    PokemonRegionMapScene.send(:remove_method, :pbStartScene)
    missing = PokeAccess::Hooks.missing.dup
    with_armonia_profile { assert_equal missing, PokeAccess::Hooks.missing }
  ensure
    PokemonRegionMapScene.send(:define_method, :pbStartScene, hooked)
    PokeAccess::Hooks.missing.replace(missing) if missing
  end

  private

  # Runs the block with a provider registered as a profile registers one, taken back out after.
  def registering(*provider)
    count = TM.providers.length
    TM.register(*provider)
    yield
  ensure
    TM.providers.slice!(count..-1) if count
  end

  # A provider of OddScene as a profile registers one: its cursor the scene's spot, no points and no flyable set of
  # its own, any of its parts (:handles, :cursor, :move, :points, :flyable) replaced by those given.
  def odd_provider(name, parts = {})
    [name,
     parts.fetch(:handles, lambda { |s| s.is_a?(OddScene) }),
     parts.fetch(:cursor, lambda { |s| s.spot }),
     parts.fetch(:move, lambda { |s, x, y| s.spot = [x, y] }),
     parts.fetch(:points, lambda { |_s| [] }),
     parts[:flyable]]
  end

  # A provider of OddScene whose flyable set is flyable's, its points those of own_set_scene.
  def own_set_provider(flyable)
    odd_provider(:spec_own, :points => lambda { |_s| [[1, 1], [5, 1]] }, :flyable => flyable)
  end

  # An OddScene with a healing spot on (5, 1) only.
  def own_set_scene
    scene = OddScene.new
    def scene.pbGetHealingSpot(x, y); [x, y] == [5, 1] ? [1, x, y] : nil; end
    scene
  end

  # A classic scene with a flyable place each way of its cursor at (5, 4).
  def keys_scene
    points = [[2, 4], [8, 4], [5, 1], [5, 5]]
    scene = ClassicScene.new(points, points)
    TM.move(scene, 5, 4)
    scene
  end

  # Runs the block with scene opened as the map on screen, closed after.
  def opened(scene)
    TM.opened(scene)
    yield
  ensure
    TM.closed(scene)
  end

  # Runs the block with the jump turned off as a profile turns it, the setting put back after.
  def with_jump_off
    was = TM.instance_variable_get(:@jump_enabled)
    TM.jump_enabled = false
    yield
  ensure
    TM.instance_variable_set(:@jump_enabled, was)
  end

  # Runs the block with the game's record of visited maps answering record.
  def with_visited_maps(record)
    global = $PokemonGlobal
    had = global.singleton_methods.include?(:visitedMaps) ? global.method(:visitedMaps) : nil
    global.define_singleton_method(:visitedMaps) { record }
    yield
  ensure
    had ? global.define_singleton_method(:visitedMaps, had) : global.singleton_class.send(:remove_method, :visitedMaps)
  end

  # Runs the block with each named method of PokeAccess::Keys answering through its lambda, put back after.
  def with_keys(bodies)
    saved = bodies.keys.map { |m| [m, PokeAccess::Keys.method(m)] }
    bodies.each { |m, body| PokeAccess::Keys.define_singleton_method(m, &body) }
    yield
  ensure
    saved.each { |m, real| PokeAccess::Keys.define_singleton_method(m, real) } if saved
  end

  # One pulse of the town map's poller with key the only mod key down.
  def pulse(key)
    pollers = PokeAccess::Frame.instance_variable_get(:@pollers)
    poller = pollers.find { |b| b.source_location[0].end_with?("nav/town_map.rb") }
    with_keys(:key => lambda { |name| name == key }) { poller.call }
  end

  # Armonia's map module, evaluated once from the profile's file: the whole file would also register its provider and
  # its profile for good.
  def armonia
    eval_armonia(/^module PokeAccess\r?\n.*?^end\r?\n/m) unless defined?(PokeAccess::ArmoniaMap)
    PokeAccess::ArmoniaMap
  end

  # Evaluates the part of Armonia's file the pattern matches, at its own lines.
  def eval_armonia(pattern)
    src = Harness.source(ARMONIA)
    found = src.match(pattern)
    eval(found[0], TOPLEVEL_BINDING, ARMONIA, src[0, found.begin(0)].count("\n") + 1)
  end

  # Armonia's scene, unpanned: map one with Pueblo (healing spot on map 11) at (5, 5) and Ruta (none) at (9, 2), map
  # two with Isla (healing spot on map 12) at (2, 3), beyond the window until panned.
  def armonia_scene
    ArmoniaScene.new([nil, nil, [[5, 5, "Pueblo", "", 11, 5, 6], [9, 2, "Ruta", ""]]],
                     [nil, nil, [[2, 3, "Isla", "", 12, 2, 3]]])
  end

  # Runs the block with Armonia's provider registered from its file, taken back out after.
  def with_armonia_provider
    armonia
    count = TM.providers.length
    eval_armonia(/^PokeAccess::TownMap\.register\(\r?\n  :armonia,.*?^\)\r?\n/m)
    yield
  ensure
    TM.providers.slice!(count..-1) if count
  end

  # Runs the block with Armonia's profile block (its Game.define) in force over the stubs' PokemonRegionMapScene,
  # what it registers taken back after: its hook on pbStartScene, its override of the player's mark, its name.
  def with_armonia_profile
    armonia
    chain = PokeAccess::Hooks.instance_variable_get(:@chains)["PokemonRegionMapScene#pbStartScene"]
    kept = chain.dup
    square = PokeAccess::RegionMap.method(:player_square?)
    listed = PokeAccess::Hooks.overrides.length
    profiles = PokeAccess::Game.profiles.dup
    eval_armonia(/^PokeAccess::Game\.define\("armonia"\) do\r?\n.*?^end\r?\n/m)
    yield
  ensure
    if kept
      chain.replace(kept)
      PokeAccess::RegionMap.define_singleton_method(:player_square?, square)
      PokeAccess::Hooks.overrides.slice!(listed..-1)
      PokeAccess::Game.profiles.replace(profiles)
      PokeAccess::Game.instance_variable_set(:@profile_name, nil)
    end
  end

  # The stubs' region map scene built as Armonia's: map one, the head's, with Ciudad Wiel at (5, 10), and an empty map
  # two; its own pbGetMapLocation answers the place of the square on the map shown, and the build asks it for the
  # player's square as Armonia's does.
  def armonia_region_scene
    wiel = [nil, nil, [[5, 10, "Ciudad Wiel", ""]]]
    east = [nil, nil, []]
    scene = PokemonRegionMapScene.new
    scene.instance_variable_set(:@build, lambda do |s, _a|
      s.instance_variable_set(:@sprites, { "player" => Object.new })
      { :@map1 => wiel, :@map2 => east, :@map => wiel }.each { |k, v| s.instance_variable_set(k, v) }
      s.pbGetMapLocation(5, 10)
    end)
    scene.define_singleton_method(:pbGetMapLocation__pa_orig_PokemonRegionMapScene) do |x, y|
      pt = @map[2].find { |p| p[0] == x && p[1] == y }
      pt ? pt[2] : ""
    end
    scene
  end

  # A blank square's line, by its coordinates.
  def square(x, y)
    PokeAccess::I18n.t(:brm_square, :x => x, :y => y)
  end
end
