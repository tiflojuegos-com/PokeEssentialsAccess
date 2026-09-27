# Crossing water on a TileWorld: the guide leads to the shore whose water reaches the target and holds there saying
# which way to surf; deep water over a sea is a dive spot.
WATER_TWO_PONDS = ["############",
                   "#@....~~#..#",
                   "#.....~~#..#",
                   "#.......#..#",
                   "#.......~~~#",
                   "#.......~~~#",
                   "############"]

Suite.define("route water: the shore to push off from is the one whose water reaches the target") do
  pf = PokeAccess::Pathfinder
  with_tile_world(WATER_TWO_PONDS) do
    truthy "the island cannot be walked to", pf.find_path(10, 1).nil?
    plan = pf.surf_plan(10, 1)
    eq "the flood pushed off from the lower pond's shore, facing it", plan, [7, 4, 6]
    route = pf.surf_launch(10, 1)
    eq "and the guide leads onto that shore", pf.trace(1, 1, 0, route).last.tile, [7, 4]
    set = pf.reachable_set
    near = set.keys.map { |k| [k / pf::PKEY_STRIDE, k % pf::PKEY_STRIDE] }.select do |x, y|
      pf::DIRS.any? { |d| $game_map.water?(x + d[0], y + d[1]) }
    end.min_by { |x, y| (x - 10).abs + (y - 1).abs }
    pond = [[6, 1], [7, 1], [6, 2], [7, 2]]
    truthy "which is not the shore nearest the target (#{near.inspect}, on the pond that goes nowhere)",
           pond.any? { |wx, wy| (wx - near[0]).abs + (wy - near[1]).abs == 1 }
  end
end

Suite.define("route water: a cliff over the water is no shore to push off from") do
  pf = PokeAccess::Pathfinder
  with_tile_world(["#########",
                   "#@..]~~.#",
                   "#...#~~.#",
                   "#....~~.#",
                   "#########"]) do
    eq "the ledge nearest the island is closed toward the water, so the flood pushes off lower down",
       pf.surf_plan(7, 1), [4, 3, 6]
  end
end

Suite.define("route water: a party that cannot surf gets no route across the water") do
  pf = PokeAccess::Pathfinder
  with_tile_world(WATER_TWO_PONDS) do
    tr = PokeAccess::Engine.player
    def tr.get_pokemon_with_move(_m); nil; end
    items = PokeAccess::FieldMoves.instance_variable_get(:@items)
    saved = items[:SURF]
    had_bag = $PokemonBag
    bag = Object.new
    def bag.pbQuantity(item); item == :SPECBOARD ? 1 : 0; end
    begin
      $PokemonBag = bag
      items.delete(:SURF)
      truthy "nobody knows Surf and no item stands in for it: no plan", pf.surf_plan(10, 1).nil?
      PokeAccess::FieldMoves.register_item(:SURF, :SPECBOARD)
      eq "with the game's own surfboard in the bag it can", pf.surf_plan(10, 1), [7, 4, 6]
    ensure
      $PokemonBag = had_bag
      class << tr; remove_method :get_pokemon_with_move; end
      if saved then items[:SURF] = saved else items.delete(:SURF) end
    end
  end
end

Suite.define("route water: on the shore the guides hold and say which way to surf") do
  loc = PokeAccess::Locator
  with_tile_world(WATER_TWO_PONDS) do
    ivars = [:@guide, :@steps, :@steps_at, :@steps_leg, :@guide_path, :@guide_from, :@guide_target, :@guide_fresh,
             :@guide_surf, :@guide_gate, :@guide_noroute, :@noroute_key, :@hold_said, :@target]
    saved = ivars.map { |s| loc.instance_variable_get(s) }
    begin
      ivars.each { |s| loc.instance_variable_set(s, nil) }
      target = loc::SurfaceTarget.new(10, 1, "isla", nil)
      loc.instance_variable_set(:@target, target)
      eq "selected, it says the way is across the water", loc.step_phrase(target), ", " + PokeAccess::I18n.t(:loc_surf_route)
      $game_player.x = 7; $game_player.y = 4
      loc.instance_variable_set(:@steps, true)
      SpeakCapture.clear
      loc.steps_tick
      eq "on the shore it says to surf right", SpeakCapture.lines,
         [PokeAccess::I18n.t(:loc_surf_toward, :dir => PokeAccess::I18n.t(:dir_right))]
      truthy "and the step guide stays on", loc.instance_variable_get(:@steps)
      SpeakCapture.clear
      loc.instance_variable_set(:@steps_at, nil)
      loc.steps_tick
      eq "once, not on every tick", SpeakCapture.lines, []
    ensure
      ivars.each_index { |i| loc.instance_variable_set(ivars[i], saved[i]) }
    end
  end
