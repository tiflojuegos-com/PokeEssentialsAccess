# Well Temple Depths (map 687, Case Seventeen): dived into from the well (map 686, event 45) with 15 seconds of air on
# the game's timer (event 2). The switch (event 3), twelve tiles north of the landing (34, 24) and one west, adds one to
# variable 251, the north spikes' count, and sends the player up; the way round is 66 tiles. Exit: event 1.
PokeAccess::Game.define("ashenfrost") do
  pressed = lambda { $game_self_switches[[687, 3, "A"]] ? true : false }
  mechanic(:state, 687, :part => :depths) do
    name 3, :afc_switch
    phase lambda { PokeAccess::Puzzles.assist? && !pressed.call }, :hint => :afc_depths_way
    solved(nil, :quiet => true) { pressed.call }
  end
end
