# Mossdeep's gym (map 442): rooms joined by pairs of pads; pad 7 is one way and drops the player where no pad brings back.
# TOWARDS holds the pads on a shortest way to Tate and Liza, counting rooms joined by pads only. Their fight (switch 119) ends it.
PokeAccess::Game.define("fireash") do
  pads = (1..11).to_a
  towards = [1, 4, 8, 10]
  mechanic(:state, 442) do
    auto
    name pads, PokeAccess::FireAshPads.namer(towards, :fa_pad, :fa_pad_towards)
    sent_back :fa_pad_oneway, :events => 7
    sent_back :fa_pad_sent, :events => pads - [5, 6, 7]
    arrival_hint :fa_pads_rule
    solved { $game_switches[119] }
  end
end
