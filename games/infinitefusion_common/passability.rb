# Both Infinite Fusion games' player passability reads only the map's tiles, tileset and events, the bridge, surf and
# bike state, the player's place and switch 815 (SWITCH_LOCK_PLAYER_MOVEMENT, the probe's mode), so an event's end
# keeps the probe's answers. Their pbPushThisEvent moves a boulder after the non-strict check, hence loose_pushes.
PokeAccess::Game.define("infinitefusion_common") do
  PokeAccess::World::Probe.mode_reader { ($game_switches[815] rescue nil) ? true : false }
  plain_passability
  loose_pushes
end
