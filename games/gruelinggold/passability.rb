# Grueling Gold's player passability reads the map's tiles, tileset and events, the bridge, surf and bike state and the
# player's place, nothing else an event sets, so an event's end keeps the probe's answers.
PokeAccess::Game.define("gruelinggold") do
  plain_passability
end
