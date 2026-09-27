# Terrain that moves the player on arrival, as each game or plugin runs it (slides, spin arrows, currents, slopes,
# floor traps), and the climbs some games add. The profile files are loaded here once.

# A modern terrain tag stand-in carrying the flags the plugins read.
RouteTag = Struct.new(:id_number, :slide_up, :slide_right, :slide_down, :slide_left, :waterCurrent, :rockclimb)

# Evaluates a game's profile file from this repo once, as the loader does; no outside input reaches the eval.
def route_terrain_profile(game, file)
  $route_terrain_loaded ||= {}
  key = "#{game}/#{file}"
  return if $route_terrain_loaded[key]
  path = File.join(Harness::ROOT, "games", game, "#{file}.rb")
  eval(File.read(path), TOPLEVEL_BINDING, path)
  $route_terrain_loaded[key] = true
end

Suite.define("route terrain: with terrain registered, a JPS or HPA* setting still routes over it") do
  pf = PokeAccess::Pathfinder
  algo = PokeAccess::Config.path_algorithm
  arrow = {}
  $game_map.load_grid(["#########",
                       "#@......#",
                       "#.......#",
                       "#########"])
  begin
    without_terrain_rules do
      truthy "with nothing registered the open room is a uniform grid", pf.uniform_grid?
      pf.arrival_rule { |x, y, _d| arrow[[x, y]] }
      arrow[[4, 1]] = [1, 2]
      [:jps, :hpa].each do |a|
        PokeAccess::Config.path_algorithm = a
        pf.invalidate_cache(true)
        falsy "#{a}: an arrow tile registered makes it none", pf.uniform_grid?
        path = pf.find_path(7, 1)
        last = path && pf.trace(1, 1, 0, path).last
        truthy "#{a}: the route, replayed over the arrow, still ends beside the target",
               last && (last.x - 7).abs + (last.y - 1).abs <= 1
      end
    end
  ensure
    PokeAccess::Config.path_algorithm = algo
    $game_map.clear_grid
  end
end

Suite.define("route terrain: a sliding tile runs the player on, and one met on the way turns the slide") do
  pf = PokeAccess::Pathfinder
  $game_map.load_grid(["########",
                       "#@.....#",
                       "#......#",
                       "#......#",
                       "########"])
  begin
    $game_map.set_terrain(2, 1, RouteTag.new(32, false, true, false, false))
    pf.invalidate_cache(true)
    eq "stepping onto a right slide runs right until the floor is no longer sliding", spots(pf.trace(1, 1, 0, [6])), [[3, 1, 0]]
    $game_map.set_terrain(3, 1, RouteTag.new(32, false, true, false, false))
    $game_map.set_terrain(4, 1, RouteTag.new(33, false, false, true, false))
    pf.invalidate_cache(true)
    eq "a down slide met on the way sends the player down it", spots(pf.trace(1, 1, 0, [6])), [[4, 2, 0]]
  ensure
    $game_map.clear_grid
  end
end

Suite.define("route terrain: a spinning arrow spins the player on past the arrows until a wall stops them") do
  pf = PokeAccess::Pathfinder
  added = []
  [["SpinTileUp", 31], ["SpinTileDown", 32], ["SpinTileLeft", 33], ["SpinTileRight", 34]].each do |n, v|
    next if PBTerrain.const_defined?(n)
    PBTerrain.const_set(n, v)
    added.push(n)
  end
  PokeAccess::SpinTiles.instance_variable_set(:@arrows, nil)
  $game_map.load_grid(["#######",
                       "#@....#",
                       "#.....#",
                       "#.....#",
                       "#######"])
  begin
    $game_map.set_terrain(2, 1, 34)
    pf.invalidate_cache(true)
    eq "an arrow to the right carries on over the plain floor to the wall", spots(pf.trace(1, 1, 0, [6])), [[5, 1, 0]]
    $game_map.set_terrain(4, 1, 32)
    pf.invalidate_cache(true)
    eq "an arrow met on the way turns the spin", spots(pf.trace(1, 1, 0, [6])), [[4, 3, 0]]
    route_terrain_profile("realidea", "spin_stop")
    was = $game_map.map_id
    begin
      $game_map.map_id = 323
      pf.invalidate_cache(true)
      eq "Realidea's copy stops the spin on the plain floor of its map 323", spots(pf.trace(1, 1, 0, [6])), [[3, 1, 0]]
    ensure
      $game_map.map_id = was
    end
  ensure
    $game_map.clear_grid
    added.each { |n| PBTerrain.send(:remove_const, n) }
    PokeAccess::SpinTiles.instance_variable_set(:@arrows, nil)
  end
