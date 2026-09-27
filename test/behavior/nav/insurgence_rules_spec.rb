# Insurgence's field rules (games/insurgence): its own field-move conditions, the rolling boulders, the Ancient Tower's
# pitfalls, waterfalls without a crest, sludge, and the names of its recurring events. The profile's modules alone are
# loaded; their overrides belong to the Insurgence process (insurgence_profile_spec).
module InsurgenceRulesSpec
  # Evaluates the module blocks of one of the profile's files, as the harness loads every file.
  def self.load_modules(file)
    path = File.join(Harness::ROOT, "games", "insurgence", file)
    File.read(path).scan(/^module PokeAccess\r?\n.*?^end\r?\n/m).each { |m| eval(m, TOPLEVEL_BINDING, path) }
  end

  Move = Struct.new(:id, :type, :basedamage)

  # Constants the rules ask of the game's tables, where the stubs lack them.
  def self.consts
    { PBItems => { :LAPRAS => 569, :JETPACK => 570, :SCUBAGEAR => 572, :HIKINGBOOTS => 573 },
      PBMoves => { :STRENGTH => 70, :ICYWIND => 196, :KARATECHOP => 2 }, PBTypes => { :FIGHTING => 1 } }.each do |mod, h|
      h.each { |k, v| mod.const_set(k, v) unless mod.const_defined?(k) }
    end
  end

  # Runs the block with a bag holding the given items, a party and a badge count, all put back afterwards.
  def self.world(items, party, badges)
    bag_was = $PokemonBag
    $PokemonBag = Object.new
    $PokemonBag.define_singleton_method(:pbQuantity) { |id| items.include?(id) ? 1 : 0 }
    $Trainer.define_singleton_method(:party) { party }
    $Trainer.badges = [true] * badges + [false] * (8 - badges)
    yield
  ensure
    $PokemonBag = bag_was
    class << $Trainer; remove_method(:party) rescue nil; end
    $Trainer.badges = [false] * 8
  end
end

%w[field_moves.rb routes.rb water.rb naming.rb].each { |f| InsurgenceRulesSpec.load_modules(f) } unless defined?(PokeAccess::InsurgenceNames)
InsurgenceRulesSpec.consts

Suite.define("insurgence field moves: Surf, Waterfall, Dive and Rock Climb as this game asks for them") do
  fm = PokeAccess::InsurgenceFieldMoves
  knows = PokeAccess::FieldMoves.method(:knows?)
  begin
    PokeAccess::FieldMoves.define_singleton_method(:knows?) { |_m| false }
    InsurgenceRulesSpec.world([569], [], 5) do
      falsy "Surf waits for the first gym's switch, Lapras or not", fm.can?(:SURF)
      $game_switches[4] = true
      truthy "with it, the Instant Lapras pack surfs with no Pokemon knowing the move", fm.can?(:SURF)
      falsy "five badges are not enough for Waterfall", fm.can?(:WATERFALL)
    end
    InsurgenceRulesSpec.world([570, 572], [], 6) do
      falsy "no Lapras and no Surf in the party: no Surf", fm.can?(:SURF)
      truthy "six badges and the Magic Carpet climb waterfalls", fm.can?(:WATERFALL)
      truthy "the Scuba Gear alone dives", fm.can?(:DIVE)
      falsy "and without the Hiking Boots there is no Rock Climb", fm.can?(:ROCKCLIMB)
    end
    eq "the guide names the Magic Carpet for Waterfall", fm.name(:WATERFALL), "Item570"
    falsy "moves of other rules are left to the core", fm.handles?(:CUT)
  ensure
    PokeAccess::FieldMoves.define_singleton_method(:knows?, knows)
  end
end

Suite.define("insurgence field moves: Strength by any of its thirteen moves, Rock Smash by a damaging Fighting move") do
  fm = PokeAccess::InsurgenceFieldMoves
  m = InsurgenceRulesSpec::Move
  party = [Poke.build(:moves => [m.new(33, 0, 40), m.new(196, 14, 55)]), Poke.build(:moves => [m.new(2, 1, 50)])]
  InsurgenceRulesSpec.world([], party, 1) do
    falsy "Strength waits for the first gym's switch", fm.can?(:STRENGTH)
    $game_switches[4] = true
    truthy "then Icy Wind moves boulders", fm.can?(:STRENGTH)
    eq "and the guide names the move the game will use", fm.name(:STRENGTH), "Mov196"
    truthy "a damaging Fighting-type move breaks the rocks, with no switch", fm.can?(:ROCKSMASH)
    eq "named as the game's first pick", fm.name(:ROCKSMASH), "Mov2"
  end
  InsurgenceRulesSpec.world([], [Poke.build(:moves => [m.new(2, 1, 0)])], 8) do
    falsy "a Fighting move that does no damage does not", fm.can?(:ROCKSMASH)
    eq "and the guide says what it takes", fm.name(:ROCKSMASH), PokeAccess::I18n.t(:ins_fighting_move)
  end
