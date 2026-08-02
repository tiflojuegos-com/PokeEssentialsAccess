# Standalone pathfinder benchmark. Does NOT touch the shipped pathfinder; it reimplements the same
# A*/flood and the candidate optimizations (#1 skip-flood-when-near, #2 skip-2nd-pass-no-ledges,
# #3 fewer allocations, #5 flood-pruned A*, plus a map-load passability cache) and measures, per
# scenario, the engine-independent work metric (passable? calls) and wall-clock time. passable?
# carries a tunable simulated cost to model the real engine call being far heavier than a lookup.
# Run: ruby test/pathfinder_bench.rb

W = 120; H = 90
REACH = 512
ASTAR_MAX = 5000
PASS_COST = (ENV["PASS_COST"] || "0").to_i   # busy iterations per passable? to model engine cost

# build a large map: border walls, scattered rectangular buildings, and a water strip on the right
# third (for the surf scenario). walkable[y][x] = land you can stand on.
$walk = Array.new(H) { Array.new(W, true) }
$water = Array.new(H) { Array.new(W, false) }
(0...H).each { |y| (0...W).each { |x| $walk[y][x] = false if x == 0 || y == 0 || x == W - 1 || y == H - 1 } }
srand(42)
40.times do
  bx = 2 + rand(W - 12); by = 2 + rand(H - 10); bw = 3 + rand(7); bh = 3 + rand(6)
  (by...[by + bh, H - 1].min).each { |y| (bx...[bx + bw, W - 1].min).each { |x| $walk[y][x] = false } }
end
(70...W).each { |x| (1...H - 1).each { |y| $walk[y][x] = false; $water[y][x] = true } }  # water region (not walkable on foot)
# a sealed 3x3 chamber (unreachable on foot) near the player, for the "near unreachable" case
(40..42).each { |y| (44..46).each { |x| $walk[y][x] = (x == 45 && y == 41) } }  # hollow center, walls around
$walk[40][45] = false; $walk[42][45] = false; $walk[41][44] = false; $walk[41][46] = false

$pcalls = 0
def passable?(x, y, dx, dy)
  $pcalls += 1
  if PASS_COST > 0; s = 0; PASS_COST.times { |i| s += i }; end
  nx = x + dx; ny = y + dy
  return false if nx < 0 || ny < 0 || nx >= W || ny >= H
  $walk[ny][nx]
end

DIRS = [[0, -1], [0, 1], [-1, 0], [1, 0]]

def heap_push(h, it)
  h.push(it); i = h.size - 1
  while i > 0; p = (i - 1) / 2; break if h[p][0] <= h[i][0]; h[p], h[i] = h[i], h[p]; i = p; end
end
def heap_pop(h)
  top = h[0]; last = h.pop
  unless h.empty?
    h[0] = last; i = 0; n = h.size
    loop do
      l = 2 * i + 1; r = 2 * i + 2; s = i
      s = l if l < n && h[l][0] < h[s][0]; s = r if r < n && h[r][0] < h[s][0]
      break if s == i; h[i], h[s] = h[s], h[i]; i = s
    end
  end
  top
end

def pkey(x, y); x * 100000 + y; end

# A*; prune=set restricts expansion to flood-reachable tiles (variant #5). A "#3 light" variant
# (lighter heap nodes) once threaded a flag through here, but its two branches had ended up identical
# -- it measured nothing, so it was removed rather than kept as a lying row.
def astar(px, py, tx, ty, prune = nil)
  return nil if (px - tx).abs + (py - ty).abs > REACH
  h = [[((px - tx).abs + (py - ty).abs), px, py]]
  g = { pkey(px, py) => 0 }; came = {}; closed = {}; iter = 0
  bestk = pkey(px, py); bestd = (px - tx).abs + (py - ty).abs
  until h.empty?
    iter += 1; break if iter > ASTAR_MAX
    cur = heap_pop(h); cx = cur[1]; cy = cur[2]; ck = pkey(cx, cy)
    next if closed[ck]; closed[ck] = true
    md = (cx - tx).abs + (cy - ty).abs
    if md < bestd; bestd = md; bestk = ck; end
    return :ok if md <= 1
    DIRS.each do |d|
      dx = d[0]; dy = d[1]
      next unless passable?(cx, cy, dx, dy)
      nx = cx + dx; ny = cy + dy
      nk = pkey(nx, ny)
      next if prune && !prune[nk]
      next if closed[nk]
      ng = g[ck] + 1
      if g[nk].nil? || ng < g[nk]
        g[nk] = ng; came[nk] = ck
        heap_push(h, [ng + (nx - tx).abs + (ny - ty).abs, nx, ny])
      end
    end
  end
  (bestd <= 2 && bestk != pkey(px, py)) ? :ok : nil
