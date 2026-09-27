# The opt-in JPS and HPA* over the grid harness: valid routes, JPS as short as A*, HPA* near-optimal across clusters.
Suite.define("pathfinder: JPS matches A* on corridor mazes") do
  PokeAccess::Config.route_cache = false
  PokeAccess::Config.route_reach = 128
  PokeAccess::Config.astar_max = 5000

  use_grid = lambda do |rows|
    $game_map.load_grid(rows)
    PokeAccess::Pathfinder.instance_variable_set(:@rs_key, nil)
    PokeAccess::Pathfinder.instance_variable_set(:@pcache_state, nil)
    PokeAccess::Pathfinder.instance_variable_set(:@hpa_sig, nil)
  end

  grids = [["#######", "#@....#", "#.###.#", "#.#...#", "#.#.#.#", "#...#G#", "#######"],
           ["#########", "#@......#", "#######.#", "#.......#", "#.#####.#", "#.#G....#", "#########"]]
  grids.each_with_index do |grid, gi|
    tx = nil; ty = nil
    grid.each_index { |y| (gx = grid[y].index("G")) && (tx = gx; ty = y) }
    use_grid.call(grid); PokeAccess::Config.path_algorithm = :astar
    astar = PokeAccess::Pathfinder.find_path(tx, ty)
    use_grid.call(grid); PokeAccess::Config.path_algorithm = :jps
    jps = without_terrain_rules { PokeAccess::Pathfinder.find_path(tx, ty) }
    truthy "JPS returns a valid route ##{gi}", jps && !jps.empty?
    truthy "JPS is optimal, equal to A* length ##{gi}",
           astar && jps && jps.length == astar.length
  end

  PokeAccess::Config.path_algorithm = :astar
  PokeAccess::Config.route_cache = true
end

# HPA* on a 24x14 arena whose two wall bands, one gap each, force portal crossings between 10-tile clusters: a real,
# walkable route that reaches the goal, near-optimal against A*.
Suite.define("pathfinder: HPA* crosses clusters near-optimally") do
  PokeAccess::Config.route_cache = false
  PokeAccess::Config.route_reach = 128
  PokeAccess::Config.astar_max = 5000

  use_grid = lambda do |rows|
    $game_map.load_grid(rows)
    PokeAccess::Pathfinder.instance_variable_set(:@rs_key, nil)
    PokeAccess::Pathfinder.instance_variable_set(:@pcache_state, nil)
    PokeAccess::Pathfinder.instance_variable_set(:@hpa_sig, nil)
  end
  walk_route = lambda do |route, sx, sy|
    x = sx; y = sy; ok = true
    route.each do |d|
      ok = false unless $game_map.passable?(x, y, d)
      x += (d == 6 ? 1 : (d == 4 ? -1 : 0)); y += (d == 2 ? 1 : (d == 8 ? -1 : 0))
    end
    [ok, x, y]
  end

  big = ["#" * 24]
  (1..12).each do |y|
    row = ""
    (0..23).each do |x|
      row << (
        (x == 0 || x == 23) ? "#" :
        (x == 1 && y == 1) ? "@" :
        (x == 22 && y == 12) ? "G" :
        ((x == 8 && y != 3) || (x == 16 && y != 10)) ? "#" : ".")
    end
    big << row
  end
  big << "#" * 24
  tx = 22; ty = 12
  use_grid.call(big); PokeAccess::Config.path_algorithm = :astar
  big_astar = PokeAccess::Pathfinder.find_path(tx, ty)
  use_grid.call(big); PokeAccess::Config.path_algorithm = :hpa
  sx = $game_player.x; sy = $game_player.y
  hpa = PokeAccess::Pathfinder.hpa_search(tx, ty)
  truthy "HPA* produces a hierarchical route (not fallback)", hpa.is_a?(Array) && !hpa.empty?
  hok, hex, hey = hpa.is_a?(Array) ? walk_route.call(hpa, sx, sy) : [false, -1, -1]
  truthy "HPA* route is walkable and arrives", hok && (hex - tx).abs + (hey - ty).abs <= 1
  truthy "HPA* is near-optimal versus A*",
         big_astar && hpa.is_a?(Array) && hpa.length <= big_astar.length * 1.5 + 4

  PokeAccess::Config.path_algorithm = :astar
  PokeAccess::Config.route_cache = true
end

# JPS fuzz over seeded random wall grids: on every reachable pair its route is as short as A*'s.
Suite.define("pathfinder: JPS fuzz stays optimal on reachable pairs") do
  PokeAccess::Config.route_cache = false
  PokeAccess::Config.route_reach = 128
  PokeAccess::Config.astar_max = 5000

  use_grid = lambda do |rows|
    $game_map.load_grid(rows)
    PokeAccess::Pathfinder.instance_variable_set(:@rs_key, nil)
    PokeAccess::Pathfinder.instance_variable_set(:@pcache_state, nil)
    PokeAccess::Pathfinder.instance_variable_set(:@hpa_sig, nil)
  end
  walk_route = lambda do |route, sx, sy|
    x = sx; y = sy; ok = true
    route.each do |d|
      ok = false unless $game_map.passable?(x, y, d)
      x += (d == 6 ? 1 : (d == 4 ? -1 : 0)); y += (d == 2 ? 1 : (d == 8 ? -1 : 0))
    end
    [ok, x, y]
  end

  srand(20240620)
  jf_runs = 0; jf_ok = 0
  60.times do
    w = 14; h = 14
    rows = []
    h.times do |y|
      row = ""
      w.times { |x| row << ((x == 0 || y == 0 || x == w - 1 || y == h - 1) ? "#" : (rand < 0.25 ? "#" : ".")) }
      rows << row
    end
    floors = []
    rows.each_index { |y| (0...rows[y].length).each { |x| floors << [x, y] if rows[y][x, 1] == "." } }
    next if floors.length < 6
    ps = floors[rand(floors.length)]; ts = floors[rand(floors.length)]
    next if (ps[0] - ts[0]).abs + (ps[1] - ts[1]).abs < 4
    rows[ps[1]] = rows[ps[1]][0, ps[0]] + "@" + (rows[ps[1]][(ps[0] + 1)..-1] || "")
    use_grid.call(rows); PokeAccess::Config.path_algorithm = :astar
    a = PokeAccess::Pathfinder.find_path(ts[0], ts[1])
    next if a.nil?
    aok, axe, aye = walk_route.call(a, ps[0], ps[1])
    next unless aok && (axe - ts[0]).abs + (aye - ts[1]).abs <= 1
    use_grid.call(rows); PokeAccess::Config.path_algorithm = :jps
    j = without_terrain_rules { PokeAccess::Pathfinder.find_path(ts[0], ts[1]) }
    jf_runs += 1
    jok, jxe, jye = j ? walk_route.call(j, ps[0], ps[1]) : [false, -1, -1]
    jf_ok += 1 if jok && (jxe - ts[0]).abs + (jye - ts[1]).abs <= 1 && j.length == a.length
  end
  truthy "JPS fuzz: optimal == A* on every reachable pair (#{jf_ok}/#{jf_runs})",
         jf_runs >= 12 && jf_ok == jf_runs

  PokeAccess::Config.path_algorithm = :astar
  PokeAccess::Config.route_cache = true
end
