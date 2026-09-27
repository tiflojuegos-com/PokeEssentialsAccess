# HPA* reaches a target on a tile the player cannot enter by routing adjacent to it (target_reached?, as A* does),
# still enters a walkable target, and returns :fallback for an unreachable one.

# hpa_fresh_grid and hpa_arena come from test/support/hpa_helpers.rb.

# Walks a step route from (sx,sy) checking each step is passable; returns [all_passable, end_x, end_y].
def hpa_walk(route, sx, sy)
  x = sx; y = sy; ok = true
  route.each do |d|
    ok = false unless $game_map.passable?(x, y, d)
    x += (d == 6 ? 1 : (d == 4 ? -1 : 0)); y += (d == 2 ? 1 : (d == 8 ? -1 : 0))
  end
  [ok, x, y]
end

Suite.define("pathfinder: HPA* reaches a blocking target by routing adjacent, no fallback") do
  pf = PokeAccess::Pathfinder
  PokeAccess::Config.route_cache = false
  PokeAccess::Config.route_reach = 128
  PokeAccess::Config.astar_max = 5000
  PokeAccess::Config.path_algorithm = :hpa

  tx = 22; ty = 12
  hpa_fresh_grid(hpa_arena("N"))
  npc = $game_map.events.values.find { |e| e.x == tx && e.y == ty }
  truthy "the target NPC exists on its tile", !npc.nil?
  npc.blocking = true
  falsy "the target tile is genuinely unenterable (a solid event)", $game_map.passable?(tx, ty - 1, 2)

  sx = $game_player.x; sy = $game_player.y
  route = pf.hpa_search(tx, ty)
  truthy "HPA* returns a real hierarchical route, not :fallback", route.is_a?(Array) && !route.empty?
  ok, ex, ey = route.is_a?(Array) ? hpa_walk(route, sx, sy) : [false, -1, -1]
  truthy "the HPA* route is walkable end to end", ok
  truthy "the HPA* route lands orthogonally adjacent to the blocking target",
         ok && pf.target_reached?(ex, ey, tx, ty)
  falsy "and never stands on the solid target tile itself", ex == tx && ey == ty

  hpa_fresh_grid(hpa_arena("N"))
  $game_map.events.values.find { |e| e.x == tx && e.y == ty }.blocking = true
  PokeAccess::Config.path_algorithm = :astar
  astar = pf.find_path(tx, ty)
  aok, aex, aey = astar ? hpa_walk(astar, sx, sy) : [false, -1, -1]
  truthy "A* also reaches the blocking target adjacently",
         astar && !astar.empty? && aok && pf.target_reached?(aex, aey, tx, ty)
  truthy "the HPA* route is near-optimal versus A* to the blocking target",
         astar && route.is_a?(Array) && route.length <= astar.length * 1.5 + 4

  PokeAccess::Config.path_algorithm = :astar
  PokeAccess::Config.route_cache = true
end

Suite.define("pathfinder: HPA* to a WALKABLE target still enters it (behaviour unchanged)") do
  pf = PokeAccess::Pathfinder
  PokeAccess::Config.route_cache = false
  PokeAccess::Config.route_reach = 128
  PokeAccess::Config.astar_max = 5000
  PokeAccess::Config.path_algorithm = :hpa

  tx = 22; ty = 12
  hpa_fresh_grid(hpa_arena("G"))
  ev = $game_map.events.values.find { |e| e.x == tx && e.y == ty }
  ev.blocking = false if ev
  truthy "the walkable target tile can be entered", $game_map.passable?(tx, ty - 1, 2)

  sx = $game_player.x; sy = $game_player.y
  route = pf.hpa_search(tx, ty)
  truthy "HPA* returns a real route to the walkable target", route.is_a?(Array) && !route.empty?
  ok, ex, ey = route.is_a?(Array) ? hpa_walk(route, sx, sy) : [false, -1, -1]
  truthy "the route is walkable and arrives on/next to the walkable target",
         ok && pf.target_reached?(ex, ey, tx, ty)

  PokeAccess::Config.path_algorithm = :astar
  PokeAccess::Config.route_cache = true
end

# A wall column at x=6 seals off the target, whose walkable neighbour keeps the search from short-circuiting.
Suite.define("pathfinder: HPA* still falls back when the target is genuinely unreachable") do
  pf = PokeAccess::Pathfinder
  PokeAccess::Config.route_cache = false
  PokeAccess::Config.route_reach = 128
  PokeAccess::Config.astar_max = 5000
  PokeAccess::Config.path_algorithm = :hpa

  sealed = []
  sealed << "#" * 15
  (1..8).each do |y|
    row = ""
    (0..14).each do |x|
      row << (
        (x == 0 || x == 14) ? "#" :
        (x == 6) ? "#" :
        (x == 1 && y == 1) ? "@" :
        (x == 12 && y == 4) ? "N" : ".")
    end
    sealed << row
  end
  sealed << "#" * 15

  hpa_fresh_grid(sealed)
  npc = $game_map.events.values.find { |e| e.x == 12 && e.y == 4 }
  truthy "the sealed target NPC exists", !npc.nil?
  npc.blocking = true
  falsy "the sealed target has no walking route (proving it is genuinely unreachable)",
        pf.find_path(12, 4)
  eq "HPA* returns :fallback for the unreachable target", pf.hpa_search(12, 4), :fallback

  PokeAccess::Config.path_algorithm = :astar
  PokeAccess::Config.route_cache = true
end
