# Ice: a step onto ice carries the search to where the slide stops (the first floor past it, or the last ice before
# a wall), and step_target returns that end.
Suite.define("pathfinder: ice slide stops at floor or last ice before a wall") do
  ice_map = Class.new do
    attr_reader :map_id
    def initialize; @map_id = 777; end
    def terrain_tag(x, y, *_); (y == 3 && x >= 2 && x <= 5) ? 12 : 0; end
    def valid?(x, y); x >= 0 && y >= 0 && x < 9 && y < 7; end
    def width; 9; end
    def height; 7; end
  end
  ice_player = Class.new do
    attr_accessor :x, :y, :far
    def initialize(far); @x = 1; @y = 3; @far = far; end
    def floor?(x, y); y == 3 && x >= 1 && x <= @far; end
    def passable?(x, y, d)
      dl = { 8 => [0, -1], 2 => [0, 1], 4 => [-1, 0], 6 => [1, 0] }[d]
      dl ? floor?(x + dl[0], y + dl[1]) : false
    end
  end

  old_map = $game_map; old_pl = $game_player
  $game_map = ice_map.new; $game_player = ice_player.new(6)
  PokeAccess::Pathfinder.instance_variable_set(:@pcache_state, nil)
  slide = PokeAccess::Pathfinder.ice_slide(2, 3, 1, 0, 6)
  eq "slide stops at the first floor past the ice", slide, [6, 3]
  st = PokeAccess::Pathfinder.step_target(1, 3, [1, 0, 6], false, false)
  eq "step_target returns the slide end", st, [6, 3]

  $game_player = ice_player.new(5)
  PokeAccess::Pathfinder.instance_variable_set(:@pcache_state, nil)
  slide2 = PokeAccess::Pathfinder.ice_slide(2, 3, 1, 0, 6)
  eq "slide stops at the last ice when a wall blocks", slide2, [5, 3]

  $game_map = old_map; $game_player = old_pl
end

# A bridge map on two levels: the search carries the level its ramps set (pbBridgeOn/Off), and the player's is put
# back even on a raise. Deck: row 3, x 2-5; On ramps at x 1 and 6, Off at 0 and 7; a path under it at x 3.
Suite.define("pathfinder: a bridge map is walked on two levels, and the player's level is put back") do
  bridge_map = Class.new do
    attr_accessor :map_id, :events
    def initialize; @map_id = 778; @events = {}; end
    def terrain_tag(*_); 0; end
    def valid?(x, y); x >= 0 && y >= 0 && x < 9 && y < 7; end
    def width; 9; end
    def height; 7; end
    def deck?(x, y); y == 3 && x >= 2 && x <= 5; end
    def stand?(x, y, lvl)
      return lvl > 0 || x == 3 if deck?(x, y)
      (y == 3 && x >= 0 && x <= 7) || (x == 3 && y >= 0 && y <= 6)
    end
    def passable?(x, y, d)
      lvl = ($PokemonGlobal.bridge rescue 0).to_i
      dl = { 8 => [0, -1], 2 => [0, 1], 4 => [-1, 0], 6 => [1, 0] }[d]
      return stand?(x, y, lvl) if dl.nil?
      nx = x + dl[0]; ny = y + dl[1]
      return false unless stand?(nx, ny, lvl)
      vertical = (d == 2 || d == 8)
      return !vertical if lvl > 0 && (deck?(nx, ny) || deck?(x, y))
      return vertical if lvl == 0 && ([nx, ny] == [3, 3] || [x, y] == [3, 3])
      true
    end
  end
  bridge_player = Class.new do
    attr_accessor :x, :y, :through
    def initialize; @x = 0; @y = 3; end
    def passable?(x, y, d); $game_map.passable?(x, y, d); end
  end

  pf = PokeAccess::Pathfinder
  old_map = $game_map; old_pl = $game_player
  had = $PokemonGlobal.bridge
  $game_map = bridge_map.new; $game_player = bridge_player.new
  begin
    $PokemonGlobal.bridge = 0
    PokeAccess::Config.route_reach = 128; PokeAccess::Config.astar_max = 5000
    ramp = lambda { |id, x, s| World.touch(:id => id, :x => x, :y => 3, :list => [TestCmd.new(355, [s])]) }
    ramp.call(1, 1, "pbBridgeOn"); ramp.call(2, 6, "pbBridgeOn"); ramp.call(3, 0, "pbBridgeOff"); ramp.call(4, 7, "pbBridgeOff")
    pf.invalidate_cache(true)
    route = pf.find_path(7, 3)
    eq "the route climbs the ramp and crosses the deck", route, [6, 6, 6, 6, 6, 6]
    eq "and the player's own level is put back", $PokemonGlobal.bridge, 0

    $game_player.x = 3; $game_player.y = 1
    pf.invalidate_cache(true)
    eq "under the bridge the ground is walked at level 0", pf.find_path(3, 5), [2, 2, 2]
    eq "a search that another left on the deck still starts from the player's level",
       pf.searching { pf.use_level(2); [pf.bridge_level, pf.find_path_to(3, 5, false)] }, [0, [2, 2, 2]]
    eq "and the passability memo keeps each level's own answer",
       pf.searching { pf.use_level(0); a = pf.passable_at?(3, 2, 2); pf.use_level(2); [a, pf.passable_at?(3, 2, 2)] },
       [true, false]

    $game_map.events.clear
    $game_player.x = 0; $game_player.y = 3
    pf.invalidate_cache(true)
    truthy "without a ramp the deck is out of reach, as it is in the game", pf.find_path(7, 3).nil?

    ramp.call(1, 1, "pbBridgeOn")
    pf.invalidate_cache(true)
    raised = false
    begin
      pf.with_level_kept { pf.use_level(2); raise "boom" }
    rescue StandardError
      raised = true
    end
    truthy "the level is put back even when the search raises", raised && $PokemonGlobal.bridge == 0
  ensure
    $PokemonGlobal.bridge = had
    $game_map = old_map; $game_player = old_pl
    pf.invalidate_cache(true)
  end
end
