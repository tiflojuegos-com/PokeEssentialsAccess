# Navel Rock (map 716): two mazes of hidden warp panels in pairs. Toward Ho-Oh's chamber (event 8, at (49,27)) the
# panels 2, 4 and 6 lead on; toward the way out to map 718 (event 26, at (42,103)) the panels 12, 14, 16, 18, 20, 22 and
# 23, each landing two tiles to the side of the next. Their partners lead back. Checked by a search over the map, the
# panels set in walls firing as the player walks into them.
PokeAccess::Game.define("emerald") do
  mechanic(:state, 716) do
    auto
    hide [3, 5, 7, 13, 15, 17, 19, 21, 24, 25], :assist => true
    phase lambda { $game_player.y < 70 }, :quiet => true, :hint => :em_navel_upper_hint, :hidden => right_way(2, 4, 6)
    phase lambda { $game_player.y >= 70 }, :quiet => true, :hint => :em_navel_hint,
          :hidden => right_way(12, 14, 16, 18, 20, 22, 23)
  end
end
