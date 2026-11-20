# Ancient Tower. In the present (maps 365 to 368) the floor has invisible pitfalls that drop to the floor below, and
# Tesseract rifts (events named Tesseract_Spot_2: map 365 events 1 and 3, map 366 event 1, map 368 event 30) that bring a
# platform from the past once the Tesseract is used within three tiles of them. The past floors (maps 646 to 649) are
# full of rocks that roll one tile when pushed.
PokeAccess::Game.define("insurgence") do
  rifts = { 365 => [1, 3], 366 => [1], 368 => [30] }
  rifts.each do |map, ids|
    mechanic(:state, map, :part => :rifts) do
      auto
      name ids, lambda { |_ev| PokeAccess::Puzzles.assist? ? :ins_o2_rift_hint : :ins_o2_rift },
           :when => lambda { |ev| !$game_self_switches[[$game_map.map_id, ev.id, "A"]] }
    end
  end
  mechanic(:state, [366, 367, 368], :part => :pits) do
    auto
    arrival_hint :ins_o2_tower_pits, :once => true
  end
  mechanic(:state, [646, 647, 648, 649], :part => :rocks) do
    auto
    arrival_hint :ins_o2_tower_rocks, :once => true
  end
end
