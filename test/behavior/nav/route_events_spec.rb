# What the map's touch events do to a route, on the grid stub (the search, the flood and the guide's replay all go
# through Pathfinder.move_target).

# The tiles a route walks through from (x,y), as [x, y] pairs.
def route_tiles(x, y, path)
  PokeAccess::Pathfinder.trace(x, y, 0, path).map { |p| p.tile }
end

Suite.define("route events: a two-way slide carries each facing by its own branch") do
  pf = PokeAccess::Pathfinder
  $game_map.load_grid(["#########",
                       "#...#...#",
                       "#@..#...#",
                       "#########"])
  begin
    World.touch(:id => 50, :x => 3, :y => 2, :list => [World.if_facing(6), World.move_player([3, 3], 1), World.end_])
    World.touch(:id => 51, :x => 5, :y => 1, :list => [World.if_facing(4), World.move_player([2, 2], 1), World.else_,
                                                       World.move_player([3], 1), World.end_])
    pf.invalidate_cache(true)
    eq "the slide takes the route through the wall", pf.find_path(7, 2), [6, 6, 6]
    eq "walked into facing left, the return slide takes its own branch", route_tiles(6, 1, [4]), [[3, 1]]
    eq "walked into any other way it takes the else", route_tiles(5, 2, [8]), [[6, 1]]
  ensure
    World.clear_events
    $game_map.clear_grid
  end
end

Suite.define("route events: while a slide carries the player the step guide keeps quiet") do
  loc = PokeAccess::Locator
  $game_map.load_grid(["##########",
                       "#........#",
                       "#@..#....#",
                       "##########"])
  ivars = [:@steps, :@steps_at, :@steps_leg, :@guide_path, :@guide_from, :@guide_target, :@guide_fresh,
           :@guide_surf, :@guide_gate, :@guide_noroute, :@noroute_key, :@hold_said, :@target]
  saved = ivars.map { |s| loc.instance_variable_get(s) }
  class << $game_player; attr_accessor :move_route_forcing; end
  begin
    ivars.each { |s| loc.instance_variable_set(s, nil) }
    World.touch(:id => 50, :x => 3, :y => 2, :list => [World.if_facing(6), World.move_player([3, 3], 1), World.end_])
    target = World.event(:id => 90, :x => 8, :y => 2, :sprite => "npc")
    PokeAccess::Pathfinder.invalidate_cache(true)
    $game_player.x = 1; $game_player.y = 2
    loc.instance_variable_set(:@target, target)
    loc.instance_variable_set(:@steps, true)
    loc.steps_tick
    $game_player.x = 2
    loc.steps_tick
    SpeakCapture.clear
    $game_player.move_route_forcing = true
    [3, 4].each do |x|
      $game_player.x = x
      loc.steps_tick
    end
    eq "carried across the slide, it says nothing", SpeakCapture.lines, []
    $game_player.move_route_forcing = false
    $game_player.x = 5
    loc.steps_tick
    falsy "and from the landing no leg points back", SpeakCapture.lines.any? { |l| l.include?(PokeAccess::I18n.t(:dir_left)) }
  ensure
    $game_player.move_route_forcing = nil
    class << $game_player; remove_method :move_route_forcing, :move_route_forcing=; end
    ivars.each_index { |i| loc.instance_variable_set(ivars[i], saved[i]) }
    World.clear_events
    $game_map.clear_grid
  end
end

Suite.define("route events: a hedge bumped into hops the player over, and the guide says jump") do
  pf = PokeAccess::Pathfinder
  loc = PokeAccess::Locator
  $game_map.load_grid(["#######",
                       "#@.#..#",
                       "#######"])
  begin
    World.touch(:id => 52, :x => 3, :y => 1, :list => [World.if_facing(6), World.move_player([[14, [2, 0]]], 1),
                                                       World.else_, World.move_player([[14, [-2, 0]]], 1), World.end_])
    pf.invalidate_cache(true)
    eq "the route hops the hedge", pf.find_path(5, 1), [6, 6]
    $game_player.x = 2; $game_player.y = 1
    truthy "the step into the hedge is a jump", loc.jump_step?(6)
    SpeakCapture.clear
    loc.instance_variable_set(:@jump_at, nil)
    loc.announce_jump_step(6)
    eq "and the guide says so", SpeakCapture.lines, [PokeAccess::I18n.t(:loc_jump, :dir => PokeAccess::I18n.t(:dir_right))]
  ensure
    World.clear_events
    $game_map.clear_grid
  end
end

