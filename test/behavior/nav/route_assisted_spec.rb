# Assisted routes: with no walking route, the search allows what the player can do (action-button climbs, pushed
# boulders, getting off the bike, Waterfall) and cuts the route at the first such step, saying what to do there.

# An action-button event on (x,y) whose question, answered yes, moves the player with Through on.
def assisted_climb(id, x, y, codes, extra = [])
  World.touch(:id => id, :x => x, :y => y, :trigger => 0,
              :list => [TestCmd.new(101, ["¿Quieres usar el Equipo de Escalada?"]), TestCmd.new(102, [["Sí", "No"], 2]),
                        TestCmd.new(402, [0, "Sí"]), World.move_player([37] + codes + [38], 1)] + extra +
                       [TestCmd.new(402, [1, "No"]), TestCmd.new(404, [])])
end

Suite.define("assisted: a wall climbed with the action button ends the route where the button is pressed") do
  pf = PokeAccess::Pathfinder
  loc = PokeAccess::Locator
  $game_map.load_grid(["#####",
                       "#...#",
                       "#####",
                       "#####",
                       "#.@.#",
                       "#####"])
  begin
    assisted_climb(90, 2, 3, [4, 4, 4])
    pf.invalidate_cache(true)
    truthy "the top cannot be walked to", pf.find_path(3, 1).nil?
    g = pf.gated_path(3, 1)
    eq "the route is already there", g && g[0], []
    eq "and the step is the button, facing up", g && [g[1][:kind], g[1][:face]], [:act, 8]
    eq "the guide says so", loc.gate_line(g[1]),
       PokeAccess::I18n.t(:loc_act_here, :dir => PokeAccess::I18n.t(:dir_up))
    eq "and the listing names it", loc.gate_route_text(g[1]), PokeAccess::I18n.t(:loc_act_route)
    World.clear_events
    assisted_climb(91, 2, 3, [4, 4, 4], [TestCmd.new(121, [30, 30, 0], 1)])
    pf.invalidate_cache(true)
    truthy "a page that also sets a switch is a scene, not a climb", pf.gated_path(3, 1).nil?
  ensure
    World.clear_events
    $game_map.clear_grid
  end
end

Suite.define("assisted: with nothing on the map to assist, an unreachable target is not searched again") do
  pf = PokeAccess::Pathfinder
  cap = PokeAccess::Config.astar_max
  sources = pf.instance_variable_get(:@assist_sources)
  $game_map.load_grid(["############",
                       "#@....#....#",
                       "#.....#....#",
                       "#.....#....#",
                       "############"])
  begin
    pf.instance_variable_set(:@assist_sources, [])
    PokeAccess::Config.astar_max = 4
    pf.invalidate_cache(true)
    falsy "nothing to clear, push, act at or get off", pf.assist_possible?
    before = pf.cuts
    truthy "so no assisted route", pf.gated_path(9, 2).nil?
    eq "and no search cut short to report", pf.cuts, before
    assisted_boulder(97, 3, 1)
    pf.invalidate_cache(true)
    truthy "a boulder on the map is something to assist with", pf.assist_possible?
  ensure
    pf.instance_variable_set(:@assist_sources, sources)
    PokeAccess::Config.astar_max = cap
    World.clear_events
    $game_map.clear_grid
  end
end

# A Strength boulder on (x,y), solid, that moves when the grid tile beyond it is open; through, it passes
# anywhere, as the engine's own check does.
def assisted_boulder(id, x, y)
  ev = World.touch(:id => id, :name => "Boulder", :x => x, :y => y, :trigger => 0, :sprite => "boulder",
                   :list => [TestCmd.new(355, ["pbPushThisBoulder"])])
  ev.blocking = true
  def ev.passableStrict?(x, y, d)
    nx = x + (d == 6 ? 1 : (d == 4 ? -1 : 0)); ny = y + (d == 2 ? 1 : (d == 8 ? -1 : 0))
    return true if through
    !$game_map.blocked?(nx, ny)
  end
  ev
