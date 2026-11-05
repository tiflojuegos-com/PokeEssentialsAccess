# Ashen Frost's player passability is stock v20.1 (Game_Player#passable?, Game_Character#passable?, Game_Map#passable? and
# #playerPassable?, unchanged in its scripts; no plugin aliases them; its followers only stop other events): it reads the
# map's tiles, tileset and events, the bridge, surf and bike state and the player's place, nothing else an event sets, so
# an event's end keeps the probe's answers.
PokeAccess::Game.define("ashenfrost") do
  plain_passability
end
