# Pokemon Z's player passability reads the map's tiles, tileset and events, the bridge, surf and bike state and the
# player's place, nothing else an event sets (checked against its scripts; 2.13 and 2.18 alike; its follower script
# only stops other events), so an event's end keeps the probe's answers.
PokeAccess::Game.define("pokemon_z") do
  plain_passability
end
