# Keishou's player passability (Advanced Items' Game_Map#playerPassable?, 02_Terrain Tag Plus.rb) reads the map's tiles,
# tileset and events, the bridge, surf and bike state and the player's place, nothing else an event sets; its Following
# Pokemon EX only stops other events, and a Rock Climb passes through. So an event's end keeps the probe's answers.
PokeAccess::Game.define("keishou") do
  plain_passability
end
