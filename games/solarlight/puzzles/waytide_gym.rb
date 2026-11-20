# Waytide's gym (maps 288 to 291 and 293 to 295, one map for each way its currents run): on each, a floor switch drawn
# with a tile (event 1, switches 545 to 551) that, stepped on, turns the currents and carries the player to the next map
# on the same tile. Map 292, the first hall after its fourth switch, has none.
PokeAccess::Game.define("solarlight") do
  mechanic(:state, [288, 289, 290, 291, 293, 294, 295]) do
    auto
    name 1, :solar_waytide_switch
    avoid 1
    arrival_hint :solar_waytide_rule, :once => true
  end
end
