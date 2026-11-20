# Shattered Seas (map 218), after Krakanao: two groups of tide currents, events 31, 74, 78, 90 to 92 in the west (x 69 to 72,
# y 42 to 45) and 93 to 100 in the east (x 90 to 95, y 78 to 80). With the Tidal Bell in the bag, stepping on one switches the
# currents of its group on, and from then on each current carries the player across the sea.
PokeAccess::Game.define("uranium") do
  mechanic(:state, 218) do
    auto
    name [31, 74, 78, 90, 91, 92], :ura_pp_tide, :grouped => true
    name((93..100).to_a, :ura_pp_tide, :grouped => true)
    sent_back :ura_pp_tide_carried, :events => [31, 74] + (93..100).to_a
    hint lambda { $game_switches[159] ? :ura_pp_tide_hint : "" }
  end
end
