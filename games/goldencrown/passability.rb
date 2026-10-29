# Golden Crown's player passability and terrain are Essentials v19.1's own: Following Pokemon EX's passable? alias
# stops only other events at the follower, and its passableStrict? and the DarkGrass and phenomena terrain tags change
# no rule the player walks by. They read the map's tiles, tileset and events, the bridge, surf and bike state and the
# player's place, nothing else an event sets.
PokeAccess::Game.define("goldencrown") do
  plain_passability
end
