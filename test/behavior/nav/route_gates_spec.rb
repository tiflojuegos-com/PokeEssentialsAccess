# A field-move obstacle in the way: the route runs up to it, the guides hold there naming it and its move, and the
# locator and the route key say what blocks the way. gates_tree_map lays a corridor closed by a cuttable tree.
def gates_tree_map
  $game_map.load_grid(["#######",
                       "#@....#",
                       "#######"])
  tree = World.event(:kind => :npc, :id => 80, :x => 3, :y => 1, :name => "Tree")
  tree.blocking = true
  PokeAccess::Pathfinder.invalidate_cache(true)
  tree
end

Suite.define("route gates: the route runs up to the obstacle and names it") do
  pf = PokeAccess::Pathfinder
  loc = PokeAccess::Locator
  begin
    tree = gates_tree_map
    truthy "the tree closes the corridor", pf.find_path(5, 1).nil?
    g = pf.gated_path(5, 1)
    eq "the route stops short of it", g && g[0], [6]
    eq "and says what it is and where", g && [g[1][:label], g[1][:move], g[1][:x], g[1][:y]], [:loc_cut_tree, :CUT, 3, 1]
    falsy "the tree is left standing", tree.through
    target = loc::SurfaceTarget.new(5, 1, "cofre", nil)
    move = PokeAccess::FieldMoves.name(:CUT)
    what = PokeAccess::I18n.t(:loc_cut_tree)
    eq "selected, the target says what blocks it", loc.step_phrase(target),
       ", " + PokeAccess::I18n.t(:loc_gate_route, :what => what, :move => move)
  ensure
    World.clear_events
    $game_map.clear_grid
  end
end

Suite.define("route gates: the guides hold at the obstacle and go on once it is gone") do
  loc = PokeAccess::Locator
  ivars = [:@guide, :@steps, :@steps_at, :@steps_leg, :@guide_path, :@guide_from, :@guide_target, :@guide_fresh,
           :@guide_surf, :@guide_gate, :@guide_noroute, :@noroute_key, :@hold_said, :@target, :@guide_level]
  saved = ivars.map { |s| loc.instance_variable_get(s) }
  tr = PokeAccess::Engine.player
  begin
    tree = gates_tree_map
    ivars.each { |s| loc.instance_variable_set(s, nil) }
    loc.instance_variable_set(:@target, loc::SurfaceTarget.new(5, 1, "cofre", nil))
    loc.instance_variable_set(:@steps, true)
    $game_player.x = 2; $game_player.y = 1
    SpeakCapture.clear
    loc.steps_tick
    move = PokeAccess::FieldMoves.name(:CUT)
    what = PokeAccess::I18n.t(:loc_cut_tree)
    eq "beside the tree it names it and the move", SpeakCapture.lines,
       [PokeAccess::I18n.t(:loc_gate_use, :what => what, :dir => PokeAccess::I18n.t(:dir_right), :move => move)]
    truthy "and the step guide stays on", loc.instance_variable_get(:@steps)

    def tr.get_pokemon_with_move(_m); nil; end
    loc.instance_variable_set(:@hold_said, nil)
    loc.instance_variable_set(:@guide_path, nil)
    loc.instance_variable_set(:@steps_at, nil)
    SpeakCapture.clear
    loc.steps_tick
    eq "with nobody able to use it, it says the move is needed", SpeakCapture.lines,
       [PokeAccess::I18n.t(:loc_gate_need, :what => what, :dir => PokeAccess::I18n.t(:dir_right), :move => move)]

    tree.blocking = false
    PokeAccess::Pathfinder.invalidate_cache(true)
    loc.forget_noroute
    loc.instance_variable_set(:@steps_at, nil)
    SpeakCapture.clear
    loc.steps_tick
    eq "cut down, the way on is the plain route", SpeakCapture.lines, ["2 " + PokeAccess::I18n.t(:dir_right)]
  ensure
    (class << tr; remove_method :get_pokemon_with_move; end) rescue nil
    ivars.each_index { |i| loc.instance_variable_set(ivars[i], saved[i]) }
    World.clear_events
    $game_map.clear_grid
  end
end

Suite.define("route gates: the route key reads the way up to the obstacle") do
  loc = PokeAccess::Locator
  saved = loc.instance_variable_get(:@target)
  begin
    gates_tree_map
    loc.instance_variable_set(:@target, loc::SurfaceTarget.new(5, 1, "cofre", nil))
    loc.instance_variable_set(:@targets_stale, false)
    SpeakCapture.clear
    loc.announce_route
    eq "route to the tree, then what it is", SpeakCapture.lines,
       [PokeAccess::I18n.t(:loc_route_gate, :what => PokeAccess::I18n.t(:loc_cut_tree),
                           :steps => PokeAccess::Pathfinder.path_to_text([6]))]
  ensure
    loc.instance_variable_set(:@target, saved)
    World.clear_events
    $game_map.clear_grid
  end
end

Suite.define("route gates: one obstacle and a longer way round beat several in a row") do
  pf = PokeAccess::Pathfinder
  $game_map.load_grid(["#########",
                       "#.......#",
                       "#.#####.#",
                       "#.#####.#",
                       "#@......#",
                       "#########"])
  begin
    [[3, 4], [4, 4], [5, 4], [7, 3]].each_with_index do |xy, i|
      t = World.event(:kind => :npc, :id => 81 + i, :x => xy[0], :y => xy[1], :name => "Tree")
      t.blocking = true
    end
    pf.invalidate_cache(true)
    truthy "no walking route", pf.find_path(6, 4).nil?
    g = pf.gated_path(6, 4)
    eq "the way round with one tree is taken over the short way through three", g && [g[1][:x], g[1][:y]], [7, 3]
  ensure
    World.clear_events
    $game_map.clear_grid
  end
end
