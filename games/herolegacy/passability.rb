# Pokémon Hero Legacy's player passability reads the map's tiles, tileset and events, the bridge, surf and bike state and the
# player's place (Game_Map#playerPassable?), and its rock climb's state, which joins the probe's mode with that plugin. So an
# event's end keeps the probe's answers.
PokeAccess::Game.define("herolegacy") do
  plain_passability
end