end

Suite.define("route water: deep water over a sea is offered as a place to dive") do
  loc = PokeAccess::Locator
  class Object
    private
    def pbGetMetadata(mid, idx); (mid == 900 && idx == 8) ? 77 : nil; end
  end
  begin
    with_tile_world(["#########",
                     "#@..DDD.#",
                     "#.......#",
                     "#########"]) do
      loc.instance_variable_set(:@surface_cache, nil)
      found = loc.scan_surfaces(1, 1)
      dive = found.find { |t| t.key == :surf_dive }
      eq "the nearest deep tile is a dive spot", dive && [dive.x, dive.y], [4, 1]
      eq "named as one", dive && dive.name, PokeAccess::I18n.t(:surf_dive)
      falsy "and not also as deep water", found.any? { |t| t.key == :surf_deepwater }
      eq "the guide ends ON it, where the button works", loc.dive_key(dive), :loc_dive_here
    end
    with_tile_world(["#########",
                     "#@..~~~.#",
                     "#########"]) do
      $game_map.map_id = 901
      found = loc.scan_surfaces(1, 1)
      falsy "a map with no sea beneath offers none", found.any? { |t| t.key == :surf_dive }
    end
  ensure
    class Object; remove_method :pbGetMetadata; end
  end
end

Suite.define("route water: a dive spot chosen on foot holds on the shore with the way to surf") do
  loc = PokeAccess::Locator
  class Object
    private
    def pbGetMetadata(mid, idx); (mid == 900 && idx == 8) ? 77 : nil; end
  end
  ivars = [:@guide, :@steps, :@steps_at, :@steps_leg, :@guide_path, :@guide_from, :@guide_target, :@guide_fresh,
           :@guide_surf, :@guide_gate, :@guide_noroute, :@noroute_key, :@hold_said, :@target, :@surface_cache]
  saved = ivars.map { |s| loc.instance_variable_get(s) }
  begin
    ivars.each { |s| loc.instance_variable_set(s, nil) }
    with_tile_world(["##########",
                     "#@..~~DD~#",
                     "#...~~~~~#",
                     "##########"]) do
      dive = loc.scan_surfaces(1, 1).find { |t| t.key == :surf_dive }
      loc.instance_variable_set(:@target, dive)
      loc.instance_variable_set(:@steps, true)
      loc.steps_tick
      truthy "on foot the route ends at the shore", loc.instance_variable_get(:@guide_surf)
      path = loc.instance_variable_get(:@guide_path)
      last = PokeAccess::Pathfinder.trace($game_player.x, $game_player.y, 0, path).last
      $game_player.x = last.x; $game_player.y = last.y
      SpeakCapture.clear
      loc.steps_tick
      eq "there it says to surf, not to dive", SpeakCapture.lines,
         [PokeAccess::I18n.t(:loc_surf_toward, :dir => PokeAccess::I18n.t(:dir_right))]
      truthy "and the step guide stays on", loc.instance_variable_get(:@steps)
    end
  ensure
    ivars.each_index { |i| loc.instance_variable_set(ivars[i], saved[i]) }
    class Object; remove_method :pbGetMetadata; end
  end
end

Suite.define("route water: where the game keeps the player on the bike, Surf is not offered") do
  pf = PokeAccess::Pathfinder
  mm = PokeAccess::MapMeta
  with_tile_world(WATER_TWO_PONDS) do
    truthy "on an ordinary map the lower pond is the way", !pf.surf_plan(10, 1).nil?
    class << mm
      alias_method :spec_always_bicycle?, :always_bicycle?
      def always_bicycle?(_mid); true; end
    end
    begin
      pf.invalidate_cache(true)
      truthy "on a cycling road the game refuses Surf, so there is no plan", pf.surf_plan(10, 1).nil?
    ensure
      class << mm
        alias_method :always_bicycle?, :spec_always_bicycle?
        remove_method :spec_always_bicycle?
      end
    end
  end
end
