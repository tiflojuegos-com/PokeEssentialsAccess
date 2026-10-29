# World Frontier's player passability reads the map's tiles (MakerStudio's extended layers among them, kept in each
# map's data), tileset and events (MakerStudio's always-blocking pages among them), the bridge, surf and bike state and
# the player's place, nothing else an event sets: checked against MakerStudio's 003_GameMapOverride and
# 013_EventExtensions and Marin Side Stairs; no map uses MakerStudio's switch-selected versions, and Following Pokemon
# EX only stops other events. An event's end keeps the probe's answers.
PokeAccess::Game.define("worldfrontier") do
  plain_passability
end
