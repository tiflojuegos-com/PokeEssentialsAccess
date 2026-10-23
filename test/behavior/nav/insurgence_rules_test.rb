# Insurgence's field rules (games/insurgence): its own field-move conditions, the rolling boulders, the Ancient Tower's
# pitfalls, waterfalls without a crest, the Rock Climb, sludge, and the names of its recurring events. Only the profile's modules are
# loaded here; their overrides belong to the Insurgence process (insurgence_profile_test).
unless defined?(PokeAccess::InsurgenceNames)
  %w[field_moves.rb routes.rb water.rb naming.rb].each do |file|
    path = File.join(Harness::ROOT, "games", "insurgence", file)
    Harness.source(path).scan(/^module PokeAccess\r?\n.*?^end\r?\n/m).each { |m| eval(m, TOPLEVEL_BINDING, path) }
  end
end

class InsurgenceRulesTest < PokeAccessTest
  Rules = PokeAccess::InsurgenceFieldMoves
  Names = PokeAccess::InsurgenceNames
  Pits = PokeAccess::InsurgencePits
  Falls = PokeAccess::InsurgenceFalls
  Climb = PokeAccess::InsurgenceRockClimb
  Water = PokeAccess::InsurgenceWater
  Effects = PokeAccess::Routes::Effects
  Moves = PokeAccess::Routes::Moves

  # A party move as the rules read it.
  Move = Struct.new(:id, :type, :basedamage)
  # The game's ids the rules ask for, by the table that holds them.
  IDS = { PBItems => { :LAPRAS => 569, :JETPACK => 570, :SCUBAGEAR => 572, :HIKINGBOOTS => 573, :PICKAXE => 574 },
          PBMoves => { :STRENGTH => 70, :ICYWIND => 196, :KARATECHOP => 2 }, PBTypes => { :FIGHTING => 1 } }
  LAPRAS = 569
  CARPET = 570
  SCUBA = 572
  BOOTS = 573
  PICKAXE = 574
  GYM1 = 4
  ICY_WIND = Move.new(196, 14, 55)
  STRENGTH = Move.new(70, 0, 80)
  KARATE_CHOP = Move.new(2, 1, 50)
  TACKLE = Move.new(33, 0, 40)
  # The move-route code that steps each way, as the rolling boulders' branches use them.
  STEP_MOVES = { 2 => 1, 4 => 2, 6 => 3, 8 => 4 }

  test "takes over Surf, Strength, Rock Smash, Waterfall, Dive, Rock Climb and Cut, and leaves any other move to " \
       "the core" do
    { :SURF => true, :STRENGTH => true, :ROCKSMASH => true, :WATERFALL => true, :DIVE => true, :ROCKCLIMB => true,
      :CUT => true, :FLY => false, :FLASH => false, :HEADBUTT => false }.each do |move, want|
      assert_equal want, Rules.handles?(move), move.to_s
    end
  end

  test "has no answer of its own for a move of other rules" do
    assert_nil in_game { Rules.can?(:FLY) }
  end

  test "Surf waits for the first gym's switch, Lapras pack or not" do
    assert_equal false, in_game([LAPRAS]) { knowing(true) { Rules.can?(:SURF) } }
  end

  test "with the first gym's switch the Instant Lapras pack surfs with no Pokemon knowing the move" do
    $game_switches[GYM1] = true
    assert_equal true, in_game([LAPRAS]) { knowing(false) { Rules.can?(:SURF) } }
  end

  test "with the switch and no Lapras pack, Surf is a Pokemon knowing it, as the core tells" do
    $game_switches[GYM1] = true
    { true => true, false => false, nil => nil }.each do |knows, want|
      assert_answer want, in_game { knowing(knows) { Rules.can?(:SURF) } }, "the core says #{knows.inspect}"
    end
  end

  test "Cut waits for switch 6, then takes a Pokemon that knows it, with no badge" do
    got = [false, true].map do |on|
      $game_switches[6] = on
      in_game { knowing(true) { Rules.can?(:CUT) } }
    end
    assert_equal [false, true], got
  ensure
    $game_switches[6] = false
  end

  test "tells a Rock that calls the stock Kernel.pbRockSmash from one running the game's own smash" do
    stock = Object.new
    stock.instance_variable_set(:@list, [TestCmd.new(111, [12, "Kernel.pbRockSmash"])])
    own = Object.new
    own.instance_variable_set(:@list, [TestCmd.new(355, ["doInsurgenceRockSmash"])])
    assert_equal [true, false], [stock, own].map { |ev| Rules.stock_rock?(:move => :ROCKSMASH, :ev => ev) }
  end

  test "the stock Rock Smash waits for switch 10, then takes the Pickaxe or a Pokemon that knows the move" do
    cases = [[false, [PICKAXE], false], [true, [PICKAXE], false], [true, [], false], [true, [], true]]
    got = cases.map do |on, items, knows|
      $game_switches[10] = on
      in_game(items) { knowing(knows) { Rules.stock_rock_clear? } }
    end
    assert_equal [false, true, false, true], got
  ensure
    $game_switches[10] = false
  end

  test "Waterfall takes six badges and the Magic Carpet" do
    { [5, [CARPET]] => false, [6, [CARPET]] => true, [8, [CARPET]] => true,
      [6, [SCUBA, BOOTS]] => false }.each do |(badges, items), want|
      got = in_game(items, [], badges) { Rules.can?(:WATERFALL) }
      assert_equal want, got, "#{badges} badges, items #{items.inspect}"
    end
  end

  test "Waterfall counts the badges the game's own setting asks for" do
    with_constant(Object, :BADGEFORWATERFALL, 3) do
      assert_equal [false, true], [2, 3].map { |n| in_game([CARPET], [], n) { Rules.can?(:WATERFALL) } }
    end
  end

  test "Waterfall has no answer with no player to count the badges" do
    was = $Trainer
    $Trainer = nil
    assert_nil with_ids { Rules.can?(:WATERFALL) }
  ensure
    $Trainer = was
  end

  test "Dive takes the Scuba Gear alone and Rock Climb the Hiking Boots alone" do
    { [:DIVE, [SCUBA]] => true, [:DIVE, [BOOTS, CARPET, LAPRAS]] => false,
      [:ROCKCLIMB, [BOOTS]] => true, [:ROCKCLIMB, [SCUBA, CARPET, LAPRAS]] => false }.each do |(move, items), want|
      assert_equal want, in_game(items) { Rules.can?(move) }, "#{move} with #{items.inspect}"
    end
  end

  test "a move whose item the game's tables lack has no answer" do
    assert_nil in_game([BOOTS], [], 0, [:HIKINGBOOTS]) { Rules.can?(:ROCKCLIMB) }
  end

  test "a move with no bag to look in has no answer" do
    was = $PokemonBag
    $PokemonBag = nil
    assert_nil with_ids { Rules.can?(:DIVE) }
  ensure
    $PokemonBag = was
  end

  test "Strength waits for the first gym's switch" do
    assert_equal false, in_game([], [Poke.build(:moves => [STRENGTH, ICY_WIND])]) { Rules.can?(:STRENGTH) }
  end

  test "after the first gym's switch any of its thirteen moves pushes boulders, and no other move does" do
    $game_switches[GYM1] = true
    { [ICY_WIND] => true, [STRENGTH] => true, [TACKLE, KARATE_CHOP] => false }.each do |moves, want|
      got = in_game([], [Poke.build(:moves => moves)]) { Rules.can?(:STRENGTH) }
      assert_equal want, got, moves.map { |m| m.id }.inspect
    end
  end

  test "Strength is free once used on the map, switch or not" do
    was = $PokemonMap
    $PokemonMap = Struct.new(:strengthUsed).new(true)
    assert_equal true, in_game { Rules.can?(:STRENGTH) }
  ensure
    $PokemonMap = was
  end

  test "Strength and Rock Smash have no answer with no party to look through" do
    $game_switches[GYM1] = true
    assert_equal [nil, nil], with_ids { [Rules.can?(:STRENGTH), Rules.can?(:ROCKSMASH)] }
  end

  test "Rock Smash takes a damaging Fighting-type move, with no switch" do
    assert_equal true, in_game([], [Poke.build(:moves => [TACKLE, KARATE_CHOP])]) { Rules.can?(:ROCKSMASH) }
  end

  test "Rock Smash takes the weakest damaging Fighting move and the first move id" do
    { "1 damage" => Move.new(2, 1, 1), "move id 1" => Move.new(1, 1, 50) }.each do |what, mv|
      assert_equal true, in_game([], [Poke.build(:moves => [mv])]) { Rules.can?(:ROCKSMASH) }, what
    end
  end

  test "Rock Smash refuses a Fighting move that does no damage, a move of another type and an empty slot" do
    { "no damage" => Move.new(2, 1, 0), "another type" => TACKLE,
      "an empty slot" => Move.new(0, 1, 50) }.each do |what, mv|
      assert_equal false, in_game([], [Poke.build(:moves => [mv])]) { Rules.can?(:ROCKSMASH) }, what
    end
  end

  test "with no Fighting type in the game's tables no move breaks rocks, not even one of unknown type" do
    party = [Poke.build(:moves => [Move.new(2, nil, 50)])]
    assert_equal false, in_game([], party, 0, [:FIGHTING]) { Rules.can?(:ROCKSMASH) }
  end

  test "goes through the whole party, past a Pokemon with no moves to read and an empty move slot" do
    party = [Poke.build(:moves => nil), Poke.build(:moves => [nil, KARATE_CHOP])]
    assert_equal [true, "Mov2"], in_game([], party) { [Rules.can?(:ROCKSMASH), Rules.name(:ROCKSMASH)] }
  end

  test "names the Strength move the game will use: the first one in party order" do
    party = [Poke.build(:moves => [TACKLE, ICY_WIND]), Poke.build(:moves => [STRENGTH])]
    assert_equal "Mov196", in_game([], party) { Rules.name(:STRENGTH) }
  end

  test "leaves Strength its own name when no move in the party can push" do
    assert_nil in_game([], [Poke.build(:moves => [TACKLE])]) { Rules.name(:STRENGTH) }
  end

  test "names the Fighting move Rock Smash will use" do
    party = [Poke.build(:moves => [TACKLE]), Poke.build(:moves => [Move.new(9, 1, 0), KARATE_CHOP])]
    assert_equal "Mov2", in_game([], party) { Rules.name(:ROCKSMASH) }
  end

  test "says what Rock Smash takes when no move in the party can break the rock" do
    assert_equal t(:ins_fighting_move), in_game([], [Poke.build(:moves => [TACKLE])]) { Rules.name(:ROCKSMASH) }
  end

  test "names the item that stands in for Waterfall, Dive and Rock Climb" do
    { :WATERFALL => "Item570", :DIVE => "Item572", :ROCKCLIMB => "Item573" }.each do |move, want|
      assert_equal want, in_game { Rules.name(move) }, move.to_s
    end
  end

  test "has no name for an item the game's tables lack" do
    assert_nil in_game([], [], 0, [:JETPACK]) { Rules.name(:WATERFALL) }
  end

  test "has no name for a move of other rules" do
    assert_nil in_game { Rules.name(:FLY) }
  end

  test "a boulder that moves itself the way the player walks into it is pushed with no field move" do
    boulder = rolling
    assert_equal [true, [nil]], [Effects.self_pushed?(boulder), Effects.push_move(boulder)]
  end

  test "names such a boulder a pushable object, not a Strength boulder, also when it says something on the way" do
    { "silent" => rolling,
      "saying a line" => rolling(:say => "The boulder raised the level of the lava!") }.each do |what, ev|
      assert_equal t(:loc_pushable), PokeAccess::Locator.target_name(ev), what
    end
  end

  test "a Pikachu built the same way is pushed too, keeping its own name" do
    pikachu = rolling(:name => "pikachu", :sprite => "025")
    assert_equal [[nil], "pikachu"], [Effects.push_move(pikachu), PokeAccess::Locator.target_name(pikachu)]
  end

  test "is a push walked into or touched by the event, and when the branch only turns the player besides" do
    { "walked into" => rolling, "touched by the event" => rolling(:trigger => 2),
      "turning the player" => rolling(:player => [16]) }.each do |what, ev|
      assert_equal true, Effects.self_pushed?(ev), what
    end
  end

  test "is no push when the route steps the player, rolls it two tiles, or the action button fires it" do
    { "a route on the player" => rolling(:target => -1), "the player stepping too" => rolling(:player => [1]),
      "two tiles" => rolling(:steps => 2), "the action button" => rolling(:trigger => 0) }.each do |what, ev|
      assert_equal false, Effects.self_pushed?(ev), what
    end
  end

  test "a boulder its script pushes needs Strength, as one named a boulder alone does" do
    script = [TestCmd.new(355, ["pbPushThisBoulder"])]
    scripted = TestGameEvent.new(:id => 4, :name => "Boulder",
                                 :pages => [TestPage.new(:sprite => "object_boulder", :list => script)])
    named = TestGameEvent.new(:id => 5, :name => "Boulder", :pages => [TestPage.new(:sprite => "object_boulder")])
    assert_equal [[:STRENGTH], [:STRENGTH]], [Effects.push_move(scripted), Effects.push_move(named)]
  end

  test "an event that is neither is not pushed" do
    hiker = TestGameEvent.new(:id => 6, :name => "Hiker", :pages => [TestPage.new(:sprite => "hiker")])
    assert_nil Effects.push_move(hiker)
  end

  test "a pitfall stops a route on foot and is crossed riding the bicycle, straight on to the tile past it" do
    pitfall(4, 4)
    { false => false, true => [5, 4, 2] }.each do |riding, want|
      $PokemonGlobal.bicycle = riding
      assert_equal want, Pits.arrival(4, 4, 6), "riding: #{riding}"
    end
  ensure
    $PokemonGlobal.bicycle = false
  end

  test "riding, a row of pits is crossed a press a tile, and one with the way on shut is no step" do
    on_pits(['######', '#@PP.#', '#.PP##', '######']) do
      assert_equal [[4, 1, 3], false], [Pits.arrival(2, 1, 6), Pits.arrival(2, 2, 6)]
    end
  end

  test "riding, a route never turns on a pit: the bend of pits is ridden past and walked back to" do
    on_pits(['#######', '#@PPP.#', '####P.#', '####..#', '#######']) do
      assert_equal [6, 6, 6, 6, 2, 2, 4], PokeAccess::Routes::Planner.walk(4, 3, true).route
    end
  end

  test "riding, a route never stops on a pit beside the target, ending on the floor beside it" do
    on_pits(['#####', '#PTP#', '#P.P#', '#@..#', '#####']) do
      assert_equal [6, 8], PokeAccess::Routes::Planner.walk(2, 1).route
    end
  end

  test "leaves a tile with no pitfall to the core" do
    pitfall(4, 4)
    $PokemonGlobal.bicycle = true
    assert_nil Pits.arrival(5, 4, 6)
  ensure
    $PokemonGlobal.bicycle = false
  end

  test "off the Ancient Tower's maps no tile is read for a pitfall" do
    $game_map.map_id = 40
    asked = counting(PokeAccess::World::Events, :anchored) { (0...10).each { |x| Pits.pit?(x, 4) } }
    assert_equal 0, asked
  end

  test "on a map with no fall, only the first tile asked looks over the map for one" do
    Falls.forget
    $game_map.set_terrain(6, 5, 7)
    first = Falls.above_fall?(6, 4)
    asked = counting(PokeAccess::World::Terrain, :kind) { (0...10).each { |x| Falls.above_fall?(x, 4) } }
    assert_equal [false, 0], [first, asked]
  end

  test "on a map with a fall, a tile above it is above a fall and one beside it is not" do
    Falls.forget
    falls
    assert_equal [true, true, false], [Falls.above_fall?(6, 2), Falls.above_fall?(6, 3), Falls.above_fall?(5, 2)]
  end

  test "carries a surfer whose step down ends above a fall to the water past it" do
    falls
    assert_equal [6, 5], Falls.descent(6, 2, 2)
  end

  test "carries a walker whose step down ends above a fall past it too, as the game does on foot" do
    falls
    $PokemonGlobal.surfing = false
    $game_map.set_terrain(6, 5, 0)
    assert_equal [6, 5], Falls.descent(6, 2, 2)
  end

  test "carries no one moving across or with no fall below" do
    falls
    assert_nil Falls.descent(6, 2, 6), "moving across"
    assert_nil Falls.descent(5, 2, 2), "no fall below"
  end

  test "carries a surfer over a fall that runs off the map nowhere" do
    $game_map.set_terrain(6, 18, 8).set_terrain(6, 19, 8)
    $PokemonGlobal.surfing = true
    assert_equal false, Falls.descent(6, 17, 2)
  end

  test "a planned surf down into a fall with no crest is carried past it once the game declares its falls crestless" do
    was = Moves.instance_variable_get(:@crestless)
    falls
    assert_nil Moves.falls_step(6, 3, 2, 0), "the core alone carries a surfer from a crest only"
    Moves.crestless_falls!
    landed = [3, 4].map { |y| s = Moves.falls_step(6, y, 2, 0); s && [s.x, s.y] }
    assert_equal [[6, 5], [6, 5]], landed, "declared crestless, from either of the fall's tiles"
  ensure
    Moves.instance_variable_set(:@crestless, was)
  end

  test "climbs the rocks up with the Hiking Boots past them, and a step on where the game lets the player take it" do
    on_rocks do
      up = in_game([BOOTS]) { Climb.step(2, 5, [0, -1, 8], 0) }
      assert_equal [[2, 1], [:field, :ins_rock_climb, :HIKINGBOOTS, 2, 4]],
                   [up.tile, [up.gate[:kind], up.gate[:label], up.gate[:item], up.gate[:x], up.gate[:y]]]
    end
  end

  test "climbs the rocks down to the first tile past them where the step on is closed" do
    on_rocks do
      down = in_game([BOOTS]) { Climb.step(2, 2, [0, 1, 2], 0) }
      assert_equal [[2, 5], 2, 3], [down.tile, down.gate[:x], down.gate[:y]]
    end
  end

  test "climbs nothing facing the rocks across, with no rocks in front, or without the Hiking Boots" do
    on_rocks do
      assert_nil in_game([BOOTS]) { Climb.step(1, 3, [1, 0, 6], 0) }, "facing across"
      assert_nil in_game([BOOTS]) { Climb.step(1, 5, [0, -1, 8], 0) }, "no rocks in front"
      assert_nil in_game([SCUBA]) { Climb.step(2, 5, [0, -1, 8], 0) }, "without the boots"
    end
  end

  test "says the climbable rocks ahead and the Hiking Boots that clear them" do
    on_rocks do
      said = in_game([BOOTS]) { PokeAccess::Routes::Text.hold(Climb.step(2, 5, [0, -1, 8], 0).gate, 2, 5) }
      assert_equal t(:loc_gate_use, :what => t(:ins_rock_climb), :dir => t(:dir_up), :move => "Item573"), said
    end
  end

  test "names a current by the way it carries the player" do
    { "current_up" => :dir_up, "current_down" => :dir_down, "current_left" => :dir_left,
      "current_right" => :dir_right }.each do |name, dir|
      assert_equal t(:ins_current, :dir => t(dir)), Names.name(named(name, "tide_current")), name
    end
  end

  test "names a Hoopa ring that leads nowhere yet, and leaves one that transfers to the core" do
    dormant = named("Hoopa_Hole", "hoopa_ring")
    open = named("Hoopa_Hole", "hoopa_ring", [TestCmd.new(201, [0, 5, 1, 1]), TestCmd.new(0, [])])
    assert_equal [t(:ins_hoopa_ring), nil], [Names.name(dormant), Names.name(open)]
  end

  test "names a Manaphy statue by its name and sprite, and a Heart Swap spot without the statue an object" do
    { ["HeartSwap_S1", "manaphy_statue"] => t(:ins_manaphy_statue), ["HeartSwap_S1", ""] => t(:loc_object),
      ["Statue", "manaphy_statue"] => nil }.each do |(name, sprite), want|
      assert_answer want, Names.name(named(name, sprite)), "#{name}, #{sprite}"
    end
  end

  test "names a Pokemon Centre's secret base door: a page that only calls the base's entrance" do
    door = TestCmd.new(117, [6])
    { [door, TestCmd.new(0, [])] => t(:ins_sb_door), [door, nil, TestCmd.new(0, [])] => t(:ins_sb_door),
      [TestCmd.new(117, [7]), TestCmd.new(0, [])] => nil, [TestCmd.new(101, ["Hi"]), door] => nil,
      [] => nil }.each do |list, want|
      assert_answer want, Names.name(named("EV022", "", list)), list.map { |c| c && c.code }.inspect
    end
  end

  test "names what a Tesseract spot gives" do
    spot = named("Tesseract_Spot_2", "", [TestCmd.new(355, ["pbItemBall(:POTION)"]), TestCmd.new(0, [])])
    assert_equal t(:loc_object_named, :name => "Pocion"), Names.name(spot)
  end

  test "names a Tesseract spot a bare object with item naming off, or with no command list" do
    spot = named("Tesseract_Spot_2", "", [TestCmd.new(355, ["pbItemBall(:POTION)"]), TestCmd.new(0, [])])
    bare = named("Tesseract_Spot_2", "", nil)
    PokeAccess::Config.name_items = false
    assert_equal t(:loc_object), Names.name(spot), "item naming off"
    PokeAccess::Config.name_items = true
    assert_equal t(:loc_object), Names.name(bare), "no command list"
  end

  test "names a Tesseract spot that brings a wild Pokemon by its species, and one that brings a boulder pushable" do
    wild = named("Tesseract_Spot_2", "025", [TestCmd.new(355, ["pbWildBattle(PBSpecies::PIKACHU,15)"]),
                                             TestCmd.new(0, [])])
    species = PokeAccess::Locator.sprite_species("025")
    refute_nil species, "the stand-in data names the sprite's species"
    assert_equal [species, t(:loc_pushable)], [Names.name(wild), Names.name(rolling(:name => "Tesseract_Spot_2"))]
  end

  test "names what a Tesseract spot gives when the item-naming setting cannot be read" do
    spot = named("Tesseract_Spot_2", "", [TestCmd.new(355, ["pbItemBall(:POTION)"]), TestCmd.new(0, [])])
    was = PokeAccess::Config.method(:name_items)
    PokeAccess::Config.define_singleton_method(:name_items) { raise "unreadable" }
    assert_equal t(:loc_object_named, :name => "Pocion"), Names.name(spot)
  ensure
    PokeAccess::Config.define_singleton_method(:name_items, was)
  end

  test "files currents, rings and statues as things, and nothing else" do
    { ["current_up", "tide_current"] => true, ["Hoopa_Hole", "hoopa_ring"] => true,
      ["HeartSwap_S1", "manaphy_statue"] => true, ["HeartSwap_S1", ""] => false, ["Statue", "manaphy_statue"] => false,
      ["EV001", "npc"] => false }.each do |(name, sprite), want|
      assert_equal want, Names.object?(named(name, sprite)), "#{name}, #{sprite}"
    end
  end

  test "leaves the soaring maps' shadow marker out, and only it" do
    { "soar_stalker" => true, "soar_stalker2" => false, "EV001" => false }.each do |name, want|
      assert_equal want, Names.hidden?(named(name, "soar_marker")), name
    end
  end

  test "an event whose name cannot be read is none of its families" do
    broken = Object.new
    def broken.name; raise "no name"; end
    assert_equal [nil, false, false], [Names.name(broken), Names.object?(broken), Names.hidden?(broken)]
  end

  test "drops a trainer sprite's variant and a Pokemon sprite's form, and nothing from any other sprite" do
    { "trchar050_1" => "trchar050", "718_3" => "718", "025_12" => "025", "NPC 14" => nil, "trchar050" => nil,
      "7180_3" => nil, "trchar050_x" => nil }.each do |sprite, want|
      assert_answer want, Names.base_sprite(sprite), sprite
    end
  end

  test "still water is sludge while the map's sludge slot holds slime" do
    on_tileset("ins_outside", ["", "", "", "", "", "", "slime"]) do
      assert_equal [true, false], [Water.sludge_at?(2, 2), Water.sludge_at?(3, 2)], "the still water, and dry ground"
    end
  end

  test "still water is water again once Seed Flare turns the slot to water" do
    names = ["", "", "", "", "", "", "slime"]
    on_tileset("ins_outside", names) do
      names[6] = "calm transparent water 2"
      assert_equal false, Water.sludge_at?(2, 2)
    end
  end

  test "each of the game's tilesets keeps its sludge in its own slot" do
    { "ins_outside" => 6, "interior_main" => 0, "ins_black" => 1, "DeepSeaBase" => 4 }.each do |tileset, slot|
      names = Array.new(7, "")
      names[slot] = "slime"
      other = Array.new(7, "slime")
      other[slot] = ""
      got = [names, other].map { |slots| on_tileset(tileset, slots) { Water.sludge_at?(2, 2) } }
      assert_equal [true, false], got, tileset
    end
  end

  test "a tileset with no sludge slot has no sludge" do
    assert_equal false, on_tileset("ins_town", Array.new(7, "slime")) { Water.sludge_at?(2, 2) }
  end

  private

  def t(key, opts = {}); PokeAccess::I18n.t(key, opts); end

  # Passes when got is want, nil included.
  def assert_answer(want, got, msg = nil)
    want.nil? ? assert_nil(got, msg) : assert_equal(want, got, msg)
  end

  # The block's value in a game whose bag holds the items given (by id), with the party and the badge count given and
  # the ids the rules ask for, but for those named in lacking; all put back after.
  def in_game(items = [], party = [], badges = 0, lacking = [])
    bag_was = $PokemonBag
    $PokemonBag = Object.new
    $PokemonBag.define_singleton_method(:pbQuantity) { |id| items.include?(id) ? 1 : 0 }
    $Trainer.define_singleton_method(:party) { party }
    $Trainer.badges = [true] * badges + [false] * (8 - badges)
    with_ids(lacking) { yield }
  ensure
    $PokemonBag = bag_was
    $Trainer.singleton_class.send(:remove_method, :party) if $Trainer.singleton_methods.include?(:party)
    $Trainer.badges = [false] * 8
  end

  # The block's value with the game's tables holding IDS, but for the names in lacking, which are taken out meanwhile;
  # every table is put back as it was.
  def with_ids(lacking = [])
    added = []
    taken = []
    IDS.each do |mod, ids|
      ids.each do |name, id|
        if lacking.include?(name)
          next unless mod.const_defined?(name, false)
          taken.push([mod, name, mod.const_get(name)])
          mod.send(:remove_const, name)
        elsif !mod.const_defined?(name, false)
          mod.const_set(name, id)
          added.push([mod, name])
        end
      end
    end
    yield
  ensure
    added.each { |mod, name| mod.send(:remove_const, name) }
    taken.each { |mod, name, v| mod.const_set(name, v) }
  end

  # The block's value with owner::name set to value, put back as it was after.
  def with_constant(owner, name, value)
    had = owner.const_defined?(name, false)
    was = had ? owner.const_get(name) : nil
    owner.send(:remove_const, name) if had
    owner.const_set(name, value)
    yield
  ensure
    owner.send(:remove_const, name) if owner.const_defined?(name, false)
    owner.const_set(name, was) if had
  end

  # The block's value with the core answering whether a party Pokemon knows a move, its own answer put back after.
  def knowing(answer)
    core = PokeAccess::FieldMoves
    was = core.method(:knows?)
    core.define_singleton_method(:knows?) { |_move| answer }
    yield
  ensure
    core.define_singleton_method(:knows?, was)
  end

  # A touch event that, for each way the player faces (111 [6, -1, d]), sets a move route on the event itself stepping
  # that way, as Insurgence's rolling boulders (Map280 ev1) and Pokemon Z's Pikachu (Map123 ev16) are built.
  # param opts :name, :sprite, :trigger, :target (the route's character, 0 the event, -1 the player), :steps (steps
  #   per route), :player (move codes of a route on the player beside it), :say (a line said in the first branch)
  def rolling(opts = {})
    list = []
    STEP_MOVES.each do |d, step|
      route = TestMoveRoute.new([TestMoveCmd.new(step)] * opts.fetch(:steps, 1) + [TestMoveCmd.new(0)])
      list.push(TestCmd.new(111, [6, -1, d], 0))
      list.push(TestCmd.new(209, [opts.fetch(:target, 0), route], 1))
      list.push(World.move_player(opts[:player], 1)) if opts[:player]
      list.push(TestCmd.new(101, [opts[:say]], 1)) if opts[:say] && d == 2
      list.push(TestCmd.new(0, [], 1))
      list.push(TestCmd.new(412, [], 0))
    end
    list.push(TestCmd.new(0, [], 0))
    page = TestPage.new(:trigger => opts.fetch(:trigger, 1), :sprite => opts.fetch(:sprite, "object_boulder"),
                        :list => list)
    TestGameEvent.new(:id => 3, :name => opts.fetch(:name, "boulder"), :pages => [page])
  end

  # An event of one action-button page with the sprite and the command list given.
  def named(name, sprite, list = [])
    TestGameEvent.new(:id => 9, :name => name, :pages => [TestPage.new(:sprite => sprite, :list => list)])
  end

  # Places one of the Ancient Tower's invisible pitfalls on (x, y), on its first floor's map.
  def pitfall(x, y)
    $game_map.map_id = 366
    $game_map.events[7] = TestGameEvent.new(:id => 7, :name => "Pitfall", :x => x, :y => y)
    World.next_frame
  end

  # The block's value riding the bicycle on the Ancient Tower's first floor drawn as rows, each 'P' a pitfall and
  # 'T' a solid event, with the profile's pit rule registered as the profile does; the rules and the map put back.
  def on_pits(rows)
    moves = PokeAccess::Routes::Moves
    rules = moves.instance_variable_get(:@arrival_rules)
    saved = rules.dup
    hpa_fresh_grid(rows)
    $game_map.map_id = 366
    $game_map.events.each_value do |e|
      ch = rows[e.y][e.x, 1]
      e.name = "Pitfall" if ch == "P"
      e.character_name = "" if ch == "P"
      e.blocking = true if ch == "T"
    end
    moves.arrival_rule(:tiles => lambda { |x, y| Pits.pit?(x, y) }) { |x, y, d| Pits.arrival(x, y, d) }
    $PokemonGlobal.bicycle = true
    PokeAccess::World.reset!
    yield
  ensure
    $PokemonGlobal.bicycle = false
    rules.replace(saved)
    moves.forget_map
    $game_map.clear_grid
    PokeAccess::World.reset!
  end

  # Runs the block counting the calls of mod's method name; answers the count.
  def counting(mod, name)
    was = mod.method(name)
    calls = 0
    mod.define_singleton_method(name) { |*args| calls += 1; was.call(*args) }
    yield
    calls
  ensure
    mod.define_singleton_method(name, was)
  end

  # The block's value on a room whose column x = 2 holds climbable rocks on rows 3 and 4 (walls of tag 4), open
  # above them on rows 1 and 2, and below them on row 5 over a wall; the map cleared after.
  def on_rocks
    $game_map.load_grid(["#####", "#...#", "#...#", "#.#.#", "#.#.#", "#...#", "#####"])
    [3, 4].each { |y| $game_map.set_terrain(2, y, Climb::TAG) }
    yield
  ensure
    $game_map.clear_grid
  end

  # A waterfall on (6, 3) and (6, 4) over water on (6, 5), with no crest, and the player afloat.
  def falls
    $game_map.set_terrain(6, 3, 8).set_terrain(6, 4, 8).set_terrain(6, 5, 7)
    $PokemonGlobal.surfing = true
  end

  # The block's value on a map of the tileset given whose autotile slots are names, its tile (2, 2) still water; the
  # map's own answers put back after.
  def on_tileset(tileset, names)
    $game_map.define_singleton_method(:tileset_name) { tileset }
    $game_map.define_singleton_method(:autotile_names) { names }
    $game_map.set_terrain(2, 2, 6)
    yield
  ensure
    [:tileset_name, :autotile_names].each do |m|
      $game_map.singleton_class.send(:remove_method, m) if $game_map.singleton_methods.include?(m)
    end
  end
end
