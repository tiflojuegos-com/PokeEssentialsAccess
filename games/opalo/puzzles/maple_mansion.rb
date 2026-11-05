# Opalo's Maple mansion (map 293), the night of the noise (switch 545 until the fight with Lina, switch 546): the guard of the
# young lady's room (event 28) leaves and her door (event 20, at (12, 19)) is free; five doors at the south (events 1 to 5) and
# two groups of three (events 12 to 14 and 23 to 25) say the noise was not there. That the guard left is told only on
# the screen around his post, as it is seen.
PokeAccess::Game.define("opalo") do
  night = lambda { $game_switches[545] && !$game_switches[546] }

  mechanic(:state, 293) do
    auto
    on_screen = at(2, 22, 13, 27)
    phase lambda { night.call && on_screen.call }, :title => :op_maple_guard_gone, :hint => :op_maple_hint
    phase night, :title => :op_maple_night, :quiet => true, :hint => :op_maple_hint
    spot :at => [12, 19], :label => :op_maple_door, :assist => true, :when => night
  end
end
