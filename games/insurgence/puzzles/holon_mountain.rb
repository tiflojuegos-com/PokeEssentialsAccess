# Holon Mountain: the grass southeast of Settlement Juliet (map 455) hides a lightning rod pair (events 18 and 20) that
# an Electric move used in a battle inside x 60 to 71, y 17 to 27 charges (switch 521); with them charged the first wild
# Pokemon met there is a Delta Seedot (switch 522). The Mountainous Cave (map 549) has a button engraved in the rock
# (event 12, switch 520) that opens the two passages into the next cave, and a Tesseract spot (event 16).
PokeAccess::Game.define("insurgence") do
  rods = lambda { |_ev| $game_switches[521] ? :ins_o2_rod_charged : :ins_o2_rod }
  met = lambda { $game_switches[522] }
  mechanic(:state, 455, :part => :rods) do
    auto
    name [18, 20], rods
    phase lambda { !$game_switches[521] }, :quiet => true, :hint => :ins_o2_rod_hint
    phase lambda { $game_switches[521] && !met.call }, :quiet => true, :hint => :ins_o2_rod_seedot
    solved(nil, :quiet => true) { met.call }
  end
  mechanic(:state, 549, :part => :button) do
    auto
    name 12, :ins_o2_rock_button_hint, :assist => true, :when => lambda { |_ev| !$game_switches[520] }
    name 16, lambda { |_ev| PokeAccess::Puzzles.assist? ? :ins_o2_tess_spot_go : :ins_u1_tesseract_spot }
    solved(nil, :quiet => true) { $game_switches[520] }
  end
end
