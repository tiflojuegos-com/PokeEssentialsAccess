# Hoenn's player passability also lets the boat onto water like a surf, so the boat joins the probe's mode.
PokeAccess::Game.define("infinitefusion_hoenn") do
  PokeAccess::World::Probe.mode_reader { ($PokemonGlobal.boat rescue nil) ? true : false }
end
