# Broadcast Tower, mission 6 (maps 662, entered from map 201, and 663, its other time): a Tesseract spot (event 25, 61,79)
# in each takes the player to the other map when the Tesseract is used within two tiles, and a Manaphy statue (event 26)
# that Heart Swap trades places with. Crossing from 663 to 662 leaves the statue in 662 where it stood in 663.
PokeAccess::Game.define("insurgence") do
  mechanic(:state, [662, 663]) do
    auto
    name 25, lambda { |_ev| PokeAccess::Puzzles.assist? ? :ins_o2_tess_spot_go : :ins_u1_tesseract_spot }
    name 26, lambda { |_ev| PokeAccess::Puzzles.assist? ? :ins_o2_bt_statue_hint : nil }
  end
end
