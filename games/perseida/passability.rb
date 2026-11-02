# Perseida's player passability (Game_Player#passable? in 0303_Escaleras Diagonales, then Game_Character#passableEx? in
# 0307_Size Events and Game_Map#passable? and #playerPassable?) reads the map's tiles, tileset and events, the bridge, surf
# and bike state and the player's place, nothing else an event sets: 0314_Pathfinder Elena moves events along its own
# routes, and the follower's Game_Map#passable? (0317_Pokemon_Followpoke_Bezier) only stops other events. So an event's end
# keeps the probe's answers.
PokeAccess::Game.define("perseida") do
  plain_passability
end
