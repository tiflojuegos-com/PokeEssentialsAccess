# Laverre's gym (map 840): six rooms joined by pads with no sprite, and Valerie in the middle one. TOWARDS holds the pads on
# a shortest way to her, counting rooms joined by pads only. Her badge fight (switch 254) ends it.
PokeAccess::Game.define("fireash") do
  pads = (2..23).to_a - [6, 12, 14]
  towards = [4, 13, 17, 20, 22]
  mechanic(:state, 840) do
    auto
    name pads, PokeAccess::FireAshPads.namer(towards, :fa_pad, :fa_pad_towards)
    sent_back :fa_pad_sent, :events => pads
    arrival_hint :fa_pads_rule
    solved { $game_switches[254] }
  end
end
