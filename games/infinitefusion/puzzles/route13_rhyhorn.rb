# Route 13's Rhyhorn (map 437): once the villager's request is taken (switch 592) event 42 is the Rhyhorn, pushed like a
# boulder until it stands on the beach towel (19, 29), which ends the request (switch 593).
PokeAccess::Game.define("infinitefusion") do
  asked = lambda { $game_switches[592] }
  done = lambda { $game_switches[593] }

  mechanic(:state, 437) do
    auto
    name 42, :ifo_rhyhorn, :when => lambda { |_ev| asked.call && !done.call }
    spot :at => [19, 29], :label => :ifo_towel, :when => lambda { asked.call && !done.call }
    hint lambda { asked.call ? :ifo_rhyhorn_push : :ifo_rhyhorn_ask }
    active { PokeAccess::Puzzles.assist? && !done.call }
  end
end