end

Suite.define("route terrain: an Infinite Fusion current pushes a surfer up while it can") do
  route_terrain_profile("infinitefusion_common", "water_current")
  pf = PokeAccess::Pathfinder
  $game_map.load_grid(["#######",
                       "#~~~~~#",
                       "#~~~~~#",
                       "#@~~~~#",
                       "#######"])
  begin
    $PokemonGlobal.surfing = true
    cur = RouteTag.new(6, false, false, false, false, true)
    $game_map.set_terrain(2, 3, cur)
    $game_map.set_terrain(2, 2, cur)
    pf.invalidate_cache(true)
    eq "entering the current it carries the surfer up and off it", spots(pf.trace(1, 3, 0, [6])), [[2, 1, 0]]
    $PokemonGlobal.surfing = false
    pf.invalidate_cache(true)
    truthy "and nobody walks into water to be carried", pf.trace(1, 3, 0, [6]).empty?
  ensure
    $PokemonGlobal.surfing = false
    $game_map.clear_grid
  end
end

Suite.define("route terrain: Realidea's slope drops the player a tile down after each step onto it") do
  route_terrain_profile("realidea", "slides")
  pf = PokeAccess::Pathfinder
  $game_map.load_grid(["#####",
                       "#@..#",
                       "#...#",
                       "#####"])
  begin
    $game_map.set_terrain(2, 1, 42)
    pf.invalidate_cache(true)
    eq "a step onto the slope ends a tile below it", spots(pf.trace(1, 1, 0, [6])), [[2, 2, 0]]
  ensure
    $game_map.clear_grid
  end
end

Suite.define("route terrain: Awakening's floor trap throws back whoever does not keep the key held") do
  route_terrain_profile("awakening", "floor_trap")
  pf = PokeAccess::Pathfinder
  loc = PokeAccess::Locator
  $game_map.load_grid(["#####",
                       "#@..#",
                       "#...#",
                       "#...#",
                       "#####"])
  begin
    [[2, 1], [2, 2], [3, 1], [3, 2]].each { |x, y| $game_map.set_terrain(x, y, 17) }
    pf.invalidate_cache(true)
    eq "walked across, the key held, the player stays where they walked", spots(pf.trace(1, 1, 0, [6])), [[2, 1, 0]]
    eq "walked down onto it, the trap takes them down to its end", spots(pf.trace(2, 1, 0, [2])), [[2, 3, 0]]
    truthy "the trap is ground where the key must be held", pf.held_key_at?(2, 2)
    SpeakCapture.clear
    loc.instance_variable_set(:@steps_leg, nil)
    $game_player.x = 1; $game_player.y = 1
    loc.announce_leg([6, 6])
    hold = PokeAccess::I18n.t(:loc_hold_key)
    truthy "and the step guide says so", SpeakCapture.lines.last.to_s.include?(hold)
    loc.instance_variable_set(:@steps_leg, nil)
    $game_player.x = 2; $game_player.y = 1
    loc.announce_leg([2])
    falsy "but not for a step down it, which the trap carries on whatever is held",
          SpeakCapture.lines.last.to_s.include?(hold)
    said = lambda { SpeakCapture.lines.count { |l| l.to_s == hold } }
    SpeakCapture.clear
    loc.instance_variable_set(:@steps, false)
    loc.instance_variable_set(:@held_key_said, false)
    loc.announce_held_key(true)
    eq "the cane says it once as its next step ends on the trap", said.call, 1
    loc.announce_held_key(true)
    eq "and not again while the route stays on it", said.call, 1
    loc.announce_held_key(false)
    loc.announce_held_key(true)
    eq "but again once the route has left the trap and comes back to it", said.call, 2
    loc.announce_held_key(false)
    loc.instance_variable_set(:@steps, true)
    loc.announce_held_key(true)
    eq "and leaves it to the step guide when that one is on", said.call, 2
  ensure
    loc.instance_variable_set(:@steps_leg, nil)
    loc.instance_variable_set(:@steps, false)
    loc.instance_variable_set(:@held_key_said, false)
    $game_map.clear_grid
  end
end

