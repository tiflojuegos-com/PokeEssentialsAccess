# Lavaridge's gym (map 413): nineteen ladders with no sprite, each moving the player to another area. TOWARDS holds the
# ones on a shortest way to Flannery, counting areas joined by ladders only; 17 to 19 lead nowhere useful. Her badge fight
# (switch 116) ends it.
PokeAccess::Game.define("fireash") do
  ladders = (1..19).to_a
  towards = [1, 3, 5, 6, 8, 10, 11, 12, 14, 15]
  mechanic(:state, 413) do
    auto
    name ladders, PokeAccess::FireAshPads.namer(towards, :fa_ladder, :fa_ladder_towards)
    sent_back :fa_ladder_sent, :events => ladders
    arrival_hint :fa_ladders_rule
    solved { $game_switches[116] }
  end
end
