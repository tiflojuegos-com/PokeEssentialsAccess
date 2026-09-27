# The passability memo is kept per map, vehicle and bridge level, not per place of the player. Every engine refuses
# the player a step into the tile they stand on (Game_Character#passable?), so that answer must not outlive the step
# off it; any other refusal is the map's and is kept.

# The player's own passable? as the engines have it: a step into the player's tile is refused.
def with_own_tile_refused
  class << $game_player
    alias_method :own_tile_spec_passable?, :passable?
    def passable?(x, y, d)
      dd = PokeAccess::DIR_DELTA[d]
      return false if dd && x + dd[0] == @x && y + dd[1] == @y
      own_tile_spec_passable?(x, y, d)
    end
  end
  yield
ensure
  class << $game_player; remove_method :passable?, :own_tile_spec_passable?; end
end

Suite.define("route memo: the tile the player stood on is open again once they step off it") do
  pf = PokeAccess::Pathfinder
  $game_map.load_grid(["######",
                       "#@...#",
                       "######"])
  with_own_tile_refused do
    begin
      PokeAccess::Config.route_cache = true
      pf.invalidate_cache(true)
      pf.reachable_set
      falsy "the engine refuses the step into the player's own tile", pf.player_passable?(2, 1, 4)
      $game_player.x = 2
      truthy "from the next tile the flood reaches the one just left", pf.reachable_set[pf.pkey(1, 1)]
      truthy "and the step back into it is open", pf.passable_at?(2, 1, 4)
      eq "so the route back to it is one step", pf.find_path_onto(1, 1), [4]
    ensure
      pf.invalidate_cache(true)
      $game_map.clear_grid
    end
  end
end

Suite.define("route memo: a refusal that is the map's own is still remembered") do
  pf = PokeAccess::Pathfinder
  $game_map.load_grid(["######",
                       "#@.#.#",
                       "######"])
  with_own_tile_refused do
    begin
      PokeAccess::Config.route_cache = true
      pf.invalidate_cache(true)
      pf.reachable_set
      key = pf.memo_key(2, 1, 6, 0)
      eq "the wall is kept as refused", pf.instance_variable_get(:@pcache)[key], false
      falsy "while the step into the player's tile is not kept at all",
            pf.instance_variable_get(:@pcache).has_key?(pf.memo_key(2, 1, 4, 0))
    ensure
      pf.invalidate_cache(true)
      $game_map.clear_grid
    end
  end
end
