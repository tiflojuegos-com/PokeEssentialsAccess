# Pokémon Decades' player passability reads the map's tiles, tileset and events, the bridge, surf and bike state and the
# player's place, and the switch of its No Clip Disk, which lets the player through anything (Game_Player#passable?,
# 0046_Game_Player.rb); Following Pokemon EX only stops other events. So an event's end keeps the probe's answers, in that
# switch's two modes.
PokeAccess::Game.define("decades") do
  PokeAccess::World::Probe.mode_reader { ($game_switches[96] rescue nil) ? true : false }
  plain_passability
end
