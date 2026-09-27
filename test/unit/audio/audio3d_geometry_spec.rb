# The soundscape's geometry (core/audio/audio3d.rb): the wall raycast, the side rays of the wind loops and the
# clustering, on the real grid harness ('#' wall, '.' floor, '@' player); no dll involved.

# line_clear? reads occluded only for a wall on the line: not for walls beside it or the emitter's own tile, and a
# detour does not count (a ray, not a flood fill).
Suite.define("audio3d: the wall raycast reports occluded only when a wall really sits on the line") do
  a3d = PokeAccess::Audio3D

  $game_map.load_grid(["#########", "#@......#", "#########"])
  truthy "an open corridor is clear", a3d.line_clear?(1, 1, 7, 1)

  $game_map.load_grid(["#########", "#@..#...#", "#########"])
  falsy "the same corridor with one wall tile on it is occluded", a3d.line_clear?(1, 1, 7, 1)

  $game_map.load_grid(["#########", "#@......#", "##.#.#.##", "#########"])
  truthy "walls beside the line do not occlude it", a3d.line_clear?(1, 1, 7, 1)

  $game_map.load_grid(["###", "#@#", "#.#", "#.#", "###"])
  truthy "a clear vertical line", a3d.line_clear?(1, 1, 1, 3)
  $game_map.load_grid(["###", "#@#", "###", "#.#", "###"])
  falsy "the same line with a wall across it", a3d.line_clear?(1, 1, 1, 3)

  $game_map.load_grid(["#####", "#@C.#", "#####"])
  truthy "an emitter standing on an impassable tile is not self-occluded", a3d.line_clear?(1, 1, 2, 1)
  falsy "but the same counter between player and emitter occludes", a3d.line_clear?(1, 1, 3, 1)

  $game_map.load_grid(["#######", "#@#...#", "#.#...#", "#.....#", "#######"])
  falsy "an emitter reachable only by a detour is occluded, not clear", a3d.line_clear?(1, 1, 5, 1)

  $game_map.clear_grid
end

# The raycast stops at a 48-step guard and past it reports clear, safe only while the farthest configurable emitter
# (KIND_BOUNDS[:tiles]) stays under 48.
Suite.define("audio3d: the raycast guard terminates and never cuts a reachable emitter") do
  a3d = PokeAccess::Audio3D

  wide = ["#" * 64, "#@" + ("." * 50) + "#" + ("." * 10) + "#", "#" * 64]
  $game_map.load_grid(wide)
  truthy "a wall 51 steps away is past the guard, so the ray gives up and reports clear",
         a3d.line_clear?(1, 1, 60, 1)

  near = ["#" * 64, "#@" + ("." * 18) + "#" + ("." * 42) + "#", "#" * 64]
  $game_map.load_grid(near)
  falsy "the same far target with the wall inside the guard is occluded", a3d.line_clear?(1, 1, 60, 1)

  $game_map.load_grid(["###", "#@#", "###"])
  falsy "a walled-in listener aiming far away is occluded at once", a3d.line_clear?(1, 1, 1, 50)

  maxr = PokeAccess::Config::KIND_BOUNDS[:tiles][1]
  truthy "the farthest configurable emitter (#{maxr} tiles) stays inside the 48-step guard", maxr < 48

  $game_map.clear_grid
end

# The side rays: the distance to the nearest wall within audio3d_wall_range, nil when open (its wind loop stops).
Suite.define("audio3d: the side rays measure the distance to the nearest wall, nil when open") do
  a3d = PokeAccess::Audio3D
  prev_range = PokeAccess::Config.audio3d_wall_range
  begin
    PokeAccess::Config.audio3d_wall_range = 3

    $game_map.load_grid(["#######", "#.....#", "#..@..#", "#.....#", "#######"])
    a3d.update_walls($game_player.x, $game_player.y)
    eq "a room measured from its middle", a3d.instance_variable_get(:@wall),
       { :w => 3, :e => 3, :n => 2, :s => 2 }

    $game_map.load_grid(["#####", "#.@.#", "#####"])
    a3d.update_walls($game_player.x, $game_player.y)
    eq "a one-tile corridor hugs the player", a3d.instance_variable_get(:@wall),
       { :w => 2, :e => 2, :n => 1, :s => 1 }

    $game_map.load_grid(["########", "#@.....#", "########"])
    eq "a wall further than wall_range reads open", a3d.ray(1, 1, :e), nil
    eq "while the near side still measures", a3d.ray(1, 1, :w), 1

    PokeAccess::Config.audio3d_wall_range = 1
    eq "a shorter wall_range stops seeing the wall two tiles up", a3d.ray(2, 1, :n), 1
    eq "and the wall two tiles west becomes open", a3d.ray(2, 1, :w), nil
    PokeAccess::Config.audio3d_wall_range = 3
    eq "which the default range does see", a3d.ray(2, 1, :w), 2
  ensure
    PokeAccess::Config.audio3d_wall_range = prev_range
    $game_map.clear_grid
  end
end

# cluster merges 8-connected tiles that share a sprite into one (chained, keeping the nearest tile) and keeps
# different sprites apart. Entries are [x, y, distance, sprite identity].
Suite.define("audio3d: cluster merges one structure but never two different sprites") do
  a3d = PokeAccess::Audio3D
  coords = lambda { |out| out.map { |e| [e[0], e[1]] }.sort }

  eq "an empty list clusters to nothing", a3d.cluster([]), []
  one = [[4, 4, 2, "door"]]
  eq "a single emitter is returned untouched", a3d.cluster(one), one

  row = [[3, 3, 5, "door"], [4, 3, 4, "door"], [5, 3, 3, "door"]]
  merged = a3d.cluster(row)
  eq "three tiles of the same door collapse to one", merged.length, 1
  eq "represented by the tile nearest the player", [merged[0][0], merged[0][1]], [5, 3]

  eq "diagonal neighbours of the same sprite merge", a3d.cluster([[3, 3, 5, "c"], [4, 4, 4, "c"]]).length, 1

  chain =(0..4).map { |i| [i, 7, 9 - i, "counter"] }
  eq "a five-tile run chains into one cluster even though its ends are four apart", a3d.cluster(chain).length, 1

  apart = [[2, 2, 3, "door"], [6, 2, 5, "door"]]
  eq "two groups two tiles apart stay two", coords.call(a3d.cluster(apart)), [[2, 2], [6, 2]]

  crowd = [[4, 4, 3, "boy"], [5, 4, 4, "girl"]]
  eq "two people standing together stay two emitters", coords.call(a3d.cluster(crowd)), [[4, 4], [5, 4]]

  mixed = [[4, 4, 3, "door"], [5, 4, 4, "door"], [5, 5, 6, "boy"]]
  out = a3d.cluster(mixed)
  eq "a person next to a merged door is still counted apart", out.length, 2
  truthy "and the door keeps its nearest tile", out.any? { |e| e[0] == 4 && e[1] == 4 }
end
