# HPA* (#12) must reach the TYPICAL target -- an NPC/sign/item on a tile the player cannot enter -- by
# routing to an ADJACENT tile, exactly as A* and JPS do (the shared target_reached? criterion). Before the
# fix its refinement only succeeded ENTERING the exact goal tile, so a solid target always returned :fallback
# and the plain A* ran on top of the wasted hierarchical work. These specs pin the crossing to a blocking
# target across several clusters, prove the walkable-target route is unaffected, and keep a legitimately
# unreachable target falling back.

# hpa_fresh_grid / hpa_arena live in test/support/hpa_helpers.rb (runner-loaded), shared with the
# cache-readonly spec.

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

  # A* on the same blocking target must also arrive adjacent, so this is genuinely routable (the HPA* result
  # is not an artefact) and matches HPA* in reach.
  hpa_fresh_grid(hpa_arena("N"))
  $game_map.events.values.find { |e| e.x == tx && e.y == ty }.blocking = true
  PokeAccess::Config.path_algorithm = :astar
  astar = pf.find_path(tx, ty)
  aok, aex, aey = astar ? hpa_walk(astar, sx, sy) : [false, -1, -1]
  # "Adjacently" was in the label and nowhere in the assertion: the walk was computed and dropped, so a route
  # ending ON the solid tile, or nowhere near it, passed. Same check the HPA* branch already makes.
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
  # The auto-created event on the target tile stays non-blocking, so the tile is walkable.
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

Suite.define("pathfinder: HPA* still falls back when the target is genuinely unreachable") do
  pf = PokeAccess::Pathfinder
  PokeAccess::Config.route_cache = false
  PokeAccess::Config.route_reach = 128
  PokeAccess::Config.astar_max = 5000
  PokeAccess::Config.path_algorithm = :hpa

  # A solid wall column at x=6 fully seals the right region: no gap, so no portal connects the player's
  # component to the target's. The target N at (12,4) has a walkable neighbour, so arrivals are non-empty
  # (the search is not short-circuited) yet no hierarchical route exists -> the legitimate :fallback.
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
