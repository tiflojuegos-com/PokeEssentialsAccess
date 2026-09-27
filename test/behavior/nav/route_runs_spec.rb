# Marin's side stairs on the grid stub: Slope events one tile out from each end arm the stair, crossed sideways onto
# the partner's tile; a route counts every press of the run, and the guide stays on it while it is walked.

# A Slope event with its comment, as the plugin reads it.
def runs_slope(id, x, y, a, b)
  World.touch(:id => id, :name => "Slope", :x => x, :y => y, :trigger => 2,
              :list => [TestCmd.new(108, ["Slope: #{a}x#{b}"]), TestCmd.new(108, ["Width: 0/1"])])
end

RUNS_STAIR = ["#########",
              "#########",
              "####....#",
              "#@..#####",
              "#########"]

Suite.define("route runs: a side staircase is crossed in as many presses as it is long") do
  pf = PokeAccess::Pathfinder
  $game_map.load_grid(RUNS_STAIR)
  begin
    runs_slope(80, 2, 3, 3, -1)
    runs_slope(81, 5, 2, -3, 1)
    pf.invalidate_cache(true)
    route = pf.find_path(7, 2)
    eq "one step onto the stair's end, three along it, one off it", route, [6, 6, 6, 6, 6]
    eq "the tiles walked, the stair's own ones marked as on the way",
       pf.trace(1, 3, 0, route).map { |s| [s.x, s.y, s.mid] },
       [[2, 3, false], [3, 3, true], [4, 3, true], [5, 2, false], [6, 2, false]]
    eq "and it is spoken as the presses it takes", pf.path_to_text(route),
       "5 #{PokeAccess::I18n.t(:dir_right)}"
    $game_player.x = 6; $game_player.y = 2
    eq "back down it from the other end, onto the tile beside the target", pf.find_path(1, 3), [4, 4, 4, 4]
  ensure
    World.clear_events
    $game_map.clear_grid
  end
end

Suite.define("route runs: a staircase is taken only the way it goes, and not where the first step is walled") do
  pf = PokeAccess::Pathfinder
  $game_map.load_grid(["#########",
                       "#####...#",
                       "#@.######",
                       "#########"])
  begin
    runs_slope(82, 2, 2, 3, -1)
    pf.invalidate_cache(true)
    truthy "the first step is the map's to allow: walled, there is no stair", pf.find_path(7, 1).nil?
    falsy "and no step counts as its start", pf.step_ok?(2, 2, 6)
  ensure
    World.clear_events
    $game_map.clear_grid
  end
end

Suite.define("route runs: the guide stays on a stair while it is walked, and moves on when it ends") do
  pf = PokeAccess::Pathfinder
  loc = PokeAccess::Locator
  $game_map.load_grid(RUNS_STAIR)
  ivars = [:@guide_path, :@guide_from, :@guide_level]
  saved = ivars.map { |s| loc.instance_variable_get(s) }
  begin
    runs_slope(83, 2, 3, 3, -1)
    pf.invalidate_cache(true)
    loc.instance_variable_set(:@guide_path, [6, 6, 6, 6, 6])
    loc.instance_variable_set(:@guide_from, [1, 3])
    loc.instance_variable_set(:@guide_level, 0)
    truthy "on the stair's end tile the route is walked", loc.advance_guide_path(2, 3)
    eq "and the step onto it dropped", loc.instance_variable_get(:@guide_path), [6, 6, 6, 6]
    truthy "partway along the stair the player is still on the route", loc.advance_guide_path(3, 3)
    eq "with nothing dropped until the stair ends", loc.instance_variable_get(:@guide_path), [6, 6, 6, 6]
    truthy "at its far end", loc.advance_guide_path(5, 2)
    eq "the whole run is behind", loc.instance_variable_get(:@guide_path), [6]
  ensure
    ivars.each_with_index { |s, i| loc.instance_variable_set(s, saved[i]) }
    World.clear_events
    $game_map.clear_grid
  end
end

Suite.define("route runs: only partway up a stair is the map's own answer unreliable") do
  pf = PokeAccess::Pathfinder
  had = $game_player
  pl = Object.new
  def pl.on_stair?; true; end
  def pl.on_middle_of_stair?; @mid; end
  begin
    $game_player = pl
    pl.instance_variable_set(:@mid, false)
    falsy "standing on the stair's end, armed, the map answers as ever", pf.on_stair?
    pl.instance_variable_set(:@mid, true)
    truthy "partway along it, it does not", pf.on_stair?
  ensure
    $game_player = had
  end
end
