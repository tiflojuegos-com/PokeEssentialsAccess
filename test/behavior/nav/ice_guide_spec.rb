# Ice and the two guides: a slide is one route step landing where it stops, so the guides hold while the engine's
# slide flag is up, the route survives the crossing, and the landing speaks the leg that starts there.

# Aims the step guide at a target with nothing remembered, saving every ivar either guide touches.
def with_ice_guide(target)
  loc = PokeAccess::Locator
  ivars = [:@guide, :@steps, :@steps_at, :@steps_leg, :@guide_time, :@guide_path, :@guide_from,
           :@guide_target, :@guide_fresh, :@guide_surf, :@guide_noroute, :@noroute_key, :@noroute_cue_at,
           :@jump_at, :@blocked_recheck_at, :@target]
  prev = ivars.map { |s| loc.instance_variable_get(s) }
  had_trainer = $Trainer
  $Trainer = Object.new
  def $Trainer.name; "Rojo"; end
  ivars.each { |s| loc.instance_variable_set(s, nil) }
  loc.instance_variable_set(:@target, target)
  loc.instance_variable_set(:@steps, true)
  yield loc
ensure
  $PokemonGlobal.sliding = false
  $Trainer = had_trainer
  ivars.each_index { |i| loc.instance_variable_set(ivars[i], prev[i]) }
  $game_map.clear_grid
  World.clear_events
end

# Moves the player to (x, y), raising the slide flag on ice, and returns what the step guide said there.
def slide_to(loc, x, y)
  $game_player.x = x
  $game_player.y = y
  $PokemonGlobal.sliding = (PokeAccess::Terrain.ice_at?(x, y) rescue false)
  SpeakCapture.clear
  loc.steps_tick
  SpeakCapture.lines
end

Suite.define("guides: an ice slide is crossed in silence, and the leg at the landing is the next one") do
  $game_map.load_grid(["############",
                       "#..........#",
                       "#..........#",
                       "#..........#",
                       "#..........#",
                       "#..........#",
                       "############"])
  (3..7).each { |x| $game_map.set_terrain(x, 2, 12) }
  target = World.event(:kind => :npc, :id => 77, :x => 9, :y => 5)
  with_ice_guide(target) do |loc|
    searches = [0]
    real = PokeAccess::Pathfinder.method(:find_path)
    PokeAccess::Pathfinder.define_singleton_method(:find_path) { |*a| searches[0] += 1; real.call(*a) }
    begin
      $game_player.x = 1; $game_player.y = 2
      SpeakCapture.clear
      loc.steps_tick
      eq "the route starts by walking toward the ice", SpeakCapture.lines, ["3 derecha"]

      eq "the tile before the ice says nothing new", slide_to(loc, 2, 2), []
      crossing = (3..7).map { |x| slide_to(loc, x, 2) }.flatten
      eq "and nothing is said while the slide carries the player", crossing, []
      truthy "the guide is still on", loc.instance_variable_get(:@steps)

      eq "the landing consumes the slide as the single step it was", slide_to(loc, 8, 2) &&
         loc.instance_variable_get(:@guide_path), [6, 2, 2]
      eq "and says nothing, because the leg there is this one shorter", SpeakCapture.lines, []
      eq "the route is still the one computed at the start: the search ran once", searches[0], 1
      eq "the turn after it is spoken where it starts", slide_to(loc, 9, 2), ["2 abajo"]
    ensure
      PokeAccess::Pathfinder.define_singleton_method(:find_path, real)
    end
  end
end

