# Anil's player passability reads the map's tiles, tileset and events, the bridge, surf and bike state and the
# player's place, nothing else an event sets, so an event's end keeps the probe's answers; Advanced Items' lava surf
# and rock climb join the probe's mode in plugins/advanced_items.rb.
PokeAccess::Game.define("anil") do
  plain_passability
end
