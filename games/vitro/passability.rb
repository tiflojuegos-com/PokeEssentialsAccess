# Vitro's player passability (Game_Player#passable? in 0354_Escaleras Diagonales, then Game_Character#passableEx? in
# 0355_Size Events and Game_Map#passable? and #playerPassable?) reads the map's tiles, tileset and events, the bridge, surf
# and bike state and the player's place, nothing else an event sets: 0353_Pathfinder moves events along its own routes, the
# follower's Game_Map#passable? (0362_Pokemon_Followpoke_Bezier) only stops other events and the spawner's
# (0365_OWE_Spawner) its own Pokemon. So an event's end keeps the probe's answers.
PokeAccess::Game.define("vitro") do
  plain_passability
end
