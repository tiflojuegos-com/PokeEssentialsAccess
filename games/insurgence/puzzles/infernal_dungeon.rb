# Infernal Dungeon, the Magma Stone floor (map 503, reached once switch 477 is on): the lava curtain (event 2, at 29,14) only
# lets pass a player who wears the Magma Protection Suit (variable 41 at 15), which the suit stand (event 3, at 36,24) puts
# on when asked, with its own message. The curtain leads to the Upper Mantle (map 504). Switch 486 ends the Magma Stone fight.
PokeAccess::Game.define("insurgence") do
  mechanic(:state, 503) do
    auto
    name 2, :ins_u1_lava_curtain
    name 3, :ins_u1_suit_stand
    on_use 3, :ins_u1_suit_answer, :assist => true
    active { !$game_switches[486] }
    solved(nil, :quiet => true) { $game_switches[486] }
    hint :ins_u1_dungeon_hint
  end
end