Suite.define("route terrain: Opalo's trap floor is never stepped on, and the surfaces name it a trap") do
  pf = PokeAccess::Pathfinder
  rules = (pf.instance_variable_get(:@arrival_rules) || []).length
  label = PokeAccess::Terrain.method(:label)
  overrides = PokeAccess::Hooks.overrides.length
  pollers = (PokeAccess::Keys.instance_variable_get(:@frame_pollers) || []).length
  file = File.join(Harness::ROOT, "games", "opalo", "floor_traps.rb")
  eval(File.read(file), TOPLEVEL_BINDING, file)
  traps = [[2, 1], [3, 1]]
  $game_map.load_grid(["######",
                       "#@...#",
                       "#....#",
                       "######"])
  begin
    traps.each { |x, y| $game_map.set_terrain(x, y, 4) }
    pf.invalidate_cache(true)
    path = pf.find_path(4, 1)
    walked = path ? spots(pf.trace(1, 1, 0, path)).map { |x, y, _l| [x, y] } : []
    truthy "a route to the far side is found", !path.nil?
    eq "and it goes round the trap floor, never onto it", walked & traps, []
    eq "which the surfaces call a trap", PokeAccess::Terrain.label(2, 1), :op_trap
    $game_map.set_terrain(1, 2, 7)
    eq "while other terrain keeps its own name", PokeAccess::Terrain.label(1, 2), :surf_water
  ensure
    $game_map.clear_grid
    (pf.instance_variable_get(:@arrival_rules) || []).slice!(rules..-1)
    PokeAccess::Terrain.define_singleton_method(:label, label)
    PokeAccess::Hooks.overrides.slice!(overrides..-1)
    (PokeAccess::Keys.instance_variable_get(:@frame_pollers) || []).slice!(pollers..-1)
    pf.invalidate_cache(true)
  end
end

Suite.define("route terrain: Emerald's cracked floor is ridden over on the bike with the key held, never on foot") do
  pf = PokeAccess::Pathfinder
  loc = PokeAccess::Locator
  $game_map.load_grid(["#######",
                       "#@....#",
                       "#######"])
  was = $PokemonGlobal.bicycle
  begin
    World.touch(:id => 122, :x => 3, :y => 1, :list => World.cracked_floor(999))
    $PokemonGlobal.bicycle = true
    pf.invalidate_cache(true)
    eq "on the bike the route rides over it", pf.find_path(5, 1), [6, 6, 6]
    truthy "as ground where the key must be held", pf.held_key_at?(3, 1)
    SpeakCapture.clear
    loc.instance_variable_set(:@steps_leg, nil)
    $game_player.x = 1; $game_player.y = 1
    loc.announce_leg([6, 6, 6])
    truthy "which the step guide says", SpeakCapture.lines.last.to_s.include?(PokeAccess::I18n.t(:loc_hold_key))
    $PokemonGlobal.bicycle = false
    truthy "off the bike, with no event ending, the same floor is a drop no route crosses", pf.find_path(5, 1).nil?
    falsy "and no ground to hold the key on", pf.held_key_at?(3, 1)
  ensure
    $PokemonGlobal.bicycle = was
    loc.instance_variable_set(:@steps_leg, nil)
    World.clear_events
    $game_map.clear_grid
  end
end

# Runs the cane over Awakening's trap on a one-row map (guide ivars saved, a trainer lent); place returns the target.
# Yields the Locator, the Audio3D.guide_hold calls (answered tone_ok) and the chimes played.
def with_trap_cane(tone_ok, row, traps, place)
  route_terrain_profile("awakening", "floor_trap")
  loc = PokeAccess::Locator
  a3d = PokeAccess::Audio3D
  ivars = [:@guide, :@steps, :@guide_time, :@guide_tile, :@guide_path, :@guide_from, :@guide_target, :@guide_fresh,
           :@guide_surf, :@guide_gate, :@guide_noroute, :@noroute_key, :@noroute_cue_at, :@jump_at,
           :@blocked_recheck_at, :@held_key_said, :@held_ahead, :@held_tone, :@hold_said, :@target]
  prev = ivars.map { |s| loc.instance_variable_get(s) }
  had_trainer = $Trainer
  $Trainer = Object.new
  def $Trainer.name; "Rojo"; end
  tones = []; chimes = []
  real_hold = a3d.method(:guide_hold)
  a3d.define_singleton_method(:guide_hold) { |*a| tones.push(a); tone_ok }
  real_se = Audio.method(:se_play)
  Audio.define_singleton_method(:se_play) { |*a| chimes.push(a); nil }
  $game_map.load_grid(["#" * row.length, row, "#" * row.length])
  begin
    traps.each { |x| $game_map.set_terrain(x, 1, 17) }
    target = place.call
    PokeAccess::Pathfinder.invalidate_cache(true)
    ivars.each { |s| loc.instance_variable_set(s, nil) }
    loc.instance_variable_set(:@target, target)
    loc.instance_variable_set(:@guide, true)
    yield loc, tones, chimes
  ensure
    a3d.define_singleton_method(:guide_hold, real_hold)
    Audio.define_singleton_method(:se_play, real_se)
    $Trainer = had_trainer
    ivars.each_index { |i| loc.instance_variable_set(ivars[i], prev[i]) }
    $game_map.clear_grid
    World.clear_events
  end