end

def flood(px, py)
  set = { pkey(px, py) => true }; q = [[px, py]]; head = 0; iter = 0; full = true
  while head < q.length
    iter += 1; (full = false; break) if iter > 10000
    c = q[head]; head += 1; cx = c[0]; cy = c[1]
    DIRS.each do |d|
      next unless passable?(cx, cy, d[0], d[1])
      nx = cx + d[0]; ny = cy + d[1]
      next if (nx - px).abs + (ny - py).abs > REACH
      nk = pkey(nx, ny); next if set[nk]
      set[nk] = true; q.push([nx, ny])
    end
  end
  [set, full]
end

NEAR2 = [[0, 0], [1, 0], [-1, 0], [0, 1], [0, -1], [2, 0], [-2, 0], [0, 2], [0, -2], [1, 1], [1, -1], [-1, 1], [-1, -1]]
def blocked?(set, full, tx, ty)
  return false unless full
  !NEAR2.any? { |d| set[pkey(tx + d[0], ty + d[1])] }
end

# find_path under a variant. opts: :flood_gate (#1), :no_ledges (#2: skip 2nd pass), :prune (#5).
# has_ledges models a map with ledge tiles (so the 2nd pass differs).
def find_path(px, py, tx, ty, opts, has_ledges)
  set = nil; full = true
  near = (px - tx).abs + (py - ty).abs <= 20
  do_flood = !(opts[:flood_gate] && near)
  if do_flood
    set, full = flood(px, py)
    return nil if blocked?(set, full, tx, ty)
  end
  prune = (opts[:prune] && set) ? set : nil
  r = astar(px, py, tx, ty, prune)
  return r if r
  # second pass (ledge): skipped by #2 when the map has no ledges (same result)
  return nil if opts[:no_ledges] && !has_ledges
  astar(px, py, tx, ty, prune)
end

PLAYER = [35, 41]
SCEN = {
  "near reachable"   => [45, 48],
  "far reachable"    => [60, 80],
  "far UNreachable"  => [68, 5],     # boxed by water/buildings, no foot route
  "near UNreachable" => [45, 41],    # the sealed chamber center
}
VARIANTS = {
  "baseline"     => {},
  "#1 floodgate" => { :flood_gate => true },
  "#2 noledge"   => { :no_ledges => true },
  "#1+#2"        => { :flood_gate => true, :no_ledges => true },
  "#5 prune"     => { :prune => true },
}

def bench(px, py, tx, ty, opts, reps)
  $pcalls = 0
  t0 = Time.now
  reps.times { find_path(px, py, tx, ty, opts, false) }
  dt = (Time.now - t0) * 1000.0 / reps
  [$pcalls / reps, dt]
end

REPS = 40
puts "Map #{W}x#{H}, reach #{REACH}, astar_max #{ASTAR_MAX}, PASS_COST #{PASS_COST}, #{REPS} reps/avg"
puts "(passable? calls = engine-independent work; ms = on this Ruby, in-game 1.8.7 is slower)\n\n"
SCEN.each do |name, (tx, ty)|
  puts "== #{name} (target #{tx},#{ty}) =="
  printf("  %-14s %10s  %9s\n", "variant", "pass?calls", "ms")
  base = nil
  VARIANTS.each do |vn, opts|
    calls, ms = bench(PLAYER[0], PLAYER[1], tx, ty, opts, REPS)
    base ||= calls
    pct = base > 0 ? (100.0 * calls / base).round : 0
    printf("  %-14s %10d  %9.3f   (%d%% calls)\n", vn, calls, ms, pct)
  end
  puts ""
end
