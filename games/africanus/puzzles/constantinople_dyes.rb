# Constantinople's flashback (map 277): four merchants each want a dye of two colours for the banners, purple, orange,
# blue green and light green. Four jars with no sprite hold one colour each, drawn on the map (green V111, red V112,
# blue V113, yellow V114); each use adds a dose. A merchant looks only at his two colours: one dose of each and he
# takes the dye, else he refuses; either way all four are emptied, and EV49 empties them by hand. V115 counts the
# banners, 4 in all.
PokeAccess::Game.define("africanus") do
  mechanic(:state, 277) do
    auto
    name 50, :af_dye_blue
    name 51, :af_dye_yellow
    name 52, :af_dye_red
    name 53, :af_dye_green
    name 49, :af_dye_wash
    count :af_banners, :var => 115, :of => 4, :assist => true
    hint :af_dye_hint
    solved(nil) { $game_variables[115].to_i >= 4 }
  end
end