end

Suite.define("insurgence routes: rolling boulders, pitfalls and waterfalls without a crest") do
  b = PokeAccess::InsurgenceBoulders
  roll = lambda do |name, target|
    page = TestPage.new(:trigger => 1, :sprite => "object_boulder",
                        :list => [TestCmd.new(209, [target, TestMoveRoute.new([TestMoveCmd.new(1)])]), TestCmd.new(0, [])])
    TestGameEvent.new(:id => 3, :name => name, :pages => [page])
  end
  truthy "a lower-case boulder moving itself on touch rolls with no move", b.rolling?(roll.call("boulder", 0))
  falsy "the capitalised Boulder is Strength's", b.rolling?(roll.call("Boulder", 0))
  falsy "a route on the player is no rolling boulder", b.rolling?(roll.call("boulder", -1))

  $game_map.events.clear
  $game_map.events[7] = TestGameEvent.new(:id => 7, :name => "Pitfall", :x => 4, :y => 4)
  PokeAccess::Pathfinder.forget_event_indexes
  p = PokeAccess::InsurgencePits
  eq "on foot a pit stops the route", p.arrival(4, 4), false
  $PokemonGlobal.bicycle = true
  eq "riding it is crossed", p.arrival(4, 4), [4, 4]
  eq "anywhere else the core decides", p.arrival(5, 4), nil
  $PokemonGlobal.bicycle = false

  $game_map.set_terrain(6, 3, 8).set_terrain(6, 4, 8).set_terrain(6, 5, 7)
  $PokemonGlobal.surfing = true
  eq "a surfer ending a step down above a fall is carried past it", PokeAccess::InsurgenceFalls.descent(6, 2, 2), [6, 5]
  eq "not when moving across", PokeAccess::InsurgenceFalls.descent(6, 2, 6), nil
  eq "a planned fall is left to the core unless it goes down", PokeAccess::InsurgenceFalls.entered(6, 3, 8, 0), :none
  $PokemonGlobal.surfing = false
end

Suite.define("insurgence names: currents, rings, statues, base doors and sprites with a variant") do
  n = PokeAccess::InsurgenceNames
  t = PokeAccess::I18n
  ev = lambda { |name, sprite, list| TestGameEvent.new(:id => 9, :name => name, :pages => [TestPage.new(:sprite => sprite, :list => list)]) }
  eq "a current by the way it carries", n.name(ev.call("current_left", "tide_current", [])),
     t.t(:ins_current, :dir => t.t(:dir_left))
  eq "a ring that leads nowhere yet", n.name(ev.call("Hoopa_Hole", "hoopa_ring", [])), t.t(:ins_hoopa_ring)
  eq "a Manaphy statue", n.name(ev.call("HeartSwap_S", "manaphy_statue", [])), t.t(:ins_manaphy_statue)
  eq "a Pokemon Centre's base door", n.name(ev.call("EV022", "", [TestCmd.new(117, [6]), TestCmd.new(0, [])])), t.t(:ins_sb_door)
  eq "anything else is the core's", n.name(ev.call("EV023", "", [TestCmd.new(117, [7])])), nil
  truthy "currents, rings and statues are things", n.object?(ev.call("current_up", "tide_current", []))
  truthy "the soaring shadow marker stays out", n.hidden?(ev.call("soar_stalker", "soar_marker", []))
  eq "a trainer sprite's variant is dropped", n.base_sprite("trchar050_1"), "trchar050"
  eq "and a Pokemon sprite's form", n.base_sprite("718_3"), "718"
  eq "a plain sprite has none", n.base_sprite("NPC 14"), nil
end

Suite.define("insurgence sludge: still water while the map's sludge slot is slime, and water once cleared") do
  w = PokeAccess::InsurgenceWater
  names = ["", "", "", "", "", "", "slime"]
  def $game_map.tileset_name; "ins_outside"; end
  $game_map.define_singleton_method(:autotile_names) { names }
  begin
    $game_map.set_terrain(2, 2, 6)
    truthy "still water on a slime map is sludge", w.sludge_at?(2, 2)
    falsy "other tiles are not", w.sludge_at?(3, 2)
    names[6] = "calm transparent water 2"
    falsy "after Seed Flare it is water again", w.sludge_at?(2, 2)
  ensure
    class << $game_map
      remove_method(:tileset_name) rescue nil
      remove_method(:autotile_names) rescue nil
    end
  end
end
