# The region map's cursor adapter: the provider is picked by the scene's shape, since Arcky's plugin and the v21+
# rework share the class name PokemonRegionMap_Scene with their cursors in different ivars.
module PaTownRig
  # gen-6 vanilla and Arcky's: @mapX/@mapY, points as raw rows in @map[2].
  class Classic
    attr_accessor :mapX, :mapY, :map, :fly
    def initialize(points, fly)
      @mapX = 0; @mapY = 0; @fly = fly
      @map = [nil, nil, points.map { |x, y| [x, y, "name", "desc", nil, nil, nil, nil] }]
    end
    def pbGetHealingSpot(x, y); @fly.include?([x, y]) ? [1, 2, 3] : nil; end
  end

  # The v21+ rework: @map_x/@map_y, points behind @map.point.
  class Modern
    attr_accessor :map_x, :map_y, :map, :fly
    def initialize(points, fly)
      @map_x = 0; @map_y = 0; @fly = fly
      @map = Struct.new(:point).new(points.map { |x, y| [x, y, "name", "desc", nil, nil, nil, nil] })
    end
    def pbGetHealingSpot(x, y); @fly.include?([x, y]) ? [1, 2, 3] : nil; end
  end

  # v20.1: the snake_case ivars, with the old Array in @map[2].
  class HalfModern
    attr_accessor :map_x, :map_y, :map, :fly
    def initialize(points, fly)
      @map_x = 0; @map_y = 0; @fly = fly
      @map = [nil, nil, points.map { |x, y| [x, y, "name", "desc", nil, nil, nil, nil] }]
    end
    def pbGetHealingSpot(x, y); return nil if !@map[2]; @fly.include?([x, y]) ? [1, 2, 3] : nil; end
  end

  # A scene no built-in provider understands.
  class Exotic
    attr_accessor :spot
    def initialize; @spot = [0, 0]; end
  end
end

Suite.define("town map: the cursor provider is chosen by SHAPE, not by class name or era") do
  classic = PaTownRig::Classic.new([[1, 1], [5, 1]], [[5, 1]])
  modern  = PaTownRig::Modern.new([[2, 2], [9, 2]], [[9, 2]])

  eq "the gen-6 / Arcky shape is recognised by its cursor ivar",
     PokeAccess::TownMap.provider_for(classic)[0], :classic
  eq "and the v21+ shape by its own, despite sharing a class name with Arcky",
     PokeAccess::TownMap.provider_for(modern)[0], :ui_rework
  eq "a scene neither understands gets no provider", PokeAccess::TownMap.provider_for(PaTownRig::Exotic.new), nil

  eq "the cursor is read from whichever shape it is", PokeAccess::TownMap.cursor(classic), [0, 0]
  truthy "and moving it writes the right ivars", PokeAccess::TownMap.move(classic, 4, 7)
  eq "the classic scene really moved", [classic.mapX, classic.mapY], [4, 7]
  PokeAccess::TownMap.move(modern, 3, 6)
  eq "the modern scene really moved", [modern.map_x, modern.map_y], [3, 6]

  falsy "an unknown shape refuses to move rather than pretending",
        PokeAccess::TownMap.move(PaTownRig::Exotic.new, 1, 1)
  eq "and offers no points", PokeAccess::TownMap.points(PaTownRig::Exotic.new), []

  eq "points come from @map[2] in the classic shape", PokeAccess::TownMap.points(classic), [[1, 1], [5, 1]]
  eq "and from @map.point in the modern one", PokeAccess::TownMap.points(modern), [[2, 2], [9, 2]]

  half = PaTownRig::HalfModern.new([[3, 3], [7, 3]], [[7, 3]])
  eq "the half-modern shape is still the modern provider",
     PokeAccess::TownMap.provider_for(half)[0], :ui_rework
  eq "and its points are found in the Array it really keeps",
     PokeAccess::TownMap.points(half), [[3, 3], [7, 3]]

  eq "only the points the game says can be flown to are candidates",
     PokeAccess::TownMap.fly_points(classic), [[5, 1]]
end