Suite.define("guides: a route that is only a slide does not arrive on the first ice tile") do
  $game_map.load_grid(["##########",
                       "#........#",
                       "#........#",
                       "#........#",
                       "##########"])
  (2..7).each { |x| $game_map.set_terrain(x, 1, 12) }
  target = World.event(:kind => :npc, :id => 78, :x => 8, :y => 2)
  with_ice_guide(target) do |loc|
    $game_player.x = 1; $game_player.y = 1
    SpeakCapture.clear
    loc.steps_tick
    eq "one press carries the player the whole way", loc.instance_variable_get(:@guide_path), [6]

    said = (2..7).map { |x| slide_to(loc, x, 1) }.flatten
    eq "no arrival is announced while sliding", said, []
    truthy "and the guide has not switched itself off", loc.instance_variable_get(:@steps)

    eq "the arrival is announced where the slide stops", slide_to(loc, 8, 1),
       [PokeAccess::I18n.t(:loc_arrived)]
  end
end

Suite.define("route: a step onto ice spans the whole slide, as a ledge step spans its hop") do
  loc = PokeAccess::Locator
  pf = PokeAccess::Pathfinder
  $game_map.load_grid(["##########",
                       "#........#",
                       "#........#",
                       "##########"])
  begin
    (3..6).each { |x| $game_map.set_terrain(x, 1, 12) }
    eq "the step onto the ice lands where the run ends", spots(pf.trace(2, 1, 0, [6])), [[7, 1, 0]]
    eq "a step off the ice is one tile", spots(pf.trace(7, 1, 0, [6])), [[8, 1, 0]]
    eq "and a step that meets no ice is one tile", spots(pf.trace(2, 2, 0, [6])), [[3, 2, 0]]
    truthy "a cached route over the ice stays valid", loc.path_walkable?(2, 1, [6, 6])
  ensure
    $game_map.clear_grid
  end
end

# A slide event (a sprite-less tile that force-moves the player across a gap) is part of the step that lands on it,
# in the search and in the cached route; this one only fires walked into from the left.
Suite.define("route: a step onto a slide event ends where the slide leaves the player") do
  loc = PokeAccess::Locator
  pf = PokeAccess::Pathfinder
  $game_map.load_grid(["##########",
                       "#........#",
                       "#........#",
                       "##########"])
  begin
    World.touch(:id => 40, :x => 3, :y => 1,
                :list => [World.if_facing(6), World.move_player([3, 3, 3], 1), World.end_])
    pf.invalidate_cache(true)
    eq "stepping right onto the slide tile ends beyond the gap", spots(pf.trace(2, 1, 0, [6])), [[6, 1, 0]]
    eq "stepping onto it another way is an ordinary step", spots(pf.trace(3, 2, 0, [8])), [[3, 1, 0]]
    truthy "so a cached route over the gap stays valid", loc.path_walkable?(2, 1, [6, 6])
  ensure
    World.clear_events
    $game_map.clear_grid
  end
end

# The cane holds through a slide, including the frame the player steps onto the ice before the flag is up; guide_tick
# stamps its clock only when it runs.
Suite.define("guides: the cane holds through a slide, flag or no flag") do
  $game_map.load_grid(["##########",
                       "#@.......#",
                       "#........#",
                       "##########"])
  (2..6).each { |x| $game_map.set_terrain(x, 1, 12) }
  target = World.event(:kind => :npc, :id => 79, :x => 8, :y => 2)
  with_ice_guide(target) do |loc|
    loc.instance_variable_set(:@steps, nil)
    loc.instance_variable_set(:@guide, true)
    $game_player.x = 3; $game_player.y = 1
    $PokemonGlobal.sliding = true
    loc.guide_tick
    falsy "with the engine's flag up the cane does not run at all", loc.instance_variable_get(:@guide_time)

    $PokemonGlobal.sliding = false
    def $game_player.moving?; true; end
    begin
      loc.guide_tick
      falsy "nor on the frame the player steps onto the ice, before the flag is up",
            loc.instance_variable_get(:@guide_time)
    ensure
      class << $game_player
        remove_method :moving?
      end
    end
    loc.guide_tick
    truthy "and once the slide is over it runs again", loc.instance_variable_get(:@guide_time)
  end
end
