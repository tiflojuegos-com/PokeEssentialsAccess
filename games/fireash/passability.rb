# Fire Ash's player passability and terrain are Essentials v19's own, redefined by none of its plugins: they read the
# map's tiles, tileset and events, the bridge, surf and bike state and the player's place, nothing else an event sets.
PokeAccess::Game.define("fireash") do
  plain_passability
end
