# The step guide (Ctrl+I): the route spoken one leg at a time, the next only once this one is walked. The
# rule the whole feature rests on is that an instruction is spoken when it is NEW, and that is what is
# pinned here, because both ways of getting it wrong pass a green suite silently: repeat the leg on every
# tile and the guide natters over the game; skip a leg that merely got longer after a wrong turn and it
# goes quiet at the exact moment the player is lost.
#
# The second thing pinned is that the two guides share one ending. The cane and the step guide walk the
# same route and reach the target on the same frame, so without a shared stop the player hears "you have
# arrived" twice, and the same for "no route".

# Aims the step guide at a target with nothing remembered, so the next tick recomputes and speaks.
def steps_aim(loc, target)
  [:@guide_time, :@guide_path, :@guide_from, :@guide_target, :@guide_fresh, :@guide_surf,
   :@noroute_key, :@noroute_cue_at, :@guide_noroute, :@jump_at, :@blocked_recheck_at,
   :@steps_at, :@steps_leg].each { |s| loc.instance_variable_set(s, nil) }
  loc.instance_variable_set(:@target, target)
  loc.instance_variable_set(:@steps, true)
end

# Runs the block with every ivar either guide touches saved, then restores them and drops the test grid, so
# a suite cannot leave a guide switched on. It also lends the world a trainer for the duration: guide_tick
# is gated on Spatial.busy?, and with the gen-6 stub's $Trainer = nil the mod believes the player is still
# on the character-selection screen and the cane stays silent for the wrong reason.
def with_step_state
  loc = PokeAccess::Locator
  ivars = [:@guide, :@steps, :@steps_at, :@steps_leg, :@guide_time, :@guide_path, :@guide_from,
           :@guide_target, :@guide_fresh, :@guide_surf, :@guide_noroute, :@noroute_key, :@noroute_cue_at,
           :@jump_at, :@blocked_recheck_at, :@target]
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

# The split both readers share. path_to_text used to count the runs itself; the step guide needs the same
# count for the head leg alone, and two copies of "where does the corner fall" would drift.
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

# The corridor turns once, so the route is exactly two legs and every interesting moment falls on it: the
# first instruction, walking it down, a wrong turn, the corner, and arriving.
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

    eq "walking a tile of it says nothing: the leg only got shorter", walk_to(loc, 2, 1), []
    eq "nor does the next", walk_to(loc, 3, 1), []

    eq "stepping back the way you came speaks the leg again, longer",
       walk_to(loc, 2, 1), [pf.leg_text([6, 6])]

    (3..7).each { |x| walk_to(loc, x, 1) }
    eq "the far end of the corridor turns, so the new direction is announced",
       walk_to(loc, 8, 1), [pf.leg_text([2, 1])]

    eq "and the tile beside the target ends the journey",
       walk_to(loc, 8, 2), [PokeAccess::I18n.t(:loc_arrived)]
    falsy "which switches the step guide off", loc.instance_variable_get(:@steps)
  end
end

# Both guides run off one route, so both reach the same arrival and the same dead end on the same frame.
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