# A provider a profile registers wins over the built-in ones, the latest one first (profiles load after the core).
Suite.define("town map: a profile's own provider wins over the built-in ones") do
  before = PokeAccess::TownMap.providers.length
  begin
    PokeAccess::TownMap.register(
      :spec_exotic,
      lambda { |s| s.respond_to?(:spot) },
      lambda { |s| s.spot },
      lambda { |s, x, y| s.spot = [x, y] },
      lambda { |_s| [[7, 7]] }
    )
    exotic = PaTownRig::Exotic.new
    eq "the scene nobody understood is now handled",
       PokeAccess::TownMap.provider_for(exotic)[0], :spec_exotic
    truthy "and it moves through the profile's own code", PokeAccess::TownMap.move(exotic, 8, 9)
    eq "which really moved it", exotic.spot, [8, 9]

    PokeAccess::TownMap.register(
      :spec_later, lambda { |_s| true }, lambda { |_s| [0, 0] }, lambda { |_s, _x, _y| nil }, lambda { |_s| [] }
    )
    eq "the newest provider that handles the scene is the one used",
       PokeAccess::TownMap.provider_for(PaTownRig::Classic.new([], []))[0], :spec_later
  ensure
    PokeAccess::TownMap.providers.slice!(before, PokeAccess::TownMap.providers.length - before)
  end
end

# The jump target: the nearest point ahead that way, drifting a row if closer (on purpose: exact alignment would skip
# most places on a sparse map); a tie goes to the smaller sideways drift.
Suite.define("town map: the jump lands on the nearest flyable point in that direction, never behind") do
  pts = [[2, 5], [8, 5], [5, 1], [5, 9], [5, 5], [4, 4]]
  tm = PokeAccess::TownMap

  eq "right takes the next one to the right", tm.nearest(pts, 5, 5, :right), [8, 5]
  eq "down takes the next one below", tm.nearest(pts, 5, 5, :down), [5, 9]

  eq "left takes the CLOSEST one leftward, even if it drifts a row", tm.nearest(pts, 5, 5, :left), [4, 4]
  eq "and up likewise", tm.nearest(pts, 5, 5, :up), [4, 4]
  eq "with the drifting one gone, the aligned one is next",
     tm.nearest(pts - [[4, 4]], 5, 5, :left), [2, 5]

  eq "the point you are standing on is never the answer", tm.nearest([[5, 5]], 5, 5, :right), nil
  eq "and neither is one behind you", tm.nearest([[2, 5]], 5, 5, :right), nil
  eq "no candidates at all is a clean nil", tm.nearest([], 5, 5, :up), nil

  eq "a tie ahead breaks towards the smaller sideways drift",
     tm.nearest([[8, 9], [8, 5]], 5, 5, :right), [8, 5]
  eq "distance beats alignment, so it never skips a closer one",
     tm.nearest([[6, 9], [8, 5]], 5, 5, :right), [6, 9]
end

# The jump moves the game's cursor and leaves the announcement to the map; the flyable list is cached per opening.
Suite.define("town map: the jump moves the game's own cursor and lets the map announce it") do
  scene = PaTownRig::Classic.new([[1, 5], [8, 5], [5, 5]], [[1, 5], [8, 5]])
  begin
    PokeAccess::TownMap.opened(scene)
    eq "the open scene is tracked, which is what frees J K L I here",
       PokeAccess::TownMap.open_scene.equal?(scene), true

    PokeAccess::TownMap.move(scene, 5, 5)
    SpeakCapture.clear
    truthy "jumping right lands on the flyable point", PokeAccess::TownMap.jump(scene, :right)
    eq "and it moved the GAME's cursor, so confirming flies there", [scene.mapX, scene.mapY], [8, 5]
    eq "the jump itself says nothing: the map's own loop announces the new square",
       SpeakCapture.log.length, 0

    scene.fly = [[1, 5], [8, 5], [5, 5]]
    PokeAccess::TownMap.move(scene, 1, 5)
    PokeAccess::TownMap.jump(scene, :right)
    eq "while the map stays open the cached list is kept, so the new spot is skipped",
       [scene.mapX, scene.mapY], [8, 5]
    PokeAccess::TownMap.closed(scene)
    PokeAccess::TownMap.opened(scene)
    PokeAccess::TownMap.move(scene, 1, 5)
    PokeAccess::TownMap.jump(scene, :right)
    eq "reopening recomputes it, and now the middle spot is flyable",
       [scene.mapX, scene.mapY], [5, 5]
    scene.fly = [[1, 5], [8, 5]]
    PokeAccess::TownMap.closed(scene)
    PokeAccess::TownMap.opened(scene)
    PokeAccess::TownMap.move(scene, 8, 5)

    SpeakCapture.clear
    falsy "with nothing further right, it does not move", PokeAccess::TownMap.jump(scene, :right)
    eq "the cursor stayed put", [scene.mapX, scene.mapY], [8, 5]
    truthy "and it said so", SpeakCapture.log.length > 0

    PokeAccess::TownMap.closed(scene)
    eq "closing the map releases the keys back to the locator", PokeAccess::TownMap.open_scene, nil
    falsy "and a jump with no open scene does nothing", PokeAccess::TownMap.jump(nil, :left)
  ensure
    PokeAccess::TownMap.closed(scene)
  end
