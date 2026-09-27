# The step guide (Ctrl+I) speaks the route a leg at a time, each leg when it is new, silent while it shortens; it
# shares one arrival and one dead end with the cane.

# Aims the step guide at a target with nothing remembered, so the next tick recomputes and speaks.
def steps_aim(loc, target)
  [:@guide_time, :@guide_path, :@guide_from, :@guide_target, :@guide_fresh, :@guide_surf,
   :@noroute_key, :@noroute_cue_at, :@guide_noroute, :@guide_cut, :@jump_at, :@blocked_recheck_at,
   :@steps_at, :@steps_leg, :@leg_seq].each { |s| loc.instance_variable_set(s, nil) }
  loc.instance_variable_set(:@target, target)
  loc.instance_variable_set(:@steps, true)
end

# Runs the block with both guides' ivars saved and restored and the test grid dropped after, and with a $Trainer,
# since guide_tick is silent while Spatial.busy? (no trainer reads as character selection).
def with_step_state
  loc = PokeAccess::Locator
  ivars = [:@guide, :@steps, :@steps_at, :@steps_leg, :@guide_time, :@guide_path, :@guide_from,
           :@guide_target, :@guide_fresh, :@guide_surf, :@guide_noroute, :@guide_cut, :@noroute_key,
           :@noroute_cue_at, :@jump_at, :@blocked_recheck_at, :@target, :@leg_seq]
  prev = ivars.map { |s| loc.instance_variable_get(s) }
  had_trainer = $Trainer
  $Trainer = Object.new
  def $Trainer.name; "Rojo"; end
  yield loc
ensure
  $Trainer = had_trainer
  ivars.each_index { |i| loc.instance_variable_set(ivars[i], prev[i]) }
  $game_map.clear_ledges
  $game_map.clear_grid
end

# Puts the player on a tile, runs one step tick and returns what it said.
def walk_to(loc, x, y)
  $game_player.x = x
  $game_player.y = y
  SpeakCapture.clear
  loc.steps_tick
  SpeakCapture.lines
end

# legs splits a route into runs of one direction, shared by path_to_text and the step guide.
Suite.define("route: legs merge runs of one direction, and the whole phrase is those legs joined") do
  pf = PokeAccess::Pathfinder
  eq "runs merge, order kept", pf.legs([4, 8, 8, 8, 8, 8, 8]), [[4, 1], [8, 6]]
  eq "a route that never turns is one leg", pf.legs([6, 6, 6]), [[6, 3]]
  eq "and a zigzag is all ones", pf.legs([6, 2, 6, 2]), [[6, 1], [2, 1], [6, 1], [2, 1]]
  eq "no route has no legs", pf.legs(nil), []
  eq "nor has an empty one", pf.legs([]), []

  left = PokeAccess::I18n.t(:dir_left)
  up = PokeAccess::I18n.t(:dir_up)
  eq "one leg reads as count then direction", pf.leg_text([8, 6]), "6 #{up}"
  eq "the whole route is the legs, comma separated", pf.path_to_text([4, 8, 8, 8, 8, 8, 8]),
     "1 #{left}, 6 #{up}"
  eq "standing next to the target is not a route", pf.path_to_text([]), PokeAccess::I18n.t(:loc_next_to)
  eq "and no route says so", pf.path_to_text(nil), PokeAccess::I18n.t(:loc_no_route)
end

