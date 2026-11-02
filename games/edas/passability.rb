# Edas' player passability (Game_Player#passable? in 0225_Escaleras Diagonales, then Game_Character#passableEx? and
# Game_Map#passable? and #playerPassable?) reads the map's tiles, tileset and events, the bridge, surf and bike state and
# the player's place, nothing else an event sets; its side stairs read terrain tags, and the Eye of Truth changes an
# event's through flag, which the world's events follow, so an event's end keeps the probe's answers.
PokeAccess::Game.define("edas") do
  plain_passability
end