end

# A profile can turn the jump off (jump_enabled): it then neither moves the cursor nor speaks.
Suite.define("town map: a profile can turn the jump off where the game already does it better") do
  scene = PaTownRig::Classic.new([[1, 5], [8, 5]], [[1, 5], [8, 5]])
  begin
    PokeAccess::TownMap.opened(scene)
    PokeAccess::TownMap.move(scene, 5, 5)
    PokeAccess::TownMap.jump_enabled = false
    SpeakCapture.clear
    falsy "the jump refuses when the profile disabled it", PokeAccess::TownMap.jump(scene, :right)
    eq "without moving the cursor", [scene.mapX, scene.mapY], [5, 5]
    eq "and without speaking a 'nothing that way' that would only confuse", SpeakCapture.log.length, 0
  ensure
    PokeAccess::TownMap.jump_enabled = true
    PokeAccess::TownMap.closed(scene)
  end
end

# Armonia's two maps side by side, panned under a cursor in window squares: the fly points of both, shifted by their
# pan. Only the profile's module is evaluated (this repo's file): the whole file would register a lasting provider.
Suite.define("town map: armonia's two panned maps, jumped in window squares") do
  path = File.join(Harness::ROOT, "games", "armonia", "fly_map.rb")
  eval(File.read(path)[/^module PokeAccess\r?\n.*?^end\r?\n/m], TOPLEVEL_BINDING, path) unless defined?(PokeAccess::ArmoniaMap)
  klass = Class.new do
    attr_accessor :sprites
    def transformX(x); x; end
    def pbGetHealingSpot(map, x, y)
      pt = map[2].find { |p| p[0] == x && p[1] == y }
      pt && pt[4] ? [pt[4], pt[5], pt[6]] : nil
    end
  end
  { :LEFT => 0, :RIGHT => 29, :TOP => 0, :BOTTOM => 19, :SQUAREWIDTH => 16, :SQUAREHEIGHT => 16 }.each { |k, v| klass.const_set(k, v) }
  map1 = [nil, nil, [[5, 5, "Pueblo", "", 11, 5, 6], [9, 2, "Ruta", ""]]]
  map2 = [nil, nil, [[2, 3, "Isla", "", 12, 2, 3]]]
  s = klass.new
  s.sprites = { "cursor" => Struct.new(:x, :y).new(0, 0) }
  { :@map1 => map1, :@map2 => map2, :@map => map1, :@mapX => 0, :@mapY => 0, :@map1TransformX => 0,
    :@map1TransformY => 0, :@map2TransformX => 30, :@map2TransformY => 4 }.each { |k, v| s.instance_variable_set(k, v) }
  am = PokeAccess::ArmoniaMap
  eq "unpanned: map one's places where they are, map two's beyond the window", am.flyable(s), [[5, 5]]
  s.instance_variable_set(:@map1TransformX, 25)
  s.instance_variable_set(:@map2TransformX, 5)
  eq "panned right: map two's place comes into the window, shifted by its pan", am.flyable(s), [[7, 7]]
  am.move(s, 7, 7)
  eq "landing puts the cursor on that place's map, in window squares",
     [s.instance_variable_get(:@mapindex), s.instance_variable_get(:@mapX), s.instance_variable_get(:@mapY)], [1, 7, 7]
  eq "and the cursor where the screen draws that square",
     [s.sprites["cursor"].x, s.sprites["cursor"].y], [120, 136]