end

Suite.define("assisted: a boulder is pushed out of the way when the tile beyond it lets it move") do
  pf = PokeAccess::Pathfinder
  loc = PokeAccess::Locator
  $game_map.load_grid(["#######",
                       "#@....#",
                       "#######"])
  begin
    assisted_boulder(92, 3, 1)
    pf.invalidate_cache(true)
    truthy "the boulder closes the corridor", pf.find_path(5, 1).nil?
    g = pf.gated_path(5, 1)
    eq "the route stops beside it", g && g[0], [6]
    eq "at a Strength boulder", g && [g[1][:kind], g[1][:label], g[1][:move]], [:field, :loc_strength_boulder, :STRENGTH]
    truthy "which the guide names with the move", loc.gate_line(g[1]).include?(PokeAccess::FieldMoves.name(:STRENGTH))
  ensure
    World.clear_events
    $game_map.clear_grid
  end
  $game_map.load_grid(["#####",
                       "#@..#",
                       "###.#",
                       "###.#",
                       "#####"])
  begin
    assisted_boulder(94, 3, 1)
    pf.invalidate_cache(true)
    truthy "a boulder against a wall stays put, and so the way past it stays shut", pf.gated_path(3, 3).nil?
  ensure
    World.clear_events
    $game_map.clear_grid
  end
end

Suite.define("assisted: tall grass the bike cannot ride onto is crossed on foot") do
  pf = PokeAccess::Pathfinder
  loc = PokeAccess::Locator
  with_tile_world(["######",
                   '#@gg.#',
                   "######"]) do
    $PokemonGlobal.bicycle = true
    begin
      truthy "riding, the grass closes the way", pf.find_path(4, 1).nil?
      g = pf.gated_path(4, 1)
      eq "the route stops here", g && g[0], []
      eq "to get off the bike and go on right", g && [g[1][:kind], g[1][:face]], [:dismount, 6]
      eq "as the guide says", loc.gate_line(g[1]),
         PokeAccess::I18n.t(:loc_dismount_here, :dir => PokeAccess::I18n.t(:dir_right))
      truthy "and the bike is back under the player", $PokemonGlobal.bicycle
      mm = PokeAccess::MapMeta
      class << mm
        alias_method :spec_always_bicycle?, :always_bicycle?
        def always_bicycle?(_mid); true; end
      end
      begin
        truthy "where the game never lets the player off, there is no such route", pf.gated_path(4, 1).nil?
      ensure
        class << mm
          alias_method :always_bicycle?, :spec_always_bicycle?
          remove_method :spec_always_bicycle?
        end
      end
    ensure
      $PokemonGlobal.bicycle = false
    end
  end
end

WATERFALL_ROWS = ["#####",
                  "#~~~#",
                  "#~V~#",
                  "##W##",
                  "##W##",
                  "#~~~#",
                  "#@###",
                  "#####"]

Suite.define("assisted: a waterfall is ridden down from its crest and climbed with Waterfall") do
  pf = PokeAccess::Pathfinder
  with_tile_world(WATERFALL_ROWS) do
    $PokemonGlobal.surfing = true
    begin
      $game_player.x = 2; $game_player.y = 1
      eq "afloat above it, one press down the crest drops to the pool", pf.find_path(1, 5), [2]
      eq "landing below the fall", spots(pf.trace(2, 1, 0, [2])), [[2, 5, 0]]
      $game_player.x = 2; $game_player.y = 5
      truthy "from below it cannot be swum up", pf.find_path(1, 1).nil?
      g = pf.gated_path(1, 1)
      eq "it is climbed from right here", g && g[0], []
      eq "with Waterfall", g && [g[1][:label], g[1][:move]], [:surf_waterfall, :WATERFALL]
    ensure
      $PokemonGlobal.surfing = false
    end
  end
end

