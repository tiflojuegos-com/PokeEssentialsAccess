# Mauville Gym (map 398): two rows of lasers (events 7 and 10 on switch 43, events 11 and 16 on switch 44) are drawn while their
# switch is on, which Vermilion's gym turns on, and close the way to Wattson. Beating Kirk (event 4) turns switch 43 off and
# beating Watt (event 17) turns switch 44 off. Both off is the end. With Wattson already beaten (switch 115) both trainers are
# on a page that no longer battles or turns anything off, so rows drawn then stay.
PokeAccess::Game.define("fireash") do
  mechanic(:state, 398) do
    auto
    stuck = lambda { $game_switches[115] && ($game_switches[43] || $game_switches[44]) }
    name [7, 10, 11, 16], :fa_laser, :when => lambda { |_ev| $game_switches[43] || $game_switches[44] }
    watch :switch => 43, :label => :fa_o_row_near, :on => :fa_o_row_closed, :off => :fa_o_row_open
    watch :switch => 44, :label => :fa_o_row_far, :on => :fa_o_row_closed, :off => :fa_o_row_open
    arrival_hint lambda { stuck.call ? :fa_o_wattson_late_rule : :fa_o_wattson_rule }
    hint lambda { stuck.call ? :fa_o_wattson_late_hint : :fa_o_wattson_hint }
    solved { !$game_switches[43] && !$game_switches[44] }
  end
end