end

# Both of Armonia's maps number their squares from 0, so the other map has a square with the player's coordinates,
# and its pbStartScene asks pbGetMapLocation for the window's square, wrong on the second map. The profile's Game.define
# block (this repo's fly_map.rb) evaluated over the stubs' PokemonRegionMapScene: its @build stands for Armonia's, and
# its original pbGetMapLocation answers the place of the square on the map shown. What the block registers is taken
# back after.
Suite.define("town map: armonia's profile leaves the build unsaid and keeps the player's mark on the head's map") do
  path = File.join(Harness::ROOT, "games", "armonia", "fly_map.rb")
  src = File.read(path)
  eval(src[/^module PokeAccess\r?\n.*?^end\r?\n/m], TOPLEVEL_BINDING, path) unless defined?(PokeAccess::ArmoniaMap)
  block = src[/^PokeAccess::Game\.define\("armonia"\) do\r?\n.*?^end\r?\n/m]
  truthy "the profile's block is found", !block.nil?
  t = PokeAccess::I18n
  rm = PokeAccess::RegionMap
  chain = PokeAccess::Hooks.instance_variable_get(:@chains)["PokemonRegionMapScene#pbStartScene"]
  kept = chain.dup
  square = rm.method(:player_square?)
  listed = PokeAccess::Hooks.overrides.length
  profiles = PokeAccess::Game.profiles.dup
  wiel = [nil, nil, [[5, 10, "Ciudad Wiel", ""]]]
  east = [nil, nil, []]
  s = PokemonRegionMapScene.new
  s.instance_variable_set(:@build, lambda do |sc, _a|
    sc.instance_variable_set(:@sprites, { "player" => Object.new })
    { :@map1 => wiel, :@map2 => east, :@map => wiel }.each { |k, v| sc.instance_variable_set(k, v) }
    sc.pbGetMapLocation(5, 10)
  end)
  s.define_singleton_method(:pbGetMapLocation__pa_orig_PokemonRegionMapScene) do |x, y|
    pt = @map[2].find { |p| p[0] == x && p[1] == y }
    pt ? pt[2] : ""
  end
  begin
    eval(block.to_s, TOPLEVEL_BINDING, path)
    SpeakCapture.clear
    s.pbStartScene
    silent "the build's own ask for the square is left unsaid"
    s.pbGetMapLocation(5, 10)
    eq "the loop's first square, on the head's map, is the player's", SpeakCapture.lines, ["Ciudad Wiel, #{t.t(:rmap_you)}"]
    s.instance_variable_set(:@map, east)
    s.pbGetMapLocation(5, 9)
    SpeakCapture.clear
    s.pbGetMapLocation(5, 10)
    eq "the other map's square with the same coordinates is not", SpeakCapture.lines,
       [t.t(:brm_square, :x => 5, :y => 10)]
    s.instance_variable_set(:@map, wiel)
    s.pbGetMapLocation(5, 9)
    SpeakCapture.clear
    s.pbGetMapLocation(5, 10)
    eq "and back on the head's map it is again", SpeakCapture.lines, ["Ciudad Wiel, #{t.t(:rmap_you)}"]
    plain = Object.new
    plain.instance_variable_set(:@access_player_sq, [3, 4])
    truthy "a map screen with no head map kept answers as the core does", rm.player_square?(plain, 3, 4)
  ensure
    s.pbEndScene
    chain.replace(kept)
    rm.define_singleton_method(:player_square?, square)
    PokeAccess::Hooks.overrides.slice!(listed..-1)
    PokeAccess::Game.profiles.replace(profiles)
    PokeAccess::Game.instance_variable_set(:@profile_name, nil)
  end
end