# A corridor that turns once: the first leg, walking it down, a wrong turn, the corner and the arrival.
Suite.define("step guide: speaks a leg when it is new and holds its tongue while it shortens") do
  hpa_fresh_grid(["##########",
                  "#@.......#",
                  "########.#",
                  "########T#",
                  "##########"])
  with_step_state do |loc|
    target = $game_map.events[1]
    eq "the fixture put the target below the far end of the corridor", [target.x, target.y], [8, 3]
    steps_aim(loc, target)

    pf = PokeAccess::Pathfinder
    first = walk_to(loc, 1, 1)
    leg = pf.legs(loc.instance_variable_get(:@guide_path))[0]
    eq "the route starts with the run along the corridor", leg, [6, 7]
    eq "and the first tick speaks exactly that leg", first, [pf.leg_text([6, 7])]
    eq "queued behind whatever was being said", SpeakCapture.log.last[1], false

    eq "walking a tile of it says nothing: the leg only got shorter", walk_to(loc, 2, 1), []
    eq "nor does the next", walk_to(loc, 3, 1), []

    eq "stepping back the way you came speaks the leg again, longer",
       walk_to(loc, 2, 1), [pf.leg_text([6, 6])]
    eq "cutting the leg before it rather than queueing behind it", SpeakCapture.log.last[1], true

    walk_to(loc, 3, 1)
    PokeAccess.speak("otra cosa", false)
    eq "but a line said since the last leg is not cut: the next leg queues behind it",
       [walk_to(loc, 2, 1), SpeakCapture.log.last[1]], [[pf.leg_text([6, 6])], false]

    (3..7).each { |x| walk_to(loc, x, 1) }
    eq "the far end of the corridor turns, so the new direction is announced",
       walk_to(loc, 8, 1), [pf.leg_text([2, 1])]

    eq "and the tile beside the target ends the journey",
       walk_to(loc, 8, 2), [PokeAccess::I18n.t(:loc_arrived)]
    falsy "which switches the step guide off", loc.instance_variable_get(:@steps)
  end
end

Suite.define("step guide: a route a turned page changes is checked again at once, not after the freshness window") do
  hpa_fresh_grid(["##########",
                  "#@......T#",
                  "#........#",
                  "##########"])
  with_step_state do |loc|
    pf = PokeAccess::Pathfinder
    target = $game_map.events[1]
    floor = World.touch(:id => 81, :x => 5, :y => 1, :list => [TestCmd.new(355, ["pbSEPlay('Crack')"])])
    pf.invalidate_cache(true)
    steps_aim(loc, target)
    walk_to(loc, 1, 1)
    crosses = lambda { |x, y| pf.trace(x, y, 0, loc.instance_variable_get(:@guide_path)).any? { |p| p.tile == [5, 1] } }
    truthy "the route runs along the top row, over the floor at (5,1)", crosses.call(1, 1)
    walk_to(loc, 2, 1)
    hole = TestPage.new(:trigger => 1, :sprite => "", :list => [TestCmd.new(201, [0, $game_map.map_id, 1, 2]), TestCmd.new(0, [])])
    [:@active, :@page].each { |iv| floor.instance_variable_set(iv, hole) }
    floor.instance_variable_set(:@list, hole.list)
    walk_to(loc, 3, 1)
    falsy "once the floor has given way the route no longer steps on it, well inside the freshness window",
          crosses.call(3, 1)
    last = pf.trace(3, 1, 0, loc.instance_variable_get(:@guide_path)).last
    truthy "and it still ends beside the target", last && pf.target_reached?(last.x, last.y, target.x, target.y)
  end
end

# Both guides run off one route: the arrival and a dead end are each said once, not once per guide.
Suite.define("step guide: the cane and the step guide share one arrival and one dead end") do
  hpa_fresh_grid(["#####",
                  "#@.T#",
                  "#####"])
  with_step_state do |loc|
    steps_aim(loc, $game_map.events[1])
    loc.instance_variable_set(:@guide, true)
    $game_player.x = 2
    $game_player.y = 1
    SpeakCapture.clear
    loc.guide_tick
    loc.steps_tick
    eq "arrival is announced once, not once per guide", SpeakCapture.lines,
       [PokeAccess::I18n.t(:loc_arrived)]
    falsy "the cane is off", loc.instance_variable_get(:@guide)
    falsy "and so is the step guide", loc.instance_variable_get(:@steps)
  end

  hpa_fresh_grid(["#####",
                  "#@#T#",
                  "#####"])
  with_step_state do |loc|
    steps_aim(loc, $game_map.events[1])
    loc.instance_variable_set(:@guide, true)
    SpeakCapture.clear
    loc.guide_tick
    loc.steps_tick
    eq "a walled-off target is reported once, by whichever guide got there first",
       SpeakCapture.lines, [PokeAccess::I18n.t(:loc_no_route)]
    SpeakCapture.clear
    loc.guide_tick
    loc.steps_tick
    eq "and never again while nothing has changed", SpeakCapture.lines, []
  end
