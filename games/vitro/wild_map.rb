# Vitro's Pokemon on the map: those its spawners bring (0365_OWE_Spawner, events named SpawnedPokemon, on 59 maps, with
# $PokemonSystem.pokeMap on as it comes) and those a CaveMon dust cloud turns into as the map's scene starts (pbSetBattles in
# 0364_Pokemon_WildMap, events named PokeBattle), each kept for its battle in $PokemonGlobal.storedRouteMon under its event's id.
# Core would say the event's name. The routes meet them as any event that walks: World::Events follows them as they come and go.
# A spawn is said only when shiny, which the game marks with an animation alone: the rest come every few seconds, with a cry.
module PokeAccess
  module VitroWild
    NAMES = %w[SpawnedPokemon PokeBattle]

    # The Pokemon an event stands for, or nil.
    def self.pokemon(ev)
      return nil unless NAMES.include?(ev.name.to_s)
      stored = $PokemonGlobal.storedRouteMon
      stored && stored[ev.id]
    end

    # Says the Pokemon of the event just spawned, if shiny.
    def self.spawned(id)
      stored = $PokemonGlobal.storedRouteMon
      pokemon = id && stored && stored[id]
      PokeAccess.speak(PokeAccess::Locator.wild_name(pokemon), false) if pokemon && PokeAccess::Party.shiny?(pokemon)
    end
  end
end

PokeAccess::Game.define("vitro") do
  event_name do |ev|
    pokemon = PokeAccess::VitroWild.pokemon(ev)
    pokemon && PokeAccess::Locator.wild_name(pokemon)
  end
  after("Game_Map", :spawnPokemonEvent, :hook_container => true) { |_map, id, _args| PokeAccess::VitroWild.spawned(id) }
end
