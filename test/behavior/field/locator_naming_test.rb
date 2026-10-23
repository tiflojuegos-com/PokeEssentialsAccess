# The names the locator gives map events and what it counts as something to do (core/nav/locator_naming.rb), and what
# the cursor-mode naming screen says as it opens, as its cursor moves and as the name is typed (CursorNaming).
class LocatorNamingTest < PokeAccessTest
  # Naming keyboards as the game's @@Characters lays them out, a row per tab: the modern one with four tabs (at
  # -6..-3), gen 6's with three (at -5..-3), and one of five, which the mod has no tab names for.
  class FourTabs
    @@Characters = [[("ABCDEFGHIJ ,.").scan(/./), "UPPER"], [("abcdefghij ,.").scan(/./), "lower"],
                    [("áéíóúàèìòù ,.").scan(/./), "accents"], [(",.:;!?   ♂♀  ").scan(/./), "other"]]
  end

  class ThreeTabs
    @@Characters = [[("ABCDEFGHIJ ,.").scan(/./), "UPPER"], [("abcdefghij ,.").scan(/./), "lower"],
                    [(",.:;!?   ♂♀  ").scan(/./), "other"]]
  end

  class FiveTabs
    @@Characters = [[("ABC").scan(/./), "a"], [("abc").scan(/./), "b"], [("123").scan(/./), "c"],
                    [("456").scan(/./), "d"], [("789").scan(/./), "e"]]
  end

  # The text box of the naming screen.
  Helper = Struct.new(:text)

  # Leaves the locator's per-map caches as an empty map builds them, so a lever a test placed on the shared map is
  # none for the tests after.
  def teardown
    World.clear_events
    map_settled
    super
  end

  test "a two-pose event worked by hand, its second pose behind a switch, is a lever in the pose it shows" do
    off = World.event(:kind => :lever, :id => 1)
    on = World.event(:kind => :lever, :id => 2, :x => 6, :active => 1)
    map_settled
    assert_equal "#{t(:loc_lever)}, #{t(:loc_lever_off)}", locator.target_name(off), "showing its first pose"
    assert_equal "#{t(:loc_lever)}, #{t(:loc_lever_on)}", locator.target_name(on), "showing its second pose"
  end

  test "a two-pose event is a lever only if its first page turns on the gate of its second and its rows match, it gives and fights nothing and a word that is no door's says lever" do
    a = { :self_switch_valid => true, :self_switch_ch => "A" }
    kinds = [["the switch on", toggle(1)],
             ["its own self switch", toggle(2, :first => [TestCmd.new(123, ["A", 0])], :gate => a)],
             ["the switch from a script", toggle(3, :first => [TestCmd.new(355, ["$game_switches[50] = true"])])],
             ["lever said in a text", toggle(4, :sprite => "box", :first => [TestCmd.new(101, ["Mueves el interruptor."]),
                                                                          TestCmd.new(121, [50, 50, 0])])],
             ["nothing turned on", toggle(5, :first => [])],
             ["another row", toggle(6, :rows => [2, 4])],
             ["a battle in a branch", toggle(7, :second => [TestCmd.new(111, [12, "pbTrainerBattle(:HIKER)"])])],
             ["a door's sheet", toggle(8, :sprite => "door_lever")],
             ["no word for lever", toggle(9, :sprite => "box")]]
    map_settled
    assert_equal ["the switch on", "its own self switch", "the switch from a script", "lever said in a text"],
                 kinds.select { |_what, ev| locator.lever?(ev) }.map { |what, _ev| what }
  end

  test "a lever says its own name, not a placeholder nor a name its map's levers share while working other switches" do
    other = toggle(4, :name => "Interruptor 1", :first => [TestCmd.new(121, [51, 51, 0])],
                      :gate => { :switch1_valid => true, :switch1_id => 51 })
    levers = [toggle(1, :name => "Norte"), toggle(2, :name => "EV002"), toggle(3, :name => "Interruptor 1"), other,
              toggle(5, :name => "Gemela"), toggle(6, :name => "Gemela")]
    map_settled
    off = t(:loc_lever_off)
    word = "#{t(:loc_lever)}, #{off}"
    assert_equal ["Norte, #{off}", word, word, word, "Gemela, #{off}", "Gemela, #{off}"],
                 levers.map { |ev| locator.target_name(ev) }
  end

  test "a two-pose event whose first page gives an item is an object named for itself, a chest or its item, closed until another page shows" do
    gift = [TestCmd.new(355, ["pbReceiveItem(:POTION)"]), TestCmd.new(123, ["A", 0])]
    a = { :self_switch_valid => true, :self_switch_ch => "A" }
    named = toggle(1, :name => "Badge 1 Chest", :sprite => "Object_Chest", :first => gift, :gate => a)
    opened = toggle(2, :name => "Badge 2 Chest", :sprite => "Object_Chest", :first => gift, :gate => a, :active => 1)
    chest = toggle(3, :sprite => "Cofre", :first => [TestCmd.new(126, [1, 0, 0, 1])], :gate => a)
    crater = toggle(4, :sprite => "crater", :first => item_branch(:POTION), :gate => a)
    map_settled
    closed = t(:loc_container_closed)
    potion = PokeAccess::Data.item_id(:POTION)[1]
    assert_equal ["Badge 1 Chest, #{closed}", "Badge 2 Chest, #{t(:loc_container_open)}", "#{t(:loc_chest)}, #{closed}",
                  "#{t(:loc_object_named, :name => potion)}, #{t(:loc_object_closed)}"],
                 [named, opened, chest, crater].map { |ev| locator.target_name(ev) }
    assert_equal [:objects] * 4, [named, opened, chest, crater].map { |ev| locator.event_category(ev) }
    assert_equal true, locator.interactable?(opened), "open, with nothing left to do, it stays listed"
  end

  test "in Polish a chest is closed or open in the feminine and an object in the masculine" do
    PokeAccess::Config.language = :pl
    a = { :self_switch_valid => true, :self_switch_ch => "A" }
    chest = toggle(3, :sprite => "Cofre", :first => [TestCmd.new(126, [1, 0, 0, 1])], :gate => a)
    crater = toggle(4, :sprite => "crater", :first => item_branch(:POTION), :gate => a)
    dug = toggle(5, :sprite => "crater", :first => item_branch(:POTION), :gate => a, :active => 1)
    map_settled
    states = [chest, crater, dug].map { |ev| locator.target_name(ev).split(", ").last }
    assert_equal ["zamknięta", "zamknięty", "otwarty"], states
  end

  test "any other two-pose event is said as any event, and a person only by a character's sheet or by turning to talk" do
    talk = [TestCmd.new(101, ["¡Alto!"])]
    trainer = toggle(1, :sprite => "trchar045", :first => [])
    guard = toggle(2, :sprite => "guard", :first => talk, :rows => [2, 4])
    statue = toggle(3, :sprite => "statue", :first => talk)
    rail = toggle(4, :sprite => "vias", :first => [])
    map_settled
    assert_equal [:people, :people, :objects, :objects], [trainer, guard, statue, rail].map { |ev| locator.event_category(ev) }
    assert_equal "statue", locator.target_name(statue)
  end

  test "a lever's kind does not outlive the test that placed it on the test map" do
    lever = toggle(1)
    map_settled
    was = locator.lever?(lever)
    Reset.before_test
    bob = TestGameEvent.new(:id => 1, :x => 1, :y => 3, :name => "Bob",
                            :pages => [TestPage.new(:sprite => "npc", :list => [TestCmd.new(101, ["Hola."])])])
    $game_map.events[1] = bob
    assert_equal [true, "Bob", :people], [was, locator.target_name(bob), locator.event_category(bob)]
  end

  test "an event name's shadow flags are not said" do
    said = ["Chorrillo.shadowless", "Objeto.noshadow", "Interruptor 1.NoShadow"].each_with_index.map do |name, i|
      locator.target_name(TestGameEvent.new(:id => 40 + i, :name => name, :pages => [TestPage.new(:sprite => "npc")]))
    end
    assert_equal ["Chorrillo", "Objeto", "Interruptor 1"], said
  end

  test "a battle trainer's two poses are no lever: unnamed, it goes by its sprite" do
    trainer = World.event(:kind => :trainer, :id => 2)
    map_settled
    assert_equal "hiker", locator.target_name(trainer)
  end

  test "an event named Trainer(...) is said by the class its battle fights as, and a trainer with trainer names off" do
    trainer = World.event(:kind => :trainer, :id => 2, :name => "Trainer(5)")
    map_settled
    named = locator.target_name(trainer)
    PokeAccess::Config.name_trainers = false
    assert_equal ["Montanero", t(:loc_trainer)], [named, locator.target_name(trainer)]
  end

  test "a trainer named for its sight is said beaten once its live page is the one its battle leaves" do
    fresh = World.event(:kind => :trainer, :id => 2, :name => "Trainer(5)")
    beaten = World.event(:kind => :trainer, :id => 3, :x => 6, :name => "Trainer(5)", :active => 1)
    map_settled
    assert_equal ["Montanero", t(:loc_trainer_beaten, :name => "Montanero")],
                 [locator.target_name(fresh), locator.target_name(beaten)]
  end

  test "a trainer whose live page on a self switch battles again is not said beaten" do
    battle = [TestCmd.new(355, ["pbTrainerBattle(PBTrainers::HIKER,\"Ana\")"])]
    pages = [TestPage.new(:trigger => 0, :sprite => "hiker", :list => battle),
             TestPage.new(:trigger => 0, :sprite => "hiker", :list => battle,
                          :condition => { :self_switch_valid => true, :self_switch_ch => "A" })]
    rematch = TestGameEvent.new(:id => 4, :name => "Trainer(2)", :pages => pages, :active_page => pages[1])
    assert_equal "Montanero", locator.target_name(rematch)
  end

  test "a trainer named for its sight whose pages hold no battle call is said by its sprite's class" do
    page = TestPage.new(:trigger => 0, :sprite => "trchar065", :list => [TestCmd.new(101, ["¡Hola!"])])
    assert_equal "Posadera", locator.target_name(TestGameEvent.new(:id => 5, :name => "Trainer(3)", :pages => [page]))
  end

  test "a Pokemon drawn with its species' sprite is said by the species, as the game spells it" do
    with_species(:GROWLITHE => 58, :GEODUDE => 74, :EXEGGUTOR => 103, :LAPRAS => 131) do
      said = ["pkmn_growlithe", "GEODUDE_1", "POKEMON_EXEGGUTOR", "Followers/GROWLITHE (2)", "pkmn_lapras3"]
             .each_with_index.map { |g, i| locator.target_name(event(60 + i, g, [TestCmd.new(101, ["¡Grr!"])])) }
      assert_equal ["Especie58", "Especie74", "Especie103", "Especie58", "Especie131"], said
    end
  end

  test "a sprite named like a constant outside the species, a numeric setting's, is said by its file name" do
    Object.const_set(:LEVELCAP, 50)
    assert_equal "LEVELCAP", locator.target_name(event(68, "LEVELCAP", [TestCmd.new(101, ["..."])]))
  ensure
    Object.send(:remove_const, :LEVELCAP) if Object.const_defined?(:LEVELCAP, false)
  end

  test "where the data keeps the species table, a sprite is said by the species it knows under that symbol" do
    table = Module.new
    def table.species_known?(id); [:MALAMAR, :SWABLU].include?(id); end
    def table.species_name(id); "Mon#{id}"; end
    said = Harness.with_provider(table) do
      ["pkmn_malamar", "pkmn_Swablu", "pkmn_celebi4"].each_with_index.map do |g, i|
        locator.target_name(event(90 + i, g, [TestCmd.new(101, ["..."])]))
      end
    end
    assert_equal ["MonMALAMAR", "MonSWABLU", "pkmn_celebi4"], said
  end

  test "a sprite no species is named after, or any with species names off, is said by its file name" do
    with_species(:GROWLITHE => 58) do
      guard = locator.target_name(event(66, "NPC_GUARD", [TestCmd.new(101, ["Alto."])]))
      PokeAccess::Config.name_species = false
      dog = locator.target_name(event(67, "pkmn_growlithe", [TestCmd.new(101, ["¡Grr!"])]))
      assert_equal ["NPC_GUARD", "pkmn_growlithe"], [guard, dog]
    end
  end

  test "an invisible event with text is named by what its text tells it is, in the game's own words" do
    texts = { "Aquí solo hay basura." => :loc_sign_bin, "Hay muchos libros en esta estantería." => :loc_sign_shelf,
              "Locked." => :loc_sign_locked, "The door is locked." => :loc_sign_locked,
              "La porte est verrouillée." => :loc_sign_locked, "A breeze is coming through the window." => :loc_sign_window,
              "It's a TV. A cartoon is on." => :loc_sign_tv, "Nada interesante en este PC." => :loc_sign_computer,
              "ROUTE 117 [R] MAUVILLE CITY" => :loc_sign, "\"Los libros que no se ven son la clave\"." => :loc_sign,
              "MELIA: We can't stand on the shelves all day." => :loc_sign }
    said = texts.keys.each_with_index.map { |s, i| locator.target_name(event(70 + i, "", [TestCmd.new(101, [s])])) }
    assert_equal texts.values.map { |k| t(k) }, said
  end

  test "a sign is named by the text its live page shows, and a sign alone with sign names off" do
    old = TestPage.new(:trigger => 0, :sprite => "", :list => [TestCmd.new(101, ["Aquí solo hay basura."])])
    now = TestPage.new(:trigger => 0, :sprite => "", :list => [TestCmd.new(101, ["Bienvenido a Ciudad Lirio."])],
                       :condition => { :self_switch_valid => true, :self_switch_ch => "A" })
    moved = TestGameEvent.new(:id => 85, :pages => [old, now], :active_page => now)
    bin = event(86, "", [TestCmd.new(101, ["Aquí solo"]), TestCmd.new(401, ["hay basura."])])
    live = [locator.target_name(moved), locator.target_name(bin)]
    PokeAccess::Config.name_signs = false
    assert_equal [t(:loc_sign), t(:loc_sign_bin), t(:loc_sign)], live + [locator.target_name(bin)]
  end

  test "an invisible event whose live page gives an item is that item, then a sign by its text once it is taken" do
    potion = PokeAccess::Data.item_id(:POTION)[1]
    gifts = { "pbReceiveItem" => [TestCmd.new(355, ["pbReceiveItem(:POTION)"])],
              "a word then pbReceiveItem" => [TestCmd.new(101, ["Hay algo dentro."]), TestCmd.new(355, ["pbReceiveItem(:POTION)"])],
              "pbItemBall" => item_branch(:POTION), "Change Items" => [TestCmd.new(126, [1, 0, 0, 1])] }
    bin = [TestCmd.new(101, ["Aquí solo hay basura."])]
    said = gifts.each_with_index.map do |(what, list), i|
      gift = TestPage.new(:trigger => 0, :sprite => "", :list => list)
      left = TestPage.new(:trigger => 0, :sprite => "", :list => bin, :condition => { :self_switch_valid => true, :self_switch_ch => "A" })
      full = TestGameEvent.new(:id => 90 + 2 * i, :pages => [gift, left], :active_page => gift)
      taken = TestGameEvent.new(:id => 91 + 2 * i, :pages => [gift, left], :active_page => left)
      [what, locator.sign_event?(full), locator.target_name(full), locator.target_name(taken)]
    end
    named = t(:loc_object_named, :name => potion)
    assert_equal [["pbReceiveItem", false, named, t(:loc_sign_bin)], ["a word then pbReceiveItem", false, named, t(:loc_sign_bin)],
                  ["pbItemBall", false, named, t(:loc_sign_bin)], ["Change Items", false, t(:loc_object), t(:loc_sign_bin)]], said
  end

  test "an invisible event whose live page takes an item away is a sign by its text, not an object" do
    page = TestPage.new(:trigger => 0, :sprite => "",
                        :list => [TestCmd.new(101, ["Aquí solo hay basura."]), TestCmd.new(126, [1, 1, 0, 1])])
    ev = TestGameEvent.new(:id => 96, :pages => [page], :active_page => page)
    assert_equal [true, t(:loc_sign_bin)], [locator.sign_event?(ev), locator.target_name(ev)]
  end

  test "a two-pose event whose first page takes an item away is no container" do
    a = { :self_switch_valid => true, :self_switch_ch => "A" }
    slot = toggle(6, :sprite => "Cofre", :first => [TestCmd.new(126, [1, 1, 0, 1]), TestCmd.new(123, ["A", 0])], :gate => a)
    map_settled
    assert_equal :rest, locator.toggle_kind(slot)
  end

  test "a visible wild Pokemon is said wild, and shiny when it is, as its sprite shows it" do
    with_poke_events do |klass|
      plain = klass.new(:id => 2)
      plain.pokemon = Poke.build(:name => "Pikachu")
      shiny = klass.new(:id => 3)
      shiny.pokemon = Poke.build(:name => "Pikachu", :shiny => true)
      wild = t(:loc_wild, :name => "Pikachu")
      assert_equal [wild, "#{wild}, #{t(:pk_shiny)}"], [locator.target_name(plain), locator.target_name(shiny)]
    end
  end

  test "a name's engine notes go unsaid: how far a counter or a sight reaches, a bush depth, a trainer's range" do
    names = ["Counter(3)", "Sight(3)", "Watchog Counter(3)", "Claydol Sentry Counter(4)", "Cultist Trainer(3)",
             "wailord bush_depth(14)"]
    evs = names.each_with_index.map { |name, i| World.event(:id => i + 2, :name => name, :sprite => "npc_girl") }
    plain = World.event(:id => 9, :sprite => "npc_girl")
    map_settled
    unnamed = locator.target_name(plain)
    assert_equal [unnamed, unnamed, "Watchog", "Claydol Sentry", "Cultist Trainer", "wailord"],
                 evs.map { |ev| locator.target_name(ev) }
  end

  test "names a sign, a PC, a berry plant, a beam, an item ball, a person by name and a tile target by what each is" do
    pc = event(4, "", [TestCmd.new(355, ["pbPokeCenterPC"])])
    ball = event(5, "Object ball", [TestCmd.new(355, ["pbItemBall(:REPEL)"])])
    sign = World.event(:kind => :sign, :id => 1)
    berry = World.event(:id => 3, :name => "BerryPlant", :sprite => "berrytree")
    rosa = World.event(:id => 6, :name => "Rosa", :sprite => "npc_girl")
    beam = World.event(:id => 8, :sprite => "rayosAzules")
    map_settled
    { sign => t(:loc_sign), pc => t(:loc_pc), berry => t(:loc_berry_plant), beam => t(:loc_beam),
      ball => t(:loc_object_named, :name => "Repel"), rosa => "Rosa",
      locator::SurfaceTarget.new(1, 1, "Cueva", :surf_water) => "Cueva" }.each do |ev, want|
      assert_equal want, locator.target_name(ev), "for #{ev.name.inspect}"
    end
  end

  test "a door to a map with no name is an exit, unless the door has a name of its own" do
    doors = { World.event(:kind => :door, :id => 3) => t(:loc_exit),
              World.event(:kind => :door, :id => 4, :name => "Puerta") => t(:loc_exit),
              World.event(:kind => :door, :id => 7, :name => "Cueva") => "Cueva" }
    map_settled
    doors.each { |door, want| assert_equal want, locator.target_name(door), "the door #{door.name.inspect}" }
  end

  test "reads the item a ball gives out of its script, a conditional branch's too, and one handed over unseen" do
    { TestCmd.new(355, ["pbItemBall(PBItems::REPEL)"]) => "Repel",
      TestCmd.new(355, ["pbItemBall(:REPEL)"]) => "Repel",
      TestCmd.new(355, ["pbStoreItem(:RARECANDY,1)"]) => "Caramelo Raro",
      TestCmd.new(111, [12, "pbItemBall(:REPEL)"]) => "Repel",
      TestCmd.new(355, ["pbReceiveItem(:REPEL)"]) => "Repel" }.each do |cmd, want|
      assert_equal want, locator.item_name(event(1, "", [cmd])), "from #{cmd.parameters.inspect}"
    end
  end

  test "an event that hands over no item names no item, nor someone drawn who hands one over with pbReceiveItem" do
    [["", TestCmd.new(101, ["Hola"])], ["ricachona", TestCmd.new(355, ["pbReceiveItem(:REPEL)"])]].each do |sprite, cmd|
      assert_nil locator.item_name(event(1, sprite, [cmd])), "from #{cmd.parameters.inspect}"
    end
  end

  test "an item the game cannot name is named from its symbol" do
    unnamed = Module.new
    def unnamed.item_id(sym); [sym, nil]; end
    ball = event(1, "", [TestCmd.new(355, ["pbItemBall(:SILPHSCOPE)"])])
    Harness.with_provider(unnamed) { assert_equal "Silphscope", locator.item_name(ball) }
  end

  test "a field-move obstacle or pickup is named by its event name, gen 6's bare names and modern ones alike" do
    { "Rock" => :loc_rock_smash, "Tree" => :loc_cut_tree, "Boulder" => :loc_strength_boulder,
      "cuttree" => :loc_cut_tree, "Rock_Smash" => :loc_rock_smash, "SmashRock" => :loc_rock_smash,
      "Strength Boulder" => :loc_strength_boulder, "HeadbuttTree" => :loc_headbutt_tree,
      "HiddenItem" => :loc_hidden_item, "BerryPlant" => :loc_berry_plant }.each do |name, key|
      assert_equal key, locator.fieldmove_label(TestGameEvent.new(:name => name)), "an event named #{name.inspect}"
    end
  end

  test "a boulder and a headbutt tree are said without their move in a game that defines no function for it" do
    assert_equal [t(:loc_big_rock), t(:loc_shakable_tree)], move_obstacle_names
  end

  test "a boulder and a headbutt tree are said by their move under a game's own profile that defines its function" do
    with_top_level(:pbStrength) do
      with_kernel_function(:pbHeadbutt) do
        assert_equal [t(:loc_strength_boulder), t(:loc_headbutt_tree)], move_obstacle_names
        load File.join(Harness::ROOT, "games", "generic", "constants.rb")
        assert_equal [t(:loc_big_rock), t(:loc_shakable_tree)], move_obstacle_names, "under the generic profile"
      end
    end
  end

  test "a headbutt tree is said without its move in a game with no pbHeadbutt, the boulder by Strength" do
    with_kernel_function(:pbStrength) do
      assert_equal [t(:loc_strength_boulder), t(:loc_shakable_tree)], move_obstacle_names
    end
  end

  test "a name merely holding an obstacle's word, or a character who talks, is no obstacle" do
    ["Rockstar", "Treeko", "Boulders", ""].each do |name|
      assert_nil locator.fieldmove_label(TestGameEvent.new(:name => name)), "an event named #{name.inspect}"
    end
    rock = TestGameEvent.new(:name => "Rock", :pages => [TestPage.new(:list => [TestCmd.new(101, ["Soy Rock."])])])
    assert_nil locator.fieldmove_label(rock), "Rock, who talks"
  end

  test "an item ball is something to do, listed and pinged as an object whatever its sprite" do
    ball = event(21, "itemball", item_branch(:REPEL))
    map_settled
    assert_equal true, locator.item_ball?(ball), "an item ball"
    assert_equal true, locator.interactable?(ball), "something to do"
    assert_equal true, locator.in_category?(ball, :objects), "listed with the objects"
    assert_equal false, locator.in_category?(ball, :people), "not with the people its sprite might suggest"
    assert_equal :object, PokeAccess::Sound::Scene.family_of(ball), "pinged as an object"
  end

  test "a hidden item, drawn with nothing, is something to do the sonar leaves silent" do
    hidden = event(22, "", item_branch(:ETHER))
    map_settled
    assert_equal true, locator.interactable?(hidden), "something to do"
    assert_nil PokeAccess::Sound::Scene.family_of(hidden), "left to the Itemfinder"
  end

  test "an event stepped on is something to do only when it shows text, runs a script or hands goods" do
    { [1, TestCmd.new(101, ["¡Cuidado!"])] => true, [1, TestCmd.new(102, [["Sí", "No"], 2])] => true,
      [2, TestCmd.new(355, ["pbHealAll"])] => true, [1, TestCmd.new(125, [0, 0, 100])] => true,
      [1, TestCmd.new(126, [1, 0, 0, 1])] => true, [1, TestCmd.new(127, [1, 0, 0, 1])] => true,
      [1, TestCmd.new(128, [1, 0, 0, 1])] => true, [2, TestCmd.new(117, [5])] => true,
      [1, TestCmd.new(121, [5, 5, 0])] => false, [3, TestCmd.new(101, ["Hola"])] => false,
      [4, TestCmd.new(101, ["Hola"])] => false }.each do |(trigger, cmd), want|
      page = TestPage.new(:trigger => trigger, :sprite => "", :list => [cmd, TestCmd.new(0, [])])
      ev = TestGameEvent.new(:id => 40, :pages => [page])
      assert_equal want, locator.interactable?(ev), "trigger #{trigger} running #{cmd.code}"
    end
  end

  test "an event with no command list is nothing to do" do
    { 0 => 42, 1 => 43 }.each do |trigger, id|
      ev = TestGameEvent.new(:id => id, :pages => [TestPage.new(:trigger => trigger, :list => nil)])
      assert_equal false, locator.interactable?(ev), "trigger #{trigger}"
    end
  end

  test "an event whose sprite cannot be read is kept as something to do" do
    ev = TestGameEvent.new(:id => 44, :pages => [TestPage.new(:trigger => 0, :list => [TestCmd.new(121, [5, 5, 0])])])
    def ev.character_name; raise "unreadable"; end
    assert_equal true, locator.interactable?(ev)
  end

  test "a drawn control that only flips a switch is something to press; the same commands unseen are a helper" do
    press = [TestCmd.new(250, [nil]), TestCmd.new(224, [nil, 10]), TestCmd.new(225, [5, 5, 5]),
             TestCmd.new(106, [12]), TestCmd.new(121, [265, 265, 0]), TestCmd.new(0, [])]
    lever = TestGameEvent.new(:id => 2, :name => "EV002/noShadow/", :tile_id => 718,
                              :pages => [TestPage.new(:trigger => 0, :sprite => "", :list => press)])
    helper = TestGameEvent.new(:id => 3, :name => "EV003",
                               :pages => [TestPage.new(:trigger => 0, :sprite => "", :list => press)])
    $game_map.events[2] = lever
    $game_map.events[3] = helper
    map_settled
    assert_equal true, locator.examinable?(lever), "the drawn tile that opens the way can be examined"
    assert_equal true, locator.in_category?(lever, :extras), "so it is listed with the extras"
    assert_equal true, locator.in_category?(lever, :all), "and with everything"
    assert_equal :object, PokeAccess::Sound::Scene.family_of(lever), "the sonar pings it as an object"
    assert_equal false, locator.examinable?(helper), "the helper cannot be examined"
    assert_equal false, locator.in_category?(helper, :extras), "nor is it listed"
    assert_nil PokeAccess::Sound::Scene.family_of(helper), "nor pinged"
  end

  test "a drawn control that sets a variable or a self switch is something to press as well" do
    [TestCmd.new(122, [5, 5, 0, 0, 1]), TestCmd.new(123, ["A", 0])].each do |cmd|
      page = TestPage.new(:trigger => 0, :sprite => "", :list => [cmd, TestCmd.new(0, [])])
      control = TestGameEvent.new(:id => 50, :tile_id => 718, :pages => [page])
      assert_equal true, locator.examinable?(control), "running #{cmd.code}"
    end
  end

  test "a numbered sprite names the species it shows, shiny or not; any other number is an object" do
    mons = { "789" => PBSpecies.getName(789), "025s" => PBSpecies.getName(25), "001" => PBSpecies.getName(1),
             "000" => t(:loc_object), "0001" => t(:loc_object) }.each_with_index.map do |(sprite, want), i|
      [World.event(:id => 18 + i, :sprite => sprite), want]
    end
    map_settled
    mons.each { |mon, want| assert_equal want, locator.target_name(mon), "the sprite #{mon.character_name}" }
  end

  test "a trainer charset names its class, else keeps its file name; a name of punctuation alone is no name" do
    people = [["trchar065", "EV1", "Posadera"], ["trcharHIKER_2", "EV2", "Montanero"],
              ["trainer_HIKER_M", "EV3", "Montanero"], ["trchar099", "EV4", "trchar099"],
              ["trcharUNKNOWN", "EV5", "trcharUNKNOWN"], ["npc_girl", "EV6", "npc_girl"], ["trchar065", "'", "Posadera"],
              ["trchar065", "Rosa", "Rosa"]].each_with_index.map do |(sprite, name, want), i|
      [World.event(:id => 30 + i, :name => name, :sprite => sprite), want]
    end
    map_settled
    people.each do |ev, want|
      assert_equal want, locator.target_name(ev), "#{ev.name.inspect} drawn as #{ev.character_name}"
    end
  end

  test "the naming grid says the character under the cursor in the tab shown, a gap as a space" do
    keyboard = FourTabs.new
    squares = { [0, 0] => "A", [1, 2] => "c", [2, 0] => "á", [3, 1] => ".", [0, 10] => t(:key_space), [0, 13] => "" }
    squares.each do |(mode, pos), want|
      assert_equal want, PokeAccess::CursorNaming.focus_text(keyboard, mode, pos), "tab #{mode}, square #{pos}"
    end
  end

  test "a four-tab keyboard names its controls by their place" do
    { -1 => t(:nm_ok), -2 => t(:nm_back), -3 => t(:nm_symbols), -4 => t(:nm_accents), -5 => t(:nm_lower),
      -6 => t(:nm_upper), -7 => "" }.each do |pos, want|
      assert_equal want, PokeAccess::CursorNaming.focus_text(FourTabs.new, 0, pos), "at #{pos}"
    end
  end

  test "a three-tab keyboard names its own tabs, not the four-tab ones" do
    { -1 => t(:nm_ok), -2 => t(:nm_back), -3 => t(:nm_symbols), -4 => t(:nm_lower), -5 => t(:nm_upper),
      -6 => "" }.each do |pos, want|
      assert_equal want, PokeAccess::CursorNaming.focus_text(ThreeTabs.new, 0, pos), "at #{pos}"
    end
  end

  test "a keyboard of a size it has no tab names for names OK and back alone" do
    { -1 => t(:nm_ok), -2 => t(:nm_back), -3 => "", -7 => "" }.each do |pos, want|
      assert_equal want, PokeAccess::CursorNaming.focus_text(FiveTabs.new, 0, pos), "at #{pos}"
    end
  end

  test "a screen without a character grid names no character, and its controls as a four-tab keyboard's" do
    bare = Object.new
    assert_equal "", PokeAccess::CursorNaming.focus_text(bare, 0, 0), "a square"
    assert_equal t(:nm_upper), PokeAccess::CursorNaming.focus_text(bare, 0, -6), "the first tab"
  end

  test "the naming screen opens with its help, a Pokemon's sex sign and what is already written" do
    { ["¿Cómo te llamas?", "", 1, nil] => "¿Cómo te llamas?",
      ["¿Mote para Pikachu?", "Pika", 2, Poke.build(:gender => 1)] =>
        "¿Mote para Pikachu? ♀ #{t(:nm_current, :t => 'Pika')}",
      ["Nombre de la caja", "Caja 1", 3, nil] => "Nombre de la caja #{t(:nm_current, :t => 'Caja 1')}",
      ["\\c[1]¿Mote?", " ", 2, Poke.build(:gender => 2)] => "¿Mote?" }.each do |args, want|
      assert_equal want, PokeAccess::CursorNaming.caption(*args), "for #{args.first(3).inspect}"
    end
  end

  test "on opening, the naming screen says the character under the cursor, queued" do
    PokeAccess::CursorNaming.poll(keyboard(FourTabs, 0, 0, ""))
    assert_equal [["A", false]], SpeakCapture.log
  end

  test "moving the cursor says the character it lands on, interrupting, and staying says nothing" do
    scene = keyboard(FourTabs, 0, 0, "")
    PokeAccess::CursorNaming.poll(scene)
    SpeakCapture.clear
    scene.instance_variable_set(:@cursorpos, 1)
    PokeAccess::CursorNaming.poll(scene)
    assert_equal [["B", true]], SpeakCapture.log, "on the move"
    SpeakCapture.clear
    PokeAccess::CursorNaming.poll(scene)
    assert_nothing_spoken "staying"
  end

  test "switching tabs under the cursor names the keyboard's own tab, then the character" do
    [[FourTabs, 1, 1, "#{t(:nm_lower)}. b"], [FourTabs, 1, 2, "#{t(:nm_accents)}. é"],
     [FourTabs, 0, 1, "#{t(:nm_lower)}. a"], [ThreeTabs, 1, 2, "#{t(:nm_symbols)}. ."],
     [FiveTabs, 1, 2, "2"]].each do |layout, pos, mode, want|
      scene = keyboard(layout, 0, pos, "")
      PokeAccess::CursorNaming.poll(scene)
      SpeakCapture.clear
      scene.instance_variable_set(:@mode, mode)
      PokeAccess::CursorNaming.poll(scene)
      assert_equal [[want, true]], SpeakCapture.log, "#{layout.name.split('::').last}, square #{pos}, to tab #{mode}"
    end
  end

  test "choosing a tab on its control says the control once, the tab not named before it" do
    scene = keyboard(FourTabs, 0, -5, "")
    PokeAccess::CursorNaming.poll(scene)
    SpeakCapture.clear
    scene.instance_variable_set(:@mode, 1)
    PokeAccess::CursorNaming.poll(scene)
    assert_equal [[t(:nm_lower), true]], SpeakCapture.log
  end

  test "switching tabs on a screen without a character grid names the four-tab keyboard's tab" do
    scene = keyboard(Object, 0, 1, "")
    PokeAccess::CursorNaming.poll(scene)
    scene.instance_variable_set(:@mode, 2)
    PokeAccess::CursorNaming.poll(scene)
    assert_equal [["#{t(:nm_accents)}.", true]], SpeakCapture.log, "no character under the cursor, then the third tab"
  end

  test "a typed character is echoed, a space as a space, then the control the cursor jumps to" do
    scene = keyboard(FourTabs, 0, 0, "")
    PokeAccess::CursorNaming.poll(scene)
    { "A" => [["A", true]], "A " => [[t(:key_space), true]] }.each do |text, want|
      SpeakCapture.clear
      scene.instance_variable_get(:@helper).text = text
      PokeAccess::CursorNaming.poll(scene)
      assert_equal want, SpeakCapture.log, "typed up to #{text.inspect}"
    end
    SpeakCapture.clear
    scene.instance_variable_get(:@helper).text = "A B"
    scene.instance_variable_set(:@cursorpos, -1)
    PokeAccess::CursorNaming.poll(scene)
    assert_equal [["B", true], [t(:nm_ok), false]], SpeakCapture.log, "the name full, the cursor on OK"
  end

  test "typing that switches the tab names the tab after the character" do
    scene = keyboard(FourTabs, 0, 0, "")
    PokeAccess::CursorNaming.poll(scene)
    SpeakCapture.clear
    scene.instance_variable_get(:@helper).text = "A"
    scene.instance_variable_set(:@mode, 1)
    PokeAccess::CursorNaming.poll(scene)
    assert_equal [["A", true], ["#{t(:nm_lower)}. a", false]], SpeakCapture.log
  end

  test "a deletion is said with the character deleted" do
    scene = keyboard(FourTabs, 0, 0, "AB")
    PokeAccess::CursorNaming.poll(scene)
    SpeakCapture.clear
    scene.instance_variable_get(:@helper).text = "A"
    PokeAccess::CursorNaming.poll(scene)
    assert_equal [[t(:te_deleted_char, :c => "B"), true]], SpeakCapture.log
  end

  test "an item ball's mixed-case id is looked up as the game writes it" do
    cased = Module.new
    def cased.item_id(sym); sym.to_s == "ACapsula" ? [543, "Chapa Fuerte"] : [0, nil]; end
    ball = event(30, "", [TestCmd.new(355, ["pbItemBall(:ACapsula)"])])
    Harness.with_provider(cased) { assert_equal "Chapa Fuerte", locator.item_name(ball) }
  end

  test "a floor item ball the mapper named Item is said by the item it holds" do
    potion = PokeAccess::Data.item_id(:POTION)[1]
    ["Item", "item", "ItemBall"].each_with_index do |name, i|
      page = TestPage.new(:trigger => 0, :sprite => "Object ball", :list => item_branch(:POTION))
      ball = TestGameEvent.new(:id => 31 + i, :name => name, :pages => [page])
      assert_equal t(:loc_object_named, :name => potion), locator.target_name(ball), "named #{name.inspect}"
    end
  end

  test "with item names off an unnamed item ball is an object, whatever its sprite is called" do
    PokeAccess::Config.name_items = false
    assert_equal t(:loc_object), locator.target_name(event(34, "BWObjects", item_branch(:POTION)))
  end

  test "a person who talks and then hands an item over with pbItemBall stays a person, named by the sprite" do
    giver = event(35, "ricachona", [TestCmd.new(101, ["Toma esto."]), TestCmd.new(355, ["pbItemBall(:AIRBALLOON)"])])
    map_settled
    assert_equal [:people, "ricachona"], [locator.event_category(giver), locator.target_name(giver)]
  end

  test "a person whose later page hands an item ball over is a person while that page is not the live one" do
    talk = TestPage.new(:trigger => 0, :sprite => "Lider 1 bw", :list => [TestCmd.new(101, ["Hola."])])
    rematch = TestPage.new(:trigger => 0, :sprite => "Lider 1 bw", :list => item_branch(:DCAPSULA))
    brock = TestGameEvent.new(:id => 36, :pages => [talk, rematch])
    assert_equal :people, locator.event_category(brock)
  end

  test "a field-move obstacle is an object whatever its sprite is called" do
    { "cuttree" => "arbolito", "smashrock" => "golperoca", "CutTree" => "BW (8)" }.each_with_index do |(name, sprite), i|
      page = TestPage.new(:trigger => 0, :sprite => sprite, :list => [TestCmd.new(355, ["pbSmashThisEvent"])])
      ev = TestGameEvent.new(:id => 40 + i, :name => name, :pages => [page])
      assert_equal :objects, locator.event_category(ev), "#{name} drawn as #{sprite}"
    end
  end

  test "a felled tree or a smashed rock the engine left with no page is no obstacle" do
    ["CutTree", "Rock"].each_with_index do |name, i|
      ev = vanish(TestGameEvent.new(:id => 45 + i, :name => name, :pages => [TestPage.new(:sprite => "Object tree 1")]))
      assert_nil locator.fieldmove_label(ev), name
    end
  end

  test "a rock whose page breaks it with Rock Smash keeps its label though the page says something" do
    list = [TestCmd.new(111, [12, "Kernel.pbRockSmash"]), TestCmd.new(355, ["pbSmashThisEvent"], 1),
            TestCmd.new(411, []), TestCmd.new(101, ["Una roca."], 1), TestCmd.new(412, [])]
    rock = TestGameEvent.new(:name => "Rock", :pages => [TestPage.new(:sprite => "Object rock", :list => list)])
    assert_equal :loc_rock_smash, locator.fieldmove_label(rock)
  end

  test "a push tile pushes only while its pushing page is the live one" do
    push = TestPage.new(:trigger => 1, :sprite => "", :list => [World.move_player([4]), TestCmd.new(0, [])])
    empty = TestPage.new(:trigger => 0, :sprite => "", :list => [TestCmd.new(0, [])])
    talk = TestPage.new(:trigger => 0, :sprite => "trchar163", :list => [TestCmd.new(101, ["Alto."])])
    belt = $game_map.events[50] = TestGameEvent.new(:id => 50, :pages => [push, empty])
    off = $game_map.events[51] = TestGameEvent.new(:id => 51, :pages => [push, empty], :active_page => empty)
    grunt = $game_map.events[52] = TestGameEvent.new(:id => 52, :pages => [talk, push], :active_page => talk)
    map_settled
    assert_equal [true, false, false], [belt, off, grunt].map { |ev| locator.push_tile?(ev) }
  end

  private

  # Runs the block with the VOE plugin's Game_PokeEvent, a map event carrying its Pokemon, defined; removed after.
  def with_poke_events
    Object.const_set(:Game_PokeEvent, Class.new(TestGameEvent) { attr_accessor :pokemon })
    yield Object.const_get(:Game_PokeEvent)
  ensure
    Object.send(:remove_const, :Game_PokeEvent) if Object.const_defined?(:Game_PokeEvent, false)
  end

  # What the locator calls an event named Boulder and one named HeadbuttTree.
  def move_obstacle_names
    ["Boulder", "HeadbuttTree"].map { |name| locator.target_name(TestGameEvent.new(:id => 61, :name => name)) }
  end

  # Runs the block with fn defined as v19+ scripts define a field move's function: a top-level def.
  def with_top_level(fn)
    Object.send(:define_method, fn) { |*_args| nil }
    Object.send(:private, fn)
    yield
  ensure
    Object.send(:remove_method, fn) if Object.private_method_defined?(fn)
  end

  # Runs the block with fn defined as gen-6 scripts define a field move's function: def Kernel.fn.
  def with_kernel_function(fn)
    Kernel.define_singleton_method(fn) { |*_args| nil }
    yield
  ensure
    Kernel.singleton_class.send(:remove_method, fn) if Kernel.singleton_class.method_defined?(fn, false)
  end

  # Leaves ev as the engine leaves an event none of whose pages holds, or one erased: no page, list, trigger or sprite.
  def vanish(ev)
    ev.instance_variable_set(:@active, nil)
    ev.instance_variable_set(:@list, nil)
    ev.instance_variable_set(:@trigger, nil)
    ev.character_name = ""
    ev
  end

  # The module under test.
  def locator
    PokeAccess::Locator
  end

  # A spoken text by its key.
  def t(key, vars = nil)
    PokeAccess::I18n.t(key, vars)
  end

  # An action-button event on the map drawn with sprite and running list.
  def event(id, sprite, list)
    page = TestPage.new(:trigger => 0, :sprite => sprite, :list => list)
    $game_map.events[id] = TestGameEvent.new(:id => id, :pages => [page])
  end

  # Runs the block with the gen-6 species constants given (name => number) defined on PBSpecies, removed after.
  def with_species(consts)
    consts.each { |k, v| PBSpecies.const_set(k, v) }
    yield
  ensure
    consts.each_key { |k| PBSpecies.send(:remove_const, k) if PBSpecies.const_defined?(k) }
  end

  # A two-pose event on the map, drawn as :sprite ("lever") in pattern 0 then 1 and in the rows :rows gives: page 1
  # runs :first (switch 50 on), page 2, behind :gate (switch 50), runs :second; :active picks the live page.
  def toggle(id, opts = {})
    rows = opts.fetch(:rows, [2, 2])
    sprite = opts.fetch(:sprite, "lever")
    pages = [TestPage.new(:sprite => sprite, :pattern => 0, :direction => rows[0],
                          :list => opts.fetch(:first, [TestCmd.new(121, [50, 50, 0])])),
             TestPage.new(:sprite => sprite, :pattern => 1, :direction => rows[1], :list => opts.fetch(:second, []),
                          :condition => opts.fetch(:gate, { :switch1_valid => true, :switch1_id => 50 }))]
    $game_map.events[id] = TestGameEvent.new(:id => id, :x => id, :y => 3, :name => opts.fetch(:name, "EV#{id}"),
                                             :pages => pages, :active_page => pages[opts.fetch(:active, 0)])
  end

  # A v19+ item ball's commands: a Conditional Branch on pbItemBall(:item) that sets self switch A.
  def item_branch(item)
    [TestCmd.new(111, [12, "pbItemBall(:#{item})"]), TestCmd.new(123, ["A", 0]), TestCmd.new(0, []), TestCmd.new(412, [])]
  end

  # Rebuilds what the locator keeps per map id (its levers and push tiles) for the events now on the map, as entering
  # the map does: tests share the map ids.
  def map_settled
    World.next_frame
    locator.refresh_lever_cache
    locator.refresh_push_cache
  end

  # A naming screen of the layout's class on tab mode, its cursor at pos and text in its box, not polled yet.
  def keyboard(layout, mode, pos, text)
    scene = layout.new
    scene.instance_variable_set(:@mode, mode)
    scene.instance_variable_set(:@cursorpos, pos)
    scene.instance_variable_set(:@helper, Helper.new(text))
    scene
  end
end
