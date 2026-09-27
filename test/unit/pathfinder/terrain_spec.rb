# Terrain predicates on the modern tag object: each reads its boolean flag, and number() reads id_number (gen-6's
# integer tags are covered by the ice tests).
Suite.define("terrain: modern tag-object flags") do
  modtag = Struct.new(:id_number, :can_surf, :ledge, :ice, :bridge, :waterfall, :can_dive)
  t_ice = modtag.new(12, false, false, true, false, false, false)
  t_water = modtag.new(7, true, false, false, false, false, false)
  truthy "ice? reads the flag and is not surfable",
         PokeAccess::Terrain.ice?(t_ice) == true && PokeAccess::Terrain.surfable?(t_ice) == false
  eq "surfable? reads the flag", PokeAccess::Terrain.surfable?(t_water), true
  eq "number() is id_number", PokeAccess::Terrain.number(t_ice), 12
  truthy "bridge? and ledge? read their flags",
         PokeAccess::Terrain.bridge?(modtag.new(15, false, false, false, true, false, false)) == true &&
         PokeAccess::Terrain.ledge?(modtag.new(1, false, true, false, false, false, false)) == true
end

# A gen-6 number is the kind its PBTerrain name says: a non-standard name is no standard kind (Insurgence's 4,
# RockClimb), and where two names share a number the standard one wins.
Suite.define("terrain: a gen-6 number is the kind its PBTerrain name says") do
  t = PokeAccess::Terrain
  t.forget_named_kinds
  eq "a number the game leaves unnamed keeps its standard kind", t.kind_of(4), :rock
  PBTerrain.const_set(:RockClimb, 4)
  PBTerrain.const_set(:Charco, 16)
  begin
    t.forget_named_kinds
    truthy "named something else, it is no standard kind", t.kind_of(4).nil?
    truthy "nor is a puddle the game calls by another name", t.kind_of(16).nil?
    PBTerrain.const_set(:Puddle, 16)
    t.forget_named_kinds
    eq "the standard name wins where two share a number", t.kind_of(16), :puddle
    eq "whichever the engine lists first", [t.kinds_of_names([[:Puddle, 16], [:Charco, 16]])[16],
                                            t.kinds_of_names([[:Charco, 16], [:Puddle, 16]])[16]], [:puddle, :puddle]
    eq "and a standard name reads as ever", t.kind_of(10), :tall_grass
  ensure
    [:RockClimb, :Charco, :Puddle].each { |c| PBTerrain.send(:remove_const, c) if PBTerrain.const_defined?(c) }
    t.forget_named_kinds
  end
end

# The copies older than v15 answer surfable water with a global predicate, not PBTerrain's: asked before the
# standard numbers, which count still water (Insurgence's mud) as water.
Suite.define("terrain: the global surfable predicate of the oldest copies is asked before the numbers") do
  t = PokeAccess::Terrain
  Object.send(:define_method, :pbIsSurfableTag?) { |tag| [5, 7, 8, 9].include?(tag) }
  Object.send(:private, :pbIsSurfableTag?)
  begin
    falsy "still water the game does not surf on", t.probe(6, :can_surf, :isSurfableNot?, :pbIsSurfableTag?) { true }
    truthy "water it does", t.probe(7, :can_surf, :isSurfableNot?, :pbIsSurfableTag?) { false }
  ensure
    Object.send(:remove_method, :pbIsSurfableTag?)
  end
  truthy "with no such predicate the numbers answer", t.probe(6, :can_surf, :isSurfableNot?, :pbIsSurfableTag?) { true }
end

# From v16 the bridge height is kept on $PokemonGlobal; the copies before keep it on $PokemonMap (Insurgence's).
# Both are read, and a search's level is set and put back on whichever holds it.
Suite.define("terrain: the bridge height is read and set wherever the engine keeps it") do
  t = PokeAccess::Terrain
  pf = PokeAccess::Pathfinder
  eq "on $PokemonGlobal", t.bridge_holder, $PokemonGlobal
  had_global = $PokemonGlobal
  had_map = $PokemonMap
  old_map = Object.new
  class << old_map; attr_accessor :bridge; end
  old_map.bridge = 2
  $PokemonGlobal = Object.new
  $PokemonMap = old_map
  begin
    eq "on $PokemonMap where $PokemonGlobal keeps none", t.bridge_holder, old_map
    eq "its height is read", t.bridge_height, 2
    eq "and is the player's level", pf.bridge_level, 2
    pf.set_bridge(0)
    eq "a level set goes there too", old_map.bridge, 0
    $PokemonMap = nil
    eq "with neither there is no bridge", t.bridge_height, 0
  ensure
    $PokemonGlobal = had_global
    $PokemonMap = had_map
  end
end
