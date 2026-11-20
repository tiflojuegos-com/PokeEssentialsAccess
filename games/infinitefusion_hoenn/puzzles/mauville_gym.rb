# Mauville Gym (map 102): four floor switches (events 8 and 20 build the blue layout, 18 and 21 the red one) that set the
# electric fences, events named ELEC(i,j) whose script resizes them to 1 by 5, 5 by 1 or off. A switch marks itself with its
# own switch A and clears the other three, so the layout in force is the one of the switch that has it, but on each arrival
# InitializePuzzle (event 12) builds a starting layout of its own, the only one with fence (0,2) (event 14) on, and marks
# event 8, whose page does nothing then until another switch is stepped on. With the generator off (switch 2198) the fences
# are gone and the switches do nothing; beating Wattson sets switch 6.
PokeAccess::Game.define("infinitefusion_hoenn") do
  powered = lambda { !$game_switches[2198] }
  pressed = lambda do |*ids|
    lambda { powered.call && ids.any? { |id| $game_self_switches[[102, id, "A"]] } }
  end

  mechanic(:state, 102) do
    auto
    name [8, 20], :if_jh_switch_blue
    name [18, 21], :if_jh_switch_red
    obstacle({ :named => /\AELEC/ }, :label => :if_jh_fence)
    arrival_hint lambda { powered.call ? :if_jh_mauville_rule : nil }
    solved { $game_switches[6] }
    phase lambda { powered.call && !$game_self_switches[[102, 14, "B"]] }, :title => :if_jh_layout_start, :quiet => false,
          :hint => :if_jh_layout_start_hint
    phase pressed.call(18, 21), :title => :if_jh_layout_red, :quiet => false
    phase pressed.call(8, 20), :title => :if_jh_layout_blue, :quiet => false
  end
end
