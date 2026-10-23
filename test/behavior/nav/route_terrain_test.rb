# Terrain that moves the player on arriving or leaving, as each game or plugin plays it (slides, spin arrows, currents,
# slopes, floor traps, cracked floors, rails), the climbs some games add, and the held key the guides call for there.
class RouteTerrainTest < PokeAccessTest
  PF = PokeAccess::Pathfinder
  Moves = PokeAccess::Routes::Moves
  Probe = PokeAccess::World::Probe
  DIR_OF = PokeAccess::Routes::DIR_OF
  T = PokeAccess::I18n
  # The flags a modern terrain tag carries for the plugins and games that read them.
  FLAGS = [:slide_up, :slide_right, :slide_down, :slide_left, :waterCurrent, :rockclimb, :acroBike, :can_surf]
  # A modern terrain tag stand-in: its number and its flags.
  Tag = Struct.new(:id_number, *FLAGS)
  # The lists of Routes::Moves a profile registers its rules into.
  RULE_LISTS = [:@arrival_rules, :@held_rules, :@leave_rules, :@assist_sources]
  # What each profile file registered, by file, from its one evaluation in this process (see with_profile).
  LOADED = {}
  # The module methods Awakening's trap overrides, put back after each test that loads it.
  TRAP_OVERRIDES = { PokeAccess::Control => :sliding? }
  # The Spin Tiles script's arrow terrains, by their PBTerrain names.
  SPIN_ARROWS = { "SpinTileUp" => 31, "SpinTileDown" => 32, "SpinTileLeft" => 33, "SpinTileRight" => 34 }
  # A pool of water seven tiles across and six down, walled round.
  POOL = ["#######",
          "#~~~~~#",
          "#~~~~~#",
          "#~~~~~#",
          "#~~~~~#",
          "#######"]
  # A room six tiles across and four down inside.
  ROOM = ["########",
          "#......#",
          "#......#",
          "#......#",
          "#......#",
          "########"]

  test "a registered arrival rule makes the map no uniform grid" do
    grid(ROOM)
    without_terrain_rules do
      before = Moves.uniform?
      Moves.arrival_rule { |_x, _y, _d| nil }
      assert_equal [true, false], [before, Moves.uniform?]
    end
  end

  test "under a JPS or HPA* setting the route goes round a tile that moves the player, as short as can be" do
    grid(["#########",
          "#@......#",
          "#.......#",
          "#########"])
    without_terrain_rules do
      Moves.arrival_rule { |x, y, _d| [x, y] == [4, 1] ? [1, 2] : nil }
      [:jps, :hpa].each do |algo|
        PokeAccess::Config.path_algorithm = algo
        PF.invalidate_cache(true)
        path = walk_route(7, 1)
        walked = spots(traced(1, 1, 0, path)).map { |x, y, _l| [x, y] }
        assert_equal [7, false, true], [path.length, walked.include?([4, 1]), [[6, 1], [7, 2]].include?(walked.last)],
                     "#{algo}: seven presses, none onto the moving tile, ending beside the target"
      end
    end
  end

  test "a sliding tile runs the player on until the floor no longer slides" do
    grid(slide_room, { [2, 1] => tag(32, :slide_right) })
    assert_equal [[3, 1, 0]], spots(traced(1, 1, 0, [6]))
  end

  test "a sliding tile met on the way turns the slide" do
    grid(slide_room, { [2, 1] => tag(32, :slide_right), [3, 1] => tag(32, :slide_right),
                       [4, 1] => tag(33, :slide_down) })
    assert_equal [[4, 2, 0]], spots(traced(1, 1, 0, [6]))
  end

  test "each spin arrow spins the player its own way until a wall stops them" do
    rows = ["#######",
            "#.....#",
            "#.....#",
            "#..@..#",
            "#.....#",
            "#.....#",
            "#######"]
    with_spin_arrows do
      ends = { "SpinTileUp" => [4, 1], "SpinTileDown" => [4, 5], "SpinTileLeft" => [1, 3], "SpinTileRight" => [5, 3] }
      ends.each do |name, (x, y)|
        grid(rows, { [4, 3] => PBTerrain.const_get(name) })
        assert_equal [[x, y, 0]], spots(traced(3, 3, 0, [6])), name
      end
    end
  end

  test "a spin arrow met on the way turns the spin" do
    with_spin_arrows do
      grid(["#######",
            "#@....#",
            "#.....#",
            "#.....#",
            "#######"], { [2, 1] => 34, [4, 1] => 32 })
      assert_equal [[4, 3, 0]], spots(traced(1, 1, 0, [6]))
    end
  end

  test "a ring of spin arrows that would spin forever is no step" do
    with_spin_arrows do
      grid(["#######",
            "#.....#",
            "#@....#",
            "#.....#",
            "#.....#",
            "#.....#",
            "#######"], { [2, 2] => 34, [4, 2] => 32, [4, 4] => 33, [2, 4] => 31 })
      assert_equal [], traced(1, 2, 0, [6])
    end
  end

  test "Realidea's copy stops the spin on plain floor in its map 323 alone" do
    with_spin_arrows do
      with_profile("realidea/spin_stop", PokeAccess::SpinTiles => :extra_stop?) do
        grid(["#######",
              "#@....#",
              "#######"], { [2, 1] => 34 })
        got = [323, 1].map do |map|
          $game_map.map_id = map
          PF.invalidate_cache(true)
          [map, spots(traced(1, 1, 0, [6]))]
        end
        assert_equal [[323, [[3, 1, 0]]], [1, [[5, 1, 0]]]], got
      end
    end
  end

  test "an Infinite Fusion current pushes a surfer up while it can, and off it" do
    with_profile("infinitefusion_common/water_current") do
      $PokemonGlobal.surfing = true
      grid(["#######",
            "#@~~~~#",
            "#~~~~~#",
            "#~~~~~#",
            "#######"], { [2, 3] => current, [2, 2] => current })
      assert_equal [[2, 1, 0]], spots(traced(1, 3, 0, [6]))
    end
  end

  test "an Infinite Fusion current pushes up, else left, right or down, as the tiles allow" do
    with_profile("infinitefusion_common/water_current") do
      $PokemonGlobal.surfing = true
      cases = [[[2, 2, 6], [], [3, 1]], [[2, 2, 6], [8], [2, 2]], [[2, 2, 6], [8, 4], [4, 2]],
               [[3, 1, 2], [8, 4, 6], [3, 3]]]
      cases.each do |(x, y, d), shut, (lx, ly)|
        grid(POOL, { [3, 2] => current })
        shut.each { |s| $game_map.block_step(3, 2, s) }
        assert_equal [[lx, ly, 0]], spots(traced(x, y, 0, [d])), "pressing #{d} onto it with #{shut.inspect} shut"
      end
    end
  end

  test "an Infinite Fusion current carries no one on foot" do
    with_profile("infinitefusion_common/water_current") do
      grid(["#####",
            "#@..#",
            "#####"], { [2, 1] => tag(0, :waterCurrent) })
      assert_equal [[2, 1, 0]], spots(traced(1, 1, 0, [6]))
    end
  end

  test "Infinite Fusion currents that would push the surfer back and forth forever are no step" do
    with_profile("infinitefusion_common/water_current") do
      $PokemonGlobal.surfing = true
      grid(["#####",
            "#~~~#",
            "#~~~#",
            "#~~~#",
            "#####"], { [1, 2] => current, [2, 2] => current })
      $game_map.block_step(1, 2, 8)
      $game_map.block_step(2, 2, 8)
      assert_equal [], traced(2, 1, 0, [2])
    end
  end

  test "a push the player cannot make leaves the step onto the current untaken" do
    with_profile("infinitefusion_common/water_current") do
      $PokemonGlobal.surfing = true
      grid(POOL, { [3, 2] => current })
      $game_map.block_step(3, 2, 8)
      with_player_refusing(3, 2, 4) { assert_equal [], traced(2, 2, 0, [6]) }
    end
  end

  test "Realidea's slope drops the player a tile down after the step onto it" do
    with_profile("realidea/slides") do
      grid(["#####",
            "#@..#",
            "#...#",
            "#####"], { [2, 1] => 42 })
      assert_equal [[2, 2, :slide]], traced(1, 1, 0, [6]).map { |s| [s.x, s.y, s.kind] }
    end
  end

  test "with water walking on, each Realidea current pushes the player a tile its way" do
    with_profile("realidea/slides") do
      $game_switches[182] = true
      { 44 => [3, 2], 45 => [4, 3], 46 => [2, 3], 47 => [3, 4] }.each do |number, (x, y)|
        grid(current_room, { [3, 3] => number })
        assert_equal [[x, y, 0]], spots(traced(3, 4, 0, [8])), "terrain #{number}"
      end
    end
  end

  test "with water walking off, Realidea's currents push no one" do
    with_profile("realidea/slides") do
      got = [44, 45, 46, 47].map do |number|
        grid(current_room, { [3, 3] => number })
        spots(traced(3, 4, 0, [8]))
      end
      assert_equal [[[3, 3, 0]]] * 4, got
    end
  end

  test "Realidea's slope runs on down a column of slopes to the first tile that is no slope" do
    with_profile("realidea/slides") do
      grid(["#####",
            "#.@.#",
            "#...#",
            "#...#",
            "#...#",
            "#...#",
            "#####"], { [2, 2] => 42, [2, 3] => 42, [2, 4] => 42 })
      assert_equal [[2, 5, :slide]], traced(2, 1, 0, [2]).map { |s| [s.x, s.y, s.kind] }
    end
  end

  test "Realidea's slope carries the player over a slope tile closed on every side, its move route going through" do
    with_profile("realidea/slides") do
      grid(["#####",
            "#.@.#",
            "##.##",
            "#####",
            "#...#",
            "#####"], { [2, 2] => 42, [2, 3] => 42 })
      assert_equal [[2, 4, :slide]], traced(2, 1, 0, [2]).map { |s| [s.x, s.y, s.kind] }
    end
  end

  test "with water walking on, a row of Realidea currents carries the player to its end" do
    with_profile("realidea/slides") do
      $game_switches[182] = true
      grid(current_room, { [3, 3] => 46, [2, 3] => 46 })
      assert_equal [[1, 3, 0]], spots(traced(3, 4, 0, [8]))
    end
  end

  test "Realidea currents that would push the player back and forth forever are no step" do
    with_profile("realidea/slides") do
      $game_switches[182] = true
      grid(current_room, { [3, 3] => 45, [4, 3] => 46 })
      assert_nil Moves.arrive(3, 3, 8)
    end
  end

  test "on Awakening's trap the player slides only while it carries them down, whatever the game's flag says" do
    was = $PokemonGlobal.sliding
    with_profile("awakening/floor_trap", TRAP_OVERRIDES) do
      grid(trap_room, { [2, 2] => 17 })
      $PokemonGlobal.sliding = true
      got = [[2, 2, false, 2], [2, 2, true, 6], [2, 2, true, 8], [2, 2, true, 2], [1, 1, false, 2]].map do |x, y, go, d|
        player_on(x, y, go, d)
        PokeAccess::Control.sliding?
      end
      assert_equal [false, false, false, true, true], got, "on the trap still, right, up and down; off it, the flag"
    end
  ensure
    $PokemonGlobal.sliding = was
    $game_player.singleton_class.send(:remove_method, :moving?) if $game_player.singleton_methods(false).include?(:moving?)
  end

  test "Awakening's trap carries a step down onto it to its end, and leaves any other step where it lands" do
    with_profile("awakening/floor_trap", TRAP_OVERRIDES) do
      grid(trap_room, { [2, 2] => 17, [2, 3] => 17 })
      got = [[2, 1, 2], [1, 2, 6], [3, 2, 4], [2, 3, 8]].map { |x, y, d| [d, spots(traced(x, y, 0, [d]))] }
      assert_equal [[2, [[2, 4, 0]]], [6, [[2, 2, 0]]], [4, [[2, 2, 0]]], [8, [[2, 2, 0]]]], got
    end
  end

  test "an Awakening trap that runs into a wall leaves the player on its last tile" do
    with_profile("awakening/floor_trap", TRAP_OVERRIDES) do
      grid(trap_room, { [2, 3] => 17, [2, 4] => 17 })
      assert_equal [[2, 4, 0]], spots(traced(2, 2, 0, [2]))
    end
  end

  test "Awakening's trap is ground to hold the key on, and plain floor is not" do
    with_profile("awakening/floor_trap", TRAP_OVERRIDES) do
      grid(trap_room, { [2, 2] => 17 })
      assert_equal [true, false], [Moves.held?(2, 2), Moves.held?(1, 1)]
    end
  end

  test "the step guide says to hold the key along a leg across Awakening's trap" do
    with_profile("awakening/floor_trap", TRAP_OVERRIDES) do
      grid(["#######",
            "#@....#",
            "#######"], { [2, 1] => 17, [3, 1] => 17 })
      assert_equal [[held_leg(3, :dir_right), false]], first_words(spot(5, 1))
    end
  end

  test "the step guide says a step down onto Awakening's trap as the slide it is, not held, as the route key says it" do
    with_profile("awakening/floor_trap", TRAP_OVERRIDES) do
      grid(["###",
            "#@#",
            "#.#",
            "#.#",
            "#.#",
            "#.#",
            "###"], { [1, 2] => 17, [1, 3] => 17 })
      slide = PokeAccess::I18n.t(:loc_slide_leg, :dir => PokeAccess::I18n.t(:dir_down))
      assert_equal [[slide, false]], first_words(spot(1, 5))
    end
  end

  test "the cane says to hold the key once per stretch of such ground its route comes to" do
    g = PokeAccess::Guide
    [true, true, false, true].each { |held| g.say_held(held) }
    assert_equal [[T.t(:loc_hold_key), false]] * 2, SpeakCapture.log
  end

  test "the cane leaves the held key to the step guide while that one is on, and says it once it is off" do
    g = PokeAccess::Guide
    said = [true, false].map do |steps|
      g.switch(:steps, steps)
      g.say_held(true)
      SpeakCapture.log.length
    end
    assert_equal [0, 1], said, "lines said with the step guide on, then off"
  end

  test "the cane holds one tone toward Awakening's trap from the step before it until its next step leaves it" do
    with_trap_cane(true) do |loc, tones, chimes|
      grid(["#########",
            "#@.....N#",
            "#########"], { [4, 1] => 17, [5, 1] => 17 })
      guide_aim(loc, $game_map.events[1])
      got = (1..5).map { |x| cane_at(x); [x, tones.dup, chimes.length, SpeakCapture.log.dup] }
      hold = [[T.t(:loc_hold_key), false]]
      assert_equal [[1, [], 1, []], [2, [], 1, []], [3, [6], 1, hold], [4, [6, 6], 1, []], [5, [6, 6, nil], 1, []]],
                   got, "per tile: the tones held, the chimes played, what was said"
    end
  end

  test "without the positional engine the cane keeps its chime over Awakening's trap and says to hold the key" do
    with_trap_cane(false) do |loc, _tones, chimes|
      grid(["#########",
            "#@......#",
            "#########"], { [4, 1] => 17, [5, 1] => 17 })
      guide_aim(loc, World.event(:kind => :npc, :id => 78, :x => 7, :y => 1))
      cane_at(1)
      guide_rewind(loc, 10)
      cane_at(3)
      assert_equal [2, [[T.t(:loc_hold_key), false]]], [chimes.length, SpeakCapture.log]
    end
  end

  test "where the route stops at an obstacle past Awakening's trap the tone stops and the cane stays on" do
    with_trap_cane(true) do |loc, tones, _chimes|
      grid(["#######",
            "#@....#",
            "#######"], { [2, 1] => 17 })
      tree = World.event(:kind => :npc, :id => 82, :x => 3, :y => 1, :name => "Tree")
      tree.blocking = true
      guide_aim(loc, spot(5, 1))
      cane_at(1)
      cane_at(2)
      assert_equal [[6, nil], true], [tones, PokeAccess::Guide.on?(:cane)]
    end
  end

  test "routes go round Opalo's trap floor" do
    with_profile("opalo/floor_traps") do
      grid(opalo_room, { [2, 1] => 4, [3, 1] => 4 })
      assert_equal [2, 6, 6, 6], walk_route(4, 1)
    end
  end

  test "the surfaces call Opalo's trap floor a trap and leave other terrain its own name" do
    with_profile("opalo/floor_traps") do
      grid(opalo_room, { [2, 1] => 4, [1, 2] => 7 })
      label = PokeAccess::World::Terrain
      got = { [2, 1] => label.label(2, 1), [1, 2] => label.label(1, 2), [1, 1] => label.label(1, 1) }
      assert_equal({ [2, 1] => :op_trap, [1, 2] => :surf_water, [1, 1] => nil }, got)
    end
  end

  test "Emerald's cracked floor is ground to hold the key on, on the bike alone, and getting off it is seen at once" do
    cracked_corridor
    got = [true, false].map do |bike|
      $PokemonGlobal.bicycle = bike
      [bike, walk_route(5, 1), Moves.held?(3, 1)]
    end
    assert_equal [[true, [6, 6, 6], true], [false, nil, false]], got,
                 "riding over held ground, then off the bike with no event ending: a drop no route crosses"
  end

  test "on foot no route crosses Emerald's cracked floor" do
    cracked_corridor
    assert_nil walk_route(5, 1)
  end

  test "the step guide says to hold the key along Emerald's cracked floor" do
    cracked_corridor
    $PokemonGlobal.bicycle = true
    assert_equal [[held_leg(3, :dir_right), false]], first_words(spot(5, 1))
  end

  test "an ice slide goes on over ground where the key has to be held" do
    grid(["########",
          "#@.....#",
          "########"], { [2, 1] => 12, [3, 1] => 12, [4, 1] => 12, [5, 1] => 12 })
    World.touch(:id => 123, :x => 4, :y => 1, :list => World.cracked_floor(999))
    $PokemonGlobal.bicycle = true
    assert_equal [[6, 1, 0]], spots(traced(1, 1, 0, [6]))
  end

  test "an ice slide over a hole ends where the hole drops the player" do
    grid(["########",
          "#@.....#",
          "#......#",
          "########"], { [2, 1] => 12, [3, 1] => 12, [4, 1] => 12, [5, 1] => 12 })
    World.touch(:id => 95, :name => "Hole", :x => 4, :y => 1, :list => [TestCmd.new(201, [0, $game_map.map_id, 6, 2])])
    assert_equal [[6, 2, 0]], spots(traced(1, 1, 0, [6]))
  end

  test "Infinite Fusion's Rock Climb takes the player over a ledge two tiles on, either way, and not over a wall" do
    with_profile("infinitefusion_common/field_moves") do
      grid(["#######",
            "#.....#",
            "#.....#",
            "#.....#",
            "#.....#",
            "#.....#",
            "#######"], {}, [[3, 3, 2]])
      got = [[3, 4, 8], [3, 2, 2], [2, 3, 6], [4, 3, 4], [3, 1, 8]].map do |x, y, d|
        shape(Moves.step(x, y, 0, DIR_OF[d], Moves::ASSIST))
      end
      climb = { :kind => :field, :label => :loc_ledge, :move => :ROCKCLIMB, :x => 3, :y => 3 }
      assert_equal [[3, 2, 1, :assist, climb], [3, 4, 1, :assist, climb], [4, 3, 1, :assist, climb],
                    [2, 3, 1, :assist, climb], []], got, "up, down, right and left over the ledge; up into the wall"
    end
  end

  test "Infinite Fusion's assisted route up a row of ledges is gated by Rock Climb on the ledge in front" do
    with_profile("infinitefusion_common/field_moves") do
      grid(["#####",
            "#...#",
            "#...#",
            "#.@.#",
            "#####"], {}, [[1, 2, 2], [2, 2, 2], [3, 2, 2]])
      climb = { :kind => :field, :label => :loc_ledge, :move => :ROCKCLIMB, :x => 2, :y => 2 }
      assert_equal [nil, [[], climb]], [walk_route(2, 1), PokeAccess::Routes::Planner.assisted(2, 1)],
                   "no walk up the ledges; the assisted route climbs the one in front"
    end
  end

  test "Infinite Fusion's Rock Climb is no step onto a tile someone stands on, which the game's jump refuses" do
    with_profile("infinitefusion_common/field_moves") do
      grid(["#######",
            "#.....#",
            "#.....#",
            "#.....#",
            "#.....#",
            "#.....#",
            "#######"], {}, [[3, 3, 2]])
      World.event(:kind => :npc, :id => 40, :x => 3, :y => 2).blocking = true
      World.next_frame
      assert_equal false, Probe.lands?(3, 4, 8, 3, 2), "the stand-in's jump refuses the tile"
      assert_equal [], shape(Moves.step(3, 4, 0, DIR_OF[8], Moves::ASSIST))
    end
  end

  test "L gives the way up to the ledge Infinite Fusion's Rock Climb takes the player over, and to climb it there" do
    with_profile("infinitefusion_common/field_moves") do
      grid(["###",
            "#.#",
            "#.#",
            "#.#",
            "#.#",
            "#@#",
            "###"], {}, [[1, 3, 2]])
      PokeAccess::Locator.instance_variable_set(:@target, spot(1, 1))
      PokeAccess::Locator.announce_route
      hold = PokeAccess::Routes::Text.hold(PokeAccess::Locator.route_plan(spot(1, 1)).gate, 1, 4)
      said = T.t(:loc_route_gate, :what => T.t(:loc_ledge), :steps => "#{leg(1, :dir_up)}; #{hold}")
      assert_equal [[said, true]], SpeakCapture.log
    end
  end

  test "Infinite Fusion's gear in the bag stands in for Surf, Dive and Rock Climb" do
    with_profile("infinitefusion_common/field_moves") do
      gear = { :SURF => :SURFBOARD, :DIVE => :SCUBAGEAR, :ROCKCLIMB => :CLIMBINGGEAR }
      gear.each { |move, item| assert_equal true, can_with_bag(move, [item]), "#{item} for #{move}" }
    end
  end

  test "Añil's rock is climbed along to past its end, up, down and sideways where it bends" do
    cases = [[[[2, 2], [2, 3]], [2, 4, 8], [2, 1]], [[[2, 2], [2, 3]], [2, 1, 2], [2, 4]],
             [[[2, 2], [3, 1], [4, 1]], [1, 2, 6], [5, 1]], [[[2, 2], [3, 3], [4, 3]], [1, 2, 6], [5, 3]],
             [[[5, 2], [4, 2], [3, 1]], [6, 2, 4], [2, 1]], [[], [1, 1, 6], nil]]
    got = cases.map do |rocks, (x, y, d), _want|
      rock_room(rocks)
      PokeAccess::RockClimbAIFM.climb(x, y, d)
    end
    assert_equal cases.map { |_r, _from, want| want }, got,
                 "up and down the column, right a row up and a row down, left a row up; no rock in front"
  end

  test "climbing Añil's rock is one assisted move gated by Rock Climb on the rock in front" do
    climb = { :kind => :field, :label => :loc_rock_climb, :move => :ROCKCLIMB }
    cases = [[[[2, 2], [2, 3]], [2, 4, 8], [2, 1, 1, :assist, climb.merge(:x => 2, :y => 3)]],
             [[[2, 2], [3, 1], [4, 1]], [1, 2, 6], [5, 1, 1, :assist, climb.merge(:x => 2, :y => 2)]]]
    cases.each do |rocks, (x, y, d), want|
      rock_room(rocks)
      assert_equal want, shape(Moves.step(x, y, 0, DIR_OF[d], Moves::ASSIST)), "facing #{d}"
    end
  end

  test "Añil's rock climb and lava surf are each a mode of their own, whose answers the engine gives afresh" do
    grid(["#####",
          "#@..#",
          "#####"])
    asked = 0
    with_global_flags(:rockclimb, :lavasurfing) do
      with_engine(lambda { |_x, _y, _d| asked += 1; true }) do
        counts = [[false, false], [true, false], [false, true], [false, false]].map do |climb, lava|
          $PokemonGlobal.instance_variable_set(:@rockclimb, climb)
          $PokemonGlobal.instance_variable_set(:@lavasurfing, lava)
          World.next_frame
          Probe.step?(1, 1, 6)
          asked
        end
        assert_equal [1, 2, 3, 3], counts, "asked on foot, climbing, surfing lava; back on foot the answer is kept"
      end
    end
  end

  test "IF Hoenn's action button jumps onto a rail only on the bike, facing it from off the rail" do
    with_profile("infinitefusion_hoenn/acro_rails") do
      rail_across
      got = [[true, 3, 3, 8], [true, 1, 2, 6], [false, 3, 3, 8], [true, 2, 2, 6]].map do |bike, x, y, d|
        $PokemonGlobal.bicycle = bike
        shape(Moves.step(x, y, 0, DIR_OF[d], Moves::ASSIST))
      end
      up = [3, 2, 1, :assist, { :kind => :act, :face => 8, :x => 3, :y => 3 }]
      right = [2, 2, 1, :assist, { :kind => :act, :face => 6, :x => 1, :y => 2 }]
      assert_equal [up, right, [], []], got,
                   "on the bike from below it and from beside its end; on foot; along it from a rail tile"
    end
  end

  test "IF Hoenn's far side of a rail is out of reach on foot, and on the bike the rail is the way" do
    with_profile("infinitefusion_hoenn/acro_rails") do
      rail_between_floors
      $game_player.x = 1
      $game_player.y = 3
      got = [false, true].map do |bike|
        $PokemonGlobal.bicycle = bike
        PokeAccess::Routes::Planner.assisted(1, 1)
      end
      assert_equal [nil, [[], { :kind => :act, :face => 8, :x => 1, :y => 3 }]], got
    end
  end

  test "IF Hoenn's rail is hopped off a tile wherever it ends, whatever that tile's passage" do
    with_profile("infinitefusion_hoenn/acro_rails") do
      rail_across
      across = [[3, 2, 8], [3, 2, 2], [4, 2, 6], [2, 2, 4]].map { |x, y, d| shape(Moves.step(x, y, 0, DIR_OF[d], 0)) }
      grid(["#####",
            "#...#",
            "#.#.#",
            "#.#.#",
            "#...#",
            "#####"], { [2, 2] => rail, [2, 3] => rail })
      down = [[2, 2, 8], [2, 3, 2]].map { |x, y, d| shape(Moves.step(x, y, 0, DIR_OF[d], 0)) }
      hop = lambda { |x, y| [x, y, 1, :jump, nil] }
      assert_equal [[hop[3, 1], hop[3, 3], hop[5, 2], hop[1, 2]], [hop[2, 1], hop[2, 4]]], [across, down],
                   "a rail across the room: up, down and off either end; one down the room: off either end"
    end
  end

  test "IF Hoenn's rail is not hopped off toward a wall" do
    with_profile("infinitefusion_hoenn/acro_rails") do
      rail_between_floors
      assert_nil Moves.step(5, 2, 0, DIR_OF[6], 0)
    end
  end

  test "IF Hoenn's rail is not hopped off onto a tile someone stands on, which the game's jump refuses" do
    with_profile("infinitefusion_hoenn/acro_rails") do
      rail_across
      World.event(:kind => :npc, :id => 40, :x => 3, :y => 1).blocking = true
      World.next_frame
      assert_equal false, Probe.lands?(3, 2, 8, 3, 1), "the stand-in's jump refuses the tile"
      assert_nil Moves.step(3, 2, 0, DIR_OF[8], 0)
    end
  end

  private

  # Puts the player on (x, y) facing d, moving or standing still as go says.
  def player_on(x, y, go, d)
    $game_player.x = x
    $game_player.y = y
    $game_player.direction = d
    $game_player.define_singleton_method(:moving?) { go }
  end

  # A modern terrain tag numbered id carrying the flags given.
  def tag(id, *flags)
    Tag.new(id, *FLAGS.map { |f| flags.include?(f) })
  end

  # Infinite Fusion's water current: still water, surfable, carrying the waterCurrent flag.
  def current
    tag(6, :waterCurrent, :can_surf)
  end

  # IF Hoenn's acro-bike rail: a tag carrying the acroBike flag.
  def rail
    tag(34, :acroBike)
  end

  # Loads rows as the test map in place of the last one, each tile of terrain given its tag and a ledge hopped
  # toward d on each [x, y, d] of ledges; the mod sees the new tiles as a game's tile change, with no cache dropped.
  def grid(rows, terrain = {}, ledges = [])
    $game_map.clear_ledges
    $game_map.clear_grid
    $game_map.load_grid(rows)
    terrain.each { |(x, y), t| $game_map.set_terrain(x, y, t) }
    ledges.each { |x, y, d| $game_map.place_ledge(x, y, d) }
  end

  # Directional Sliding's room, eight tiles by five, the player at its top left.
  def slide_room
    ["########",
     "#@.....#",
     "#......#",
     "#......#",
     "########"]
  end

  # A room with the player at (3, 4), below the current at (3, 3).
  def current_room
    ["#######",
     "#.....#",
     "#.....#",
     "#.....#",
     "#..@..#",
     "#.....#",
     "#######"]
  end

  # A room three tiles across and four down inside, for Awakening's trap column.
  def trap_room
    ["#####",
     "#...#",
     "#...#",
     "#...#",
     "#..@#",
     "#####"]
  end

  # Opalo's room, the player at its top left.
  def opalo_room
    ["######",
     "#@...#",
     "#....#",
     "######"]
  end

  # A corridor with Emerald's cracked floor at (3, 1), the player at its left end.
  def cracked_corridor
    grid(["#######",
          "#@....#",
          "#######"])
    World.touch(:id => 122, :x => 3, :y => 1, :list => World.cracked_floor(999))
  end

  # IF Hoenn's rail along the wall row between two floors, from wall to wall.
  def rail_between_floors
    grid(["#######",
          "#.....#",
          "#######",
          "#.....#",
          "#######"], (1..5).map { |x| [[x, 2], rail] })
  end

  # IF Hoenn's rail across a room, on the wall tiles between floor at either end.
  def rail_across
    grid(["#######",
          "#.....#",
          "#.###.#",
          "#.....#",
          "#######"], { [2, 2] => rail, [3, 2] => rail, [4, 2] => rail })
  end

  # ROOM with Añil's climbable rock, a wall, on each tile of rocks.
  def rock_room(rocks)
    rows = ROOM.map { |r| r.dup }
    rocks.each { |x, y| rows[y][x, 1] = "#" }
    grid(rows, rocks.map { |xy| [xy, tag(18, :rockclimb)] })
  end

  # A spot target at (x, y), as the locator lists one.
  def spot(x, y)
    PokeAccess::Locator::SurfaceTarget.new(x, y, "cofre", :spot)
  end

  # A leg as the step guide says it: n presses toward the direction named by key.
  def leg(n, key)
    T.t(:loc_leg, :n => n, :dir => T.t(key))
  end

  # A leg along ground where the key has to be kept down.
  def held_leg(n, key)
    T.t(:loc_leg_held, :leg => leg(n, key))
  end

  # A step as [x, y, presses, kind, gate], or [] for none.
  def shape(s)
    s ? [s.x, s.y, s.presses, s.kind, s.gate] : []
  end

  # What the step guide says on its first frame toward t.
  def first_words(t)
    with_guide_state do |loc|
      steps_aim(loc, t)
      guide_frame
    end
    SpeakCapture.log
  end

  # Whether move can be used with a bag holding items and no party Pokemon that knows any move.
  def can_with_bag(move, items)
    fm = PokeAccess::FieldMoves
    knows = fm.method(:knows?)
    bag = $PokemonBag
    $PokemonBag = Object.new
    $PokemonBag.define_singleton_method(:pbQuantity) { |id| items.include?(id) ? 1 : 0 }
    fm.define_singleton_method(:knows?) { |_m| false }
    fm.can?(move)
  ensure
    $PokemonBag = bag
    fm.define_singleton_method(:knows?, knows)
  end

  # Runs the block with what the profile file games/<file>.rb registers in force, taken out again afterwards. The file
  # is evaluated once per process, as the loader evaluates it, and what it registered is kept for the next test.
  # param overridden { module => method name } for each module method the file overrides
  def with_profile(file, overridden = {})
    added = (LOADED[file] ||= loaded(file, overridden))
    saved = registries(overridden)
    install(added)
    yield
  ensure
    restore(saved) if saved
  end

  # Evaluates games/<file>.rb and answers what it registered (additions), everything it registered taken out again.
  def loaded(file, overridden)
    before = registries(overridden)
    path = File.join(Harness::ROOT, "games", "#{file}.rb")
    eval(Harness.source(path), TOPLEVEL_BINDING, path)
    added = additions(before, registries(overridden))
    restore(before)
    added
  end

  # The registries a profile adds to, as they stand: Routes::Moves' rule lists, the surface labels, the field-move
  # items, the profile names, the overrides listed and the wrappers Hooks.rebind would put back, the toolkit's
  # constants and, for each overridden method, the method with the singleton's own method names.
  def registries(overridden)
    game = PokeAccess::Game
    { :rules => RULE_LISTS.map { |iv| Moves.instance_variable_get(iv).dup },
      :labels => PokeAccess::World::Terrain.instance_variable_get(:@label_rules).dup,
      :items => Hash[PokeAccess::FieldMoves.instance_variable_get(:@items).map { |move, list| [move, list.dup] }],
      :profiles => [game.profiles.dup, game.instance_variable_get(:@profile_name)],
      :overrides => PokeAccess::Hooks.overrides.dup,
      :bound => PokeAccess::Hooks.instance_variable_get(:@bound).dup,
      :consts => PokeAccess.constants,
      :methods => overridden.map do |mod, m|
        meta = mod.singleton_class
        [meta, m, meta.instance_method(m), meta.instance_methods(false)]
      end }
  end

  # What a profile registered between two registries: the new rules, labels, items, profile names, overrides and
  # constants, and each overriding method with the aliases it calls.
  def additions(before, now)
    fresh = lambda { |was, list| list.reject { |r| was.any? { |w| w.equal?(r) } } }
    { :rules => RULE_LISTS.each_index.map { |i| fresh.call(before[:rules][i], now[:rules][i]) },
      :labels => fresh.call(before[:labels], now[:labels]),
      :items => now[:items].map { |move, list| [move, list - (before[:items][move] || [])] },
      :profiles => now[:profiles][0] - before[:profiles][0],
      :overrides => now[:overrides] - before[:overrides],
      :consts => (now[:consts] - before[:consts]).map { |c| [c, PokeAccess.const_get(c)] },
      :methods => now[:methods].each_with_index.map do |(meta, m, um, own), i|
        [meta, m, um, (own - before[:methods][i][3]).map { |a| [a, meta.instance_method(a)] }]
      end }
  end

  # Puts what a profile registered (additions) in force.
  def install(added)
    RULE_LISTS.each_with_index { |iv, i| Moves.instance_variable_get(iv).concat(added[:rules][i]) }
    Moves.forget_map
    PokeAccess::World::Terrain.instance_variable_get(:@label_rules).concat(added[:labels])
    added[:items].each { |move, list| list.each { |it| PokeAccess::FieldMoves.register_item(move, it) } }
    PokeAccess::Game.profiles.concat(added[:profiles])
    PokeAccess::Game.instance_variable_set(:@profile_name, nil)
    PokeAccess::Hooks.overrides.concat(added[:overrides])
    added[:consts].each { |c, v| PokeAccess.const_set(c, v) }
    added[:methods].each do |meta, m, um, aliases|
      aliases.each { |a, aum| meta.send(:define_method, a, aum) }
      meta.send(:define_method, m, um)
    end
  end

  # Puts the registries back as registries took them.
  def restore(saved)
    RULE_LISTS.each_with_index { |iv, i| Moves.instance_variable_set(iv, saved[:rules][i]) }
    Moves.forget_map
    PokeAccess::World::Terrain.instance_variable_set(:@label_rules, saved[:labels])
    PokeAccess::FieldMoves.instance_variable_set(:@items, saved[:items])
    PokeAccess::Game.profiles.replace(saved[:profiles][0])
    PokeAccess::Game.instance_variable_set(:@profile_name, saved[:profiles][1])
    PokeAccess::Hooks.overrides.replace(saved[:overrides])
    PokeAccess::Hooks.instance_variable_set(:@bound, saved[:bound])
    (PokeAccess.constants - saved[:consts]).each { |c| PokeAccess.send(:remove_const, c) }
    saved[:methods].each do |meta, m, um, own|
      meta.send(:define_method, m, um)
      (meta.instance_methods(false) - own).each { |a| meta.send(:remove_method, a) }
    end
  end

  # Runs the block with the Spin Tiles script's arrow terrains defined as the plugin reads them, taken away after.
  def with_spin_arrows
    made = SPIN_ARROWS.reject { |n, _v| PBTerrain.const_defined?(n) }
    made.each { |n, v| PBTerrain.const_set(n, v) }
    PokeAccess::SpinTiles.instance_variable_set(:@arrows, nil)
    yield
  ensure
    made.each { |n, _v| PBTerrain.send(:remove_const, n) }
    PokeAccess::SpinTiles.instance_variable_set(:@arrows, nil)
  end

  # Runs the block with the player's passable? refusing the step from (rx, ry) toward rd that the map allows, the
  # stub's own put back afterwards.
  def with_player_refusing(rx, ry, rd)
    with_engine(lambda { |x, y, d| !(x == rx && y == ry && d == rd) && $game_map.passable?(x, y, d) }) { yield }
  end

  # Runs the block with the player's passable? answering rule's (x, y, d), the stub's own put back afterwards.
  def with_engine(rule)
    pl = $game_player
    pl.define_singleton_method(:passable?) { |x, y, d| rule.call(x, y, d) }
    yield
  ensure
    pl.singleton_class.send(:remove_method, :passable?)
  end

  # Runs the block with the stub's global answering each flag named from its instance variable, all taken away after.
  def with_global_flags(*names)
    g = $PokemonGlobal
    names.each { |n| g.define_singleton_method(n) { instance_variable_get("@#{n}") ? true : false } }
    yield
  ensure
    names.each do |n|
      g.singleton_class.send(:remove_method, n)
      g.remove_instance_variable("@#{n}") if g.instance_variable_defined?("@#{n}")
    end
  end

  # Runs the cane over Awakening's trap with the guides' state kept and the clock still: Sound.hold answering tone_ok.
  # Yields the locator, the directions of the tones held (nil for a release) and the chimes played.
  def with_trap_cane(tone_ok)
    snd = PokeAccess::Sound
    real = [snd.method(:hold), snd.method(:release), Audio.method(:se_play), PokeAccess.method(:clock)]
    tones = []
    chimes = []
    snd.define_singleton_method(:hold) { |_id, opts| tones.push(opts[:dir]); tone_ok }
    snd.define_singleton_method(:release) { |_id| tones.push(nil); true }
    Audio.define_singleton_method(:se_play) { |*a| chimes.push(a); nil }
    PokeAccess.define_singleton_method(:clock) { 1000.0 }
    with_profile("awakening/floor_trap", TRAP_OVERRIDES) do
      with_guide_state { |loc| yield loc, tones, chimes }
    end
  ensure
    snd.define_singleton_method(:hold, real[0])
    snd.define_singleton_method(:release, real[1])
    Audio.define_singleton_method(:se_play, real[2])
    PokeAccess.define_singleton_method(:clock, real[3])
  end

  # Puts the player on (x, 1) and runs one map frame of the guides there, with nothing said before it.
  def cane_at(x)
    $game_player.x = x
    $game_player.y = 1
    SpeakCapture.clear
    guide_frame
  end
end
