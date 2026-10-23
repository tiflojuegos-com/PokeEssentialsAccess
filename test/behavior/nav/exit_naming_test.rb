# How exits and shop attendants are named (entrances, buildings, passages, unnamed maps, empty "Exit" placeholders,
# unnamed shopkeepers), and map-edge exits aimed at a stretch of the edge the player can get to.
class ExitNamingTest < PokeAccessTest
  Loc = PokeAccess::Locator
  # The gen-6 games' pbGetMetadata fields, numbered as their scripts number them (MetadataOutdoor, MetadataHealingSpot).
  METADATA_OUTDOOR = 1
  METADATA_HEALING_SPOT = 5

  test "names a door from outdoors into an interior an entrance, and any other an exit" do
    { [[1, 40], 35] => [:loc_entrance_to, 35], [[1, 40], 40] => [:loc_exit_to, 40], [[40], 35] => [:loc_exit_to, 35],
      [[40], 40] => [:loc_exit_to, 40] }.each do |(outdoor, dest), (key, map)|
      with_metadata(outdoor) do
        Loc.clear_verdicts
        assert_equal t(key, :map => "Mapa #{map}"), Loc.target_name(door(90, dest)),
                     "outdoors #{outdoor.inspect}, to #{dest}"
      end
    end
  end

  test "names a door an exit on an engine with no map metadata" do
    assert_equal t(:loc_exit_to, :map => "Mapa 35"), Loc.target_name(door(92, 35))
  end

  test "names a door to a place named like this one by what it leads to" do
    with_metadata([1, 40], 36 => [1, 5, 5]) do
      with_map_names(35 => "Mapa 1", 36 => "Mapa 1", 40 => "Mapa 1") do
        { 35 => t(:loc_building), 36 => t(:loc_pokecenter),
          40 => t(:loc_area_other, :map => "Mapa 1") }.each do |dest, name|
          assert_equal name, Loc.target_name(door(93 + dest, dest)), "to map #{dest}"
        end
      end
    end
  end

  test "says where someone takes the player to a place named like this one by what it leads to, as a door does" do
    with_metadata([1, 40], 36 => [1, 5, 5]) do
      with_map_names(35 => "Mapa 1", 36 => "Mapa 1", 40 => "Mapa 1") do
        { 35 => t(:loc_takes_to_building), 36 => t(:loc_takes_to_pokecenter),
          40 => t(:loc_takes_to_area_other, :map => "Mapa 1") }.each do |dest, takes|
          assert_equal "NPC 07, #{takes}", Loc.target_name(guide(80 + dest, dest)), "to map #{dest}"
        end
      end
    end
  end

  test "names a door to an unnamed map by its own name, or as an exit when it has none" do
    { "Cueva Oscura" => "Cueva Oscura", "Puerta" => t(:loc_exit), "EV012" => t(:loc_exit),
      "" => t(:loc_exit) }.each_with_index do |(name, said), i|
      ev = World.touch(:id => 60 + i, :name => name, :x => 3, :y => 3, :list => [TestCmd.new(201, [0, 77, 1, 1])])
      assert_equal said, Loc.target_name(ev), "named #{name.inspect}"
    end
  end

  test "names a warp within the map a passage toward where it lands" do
    { [18, 10] => t(:loc_passage_dir, :dir => t(:dir_e)), [10, 1] => t(:loc_passage_dir, :dir => t(:dir_n)),
      [10, 10] => t(:loc_passage) }.each_with_index do |((x, y), said), i|
      ev = World.touch(:id => 70 + i, :x => 3, :y => 3, :list => [TestCmd.new(201, [0, 1, x, y])])
      assert_equal said, Loc.target_name(ev), "landing on (#{x}, #{y})"
    end
  end

  test "names a map-edge exit by its destination's name now and in the language chosen now, though built before" do
    with_south_connection([6]) do
      with_map_names(3 => "Ruta 3") do
        PokeAccess::Config.language = :es
        es = [Loc.target_name(Loc.connection_targets[0]), t(:loc_exit_to, :map => "Ruta 3")]
        PokeAccess::Config.set(:language, :en)
        PokeAccess::MapNames.set(3, "Bosque")
        en = [Loc.target_name(Loc.connection_targets[0]), t(:loc_exit_to, :map => "Bosque")]
        assert_equal [es[1], en[1]], [es[0], en[0]]
      end
    end
  end

  test "takes an empty event named Salida for no exit" do
    empty = World.touch(:id => 93, :name => "Salida", :x => 2, :y => 2, :list => [])
    assert_equal false, Loc.transfer_event?(empty)
  end

  test "takes an event named Salida that runs something for an exit by its name" do
    busy = World.touch(:id => 94, :name => "Salida", :x => 4, :y => 2, :list => [TestCmd.new(355, ["pbCaveExit"])])
    assert_equal true, Loc.transfer_event?(busy)
  end

  test "takes an event named Salida whose only command cannot be read for no exit" do
    broken = World.touch(:id => 95, :name => "Salida", :x => 4, :y => 2, :list => [Object.new])
    assert_equal false, Loc.transfer_event?(broken)
  end

  test "names an unnamed attendant of any shop a shopkeeper" do
    ["pbPokemonMart([:POTION, :REPEL])", "pbSecretBaseMart(1)", "pbBattlePointShop([:PPUP])", "tm_mart(2)",
     "enter_pokemart(:center)"].each_with_index do |script, i|
      assert_equal t(:loc_shopkeeper), Loc.target_name(clerk(95 + i, "EV0#{95 + i}", script)), script
    end
  end

  test "names an item on a counter after the item, no shop" do
    potion = PokeAccess::Data.item_id(:POTION)[1]
    assert_equal t(:loc_object_named, :name => potion), Loc.target_name(clerk(96, "EV096", "pbStoreItem(:POTION)"))
  end

  test "names an item on a counter after its sprite with item names turned off" do
    PokeAccess::Config.name_items = false
    assert_equal "HGSS_008", Loc.target_name(clerk(96, "EV096", "pbStoreItem(:POTION)"))
  end

  test "keeps a named shop attendant's own name" do
    assert_equal "Dependienta", Loc.target_name(clerk(97, "Dependienta", "pbPokemonMart([:POTION])"))
  end

  test "aims a map-edge exit at the stretch of the edge the player can get to, under the same name" do
    with_edges([[2, 0], [6, 0]]) do
      edge_map(["##.###.##",
                "#@..#...#",
                "#...#...#",
                "#########"])
      aimed = Loc.aim_connection(edge(6, 0))
      assert_equal [2, 0, "salida a Ruta 3", 3], [aimed.x, aimed.y, aimed.name, aimed.ref]
    end
  end

  test "aims a map-edge exit at the stretch of the edge the fewest steps away, not the nearest in a straight line" do
    [[[1, 0], [7, 0]], [[7, 0], [1, 0]]].each do |stretches|
      with_edges(stretches) do
        edge_map(["#.#####.#",
                  "#.#@....#",
                  "#.#####.#",
                  "#.......#",
                  "#########"])
        aimed = Loc.aim_connection(edge(1, 0))
        assert_equal [7, 0], [aimed.x, aimed.y], "stretches listed as #{stretches.inspect}"
      end
    end
  end

  test "leaves a map-edge exit already aimed where the player can get to as it is" do
    with_edges([[2, 0], [6, 0]]) do
      edge_map(["##.###.##",
                "#@..#...#",
                "#...#...#",
                "#########"])
      kept = edge(2, 0)
      assert_same kept, Loc.aim_connection(kept)
    end
  end

  test "leaves a map-edge exit as it is when no stretch of its edge can be got to, or it has but one" do
    { "none reachable" => [["##.###.##", "##.#@#.##", "##.###.##", "#########"], [[2, 0], [6, 0]]],
      "a single stretch" => [["##.###.##", "#@..#...#", "#...#...#", "#########"],
                             [[6, 0]]] }.each do |what, (rows, stretches)|
      with_edges(stretches) do
        edge_map(rows)
        far = edge(6, 0)
        assert_same far, Loc.aim_connection(far), what
      end
    end
  end

  test "takes an event the engine left with no page for no exit, whatever its pages transfer to" do
    ev = World.touch(:id => 46, :x => 3, :y => 3, :list => [TestCmd.new(201, [0, 35, 1, 1])])
    ev.instance_variable_set(:@active, nil)
    ev.instance_variable_set(:@list, nil)
    ev.instance_variable_set(:@trigger, nil)
    assert_equal [false, false, false], [Loc.transfer_event?(ev), Loc.in_category?(ev, :exits), Loc.in_category?(ev, :all)]
    PokeAccess::Config.transfer_active_page_only = false
    Loc.clear_verdicts
    assert_equal false, Loc.transfer_event?(ev), "every page scanned"
  end

  test "names a door by the branch its page runs, not the first transfer it holds" do
    list = [TestCmd.new(111, [1, 10, 0, 5, 0]), TestCmd.new(201, [0, 40, 1, 1], 1), TestCmd.new(0, [], 1),
            TestCmd.new(411, []), TestCmd.new(201, [0, 35, 1, 1], 1), TestCmd.new(0, [], 1), TestCmd.new(412, [])]
    ev = World.touch(:id => 47, :x => 3, :y => 3, :list => list)
    { 1 => 35, 5 => 40 }.each do |floor, dest|
      $game_variables[10] = floor
      Loc.clear_verdicts
      assert_equal t(:loc_exit_to, :map => "Mapa #{dest}"), Loc.target_name(ev), "variable 10 at #{floor}"
    end
  end

  test "aims a map-edge exit only where the engine lets the player step off the map" do
    with_south_connection([6]) do
      exits = Loc.connection_targets.map { |e| Loc.aim_connection(e) }
      assert_equal [[6, 3]], exits.map { |e| [e.x, e.y] }
    end
  end

  test "the route key on a map-edge exit's own tile says the player has arrived, not that it lies beside them" do
    edge_map(["#.###", "#@..#", "#####"])
    Loc.instance_variable_set(:@target, Loc::SurfaceTarget.new(1, 1, "salida a Ruta 3", nil, 3))
    SpeakCapture.clear
    Loc.announce_route
    assert_equal [[t(:loc_arrived), true]], SpeakCapture.log
  end

  test "on a corner leading off two ways, each map-edge exit's route key says its own way off the map" do
    edge_map(["#.###", "#@..#", "#####"])
    Loc.instance_variable_set(:@conn_edges, 3 => [[1, 1, 8]], 4 => [[1, 1, 4]])
    said = [edge(1, 1), Loc::SurfaceTarget.new(1, 1, "salida a Ruta 4", nil, 4)].map do |e|
      Loc.instance_variable_set(:@target, e)
      SpeakCapture.clear
      Loc.announce_route
      SpeakCapture.lines
    end
    ways = [:loc_out_up, :loc_out_left].map { |k| [t(:loc_route, :steps => t(:loc_exit_out, :out => t(k)))] }
    assert_equal ways, said
  ensure
    Loc.instance_variable_set(:@conn_edges, nil)
  end

  test "on a map-edge exit's own tile its line says which way to step off the map, not that it is right here" do
    edge_map(["#.###", "#@..#", "#####"])
    with_edges([[1, 1, 4]]) do
      with_map_names(3 => "Ruta 3") do
        Loc.instance_variable_set(:@target, edge(1, 1))
        SpeakCapture.clear
        Loc.announce_selected(true)
        line = SpeakCapture.lines[0].to_s
        assert_equal [true, true, false], [line.start_with?("#{t(:loc_exit_to, :map => 'Ruta 3')}, "),
                                           line.end_with?(", #{t(:loc_out_left)}"), line.include?(t(:loc_here))]
      end
    end
  end

  test "lists no map-edge exit to a map no tile of the edge crosses into" do
    with_south_connection([]) do
      assert_equal [], Loc.candidates(:exits).select { |e| Loc.edge?(e) }
    end
  end

  private

  # A text of the mod's.
  def t(key, args = {})
    PokeAccess::I18n.t(key, args)
  end

  # Runs the block on a 9x4 room under the player, connected along its bottom edge to map 3 (as wide), the engine
  # letting the player step off the map down there only from the columns in open_cols.
  def with_south_connection(open_cols)
    $game_map.load_grid(["#########", "#@......#", "#.......#", "#.......#"])
    here = $game_map.map_id
    h = $game_map.height
    w = $game_map.width
    helper = Module.new
    helper.define_singleton_method(:getMapConnections) { [[here, 0, h, 3, 0, 0]] }
    helper.define_singleton_method(:getMapDims) { |id| id == 3 ? [w, 10] : [0, 0] }
    Object.const_set(:MapFactoryHelper, helper)
    real = $game_map.method(:passable?)
    $game_map.define_singleton_method(:passable?) do |x, y, d, *rest|
      d == 2 && y + 1 >= h ? open_cols.include?(x) : real.call(x, y, d, *rest)
    end
    Loc.instance_variable_set(:@conn_targets, nil)
    PokeAccess::Pathfinder.invalidate_cache(true)
    yield
  ensure
    $game_map.singleton_class.send(:remove_method, :passable?) rescue nil
    Object.send(:remove_const, :MapFactoryHelper) if Object.const_defined?(:MapFactoryHelper)
    Loc.instance_variable_set(:@conn_targets, nil)
    Loc.instance_variable_set(:@conn_edges, nil)
    $game_map.clear_grid
  end

  # A player-touch door on (3, 3), event id, transferring to map dest.
  def door(id, dest)
    World.touch(:id => id, :x => 3, :y => 3, :list => [TestCmd.new(201, [0, dest, 1, 1])])
  end

  # Someone the engine starts by sight, event id, drawn as NPC 07, who talks and takes the player to map dest.
  def guide(id, dest)
    World.touch(:id => id, :x => 3, :y => 3, :trigger => 2, :sprite => "NPC 07",
                :list => [TestCmd.new(101, ["In?"]), TestCmd.new(201, [0, dest, 1, 1])])
  end

  # An action-button attendant drawn as one, event id, with that name and script line.
  def clerk(id, name, script)
    page = TestPage.new(:trigger => 0, :sprite => "HGSS_008", :list => [TestCmd.new(355, [script])])
    TestGameEvent.new(:id => id, :x => 3, :y => 3, :name => name, :pages => [page])
  end

  # The map-edge exit to Ruta 3 (map 3) on (x, y).
  def edge(x, y)
    Loc::SurfaceTarget.new(x, y, "salida a Ruta 3", nil, 3)
  end

  # Lays rows out, the player on '@', and drops the routes kept.
  def edge_map(rows)
    $game_map.load_grid(rows)
    PokeAccess::Pathfinder.invalidate_cache(true)
  end

  # Runs the block with the edge tiles leading to map 3 given, as the exit targets' build leaves them.
  def with_edges(tiles)
    Loc.instance_variable_set(:@conn_edges, 3 => tiles)
    yield
  ensure
    Loc.instance_variable_set(:@conn_edges, nil)
  end

  # Runs the block with the gen-6 map metadata giving the outdoor maps and the healing spots (map id => [map, x, y]).
  def with_metadata(outdoor, spots = {})
    meta = lambda do |mid, idx|
      case idx
      when METADATA_OUTDOOR then outdoor.include?(mid) ? true : nil
      when METADATA_HEALING_SPOT then spots[mid]
      end
    end
    GameFunctions.with(:pbGetMetadata => meta) { yield }
  end

  # Runs the block with the player's names for maps given (map id => name), their own put back after and the names
  # of maps that had none deleted.
  def with_map_names(names)
    was = names.keys.map { |m| [m, PokeAccess::MapNames.get(m)] }
    names.each { |m, n| PokeAccess::MapNames.set(m, n) }
    yield
  ensure
    was.each { |m, n| n ? PokeAccess::MapNames.set(m, n) : PokeAccess::MapNames.delete(m) }
  end
end
