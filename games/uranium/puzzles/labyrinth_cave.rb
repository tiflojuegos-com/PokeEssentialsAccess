# The Labyrinth (map 80): two pairs of passages inside the cave, events 2 (to 22,88), 6 (to 54,9), 3 (to 23,8) and 4 (to 5,25).
# Crossing the cave's water with Surf, the pair of events 2 and 6 is the only way to the Route 15 exit; the pair of events 3
# and 4 only leads to the pocket with the Mega Stone at (17, 7).
PokeAccess::Game.define("uranium") do
  mechanic(:state, 80) do
    auto
    arrival_hint :ura_po_lab_rule, :once => true
    sent_back :ura_po_lab_warp, :to => [22, 88], :events => 2
    sent_back :ura_po_lab_warp, :to => [54, 9], :events => 6
    sent_back :ura_po_lab_warp, :to => [23, 8], :events => 3
    sent_back :ura_po_lab_warp, :to => [5, 25], :events => 4
    phase lambda { true }, :quiet => true, :hint => :ura_po_lab_hint
  end
end
