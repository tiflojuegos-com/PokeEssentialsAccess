# Perfection Laboratory (map 751). Four floor buttons in a row with no graphic (events 18 to 21) keep their
# order in variable 164 and switch 611, both shared with the Holon Pyramid: button 2, then 4, then 3 opens the way
# (switch 624); anything else fails back to 0. A pink floor tile (25,34) turns switch 623 on while any event but the
# player stands on it, which removes the pillars; the Manaphy statue (event 17) is what can be moved there with Heart Swap,
# which puts it where the player stood. A door with a keyboard (event 2) asks for a password (switch 622). Map 754 is not
# playable: it is the security tape, which runs by itself with the player invisible while a scientist presses buttons 2, 4 and 3.
PokeAccess::Game.define("insurgence") do
  code_done = lambda { $game_switches[624] }
  state = lambda { [($game_variables[164] || 0).to_i, $game_switches[611] ? true : false] }
  press = lambda { |n| lambda { [:ins_o1_lab_press, { :n => n }] } }
  at_count = lambda { |v, on| lambda { !code_done.call && state.call == [v, on] } }
  mechanic(:state, 751, :part => :code) do
    auto
    name 18..21, :ins_o1_lab_button, :numbered => true
    phase lambda { !code_done.call && state.call[0] == 0 }, :hint => press.call(2)
    phase at_count.call(1, true), :hint => press.call(4)
    phase at_count.call(2, true), :hint => press.call(3)
    phase lambda { !code_done.call }, :hint => :ins_o1_lab_broken
    solved(nil, :quiet => true) { code_done.call }
  end
  mechanic(:state, 751, :part => :statue) do
    auto
    name [6, 10, 14, 15], :ins_o1_lab_pillar
    spot :at => [25, 34], :label => :ins_o1_lab_pink_tile, :onto => true
    arrival_hint lambda { PokeAccess::Puzzles.assist? ? :ins_o1_lab_statue_hint : nil }, :once => true
    hint :ins_o1_lab_statue_hint
    active { !$game_switches[623] }
    solved(nil, :quiet => true) { $game_switches[623] }
  end
  mechanic(:state, 751, :part => :door) do
    auto
    name 2, :ins_o1_lab_door
    answer 2, "antilithium"
    solved(nil, :quiet => true) { $game_switches[622] }
  end
  mechanic(:state, 754) do
    arrival_hint :ins_o1_lab_tape
  end
end
