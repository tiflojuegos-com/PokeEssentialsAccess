# Infinite Fusion Hoenn's visible wild Pokemon, gamedata pass: the locator names each by the species its follower
# sprite shows, never by its template's event name ("OW_normal", "OverworldPokemon"). The stand-in comes before the
# profile file loads.
class OverworldPokemonEvent
  attr_accessor :id, :name, :character_name, :species, :pokemon
  def initialize(name, sprite, species)
    @id = 77
    @name = name
    @character_name = sprite
    @species = species
  end
end

load File.expand_path("../../../games/infinitefusion_hoenn/overworld.rb", File.dirname(__FILE__))

Suite.define("ifh overworld: a wild Pokemon is named by the species its sprite shows, shiny as its folder says") do
  t = PokeAccess::I18n
  loc = PokeAccess::Locator
  $game_map.map_id = 901
  zig = PokeAccess::Data.species_name(:ZIGZAGOON)
  ev = OverworldPokemonEvent.new("OW_normal", "Followers/ZIGZAGOON", :ZIGZAGOON)
  eq "a spawned one, not its template's name", loc.target_name(ev), t.t(:loc_wild, :name => zig)
  ev.character_name = "Followers/Shiny/ZIGZAGOON"
  eq "a shiny sprite adds the mark", loc.target_name(ev), "#{t.t(:loc_wild, :name => zig)}, #{t.t(:pk_shiny)}"
  static = OverworldPokemonEvent.new("OverworldPokemon", "Followers/WINGULL_fly", :WINGULL)
  eq "a static one, its pose suffix left out", loc.target_name(static),
     t.t(:loc_wild, :name => PokeAccess::Data.species_name(:WINGULL))
end

Suite.define("ifh overworld: a disguise is named as it is drawn, a fusion as its body's silhouette, a legendary by name") do
  t = PokeAccess::I18n
  $game_map.map_id = 901
  ditto = OverworldPokemonEvent.new("OW_normal", "Followers/POOCHYENA", :DITTO)
  ditto.instance_variable_set(:@disguised, true)
  eq "a disguised Ditto is the species it shows", PokeAccess::Locator.target_name(ditto),
     t.t(:loc_wild, :name => PokeAccess::Data.species_name(:POOCHYENA))
  zig = PokeAccess::Data.species_name(:ZIGZAGOON)
  fusion = OverworldPokemonEvent.new("OW_normal", "Followers/Fusions/ZIGZAGOON", :B263H41)
  fusion.pokemon = Struct.new(:speciesName).new("Zigzarmie")
  eq "a fusion is drawn as its body's black silhouette, which never tells which fusion it is",
     PokeAccess::Locator.target_name(fusion), t.t(:if2_ow_fusion, :name => zig)
  fusion.character_name = "Followers/Fusions/Shiny/ZIGZAGOON_swim"
  eq "and a shiny one as its outline, the pose left out", PokeAccess::Locator.target_name(fusion),
     "#{t.t(:if2_ow_fusion, :name => zig)}, #{t.t(:pk_shiny)}"
  legend = Struct.new(:id, :name, :character_name).new(12, "Legendary(RAIKOU)", "POKEMON_RAIKOU")
  eq "a roaming legendary by the species in its event name", PokeAccess::IF2Overworld.wild_name(legend),
     t.t(:loc_wild, :name => PokeAccess::Data.species_name(:RAIKOU))
  plain = Struct.new(:id, :name, :character_name).new(13, "OW_normal", "POKEMON_WINGULL_perched")
  eq "and any other event is not a wild Pokemon", PokeAccess::IF2Overworld.wild_name(plain), nil
  bare = OverworldPokemonEvent.new("OW_normal", "", :WINGULL)
  eq "one drawing no follower sprite yet is its own species", PokeAccess::IF2Overworld.wild_name(bare),
     t.t(:loc_wild, :name => PokeAccess::Data.species_name(:WINGULL))
  bare.instance_variable_set(:@disguised, true)
  eq "unless it is disguised, which that would give away", PokeAccess::IF2Overworld.wild_name(bare), nil
end
