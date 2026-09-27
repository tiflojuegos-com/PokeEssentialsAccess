# DarrylBD99's Wardrobe: the check mark is the outfit chosen, which is only put on when the player confirms on the
# way out; the outfit worn is the scene's @outfit_current, an index into its @outfit_all.

def wardrobe_spec(checked, current)
  win = World.stub_scene(:@outfits => ["Normal", "Classic", "Magma"], :@outfit_selected => checked)
  scene = World.stub_scene(:@outfit_all => ["Normal", "Magma", "Classic"], :@outfit_current => current)
  [win, scene]
end

Suite.define("wardrobe: the check reads as chosen, and only the outfit on as worn") do
  w = PokeAccess::Wardrobe
  worn = PokeAccess::I18n.t(:wardrobe_worn)
  chosen = PokeAccess::I18n.t(:wardrobe_chosen)
  win, scene = wardrobe_spec(0, 0)
  eq "on opening the check sits on the outfit worn", w.text(win, 0, scene), "Normal, #{worn}"
  win, scene = wardrobe_spec(1, 0)
  eq "moved to another, that one is chosen", w.text(win, 1, scene), "Classic, #{chosen}"
  eq "while the one on is still worn", w.text(win, 0, scene), "Normal, #{worn}"
  eq "and the rest are plain", w.text(win, 2, scene), "Magma"
  win, scene = wardrobe_spec(2, 1)
  eq "worn follows the outfit's place in the full list, not the row", w.text(win, 2, scene), "Magma, #{worn}"
  eq "with no scene to ask, the check reads as before", w.text(win, 2), "Magma, #{worn}"
end
