# Data resolution on the gen-6 harness: the PB* provider is active and maps each id to its name or field, move
# power and accuracy from PBMoveData (the modern half is provider_modern_gd_spec).
Suite.define("data: gen-6 provider resolves ids") do
  eq "gen-6 provider is active", PokeAccess::Data.active, PokeAccess::DataG6
  eq "move_name", PokeAccess::Data.move_name(7), "Mov7"
  eq "move_power via PBMoveData", PokeAccess::Data.move_power(7), 47
  eq "move_accuracy", PokeAccess::Data.move_accuracy(7), 100
  eq "type_name", PokeAccess::Data.type_name(2), "Tipo2"
  eq "item_name", PokeAccess::Data.item_name(25), "Repel"
  eq "species_name", PokeAccess::Data.species_name(3), "Especie3"
  eq "species_entry", PokeAccess::Data.species_entry(3), ["Especie3", "msg3", "msg3"]
  eq "nature_name", PokeAccess::Data.nature_name(1), "Naturaleza1"
  eq "stat_name", PokeAccess::Data.stat_name(4), "Estadistica4"
  eq "item_id symbol to id", PokeAccess::Data.item_id("REPEL"), [25, "Repel"]

  pkt = Object.new
  def pkt.type1; 1; end
  def pkt.type2; 2; end
  eq "pokemon_types gen-6", PokeAccess::Data.pokemon_types(pkt), ["Tipo1", "Tipo2"]
  eq "species_types from the dex data", PokeAccess::Data.species_types(4), ["Tipo1", "Tipo2"]
  eq "a species of one type names it once", PokeAccess::Data.species_types(25), ["Tipo13"]
  eq "trainer_type_name by number", PokeAccess::Data.trainer_type_name(65), "Posadera"
  eq "and by its constant", PokeAccess::Data.trainer_type_name("HIKER"), "Montanero"
  truthy "a constant the game lacks is nil", PokeAccess::Data.trainer_type_name("AQUAGRUNT_M").nil?
  truthy "and so is a name that cannot be one", PokeAccess::Data.trainer_type_name("hiker").nil?
  eq "none of which is a provider error", PokeAccess::Data.errors.grep(/trainer_type_name|species_types/), []
end

# The toolkit boots under the harness with its core submodules defined.
Suite.define("data: core submodules present after load") do
  %w[Config Hooks Keys Info Menus Battle Party Summary Locator Pathfinder Spatial
     ConfigMenu Settings Audio3D Pokedex Tags Appearance Data].each do |m|
    truthy "submodule #{m}", (PokeAccess.const_defined?(m.to_sym) rescue false)
  end
end