end

# A character two tiles past the trap, to walk up to.
def trap_npc
  World.event(:kind => :npc, :id => 78, :x => 7, :y => 1)
end

# Moves the player to x on row 1 and runs one cane tick there.
def cane_at(loc, x)
  $game_player.x = x
  $game_player.y = 1
  SpeakCapture.clear
  loc.guide_tick
end

Suite.define("route terrain: the cane holds its sound as one tone across Awakening's trap") do
  with_trap_cane(true, "#@......#", [4, 5], method(:trap_npc)) do |loc, tones, chimes|
    cane_at(loc, 1)
    eq "well before the trap it chimes as ever", [tones.length, chimes.length], [0, 1]
    cane_at(loc, 2)
    eq "a new tile on the leg toward it neither chimes off the clock nor holds", [tones.length, chimes.length], [0, 1]
    cane_at(loc, 3)
    eq "one step before it the tone starts toward the trap, without waiting for the next chime",
       tones.map { |t| t[0] }, [6]
    eq "in place of the chime", chimes.length, 1
    truthy "and the key is to be held", SpeakCapture.lines.include?(PokeAccess::I18n.t(:loc_hold_key))
    cane_at(loc, 4)
    eq "on the trap it keeps sounding toward the next trap tile", tones.map { |t| t[0] }, [6, 6]
    eq "with the hint said once", SpeakCapture.lines.include?(PokeAccess::I18n.t(:loc_hold_key)), false
    cane_at(loc, 5)
    eq "and once the next step is off the trap it stops", tones.last, [nil]
  end
end

Suite.define("route terrain: without the positional engine the cane keeps its chime and says to hold the key") do
  with_trap_cane(false, "#@......#", [4, 5], method(:trap_npc)) do |loc, _tones, chimes|
    cane_at(loc, 1)
    loc.instance_variable_set(:@guide_time, nil)
    cane_at(loc, 3)
    eq "the chime plays as ever", chimes.length, 2
    truthy "and the hint is spoken", SpeakCapture.lines.include?(PokeAccess::I18n.t(:loc_hold_key))
  end
end

# A cuttable tree right past a trap tile, with the target beyond it.
def trap_tree_target
  tree = World.event(:kind => :npc, :id => 82, :x => 3, :y => 1, :name => "Tree")
  tree.blocking = true
  PokeAccess::Locator::SurfaceTarget.new(5, 1, "cofre", nil)
end

Suite.define("route terrain: a route that stops at an obstacle past the trap lets the tone go there") do
  with_trap_cane(true, "#@....#", [2], method(:trap_tree_target)) do |loc, tones, _chimes|
    cane_at(loc, 1)
    eq "the step onto the trap holds the tone", tones.map { |t| t[0] }, [6]
    cane_at(loc, 2)
    eq "and where the route holds before the tree the tone stops", tones.last, [nil]
    truthy "while the cane stays on to say what to do there", loc.instance_variable_get(:@guide)
  end
end

Suite.define("route terrain: an ice slide passes over ground where the key has to be held") do
  pf = PokeAccess::Pathfinder
  $game_map.load_grid(["########",
                       "#@.....#",
                       "########"])
  was = $PokemonGlobal.bicycle
  begin
    (2..5).each { |x| $game_map.set_terrain(x, 1, 12) }
    World.touch(:id => 123, :x => 4, :y => 1, :list => World.cracked_floor(999))
    $PokemonGlobal.bicycle = true
    pf.invalidate_cache(true)
    eq "the slide carries on over it to the end of the ice", spots(pf.trace(1, 1, 0, [6])), [[6, 1, 0]]
  ensure
    $PokemonGlobal.bicycle = was
    World.clear_events
    $game_map.clear_grid
  end