Suite.define("assisted: a character who walked out of the way no longer blocks a remembered route") do
  pf = PokeAccess::Pathfinder
  $game_map.load_grid(["#######",
                       "#@....#",
                       "###.###",
                       "#######"])
  begin
    npc = World.touch(:id => 93, :x => 3, :y => 1, :trigger => 0, :sprite => "npc", :list => [TestCmd.new(101, ["Hola"])])
    npc.blocking = true
    pf.invalidate_cache(true)
    truthy "standing in the corridor it blocks it", pf.find_path(5, 1).nil?
    npc.y = 2
    eq "once it steps aside, without any event ending, the corridor is open again", pf.find_path(5, 1), [6, 6, 6]
    npc.y = 1
    truthy "and when it steps back in, the corridor it was remembered open is closed", pf.find_path(5, 1).nil?
  ensure
    World.clear_events
    $game_map.clear_grid
  end
end

Suite.define("assisted: a push asks the event itself, by whichever check its engine gives it") do
  pf = PokeAccess::Pathfinder
  modern = Object.new
  def modern.x; 3; end
  def modern.y; 1; end
  def modern.can_move_in_direction?(_d, _strict); true; end
  def modern.passable?(x, y, d, strict); [x, y, d, strict] == [3, 1, 6, true]; end
  truthy "a modern event answers with its strict passable?, from where it stands", pf.pushable?(modern, 6)
  falsy "and refuses the other way", pf.pushable?(modern, 4)
  falsy "asked from where a search has left it, it answers for that tile", pf.pushable?(modern, 6, 4, 1)
  gen6 = Object.new
  def gen6.x; 3; end
  def gen6.y; 1; end
  def gen6.passableStrict?(x, y, d); [x, y, d] == [3, 1, 2]; end
  truthy "a gen-6 one with passableStrict?, from where it stands", pf.pushable?(gen6, 2)
  $game_map.load_grid(["#####",
                       "#@..#",
                       "#####"])
  begin
    rock = assisted_boulder(99, 3, 1)
    rock.through = true
    falsy "made through by a search, a boulder against a wall is still refused", pf.pushable?(rock, 6)
    eq "and keeps its through flag afterwards", rock.through, true
  ensure
    World.clear_events
    $game_map.clear_grid
  end
end

Suite.define("assisted: the pushes that open the way are chosen, not just the nearest shove") do
  pf = PokeAccess::Pathfinder
  $game_map.load_grid(["#######",
                       "#...###",
                       "#@....#",
                       "###.###",
                       "#######"])
  begin
    assisted_boulder(98, 3, 2)
    pf.invalidate_cache(true)
    truthy "no route with the boulder where it is", pf.find_path(5, 2).nil?
    g = pf.gated_path(5, 2)
    eq "one push down into the alcove, from above, beats two pushes along the corridor",
       g && pf.trace(1, 2, 0, g[0]).last.tile, [3, 1]
    eq "three steps to get above it", g && g[0].length, 3
    eq "and the first push is that boulder", g && [g[1][:x], g[1][:y], g[1][:move]], [3, 2, :STRENGTH]
  ensure
    World.clear_events
    $game_map.clear_grid
  end
end

Suite.define("assisted: a room of boulders is planned only with the puzzle assist; without it, the one that blocks") do
  pf = PokeAccess::Pathfinder
  $game_map.load_grid(["##########",
                       "#...#..###",
                       "#@.......#",
                       "###.##.###",
                       "##########"])
  begin
    assisted_boulder(100, 3, 2)
    assisted_boulder(101, 6, 2)
    pf.invalidate_cache(true)
    truthy "two boulders in the way", pf.find_path(8, 2).nil?
    PokeAccess::Config.puzzle_assist = false
    truthy "moving both is a puzzle, which without the assist is the player's", pf.gated_path(8, 2).nil?
    PokeAccess::Config.puzzle_assist = true
    g = pf.gated_path(8, 2)
    eq "with the assist the route plans them, starting with the first boulder", g && [g[1][:x], g[1][:y]], [3, 2]
  ensure
    PokeAccess::Config.puzzle_assist = false
    World.clear_events
    $game_map.clear_grid
  end
