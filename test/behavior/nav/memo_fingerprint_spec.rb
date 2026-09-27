# A game declared plain_passability (Fire Ash) keeps its search memos (passability and terrain) across an event's end
# and holds them to the map instead: every search starts by comparing the map's tiles and tileset with the ones the
# memos were filled under. Any other game drops them at an event's end as before.

# Runs a block with the grid map dumping its rows and terrain as its tile data and exposing the tileset readers every
# engine's Game_Map has, the player's passable? and the map's terrain_tag counted, and plain_passability set as given;
# all put back afterwards.
def with_fingerprinted_grid(plain)
  pf = PokeAccess::Pathfinder
  was_plain = pf.instance_variable_get(:@plain_passability)
  asked = []
  tags = []
  class << $game_map
    def data; [@grid, @terrain.to_a.sort]; end
    def passages; @passages; end
    def priorities; nil; end
    def terrain_tags; @terrain_tags; end
    alias_method :print_spec_terrain_tag, :terrain_tag
  end
  $game_map.define_singleton_method(:terrain_tag) { |*a| tags.push(a); print_spec_terrain_tag(*a) }
  class << $game_player; alias_method :print_spec_passable?, :passable?; end
  $game_player.define_singleton_method(:passable?) { |x, y, d| asked.push([x, y, d]); print_spec_passable?(x, y, d) }
  pf.instance_variable_set(:@plain_passability, plain)
  PokeAccess::Config.route_cache = true
  yield asked, tags
ensure
  pf.instance_variable_set(:@plain_passability, was_plain)
  class << $game_player; remove_method :passable?, :print_spec_passable?; end
  class << $game_map; remove_method :data, :passages, :priorities, :terrain_tags, :terrain_tag, :print_spec_terrain_tag; end
  pf.invalidate_cache(true)
  $game_map.clear_grid
end

# An event's end as refresh_on_event_end runs it, past the two-second throttle.
def memo_spec_event_end
  pf = PokeAccess::Pathfinder
  pf.instance_variable_set(:@last_invalidate, nil)
  pf.invalidate_cache
end

# The flood the engine gives with nothing remembered.
def memo_spec_live_flood
  pf = PokeAccess::Pathfinder
  PokeAccess::Config.route_cache = false
  pf.flood(false)[0].keys.sort
ensure
  PokeAccess::Config.route_cache = true
end

Suite.define("memo fingerprint: a plain game keeps its memos past an event's end, answering as the engine does") do
  pf = PokeAccess::Pathfinder
  $game_map.load_grid(["########",
                       "#@.....#",
                       "#..##..#",
                       "########"])
  with_fingerprinted_grid(true) do |asked, tags|
    $game_map.set_terrain(5, 2, 12)
    pf.invalidate_cache(true)
    pf.reachable_set
    route = pf.find_path_onto(6, 2)
    filled = asked.length
    looked = tags.length
    truthy "the first flood and route ask the engine its passability and its terrain", filled > 0 && looked > 0
    memo_spec_event_end
    flood = pf.reachable_set.keys.sort
    eq "after the event's end the same route comes back", pf.find_path_onto(6, 2), route
    eq "and neither the flood nor the route asks anything again", [asked.length, tags.length], [filled, looked]
    eq "the flood is the one the engine gives", flood, memo_spec_live_flood
  end
end

Suite.define("memo fingerprint: a tile or a terrain the map changes is asked again at the next search, event or not") do
  pf = PokeAccess::Pathfinder
  $game_map.load_grid(["########",
                       "#@.....#",
                       "########"])
  with_fingerprinted_grid(true) do |_asked, _tags|
    pf.invalidate_cache(true)
    eq "the corridor is five steps long", pf.find_path_onto(6, 1), [6, 6, 6, 6, 6]
    $game_map.set_terrain(3, 1, 12)
    eq "ice laid on it is slid over at the next search", pf.find_path_onto(6, 1), [6, 6, 6, 6]
    $game_map.instance_variable_get(:@grid)[1] = "#@.#...#"
    pf.instance_variable_set(:@rs_key, nil)
    falsy "and a wall put across it closes it at once", pf.reachable_set[pf.pkey(6, 1)]
    eq "as the engine says", pf.reachable_set.keys.sort, memo_spec_live_flood
  end
end

Suite.define("memo fingerprint: any other game drops the memo at an event's end as before") do
  pf = PokeAccess::Pathfinder
  $game_map.load_grid(["########",
                       "#@.....#",
                       "########"])
  with_fingerprinted_grid(false) do |asked, _tags|
    pf.invalidate_cache(true)
    pf.reachable_set
    filled = asked.length
    memo_spec_event_end
    pf.reachable_set
    eq "the flood after the event's end asks the engine all over", asked.length, 2 * filled
  end
end