Suite.define("route events: a cutscene is never taken as a shortcut, and a shove back is a wall") do
  pf = PokeAccess::Pathfinder
  $game_map.load_grid(["#######",
                       "#@.#..#",
                       "#######"])
  begin
    World.touch(:id => 53, :x => 3, :y => 1, :list => [TestCmd.new(101, ["¡Alto!"]), World.move_player([[14, [2, 0]]])])
    pf.invalidate_cache(true)
    truthy "a hop inside a cutscene is no route", pf.find_path(5, 1).nil?
  ensure
    World.clear_events
    $game_map.clear_grid
  end
  $game_map.load_grid(["########",
                       "#@.....#",
                       "########"])
  begin
    World.touch(:id => 54, :x => 4, :y => 1, :list => [TestCmd.new(101, ["No puedes pasar"]), World.move_player([13])])
    pf.invalidate_cache(true)
    truthy "a tile that talks and shoves the player back cannot be walked through", pf.find_path(6, 1).nil?
    World.clear_events
    World.touch(:id => 55, :x => 4, :y => 1, :list => [TestCmd.new(101, ["¡Mira!"]), World.move_player([3])])
    pf.invalidate_cache(true)
    eq "one that talks and walks the player on is plain floor to the route", pf.find_path(6, 1), [6, 6, 6, 6]
  ensure
    World.clear_events
    $game_map.clear_grid
  end
end

Suite.define("route events: a warp inside the map is part of the route, when it fires") do
  pf = PokeAccess::Pathfinder
  $game_map.load_grid(["#########",
                       "#@..#...#",
                       "#########"])
  begin
    World.touch(:id => 56, :x => 3, :y => 1, :list => [TestCmd.new(201, [0, $game_map.map_id, 6, 1])])
    pf.invalidate_cache(true)
    eq "stepping on the pad lands across the wall", pf.find_path(7, 1), [6, 6]
    World.clear_events
    World.touch(:id => 57, :x => 3, :y => 1, :list => [World.if_facing(8), TestCmd.new(201, [0, $game_map.map_id, 6, 1], 1), World.end_])
    pf.invalidate_cache(true)
    truthy "a pad that only fires walked into upward is floor from the side", pf.find_path(7, 1).nil?
  ensure
    World.clear_events
    $game_map.clear_grid
  end
end

Suite.define("route events: a doorway out of the map is never crossed on the way somewhere else") do
  pf = PokeAccess::Pathfinder
  $game_map.load_grid(["#######",
                       "#@....#",
                       "#.....#",
                       "#######"])
  begin
    World.touch(:id => 58, :x => 3, :y => 1, :list => [TestCmd.new(201, [0, 55, 1, 1])])
    pf.invalidate_cache(true)
    route = pf.find_path(5, 1)
    truthy "there is a route", !route.nil?
    falsy "and it goes round the doormat", route_tiles(1, 1, route).include?([3, 1])
    World.clear_events
    World.touch(:id => 59, :x => 3, :y => 1, :list => [World.if_facing(8), TestCmd.new(201, [0, 55, 1, 1], 1), World.end_])
    pf.invalidate_cache(true)
    eq "a door that only opens walked into upward is floor crossed sideways", pf.find_path(5, 1), [6, 6, 6]
  ensure
    World.clear_events
    $game_map.clear_grid
  end
end

Suite.define("route events: a one-sided doorway is reached on the side it opens from") do
  pf = PokeAccess::Pathfinder
  $game_map.load_grid(["#######",
                       "#.....#",
                       "#.....#",
                       "#@....#",
                       "#######"])
  begin
    World.touch(:id => 60, :x => 3, :y => 1, :list => [World.if_facing(8), TestCmd.new(201, [0, 55, 1, 1], 1), World.end_])
    pf.invalidate_cache(true)
    route = pf.find_path(3, 1)
    eq "the route ends on the tile below the door", route_tiles(1, 3, route).last, [3, 2]
    $game_player.x = 3; $game_player.y = 2
    eq "standing there, it has arrived", pf.find_path(3, 1), []
  ensure
    World.clear_events
    $game_map.clear_grid
  end
end

Suite.define("route events: an arrow floor hands the player on from tile to tile") do
  pf = PokeAccess::Pathfinder
  $game_map.load_grid(["##########",
                       "#@.......#",
                       "##########"])
  begin
    (3..5).each { |x| World.touch(:id => 60 + x, :x => x, :y => 1, :list => [World.move_player([3])]) }
    pf.invalidate_cache(true)
    eq "each arrow fires as the player crosses it, and the chain ends past the last", spots(pf.trace(2, 1, 0, [6])), [[6, 1, 0]]
    World.clear_events
    World.touch(:id => 63, :x => 3, :y => 1, :list => [World.move_player([3]), TestCmd.new(210, [])])
    World.touch(:id => 64, :x => 4, :y => 1, :list => [World.move_player([3])])
    pf.invalidate_cache(true)
    eq "a page that waits for its move is not handed on", spots(pf.trace(2, 1, 0, [6])), [[4, 1, 0]]
  ensure
    World.clear_events
    $game_map.clear_grid
  end
end

