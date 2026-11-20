# Xenoverse's player passability (Game_Player#passable? in 0019, Game_Character#passableEx? in 0017, Game_Map#passable?
# and #playerPassable? in 0013) reads the tiles, tileset, events, bridge, surf and bike state and the player's place, and
# $PokemonGlobal.lavasurfing, which opens lava tiles. Switch 1203 makes characters jump onto ledges from any side (0017's
# move_*, and 0013 for other events), and 0172's playerPassable? belongs to its debug passability viewer. So an event's
# end keeps the probe's answers, in the modes of those two.
PokeAccess::Game.define("xenoverse") do
  PokeAccess::World::Probe.mode_reader do
    [($game_switches[1203] rescue nil) ? true : false, ($PokemonGlobal.lavasurfing rescue nil) ? true : false]
  end
  plain_passability
end
