# Yama Passage (map 113): the boulder (event 1, on (2, 29)) has to rest on (16, 32); a sensor reads it and opens three tiles
# at (9..11, 28), the way north from the lower valley. The core says what opens once the push has done it.
PokeAccess::Game.define("keishou") do
  mechanic(:state, 113) do
    auto
    spot :at => [16, 32], :label => :ks_o_boulder_goal, :onto => true, :when => lambda { !$game_self_switches[[113, 2, "A"]] }
    hint :ks_o_yama_hint
    active { PokeAccess::Puzzles.assist? && !$game_self_switches[[113, 2, "A"]] }
  end
end