end

# The two ways the guide is switched on: the key, and the setting that arms it on selecting a target.
Suite.define("step guide: toggling names the target, and the auto setting arms it on selecting one") do
  hpa_fresh_grid(["#####",
                  "#@.T#",
                  "#####"])
  with_step_state do |loc|
    target = $game_map.events[1]
    loc.instance_variable_set(:@target, target)
    loc.instance_variable_set(:@steps, false)

    SpeakCapture.clear
    loc.toggle_steps
    truthy "toggling on starts it", loc.instance_variable_get(:@steps)
    eq "and says where it is taking the player", SpeakCapture.lines,
       [PokeAccess::I18n.t(:loc_steps_to, :name => loc.target_name(target))]

    SpeakCapture.clear
    loc.toggle_steps
    falsy "toggling again stops it", loc.instance_variable_get(:@steps)
    eq "and says so", SpeakCapture.lines, [PokeAccess::I18n.t(:loc_steps_off)]

    had = PokeAccess::Config.auto_steps
    begin
      PokeAccess::Config.auto_steps = false
      loc.auto_steps_on
      falsy "with the setting off, selecting a target arms nothing", loc.instance_variable_get(:@steps)
      PokeAccess::Config.auto_steps = true
      loc.auto_steps_on
      truthy "and with it on, selecting a target starts the guide", loc.instance_variable_get(:@steps)
      eq "with nothing remembered from the last journey", loc.instance_variable_get(:@steps_leg), nil
    ensure
      PokeAccess::Config.auto_steps = had
    end
  end
end

# A nil route from a search stopped short (node budget spent, target beyond its reach) is said as not worked out from
# here; one searched to the end is no route.
Suite.define("route: a search stopped short is not called no route") do
  pf = PokeAccess::Pathfinder
  hpa_fresh_grid(["#######",
                  "#@....#",
                  "#######"])
  cuts = pf.cuts
  truthy "a target in reach is found", pf.find_path(5, 1)
  eq "and no search stopped short", pf.cuts, cuts
  PokeAccess::Config.route_reach = 3
  falsy "beyond the reach there is no route", pf.find_path(5, 1)
  truthy "but it was not looked for: the stop is counted", pf.cuts > cuts
  PokeAccess::Config.route_reach = 128
  PokeAccess::Config.astar_max = 1
  cuts = pf.cuts
  falsy "past the node budget there is none either", pf.find_path(5, 1)
  truthy "and that stop is counted too", pf.cuts > cuts
  eq "said as not worked out from here", pf.path_to_text(nil, true), PokeAccess::I18n.t(:loc_route_gave_up)
  PokeAccess::Config.astar_max = 2500
  hpa_fresh_grid(["#####",
                  "#@#.#",
                  "#####"])
  cuts = pf.cuts
  falsy "a walled-off target has no route", pf.find_path(3, 1)
  eq "searched to the end", pf.cuts, cuts

  hpa_fresh_grid(["######",
                  "#@..T#",
                  "######"])
  PokeAccess::Config.astar_max = 1
  with_step_state do |loc|
    steps_aim(loc, $game_map.events[1])
    SpeakCapture.clear
    loc.steps_tick
    eq "the step guide says so, not no route", SpeakCapture.lines, [PokeAccess::I18n.t(:loc_route_gave_up)]
  end
end
