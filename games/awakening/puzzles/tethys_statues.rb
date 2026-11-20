# The Water shrine's second statue room (map 223): four statues of Tethys, each turning to face whoever uses it. The
# parallel event 10 wants the north one (49, 8) facing down, the west one (45, 11) right, the south one (49, 14) up and
# the east one (53, 11) left, all toward the middle, then lights them and opens the door at (23, 2). Each turn is said;
# with the puzzle assist, the tile beside each statue it is used from.
PokeAccess::Game.define("awakening") do
  mechanic(:facing, 223) do
    statues(/\ATetas estatua\z/, :awk_tethys_statue)
    goals [49, 8] => 2, [45, 11] => 6, [49, 14] => 8, [53, 11] => 4
    solved { $game_self_switches[[223, 10, "A"]] }
  end

  mechanic(:state, 223, :part => :rule) do
    auto
    [[49, 9], [46, 11], [49, 13], [52, 11]].each do |x, y|
      spot :at => [x, y], :label => :awk_tethys_from, :onto => true, :assist => true
    end
    active { PokeAccess::Puzzles.assist? && !$game_self_switches[[223, 10, "A"]] }
    hint :awk_tethys_hint
    solved { $game_self_switches[[223, 10, "A"]] }
  end
end