end

Suite.define("route terrain: a slide over ice that passes over a hole ends where the hole drops the player") do
  pf = PokeAccess::Pathfinder
  $game_map.load_grid(["########",
                       "#@.....#",
                       "#......#",
                       "########"])
  begin
    (2..5).each { |x| $game_map.set_terrain(x, 1, 12) }
    World.touch(:id => 95, :name => "Hole", :x => 4, :y => 1, :list => [TestCmd.new(201, [0, $game_map.map_id, 6, 2])])
    pf.invalidate_cache(true)
    eq "the hole on the ice takes the slide down with it", spots(pf.trace(1, 1, 0, [6])), [[6, 2, 0]]
  ensure
    World.clear_events
    $game_map.clear_grid
  end
end

Suite.define("route terrain: Rock Climb scales a ledge in Infinite Fusion and a rock wall in Añil") do
  route_terrain_profile("infinitefusion_common", "field_moves")
  pf = PokeAccess::Pathfinder
  $game_map.load_grid(["#####",
                       "#...#",
                       "#...#",
                       "#.@.#",
                       "#####"])
  begin
    $game_map.place_ledge(1, 2, 2) rescue nil
    $game_map.place_ledge(2, 2, 2) rescue nil
    $game_map.place_ledge(3, 2, 2) rescue nil
    pf.invalidate_cache(true)
    truthy "a ledge is not walked up", pf.find_path(2, 1).nil?
    g = pf.gated_path(2, 1)
    eq "it is climbed with Rock Climb from below", g && [g[1][:label], g[1][:move]], [:loc_ledge, :ROCKCLIMB]
  ensure
    $game_map.clear_ledges rescue nil
    $game_map.clear_grid
  end
  $game_map.load_grid(["#####",
                       "#...#",
                       "#####",
                       "#####",
                       "#...#",
                       "#####"])
  begin
    rock = RouteTag.new(18, false, false, false, false, false, true)
    $game_map.set_terrain(2, 2, rock)
    $game_map.set_terrain(2, 3, rock)
    $game_player.x = 2; $game_player.y = 4
    pf.invalidate_cache(true)
    eq "Añil's rock is climbed straight up and the player set down past its top",
       PokeAccess::RockClimbAIFM.climb(2, 4, 8), [2, 1]
    g = pf.gated_path(2, 1)
    eq "as a step of the assisted route, named as rock to climb", g && [g[1][:label], g[1][:move]],
       [:loc_rock_climb, :ROCKCLIMB]
    $game_map.load_grid(["########",
                         "#......#",
                         "#.######",
                         "########"])
    [[2, 2], [3, 1], [4, 1]].each { |x, y| $game_map.set_terrain(x, y, rock) }
    eq "sideways it follows the rock a row up where the wall bends, and leaves past its end",
       PokeAccess::RockClimbAIFM.climb(1, 2, 6), [5, 1]
  ensure
    $game_map.clear_grid
  end
end

# An IF Hoenn rail tag: acroBike set.
RailTag = Struct.new(:id_number, :acroBike)

Suite.define("route terrain: IF Hoenn's rails are jumped onto on the bike and hopped off at any side") do
  route_terrain_profile("infinitefusion_hoenn", "acro_rails")
  pf = PokeAccess::Pathfinder
  $game_map.load_grid(["#######",
                       "#.....#",
                       "#######",
                       "#.....#",
                       "#######"])
  begin
    rail = RailTag.new(34, true)
    (1..5).each { |x| $game_map.set_terrain(x, 2, rail) }
    $game_player.x = 1; $game_player.y = 3
    pf.invalidate_cache(true)
    truthy "the far side is out of reach on foot", pf.gated_path(1, 1).nil?
    $PokemonGlobal.bicycle = true
    g = pf.gated_path(1, 1)
    eq "on the bike the rail is the way, jumped onto with the action button", g && [g[1][:kind], g[1][:face]], [:act, 8]
    eq "and off it the player hops wherever the rail ends", pf.step_target(1, 2, [0, -1, 8], false, false), [1, 1]
  ensure
    $PokemonGlobal.bicycle = false
    $game_map.clear_grid
  end
end
