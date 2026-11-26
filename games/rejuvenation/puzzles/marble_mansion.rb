# Marble Mansion in Aevium's past (map 250): four Meloetta statues (events 49, 51, 54, 55; variables 661 to 664) turn a
# quarter as the player uses them from below. At variable 246 of 30 or more, event 56 wants the north-west one facing
# east, north-east south, south-west north and south-east west, then sets 246 to 32 and 33.
PokeAccess::Game.define("rejuvenation") do
  mechanic(:facing, 250, :part => :meloetta_statues) do
    auto
    statues(/\Apkmn_meloetta_1\z/, :rj_meloetta_statue)
    goals [63, 10] => 6, [82, 11] => 2, [59, 32] => 8, [78, 33] => 4
    solved(nil, :quiet => true) { $game_variables[246].to_i >= 32 }
  end

  mechanic(:state, 250, :part => :meloetta) do
    auto
    [[63, 11], [82, 12], [59, 33], [78, 34]].each do |xy|
      spot :at => xy, :label => :rj_meloetta_turn_from, :onto => true, :assist => true
    end
    not_control [49, 51, 54, 55]
    hint :rj_meloetta_hint
    active { PokeAccess::Puzzles.assist? && $game_variables[246].to_i >= 30 && $game_variables[246].to_i < 32 }
    solved(nil, :quiet => true) { $game_variables[246].to_i >= 32 }
  end

  mechanic(:state, 250, :part => :portrait) do
    auto
    name 57, :rj_marble_portrait, :when => lambda { |_ev| !$game_switches[604] }
    hint :rj_marble_portrait_hint
    active { !$game_switches[604] }
    solved(nil, :quiet => true) { $game_switches[604] }
  end
end
