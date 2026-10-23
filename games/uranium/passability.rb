# Uranium's player passability reads the map's tiles, tileset and events, the bridge, surf and bike state and the
# player's place, nothing else an event sets (checked against its scripts; the bridge it keeps in $PokemonMap
# included), so an event's end keeps the probe's answers.
PokeAccess::Game.define("uranium") do
  plain_passability
end
