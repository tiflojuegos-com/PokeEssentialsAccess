# Deep Mantle (map 505 in the present, 508 in the past; the Tesseract carries the player from one to the other on the same
# tile, from two tiles or less of its point, Tesseract_Spot_1). From the entrance, the exit to the Outer Core (event 43, at
# 73,6) can only be walked to in the past: in the present the way is cut, with or without the 39 boulders (events 3 to 41),
# which are decoration in the past, so in both they stay out of the lists. In the past, a Heart Swap that leaves the Manaphy
# statue at x 33, y 16 to 22 sends the next Tesseract to one of the maps 510 to 516 instead of 505: the same room with the
# ruined statue (DERELICT, in 505 too) where the Manaphy statue was left, boulders that are pushed and a Tesseract that goes
# back to the past. Only in 510 and 515 does the way to the exit open once the boulders in the corridor at x 70 are out of it.
# The exit leads to the Outer Core, whose Magma Stone (switch 479) ends the errand.
PokeAccess::Game.define("insurgence") do
  tesseract = /\ATesseract_Spot_1\z/
  hint_with = lambda do |keys|
    lambda { keys.map { |k| PokeAccess::I18n.t(k) }.join(". ") }
  end
  [[505, [:ins_u1_mantle_present_hint], true], [508, [:ins_u1_mantle_past_hint], true],
   [[510, 515], [:ins_u1_mantle_altered_hint, :ins_u1_mantle_rocks_open], false],
   [[511, 512, 513, 514, 516], [:ins_u1_mantle_altered_hint, :ins_u1_mantle_rocks_cut], false]].each do |maps, hints, quiet_rocks|
    mechanic(:state, maps) do
      auto
      name tesseract, :ins_u1_tesseract_spot
      name(/\ADERELICT\z/, :ins_u1_mantle_derelict)
      hide(/\Aboulder\z/) if quiet_rocks
      active { !$game_switches[479] }
      solved(nil, :quiet => true) { $game_switches[479] }
      hint hint_with.call(hints + [:ins_u1_tesseract_range])
    end
  end
end
