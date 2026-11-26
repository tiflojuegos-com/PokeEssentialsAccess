# The type beacons of the Garufa ruins: each says its type and opens the party filtered by it; a Pokémon of that type
# lights it, showing another graphic. Water on the Garufa Sanctuary (map 72, event 12, variable 750 to 9), Dragon and
# Poison on Cubi Excellus (map 107, events 8 and 59, switches 1588 and 1589), each fading a seal.
PokeAccess::Game.define("rejuvenation") do
  { 72 => { 12 => lambda { $game_variables[750].to_i >= 9 } },
    107 => { 8 => lambda { $game_switches[1588] }, 59 => lambda { $game_switches[1589] } } }.each do |map, beacons|
    mechanic(:state, map, :part => :type_beacons) do
      auto
      beacons.each { |id, lit| name id, :rj_type_beacon, :when => lambda { |_ev| !lit.call } }
    end
  end
end