end

Suite.define("assisted: getting off the bike is seen by the remembered passability") do
  pf = PokeAccess::Pathfinder
  with_tile_world(["######",
                   '#@gg.#',
                   "######"]) do
    $PokemonGlobal.bicycle = true
    begin
      truthy "riding, no way through the grass", pf.find_path(4, 1).nil?
      $PokemonGlobal.bicycle = false
      eq "on foot, on the same map and with nothing invalidated, the grass lets the player through",
         pf.find_path(4, 1), [6, 6]
    ensure
      $PokemonGlobal.bicycle = false
    end
  end
end

Suite.define("assisted: an event that goes through or turns a touch page is seen by the next search") do
  pf = PokeAccess::Pathfinder
  $game_map.load_grid(["#######",
                       "#@....#",
                       "#######"])
  begin
    wall = World.touch(:id => 96, :x => 3, :y => 1, :trigger => 0, :sprite => "rock", :list => [TestCmd.new(101, ["..."])])
    wall.blocking = true
    pf.invalidate_cache(true)
    truthy "solid, it closes the corridor", pf.find_path(5, 1).nil?
    wall.through = true
    eq "gone through, as the Lens of Truth leaves it, the corridor is open", pf.find_path(5, 1), [6, 6, 6]
    wall.through = false
    truthy "and solid again, closed again", pf.find_path(5, 1).nil?
  ensure
    World.clear_events
    $game_map.clear_grid
  end
end

Suite.define("assisted: a touch event that turns its page is read anew by the next search") do
  pf = PokeAccess::Pathfinder
  $game_map.load_grid(["########",
                       "#@.#...#",
                       "########"])
  begin
    pad = World.touch(:id => 97, :x => 2, :y => 1, :list => [TestCmd.new(201, [0, $game_map.map_id, 5, 1])])
    pf.invalidate_cache(true)
    eq "while its page warps, the pad is the way across", pf.find_path(6, 1), [6]
    quiet = TestPage.new(:trigger => 1, :sprite => "", :list => [TestCmd.new(0, [])])
    [:@active, :@page].each { |iv| pad.instance_variable_set(iv, quiet) }
    pad.instance_variable_set(:@list, quiet.list)
    truthy "once its page turned to one that does nothing, with no event ending, it is no way at all",
           pf.find_path(6, 1).nil?
  ensure
    World.clear_events
    $game_map.clear_grid
  end
end

Suite.define("assisted: a boulder pushed once is pushed again from where it was left, not where it started") do
  pf = PokeAccess::Pathfinder
  $game_map.load_grid(["#####",
                       "#@..#",
                       "###.#",
                       "###.#",
                       "#####"])
  begin
    assisted_boulder(99, 2, 1)
    pf.invalidate_cache(true)
    truthy "pushed into the corner it would block the only way down, so there is no route", pf.gated_path(3, 3).nil?
  ensure
    World.clear_events
    $game_map.clear_grid
  end
end

# A push search that reaches its cap has not shown there is no way: it is counted as a search stopped short, so
# the guides say the route could not be worked out rather than that there is none.
Suite.define("assisted: a push search that reaches its cap is a search stopped short") do
  pf = PokeAccess::Pathfinder
  $game_map.load_grid(["###################################",
                       "#@...........................#....#",
                       "#............................#....#",
                       "#............................#....#",
                       "#............................#....#",
                       "#............................#....#",
                       "#............................#....#",
                       "#............................#....#",
                       "###################################"])
  begin
    assisted_boulder(102, 10, 4)
    pf.invalidate_cache(true)
    cuts = pf.cuts
    truthy "a walled-off target has no route", pf.find_path(33, 4).nil?
    eq "which the walking search showed to the end", pf.cuts, cuts
    truthy "nor does pushing the boulder about open one", pf.gated_path(33, 4).nil?
    truthy "but that search stopped on its cap, and is counted", pf.cuts > cuts
  ensure
    World.clear_events
    $game_map.clear_grid
  end
end
