# Sevii's player passability reads the map's tiles, tileset and events, the bridge, surf and bike state and the
# player's place, nothing else an event sets, so an event's end keeps the probe's answers. Its pushes move a boulder
# after the plain passable? check (the strict one is commented out in pbPushThisEvent).
PokeAccess::Game.define("sevii") do
  plain_passability
  loose_pushes
end
