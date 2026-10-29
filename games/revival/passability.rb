# Revival's player passability reads the map's tiles, tileset and events, the bridge, surf and bike state and the
# player's place, nothing else an event sets (checked against its scripts: SizeEvents' passableEx? asks the same tiles
# and events, Following Pokemon EX only stops other events, Debug Passability's playerPassable? is its viewer's own),
# so an event's end keeps the probe's answers.
PokeAccess::Game.define("revival") do
  plain_passability
end
