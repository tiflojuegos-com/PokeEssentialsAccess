# The fossil scouting of quest 24, place by place: Route 3 (map 98, count in variable 92) opens once variable 52 reaches
# 17, Mt. Ahi West (208, variable 93) once Route 3's count reaches 3, Route 15 (319 and 313, joined by a map connection,
# variable 94) after Mt. Ahi, and Route 18 (344, variable 95) after Route 15. Strips and tiles with no graphic each add
# one to their place's count the first time they are walked over, and the third marks a new place on the map. Nothing
# shows them, so they are listed with the puzzle assist alone, each until it or its place is done.
PokeAccess::Game.define("herolegacy") do
  counts = { 98 => 92, 208 => 93, 319 => 94, 313 => 94, 344 => 95 }
  open = lambda do |ev|
    map = $game_map.map_id
    !$game_self_switches[[map, ev.id, "A"]] && $game_variables[counts[map]].to_i < 3
  end
  mechanic(:state, counts.keys) do
    auto
    name(/\AFossil-Check/, :hl_fossil_spot, :assist => true, :when => open)
  end
end
