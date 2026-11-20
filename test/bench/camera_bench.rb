# The free camera's cost on a map as big as Insurgence's Torren Region (200x200, 338 events) in the gen6 test engine:
# milliseconds and the engine's passability questions per camera step (first over tiles never asked, then again), a
# long move, the scene read from the camera once it stands still, trails converted (straight, through a wall gone
# round, into a shut room cut there) and the route key from the camera. The engine stub answers in Ruby at once, so the questions count is what to weigh against a real game.
# Run: ruby test/bench/camera_bench.rb
require File.expand_path("../test_helper", File.dirname(__FILE__))

W = 200
H = 200
srand(7)
rows = Array.new(H) { |y| Array.new(W) { |x| x == 0 || y == 0 || x == W - 1 || y == H - 1 ? "#" : "." } }
120.times do
  bx = 3 + rand(W - 14); by = 3 + rand(H - 14); bw = 3 + rand(8); bh = 3 + rand(6)
  (by...(by + bh)).each { |y| (bx...(bx + bw)).each { |x| rows[y][x] = "#" } }
end
rows[100][100] = "@"
(100..199).each { |x| rows[100][x] = "." if x < W - 1 }
(1...(H - 1)).each { |y| rows[y][100] = "." }
$game_map.load_grid(rows.map { |r| r.join })
evs = $game_map.events
338.times do |i|
  x = 1 + rand(W - 2); y = 1 + rand(H - 2)
  next if rows[y][x] == "#" || (y == 100) || (x == 100)
  e = TestEvent.new(i + 1, "EV#{i + 1}", x, y)
  e.blocking = true
  evs[i + 1] = e
end
PokeAccess::World.reset!
$Trainer = Object.new
def $Trainer.name; "Rojo"; end

$asked = 0
class << $game_map
  alias_method :bench_passable, :passable?
  def passable?(*a); $asked += 1; bench_passable(*a); end
end

Cam = PokeAccess::Camera

def measure
  $asked = 0
  t0 = Time.now
  n = yield
  [(Time.now - t0) * 1000.0, $asked, n]
end

def report(name, ms, asked, n)
  puts format("%-44s %8.3f ms total, %7.3f ms and %6.1f questions each (%d)", name, ms, ms / n, asked.to_f / n, n)
end

Cam.reset
Cam.open
ms, q, n = measure { 98.times { Cam.move(6, :step) }; 98 }
report("step east, tiles never asked", ms, q, n)
ms, q, n = measure { 98.times { Cam.move(4, :step) }; 98 }
report("step back west, answers kept", ms, q, n)
ms, q, n = measure { 9.times { Cam.move(2, :long) }; 9 }
report("long moves south", ms, q, n)
sch = PokeAccess::Sound::Scheduler
ms, q, n = measure do
  10.times do |i|
    Cam.move(i.even? ? 8 : 2, :step)
    sch.instance_variable_set(:@scan_pos, nil)
    Cam.instance_variable_set(:@moved, PokeAccess::Frame.serial - Cam::STILL_FRAMES)
    at = Cam.focus
    sch.scan_and_ping(at[0], at[1])
  end
  10
end
report("step and scene read once still", ms, q, n)
ms, q, n = measure do
  10.times do
    PokeAccess::Frame.run_stage(:nav)
    PokeAccess::Frame.run_stage(:sound)
  end
  10
end
report("map frame :nav and :sound, camera open", ms, q, n)
Cam.home
tiles = (100..199).map { |x| [x, 100] }.first(98) + (101..152).map { |y| [197, y] }
tiles = tiles.select { |x, y| x < W - 1 && y < H - 1 }
ms, q, n = measure { PokeAccess::Routes::Trail.convert(tiles, [100, 100, 0]); 1 }
report("trail of #{tiles.length} tiles converted", ms, q, n)
(60..64).each { |y| (120..140).each { |x| rows[y][x] = "#" } }
(20..40).each { |x| rows[20][x] = "#"; rows[40][x] = "#" }
(20..40).each { |y| rows[y][20] = "#"; rows[y][40] = "#" }
$game_map.load_grid(rows.map { |r| r.join })
$game_map.events.clear
PokeAccess::World.reset!
round = (55..70).map { |y| [130, y] }
ms, q, n = measure { PokeAccess::Routes::Trail.convert(round, [130, 55, 0]); 1 }
report("trail through a wall 5 deep, gone round", ms, q, n)
shut = (10..30).map { |x| [x, 30] }
ms, q, n = measure { PokeAccess::Routes::Trail.convert(shut, [10, 30, 0]); 1 }
report("trail into a shut room, cut with no way round", ms, q, n)
ms, q, n = measure { PokeAccess::Routes::Planner.plan_from(100, 150, 0, 160, 100, true); 1 }
report("route key from the camera, 110 tiles away", ms, q, n)
Cam.reset
