# The region map's cursor adapter, the one thing the three implementations do NOT share.
#
# The stubs copy the three real shapes on purpose, including the trap: Arcky's plugin (royal) and the v21+
# UI rework both name their class PokemonRegionMap_Scene, and their cursors live in DIFFERENT ivars. A
# dispatcher that trusted the class name -- or the engine era -- would drive the wrong one, so these suites
# pin that the choice is made by asking the scene what it actually has.
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

  # A scene no built-in provider understands, for the artistic fangames that rewrite the whole screen.
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

  # Flyable is the GAME's answer, not ours: a point with no healing spot is not offered even though it is
  # a perfectly good point on the map.
  eq "only the points the game says can be flown to are candidates",
     PokeAccess::TownMap.fly_points(classic), [[5, 1]]
end

# A profile must be able to take over: fangames rewrite this screen with sprites, zoom and custom tables.
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

    # Registered later = wins, because profiles load after the core.
    PokeAccess::TownMap.register(
      :spec_later, lambda { |_s| true }, lambda { |_s| [0, 0] }, lambda { |_s, _x, _y| nil }, lambda { |_s| [] }
    )
    eq "the newest provider that handles the scene is the one used",
       PokeAccess::TownMap.provider_for(PaTownRig::Classic.new([], []))[0], :spec_later
  ensure
    PokeAccess::TownMap.providers.slice!(before, PokeAccess::TownMap.providers.length - before)
  end
end

# Choosing WHERE to jump. Pure arithmetic, and the part that decides whether the feature helps or disorients.
Suite.define("town map: the jump lands on the nearest flyable point in that direction, never behind") do
  pts = [[2, 5], [8, 5], [5, 1], [5, 9], [5, 5], [4, 4]]
  tm = PokeAccess::TownMap

  eq "right takes the next one to the right", tm.nearest(pts, 5, 5, :right), [8, 5]
  eq "down takes the next one below", tm.nearest(pts, 5, 5, :down), [5, 9]

  # [4,4] is one step left AND one step up, so it is the nearest thing in BOTH those directions and it
  # wins over the aligned-but-distant [2,5] and [5,1]. That is deliberate: on a map the player cannot see,
  # "the closest thing that way" is more useful than "the closest thing exactly in this row", which on a
  # sparse map would skip most places. Landing is always announced by name, so a diagonal step is heard.
  eq "left takes the CLOSEST one leftward, even if it drifts a row", tm.nearest(pts, 5, 5, :left), [4, 4]
  eq "and up likewise", tm.nearest(pts, 5, 5, :up), [4, 4]
  eq "with the drifting one gone, the aligned one is next",
     tm.nearest(pts - [[4, 4]], 5, 5, :left), [2, 5]

  eq "the point you are standing on is never the answer", tm.nearest([[5, 5]], 5, 5, :right), nil
  eq "and neither is one behind you", tm.nearest([[2, 5]], 5, 5, :right), nil
  eq "no candidates at all is a clean nil", tm.nearest([], 5, 5, :up), nil

  # The tie-break is what keeps a row walkable: two points the same distance ahead, the straighter one wins.
  eq "a tie ahead breaks towards the smaller sideways drift",
     tm.nearest([[8, 9], [8, 5]], 5, 5, :right), [8, 5]
  eq "distance beats alignment, so it never skips a closer one",
     tm.nearest([[6, 9], [8, 5]], 5, 5, :right), [6, 9]
end

# The jump itself: lifecycle, the cache, the profile opt-out, and the one thing it must NOT do.
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

    # The flyable list is computed ONCE per opening (pbGetHealingSpot walks the whole point table), so the
    # invalidation on open and on close is load-bearing: the next map the player opens has other towns, and
    # a cache carried over would jump to a square that is not flyable there. Nothing asserted it before.
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

    # Nothing that way is not silence: the player pressed a key and must know it did nothing.
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

# A profile must be able to stand aside: royal's map already lists the fly spots BY NAME, which is better
# than jumping blind, and two ways to do the same thing on one screen is worse than one good way.
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
