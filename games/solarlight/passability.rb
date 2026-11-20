# Solar's player passability reads the map's tiles, tileset and events, the bridge, surf and bike state and the player's
# place, nothing else an event sets (checked against its scripts): the Following Pokemon's Game_Map#passable? only lets
# other events past the follower, and Debug Passability is a viewer. An event's end keeps the probe's answers.
PokeAccess::Game.define("solarlight") do
  plain_passability
end
