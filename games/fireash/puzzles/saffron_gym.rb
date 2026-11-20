# Saffron's gym (map 136): nine rooms joined by pads with no sprite but 2 and 42, drawn with a tile, and Sabrina in the
# middle one. TOWARDS holds the pads on
# a shortest way to her, counting rooms joined by pads only; pad 42 is a shortcut to her room that her own room's pad 2 opens,
# and with it open the list changes.
# Her second fight (self switch B) ends it.
PokeAccess::Game.define("fireash") do
  pads = (2..31).to_a + [41, 42]
  closed = [4, 5, 11, 13, 15, 17, 20, 21, 27, 29, 31, 41]
  shortcut = [3, 8, 10, 11, 13, 15, 17, 20, 21, 27, 29, 31, 41, 42]
  towards = lambda { $game_self_switches[[136, 42, "A"]] ? shortcut : closed }
  mechanic(:state, 136) do
    auto
    name pads, PokeAccess::FireAshPads.namer(towards, :fa_pad, :fa_pad_towards)
    sent_back :fa_pad_sent, :events => pads
    arrival_hint :fa_pads_rule
    solved { $game_self_switches[[136, 39, "B"]] }
  end
end
