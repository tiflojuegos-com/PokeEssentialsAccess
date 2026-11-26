# Bladestar's Decompression Lab (map 505). The four security screens (events 1, 3, 4 and 11) play six recordings,
# left and right to change and Enter to look closer; with variable 294 at 20, only the fifth or the sixth one, looked
# at, moves Flora's story on (294 to 21). From the first, left once reaches the sixth.
PokeAccess::Game.define("rejuvenation") do
  mechanic(:state, 505, :part => :cameras) do
    auto
    name [1, 3, 4, 11], :rjd_bl_screens
    on_reach [1, 3, 4, 11], { :text => 1 }, lambda { $game_variables[294].to_i == 20 ? :rjd_bl_cameras_hint : nil },
             :assist => true
    hint :rjd_bl_cameras_hint
    active { $game_variables[294].to_i == 20 }
    solved { $game_variables[294].to_i >= 21 }
  end
end