Suite.define("route events: a story block drawn across a path closes all of it") do
  pf = PokeAccess::Pathfinder
  $game_map.load_grid(["#######",
                       "#.....#",
                       "#.....#",
                       "#.....#",
                       "#.....#",
                       "#..@..#",
                       "#######"])
  begin
    back = [TestCmd.new(101, ["¡Espera, no te vayas!"]), World.move_player([22, 12])]
    World.touch(:id => 70, :name => "Vuelve size(5,1)", :x => 1, :y => 3, :list => back)
    pf.invalidate_cache(true)
    truthy "no way past the block", pf.find_path(3, 1).nil?
    World.clear_events
    once = back + [TestCmd.new(121, [5, 5, 0])]
    World.touch(:id => 71, :name => "Escena size(5,1)", :x => 1, :y => 3, :list => once)
    pf.invalidate_cache(true)
    truthy "a scene that switches itself off is walked into, as the story needs", !pf.find_path(3, 1).nil?
  ensure
    World.clear_events
    $game_map.clear_grid
  end
end

Suite.define("route events: a block that moves the player by where they stepped on it reads each tile") do
  pf = PokeAccess::Pathfinder
  $game_map.load_grid(["####",
                       "#..#",
                       "#..#",
                       "#..#",
                       "#..#",
                       "#..#",
                       "#..#",
                       "#@.#",
                       "####"])
  begin
    list = [TestCmd.new(111, [12, "$game_player.x == 1"]), World.move_player([1, 1], 1), World.end_,
            TestCmd.new(111, [12, "$game_player.x == 2"]), World.move_player([1, 1, 2], 1), World.end_]
    World.touch(:id => 72, :name => "Bloqueo size(2,1)", :x => 1, :y => 4, :list => list)
    pf.invalidate_cache(true)
    eq "stepped on at x 1, its own branch sends the player back down", spots(pf.trace(1, 5, 0, [8])), [[1, 6, 0]]
    eq "at x 2, the other one, down and aside", spots(pf.trace(2, 5, 0, [8])), [[1, 6, 0]]
    truthy "so there is no way past it", pf.find_path(1, 1).nil?
  ensure
    World.clear_events
    $game_map.clear_grid
  end
end

Suite.define("route events: a bumped event that asks where the player stands reads the tile they bump from") do
  pf = PokeAccess::Pathfinder
  $game_map.load_grid(["#######",
                       "#@.#..#",
                       "#######"])
  begin
    World.touch(:id => 73, :x => 3, :y => 1, :list => [TestCmd.new(111, [12, "$game_player.x == 2"]),
                                                       World.move_player([[14, [2, 0]]], 1), World.end_])
    pf.invalidate_cache(true)
    eq "bumped from x 2, the hop runs", pf.find_path(5, 1), [6, 6]
  ensure
    World.clear_events
    $game_map.clear_grid
  end
end

Suite.define("route events: a step off the map is no step, whatever the engine says of the map next door") do
  pf = PokeAccess::Pathfinder
  with_tile_world(["#####",
                   "@...#",
                   "#####"]) do
    class << $game_player
      alias_method :edge_spec_passable?, :passable?
      def passable?(x, y, d); d == 4 && x == 0 ? true : edge_spec_passable?(x, y, d); end
    end
    begin
      eq "the connected map beyond the edge is not walked into", spots(pf.trace(0, 1, 0, [4])), []
    ensure
      class << $game_player; remove_method :passable?, :edge_spec_passable?; end
    end
  end
end

Suite.define("route events: partway up a side staircase nothing is searched or remembered") do
  pf = PokeAccess::Pathfinder
  $game_map.load_grid(["#######",
                       "#@....#",
                       "#######"])
  class << $game_player
    attr_accessor :spec_stair
    def on_stair?; @spec_stair; end
  end
  begin
    PokeAccess::Config.route_cache = true
    pf.invalidate_cache(true)
    before = pf.reachable_set
    $game_player.spec_stair = true
    pf.instance_variable_set(:@pcache, {})
    pf.passable_at?(1, 1, 6)
    eq "a passability answer on the stair is not memoised", pf.instance_variable_get(:@pcache), {}
    $game_player.x = 3
    truthy "and the flood from before the stair stands", pf.reachable_set.equal?(before)
  ensure
    $game_player.spec_stair = nil
    class << $game_player; remove_method :on_stair?, :spec_stair, :spec_stair=; end
    $game_map.clear_grid
  end
end

Suite.define("route events: a player walking through walls for a cutscene is routed as if they were not") do
  pf = PokeAccess::Pathfinder
  $game_map.load_grid(["#######",
                       "#@#...#",
                       "#.....#",
                       "#######"])
  class << $game_player
    attr_accessor :through
    alias_method :through_spec_passable?, :passable?
    def passable?(x, y, d); @through ? true : through_spec_passable?(x, y, d); end
  end
  begin
    plain = pf.find_path(4, 1)
    $game_player.through = true
    pf.invalidate_cache(true)
    eq "the route is the one around the wall", pf.find_path(4, 1), plain
    truthy "and the flag is left as it was", $game_player.through
  ensure
    class << $game_player
      remove_method :passable?, :through_spec_passable?, :through, :through=
    end
    $game_map.clear_grid
  end
end
