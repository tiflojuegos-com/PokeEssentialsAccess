# The passability memo follows the map's events between searches (sync_event_memo): an event that changes drops the
# remembered steps into every tile it covers, and so does one that comes or goes.

# The player's passable? with the engine's event rule (v19 Game_Character#passable?, Game_Map#passable?): an event
# that is not through blocks every tile its size covers, right and up from its own, when it shows a sprite or a tile.
def with_sized_events_blocking
  class << $game_player
    alias_method :sized_spec_passable?, :passable?
    def passable?(x, y, d)
      dd = PokeAccess::DIR_DELTA[d]
      nx = x + dd[0]; ny = y + dd[1]
      $game_map.events.each_value do |e|
        next if e.through || (e.character_name.to_s.empty? && e.tile_id.to_i <= 0)
        w = e.instance_variable_get(:@width) || 1
        h = e.instance_variable_get(:@height) || 1
        return false if nx >= e.x && nx < e.x + w && ny > e.y - h && ny <= e.y
      end
      sized_spec_passable?(x, y, d)
    end
  end
  yield
ensure
  class << $game_player; remove_method :passable?, :sized_spec_passable?; end
end

Suite.define("event memo: an event that comes or goes reopens the steps into its tile") do
  pf = PokeAccess::Pathfinder
  $game_map.load_grid(["#######",
                       "#@....#",
                       "#######"])
  with_sized_events_blocking do
    begin
      PokeAccess::Config.route_cache = true
      pf.invalidate_cache(true)
      eq "the corridor is open", pf.find_path_onto(5, 1), [6, 6, 6, 6]
      rock = World.event(:id => 7, :x => 3, :y => 1)
      rock.character_name = "rock"
      eq "an event that appears across it closes it", pf.find_path_onto(5, 1), nil
      $game_map.events.delete(7)
      eq "and once it is gone the corridor opens again", pf.find_path_onto(5, 1), [6, 6, 6, 6]
    ensure
      World.clear_events
      pf.invalidate_cache(true)
      $game_map.clear_grid
    end
  end
end

Suite.define("event memo: a wide event, or a tile graphic, drops the steps into every tile it covers") do
  pf = PokeAccess::Pathfinder
  $game_map.load_grid(["#######",
                       "#@....#",
                       "#######"])
  with_sized_events_blocking do
    begin
      PokeAccess::Config.route_cache = true
      pf.invalidate_cache(true)
      gate = World.event(:id => 8, :x => 2, :y => 1)
      gate.instance_variable_set(:@width, 2)
      gate.instance_variable_set(:@height, 1)
      gate.through = true
      pf.reachable_set
      truthy "while it lets the player through, the step onto its second tile is open", pf.passable_at?(4, 1, 4)
      gate.through = false
      falsy "once it stops, the step onto its second tile is closed",
            pf.with_level_kept { pf.passable_at?(4, 1, 4) }

      pf.invalidate_cache(true)
      $game_map.events.delete(8)
      slab = World.event(:id => 9, :x => 3, :y => 1)
      slab.character_name = ""
      pf.with_level_kept { pf.passable_at?(2, 1, 6) }
      truthy "a sprite-less event is walked over", pf.passable_at?(2, 1, 6)
      slab.tile_id = 400
      falsy "until it takes a tile graphic", pf.with_level_kept { pf.passable_at?(2, 1, 6) }
    ensure
      World.clear_events
      pf.invalidate_cache(true)
      $game_map.clear_grid
    end
  end
end
