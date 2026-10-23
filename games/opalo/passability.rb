# Opalo's player passability reads the map's tiles, tileset and events, the bridge, surf and bike state and the
# player's place, nothing else an event sets (checked against its scripts; its follower script only stops other
# events), so an event's end keeps the probe's answers.
PokeAccess::Game.define("opalo") do
  plain_passability
end
