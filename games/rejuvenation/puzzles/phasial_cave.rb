# The inner Phasial Cave (map 116): a battle there that ends on a Dark Crystal Cavern field (Dark Pulse, Dark Void,
# Night Daze or Light That Burns the Sky) makes the parallel event 6 move the player to the same tile of map 570, the
# cave turned dark. Narcissa (4 at 34,38) wonders about it in words.
PokeAccess::Game.define("rejuvenation") do
  mechanic(:state, 116, :part => :dark_field) do
    auto
    active { PokeAccess::Puzzles.assist? }
    hint :rj_phasial_dark_hint
  end
  mechanic(:state, 570, :part => :dark_field) do
    auto
    sent_back :rj_phasial_turned_dark, :maps => [116]
  end
end
