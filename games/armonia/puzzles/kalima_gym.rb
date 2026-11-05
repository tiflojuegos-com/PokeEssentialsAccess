# Kalima's gym and the yincana that opens it. In Ciudad Kalima (map 18) three balloons (events 47 to 49, while switch 77 is on)
# each hold a clue, counted by variable 31; Anne asks for three. In the aquarium (maps 25 to 27) one guard on each map asks about
# what the clues say: a wrong answer means a fight, and the way on after it.
PokeAccess::Game.define("armonia") do
  mechanic(:state, 18) do
    auto
    name(/\Aglobo\z/, :arm_kalima_balloon, :when => lambda { |ev| !$game_self_switches[[18, ev.id, "A"]] })
    count :arm_kalima_clues, :var => 31, :of => 3, :hide_zero => true
    active { $game_switches[77] && $game_variables[31].to_i < 3 }
  end

  [[25, 29], [26, 31], [27, 8]].each do |map, guard|
    mechanic(:state, map) do
      auto
      right_choice guard, :avoids => :battle
    end
  end
end
