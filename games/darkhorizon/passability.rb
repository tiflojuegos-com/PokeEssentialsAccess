# Dark Horizon's player passability reads the map's tiles, tileset and events, the bridge, surf and bike state and the
# player's place, nothing else an event sets (checked against its scripts: Gateon Port's bridges are map 138's events
# named GateonPortBridge, Marin's Enhanced Staircases read the player's stair, Following Pokemon EX only stops other
# events), so an event's end keeps the probe's answers.
PokeAccess::Game.define("darkhorizon") do
  plain_passability
end
